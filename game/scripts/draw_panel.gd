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
	strokes: Array
)
signal panel_closed

@export var debug_timing_logs: bool = false

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


func _ready() -> void:
	visible = false
	client.canvas_viewport = canvas_viewport
	client.set("debug_timing_logs", debug_timing_logs)
	transform_button.pressed.connect(_on_transform_pressed)
	clear_button.pressed.connect(canvas.clear_canvas)
	client.entity_prediction_received.connect(_on_entity_prediction)
	client.prediction_failed.connect(_on_prediction_failed)
	status.text = "Draw something, then Transform!"


func open_panel() -> void:
	if _is_open:
		return
	_is_open = true
	_submitting = false
	client.set("debug_timing_logs", debug_timing_logs)
	visible = true
	transform_button.disabled = false
	clear_button.disabled = false
	status.text = "Draw something, then Transform!"
	_play_open_animation()


func close_panel(emit_closed: bool = true) -> void:
	if _open_tween != null:
		_open_tween.kill()
		_open_tween = null
	_is_open = false
	_submitting = false
	transform_button.disabled = false
	clear_button.disabled = false
	visible = false
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
	if debug_timing_logs and _submit_started_usec > 0:
		var total_ms := float(Time.get_ticks_usec() - _submit_started_usec) / 1000.0
		print("DrawPanel submit-to-prediction %.2f ms" % total_ms)
	drawing_ready.emit(entity, display_name, drawing, response, _pending_strokes)
	canvas.clear_canvas()
	close_panel()


func _on_prediction_failed(message: String) -> void:
	_submitting = false
	transform_button.disabled = false
	clear_button.disabled = false
	status.text = message


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
