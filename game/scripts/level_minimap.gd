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

var _view: SubViewport
var _locate: Callable
var _region: Callable
var _explored: Dictionary = {}
var _centre := Vector2.ZERO
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
	_centre = location
	var bounds: Rect2 = _region.call() if _region.is_valid() else Rect2()
	# Rooms are parked away from the exterior. Keep their own scale, while an outdoor map
	# stays at one scale even on Mayon's vertical climb or Dagat's long crossing.
	_span = clampf(maxf(bounds.size.x, bounds.size.y) + 160.0, 800.0, WORLD_SPAN) \
		if bounds.has_area() else WORLD_SPAN
	_reveal(_centre, _span * 0.38)
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


func is_explored(point: Vector2) -> bool:
	return _explored.has(_cell_at(point))


func world_rect() -> Rect2:
	return Rect2(_centre - Vector2.ONE * _span * 0.5, Vector2.ONE * _span)


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
	# A bright, outlined player pin survives every terrain palette and every current morph.
	var pin := (area.get_center() - Vector2(3.0, 5.0)).round()
	draw_rect(Rect2(pin - Vector2.ONE * 2.0, Vector2(10.0, 14.0)), UISkin.INK)
	draw_rect(Rect2(pin, Vector2(6.0, 10.0)), UISkin.GOLD)
	draw_rect(Rect2(pin, Vector2(6.0, 4.0)), UISkin.CREAM_TEXT)
