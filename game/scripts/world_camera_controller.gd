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

var target: Node2D = null
var _vertical_rest_y: float = 0.0
var _has_vertical_rest := false
var _last_emitted_position := Vector2(INF, INF)


func _ready() -> void:
	make_current()
	snap_to_target()


func _process(delta: float) -> void:
	var desired := _clamped_target_position()
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


func set_target(new_target: Node2D) -> void:
	target = new_target
	_has_vertical_rest = false


func set_bounds(bounds: Rect2) -> void:
	world_bounds = bounds


func snap_to_target() -> void:
	global_position = _clamped_target_position()
	_emit_camera_moved_if_needed(true)


func _clamped_target_position() -> Vector2:
	var desired := global_position
	if target != null and is_instance_valid(target):
		desired.x = target.global_position.x + target_offset.x
		desired.y = _vertical_follow_y(target.global_position.y)

	var viewport_size := _viewport_size()
	var half_view := viewport_size * 0.5
	var bounds_end := world_bounds.position + world_bounds.size

	var min_x := world_bounds.position.x + half_view.x - play_area_left
	var max_x := bounds_end.x - half_view.x
	if min_x <= max_x:
		desired.x = clampf(desired.x, min_x, max_x)
	else:
		desired.x = world_bounds.position.x + world_bounds.size.x * 0.5

	desired.y = _clamp_camera_y(desired.y)

	return desired


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


func _viewport_size() -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1600.0, 900.0)
	return viewport_size


func _emit_camera_moved_if_needed(force: bool = false) -> void:
	var threshold_sq := camera_move_epsilon * camera_move_epsilon
	if force or _last_emitted_position.distance_squared_to(global_position) >= threshold_sq:
		_last_emitted_position = global_position
		camera_moved.emit(global_position)
