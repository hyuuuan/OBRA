extends Control
## Freehand drawing canvas. Attach to a Control that fills a SubViewport
## (with a white ColorRect behind it as the background).

signal stroke_cost_changed(cost: float)
signal ink_blocked

@export var stroke_color: Color = Color.BLACK
@export var stroke_width: float = 8.0
@export var min_point_spacing: float = 2.0

var _current_line: Line2D
var _drawn_length: float = 0.0
var _max_length: float = INF
var _cost_diagonal: float = Vector2(512.0, 512.0).length()
var _blocked_emitted := false


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
	if _drawn_length >= _max_length - 0.001:
		_emit_blocked_once()
		return
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
	var distance := last.distance_to(at)
	if force:
		if distance > 0.1:
			_append_budgeted_point(last, at, distance)
		return

	var min_spacing_sq := min_point_spacing * min_point_spacing
	if distance * distance >= min_spacing_sq:
		_append_budgeted_point(last, at, distance)


func _append_budgeted_point(from: Vector2, to: Vector2, distance: float) -> void:
	var remaining := maxf(0.0, _max_length - _drawn_length)
	if remaining <= 0.001:
		_emit_blocked_once()
		return
	var accepted := minf(distance, remaining)
	var point := to
	if accepted < distance:
		point = from + (to - from) * (accepted / distance)
	_current_line.add_point(point)
	_drawn_length += accepted
	stroke_cost_changed.emit(get_current_cost())
	if accepted < distance or _drawn_length >= _max_length - 0.001:
		_emit_blocked_once()


func clear_canvas() -> void:
	_current_line = null
	_drawn_length = 0.0
	_blocked_emitted = false
	for child in get_children():
		if child is Line2D:
			child.queue_free()
	stroke_cost_changed.emit(0.0)


func set_ink_budget(ink_units: float, canvas_size: Vector2 = Vector2(512.0, 512.0)) -> void:
	_cost_diagonal = maxf(1.0, canvas_size.length())
	_max_length = maxf(0.0, ink_units) * _cost_diagonal
	_blocked_emitted = false


func get_current_cost() -> float:
	return _drawn_length / maxf(1.0, _cost_diagonal)


func get_drawn_length() -> float:
	return _drawn_length


func _emit_blocked_once() -> void:
	if _blocked_emitted:
		return
	_blocked_emitted = true
	ink_blocked.emit()


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
