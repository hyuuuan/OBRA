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
@onready var canvas_viewport_container: Control = $PanelRoot/SubViewportContainer
@onready var canvas_viewport: SubViewport = $PanelRoot/SubViewportContainer/SubViewport
@onready var canvas: Control = $PanelRoot/SubViewportContainer/SubViewport/Canvas
@onready var canvas_frame: UIOvalFrame = $PanelRoot/CanvasFrame
@onready var transform_button: Button = $PanelRoot/TransformButton
@onready var clear_button: Button = $PanelRoot/ClearButton
@onready var status: Label = $PanelRoot/StatusLabel
@onready var guess_label: Label = $PanelRoot/GuessLabel
@onready var client: Node = $PanelRoot/SketchClient

const OPEN_DURATION := 0.54

## The header's own ink readout. The scrim covers the HUD, so while the panel is open the
## gauge in the corner of the screen is hidden -- at exactly the moment ink matters most.
var _ink_gauge: InkBrush
var _ink_value: Label


var _pending_strokes: Array = []
var _is_open := false
## Lolo's explanation of this screen, handed in by the level from `tutorial.json`. Empty
## means no briefing, which is how every level but the tutorial opens its canvas.
var briefing_lines: Array = []
var _briefing: CanvasBriefing
var _briefed := false
## Read by UIRouter.refresh_pause through the modal_overlays group.
var pauses_game := true
var _submitting := false
var _open_tween: Tween = null
var _scrim_material: ShaderMaterial
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
	_scrim_material = scrim.material as ShaderMaterial
	visible = false
	canvas_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_style_panel()
	client.canvas_viewport = canvas_viewport
	client.set("debug_timing_logs", debug_timing_logs)
	transform_button.pressed.connect(_on_transform_pressed)
	clear_button.pressed.connect(_clear_canvas)
	# The frame is bigger than the viewport and offset from it, so the opening has to be
	# carried into the canvas's own coordinates. It is the one number both of them read: the
	# ellipse the moulding opens and the ellipse ink is allowed inside are the same ellipse.
	var hole := canvas_frame.opening()
	hole.position += canvas_frame.position - canvas_viewport_container.position
	canvas.call(&"set_drawable_bounds", hole)
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
	_set_world_hud_visible(false)
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
	_brief_if_this_is_the_first_time()


## ⚠ THE FIRST TIME ONLY, AND ONLY WITH LINES AUTHORED FOR IT. The panel is a modal, so the
## world is already stopped and an explanation costs nothing -- but it costs the SECOND
## opening a keypress, and a tutorial that charges for a screen the player has already been
## shown is the thing everyone skips.
func _brief_if_this_is_the_first_time() -> void:
	if _briefed or briefing_lines.is_empty():
		return
	_briefed = true
	if _briefing == null:
		_briefing = CanvasBriefing.new()
		_briefing.name = "CanvasBriefing"
		add_child(_briefing)
	_briefing.begin(briefing_lines)


## The in-world HUD steps aside while the canvas is up.
##
## It has to now. The panel used to be an opaque slab that simply covered the ink gauge, the
## bag and the keybind row; with the slab gone they are still there behind the frame, and
## the bag in particular sits exactly where the status line does. Dimming them was not
## enough -- two rows of interface reading through each other is worse than either.
func _set_world_hud_visible(shown: bool) -> void:
	var layer := get_parent().get_node_or_null("CanvasLayer") as CanvasLayer
	if layer != null:
		layer.visible = shown


func close_panel(emit_closed: bool = true, release_ink: bool = true) -> void:
	if _open_tween != null:
		_open_tween.kill()
		_open_tween = null
	_is_open = false
	_submitting = false
	transform_button.disabled = false
	clear_button.disabled = false
	visible = false
	_set_world_hud_visible(true)
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
		UISkin.GOLD_PALE if sure else UISkin.PENDING)
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
	# Darker than it was, because the panel behind the controls is gone. With a slab under
	# them the buttons and the status line had their own ground; floating over the level they
	# only have the scrim, and at 0.62 the terraces still read straight through the words.
	# The scrim's shader owns the tint now; white keeps ColorRect from multiplying the
	# sampled level, while modulate.a remains available to fade the whole lens in.
	scrim.color = Color.WHITE
	if _scrim_material != null:
		_scrim_material.set_shader_parameter(&"veil_color", UISkin.INK)
	# NOTHING BEHIND THE FRAME. The panel used to be a lime-bordered slab with the gilt oval
	# drawn on top of it, which read as two objects -- a mirror sitting in a box -- and the
	# box was the one the eye found first. The oval IS the panel now: what opens is the
	# frame, over the scrim, with the header above it and the buttons below. The root keeps
	# its size because everything else is laid out against it, and paints nothing.
	panel_root.set("color", Color(0.0, 0.0, 0.0, 0.0))
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
	caption.position = Vector2(86.0, 26.0)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_root.add_child(caption)

	_ink_value = Label.new()
	_ink_value.name = "InkValue"
	_ink_value.text = ""
	_ink_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ink_value.theme_type_variation = &"HudValue"
	_ink_value.position = Vector2(406.0, 26.0)
	_ink_value.size = Vector2(168.0, 24.0)
	_ink_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_root.add_child(_ink_value)

	# The same brush the level HUD shows, two art pixels to the screen pixel instead of
	# three -- this strip is 158 wide between the caption and the number, and the brush is
	# 61 of its own pixels long. It is the SAME OBJECT in both places on purpose: the thing
	# draining while you draw is the thing you took off the stand in the house.
	_ink_gauge = InkBrush.new()
	_ink_gauge.name = "InkGauge"
	_ink_gauge.position = Vector2(248.0, 28.0)
	_ink_gauge.size = Vector2(158.0, 22.0)
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
	panel_root.modulate = Color(UISkin.GOLD_PALE.r, UISkin.GOLD_PALE.g, UISkin.GOLD_PALE.b, 0.0)
	panel_root.scale = Vector2(0.84, 0.84)
	if _scrim_material != null:
		_scrim_material.set_shader_parameter(&"opening_burst", 1.0)

	_open_tween = create_tween()
	_open_tween.set_parallel(true)
	_open_tween.tween_property(scrim, "modulate:a", 1.0, 0.34) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(panel_root, "modulate", Color.WHITE, 0.28) \
		.set_delay(0.06).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(panel_root, "scale", Vector2.ONE, OPEN_DURATION) \
		.set_delay(0.03) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	if _scrim_material != null:
		_open_tween.tween_property(_scrim_material, "shader_parameter/opening_burst", 0.0, 0.92) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
