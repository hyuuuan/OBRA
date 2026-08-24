class_name DrawPanel
extends CanvasLayer
## In-game drawing panel. Lives alongside the running game instead of being its
## own scene: when the backend recognizes a drawing it emits `drawing_ready` and
## the game level spawns/replaces the creature in place — no scene switch.

signal drawing_ready(
	entity: String,
	display_name: String,
	drawing: Image,
	response: Dictionary,
	strokes: Array,
	ink_cost: float
)
signal panel_closed
## A declined recognition, so the level can answer it. The panel already handles the
## player-facing part (ink released, buttons re-enabled); this exists because Lolo speaks
## over the FIRST decline anywhere in the level -- "not because you drew it wrong, because
## I could not tell it apart from something else" -- and only the level knows it is first.
signal recognition_declined(entity: String, confidence: float, margin: float, reason: String)

@export var debug_timing_logs: bool = false

## Seconds between live guesses. The model answers in single-digit milliseconds, so
## this paces the RENDER-and-encode cost, not inference, and keeps the readout from
## flickering through a new class on every stroke point.
@export var live_guess_interval: float = 0.28

var ink_manager: InkManager

@onready var scrim: ColorRect = $Scrim
@onready var panel_root: Control = $PanelRoot
@onready var canvas_viewport: SubViewport = $PanelRoot/SubViewportContainer/SubViewport
@onready var canvas: Control = $PanelRoot/SubViewportContainer/SubViewport/Canvas
@onready var canvas_frame: UIOvalFrame = $PanelRoot/CanvasFrame
@onready var transform_button: Button = $PanelRoot/TransformButton
@onready var clear_button: Button = $PanelRoot/ClearButton
@onready var status: Label = $PanelRoot/StatusLabel
@onready var guess_label: Label = $PanelRoot/GuessLabel
@onready var client: Node = $PanelRoot/SketchClient

## The header's own ink readout. The scrim covers the HUD, so while the panel is open the
## gauge in the corner of the screen is hidden -- at exactly the moment ink matters most.
var _ink_gauge: HudPanel.Gauge
var _ink_value: Label


var _pending_strokes: Array = []
var _is_open := false
## Read by UIRouter.refresh_pause through the modal_overlays group.
var pauses_game := true
var _submitting := false
var _open_tween: Tween = null
var _submit_started_usec: int = 0
## --- live guessing ---------------------------------------------------------
## The canvas revision the last live guess was taken from. While it trails the
## canvas there is new ink the guess has not seen; while it matches, the player has
## stopped and the guess describes the finished drawing.
var _guessed_revision: int = -1
var _live_cooldown: float = 0.0
var _guess_entity: String = ""
var _guess_display: String = ""
var _guess_confidence: float = 0.0
var _guess_margin: float = 0.0
# Autoloads resolved through the tree so this class_name script compiles even when a
# tool precompiles it before the autoloads register. Untyped for dynamic dispatch.
var _telemetry
var _profile


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	# Not a ModalOverlay -- it owns a SubViewport, an ink transaction and a tween, and
	# none of that belongs in a shared base. It joins the group anyway so the derived
	# pause state can SEE it: otherwise any overlay closing anywhere would recompute
	# the tree as unpaused while the draw panel is still up over a live game.
	add_to_group(ModalOverlay.GROUP)
	_telemetry = get_node_or_null("/root/Telemetry")
	_profile = get_node_or_null("/root/PlayerProfile")
	visible = false
	canvas_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_style_panel()
	client.canvas_viewport = canvas_viewport
	client.set("debug_timing_logs", debug_timing_logs)
	transform_button.pressed.connect(_on_transform_pressed)
	clear_button.pressed.connect(_clear_canvas)
	# The frame sits over the viewport at the same size and origin, so its opening is
	# already in the canvas's coordinates -- no mapping, and nothing to get out of step.
	canvas.call(&"set_drawable_bounds", canvas_frame.opening())
	canvas.stroke_cost_changed.connect(_on_stroke_cost_changed)
	canvas.ink_blocked.connect(_on_ink_blocked)
	client.entity_prediction_received.connect(_on_entity_prediction)
	client.entity_declined.connect(_on_entity_declined)
	client.prediction_failed.connect(_on_prediction_failed)
	client.live_prediction.connect(_on_live_prediction)
	client.live_prediction_failed.connect(_on_live_prediction_failed)
	set_process(false)
	_clear_guess()
	status.text = "Draw something, then Transform!"


## Part of the modal_overlays contract, so the derived pause state can see this.
func is_open() -> bool:
	return _is_open


func open_panel() -> void:
	if _is_open:
		return
	_is_open = true
	_submitting = false
	client.set("debug_timing_logs", debug_timing_logs)
	visible = true
	canvas_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	transform_button.disabled = false
	clear_button.disabled = false
	canvas.clear_canvas()
	_clear_guess()
	set_process(true)
	if ink_manager != null:
		var available := ink_manager.total_uncommitted_available()
		canvas.set_ink_budget(available, ink_manager.canvas_size)
		if available <= 0.0001:
			# Otherwise the panel opens looking perfectly normal and then refuses every
			# stroke without a word: the budget is spent, so the canvas silently rejects
			# each one and Transform posts an empty image to be told it is empty.
			status.text = "No ink left — nothing more can be drawn in this level"
		else:
			# The header gauge carries the budget. This said "Ink remaining 12.0 / 12.0"
			# beneath a gauge already showing it, in decimals, and then went stale the
			# moment the first stroke landed.
			status.text = "Draw something, then Transform"
	else:
		status.text = "Draw something, then Transform"
	# Nothing has been drawn yet, so there is nothing to transform.
	transform_button.disabled = true
	_refresh_ink_row(0.0)
	UIRouter.refresh_pause(get_tree())
	_play_open_animation()


func close_panel(emit_closed: bool = true, release_ink: bool = true) -> void:
	if _open_tween != null:
		_open_tween.kill()
		_open_tween = null
	_is_open = false
	_submitting = false
	transform_button.disabled = false
	clear_button.disabled = false
	visible = false
	set_process(false)
	_clear_guess()
	canvas_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if release_ink and ink_manager != null:
		ink_manager.release_attempt()
	UIRouter.refresh_pause(get_tree())
	if emit_closed:
		panel_closed.emit()


## The running guess. The panel used to say nothing at all until Transform was pressed,
## so the player found out whether the game had understood their drawing only after
## spending the ink on it -- and a wrong read looked like the game being broken rather
## than like a drawing that needed another line. Now the guess is on screen the whole
## time they are drawing.
##
## It only ever REPORTS. Transforming is spent ink and a changed body, and nothing here
## decides on the player's behalf that the drawing is finished -- pausing to look at
## what you have made is not the same as saying you are done with it.
func _process(delta: float) -> void:
	if not _is_open or _submitting:
		return
	_live_cooldown = maxf(0.0, _live_cooldown - delta)
	var revision: int = canvas.content_revision()
	# The last guess was taken from exactly this ink: nothing new to ask about.
	if revision == _guessed_revision:
		return
	if _live_cooldown > 0.0:
		return
	if not canvas.has_ink():
		_clear_guess()
		return
	_live_cooldown = live_guess_interval
	# Claimed before the request so a slow answer does not re-send the same ink; a
	# refusal (one already in flight) hands it back to be retried next tick.
	var claimed := revision
	_guessed_revision = claimed
	if not await client.request_live_guess():
		if _guessed_revision == claimed:
			_guessed_revision = -1


func _on_live_prediction(
	entity: String,
	display_name: String,
	confidence: float,
	margin: float,
	_response: Dictionary
) -> void:
	if not _is_open or _submitting:
		return
	_guess_entity = entity
	_guess_display = display_name
	_guess_confidence = confidence
	_guess_margin = margin
	guess_label.text = "I see a %s  ·  %.0f%%" % [display_name, confidence * 100.0]
	# Colour carries the same judgement the Transform gate will apply, so the player can
	# tell "it knows what this is" from "it is guessing" without reading the number.
	var sure: bool = confidence >= 0.6 and margin >= 0.15
	guess_label.modulate = Color.WHITE
	guess_label.add_theme_color_override(&"font_color",
		UISkin.LIME_PALE if sure else UISkin.PENDING)
	transform_button.text = "Transform into %s" % display_name if sure else "Transform"


func _on_live_prediction_failed(message: String) -> void:
	if not _is_open or _submitting:
		return
	_forget_guess()
	# Deliberately NOT resetting the cooldown: it was set when the request went out, so
	# leaving it alone is what paces the retry. Clearing it here would turn a backend
	# that is down into a request every frame.
	_guessed_revision = -1
	# An empty-canvas answer arrives with no message and is not worth reporting -- the
	# player has simply not drawn enough of anything yet.
	if not message.is_empty():
		guess_label.text = message
		guess_label.add_theme_color_override(&"font_color", UISkin.MUTED)


## Dress the panel in the game's own language.
##
## It was a cold blue-grey slab with a white square on it and two identical buttons: the
## screen the player spends the most time looking at, and the one least like the rest of
## the game. Everything below is appearance -- no node is added or removed that the panel's
## behaviour depends on.
func _style_panel() -> void:
	scrim.color = Color(UISkin.INK.r, UISkin.INK.g, UISkin.INK.b, 0.62)
	# The ColorRect stops painting its own slab; a Panel behind everything carries the
	# frame instead, because a ColorRect cannot hold a stylebox.
	panel_root.set("color", Color(0.0, 0.0, 0.0, 0.0))
	var frame := Panel.new()
	frame.name = "Frame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override(&"panel", HudPanel.frame())
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_root.add_child(frame)
	panel_root.move_child(frame, 0)

	# No sunken well behind the page any more. The gilt oval is the thing the paper is set
	# into, and a rectangle drawn a few pixels outside it only showed as a stray box around
	# a round frame -- two edges disagreeing about what shape the canvas is.

	# The four lime corner brackets that used to sit on the page are gone: the gilt oval
	# says "this is the thing you are working in" far better than they did, and two frames
	# around one piece of paper is one frame too many.
	var paper := canvas_viewport.get_node_or_null("Paper") as ColorRect
	if paper != null:
		# Paper, not printer white. The ink is black and the drawing is the point, so this
		# only comes far enough off white to stop the square glaring.
		paper.color = Color(0.965, 0.95, 0.9, 1.0)

	_build_header()

	guess_label.add_theme_font_size_override(&"font_size", UISkin.FONT_SUBTITLE)
	status.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	status.add_theme_color_override(&"font_color", UISkin.MUTED)

	# Hierarchy: one of these is the thing you came here to do and the other undoes your
	# work. They were identical twins. It is a family now rather than a stylebox built
	# here, so the green button in this panel and the green button on the pause menu
	# cannot drift apart.
	transform_button.theme_type_variation = &"PrimaryButton"
	transform_button.add_theme_font_size_override(&"font_size", UISkin.FONT_BODY)
	clear_button.add_theme_font_size_override(&"font_size", UISkin.FONT_BODY)


## DRAW on the left, ink on the right, in the strip above the page.
func _build_header() -> void:
	var caption := Label.new()
	caption.name = "Caption"
	caption.text = "DRAW"
	caption.theme_type_variation = &"HudCaption"
	caption.position = Vector2(48.0, 14.0)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_root.add_child(caption)

	_ink_value = Label.new()
	_ink_value.name = "InkValue"
	_ink_value.text = ""
	_ink_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ink_value.theme_type_variation = &"HudValue"
	_ink_value.position = Vector2(392.0, 14.0)
	_ink_value.size = Vector2(168.0, 24.0)
	_ink_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_root.add_child(_ink_value)

	_ink_gauge = HudPanel.Gauge.new()
	_ink_gauge.name = "InkGauge"
	_ink_gauge.position = Vector2(210.0, 20.0)
	_ink_gauge.size = Vector2(164.0, 14.0)
	panel_root.add_child(_ink_gauge)


## Keep the header honest while the player draws: what is left, and what the strokes on
## the page have claimed so far.
func _refresh_ink_row(cost: float) -> void:
	if _ink_gauge == null or ink_manager == null:
		return
	_ink_gauge.capacity = ink_manager.capacity
	_ink_gauge.remaining = ink_manager.remaining()
	_ink_gauge.reserved = maxf(0.0, cost)
	_ink_gauge.queue_redraw()
	_ink_value.text = "%d of %d" % [
		floori(maxf(0.0, ink_manager.remaining())), roundi(ink_manager.capacity)]


func _clear_guess() -> void:
	_forget_guess()
	_guessed_revision = -1
	_live_cooldown = 0.0


func _forget_guess() -> void:
	_guess_entity = ""
	_guess_display = ""
	_guess_confidence = 0.0
	_guess_margin = 0.0
	guess_label.text = "…"
	guess_label.add_theme_color_override(&"font_color", UISkin.MUTED)
	transform_button.text = "Transform"


func _on_transform_pressed() -> void:
	if _submitting:
		return
	_submitting = true
	transform_button.disabled = true
	clear_button.disabled = true
	status.text = "Recognizing..."
	_submit_started_usec = Time.get_ticks_usec()
	# Capture the stroke vectors alongside the rasterized image so the rig can
	# animate the actual drawn lines.
	_pending_strokes = canvas.get_strokes()
	var ink_cost: float = float(canvas.get_current_cost())
	if ink_manager != null and not ink_manager.reserve_attempt(ink_cost):
		_submitting = false
		transform_button.disabled = false
		clear_button.disabled = false
		status.text = "Not enough ink"
		return
	if debug_timing_logs:
		var stroke_ms := float(Time.get_ticks_usec() - _submit_started_usec) / 1000.0
		print("DrawPanel collect strokes %.2f ms (%d strokes)" % [stroke_ms, _pending_strokes.size()])
	client.send_drawing()


func _on_entity_prediction(
	entity: String,
	display_name: String,
	confidence: float,
	drawing: Image,
	response: Dictionary
) -> void:
	status.text = "%s %.0f%%" % [display_name, confidence * 100.0]
	var latency_ms := _submit_latency_ms()
	if debug_timing_logs and _submit_started_usec > 0:
		print("DrawPanel submit-to-prediction %.2f ms" % latency_ms)
	if _telemetry:
		_telemetry.record_recognition({
			"outcome": "accept",
			"entity": entity,
			"source_label": response.get("source_label", ""),
			"confidence": confidence,
			"margin": response.get("margin", 0.0),
			"runner_up": response.get("runner_up", {}),
			"latency_ms": latency_ms,
		})
	if _profile:
		_profile.record_class_drawn(entity)
		_profile.note_submission(true)
	var ink_cost: float = float(canvas.get_current_cost())
	var submitted_strokes := _pending_strokes.duplicate(true)
	# Remove the full-screen scrim and resume the world before constructing a
	# potentially complex rig. This also guarantees that a downstream spawn
	# failure cannot strand the player behind a gray paused overlay.
	close_panel(true, false)
	drawing_ready.emit(entity, display_name, drawing, response, submitted_strokes, ink_cost)
	canvas.clear_canvas()


func _on_entity_declined(
	entity: String,
	confidence: float,
	margin: float,
	response: Dictionary
) -> void:
	if _telemetry:
		_telemetry.record_recognition({
			"outcome": "decline",
			"entity": entity,
			"source_label": response.get("source_label", ""),
			"confidence": confidence,
			"margin": margin,
			"runner_up": response.get("runner_up", {}),
			"latency_ms": _submit_latency_ms(),
		})
	if _profile:
		_profile.note_submission(false)
	if ink_manager != null:
		ink_manager.release_attempt()
	_submitting = false
	transform_button.disabled = false
	clear_button.disabled = false
	status.text = "not sure what that is — try drawing it more clearly!"
	# Which half of the dual gate refused it. The thesis reports these separately, and
	# they mean different things to a player: a low margin is "it looked like two things",
	# a low confidence is "it looked like nothing".
	var reason := "margin" if confidence >= 0.6 else "confidence"
	recognition_declined.emit(entity, confidence, margin, reason)


func _submit_latency_ms() -> float:
	if _submit_started_usec <= 0:
		return 0.0
	return float(Time.get_ticks_usec() - _submit_started_usec) / 1000.0


func _on_prediction_failed(message: String) -> void:
	if ink_manager != null:
		ink_manager.release_attempt()
	_submitting = false
	transform_button.disabled = false
	clear_button.disabled = false
	status.text = message


func _clear_canvas() -> void:
	canvas.clear_canvas()
	_clear_guess()
	transform_button.disabled = true
	if ink_manager != null:
		ink_manager.release_attempt()


func _on_stroke_cost_changed(cost: float) -> void:
	# Clearing the hidden canvas after a successful prediction must not replace
	# the pending utility reservation with zero before placement/storage commits.
	if not _is_open:
		return
	# There is ink on the canvas now, so there is something to offer the recogniser.
	transform_button.disabled = cost <= 0.0
	_refresh_ink_row(cost)
	if ink_manager != null:
		ink_manager.reserve_attempt(cost)
	# The status line no longer recites the ink. It used to read "Ink remaining 10.7 / 12.0
	# -- attempt 1.3" on every stroke point, which is the header gauge's job now, said in
	# decimals, over the top of whatever the panel had last told the player. This line is
	# for messages; the gauge is for the budget.


func _on_ink_blocked() -> void:
	status.text = "Ink limit reached — transform or clear"


## Called by UIRouter, ahead of the pause menu in the cancel chain. Mid-submission the
## panel declines rather than closing: the drawing is already with the recogniser and
## the ink is reserved, so tearing the panel down there would strand the transaction.
## Declining lets the key fall through to the pause menu, which is the honest result.
func handle_cancel() -> bool:
	if not _is_open or _submitting:
		return false
	canvas.clear_canvas()
	close_panel(true, true)
	return true


func _play_open_animation() -> void:
	if _open_tween != null:
		_open_tween.kill()
	panel_root.pivot_offset = panel_root.size * 0.5
	scrim.modulate.a = 0.0
	panel_root.modulate.a = 0.0
	panel_root.scale = Vector2(0.92, 0.92)

	_open_tween = create_tween()
	_open_tween.set_parallel(true)
	_open_tween.tween_property(scrim, "modulate:a", 1.0, 0.14)
	_open_tween.tween_property(panel_root, "modulate:a", 1.0, 0.16)
	_open_tween.tween_property(panel_root, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
