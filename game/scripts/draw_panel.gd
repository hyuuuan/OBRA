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

@export var debug_timing_logs: bool = false

var ink_manager: InkManager

@onready var scrim: ColorRect = $Scrim
@onready var panel_root: Control = $PanelRoot
@onready var canvas_viewport: SubViewport = $PanelRoot/SubViewportContainer/SubViewport
@onready var canvas: Control = $PanelRoot/SubViewportContainer/SubViewport/Canvas
@onready var transform_button: Button = $PanelRoot/TransformButton
@onready var clear_button: Button = $PanelRoot/ClearButton
@onready var status: Label = $PanelRoot/StatusLabel
@onready var client: Node = $PanelRoot/SketchClient


var _pending_strokes: Array = []
var _is_open := false
var _submitting := false
var _open_tween: Tween = null
var _submit_started_usec: int = 0
# Autoloads resolved through the tree so this class_name script compiles even when a
# tool precompiles it before the autoloads register. Untyped for dynamic dispatch.
var _telemetry
var _profile


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_telemetry = get_node_or_null("/root/Telemetry")
	_profile = get_node_or_null("/root/PlayerProfile")
	visible = false
	canvas_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	client.canvas_viewport = canvas_viewport
	client.set("debug_timing_logs", debug_timing_logs)
	transform_button.pressed.connect(_on_transform_pressed)
	clear_button.pressed.connect(_clear_canvas)
	canvas.stroke_cost_changed.connect(_on_stroke_cost_changed)
	canvas.ink_blocked.connect(_on_ink_blocked)
	client.entity_prediction_received.connect(_on_entity_prediction)
	client.entity_declined.connect(_on_entity_declined)
	client.prediction_failed.connect(_on_prediction_failed)
	status.text = "Draw something, then Transform!"


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
	if ink_manager != null:
		canvas.set_ink_budget(ink_manager.total_uncommitted_available(), ink_manager.canvas_size)
		status.text = "Ink remaining %.1f / %.1f — draw, then Transform" % [ink_manager.remaining(), ink_manager.capacity]
	else:
		status.text = "Draw something, then Transform!"
	get_tree().paused = true
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
	canvas_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if release_ink and ink_manager != null:
		ink_manager.release_attempt()
	get_tree().paused = false
	if emit_closed:
		panel_closed.emit()


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
	if ink_manager != null:
		ink_manager.release_attempt()


func _on_stroke_cost_changed(cost: float) -> void:
	# Clearing the hidden canvas after a successful prediction must not replace
	# the pending utility reservation with zero before placement/storage commits.
	if not _is_open:
		return
	if ink_manager != null:
		ink_manager.reserve_attempt(cost)
		status.text = "Ink remaining %.1f / %.1f — attempt %.1f" % [ink_manager.remaining(), ink_manager.capacity, cost]
	else:
		status.text = "Ink used: %.1f diagonals" % cost


func _on_ink_blocked() -> void:
	status.text = "Ink limit reached — transform or clear"


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed("ui_cancel") and not _submitting:
		get_viewport().set_input_as_handled()
		canvas.clear_canvas()
		close_panel(true, true)


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
