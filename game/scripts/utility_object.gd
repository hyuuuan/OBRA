class_name UtilityObject
extends "res://scripts/physics_shape_object.gd"
## One placed/equipped instance of a drawn utility. Unique behavior is selected
## by manifest metadata; future level targets integrate through method checks.

signal pickup_requested(utility: UtilityObject)
signal equipped(utility: UtilityObject, actor: Node2D)
signal utility_used(behavior: String, item: DrawnItemData)
signal utility_consumed(utility: UtilityObject)

var item_data: DrawnItemData
var utility_behavior: String = ""
var required_medium: String = "any"
var is_preview: bool = false

var _active: bool = false
var _settle_time: float = 0.0
var _equipped_actor: Node2D
var _boarded_actor: Node2D
var _light_cone: Polygon2D
var _point_light: PointLight2D
var _interaction_area: Area2D
var _vehicle_joint: PinJoint2D


func _ready() -> void:
	controllable = false
	super._ready()
	_create_interaction_area()
	if utility_behavior == "flashlight":
		_create_flashlight_nodes()
	add_to_group("drawn_utilities")


func configure_entity(entry: Dictionary) -> void:
	super.configure_entity(entry)
	controllable = false
	utility_behavior = String(entry.get("utility_behavior", entry.get("id", "")))
	required_medium = String(entry.get("required_medium", "any"))


func apply_item_data(item: DrawnItemData) -> void:
	item_data = item
	super.apply_item_data(item)
	if not item.runtime_state.is_empty():
		restore_utility_state(item.runtime_state)


func set_preview(enabled: bool) -> void:
	is_preview = enabled
	freeze = enabled
	gravity_scale = 0.0 if enabled else gravity_scale
	collision_layer = 0 if enabled else 1
	collision_mask = 1
	modulate = Color(0.45, 1.0, 0.55, 0.65) if enabled else Color.WHITE
	if _interaction_area != null:
		_interaction_area.monitoring = not enabled


func set_preview_valid(valid: bool) -> void:
	if is_preview:
		modulate = Color(0.45, 1.0, 0.55, 0.65) if valid else Color(1.0, 0.35, 0.32, 0.65)


func confirm_placement() -> void:
	is_preview = false
	freeze = false
	gravity_scale = 1.0
	collision_layer = 1
	collision_mask = 1
	modulate = Color.WHITE
	sleeping = false
	if item_data != null:
		item_data.placement_transform = global_transform


func interact(actor: Node2D) -> void:
	if actor == null:
		return
	if utility_behavior == "ladder" and freeze:
		if actor.has_method("is_using_ladder") and bool(actor.call("is_using_ladder", self)):
			actor.call("end_ladder")
			pickup_requested.emit(self)
			return
		if actor.has_method("begin_ladder"):
			actor.call("begin_ladder", self)
			utility_used.emit(utility_behavior, item_data)
		return
	if utility_behavior == "sailboat" and _is_in_water():
		if _boarded_actor == actor:
			_unboard_actor()
			return
		_board_actor(actor)
		return
	if _equipped_actor == actor:
		pickup_requested.emit(self)
		return
	if utility_behavior in ["axe", "key", "umbrella", "flashlight"]:
		equip_to(actor)
	else:
		pickup_requested.emit(self)


func equip_to(actor: Node2D) -> void:
	var grip: Node2D = actor.call("get_grip_anchor") as Node2D if actor.has_method("get_grip_anchor") else actor
	if grip == null:
		return
	_equipped_actor = actor
	freeze = true
	collision_layer = 0
	collision_mask = 0
	reparent(grip, false)
	position = Vector2.ZERO
	rotation = 0.0
	if actor.has_method("set_equipped_utility"):
		actor.call("set_equipped_utility", self)
	equipped.emit(self, actor)


func prepare_for_inventory() -> DrawnItemData:
	if item_data == null:
		return null
	item_data.save_world_state(self)
	if _equipped_actor != null and is_instance_valid(_equipped_actor):
		if utility_behavior == "umbrella" and _equipped_actor.has_method("set_umbrella_open"):
			_equipped_actor.call("set_umbrella_open", false)
		if _equipped_actor.has_method("set_equipped_utility"):
			_equipped_actor.call("set_equipped_utility", null)
	_equipped_actor = null
	_unboard_actor()
	return item_data


func drop_to_world(world_root: Node2D, at: Vector2) -> void:
	if world_root == null:
		return
	if _equipped_actor != null and is_instance_valid(_equipped_actor):
		if utility_behavior == "umbrella" and _equipped_actor.has_method("set_umbrella_open"):
			_equipped_actor.call("set_umbrella_open", false)
		if _equipped_actor.has_method("set_equipped_utility"):
			_equipped_actor.call("set_equipped_utility", null)
	_equipped_actor = null
	reparent(world_root, true)
	global_position = at
	freeze = false
	gravity_scale = 1.0
	collision_layer = 1
	collision_mask = 1
	sleeping = false


func use_utility(actor: Node2D) -> bool:
	if actor == null or (_equipped_actor != null and actor != _equipped_actor):
		return false
	match utility_behavior:
		"axe":
			_swing_axe(actor)
		"key":
			_use_key(actor)
		"umbrella":
			_active = not _active
			if actor.has_method("set_umbrella_open"):
				actor.call("set_umbrella_open", _active)
			scale = Vector2(1.22, 0.86) if _active else Vector2.ONE
		"flashlight":
			_active = not _active
			_set_light_active(_active)
		"sailboat":
			return _boarded_actor == actor
		_:
			return false
	utility_used.emit(utility_behavior, item_data)
	return true


func serialize_utility_state() -> Dictionary:
	return {
		"active": _active,
		"settled": freeze and utility_behavior == "ladder"
	}


func restore_utility_state(state: Dictionary) -> void:
	_active = bool(state.get("active", false))
	if utility_behavior == "flashlight":
		_set_light_active(_active)
	if utility_behavior == "ladder" and bool(state.get("settled", false)):
		freeze = true


func _physics_process(delta: float) -> void:
	if is_preview:
		return
	if utility_behavior == "ladder" and not freeze:
		if _grounded and linear_velocity.length() < 8.0 and absf(angular_velocity) < 0.18:
			_settle_time += delta
			if _settle_time >= 0.75:
				freeze = true
				linear_velocity = Vector2.ZERO
				angular_velocity = 0.0
		else:
			_settle_time = 0.0
	if utility_behavior == "sailboat" and _is_in_water() and _boarded_actor != null:
		var horizontal := Input.get_axis("move_left", "move_right")
		apply_central_force(Vector2(horizontal * mass * 900.0, 0.0))
		apply_torque(horizontal * 240.0)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	_grounded = _has_ground_contact(state)
	if utility_behavior != "sailboat" or not _is_in_water():
		return
	gravity_scale = 0.18
	var velocity := state.linear_velocity
	state.apply_central_force(-state.total_gravity * mass * 0.82)
	state.apply_central_force(-velocity * mass * 2.4)
	state.apply_torque(-state.angular_velocity * mass * 1.8)


func _swing_axe(actor: Node2D) -> void:
	for candidate in _interaction_candidates():
		var target := candidate as Node
		if target != null and target.has_method("apply_tool_hit"):
			target.call("apply_tool_hit", "axe", 420.0, actor)
		elif target != null and target.get_parent() != null and target.get_parent().has_method("apply_tool_hit"):
			target.get_parent().call("apply_tool_hit", "axe", 420.0, actor)
	var tween := create_tween()
	tween.tween_property(self, "rotation", deg_to_rad(72.0), 0.11).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "rotation", 0.0, 0.16).set_trans(Tween.TRANS_BACK)


func _use_key(_actor: Node2D) -> void:
	for candidate in _interaction_candidates():
		var target := candidate as Node
		if target != null and target.has_method("try_unlock"):
			_handle_unlock_result(target.call("try_unlock", "drawn_key", item_data))
			return
		if target != null and target.get_parent() != null and target.get_parent().has_method("try_unlock"):
			_handle_unlock_result(target.get_parent().call("try_unlock", "drawn_key", item_data))
			return


func _interaction_candidates() -> Array:
	var candidates: Array = []
	if _interaction_area != null:
		candidates.append_array(_interaction_area.get_overlapping_bodies())
		candidates.append_array(_interaction_area.get_overlapping_areas())
	var shape := RectangleShape2D.new()
	shape.size = _target_size() + Vector2(72.0, 72.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = 1
	query.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 24):
		var collider: Variant = hit.get("collider")
		if collider is Node and collider not in candidates:
			candidates.append(collider)
	return candidates


func _handle_unlock_result(result: Variant) -> void:
	if result is Dictionary and bool(result.get("consumed", false)):
		if _equipped_actor != null and is_instance_valid(_equipped_actor) and _equipped_actor.has_method("set_equipped_utility"):
			_equipped_actor.call("set_equipped_utility", null)
		utility_consumed.emit(self)


func _board_actor(actor: Node2D) -> void:
	_unboard_actor()
	var anchor := actor.call("get_physics_anchor") as RigidBody2D if actor.has_method("get_physics_anchor") else null
	if anchor == null:
		return
	_boarded_actor = actor
	var seat_position := global_position + Vector2(0.0, -_target_size().y * 0.25).rotated(global_rotation)
	if actor.has_method("apply_morph_state"):
		actor.call("apply_morph_state", {
			"position": seat_position,
			"linear_velocity": linear_velocity,
			"rotation": global_rotation,
			"angular_velocity": angular_velocity
		})
	_vehicle_joint = PinJoint2D.new()
	_vehicle_joint.name = "BoardingJoint"
	_vehicle_joint.global_position = seat_position
	get_parent().add_child(_vehicle_joint)
	_vehicle_joint.node_a = _vehicle_joint.get_path_to(self)
	_vehicle_joint.node_b = _vehicle_joint.get_path_to(anchor)
	_vehicle_joint.disable_collision = true
	utility_used.emit(utility_behavior, item_data)


func _unboard_actor() -> void:
	_boarded_actor = null
	if _vehicle_joint != null and is_instance_valid(_vehicle_joint):
		_vehicle_joint.queue_free()
	_vehicle_joint = null


func _create_interaction_area() -> void:
	_interaction_area = Area2D.new()
	_interaction_area.name = "InteractionArea"
	_interaction_area.collision_layer = 0
	_interaction_area.collision_mask = 1
	_interaction_area.monitoring = true
	add_child(_interaction_area)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = _target_size() + Vector2(72.0, 72.0)
	collision.shape = shape
	_interaction_area.add_child(collision)


func _create_flashlight_nodes() -> void:
	_light_cone = Polygon2D.new()
	_light_cone.name = "VisibleLightCone"
	_light_cone.polygon = PackedVector2Array([
		Vector2(20.0, -8.0), Vector2(230.0, -92.0),
		Vector2(230.0, 92.0), Vector2(20.0, 8.0)
	])
	_light_cone.color = Color(1.0, 0.92, 0.55, 0.22)
	_light_cone.z_index = -1
	add_child(_light_cone)
	_point_light = PointLight2D.new()
	_point_light.name = "LightCone"
	_point_light.texture = _make_cone_texture()
	_point_light.texture_scale = 1.2
	_point_light.energy = 1.25
	_point_light.position = Vector2(96.0, 0.0)
	add_child(_point_light)
	_set_light_active(_active)


func _make_cone_texture() -> ImageTexture:
	var image := Image.create(256, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for x in range(128, 256):
		var ratio := float(x - 128) / 128.0
		var half_height := 6.0 + ratio * 56.0
		for y in range(64 - int(half_height), 64 + int(half_height) + 1):
			var edge := absf(float(y - 64)) / maxf(1.0, half_height)
			var alpha := (1.0 - edge) * (1.0 - ratio * 0.7)
			image.set_pixel(x, y, Color(1.0, 0.94, 0.68, alpha))
	return ImageTexture.create_from_image(image)


func _set_light_active(enabled: bool) -> void:
	if _light_cone != null:
		_light_cone.visible = enabled
	if _point_light != null:
		_point_light.enabled = enabled


func _is_in_water() -> bool:
	return int(get_meta("water_overlap_count", 0)) > 0
