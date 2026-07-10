class_name ActiveRagdollMorph
extends Node2D
## Shared force-driven controller for all living morphs. The scene root is only
## a lifetime container; the generated torso and every articulated segment are
## real RigidBody2D nodes owned by RuntimeRig2D.

@export var skin_node_path: NodePath = NodePath("DrawingSkin")

var entity_metadata: Dictionary = {}
var rig_profile: Dictionary = {}

var _anchor: ActiveRigBody2D
var _pending_morph_state: Dictionary = {}
var _charge: float = 0.0
var _ladder: Node2D
var _umbrella_open: bool = false
var _equipped_utility: Node2D
var _camera_anchor: Marker2D
var _world_bounds: Rect2 = Rect2(0.0, -520.0, 3760.0, 1200.0)
var _drive_bodies: Array = []


func configure_entity(entry: Dictionary) -> void:
	entity_metadata = entry.duplicate(true)
	rig_profile = _load_rig_profile(String(entry.get("rig_profile", "")))
	if not rig_profile.has("rig_type"):
		rig_profile["rig_type"] = String(entry.get("rig_type", "none"))
	var skin := _get_skin()
	if skin != null and skin.has_method("configure_rig"):
		skin.configure_rig(rig_profile, entity_metadata)


func apply_drawing(drawing: Image, strokes: Array = []) -> void:
	var skin := _get_skin()
	if skin == null or not skin.has_method("apply_drawing"):
		return
	skin.apply_drawing(drawing, strokes)
	_anchor = skin.call("get_primary_body") as ActiveRigBody2D
	_refresh_drive_bodies()
	if _anchor != null and not _pending_morph_state.is_empty():
		_apply_morph_state_now(_pending_morph_state)
		_pending_morph_state.clear()
	_update_camera_anchor(true)


func set_world_bounds(bounds: Rect2) -> void:
	if bounds.size.x <= 1.0 or bounds.size.y <= 1.0:
		return
	_world_bounds = bounds
	var skin := _get_skin()
	if skin != null and skin.has_method("set_world_bounds"):
		skin.call("set_world_bounds", bounds)
	_update_camera_anchor(true)


func get_camera_target() -> Node2D:
	_ensure_camera_anchor()
	_update_camera_anchor(true)
	return _camera_anchor


func get_physics_anchor() -> ActiveRigBody2D:
	if _anchor == null:
		var skin := _get_skin()
		if skin != null and skin.has_method("get_primary_body"):
			_anchor = skin.call("get_primary_body") as ActiveRigBody2D
	return _anchor


func get_grip_anchor() -> Node2D:
	var body := get_physics_anchor()
	if body == null:
		return self
	var grip := body.get_node_or_null("GripAnchor") as Node2D
	return grip if grip != null else body


func capture_morph_state() -> Dictionary:
	var body := get_physics_anchor()
	if body == null:
		return {"position": global_position, "linear_velocity": Vector2.ZERO, "rotation": 0.0, "angular_velocity": 0.0}
	var safe_position := body.global_position
	if not _vector_is_finite(safe_position):
		_ensure_camera_anchor()
		safe_position = _camera_anchor.global_position if _vector_is_finite(_camera_anchor.global_position) else global_position
	var safe_velocity := body.linear_velocity if _vector_is_finite(body.linear_velocity) else Vector2.ZERO
	var safe_rotation := body.global_rotation if is_finite(body.global_rotation) else 0.0
	var safe_angular_velocity := body.angular_velocity if is_finite(body.angular_velocity) else 0.0
	return {
		"position": safe_position,
		"linear_velocity": safe_velocity,
		"rotation": safe_rotation,
		"angular_velocity": safe_angular_velocity
	}


func apply_morph_state(state: Dictionary) -> void:
	if get_physics_anchor() == null:
		_pending_morph_state = state.duplicate(true)
		return
	_apply_morph_state_now(state)


func _apply_morph_state_now(state: Dictionary) -> void:
	var body := get_physics_anchor()
	if body == null:
		return
	var target := Vector2(state.get("position", body.global_position))
	if not _vector_is_finite(target):
		target = body.global_position
	var offset := target - body.global_position
	var inherited_velocity := Vector2(state.get("linear_velocity", Vector2.ZERO))
	if not _vector_is_finite(inherited_velocity):
		inherited_velocity = Vector2.ZERO
	var skin := _get_skin()
	if skin != null and skin.has_method("get_rigid_bodies"):
		for rig_body in skin.call("get_rigid_bodies"):
			if rig_body is RigidBody2D:
				rig_body.global_position += offset
				rig_body.linear_velocity = inherited_velocity.limit_length(520.0)
	var inherited_rotation := float(state.get("rotation", 0.0))
	body.global_rotation = clampf(inherited_rotation if is_finite(inherited_rotation) else 0.0, -PI * 0.35, PI * 0.35)
	var inherited_angular := float(state.get("angular_velocity", 0.0))
	body.angular_velocity = clampf(inherited_angular if is_finite(inherited_angular) else 0.0, -5.0, 5.0)


func set_rig_state(state: String, params: Dictionary = {}) -> void:
	var skin := _get_skin()
	if skin != null and skin.has_method("set_motion_state"):
		skin.set_motion_state(state, params)


func begin_ladder(ladder: Node2D) -> void:
	_ladder = ladder


func end_ladder() -> void:
	_ladder = null


func is_using_ladder(ladder: Node2D) -> bool:
	return _ladder == ladder


func set_equipped_utility(utility: Node2D) -> void:
	_equipped_utility = utility


func set_umbrella_open(is_open: bool) -> void:
	_umbrella_open = is_open


func is_in_water() -> bool:
	var skin := _get_skin()
	return skin != null and skin.has_method("is_in_water") and bool(skin.call("is_in_water"))


func _physics_process(delta: float) -> void:
	var body := get_physics_anchor()
	if body == null:
		return
	var horizontal := Input.get_axis("move_left", "move_right")
	var vertical := Input.get_axis("move_up", "move_down")
	var entity_id := String(entity_metadata.get("id", ""))
	var state := "idle"
	var moving := absf(horizontal) > 0.05 or absf(vertical) > 0.05

	if _ladder != null and is_instance_valid(_ladder):
		state = _drive_ladder(body, vertical)
	elif entity_id == "spider":
		state = _drive_spider(body, horizontal, vertical)
	elif entity_id in ["bird", "butterfly"]:
		state = _drive_flier(body, horizontal, delta, entity_id == "butterfly")
	elif entity_id == "fish":
		state = _drive_fish(body, Vector2(horizontal, vertical))
	elif entity_id == "snake":
		state = _drive_snake(body, Vector2(horizontal, vertical))
	elif entity_id in ["frog", "rabbit"]:
		state = _drive_hopper(body, horizontal, delta, entity_id == "rabbit")
	else:
		state = _drive_grounded(body, horizontal)

	if _umbrella_open and body.linear_velocity.y > 130.0:
		var excess := body.linear_velocity.y - 130.0
		_rig_force(Vector2(0.0, -excess * 5.5))

	_apply_balance(body, entity_id)
	var max_speed := maxf(1.0, _profile_float("move_speed", _default_speed(entity_id)))
	set_rig_state(state, {
		"direction": horizontal,
		"moving": moving,
		"speed_ratio": clampf(body.linear_velocity.length() / max_speed, 0.0, 1.5),
		"charge_ratio": clampf(_charge / maxf(0.01, _profile_float("charge_time", 0.8)), 0.0, 1.0),
		"vertical_speed": body.linear_velocity.y
	})
	_update_camera_anchor(false)


func _drive_grounded(body: ActiveRigBody2D, horizontal: float) -> String:
	_set_rig_gravity(1.0)
	_drive_horizontal(body, horizontal, _profile_float("move_speed", _default_speed(String(entity_metadata.get("id", "")))))
	if Input.is_action_just_pressed("jump") and body.grounded:
		_rig_impulse(Vector2(0.0, -_profile_float("jump_impulse", 330.0)))
		return "jump"
	if not body.grounded:
		return "jump" if body.linear_velocity.y < 0.0 else "fall"
	return "walk" if absf(horizontal) > 0.05 else "idle"


func _drive_spider(body: ActiveRigBody2D, horizontal: float, vertical: float) -> String:
	if (body.wall_contact or body.ceiling_contact) and absf(vertical) > 0.05:
		_set_rig_gravity(0.0)
		_rig_force(Vector2(0.0, vertical * 1550.0))
		_rig_force(-body.dominant_surface_normal * 520.0)
		return "climb"
	_set_rig_gravity(1.0)
	_drive_horizontal(body, horizontal, 180.0)
	if Input.is_action_just_pressed("jump") and (body.grounded or body.wall_contact):
		_rig_impulse(Vector2(horizontal * 90.0, -300.0))
		return "jump"
	if not body.grounded:
		return "fall"
	return "walk" if absf(horizontal) > 0.05 else "idle"


func _drive_flier(body: ActiveRigBody2D, horizontal: float, _delta: float, butterfly: bool) -> String:
	_set_rig_gravity(0.34 if butterfly else 0.82)
	_drive_horizontal(body, horizontal, 220.0 if butterfly else 245.0)
	if Input.is_action_just_pressed("jump"):
		_rig_impulse(Vector2(0.0, -250.0 if butterfly else -330.0))
		return "flap"
	if Input.is_action_pressed("jump"):
		if butterfly:
			_rig_force(Vector2(0.0, -390.0))
			return "fly"
		if body.linear_velocity.y > 105.0:
			_rig_force(Vector2(0.0, -(body.linear_velocity.y - 105.0) * 6.0))
			return "glide"
	if body.grounded:
		return "walk" if absf(horizontal) > 0.05 else "idle"
	return "fly"


func _drive_fish(body: ActiveRigBody2D, input_vector: Vector2) -> String:
	if is_in_water():
		_set_rig_gravity(0.0)
		body.linear_damp = 1.5
		if input_vector.length() > 1.0:
			input_vector = input_vector.normalized()
		var target := input_vector * 260.0
		_rig_force((target - body.linear_velocity) * 7.0)
		if input_vector.length() > 0.1:
			var desired := input_vector.angle()
			body.apply_torque(clampf(wrapf(desired - body.rotation, -PI, PI) * 900.0 - body.angular_velocity * 90.0, -1800.0, 1800.0))
		return "swim" if input_vector.length() > 0.05 else "idle"
	_set_rig_gravity(1.0)
	body.linear_damp = 0.25
	if Input.is_action_just_pressed("jump") and body.grounded:
		_rig_impulse(Vector2(80.0 if input_vector.x >= 0.0 else -80.0, -145.0))
	return "fall" if not body.grounded else "idle"


func _drive_snake(body: ActiveRigBody2D, input_vector: Vector2) -> String:
	if is_in_water():
		_set_rig_gravity(0.0)
		if input_vector.length() > 1.0:
			input_vector = input_vector.normalized()
		_rig_force((input_vector * 225.0 - body.linear_velocity) * 5.0)
		return "swim" if input_vector.length() > 0.05 else "idle"
	_set_rig_gravity(1.0)
	_drive_horizontal(body, input_vector.x, 205.0)
	if Input.is_action_just_pressed("jump") and body.grounded:
		_rig_impulse(Vector2(input_vector.x * 85.0, -210.0))
		return "jump"
	return "walk" if absf(input_vector.x) > 0.05 else ("fall" if not body.grounded else "idle")


func _drive_hopper(body: ActiveRigBody2D, horizontal: float, delta: float, rabbit: bool) -> String:
	_set_rig_gravity(1.0)
	if not body.grounded:
		return "jump" if body.linear_velocity.y < 0.0 else "fall"
	if rabbit and Input.is_action_just_pressed("jump"):
		_rig_impulse(Vector2(horizontal * 185.0, -430.0))
		return "jump"
	if not rabbit:
		if Input.is_action_pressed("jump"):
			_charge = minf(_profile_float("charge_time", 0.8), _charge + delta)
			return "charge"
		if Input.is_action_just_released("jump"):
			var charge_time := _profile_float("charge_time", 0.8)
			var ratio := clampf(_charge / maxf(0.01, charge_time), 0.0, 1.0)
			_charge = 0.0
			var lift := lerpf(250.0, 620.0, ratio)
			_rig_impulse(Vector2(horizontal * 180.0, -lift))
			return "jump"
	return "idle"


func _drive_ladder(body: ActiveRigBody2D, vertical: float) -> String:
	if not is_instance_valid(_ladder):
		_ladder = null
		return "idle"
	_set_rig_gravity(0.0)
	var axis := -_ladder.global_transform.y.normalized()
	var along_velocity := body.linear_velocity.dot(axis)
	var target := -vertical * 155.0
	_rig_force(axis * (target - along_velocity) * 9.0)
	var lateral := _ladder.global_position - body.global_position
	_rig_force(lateral.slide(axis) * 10.0)
	if Input.is_action_just_pressed("jump"):
		end_ladder()
		_set_rig_gravity(1.0)
		_rig_impulse(Vector2(0.0, -250.0))
		return "jump"
	return "climb" if absf(vertical) > 0.05 else "idle"


func _drive_horizontal(body: ActiveRigBody2D, input_axis: float, speed: float) -> void:
	var target := input_axis * speed
	var error := target - body.linear_velocity.x
	# Accelerate the WHOLE rig, not just the torso. The torso is only a small
	# fraction of the total mass, so a torso-only force is instantly cancelled by
	# the friction and weight of every grounded limb and the creature never moves.
	var accel := clampf(error * 6.0, -1700.0, 1700.0)
	_rig_force(Vector2(accel, 0.0))


func _drive_targets() -> Array:
	if _drive_bodies.is_empty():
		_refresh_drive_bodies()
	return _drive_bodies


func _refresh_drive_bodies() -> void:
	var skin := _get_skin()
	if skin != null and skin.has_method("get_rigid_bodies"):
		_drive_bodies = skin.call("get_rigid_bodies")
	else:
		_drive_bodies = []


## Apply a per-unit-mass force to every rig body so the articulated creature
## translates as one cohesive unit. force_per_mass is an acceleration (px/s^2).
func _rig_force(force_per_mass: Vector2) -> void:
	for candidate in _drive_targets():
		var b := candidate as RigidBody2D
		if b != null and is_instance_valid(b):
			b.apply_central_force(force_per_mass * b.mass)


## Apply a per-unit-mass impulse to every rig body (a whole-rig velocity change).
func _rig_impulse(impulse_per_mass: Vector2) -> void:
	for candidate in _drive_targets():
		var b := candidate as RigidBody2D
		if b != null and is_instance_valid(b):
			b.apply_central_impulse(impulse_per_mass * b.mass)


## Set gravity on every rig body together so climb/fly/swim modes float the whole
## creature instead of only the torso while the limbs keep falling.
func _set_rig_gravity(scale: float) -> void:
	for candidate in _drive_targets():
		var b := candidate as RigidBody2D
		if b != null and is_instance_valid(b):
			b.gravity_scale = scale


func _apply_balance(body: ActiveRigBody2D, entity_id: String) -> void:
	if entity_id in ["fish", "snake"] or (entity_id in ["bird", "butterfly"] and not body.grounded):
		return
	var target_rotation := 0.0
	if _ladder != null and is_instance_valid(_ladder):
		target_rotation = _ladder.global_rotation
	elif entity_id == "spider" and (body.wall_contact or body.ceiling_contact):
		target_rotation = body.dominant_surface_normal.angle() + PI * 0.5
	# Right the torso only. The muscle controller already owns the limbs' angles;
	# torquing every body toward upright fought the gait and curled the creature
	# into a rollable ball. A strong torso-only righting spring keeps the root
	# upright and the joints carry the limbs along.
	var error := wrapf(target_rotation - body.rotation, -PI, PI)
	var torque_limit := body.mass * 3200.0
	var torque := clampf(error * body.mass * 2200.0 - body.angular_velocity * body.mass * 240.0, -torque_limit, torque_limit)
	body.apply_torque(torque)


func _ensure_camera_anchor() -> void:
	if _camera_anchor != null and is_instance_valid(_camera_anchor):
		return
	_camera_anchor = Marker2D.new()
	_camera_anchor.name = "StableCameraAnchor"
	add_child(_camera_anchor)


func _update_camera_anchor(snap: bool) -> void:
	_ensure_camera_anchor()
	var body := get_physics_anchor()
	if body == null:
		return
	var position := body.global_position
	if not is_finite(position.x) or not is_finite(position.y):
		return
	var bounds_end := _world_bounds.end
	position.x = clampf(position.x, _world_bounds.position.x, bounds_end.x)
	position.y = clampf(position.y, _world_bounds.position.y, bounds_end.y)
	if snap or not is_finite(_camera_anchor.global_position.x) or not is_finite(_camera_anchor.global_position.y):
		_camera_anchor.global_position = position
	else:
		_camera_anchor.global_position = _camera_anchor.global_position.lerp(position, 0.35)


func _vector_is_finite(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


func _default_speed(entity_id: String) -> float:
	match entity_id:
		"spider": return 180.0
		"cat": return 225.0
		"dog": return 215.0
		"rabbit": return 210.0
		"frog": return 180.0
		"bird": return 245.0
		"butterfly": return 220.0
		"fish": return 260.0
		"snake": return 205.0
		_: return 240.0


func _get_skin() -> Node:
	var skin := get_node_or_null(skin_node_path)
	if skin == null:
		skin = find_child("DrawingSkin", true, false)
	return skin


func _load_rig_profile(profile_path: String) -> Dictionary:
	if profile_path.is_empty():
		return {}
	var text := FileAccess.get_file_as_string(profile_path)
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func _profile_float(key: String, fallback: float) -> float:
	var value: Variant = rig_profile.get(key, fallback)
	return float(value) if typeof(value) in [TYPE_FLOAT, TYPE_INT] else fallback
