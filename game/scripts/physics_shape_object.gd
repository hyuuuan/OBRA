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
var _entity_configured := false
var _collision_key := ""
var _collision_generation: int = 0
var _generated_collisions: Array[CollisionShape2D] = []
var _world_bounds: Rect2 = Rect2(0.0, -520.0, 3760.0, 1200.0)
var _last_safe_transform: Transform2D = Transform2D.IDENTITY


func _ready() -> void:
	_ensure_collision_shape()
	if not _entity_configured:
		_configure_physics()
		_configure_skin()
		_rebuild_collision()
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	_last_safe_transform = global_transform
	call_deferred("_apply_spawn_motion")


func configure_entity(entry: Dictionary) -> void:
	entity_metadata = entry.duplicate(true)
	controllable = String(entry.get("runtime_role", "physics_morph")) == "physics_morph"
	shape_type = _resolve_shape_type()
	rig_profile = _load_rig_profile(String(entry.get("rig_profile", "")))
	if not rig_profile.has("rig_type"):
		rig_profile["rig_type"] = String(entry.get("rig_type", "none"))
	# An authored size, before the skin is built from the profile. 21 of the 27 utilities
	# share one scene, so its 96x96 export was the size of every one of them: a bridge
	# drawn as a long span was squashed to fit a square and came out too short to reach
	# across anything. A scene export cannot tell those 21 apart; config/object_sizes.json
	# can.
	var authored := _authored_target_size(String(entry.get("id", "")))
	if authored != Vector2.ZERO:
		rig_profile["target_size"] = [authored.x, authored.y]
		default_target_size = authored
	_configure_physics()
	_configure_skin()
	_rebuild_collision()
	_entity_configured = true


func apply_drawing(drawing: Image, strokes: Array = []) -> void:
	var skin := _get_skin()
	if skin != null and skin.has_method("apply_drawing"):
		skin.apply_drawing(drawing, strokes)
	_rebuild_collision()


func get_physics_anchor() -> RigidBody2D:
	return self


func get_camera_target() -> Node2D:
	return self


func set_world_bounds(bounds: Rect2) -> void:
	if bounds.size.x > 1.0 and bounds.size.y > 1.0:
		_world_bounds = bounds


func get_grip_anchor() -> Node2D:
	var grip := get_node_or_null("GripAnchor") as Node2D
	if grip == null:
		grip = Marker2D.new()
		grip.name = "GripAnchor"
		grip.position = Vector2(_target_size().x * 0.35, -_target_size().y * 0.15)
		add_child(grip)
	return grip


func capture_morph_state() -> Dictionary:
	var safe_position := global_position if _vector_is_finite(global_position) else _last_safe_transform.origin
	var safe_velocity := linear_velocity if _vector_is_finite(linear_velocity) else Vector2.ZERO
	return {
		"position": safe_position,
		"linear_velocity": safe_velocity,
		"rotation": global_rotation if is_finite(global_rotation) else 0.0,
		"angular_velocity": angular_velocity if is_finite(angular_velocity) else 0.0
	}


func apply_morph_state(state: Dictionary) -> void:
	_spawn_motion_applied = true
	var position := Vector2(state.get("position", global_position))
	global_position = position if _vector_is_finite(position) else global_position
	var velocity := Vector2(state.get("linear_velocity", Vector2.ZERO))
	linear_velocity = velocity.limit_length(520.0) if _vector_is_finite(velocity) else Vector2.ZERO
	var rotation_value := float(state.get("rotation", global_rotation))
	global_rotation = rotation_value if is_finite(rotation_value) else 0.0
	var angular_value := float(state.get("angular_velocity", 0.0))
	angular_velocity = clampf(angular_value if is_finite(angular_value) else 0.0, -8.0, 8.0)


## Preview state, here rather than on UtilityObject because a drawn SHAPE is placed
## too. The placement controller used to cast its preview to UtilityObject, so a
## circle -- whose scene is a PhysicsShapeObject and not a utility -- came back null
## and placement silently refused to start.
var is_preview := false
## The drawn item this object was built from, kept so confirming a placement can
## record where it ended up.
var item_data: DrawnItemData = null


func set_preview(enabled: bool) -> void:
	is_preview = enabled
	freeze = enabled
	gravity_scale = 0.0 if enabled else 1.0
	collision_layer = 0 if enabled else 1
	collision_mask = 1
	modulate = Color(0.45, 1.0, 0.55, 0.65) if enabled else Color.WHITE
	if enabled:
		# _apply_spawn_motion is deferred from _ready and would otherwise land on the
		# preview a frame later, loading it with the toss velocity a free-spawned
		# shape gets. Frozen it looks fine -- and then confirming unfroze a body
		# already carrying (95, -35) at 5 rad/s, so the thing the player had just
		# carefully positioned rolled away the instant they clicked.
		_spawn_motion_applied = true


func set_preview_valid(valid: bool) -> void:
	if is_preview:
		modulate = Color(0.45, 1.0, 0.55, 0.65) if valid else Color(1.0, 0.35, 0.32, 0.65)


func confirm_placement() -> void:
	# Leaving the preview IS the whole of confirming, so it goes through set_preview
	# rather than restating its fields. UtilityObject overrode this method with a
	# byte-for-byte copy that forgot to re-arm the interaction area set_preview had
	# switched off -- so a placed axe never found anything to chop and a placed key
	# never found a lock. Routing through the setter makes that impossible to forget.
	set_preview(false)
	sleeping = false
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	# A PLACED OBJECT KEEPS THE POSE IT WAS PLACED IN. Aiming a ladder upright and
	# watching it topple flat the moment it is let go makes placement pointless -- the
	# player set an orientation and the physics threw it away. Rotation is locked to what
	# they chose. The exceptions are the things whose whole ability is turning: a circle
	# rolls (that IS its ConceptNet ability) and a wheel has to spin to drive anything.
	if not _rolls():
		lock_rotation = true
	# And the spawn toss is suppressed here for the same reason set_preview does it: a
	# confirmed placement is deliberate. Utilities were spared because _apply_spawn_motion
	# returns early for them, so only the SHAPES got a spin applied a frame after being
	# set down -- which is why a placed square span to 64 degrees with its rotation
	# supposedly locked. The lock was fine; something was still handing it a spin.
	_spawn_motion_applied = true
	# A placed shape is scenery, not a body the player is driving. Shapes route to
	# placement rather than to the morph path, so leaving controllable set meant every
	# square and circle in the level answered the movement keys remotely -- press D and
	# the step you just built rolled off the ledge with you nowhere near it.
	controllable = false
	if item_data != null:
		item_data.placement_transform = global_transform


## The object's own collision, as one world-space rectangle. Anything asking "how far
## away is this thing" wants this and not global_position: the origin of a tall object is
## its middle, so a standing 244px ladder reads as 122px away from someone with their
## hand on it.
func world_extent() -> Rect2:
	var bounds := Rect2()
	var started := false
	for child in get_children():
		var collision := child as CollisionShape2D
		if collision == null or collision.shape == null or not collision.shape.has_method("get_rect"):
			continue
		var rect: Rect2 = collision.shape.call("get_rect")
		var basis := collision.global_transform
		for corner in [
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			Vector2(rect.position.x, rect.end.y),
			rect.end,
		]:
			var point: Vector2 = basis * corner
			bounds = bounds.expand(point) if started else Rect2(point, Vector2.ZERO)
			started = true
	return bounds if started else Rect2(global_position, Vector2.ZERO)


## How far a point is from the object's surface, rather than from its middle.
func distance_from(point: Vector2) -> float:
	var bounds := world_extent()
	if bounds.size == Vector2.ZERO:
		return point.distance_to(global_position)
	return point.distance_to(Vector2(
		clampf(point.x, bounds.position.x, bounds.end.x),
		clampf(point.y, bounds.position.y, bounds.end.y)))


## Things whose function is rotation, and which must therefore stay free to tumble.
func _rolls() -> bool:
	return shape_type in ["circle", "wheel"]


func apply_item_data(item: DrawnItemData) -> void:
	if item == null:
		return
	# WHAT THIS OBJECT IS, recorded here rather than only in UtilityObject.
	#
	# `item_data` is declared on this class but was assigned only by the utility subclass,
	# so the three primitives -- circle, square, triangle -- carried none. Anything asking a
	# placed object what it is got null for exactly the classes most likely to be placed:
	# the checkpoint snapshot skipped them, so a restore never cleaned up a placed square,
	# and the floating tread could not tell a circle resting on it from a rock.
	item_data = item
	apply_drawing(item.image, item.strokes)
	if not item.runtime_state.is_empty() and has_method("restore_utility_state"):
		call("restore_utility_state", item.runtime_state)


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
		"axe":
			mass = 1.15
			gravity_scale = 1.0
			linear_damp = 0.16
			angular_damp = 0.09
			material.friction = 0.68
			material.bounce = 0.06
			_move_force = 1750.0
			_roll_torque = 34000.0
			_jump_impulse = 400.0
			max_horizontal_speed = 300.0
			max_angular_speed = 10.0
		"ladder":
			mass = 1.45
			gravity_scale = 1.0
			linear_damp = 0.22
			angular_damp = 0.18
			material.friction = 0.82
			material.bounce = 0.03
			_move_force = 2200.0
			_roll_torque = 26000.0
			_jump_impulse = 430.0
			max_horizontal_speed = 260.0
			max_angular_speed = 7.0
		"key":
			mass = 0.9
			gravity_scale = 1.0
			linear_damp = 0.12
			angular_damp = 0.07
			material.friction = 0.42
			material.bounce = 0.10
			_move_force = 1450.0
			_roll_torque = 32000.0
			_jump_impulse = 360.0
			max_horizontal_speed = 330.0
			max_angular_speed = 12.0
		"umbrella":
			mass = 1.05
			gravity_scale = 0.92
			linear_damp = 0.26
			angular_damp = 0.14
			material.friction = 0.52
			material.bounce = 0.08
			_move_force = 1500.0
			_roll_torque = 30000.0
			_jump_impulse = 390.0
			max_horizontal_speed = 300.0
			max_angular_speed = 9.0
		"flashlight":
			mass = 0.95
			gravity_scale = 1.0
			linear_damp = 0.13
			angular_damp = 0.08
			material.friction = 0.44
			material.bounce = 0.09
			_move_force = 1500.0
			_roll_torque = 33000.0
			_jump_impulse = 365.0
			max_horizontal_speed = 330.0
			max_angular_speed = 12.0
		"sailboat":
			mass = 1.2
			gravity_scale = 0.95
			linear_damp = 0.2
			angular_damp = 0.12
			material.friction = 0.48
			material.bounce = 0.07
			_move_force = 1650.0
			_roll_torque = 31000.0
			_jump_impulse = 405.0
			max_horizontal_speed = 305.0
			max_angular_speed = 9.0
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
	_grounded = _has_ground_contact(state)
	var position := state.transform.origin
	var velocity := state.linear_velocity
	if not _vector_is_finite(position) or not _vector_is_finite(velocity) or not is_finite(state.angular_velocity):
		state.transform = _last_safe_transform
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		return
	if not _world_bounds.grow(180.0).has_point(position):
		var end := _world_bounds.end
		state.transform.origin = Vector2(
			clampf(position.x, _world_bounds.position.x + 42.0, end.x - 42.0),
			clampf(position.y, _world_bounds.position.y + 42.0, end.y - 42.0)
		)
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
	elif velocity.length() > 620.0:
		state.linear_velocity = velocity.normalized() * 620.0
	state.angular_velocity = clampf(state.angular_velocity, -max_angular_speed, max_angular_speed)
	_last_safe_transform = state.transform
	if not controllable:
		return

	var horizontal := Input.get_axis("move_left", "move_right")
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
		"axe":
			return direction * 1100.0
		"ladder":
			return direction * 750.0
		"key":
			return direction * 1150.0
		"umbrella":
			return direction * 900.0
		"flashlight":
			return direction * 1150.0
		"sailboat":
			return direction * 950.0
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
	_collision_generation += 1
	_clear_generated_collisions()
	var skin := _get_skin()
	var strokes: Array = []
	if skin != null and skin.has_method("get_vector_strokes"):
		strokes = skin.call("get_vector_strokes")
	for stroke_value in strokes:
		if _generated_collisions.size() >= 24 or not (stroke_value is Dictionary):
			break
		var stroke: Dictionary = stroke_value
		var points_value: Variant = stroke.get("points")
		if not (points_value is PackedVector2Array):
			continue
		var points: PackedVector2Array = points_value
		var width := float(stroke.get("width", 6.0))
		if _points_are_closed(points, width):
			var hull := Geometry2D.convex_hull(points)
			if hull.size() >= 3:
				var polygon := ConvexPolygonShape2D.new()
				polygon.points = hull
				_add_generated_shape(polygon, Vector2.ZERO, 0.0)
				continue
		var sampled := _sample_collision_points(points, 12)
		for index in range(sampled.size() - 1):
			if _generated_collisions.size() >= 24:
				break
			var from := sampled[index]
			var to := sampled[index + 1]
			var length := from.distance_to(to)
			if length <= 0.5:
				continue
			var radius := clampf(width * 0.5, 2.0, 7.0)
			var capsule := CapsuleShape2D.new()
			capsule.radius = radius
			capsule.height = maxf(radius * 2.0, length + radius * 2.0)
			_add_generated_shape(capsule, (from + to) * 0.5, (to - from).angle() + PI * 0.5)
	if _generated_collisions.is_empty():
		_add_class_fallback_collision()
	_collision_key = "%s:%d" % [shape_type, _collision_generation]


func _clear_generated_collisions() -> void:
	for collision in _generated_collisions:
		if collision != _collision_shape and is_instance_valid(collision):
			collision.queue_free()
	_generated_collisions.clear()
	_collision_shape.shape = null
	_collision_shape.position = Vector2.ZERO
	_collision_shape.rotation = 0.0


func _add_generated_shape(shape: Shape2D, at: Vector2, angle: float) -> void:
	var collision := _collision_shape
	if not _generated_collisions.is_empty():
		collision = CollisionShape2D.new()
		add_child(collision)
	collision.shape = shape
	collision.position = at
	collision.rotation = angle
	_generated_collisions.append(collision)


func _add_class_fallback_collision() -> void:
	var target_size := _target_size()
	var side := minf(target_size.x, target_size.y)
	var shape: Shape2D
	match shape_type:
		"circle":
			var circle := CircleShape2D.new()
			circle.radius = side * 0.5
			shape = circle
		"triangle":
			var triangle := ConvexPolygonShape2D.new()
			triangle.points = PackedVector2Array([
				Vector2(0.0, -side * 0.5),
				Vector2(-side * 0.56, side * 0.5),
				Vector2(side * 0.56, side * 0.5)
			])
			shape = triangle
		_:
			var rectangle := RectangleShape2D.new()
			rectangle.size = target_size
			shape = rectangle
	_add_generated_shape(shape, Vector2.ZERO, 0.0)


func _points_are_closed(points: PackedVector2Array, width: float) -> bool:
	return points.size() >= 3 and points[0].distance_to(points[points.size() - 1]) <= maxf(6.0, width * 1.5)


func _sample_collision_points(points: PackedVector2Array, maximum: int) -> PackedVector2Array:
	if points.size() <= maximum:
		return points.duplicate()
	var sampled := PackedVector2Array()
	for index in range(maximum):
		var source_index := int(round(float(index) * float(points.size() - 1) / float(maximum - 1)))
		sampled.append(points[source_index])
	return sampled


func _apply_spawn_motion() -> void:
	if _spawn_motion_applied:
		return
	_spawn_motion_applied = true
	if String(entity_metadata.get("runtime_role", "physics_morph")) == "utility":
		return
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
		"axe":
			linear_velocity = Vector2(64.0, -24.0)
			angular_velocity = 2.4
		"ladder":
			linear_velocity = Vector2(48.0, -18.0)
			angular_velocity = 1.2
		"key":
			linear_velocity = Vector2(80.0, -26.0)
			angular_velocity = 3.8
		"umbrella":
			linear_velocity = Vector2(58.0, -30.0)
			angular_velocity = 1.8
		"flashlight":
			linear_velocity = Vector2(82.0, -24.0)
			angular_velocity = 3.4
		"sailboat":
			linear_velocity = Vector2(62.0, -28.0)
			angular_velocity = 1.7
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


## Cached per run: every placement instantiates an object, and re-reading the table for
## each one would put a file read on the placement path.
static var _authored_sizes: Dictionary = {}
static var _authored_sizes_loaded := false


func _authored_target_size(entity_id: String) -> Vector2:
	if not _authored_sizes_loaded:
		_authored_sizes_loaded = true
		var text := FileAccess.get_file_as_string("res://config/object_sizes.json")
		var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
		if parsed is Dictionary:
			_authored_sizes = (parsed as Dictionary).get("sizes", {})
		else:
			push_warning("Could not read config/object_sizes.json; drawn objects keep their scene sizes")
	var value: Variant = _authored_sizes.get(entity_id)
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


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


func _vector_is_finite(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
