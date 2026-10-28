class_name Lola2D
extends Node2D
## Lola at the summit: painting at her easel with her back turned, as she must have been for all
## of this, until she turns around (LEVEL_5.md, Act Three).
##
## Her sprites are placeholders (tools/build_mayon_lola.py, ART_PLACEHOLDERS.md). The easel is
## drawn here, and on it is the painting she is making: Mayon, the hub's own painting of it.

const BACK := preload("res://assets/Level5/people/lola_back.png")
const FRONT := preload("res://assets/Level5/people/lola_front.png")
const PAINTING := preload("res://assets/hub/paintings/level_5.png")
## An adult beside the apo.
const SCALE := 1.25
const WOOD := Color(0.36, 0.24, 0.15)

var _sprite: Sprite2D
var _turned := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite = Sprite2D.new()
	_sprite.name = "Lola"
	_sprite.texture = BACK
	_sprite.scale = Vector2(SCALE, SCALE)
	# Standing on the ground at her origin.
	_sprite.position = Vector2(0.0, -BACK.get_height() * SCALE * 0.5)
	add_child(_sprite)
	queue_redraw()


## She turns around.
func turn_around() -> void:
	_turned = true
	_sprite.texture = FRONT


## Back to her painting: for a checkpoint below the summit.
func face_the_painting() -> void:
	_turned = false
	_sprite.texture = BACK


func is_turned() -> bool:
	return _turned


func _draw() -> void:
	# The easel, ahead of her, and Mayon on it.
	var at := Vector2(70.0, 0.0)
	draw_line(at + Vector2(-26.0, 0.0), at + Vector2(0.0, -130.0), WOOD, 4.0)
	draw_line(at + Vector2(26.0, 0.0), at + Vector2(0.0, -130.0), WOOD, 4.0)
	draw_line(at + Vector2(0.0, -130.0), at + Vector2(10.0, 0.0), WOOD, 3.0)
	var size := PAINTING.get_size()
	draw_rect(Rect2(at + Vector2(-size.x * 0.5 - 4.0, -150.0 - 4.0), size + Vector2(8.0, 8.0)), WOOD)
	draw_texture(PAINTING, at + Vector2(-size.x * 0.5, -150.0))
