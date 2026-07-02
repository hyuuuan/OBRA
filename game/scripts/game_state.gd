extends Node
## Tiny handoff store between the drawing screen and game scene.

var pending_entity: String = ""
var pending_display_name: String = ""
var pending_drawing: Image = null
var pending_response: Dictionary = {}


func set_pending_prediction(
	entity: String,
	display_name: String,
	drawing: Image,
	response: Dictionary
) -> void:
	pending_entity = entity
	pending_display_name = display_name
	pending_drawing = drawing
	pending_response = response


func clear_pending() -> void:
	pending_entity = ""
	pending_display_name = ""
	pending_drawing = null
	pending_response = {}

