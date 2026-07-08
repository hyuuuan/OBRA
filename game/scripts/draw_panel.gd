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

@onready var canvas_viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var canvas: Control = $SubViewportContainer/SubViewport/Canvas
@onready var transform_button: Button = $TransformButton
@onready var clear_button: Button = $ClearButton
@onready var status: Label = $StatusLabel
@onready var client: Node = $SketchClient


var _pending_strokes: Array = []


func _ready() -> void:
	client.canvas_viewport = canvas_viewport
	transform_button.pressed.connect(_on_transform_pressed)
	clear_button.pressed.connect(canvas.clear_canvas)
	client.entity_prediction_received.connect(_on_entity_prediction)
	client.prediction_failed.connect(_on_prediction_failed)
	status.text = "Draw something, then Transform!"


func _on_transform_pressed() -> void:
	# Capture the stroke vectors alongside the rasterized image so the rig can
	# animate the actual drawn lines.
	_pending_strokes = canvas.get_strokes()
	client.send_drawing()


func _on_entity_prediction(
	entity: String,
	display_name: String,
	confidence: float,
	drawing: Image,
	response: Dictionary
) -> void:
	status.text = "%s %.0f%%" % [display_name, confidence * 100.0]
	drawing_ready.emit(entity, display_name, drawing, response, _pending_strokes)


func _on_prediction_failed(message: String) -> void:
	status.text = message
