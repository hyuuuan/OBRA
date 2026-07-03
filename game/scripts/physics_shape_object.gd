class_name PhysicsShapeObject
extends RigidBody2D
## Dynamic sketch object for simple recognized shapes.

@export var skin_node_path: NodePath = NodePath("DrawingSkin")
@export var collision_shape_path: NodePath = NodePath("CollisionShape2D")
@export var shape_type: String = ""
@export var default_target_size: Vector2 = Vector2(96, 96)

var entity_metadata: Dictionary = {}
var rig_profile: Dictionary = {}

var _collision_shape: CollisionShape2D
var _spawn_motion_applied := false


func _ready() -> void:
	_ensure_collision_shape()
	_configure_physics()
	_configure_skin()
	_rebuild_collision()
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
		"square":
			mass = 1.25
			gravity_scale = 1.0
			linear_damp = 0.18
			angular_damp = 0.16
			material.friction = 0.85
			material.bounce = 0.04
		"triangle":
			mass = 1.1
			gravity_scale = 1.0
			linear_damp = 0.14
			angular_damp = 0.08
			material.friction = 0.72
			material.bounce = 0.07
		_:
			mass = 1.0
			gravity_scale = 1.0
			linear_damp = 0.12
			angular_damp = 0.08
			material.friction = 0.55
			material.bounce = 0.08
	physics_material_override = material
	can_sleep = true
	lock_rotation = false


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
