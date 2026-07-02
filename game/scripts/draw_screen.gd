extends Control

@onready var canvas_viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var canvas: Control = $SubViewportContainer/SubViewport/Canvas
@onready var transform_button: Button = $TransformButton
@onready var clear_button: Button = $ClearButton
@onready var status: Label = $StatusLabel
@onready var client: Node = $SketchClient


func _ready() -> void:
	client.canvas_viewport = canvas_viewport
	transform_button.pressed.connect(client.send_drawing)
	clear_button.pressed.connect(canvas.clear_canvas)
	client.entity_prediction_received.connect(_on_entity_prediction)
	client.prediction_failed.connect(_on_prediction_failed)
	status.text = "Ready"


func _on_entity_prediction(
	entity: String,
	display_name: String,
	confidence: float,
	drawing: Image,
	response: Dictionary
) -> void:
	status.text = "%s %.0f%%" % [display_name, confidence * 100.0]
	GameState.set_pending_prediction(entity, display_name, drawing, response)
	get_tree().change_scene_to_file("res://game_level.tscn")


func _on_prediction_failed(message: String) -> void:
	status.text = message

