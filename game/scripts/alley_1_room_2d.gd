extends "res://scripts/piyesta_room_2d.gd"
## The supplied Alley 1 plates dress the existing room shell. Floor, openings, flight
## space and transitions come from PiyestaRoom2D; these pixels add no collision.
const SKY := preload("res://assets/Level2/alley_1/sky.png")
const STORE := preload("res://assets/Level2/alley_1/store.png")
const GROUND := preload("res://assets/Level2/alley_1/ground.png")
const SOURCE_SIZE := Vector2(1448.0, 1086.0)
## One scale for both axes keeps the shop, roofs and cobbles at their source proportions.
const ART_SCALE := 0.65
const ART_WIDTH := SOURCE_SIZE.x * ART_SCALE
## The ground's walk row and the store's feet were authored at different heights.
## Register both to the live floor; the facades stand just behind the walking strip.
const GROUND_WALK_ROW := 895.0
const STORE_FOOT_ROW := 800.0
const FACADE_SETBACK := 14.0


func camera_rect() -> Rect2:
	return Rect2(global_position + Vector2(-ART_WIDTH * 0.5, -wall_height),
		Vector2(ART_WIDTH, wall_height + floor_depth))


func how_far_in() -> float:
	# Keep wide windows on the supplied plate too. This only changes framing, not the room.
	return maxf(room_zoom, get_viewport_rect().size.x / ART_WIDTH)


func ground_art_rect() -> Rect2:
	return Rect2(-ART_WIDTH * 0.5, -GROUND_WALK_ROW * ART_SCALE,
		ART_WIDTH, SOURCE_SIZE.y * ART_SCALE)


func _draw() -> void:
	var ground_rect := ground_art_rect()
	draw_texture_rect(SKY, ground_rect, false)
	draw_texture_rect(GROUND, ground_rect, false)
	var store_rect := ground_rect
	store_rect.position.y = -STORE_FOOT_ROW * ART_SCALE - FACADE_SETBACK
	draw_texture_rect(STORE, store_rect, false)
	# These are street exits, so mark the original transition areas on the walking lane
	# instead of painting the old masonry door frames over the sari-sari counter.
	_draw_way_marker(exit_rect(), -1.0, true)
	_draw_way_marker(onward_rect(), 1.0, onward_open)


func _draw_way_marker(reach: Rect2, direction: float, open: bool) -> void:
	var x := reach.get_center().x
	var wood := Color("70441f")
	var edge := Color("352317")
	var face := Color("c28b45")
	draw_rect(Rect2(x - 3.0, -68.0, 6.0, 62.0), edge)
	draw_rect(Rect2(x - 26.0, -84.0, 52.0, 26.0), edge)
	draw_rect(Rect2(x - 23.0, -81.0, 46.0, 20.0), face)
	var centre := Vector2(x, -71.0)
	draw_line(centre - Vector2(direction * 13.0, 0.0),
		centre + Vector2(direction * 13.0, 0.0), edge, 3.0)
	draw_polyline(PackedVector2Array([
		centre + Vector2(direction * 4.0, -7.0),
		centre + Vector2(direction * 13.0, 0.0),
		centre + Vector2(direction * 4.0, 7.0)]), edge, 3.0)
	if not open:
		for side in [-1.0, 1.0]:
			draw_rect(Rect2(x + side * 31.0 - 4.0, -53.0, 8.0, 48.0), edge)
		for y in [-48.0, -30.0, -12.0]:
			draw_rect(Rect2(x - 38.0, y, 76.0, 10.0), edge)
			draw_rect(Rect2(x - 36.0, y + 1.0, 72.0, 6.0), wood)
