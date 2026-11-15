extends "res://scripts/piyesta_room_2d.gd"
## The supplied sunset market frames, registered to the existing Alley 2 floor.
## Only the occupied room advances; dialogue and menus pause the market with the world.
const FRAMES := [
	preload("res://assets/Level2/alley_2/market_01.png"),
	preload("res://assets/Level2/alley_2/market_02.png"),
	preload("res://assets/Level2/alley_2/market_03.png"),
	preload("res://assets/Level2/alley_2/market_04.png"),
]
const FRAME_SECONDS := 0.45
## Frame 1 is one column narrower. Sample the common width without stretching any frame.
const ART_WIDTH := 1684.0
const WALK_ROW := 790.0
## Frame the market below the decorative overhead banners (which end at source row 340).
## The existing live, cuttable line remains the only bunting visible above the flock.
const SOURCE_TOP := 350.0
const SOURCE_HEIGHT := 584.0

var _animation_clock := 0.0
var _frame := 0


func _process(delta: float) -> void:
	super(delta)
	if not visible:
		return
	_animation_clock = fmod(_animation_clock + delta, FRAME_SECONDS * FRAMES.size())
	var next_frame := int(_animation_clock / FRAME_SECONDS)
	if next_frame != _frame:
		_frame = next_frame
		queue_redraw()


func camera_rect() -> Rect2:
	return Rect2(global_position + market_art_rect().position, market_art_rect().size)


func how_far_in() -> float:
	return maxf(room_zoom, get_viewport_rect().size.x / ART_WIDTH)


func market_art_rect() -> Rect2:
	return Rect2(-ART_WIDTH * 0.5, SOURCE_TOP - WALK_ROW, ART_WIDTH, SOURCE_HEIGHT)


func animation_frame() -> int:
	return _frame


func _draw() -> void:
	# Native pixels and a stable rect keep the architecture still as the shoppers move.
	draw_texture_rect_region(FRAMES[_frame], market_art_rect(),
		Rect2(0.0, SOURCE_TOP, ART_WIDTH, SOURCE_HEIGHT))
	_draw_way_marker(exit_rect(), -1.0, true)
	_draw_way_marker(onward_rect(), 1.0, onward_open)
