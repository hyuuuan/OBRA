class_name Lola2D
extends Node2D
## Supplied performance board, cut by build_mayon_performance.py.
## Feet share one registration through painting, turning, receiving, and looking back.
const FOLDER := "res://assets/Level5/people/lola_"
const PAINTING := preload("res://assets/hub/paintings/level_5.png")
const WALK := preload("res://assets/Level5/people/lola_walk.png")
const WALK_FRAMES := 6
const WALK_FRAME_SECONDS := 0.14
const PAINTING_IDLE := preload("res://assets/Level5/people/lola_painting_idle.png")
const PAINTING_FRAME_COUNT := 18
## Rear strokes, a thoughtful turn, three-quarter strokes, then the supplied idle variations.
const PAINTING_FRAMES := [12, 0, 1, 2, 3, 4, 5, 4, 3, 2, 1, 0, 13, 6, 7, 8, 9, 10, 11, 10, 9, 8, 7, 6, 14, 15, 16, 13, 17]
const PAINTING_HOLDS := [1.2, 0.4, 0.3, 0.4, 0.3, 0.35, 0.35, 0.35, 0.35, 0.35, 0.3, 0.5, 1.2, 0.4, 0.3, 0.4, 0.3, 0.35, 0.35, 0.35, 0.35, 0.35, 0.3, 0.5, 1.0, 0.6, 1.1, 0.6, 1.2]
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
	_show_painting_idle()


func _pose(pose: String) -> void:
	_sprite.hframes = 1
	if _sprite.texture != POSES[pose]:
		_sprite.texture = POSES[pose]


func _process(delta: float) -> void:
	_clock += delta
	if _walking:
		_sprite.frame = int(_clock / WALK_FRAME_SECONDS) % WALK_FRAMES
		return
	if _painting and not _flowers:
		_show_painting_idle()


func _show_painting_idle() -> void:
	if _sprite.texture != PAINTING_IDLE:
		_sprite.texture = PAINTING_IDLE
		_sprite.hframes = PAINTING_FRAME_COUNT
	var frame := 12
	if not Motion.reduced():
		var total := 0.0
		for hold: float in PAINTING_HOLDS:
			total += hold
		var within := fmod(_clock, total)
		for i in range(PAINTING_HOLDS.size()):
			if within < PAINTING_HOLDS[i]:
				frame = PAINTING_FRAMES[i]
				break
			within -= PAINTING_HOLDS[i]
	_sprite.frame = frame


## Facing whoever she is talking to: away from the painting, her face to them.
func greet() -> void:
	_painting = false
	_sprite.flip_h = false
	_pose("front")
	_turned = true


## Across the room to `x`, at `speed`, with the supplied six-frame walking cycle.
## Returns when she is there. With reduced motion she is simply there.
func walk_to(x: float, speed: float) -> void:
	_painting = false
	_turned = false
	_sprite.flip_h = x < global_position.x
	_pose("turn")
	if Motion.reduced() or speed <= 0.0:
		global_position.x = x
	else:
		_walking = true
		_clock = 0.0
		_sprite.texture = WALK
		_sprite.hframes = WALK_FRAMES
		_sprite.frame = 0
		var seconds := absf(x - global_position.x) / speed
		var walk := create_tween()
		Motion.step(walk, self, "global_position:x", x, seconds)
		await walk.finished
		_walking = false
		_pose("turn")


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
	_clock = 0.0
	if _flowers:
		_pose("remember")
	else:
		_show_painting_idle()


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
