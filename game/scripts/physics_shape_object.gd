class_name PhysicsShapeObject
extends RigidBody2D
## Dynamic sketch object for simple recognized shapes.

@export var skin_node_path: NodePath = NodePath("DrawingSkin")
@export var collision_shape_path: NodePath = NodePath("CollisionShape2D")
@export var shape_type: String = ""
@export var default_target_size: Vector2 = Vector2(96, 96)
@export var controllable: bool = true
@export var max_horizontal_speed: float = 320.0
@export var max_angular_speed: float = 12.0
@export_range(0.0, 1.0) var air_control_multiplier: float = 0.35

var entity_metadata: Dictionary = {}
var rig_profile: Dictionary = {}

var _collision_shape: CollisionShape2D
var _spawn_motion_applied := false
var _move_force := 1600.0
var _roll_torque := 28000.0
var _jump_impulse := 380.0
var _grounded := false


func _ready() -> void:
	_ensure_collision_shape()
	_configure_physics()
	_configure_skin()
	_rebuild_collision()
	contact_monitor = true
	max_contacts_reported = 8
	call_deferred("_apply_spawn_motion")


func configure_entity(entry: Dictionary) -> void:
	entity_metadata = entry.duplicate(true)
	shape_type = _resolve_shape_type()
	rig_profile = _load_rig_profile(String(entry.get("rig_profile", "")))
	if not rig_profile.has("rig_type"):
		rig_profile["rig_type"] = String(entry.get("rig_type", "none"))
	_configure_physics()
	_configure_skin()
	_rebuild_collision()


func apply_drawing(drawing: Image, strokes: Array = []) -> void:
	var skin := _get_skin()
	if skin != null and skin.has_method("apply_drawing"):
		skin.apply_drawing(drawing, strokes)
	_rebuild_collision()


func _resolve_shape_type() -> String:
	var configured := String(entity_metadata.get("shape_type", shape_type)).strip_edges()
	if not configured.is_empty():
		return configured
	var entity_id := String(entity_metadata.get("id", "")).strip_edges()
	if not entity_id.is_empty():
		return entity_id
	return String(entity_metadata.get("quickdraw_label", "")).strip_edges()


func _configure_physics() -> void:
	if shape_type.is_empty():
		shape_type = _resolve_shape_type()

	var material := PhysicsMaterial.new()
	match shape_type:
		"circle":
			mass = 1.0
			gravity_scale = 1.0
			linear_damp = 0.08
			angular_damp = 0.02
			material.friction = 0.25
			material.bounce = 0.22
			_move_force = 650.0
			_roll_torque = 36000.0
			_jump_impulse = 360.0
			max_horizontal_speed = 360.0
			max_angular_speed = 14.0
		"square":
			mass = 1.25
			gravity_scale = 1.0
			linear_damp = 0.18
			angular_damp = 0.16
			material.friction = 0.85
			material.bounce = 0.04
			_move_force = 2100.0
			_roll_torque = 30000.0
			_jump_impulse = 430.0
			max_horizontal_speed = 280.0
			max_angular_speed = 8.0
		"triangle":
			mass = 1.1
			gravity_scale = 1.0
			linear_damp = 0.14
			angular_damp = 0.08
			material.friction = 0.72
			material.bounce = 0.07
			_move_force = 1850.0
			_roll_torque = 38000.0
			_jump_impulse = 410.0
			max_horizontal_speed = 300.0
			max_angular_speed = 11.0
		_:
			mass = 1.0
			gravity_scale = 1.0
			linear_damp = 0.12
			angular_damp = 0.08
			material.friction = 0.55
			material.bounce = 0.08
			_move_force = 1600.0
			_roll_torque = 28000.0
			_jump_impulse = 380.0
			max_horizontal_speed = 300.0
			max_angular_speed = 10.0
	physics_material_override = material
	can_sleep = true
	lock_rotation = false


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not controllable:
		return

	var horizontal := Input.get_axis("move_left", "move_right")
	_grounded = _has_ground_contact(state)
	if absf(horizontal) > 0.05:
		sleeping = false
		var control_scale := 1.0 if _grounded else air_control_multiplier
		if absf(linear_velocity.x) < max_horizontal_speed or signf(linear_velocity.x) != signf(horizontal):
			apply_central_force(Vector2(horizontal * _move_force * control_scale, 0.0))
		if absf(angular_velocity) < max_angular_speed or signf(angular_velocity) != signf(horizontal):
			apply_torque(horizontal * _roll_torque * control_scale)

	if Input.is_action_just_pressed("jump") and _grounded:
		sleeping = false
		apply_central_impulse(Vector2(0.0, -_jump_impulse * mass))
		apply_torque_impulse(_jump_spin_impulse(horizontal))


func _has_ground_contact(state: PhysicsDirectBodyState2D) -> bool:
	for index in range(state.get_contact_count()):
		var normal := state.get_contact_local_normal(index)
		var world_normal := normal.rotated(global_rotation)
		if normal.dot(Vector2.UP) > 0.45 or world_normal.dot(Vector2.UP) > 0.45:
			return true
	return false


func _jump_spin_impulse(horizontal: float) -> float:
	var direction := horizontal
	if absf(direction) <= 0.05:
		direction = 1.0 if angular_velocity >= 0.0 else -1.0
	match shape_type:
		"circle":
			return direction * 1400.0
		"square":
			return direction * 900.0
		"triangle":
			return direction * 1200.0
		_:
			return direction * 1000.0


func _configure_skin() -> void:
	var skin := _get_skin()
	if skin == null:
		return
	if skin.has_method("configure_rig"):
		skin.configure_rig(rig_profile, entity_metadata)
	elif skin.has_method("configure_skin"):
		skin.configure_skin(rig_profile, entity_metadata)


func _rebuild_collision() -> void:
	_ensure_collision_shape()
	if _collision_shape == null:
		return

	var target_size := _target_size()
	var side := minf(target_size.x, target_size.y)
	match shape_type:
		"circle":
			var circle := CircleShape2D.new()
			circle.radius = side * 0.5
			_collision_shape.shape = circle
		"square":
			var square := RectangleShape2D.new()
			square.size = Vector2(side, side)
			_collision_shape.shape = square
		"triangle":
			var triangle := ConvexPolygonShape2D.new()
			var half_width := side * 0.56
			var half_height := side * 0.5
			triangle.points = PackedVector2Array([
				Vector2(0.0, -half_height),
				Vector2(-half_width, half_height),
				Vector2(half_width, half_height)
			])
			_collision_shape.shape = triangle
		_:
			var fallback := RectangleShape2D.new()
			fallback.size = target_size
			_collision_shape.shape = fallback


func _apply_spawn_motion() -> void:
	if _spawn_motion_applied:
		return
	_spawn_motion_applied = true
	match shape_type:
		"circle":
			linear_velocity = Vector2(95.0, -35.0)
			angular_velocity = 5.0
		"square":
			linear_velocity = Vector2(60.0, -22.0)
			angular_velocity = 1.6
		"triangle":
			linear_velocity = Vector2(70.0, -28.0)
			angular_velocity = 3.1
		_:
			linear_velocity = Vector2(55.0, -20.0)
			angular_velocity = 1.5


func _target_size() -> Vector2:
	var value: Variant = rig_profile.get("target_size")
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return default_target_size


func _ensure_collision_shape() -> void:
	if _collision_shape != null:
		return
	_collision_shape = get_node_or_null(collision_shape_path) as CollisionShape2D
	if _collision_shape == null:
		_collision_shape = find_child("CollisionShape2D", true, false) as CollisionShape2D


func _get_skin() -> Node:
	var skin := get_node_or_null(skin_node_path)
	if skin == null:
		skin = find_child("DrawingSkin", true, false)
	return skin


func _load_rig_profile(profile_path: String) -> Dictionary:
	if profile_path.is_empty():
		return {}

	var text := FileAccess.get_file_as_string(profile_path)
	if text.is_empty():
		push_warning("Could not read rig profile: %s" % profile_path)
		return {}

	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed

	push_warning("Rig profile is not a JSON object: %s" % profile_path)
	return {}
