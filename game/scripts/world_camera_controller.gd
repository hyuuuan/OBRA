class_name WorldCameraController
extends Camera2D
## Camera tuned for the full game canvas. It follows a world target while
## keeping the target centered in the visible play area whenever bounds allow.

signal camera_moved(camera_position: Vector2)

@export var play_area_left: float = 0.0
@export var follow_lerp_speed: float = 10.0
@export var vertical_lerp_speed: float = 5.5
@export var vertical_dead_zone: float = 20.0
@export_range(0.0, 1.0) var vertical_follow_scale: float = 0.75
@export var target_offset: Vector2 = Vector2(0.0, -160.0)
@export var world_bounds: Rect2 = Rect2(0.0, -520.0, 3760.0, 1200.0)
@export var camera_move_epsilon: float = 0.05
## CENTRE ON THE TARGET INSTEAD OF ANCHORING TO THE GROUND.
##
## The vertical follow below exists for a level: it pins the camera near the bottom of the
## world and lets the player rise off it by three quarters of the distance, so the ground
## stays in shot and a jump does not swing the view. Somewhere that is not a level -- the
## room inside the straw heap, which sits in the empty sky above it -- that is exactly
## wrong: the camera stays a thousand units below the floor being stood on and points at
## nothing. This is not `focus_on`, deliberately: focus is what a line of dialogue takes and
## gives back, and a room would lose its framing the moment somebody finished a sentence.
@export var vertical_free: bool = false

var target: Node2D = null
## What the camera is pushed in on for a beat, and how far. Null means it is doing its
## ordinary job of following the player.
var _focus: Node2D = null
var _focus_zoom := 1.0
var _focus_lift := 0.0
var _focus_tween: Tween = null
var _rest_process_mode := Node.PROCESS_MODE_INHERIT
var _vertical_rest_y: float = 0.0
var _has_vertical_rest := false
var _last_emitted_position := Vector2(INF, INF)


func _ready() -> void:
	make_current()
	snap_to_target()


func _process(delta: float) -> void:
	var desired := _clamped_target_position()
	if not _vector_is_finite(desired):
		desired = world_bounds.get_center()
	if not _vector_is_finite(global_position):
		global_position = desired
	var x_weight := 1.0
	if follow_lerp_speed > 0.0:
		x_weight = 1.0 - exp(-follow_lerp_speed * delta)
	var y_weight := 1.0
	if vertical_lerp_speed > 0.0:
		y_weight = 1.0 - exp(-vertical_lerp_speed * delta)

	var next_position := Vector2(
		lerpf(global_position.x, desired.x, x_weight),
		lerpf(global_position.y, desired.y, y_weight)
	)
	global_position = next_position
	_emit_camera_moved_if_needed()


## Push in on something and hold there until released.
##
## A line of dialogue over a wide shot is a caption on a landscape: the player reads the
## box and never looks at who is talking. Moving the camera in makes the speaker the
## subject, which is the whole difference between a cutscene and a notification.
##
## The camera keeps processing while the tree is paused, because that is exactly when this
## is used -- the world is stopped for the conversation and the push-in is the only thing
## that should still be moving.
## `lift` is how far up the SCREEN the subject is placed, in pixels, so the dialogue box
## sitting across the middle does not cover the person talking. The camera moves down by
## that much in world units, which is why it is divided by the zoom.
## Gentler than it was. The portrait carries the focus now, and a hard push-in behind a
## large figure makes the background compete with it rather than recede.
func focus_on(node: Node2D, zoom_scale: float = 1.15, seconds: float = 0.45,
		lift: float = 240.0) -> void:
	if node == null or not is_instance_valid(node):
		return
	if _focus == null:
		_rest_process_mode = process_mode
	_focus = node
	_focus_zoom = maxf(0.1, zoom_scale)
	_focus_lift = lift
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tween_zoom(Vector2(_focus_zoom, _focus_zoom), seconds)


func release_focus(seconds: float = 0.35) -> void:
	if _focus == null:
		return
	_focus = null
	_focus_zoom = 1.0
	var restore := _rest_process_mode
	_tween_zoom(Vector2.ONE, seconds).finished.connect(
		func() -> void: process_mode = restore)


func is_focused() -> bool:
	return _focus != null


## Pause-immune, because a tween is bound to its node's pause state by default and this
## one exists to run while the tree is stopped.
func _tween_zoom(to: Vector2, seconds: float) -> Tween:
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	_focus_tween = create_tween()
	_focus_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_focus_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_focus_tween.tween_property(self, "zoom", to, seconds)
	return _focus_tween


func set_target(new_target: Node2D) -> void:
	target = new_target
	_has_vertical_rest = false


func set_bounds(bounds: Rect2) -> void:
	world_bounds = bounds


## Going back to anchoring on the ground forgets where the ground was, or the camera keeps
## measuring the player's height above a rest line taken somewhere they are no longer.
func set_vertical_free(free: bool) -> void:
	if vertical_free == free:
		return
	vertical_free = free
	_has_vertical_rest = false


func snap_to_target() -> void:
	global_position = _clamped_target_position()
	_emit_camera_moved_if_needed(true)


func _clamped_target_position() -> Vector2:
	var desired := global_position
	# While focused the subject wins, and the vertical follow's "rest" logic is skipped:
	# it exists to stop the camera chasing a jumping player, and there is nobody jumping.
	if _focus != null and is_instance_valid(_focus):
		var focus_position := _focus.global_position
		if _vector_is_finite(focus_position):
			var drop := _focus_lift / maxf(0.01, zoom.y)
			desired = Vector2(focus_position.x, _clamp_camera_y(focus_position.y + drop))
			return _clamp_to_bounds(desired)
	if target != null and is_instance_valid(target):
		var target_position := target.global_position
		if _vector_is_finite(target_position):
			desired.x = target_position.x + target_offset.x
			desired.y = _clamp_camera_y(target_position.y + target_offset.y) \
				if vertical_free else _vertical_follow_y(target_position.y)

	return _clamp_to_bounds(desired)


func _clamp_to_bounds(desired: Vector2) -> Vector2:
	var half_view := _viewport_size() * 0.5
	var bounds_end := world_bounds.position + world_bounds.size

	var min_x := world_bounds.position.x + half_view.x - play_area_left
	var max_x := bounds_end.x - half_view.x
	if min_x <= max_x:
		desired.x = clampf(desired.x, min_x, max_x)
	else:
		desired.x = world_bounds.position.x + world_bounds.size.x * 0.5

	desired.y = _clamp_camera_y(desired.y)

	return desired


func _vector_is_finite(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


func _clamp_camera_y(value: float) -> float:
	var min_y := _min_camera_y()
	var max_y := _max_camera_y()
	if min_y <= max_y:
		return clampf(value, min_y, max_y)
	return world_bounds.position.y + world_bounds.size.y * 0.5


func _vertical_follow_y(target_y: float) -> float:
	if not _has_vertical_rest or target_y > _vertical_rest_y:
		_vertical_rest_y = target_y
		_has_vertical_rest = true

	var upward_distance := maxf(0.0, _vertical_rest_y - target_y - vertical_dead_zone)
	var desired_y := _max_camera_y() - upward_distance * vertical_follow_scale
	return _clamp_camera_y(desired_y)


func _min_camera_y() -> float:
	return world_bounds.position.y + _viewport_size().y * 0.5


func _max_camera_y() -> float:
	return world_bounds.position.y + world_bounds.size.y - _viewport_size().y * 0.5


## How much WORLD the camera can see, which is the viewport divided by the zoom. It used
## to return the raw viewport, which was right for as long as the zoom was always one --
## and would have clamped a pushed-in camera as though it still saw the whole screen.
func _viewport_size() -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1600.0, 900.0)
	var scale := Vector2(maxf(0.01, zoom.x), maxf(0.01, zoom.y))
	return viewport_size / scale


func _emit_camera_moved_if_needed(force: bool = false) -> void:
	var threshold_sq := camera_move_epsilon * camera_move_epsilon
	if force or _last_emitted_position.distance_squared_to(global_position) >= threshold_sq:
		_last_emitted_position = global_position
		camera_moved.emit(global_position)
