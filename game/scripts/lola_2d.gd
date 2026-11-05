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
## Where the easel stands from her feet. Clear of her: at 80 the canvas began behind her own body,
## and her head sat over its corner.
const EASEL_AT := Vector2(100, 0)
const CANVAS_SIZE := Vector2(200, 112)
## THE PAINTING IS BEING PAINTED (Kent, 2026-11-05: "there is no proper animation to the painting").
## She worked at a canvas that already held the finished Mayon, and nothing on it changed. It starts
## as an underdrawing with the sky blocked in, and each time her brush reaches it -- these frames of
## the supplied painting cycle, the arm raised furthest -- a little more of it is painted
## (paint_reveal.gdshader). It is nearly finished by the time she turns: "I think it is nearly
## finished."
const BRUSH_ON_CANVAS := [2, 3, 8, 9, 15]
const PAINT_START := 0.12
const PAINT_STEP := 0.035
const PAINT_NEARLY := 0.94
## Under Reduce Motion her brush stays still, so the canvas is shown most of the way there.
const PAINT_STILL := 0.85
const PAINT_SHADER := preload("res://shaders/paint_reveal.gdshader")
var _canvas: Sprite2D
var _painted := PAINT_START
var _last_frame := -1
var _sprite: Sprite2D
var _walking := false
var _turned := false
var _flowers := false
var _clock := 0.0
var _painting := true


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if with_easel:
		# Before her sprite, so she stands in front of her work.
		_canvas = Sprite2D.new()
		_canvas.name = "Canvas"
		_canvas.texture = PAINTING
		_canvas.scale = CANVAS_SIZE / PAINTING.get_size()
		_canvas.position = EASEL_AT + Vector2(0, -170 + CANVAS_SIZE.y * 0.5)
		var material := ShaderMaterial.new()
		material.shader = PAINT_SHADER
		_canvas.material = material
		add_child(_canvas)
		_set_painted(PAINT_STILL if Motion.reduced() else PAINT_START)
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
	if frame != _last_frame and frame in BRUSH_ON_CANVAS and _canvas != null:
		_set_painted(minf(PAINT_NEARLY, _painted + PAINT_STEP))
	_last_frame = frame
	_sprite.frame = frame


func _set_painted(amount: float) -> void:
	_painted = amount
	if _canvas != null:
		(_canvas.material as ShaderMaterial).set_shader_parameter(&"reveal", amount)


## How much of the canvas she has painted, 0 to 1.
func painted() -> float:
	return _painted


## Where her canvas is, in her own coordinates: for a probe, and for anyone standing beside it.
func canvas_rect() -> Rect2:
	return Rect2(EASEL_AT + Vector2(-CANVAS_SIZE.x * 0.5, -170), CANVAS_SIZE)


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
	var at := EASEL_AT
	draw_line(at + Vector2(-30, 0), at + Vector2(0, -150), WOOD, 5)
	draw_line(at + Vector2(30, 0), at + Vector2(0, -150), WOOD, 5)
	draw_rect(Rect2(at + Vector2(-104, -174), CANVAS_SIZE + Vector2(8, 8)), WOOD)
	# The canvas itself is the Canvas sprite, painted in as she works (paint_reveal.gdshader).
