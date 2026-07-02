extends Control
## Freehand drawing canvas. Attach to a Control that fills a SubViewport
## (with a white ColorRect behind it as the background).

@export var stroke_color: Color = Color.BLACK
@export var stroke_width: float = 8.0

var _current_line: Line2D


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_stroke(event.position)
		else:
			_current_line = null
	elif event is InputEventMouseMotion and _current_line != null:
		_current_line.add_point(event.position)


func _start_stroke(at: Vector2) -> void:
	_current_line = Line2D.new()
	_current_line.default_color = stroke_color
	_current_line.width = stroke_width
	_current_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_current_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_current_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_current_line.add_point(at)
	add_child(_current_line)


func clear_canvas() -> void:
	_current_line = null
	for child in get_children():
		if child is Line2D:
			child.queue_free()
