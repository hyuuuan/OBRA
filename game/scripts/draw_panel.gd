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
## The page refused quietly (see set_refusing): the lines faded and nothing was asked of the
## recogniser. `strokes` is how many lines she drew; none is still an attempt.
signal quietly_refused(strokes: int)

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

## How much line fits on one page, in canvas diagonals. NOT the ink budget -- see the note
## in open_panel. Generous: the busiest class in the roster is well under this.
const PAGE_ALLOWANCE := 8.0

const OPEN_DURATION := 0.54
## How long a refused drawing takes to fade to the bare page.
const REFUSAL_FADE := 1.2

## The header's own ink readout. The scrim covers the HUD, so while the panel is open the
## gauge in the corner of the screen is hidden -- at exactly the moment ink matters most.
var _ink_gauge: InkBrush
## How much of a unit the drawing on the page is taking, and how much the brush shows yet.
var _claim := 0.0
var _claim_shown := 0.0
var _ink_value: Label


var _pending_strokes: Array = []
var _is_open := false
## Read by UIRouter.refresh_pause through the modal_overlays group.
var pauses_game := true
var _submitting := false
## THE BRUSH REFUSES. Mayon's two people -- lolo near the top, lola at the summit -- are the only
## things in the game the brush will not make, and the design asks that it not even try: no
## running guess, no words, no ink taken, nothing sent to the recogniser and nothing recorded.
## Paint, or putting the brush down, fades the lines to the bare page and closes it. It must not
## look like a decline -- a decline is the game failing to read a drawing, and this is the game
## being asked for something there has never been a way to make.
var _refusing := false
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
	_configure_canvas_surface()
	client.canvas_viewport = canvas_viewport
	client.set("paper_color", canvas_frame.paper)
	client.set("debug_timing_logs", debug_timing_logs)
	transform_button.pressed.connect(_on_transform_pressed)
	clear_button.pressed.connect(_clear_canvas)
	canvas.stroke_cost_changed.connect(_on_stroke_cost_changed)
	canvas.ink_blocked.connect(_on_ink_blocked)
	client.entity_prediction_received.connect(_on_entity_prediction)
	client.entity_declined.connect(_on_entity_declined)
	client.prediction_failed.connect(_on_prediction_failed)
	# Still submitting, buttons still held: only the words change, so the player knows the
	# drawing is waiting for the recogniser rather than lost.
	client.prediction_waiting.connect(func(message: String) -> void: status.text = message)
	client.live_prediction.connect(_on_live_prediction)
	client.live_prediction_failed.connect(_on_live_prediction_failed)
	set_process(false)
	_clear_guess()
	status.text = "Draw something, then Paint!"


## Part of the modal_overlays contract, so the derived pause state can see this.
func is_open() -> bool:
	return _is_open


## Whether the drawing has gone to the recogniser and the page is waiting on its answer. A
## lesson about the page has nothing to say while it is.
func is_submitting() -> bool:
	return _submitting


## Set by the level BEFORE the page opens (LevelBase._open_the_page).
func set_refusing(on: bool) -> void:
	_refusing = on


func is_refusing() -> bool:
	return _refusing


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
	_claim = 0.0
	_claim_shown = 0.0
	_clear_guess()
	set_process(true)
	if ink_manager != null:
		# ⚠ A PAGE ALLOWANCE, NOT THE BUDGET. This used to hand the canvas whatever was left
		# of the level's ink, because ink WAS length; under FR-7 a thing costs one unit
		# however neatly it is drawn, so tying the page to the purse would ration strokes
		# for a cost that no longer depends on them. What is left is a statement about the
		# page: enough line for any of the fifty classes and not enough to scribble the
		# sheet solid, which is the one thing that turns the recogniser to noise.
		canvas.set_ink_budget(PAGE_ALLOWANCE, canvas.size)
		if ink_manager.total_uncommitted_available() <= 0.0001:
			# Not "nothing more can be drawn". Becoming something is free and so is a tool
			# already in the belt, and a player on their last unit most needs to know which
			# doors are still open rather than that one has shut.
			status.text = "Out of ink — you can still become something, or use what you hold"
		else:
			# The header gauge carries the budget. This said "Ink remaining 12.0 / 12.0"
			# beneath a gauge already showing it, in decimals, and then went stale the
			# moment the first stroke landed.
			status.text = "Draw something, then Paint"
	else:
		status.text = "Draw something, then Paint"
	if _refusing:
		# Nothing on the page says what will happen. It is the drawing that has to find out.
		status.text = ""
		guess_label.text = ""
	# Nothing has been drawn yet, so there is nothing to transform.
	transform_button.disabled = true
	_refresh_ink_row()
	UIRouter.refresh_pause(get_tree())
	_play_open_animation()


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
	if not _is_open:
		return
	_ease_the_claim(delta)
	if _submitting or _refusing:
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
	var sure: bool = client.passes_gate(confidence, margin)
	guess_label.modulate = Color.WHITE
	guess_label.add_theme_color_override(&"font_color",
		UISkin.GOLD_PALE if sure else UISkin.PENDING)
	# One word whatever is on the page. "Transform into Ladder" said the player would become
	# a ladder, which is not what drawing an object does -- and it ran off the button. The
	# guess line above already names what it sees.
	transform_button.text = "Paint"


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


## The paper is an oval, but the SubViewport that receives pointer input used to be a
## 400x400 square centred inside its 568x568 frame. The uncovered left, right, top and
## bottom of the paper looked drawable and were not. Give the viewport the frame's whole
## footprint, then let DrawingCanvas reject only points outside the actual oval opening.
##
## The cream paper is drawn by CanvasPaper behind this transparent viewport. Keeping the
## viewport transparent prevents its rectangular background from showing around the oval;
## SketchClient flattens the captured ink onto paper before sending or storing it.
func _configure_canvas_surface() -> void:
	var surface_size := canvas_frame.size
	canvas_viewport_container.position = canvas_frame.position
	canvas_viewport_container.size = surface_size
	canvas_viewport_container.custom_minimum_size = surface_size
	# With stretch enabled the container owns the child viewport's size. Assigning it here
	# would be rejected by Godot; resizing the container updates the viewport automatically.
	canvas_viewport.transparent_bg = true
	var viewport_paper := canvas_viewport.get_node_or_null("Paper") as CanvasItem
	if viewport_paper != null:
		viewport_paper.visible = false
	# The container and frame now share an origin, so the frame's opening is already in the
	# canvas coordinate system. This is the full visible sheet minus the moulding safety rim.
	canvas.call(&"set_drawable_bounds", canvas_frame.opening())


## THE BRUSH STANDS BESIDE THE PAGE. Kent: "the ink bar is at the top whenever i am opening
## the canvas, and its too small ... make it vertical and it should be beside the canvas or
## keep it horizontal but bigger". It was a 158 x 22 strip squeezed above the oval at two screen
## pixels to the art pixel, and nothing bigger fits there -- the oval's gilt top is in the way.
## Beside the page there is room for three times that. So the same brush, stood bristles-up
## like a brush in a jar (InkBrush.vertical): the gold drains downward the way a level does,
## and the bristles still go dry first. INK over it, how much is left under it, and all three
## in the same soft container the level HUD keeps its brush in, so it reads over any scene.
const GAUGE_SCALE := 6
## THE BRUSH ANSWERS THE PEN. Kent: "whenever i draw, the ink is not dynamically affected like
## its not changing live". Since FR-7 a thing costs one unit however it is drawn, and the gauge
## was held still while a stroke was down -- true, and dead to the hand. So the drawing on the
## page now shows on the brush as it goes: the gold it is taking turns to the claimed colour,
## from the bristles down, growing with the stroke as the page fills -- and a full page is one
## whole unit, never more, because one unit is what a drawing costs. Nothing is spent: Clear
## gives it back, and Paint settles it as the economy says. Eased, never jumping.
const CLAIM_EASE := 10.0
const GAUGE_GAP := 34.0
const GAUGE_PAD := Vector2(26.0, 14.0)


## DRAW over the page; the brush, its name and its count beside it.
func _build_header() -> void:
	var caption := Label.new()
	caption.name = "Caption"
	caption.text = "DRAW"
	caption.theme_type_variation = &"HudCaption"
	caption.position = Vector2(86.0, 26.0)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_root.add_child(caption)

	# It is the SAME OBJECT the level HUD shows, on purpose: the thing draining while you draw
	# is the thing you took off the stand in the house.
	var page := Rect2(canvas_frame.position, canvas_frame.size)
	_ink_gauge = InkBrush.new()
	_ink_gauge.name = "InkGauge"
	_ink_gauge.vertical = true
	_ink_gauge.size = InkBrush.size_at(GAUGE_SCALE, true)
	_ink_gauge.position = Vector2(page.end.x + GAUGE_GAP,
		roundf(page.get_center().y - _ink_gauge.size.y * 0.5))
	panel_root.add_child(_ink_gauge)
	var column := Rect2(_ink_gauge.position.x - 40.0, 0.0, _ink_gauge.size.x + 80.0, 0.0)
	var holder := Panel.new()
	holder.name = "InkHolder"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_theme_stylebox_override(&"panel", UISkin.frame())
	holder.position = _ink_gauge.position - Vector2(GAUGE_PAD.x, 40.0 + GAUGE_PAD.y)
	holder.size = _ink_gauge.size + Vector2(GAUGE_PAD.x * 2.0, 40.0 + 12.0 + 28.0 + GAUGE_PAD.y * 2.0)
	panel_root.add_child(holder)
	# Behind the brush, which was added first.
	panel_root.move_child(holder, _ink_gauge.get_index())

	var heading := Label.new()
	heading.name = "InkCaption"
	heading.text = "INK"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.theme_type_variation = &"HudCaption"
	heading.position = Vector2(column.position.x, _ink_gauge.position.y - 40.0)
	heading.size = Vector2(column.size.x, 28.0)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_root.add_child(heading)

	_ink_value = Label.new()
	_ink_value.name = "InkValue"
	_ink_value.text = ""
	_ink_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ink_value.theme_type_variation = &"HudValue"
	_ink_value.position = Vector2(column.position.x, _ink_gauge.position.y + _ink_gauge.size.y + 12.0)
	_ink_value.size = Vector2(column.size.x, 28.0)
	_ink_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_root.add_child(_ink_value)


func _ease_the_claim(delta: float) -> void:
	if is_equal_approx(_claim_shown, _claim):
		return
	_claim_shown = lerpf(_claim_shown, _claim, 1.0 - exp(-CLAIM_EASE * delta))
	if absf(_claim_shown - _claim) < 0.002:
		_claim_shown = _claim
	_refresh_ink_row()


## Keep the gauge honest while the player draws: what is left, and -- out of that, from the
## bristles down -- what the drawing on the page is taking.
func _refresh_ink_row() -> void:
	if _ink_gauge == null or ink_manager == null:
		return
	var left := ink_manager.remaining()
	var taking := clampf(_claim_shown, 0.0, left)
	_ink_gauge.capacity = ink_manager.capacity
	_ink_gauge.remaining = left - taking
	_ink_gauge.reserved = taking
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
	transform_button.text = "Paint"


func _on_transform_pressed() -> void:
	if _submitting:
		return
	if _refusing:
		_refuse_quietly()
		return
	_submitting = true
	transform_button.disabled = true
	clear_button.disabled = true
	status.text = "Recognizing..."
	_submit_started_usec = Time.get_ticks_usec()
	# Capture the stroke vectors alongside the rasterized image so the rig can
	# animate the actual drawn lines.
	_pending_strokes = canvas.get_strokes()
	# ⚠ NOTHING IS RESERVED HERE ANY MORE, and refusing here would be wrong.
	#
	# Under the old length-based economy the page itself cost ink, so a submission could be
	# priced before anybody knew what it was. Under FR-7 the price depends entirely on the
	# ANSWER: a creature transformation is free, a tool already in the belt is free, a
	# declined drawing is free, and only a new tool or a placement is a unit. Turning the
	# player away at the button would refuse them the three free cases as well -- including
	# the one a player with an empty gauge most needs, which is becoming something.
	#
	# So the charge happens where the outcome is known: LevelBase, on acquisition and on
	# each placement, through InkManager.spend_unit, which refuses on its own when empty.
	if ink_manager != null:
		ink_manager.release_attempt()
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
		_profile.record_class_drawing(entity, drawing)
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
	# Which half of the dual gate refused it -- asked of the client, which holds the level's
	# thresholds, rather than of a literal that would drift from them.
	var reason := String(client.decline_reason(confidence, margin))
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
	if _refusing:
		# Nothing will be taken for it, so the brush shows nothing going.
		return
	# Nothing is spent while a stroke is down -- a unit goes when a thing is acquired or set
	# down -- but the brush shows what this drawing is taking. See CLAIM_EASE.
	_claim = InkManager.UNIT * clampf(cost / PAGE_ALLOWANCE, 0.0, 1.0)
	# The status line no longer recites the ink. It used to read "Ink remaining 10.7 / 12.0
	# -- attempt 1.3" on every stroke point, which is the header gauge's job now, said in
	# decimals, over the top of whatever the panel had last told the player. This line is
	# for messages; the gauge is for the budget.


func _on_ink_blocked() -> void:
	if _refusing:
		return
	status.text = "Ink limit reached — transform or clear"


## Called by UIRouter, ahead of the pause menu in the cancel chain. Mid-submission the
## panel declines rather than closing: the drawing is already with the recogniser and
## the ink is reserved, so tearing the panel down there would strand the transaction.
## Declining lets the key fall through to the pause menu, which is the honest result.
func handle_cancel() -> bool:
	if not _is_open or _submitting:
		return false
	if _refusing:
		# Putting the brush down is trying too.
		_refuse_quietly()
		return true
	canvas.clear_canvas()
	close_panel(true, true)
	return true


## The lines fade to the bare page, and the page closes. Nothing is sent and nothing is said.
func _refuse_quietly() -> void:
	_submitting = true
	transform_button.disabled = true
	clear_button.disabled = true
	var strokes: int = canvas.get_strokes().size()
	# ⚠ ALWAYS RUNS. The panel processes only while the tree is paused, and a refusal must not
	# hang on the page if anything unpauses it mid-fade.
	var fade := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(canvas, "modulate:a", 0.0, REFUSAL_FADE)
	await fade.finished
	canvas.clear_canvas()
	canvas.modulate.a = 1.0
	close_panel(true, true)
	quietly_refused.emit(strokes)


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
	# In held frames, like every other motion (Motion.step): the canvas pops in pixel-art steps.
	Motion.step(_open_tween, scrim, "modulate:a", 1.0, 0.34, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	Motion.step(_open_tween, panel_root, "modulate", Color.WHITE, 0.28, Tween.TRANS_CUBIC, Tween.EASE_OUT, 0.06)
	Motion.step(_open_tween, panel_root, "scale", Vector2.ONE, OPEN_DURATION, Tween.TRANS_BACK, Tween.EASE_OUT, 0.03)
	if _scrim_material != null:
		Motion.step(_open_tween, _scrim_material, "shader_parameter/opening_burst", 0.0, 0.92,
			Tween.TRANS_QUINT, Tween.EASE_OUT)
