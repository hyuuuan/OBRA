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
