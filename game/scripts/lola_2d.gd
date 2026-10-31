class_name Lola2D
extends Node2D
## Dedicated generated performance art, cut by build_mayon_performance.py.
## Feet share one registration through painting, turning, receiving, and looking back.
const FOLDER := "res://assets/Level5/people/lola_"
const PAINTING := preload("res://assets/hub/paintings/level_5.png")
const POSES := {
	"back": preload("res://assets/Level5/people/lola_back.png"),
	"paint": preload("res://assets/Level5/people/lola_paint.png"),
	"turn": preload("res://assets/Level5/people/lola_turn.png"),
	"front": preload("res://assets/Level5/people/lola_front.png"),
	"flowers": preload("res://assets/Level5/people/lola_flowers.png"),
	"remember": preload("res://assets/Level5/people/lola_remember.png"),
}
const WOOD := Color(0.36, 0.24, 0.15)
var _sprite: Sprite2D
var _turned := false
var _flowers := false
var _clock := 0.0
var _painting := true


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite = Sprite2D.new()
	_sprite.name = "Lola"
	_sprite.position = Vector2(0, -72)
	add_child(_sprite)
	_pose("back")


func _pose(pose: String) -> void:
	if _sprite.texture != POSES[pose]:
		_sprite.texture = POSES[pose]


func _process(delta: float) -> void:
	_clock += delta
	if _painting and not _flowers:
		_pose("paint" if not Motion.reduced() and fmod(_clock, 2.4) > 1.6 else "back")


func turn_around() -> void:
	_painting = false
	if not Motion.reduced():
		_pose("turn")
		await get_tree().create_timer(0.28, false).timeout
	_pose("front")
	_turned = true


func receive_flowers() -> void:
	_flowers = true
	_pose("flowers")


func turn_back(keep_flowers: bool = false) -> void:
	if not Motion.reduced():
		_pose("turn")
		await get_tree().create_timer(0.28, false).timeout
	face_the_painting(keep_flowers)


func face_the_painting(keep_flowers: bool = false) -> void:
	_turned = false
	_painting = true
	_flowers = keep_flowers and _flowers
	_pose("remember" if _flowers else "back")


func is_turned() -> bool:
	return _turned


func has_flowers() -> bool:
	return _flowers


func _draw() -> void:
	var at := Vector2(80, 0)
	draw_line(at + Vector2(-30, 0), at + Vector2(0, -150), WOOD, 5)
	draw_line(at + Vector2(30, 0), at + Vector2(0, -150), WOOD, 5)
	var size := Vector2(200, 112)
	draw_rect(Rect2(at + Vector2(-104, -174), size + Vector2(8, 8)), WOOD)
	draw_texture_rect(PAINTING, Rect2(at + Vector2(-100, -170), size), false)
