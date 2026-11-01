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
## Her easel and Mayon on it, drawn at her right hand. Off in the house after the run, where her
## easel stands across the room before she does and she walks to it (HouseEpilogue).
@export var with_easel := true
## How high a step lifts her, and how often, while she walks. A PLACEHOLDER for a walk cycle the
## delivered poses do not have (ART_PLACEHOLDERS.md): her side-on pose, stepping.
const STEP_LIFT := 2.0
const STEP_EVERY := 0.25
var _sprite: Sprite2D
var _walking := false
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
	if _walking:
		_sprite.position.y = -72.0 - (STEP_LIFT if fmod(_clock, STEP_EVERY * 2.0) < STEP_EVERY else 0.0)
		return
	if _painting and not _flowers:
		_pose("paint" if not Motion.reduced() and fmod(_clock, 2.4) > 1.6 else "back")


## Facing whoever she is talking to: away from the painting, her face to them.
func greet() -> void:
	_painting = false
	_sprite.flip_h = false
	_pose("front")
	_turned = true


## Across the room to `x`, at `speed`, side-on and stepping; then she faces the way she was going.
## Returns when she is there. With reduced motion she is simply there.
func walk_to(x: float, speed: float) -> void:
	_painting = false
	_turned = false
	_sprite.flip_h = x < global_position.x
	if Motion.reduced() or speed <= 0.0:
		global_position.x = x
	else:
		_walking = true
		_pose("turn")
		var seconds := absf(x - global_position.x) / speed
		var walk := create_tween()
		Motion.step(walk, self, "global_position:x", x, seconds)
		await walk.finished
		_walking = false
		_sprite.position.y = -72.0


func is_walking() -> bool:
	return _walking


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
	_sprite.flip_h = false
	_painting = true
	_flowers = keep_flowers and _flowers
	_pose("remember" if _flowers else "back")


func is_turned() -> bool:
	return _turned


func has_flowers() -> bool:
	return _flowers


func _draw() -> void:
	if not with_easel:
		return
	var at := Vector2(80, 0)
	draw_line(at + Vector2(-30, 0), at + Vector2(0, -150), WOOD, 5)
	draw_line(at + Vector2(30, 0), at + Vector2(0, -150), WOOD, 5)
	var size := Vector2(200, 112)
	draw_rect(Rect2(at + Vector2(-104, -174), size + Vector2(8, 8)), WOOD)
	draw_texture_rect(PAINTING, Rect2(at + Vector2(-100, -170), size), false)
