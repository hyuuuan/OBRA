class_name LevelMinimap
extends PanelContainer
## A second, low-resolution view of the existing world, with explored cells kept for this run.
## Sharing World2D renders the actual terrain and placed drawings without copying gameplay.
## CanvasLayers belong to the main viewport, so neither the HUD nor modals enter this view.

const SIDE := 256.0
const INSET := 6.0
const RESOLUTION := 122
const WORLD_SPAN := 2400.0
const CELL := 48.0
const REFRESH_SECONDS := 0.1
## How much of a room the map shows across, at most: the heap is painted two thousand units
## long, and fitted whole into the square it was a thin strip. Narrower rooms are shown whole.
const ROOM_SPAN := 900.0
## The ink left round a room that fits, so its walls do not sit on the frame.
const ROOM_MARGIN := 24.0

var _view: SubViewport
var _locate: Callable
var _region: Callable
var _explored: Dictionary = {}
## The middle of what the map shows, and where the pin is. The same point outdoors; inside a
## room the view keeps to the room and the pin goes where she is in it.
var _centre := Vector2.ZERO
var _marked := Vector2.ZERO
## ⚠ THE ROOM SHE IS IN, AND THE MAP SHOWS NOTHING ELSE. Kent: "the minimap inside the haybale
## looks so weird, i can clearly see that this is just above level 1". The map is a second view
## of the same world, and every interior is parked in the sky over its level -- so a view
## centred on her showed the heap as a strip with Payyo's sky and terraces round it. Everything
## outside this box is inked over. Empty outdoors.
var _room := Rect2()
var _span := WORLD_SPAN
var _elapsed := REFRESH_SECONDS
var _has_player := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2.ONE * SIDE
	add_theme_stylebox_override(&"panel", UISkin.frame(INSET, INSET))


func bind(world: World2D, locate: Callable, region: Callable) -> void:
	_locate = locate
	_region = region
	_view = SubViewport.new()
	_view.name = "MapView"
	_view.size = Vector2i.ONE * RESOLUTION
	_view.disable_3d = true
	_view.transparent_bg = true
	_view.gui_disable_input = true
	_view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_view.world_2d = world
	add_child(_view)


func _process(delta: float) -> void:
	if _view == null or not is_visible_in_tree() or modulate.a <= 0.01:
		return
	_elapsed += delta
	if _elapsed < REFRESH_SECONDS:
		return
	_elapsed = 0.0
	refresh()


func refresh() -> void:
	if not _locate.is_valid() or _view == null:
		return
	var location: Variant = _locate.call()
	_has_player = location is Vector2
	if not _has_player:
		queue_redraw()
		return
	_marked = location
	_centre = location
	var bounds: Rect2 = _region.call() if _region.is_valid() else Rect2()
	_room = bounds if bounds.has_area() else Rect2()
	# An outdoor map stays at one scale even on Mayon's vertical climb or Dagat's long
	# crossing. A room is shown at its own: all of its height, and as much of its length as
	# fits, held inside it as she walks so the view never runs off its end into the sky.
	_span = WORLD_SPAN
	if _room.has_area():
		_span = minf(maxf(_room.size.y, minf(_room.size.x, ROOM_SPAN)) + ROOM_MARGIN * 2.0,
			WORLD_SPAN)
		var inner := _span * 0.5 - ROOM_MARGIN
		_centre = Vector2(
			clampf(_marked.x, _room.position.x + inner, _room.end.x - inner)
				if _room.size.x > inner * 2.0 else _room.get_center().x,
			_room.get_center().y)
		# A room is one place she is standing in, so it is on the map whole. Fog cut round her
		# made Ang Bale a corner of a picture and the heap a ragged blob, both ink to the side.
		_reveal_rect(_room)
	else:
		_reveal(_marked, _span * 0.38)
	# Set this viewport's transform directly: a second Camera2D must never take control of
	# the gameplay camera or change its zoom, focus, room clamp, or audio listener.
	var map_scale := float(RESOLUTION) / _span
	_view.canvas_transform = Transform2D(0.0, Vector2.ONE * map_scale, 0.0,
		Vector2.ONE * (RESOLUTION * 0.5) - _centre * map_scale)
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	queue_redraw()


func _cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.y / CELL))


func _reveal(point: Vector2, radius: float) -> void:
	var cell := _cell_at(point)
	var reach := ceili(radius / CELL)
	for y in range(cell.y - reach, cell.y + reach + 1):
		for x in range(cell.x - reach, cell.x + reach + 1):
			var key := Vector2i(x, y)
			if (Vector2(key) * CELL + Vector2.ONE * CELL * 0.5).distance_to(point) <= radius:
				_explored[key] = true


func _reveal_rect(rect: Rect2) -> void:
	var first := _cell_at(rect.position)
	var last := _cell_at(rect.end)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			_explored[Vector2i(x, y)] = true


func is_explored(point: Vector2) -> bool:
	return _explored.has(_cell_at(point))


func world_rect() -> Rect2:
	return Rect2(_centre - Vector2.ONE * _span * 0.5, Vector2.ONE * _span)


## The world point the pin marks: where she is, or Vector2.INF with nobody to mark.
func marked() -> Vector2:
	return _marked if _has_player else Vector2.INF


## Whether a world point is drawn on the map: in view, explored, and inside the room she is in,
## when she is in one.
func shows(point: Vector2) -> bool:
	return _has_player and world_rect().has_point(point) and is_explored(point) \
		and (not _room.has_area() or _room.has_point(point))


func _draw() -> void:
	var area := Rect2(Vector2.ONE * INSET, size - Vector2.ONE * INSET * 2.0)
	draw_rect(area, UISkin.INK)
	if _view == null or not _has_player:
		return
	draw_texture_rect(_view.get_texture(), area, false)
	var world := world_rect()
	var first := _cell_at(world.position)
	var last := _cell_at(world.end)
	var ratio := area.size.x / _span
	# Whole map pixels and clipped edges keep the fog inside the square's frame.
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			if _explored.has(Vector2i(x, y)):
				continue
			var start := (area.position + (Vector2(x, y) * CELL - world.position) * ratio).floor()
			var end := (area.position + (Vector2(x + 1, y + 1) * CELL - world.position) * ratio).ceil()
			draw_rect(Rect2(start, end - start).intersection(area), UISkin.INK)
	if _room.has_area():
		_ink_outside(area, Rect2(
			(area.position + (_room.position - world.position) * ratio).floor(),
			(_room.size * ratio).ceil()).intersection(area))
	# A bright, outlined player pin survives every terrain palette and every current morph.
	var at := area.position + (_marked - world.position) * ratio
	var pin := (at.clamp(area.position, area.end) - Vector2(3.0, 5.0)).round()
	draw_rect(Rect2(pin - Vector2.ONE * 2.0, Vector2(10.0, 14.0)), UISkin.INK)
	draw_rect(Rect2(pin, Vector2(6.0, 10.0)), UISkin.GOLD)
	draw_rect(Rect2(pin, Vector2(6.0, 4.0)), UISkin.CREAM_TEXT)


## Ink over the map everywhere but `keep`: the four bands round it, inside `area`.
func _ink_outside(area: Rect2, keep: Rect2) -> void:
	if not keep.has_area():
		draw_rect(area, UISkin.INK)
		return
	draw_rect(Rect2(area.position, Vector2(area.size.x, keep.position.y - area.position.y)),
		UISkin.INK)
	draw_rect(Rect2(area.position.x, keep.end.y, area.size.x, area.end.y - keep.end.y), UISkin.INK)
	draw_rect(Rect2(area.position.x, keep.position.y, keep.position.x - area.position.x,
		keep.size.y), UISkin.INK)
	draw_rect(Rect2(keep.end.x, keep.position.y, area.end.x - keep.end.x, keep.size.y), UISkin.INK)
