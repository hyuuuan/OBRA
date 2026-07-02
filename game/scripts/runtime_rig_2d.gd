extends "res://scripts/drawing_skin_2d.gd"
class_name RuntimeRig2D
## Class-guided procedural animation for a player's original drawing.

var _strategy: String = "none"
var _motion_state: String = "idle"
var _motion_params: Dictionary = {}
var _phase: float = 0.0
var _impact_timer: float = 0.0
var _impact_duration: float = 0.18
var _facing: float = 1.0
var _limb_overlay_root: Node2D
var _limb_lines: Array = []
var _limb_specs: Array = []
var _limb_base_points: Array = []


func configure_rig(new_profile: Dictionary, new_entity_metadata: Dictionary = {}) -> void:
	configure_skin(new_profile, new_entity_metadata)
	_strategy = _profile_string(
		"deform_strategy",
		String(new_entity_metadata.get("deform_strategy", "none"))
	)
	if _strategy.is_empty():
		_strategy = "none"


func apply_drawing(drawing: Image) -> Dictionary:
	var result := super.apply_drawing(drawing)
	_prepare_deformation_nodes()
	return result


func set_motion_state(state: String, params: Dictionary = {}) -> void:
	_motion_state = state
	_motion_params = params.duplicate(true)
	var direction := _param_float("direction", 0.0)
	if absf(direction) > 0.05:
		_facing = 1.0 if direction > 0.0 else -1.0
	if state == "landed":
		_impact_timer = _impact_duration


func _process(delta: float) -> void:
	if not has_texture():
		return

	_phase += delta
	_impact_timer = maxf(0.0, _impact_timer - delta)

	match _strategy:
		"spline":
			_animate_spline()
		"squash":
			_animate_squash()
		"flap":
			_animate_flap()
		"limb_template":
			_animate_limb_template()
		_:
			_animate_none()


func _prepare_deformation_nodes() -> void:
	if _strategy == "spline":
		_clear_limb_overlay()
		_rebuild_segments(_profile_int("segments", 5))
		_set_body_visible(false)
	elif _strategy == "limb_template":
		_clear_segments()
		_set_body_visible(true)
		_rebuild_limb_overlay()
	else:
		_clear_segments()
		_clear_limb_overlay()
		_set_body_visible(true)


func _animate_none() -> void:
	reset_body_transform()


func _animate_spline() -> void:
	if _segment_roots.is_empty():
		_prepare_deformation_nodes()
		return

	_set_body_visible(false)
	var speed_ratio := clampf(_param_float("speed_ratio", 0.0), 0.0, 1.0)
	var activity := maxf(0.25, speed_ratio)
	var amplitude := _profile_float("spline_amplitude", 5.0)
	var bonus := _profile_float("speed_amplitude_bonus", 1.0)
	var rotation_degrees := _profile_float("spline_rotation_degrees", 6.0)
	var frequency := _profile_float("spline_frequency", 5.5)
	var phase_step := _profile_float("spline_phase_step", 0.7)
	var idle_bob := sin(_phase * _profile_float("idle_frequency", 1.2)) * _profile_float("idle_bob", 0.0)

	for index in range(_segment_roots.size()):
		var segment := _segment_roots[index] as Node2D
		if segment == null:
			continue
		var wave := sin(_phase * frequency + float(index) * phase_step)
		var base_position: Vector2 = _segment_base_positions[index]
		var local_strength := activity * bonus
		segment.position = base_position + Vector2(0.0, idle_bob + wave * amplitude * local_strength)
		segment.rotation = deg_to_rad(wave * rotation_degrees * local_strength)


func _animate_squash() -> void:
	var squash := Vector2.ONE
	var offset := Vector2.ZERO
	var rotation := 0.0
	var bob := sin(_phase * _profile_float("idle_frequency", 1.2)) * _profile_float("idle_bob", 0.0)
	var direction := _param_float("direction", 0.0)

	match _motion_state:
		"charge":
			var amount := _profile_float("charge_squash", 0.2) * clampf(_param_float("charge_ratio", 0.0), 0.0, 1.0)
			squash = Vector2(1.0 + amount, 1.0 - amount)
			offset.y += amount * 24.0
		"jump", "jumping":
			var amount := _profile_float("jump_stretch", 0.12)
			squash = Vector2(1.0 - amount * 0.5, 1.0 + amount)
			offset.y -= amount * 20.0
		"fall", "falling":
			var amount := _profile_float("jump_stretch", 0.12) * 0.5
			squash = Vector2(1.0 - amount * 0.4, 1.0 + amount)
		"landed":
			var amount := _profile_float("landing_squash", 0.18) * _impact_ratio()
			squash = Vector2(1.0 + amount, 1.0 - amount)
			offset.y += amount * 18.0
		_:
			offset.y += bob

	rotation = deg_to_rad(direction * _profile_float("tilt_degrees", 4.0))
	_apply_body_transform(offset, squash, rotation)


func _animate_flap() -> void:
	var squash := Vector2.ONE
	var offset := Vector2.ZERO
	var direction := _param_float("direction", 0.0)
	var vertical_speed := _param_float("vertical_speed", 0.0)
	var rotation := deg_to_rad(direction * _profile_float("tilt_degrees", 7.0))

	if _motion_state == "flap":
		var pulse := absf(sin(_phase * _profile_float("flap_frequency", 9.0)))
		var amount := _profile_float("flap_squash", 0.14) * pulse
		squash = Vector2(1.0 + amount, 1.0 - amount)
		offset.y -= _profile_float("flap_lift", 5.0) * pulse
	elif _motion_state == "glide":
		var amount := _profile_float("glide_stretch", 0.08)
		squash = Vector2(1.0 + amount, 1.0 - amount * 0.5)
		rotation += deg_to_rad(clampf(vertical_speed / 500.0, -1.0, 1.0) * 5.0)
	else:
		offset.y += sin(_phase * _profile_float("idle_frequency", 1.4)) * _profile_float("idle_bob", 1.0)

	_apply_body_transform(offset, squash, rotation)


func _animate_limb_template() -> void:
	var squash := Vector2.ONE
	var offset := Vector2.ZERO
	var direction := _param_float("direction", 0.0)
	var rotation := deg_to_rad(direction * _profile_float("tilt_degrees", 4.0))
	var moving := bool(_motion_params.get("moving", false))

	if _motion_state == "walk" or _motion_state == "climb" or moving:
		var frequency := _profile_float("walk_frequency", 7.0)
		if _motion_state == "climb":
			frequency = _profile_float("climb_frequency", frequency)
		var step := absf(sin(_phase * frequency))
		var bob_key := "climb_bob" if _motion_state == "climb" else "walk_bob"
		offset.y += step * _profile_float(bob_key, 3.0)
		var amount := step * _profile_float("walk_squash", 0.04)
		squash = Vector2(1.0 + amount, 1.0 - amount)
	elif _motion_state == "jump" or _motion_state == "jumping":
		var amount := _profile_float("jump_stretch", 0.1)
		squash = Vector2(1.0 - amount * 0.5, 1.0 + amount)
		offset.y -= amount * 18.0
	elif _motion_state == "fall" or _motion_state == "falling":
		var amount := _profile_float("jump_stretch", 0.1) * 0.45
		squash = Vector2(1.0 - amount * 0.35, 1.0 + amount)
	elif _motion_state == "landed":
		var amount := _profile_float("landing_squash", 0.14) * _impact_ratio()
		squash = Vector2(1.0 + amount, 1.0 - amount)
		offset.y += amount * 16.0
	else:
		offset.y += sin(_phase * _profile_float("idle_frequency", 1.1)) * _profile_float("idle_bob", 0.0)

	_apply_body_transform(offset, squash, rotation)
	_update_limb_overlay()


func _apply_body_transform(offset: Vector2, squash: Vector2, rotation: float) -> void:
	_ensure_body()
	if _body == null:
		return
	_set_body_visible(true)
	_body.position = _body_base_position + offset
	_body.scale = Vector2(_body_base_scale.x * squash.x * _facing, _body_base_scale.y * squash.y)
	_body.rotation = rotation
	if _limb_overlay_root != null:
		_limb_overlay_root.position = _body.position
		_limb_overlay_root.scale = _body.scale
		_limb_overlay_root.rotation = _body.rotation


func _impact_ratio() -> float:
	if _impact_duration <= 0.0:
		return 0.0
	return clampf(_impact_timer / _impact_duration, 0.0, 1.0)


func _param_float(key: String, default_value: float) -> float:
	var value: Variant = _motion_params.get(key, default_value)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return default_value


func _rebuild_limb_overlay() -> void:
	_clear_limb_overlay()
	if _texture == null:
		return

	var alpha := _profile_float("limb_overlay_alpha", 0.0)
	var limbs: Variant = profile.get("limbs", [])
	if alpha <= 0.0 or not (limbs is Array):
		return

	_limb_overlay_root = Node2D.new()
	_limb_overlay_root.name = "LimbOverlay"
	add_child(_limb_overlay_root)

	for raw_limb in limbs:
		if not (raw_limb is Dictionary):
			continue
		var limb: Dictionary = raw_limb
		var start := _normalized_texture_point(_dict_vector2(limb, "from", Vector2(0.5, 0.5)))
		var end := _normalized_texture_point(_dict_vector2(limb, "to", Vector2(0.5, 0.5)))

		var line := Line2D.new()
		line.default_color = Color(0.0, 0.0, 0.0, alpha)
		line.width = _profile_float("limb_width", 4.0)
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.add_point(start)
		line.add_point(end)
		_limb_overlay_root.add_child(line)

		_limb_lines.append(line)
		_limb_specs.append(limb.duplicate(true))
		_limb_base_points.append([start, end])


func _clear_limb_overlay() -> void:
	if _limb_overlay_root != null and is_instance_valid(_limb_overlay_root):
		_limb_overlay_root.queue_free()
	_limb_overlay_root = null
	_limb_lines.clear()
	_limb_specs.clear()
	_limb_base_points.clear()


func _update_limb_overlay() -> void:
	if _limb_lines.is_empty():
		return

	var frequency := _profile_float("walk_frequency", 7.0)
	if _motion_state == "climb":
		frequency = _profile_float("climb_frequency", frequency)
	var swing := _profile_float("limb_swing", 18.0)
	var activity := 1.0 if bool(_motion_params.get("moving", false)) else 0.25

	for index in range(_limb_lines.size()):
		var line := _limb_lines[index] as Line2D
		if line == null:
			continue
		var spec: Dictionary = _limb_specs[index]
		var base_points: Array = _limb_base_points[index]
		var phase := _dict_float(spec, "phase", 0.0)
		var axis := _dict_vector2(spec, "axis", Vector2(1.0, 0.0))
		if axis.length() <= 0.001:
			axis = Vector2(1.0, 0.0)
		axis = axis.normalized()

		var start: Vector2 = base_points[0]
		var end: Vector2 = base_points[1]
		var wave := sin(_phase * frequency + phase)
		line.set_point_position(0, start)
		line.set_point_position(1, end + axis * wave * swing * activity)


func _normalized_texture_point(normalized: Vector2) -> Vector2:
	if _texture == null:
		return Vector2.ZERO
	return (normalized - Vector2(0.5, 0.5)) * _texture.get_size()


func _dict_float(source: Dictionary, key: String, default_value: float) -> float:
	var value: Variant = source.get(key, default_value)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return default_value


func _dict_vector2(source: Dictionary, key: String, default_value: Vector2) -> Vector2:
	var value: Variant = source.get(key)
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return default_value
