class_name ObjectiveMarker
extends Control
## WHERE THE OBJECTIVE IS, drawn over the world.
##
## The banner says what to do; this says where. A bobbing gold chevron over the thing itself
## while it is on screen, and an arrow at the edge of the frame pointing toward it while it is
## not. Payyo had a distance in the corner -- "GOAL 141 m" -- which says how far and not which
## way, and counts down to a house the level does not end at. Piyesta had nothing at all, in a
## level that is four doors, a church, two alleys and a table.
##
## ⚠ IT DRAWS NOTHING WHEN THE PLAYER IS ALREADY THERE. A marker hovering over the apo's head
## while they stand at the right door is the game failing to notice they arrived.

## How far in from the edge an off-screen arrow sits.
const EDGE := 46.0
## The HUD's bands: the ink plate and badge along the top, the bag and the verbs along the
## bottom. An arrow is kept between them so it never lands on a readout.
const TOP_BAND := 120.0
const BOTTOM_BAND := 104.0
## Close enough to count as there, in world units. A BOX, NOT A RADIUS: targets are pointed
## at from above -- over a door's hood, over a candle -- so a player standing right at one is
## still two hundred units from the point, and a radius either never arrives or arrives from
## across the room.
const ARRIVED := Vector2(80.0, 300.0)

const OUTLINE := Color(0.027, 0.035, 0.024, 0.9)

var _target := Vector2.INF
var _player: Node2D = null
var _time := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func point_at(world: Vector2, player: Node2D) -> void:
	_target = world
	_player = player


func clear() -> void:
	if _target == Vector2.INF:
		return
	_target = Vector2.INF
	queue_redraw()


func has_target() -> bool:
	return _target != Vector2.INF


func target() -> Vector2:
	return _target


## Where the target is on the screen right now, in this control's space. The world is drawn
## through the camera's canvas transform; this control is on a CanvasLayer that is not.
func screen_point() -> Vector2:
	return get_viewport().get_canvas_transform() * _target


## True while the target is inside the part of the frame an on-screen chevron may use.
func on_screen() -> bool:
	return _inner().has_point(screen_point())


## Whether anything is being drawn this frame -- false when the player is already standing
## at the target, which is the case a probe most needs to tell apart from "no target".
func showing() -> bool:
	return has_target() and not _arrived()


func _process(delta: float) -> void:
	_time += delta
	if has_target():
		queue_redraw()


func _arrived() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	var apart := _player.global_position - _target
	return absf(apart.x) < ARRIVED.x and absf(apart.y) < ARRIVED.y


func _inner() -> Rect2:
	var view := get_viewport_rect().size
	return Rect2(EDGE, TOP_BAND, view.x - EDGE * 2.0, view.y - TOP_BAND - BOTTOM_BAND)


func _draw() -> void:
	if not showing():
		return
	var at := screen_point()
	var inner := _inner()
	var bob := sin(_time * 4.2) * 5.0
	if inner.has_point(at):
		_draw_arrow(at + Vector2(0.0, -16.0 + bob), Vector2.DOWN, 20.0)
		return
	var centre := inner.get_center()
	var toward := (at - centre).normalized()
	_draw_arrow(_edge_of(inner, centre, toward) + toward * bob * 0.6, toward, 21.0)


## Where a ray from the middle of the frame leaves the inner rect.
func _edge_of(rect: Rect2, from: Vector2, toward: Vector2) -> Vector2:
	var best := INF
	if absf(toward.x) > 0.0001:
		for x: float in [rect.position.x, rect.end.x]:
			var t := (x - from.x) / toward.x
			if t > 0.0:
				best = minf(best, t)
	if absf(toward.y) > 0.0001:
		for y: float in [rect.position.y, rect.end.y]:
			var t := (y - from.y) / toward.y
			if t > 0.0:
				best = minf(best, t)
	return from + toward * (best if best != INF else 0.0)


## A gold arrowhead with a dark keyline, so it reads on sky, on plaster and on shadow alike.
func _draw_arrow(tip: Vector2, toward: Vector2, size: float) -> void:
	var across := Vector2(-toward.y, toward.x)
	var back := tip - toward * size * 1.2
	var points := PackedVector2Array([tip, back + across * size, back - across * size])
	var outline := PackedVector2Array([tip + toward * 3.0,
		back + across * (size + 3.5) - toward * 2.0, back - across * (size + 3.5) - toward * 2.0])
	draw_colored_polygon(outline, OUTLINE)
	draw_colored_polygon(points, UISkin.GOLD)
	draw_line(tip, back + across * size, Color(1.0, 0.92, 0.66, 1.0), 2.0)
