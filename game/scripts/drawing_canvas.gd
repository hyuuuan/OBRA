extends Control
## Freehand drawing canvas. Attach to a Control that fills a SubViewport
## (with a white ColorRect behind it as the background).

@export var stroke_color: Color = Color.BLACK
@export var stroke_width: float = 8.0
@export var min_point_spacing: float = 2.0

var _current_line: Line2D


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_stroke(event.position)
		else:
			_append_point(event.position, true)
			_current_line = null
	elif event is InputEventMouseMotion and _current_line != null:
		_append_point(event.position)


func _start_stroke(at: Vector2) -> void:
	_current_line = Line2D.new()
	_current_line.default_color = stroke_color
	_current_line.width = stroke_width
	_current_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_current_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_current_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_append_point(at, true)
	add_child(_current_line)


func _append_point(at: Vector2, force: bool = false) -> void:
	if _current_line == null:
		return
	var count := _current_line.get_point_count()
	if count == 0:
		_current_line.add_point(at)
		return

	var last := _current_line.get_point_position(count - 1)
	var distance_sq := last.distance_squared_to(at)
	if force:
		if distance_sq > 0.01:
			_current_line.add_point(at)
		return

	var min_spacing_sq := min_point_spacing * min_point_spacing
	if distance_sq >= min_spacing_sq:
		_current_line.add_point(at)


func clear_canvas() -> void:
	_current_line = null
	for child in get_children():
		if child is Line2D:
			child.queue_free()


## Returns the drawn strokes as raw polylines so the rig can animate the
## player's actual ink instead of a flattened bitmap.
func get_strokes() -> Array:
	var strokes: Array = []
	for child in get_children():
		if child is Line2D and child.get_point_count() > 0:
			strokes.append({
				"points": child.points.duplicate(),
				"width": child.width,
				"color": child.default_color
			})
	return strokes
