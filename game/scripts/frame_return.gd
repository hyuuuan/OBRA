class_name FrameReturn
extends CanvasLayer
## THE FRAME RETURNS (LEVEL_5.md): cut out of the painting, the apo is sitting with lola in the
## real world, where she has presumably been the whole time. A window, a chair, a canvas with the
## unfinished Mayon on it -- and lola, who does not know her.
##
## A PLACEHOLDER ROOM, drawn here until the art team's arrives (ART_PLACEHOLDERS.md): a wall, a
## window onto Mayon's sky, the easel, and the two of them seated -- the apo's own sprite and
## lola's stand-in. Under the dialogue box (layer 8) and the bars (9), over the HUD.

const LAYER := 7
const WALL := Color(0.29, 0.22, 0.18)
const FLOOR := Color(0.2, 0.15, 0.12)
const WOOD := Color(0.36, 0.24, 0.15)
const SKY := preload("res://assets/Level5/backdrop/sky.png")
const PAINTING := preload("res://assets/hub/paintings/level_5.png")
const LOLA := preload("res://assets/Level5/people/lola_front.png")
const APO := preload("res://assets/characters/apo/apo_turnaround.png")
## How long the black holds at the very end.
const BLACK_HOLD := 3.0

var _black: ColorRect
var _room: Control


func _ready() -> void:
	layer = LAYER
	_room = Control.new()
	_room.name = "Room"
	_room.set_anchors_preset(Control.PRESET_FULL_RECT)
	_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_room.draw.connect(_draw_room)
	add_child(_room)
	_black = ColorRect.new()
	_black.name = "Black"
	_black.color = Color(0, 0, 0, 0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	# In from white: out of the painting, which had gone to paper.
	_room.modulate = Color(3.0, 3.0, 3.0, 1.0)
	create_tween().tween_property(_room, "modulate", Color.WHITE, 1.6)


## Cut to black, and hold.
func cut_to_black() -> void:
	_black.color.a = 1.0
	await get_tree().create_timer(BLACK_HOLD, true).timeout


func is_black() -> bool:
	return _black.color.a >= 1.0


func _draw_room() -> void:
	var size := _room.size
	_room.draw_rect(Rect2(Vector2.ZERO, size), WALL)
	_room.draw_rect(Rect2(0.0, size.y * 0.72, size.x, size.y * 0.28), FLOOR)
	# The window, onto the evening.
	var window := Rect2(size.x * 0.08, size.y * 0.14, size.x * 0.24, size.y * 0.32)
	_room.draw_texture_rect_region(SKY, window, Rect2(300, 200, 700, 400))
	_room.draw_rect(window, WOOD, false, 8.0)
	# The easel and the unfinished Mayon.
	var easel := Vector2(size.x * 0.72, size.y * 0.72)
	_room.draw_line(easel + Vector2(-60, 0), easel + Vector2(0, -300), WOOD, 8.0)
	_room.draw_line(easel + Vector2(60, 0), easel + Vector2(0, -300), WOOD, 8.0)
	var canvas := Rect2(easel + Vector2(-150, -330), Vector2(300, 170))
	_room.draw_rect(canvas.grow(6.0), WOOD)
	_room.draw_rect(canvas, Color(0.96, 0.94, 0.89))
	_room.draw_texture_rect(PAINTING, Rect2(canvas.position, Vector2(canvas.size.x * 0.55, canvas.size.y)), false,
		Color(1, 1, 1, 0.85))
	# The two of them, seated.
	_room.draw_rect(Rect2(size.x * 0.38, size.y * 0.6, size.x * 0.11, size.y * 0.04), WOOD)
	_room.draw_texture_rect(LOLA, Rect2(size.x * 0.385, size.y * 0.33, 80 * 3.2, 106 * 3.2) , false)
	_room.draw_texture_rect_region(APO, Rect2(size.x * 0.53, size.y * 0.42, 80 * 2.6, 106 * 2.6),
		Rect2(0, 0, 80, 106))
