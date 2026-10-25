class_name ScreenTremor
extends Node
## The eruption, felt. Mayon rumbles under everything in Acts One and Two, and every sound has a
## visual twin (Dilim's rule): this is the rumble's. Every `every` seconds the view shakes a few
## whole pixels for `length` seconds and `trembled` fires, so the ash can surge with it.
##
## It shakes Camera2D.offset, which nothing else in the game writes, and leaves the camera's
## position alone -- the backdrop bands read position, so the whole picture shakes as one and
## the parallax never jumps.

signal trembled(strength: float)

## The camera to shake; the viewport's current camera if empty.
@export var camera_path: NodePath
## Seconds between tremors; 0 is never on its own (only when asked).
@export var every: float = 20.0
@export var length: float = 0.6
## The widest shake, in px.
@export var amplitude: float = 3.0
@export var enabled := true

var _clock := 0.0
var _left := 0.0
var _strength := 1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20261025


## Shake now. `strength` scales the shake and is passed on to whoever surges with it.
func tremble(strength: float = 1.0) -> void:
	_left = length
	_strength = clampf(strength, 0.0, 2.0)
	trembled.emit(_strength)


func is_trembling() -> bool:
	return _left > 0.0


func _process(delta: float) -> void:
	if enabled and every > 0.0:
		_clock += delta
		if _clock >= every:
			_clock = 0.0
			tremble()
	var camera := _camera()
	if camera == null:
		return
	if _left > 0.0:
		# The reach shrinks with the time left, and the last frame's is nothing: rounded, the
		# view lands back exactly where it was.
		_left = maxf(0.0, _left - delta)
		var reach := amplitude * _strength * (_left / maxf(length, 0.001))
		camera.offset = Vector2(roundf(_rng.randf_range(-reach, reach)),
			roundf(_rng.randf_range(-reach, reach)))


func _camera() -> Camera2D:
	if not camera_path.is_empty():
		return get_node_or_null(camera_path) as Camera2D
	return get_viewport().get_camera_2d() if get_viewport() != null else null
