class_name RuntimeRig2D
extends "res://scripts/drawing_skin_2d.gd"
## Converts normalized drawing strokes into a bounded active-ragdoll graph.
## Every visible articulated section is parented to the RigidBody2D that owns
## its collision, so vector ink and physics can never drift apart.

signal rig_built(success: bool)

const MAX_BODIES := 24
const MAX_JOINTS := 23
const MAX_SHAPES := 64
const MAX_SEGMENTS_PER_LIMB := 3
const MIN_SEGMENT_LENGTH := 8.0

var _rig_type: String = "none"
var _entity_id: String = ""
var _motion_state: String = "idle"
var _motion_params: Dictionary = {}

var _physics_root: Node2D
var _primary_body: ActiveRigBody2D
var _bodies: Array[ActiveRigBody2D] = []
var _joints: Array[PinJoint2D] = []
var _segments: Array = []
var _body_pool: PackedVector2Array = PackedVector2Array()
var _shape_count: int = 0
var _gait_phase: float = 0.0
var _build_generation: int = 0


func configure_rig(new_profile: Dictionary, new_entity_metadata: Dictionary = {}) -> void:
	configure_skin(new_profile, new_entity_metadata)
	_rig_type = _profile_string("rig_type", String(new_entity_metadata.get("rig_type", "none")))
	_entity_id = String(new_entity_metadata.get("id", ""))


func set_motion_state(state: String, params: Dictionary = {}) -> void:
	_motion_state = state
	_motion_params = params.duplicate(true)


func get_primary_body() -> ActiveRigBody2D:
	return _primary_body


func get_rigid_bodies() -> Array[ActiveRigBody2D]:
	return _bodies.duplicate()


func get_joint_count() -> int:
	return _joints.size()


func debug_segment_roles() -> Array[String]:
	var roles: Array[String] = []
	for value in _segments:
		roles.append(String((value as Dictionary).get("role", "")))
	return roles


func debug_motor_velocities() -> Array[float]:
	var velocities: Array[float] = []
	for joint in _joints:
		velocities.append(joint.motor_target_velocity)
	return velocities


func is_in_water() -> bool:
	return _primary_body != null and int(_primary_body.get_meta("water_overlap_count", 0)) > 0


func rig_summary() -> String:
	if _primary_body == null:
		return "%s/no-body" % skin_mode()
	return "%s/%d bodies/%d joints" % [skin_mode(), _bodies.size(), _joints.size()]


func _on_skin_rebuilt() -> void:
	_build_generation += 1
	_clear_rig()
	if skin_mode() == "vector" and not get_vector_strokes().is_empty():
		if _entity_id == "snake":
			_build_chain_rig(get_vector_strokes())
		else:
			_build_standard_rig(get_vector_strokes())
	else:
		_build_bitmap_fallback()
	_finalize_rig()
	analysis["physics_bodies"] = _bodies.size()
	analysis["physics_joints"] = _joints.size()
	analysis["active_ragdoll"] = _joints.size() > 0
	rig_built.emit(_primary_body != null)


func _physics_process(delta: float) -> void:
	if _primary_body == null or _segments.is_empty():
		return
	var speed_ratio := clampf(float(_motion_params.get("speed_ratio", 0.0)), 0.0, 1.5)
	if bool(_motion_params.get("moving", false)) or _motion_state in ["swim", "fly", "flap", "climb"]:
		_gait_phase += delta * lerpf(2.0, 7.0, minf(1.0, speed_ratio))

	for segment_value in _segments:
		var segment: Dictionary = segment_value
		var parent := segment["parent"] as ActiveRigBody2D
		var child := segment["body"] as ActiveRigBody2D
		var joint := segment["joint"] as PinJoint2D
		if not is_instance_valid(parent) or not is_instance_valid(child) or not is_instance_valid(joint):
			continue
		var target := _target_angle_for(segment)
		var current := wrapf(child.rotation - parent.rotation - float(segment["rest_relative"]), -PI, PI)
		var error := wrapf(target - current, -PI, PI)
		var relative_velocity := child.angular_velocity - parent.angular_velocity
		var target_velocity := clampf(error * 11.0 - relative_velocity * 0.8, -10.0, 10.0)
		joint.motor_target_velocity = target_velocity
		var spring := float(profile.get("joint_spring", 1050.0))
		var damping := float(profile.get("joint_damping", 65.0))
		var torque_limit := float(profile.get("joint_torque_limit", 2600.0))
		var torque := clampf(error * spring - relative_velocity * damping, -torque_limit, torque_limit)
		child.apply_torque(torque)
		parent.apply_torque(-torque)


func _target_angle_for(segment: Dictionary) -> float:
	var role := String(segment["role"])
	var limb_index := int(segment["limb_index"])
	var chain_index := int(segment["chain_index"])
	var direction := float(_motion_params.get("direction", 0.0))
	var phase := _gait_phase + float(segment["phase"]) + float(chain_index) * 0.28
	var moving := bool(_motion_params.get("moving", false))

	if _entity_id == "spider" and role == "leg":
		if _motion_state in ["walk", "climb"] and moving:
			var alternating := 0.0 if limb_index % 2 == 0 else PI
			return deg_to_rad(24.0) * sin(phase + alternating)
		return 0.0

	if _entity_id in ["cat", "dog"] and role == "leg":
		if _motion_state == "walk" and moving:
			var amplitude := deg_to_rad(19.0 if _entity_id == "cat" else 17.0)
			return amplitude * sin(phase + (PI if limb_index % 2 else 0.0))
		if _motion_state in ["jump", "fall"]:
			return deg_to_rad(10.0) * (-1.0 if limb_index % 2 else 1.0)
		return 0.0

	if _rig_type == "biped":
		if _motion_state == "walk" and moving:
			var amp := deg_to_rad(30.0 if role == "leg" else 18.0)
			return amp * sin(phase + (PI if limb_index % 2 else 0.0))
		if _motion_state in ["jump", "fall"]:
			return deg_to_rad(-24.0 if role == "leg" else -35.0) * signf(float(segment["side"]))
		if _motion_state == "climb":
			return deg_to_rad(28.0) * sin(phase + (PI if limb_index % 2 else 0.0))

	if _rig_type == "hopper" and role == "leg":
		match _motion_state:
			"charge":
				return deg_to_rad(-34.0) * maxf(0.15, float(_motion_params.get("charge_ratio", 0.0))) * signf(float(segment["side"]))
			"jump":
				return deg_to_rad(38.0) * signf(float(segment["side"]))
			"fall":
				return deg_to_rad(18.0) * signf(float(segment["side"]))
			_:
				return 0.0

	if _rig_type == "flier":
		if role == "wing":
			if _motion_state in ["fly", "flap"]:
				var hz_scale := 1.25 if _entity_id == "butterfly" else 1.0
				return deg_to_rad(48.0) * sin(phase * hz_scale) * signf(float(segment["side"]))
			if _motion_state == "glide":
				return deg_to_rad(-18.0) * signf(float(segment["side"]))
		if role == "leg" and _motion_state not in ["walk", "idle"]:
			return deg_to_rad(-20.0) * signf(float(segment["side"]))

	if _entity_id == "fish" and role in ["tail", "fin", "limb"]:
		if _motion_state == "swim":
			return deg_to_rad(22.0) * sin(phase + float(limb_index) * 0.55)
		return 0.0

	if _entity_id == "snake" and role == "chain":
		if moving or _motion_state == "swim":
			return deg_to_rad(28.0) * sin(phase + float(chain_index) * 0.72) * (1.0 if direction >= 0.0 else -1.0)
	return 0.0


func _build_standard_rig(strokes: Array) -> void:
	_create_physics_root()
	var body_index := _select_body_stroke(strokes)
	var body_stroke: Dictionary = strokes[body_index]
	var body_points: PackedVector2Array = body_stroke["points"]
	_body_pool = body_points.duplicate()
	var body_center := _points_center(body_points)
	_primary_body = _create_body("Torso", body_center, _mass_for_stroke(body_stroke, 1.5))
	_add_stroke_to_body(_primary_body, body_stroke, body_center, true)

	var attachment_radius := clampf(get_stroke_bounds().size.length() * 0.10, 8.0, 22.0)
	var next_limb_index := 0
	for index in range(strokes.size()):
		if index == body_index:
			continue
		var stroke: Dictionary = strokes[index]
		var points: PackedVector2Array = stroke["points"]
		var paths := _paths_attached_to_body(points, attachment_radius)
		if paths.is_empty() or _stroke_length(points) < MIN_SEGMENT_LENGTH:
			_add_stroke_to_body(_primary_body, stroke, body_center, false)
			continue
		for path_value in paths:
			var path: PackedVector2Array = path_value
			if _stroke_length(path) < MIN_SEGMENT_LENGTH:
				continue
			_build_limb_path(path, stroke, next_limb_index, body_center)
			next_limb_index += 1


func _build_chain_rig(strokes: Array) -> void:
	_create_physics_root()
	var longest: Dictionary = strokes[0]
	for stroke_value in strokes:
		var stroke: Dictionary = stroke_value
		if _stroke_length(stroke["points"]) > _stroke_length(longest["points"]):
			longest = stroke
	var sampled := _sample_points(longest["points"], 13)
	if sampled.size() < 2:
		_build_standard_rig(strokes)
		return
	var parent: ActiveRigBody2D
	for index in range(sampled.size() - 1):
		if _bodies.size() >= MAX_BODIES:
			break
		var pair := PackedVector2Array([sampled[index], sampled[index + 1]])
		var center := (pair[0] + pair[1]) * 0.5
		var body := _create_body("Chain%02d" % index, center, 0.35)
		_add_polyline_to_body(body, pair, float(longest.get("width", 5.0)), Color(longest.get("color", Color.BLACK)), center)
		if index == 0:
			_primary_body = body
			_body_pool = pair.duplicate()
		else:
			var joint := _create_joint(parent, body, sampled[index], deg_to_rad(58.0))
			if joint != null:
				_segments.append({
					"parent": parent,
					"body": body,
					"joint": joint,
					"rest_relative": wrapf(body.rotation - parent.rotation, -PI, PI),
					"role": "chain",
					"limb_index": 0,
					"chain_index": index,
					"phase": 0.0,
					"side": 1.0
				})
		parent = body
	for stroke_value in strokes:
		var stroke: Dictionary = stroke_value
		if stroke == longest:
			continue
		_add_stroke_to_body(_primary_body, stroke, _primary_body.position, false)


func _build_limb_path(
	path: PackedVector2Array,
	stroke: Dictionary,
	limb_index: int,
	body_center: Vector2
) -> void:
	var length := _stroke_length(path)
	var segment_count := clampi(int(ceil(length / 34.0)), 1, MAX_SEGMENTS_PER_LIMB)
	segment_count = mini(segment_count, MAX_BODIES - _bodies.size())
	if segment_count <= 0:
		return
	var parent := _primary_body
	var tip := path[path.size() - 1]
	var role := _role_for_limb(path[0], tip, body_center)
	var side := -1.0 if tip.x < body_center.x else 1.0
	for segment_index in range(segment_count):
		if _joints.size() >= MAX_JOINTS:
			break
		var start_index := int(round(float(segment_index) * float(path.size() - 1) / float(segment_count)))
		var end_index := int(round(float(segment_index + 1) * float(path.size() - 1) / float(segment_count)))
		end_index = maxi(start_index + 1, end_index)
		end_index = mini(path.size() - 1, end_index)
		var chunk := path.slice(start_index, end_index + 1)
		if chunk.size() < 2 or _stroke_length(chunk) < MIN_SEGMENT_LENGTH * 0.45:
			continue
		var center := _points_center(chunk)
		var body := _create_body("Limb%02d_%d" % [limb_index, segment_index], center, _mass_for_points(chunk, float(stroke.get("width", 5.0))))
		_add_polyline_to_body(body, chunk, float(stroke.get("width", 5.0)), Color(stroke.get("color", Color.BLACK)), center)
		var limit := deg_to_rad(82.0 if role == "wing" else 68.0)
		var joint := _create_joint(parent, body, chunk[0], limit)
		if joint == null:
			body.queue_free()
			break
		_segments.append({
			"parent": parent,
			"body": body,
			"joint": joint,
			"rest_relative": wrapf(body.rotation - parent.rotation, -PI, PI),
			"role": role,
			"limb_index": limb_index,
			"chain_index": segment_index,
			"phase": float(limb_index) * 0.37,
			"side": side
		})
		parent = body


func _build_bitmap_fallback() -> void:
	_create_physics_root()
	_primary_body = _create_body("FallbackBody", Vector2.ZERO, 1.2)
	var shape := RectangleShape2D.new()
	shape.size = _target_size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	_primary_body.add_child(collision)
	_shape_count += 1
	if _body != null and _body.texture != null:
		var sprite := Sprite2D.new()
		sprite.texture = _body.texture
		sprite.position = _body.position
		sprite.scale = _body.scale
		_primary_body.add_child(sprite)
		_body.visible = false


func _create_physics_root() -> void:
	_physics_root = Node2D.new()
	_physics_root.name = "GeneratedPhysicsRig"
	get_parent().add_child(_physics_root)


func _create_body(body_name: String, at: Vector2, body_mass: float) -> ActiveRigBody2D:
	var body := ActiveRigBody2D.new()
	body.name = body_name
	body.position = at
	body.mass = clampf(body_mass, 0.18, 5.0)
	body.gravity_scale = 1.0
	body.linear_damp = 0.32
	body.angular_damp = 0.5
	body.max_linear_speed = float(profile.get("max_linear_speed", 850.0))
	body.max_angular_speed = float(profile.get("max_angular_speed", 16.0))
	var material := PhysicsMaterial.new()
	material.friction = float(profile.get("friction", 0.78))
	material.bounce = float(profile.get("bounce", 0.02))
	body.physics_material_override = material
	_physics_root.add_child(body)
	_bodies.append(body)
	return body


func _create_joint(
	parent: ActiveRigBody2D,
	child: ActiveRigBody2D,
	at: Vector2,
	angular_limit: float
) -> PinJoint2D:
	if _joints.size() >= MAX_JOINTS:
		return null
	var joint := PinJoint2D.new()
	joint.name = "Joint%02d" % _joints.size()
	joint.position = at
	_physics_root.add_child(joint)
	joint.node_a = joint.get_path_to(parent)
	joint.node_b = joint.get_path_to(child)
	joint.disable_collision = true
	joint.softness = float(profile.get("joint_softness", 0.05))
	joint.angular_limit_enabled = true
	joint.angular_limit_lower = -angular_limit
	joint.angular_limit_upper = angular_limit
	joint.motor_enabled = true
	_joints.append(joint)
	return joint


func _add_stroke_to_body(
	body: ActiveRigBody2D,
	stroke: Dictionary,
	body_center: Vector2,
	prefer_polygon: bool
) -> void:
	var points: PackedVector2Array = stroke["points"]
	var width := float(stroke.get("width", 5.0))
	var color := Color(stroke.get("color", Color.BLACK))
	_add_visual_line(body, points, width, color, body_center)
	if prefer_polygon and _stroke_is_closed(points, width) and points.size() >= 3:
		var local := PackedVector2Array()
		for point in points:
			local.append(point - body_center)
		var hull := Geometry2D.convex_hull(local)
		if hull.size() >= 3:
			var polygon := ConvexPolygonShape2D.new()
			polygon.points = hull
			var collision := CollisionShape2D.new()
			collision.shape = polygon
			body.add_child(collision)
			_shape_count += 1
			return
	_add_capsules(body, points, width, body_center)


func _add_polyline_to_body(
	body: ActiveRigBody2D,
	points: PackedVector2Array,
	width: float,
	color: Color,
	body_center: Vector2
) -> void:
	_add_visual_line(body, points, width, color, body_center)
	_add_capsules(body, points, width, body_center)


func _add_visual_line(
	body: ActiveRigBody2D,
	points: PackedVector2Array,
	width: float,
	color: Color,
	body_center: Vector2
) -> void:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var local := PackedVector2Array()
	for point in points:
		local.append(point - body_center)
	line.points = local
	body.add_child(line)


func _add_capsules(
	body: ActiveRigBody2D,
	points: PackedVector2Array,
	width: float,
	body_center: Vector2
) -> void:
	var sampled := _sample_points(points, 16)
	var radius := clampf(width * 0.5, 2.0, 6.0)
	for index in range(sampled.size() - 1):
		if _shape_count >= MAX_SHAPES:
			return
		var from := sampled[index]
		var to := sampled[index + 1]
		var length := from.distance_to(to)
		if length <= 0.5:
			continue
		var capsule := CapsuleShape2D.new()
		capsule.radius = radius
		capsule.height = maxf(radius * 2.0, length + radius * 2.0)
		var collision := CollisionShape2D.new()
		collision.shape = capsule
		collision.position = (from + to) * 0.5 - body_center
		collision.rotation = (to - from).angle() + PI * 0.5
		body.add_child(collision)
		_shape_count += 1


func _finalize_rig() -> void:
	for first_index in range(_bodies.size()):
		for second_index in range(first_index + 1, _bodies.size()):
			_bodies[first_index].add_collision_exception_with(_bodies[second_index])
	if _primary_body != null:
		var grip := Marker2D.new()
		grip.name = "GripAnchor"
		var bounds := get_stroke_bounds()
		grip.position = Vector2(bounds.size.x * 0.32, -bounds.size.y * 0.12)
		_primary_body.add_child(grip)


func _clear_rig() -> void:
	_primary_body = null
	_bodies.clear()
	_joints.clear()
	_segments.clear()
	_body_pool = PackedVector2Array()
	_shape_count = 0
	if _physics_root != null and is_instance_valid(_physics_root):
		_physics_root.get_parent().remove_child(_physics_root)
		_physics_root.queue_free()
	_physics_root = null


func _select_body_stroke(strokes: Array) -> int:
	var best_index := 0
	var best_score := -INF
	var max_length := 0.001
	var max_area := 0.001
	for stroke_value in strokes:
		var stroke: Dictionary = stroke_value
		max_length = maxf(max_length, _stroke_length(stroke["points"]))
		max_area = maxf(max_area, absf(_polygon_area(stroke["points"])))
	for index in range(strokes.size()):
		var stroke: Dictionary = strokes[index]
		var points: PackedVector2Array = stroke["points"]
		var incoming := 0
		var radius := clampf(get_stroke_bounds().size.length() * 0.08, 6.0, 18.0)
		for other_index in range(strokes.size()):
			if index == other_index:
				continue
			var other: PackedVector2Array = strokes[other_index]["points"]
			if _point_polyline_distance(other[0], points) <= radius or _point_polyline_distance(other[other.size() - 1], points) <= radius:
				incoming += 1
		var closed_bonus := 3.0 if _stroke_is_closed(points, float(stroke.get("width", 5.0))) else 0.0
		var score := closed_bonus + float(incoming) * 2.0 \
			+ absf(_polygon_area(points)) / max_area * 1.8 \
			+ _stroke_length(points) / max_length * 0.6
		if score > best_score:
			best_score = score
			best_index = index
	return best_index


func _paths_attached_to_body(points: PackedVector2Array, radius: float) -> Array:
	var result: Array = []
	if points.size() < 2:
		return result
	var start_gap := _point_pool_distance(points[0], _body_pool)
	var end_gap := _point_pool_distance(points[points.size() - 1], _body_pool)
	if minf(start_gap, end_gap) <= radius:
		var ordered := points.duplicate()
		if end_gap < start_gap:
			ordered.reverse()
		result.append(ordered)
		return result
	var closest_index := -1
	var closest_gap := radius
	for index in range(1, points.size() - 1):
		var gap := _point_pool_distance(points[index], _body_pool)
		if gap < closest_gap:
			closest_gap = gap
			closest_index = index
	if closest_index > 0:
		var first := points.slice(0, closest_index + 1)
		first.reverse()
		var second := points.slice(closest_index, points.size())
		result.append(first)
		result.append(second)
	return result


func _role_for_limb(joint: Vector2, tip: Vector2, body_center: Vector2) -> String:
	var delta := tip - joint
	match _rig_type:
		"walker":
			return "leg"
		"biped":
			return "leg" if tip.y > body_center.y else "arm"
		"hopper":
			return "leg" if delta.y > -4.0 else "limb"
		"flier":
			if absf(delta.x) >= absf(delta.y) * 0.7 or delta.y < 0.0:
				return "wing"
			return "leg"
		"swimmer":
			return "tail" if absf(delta.x) > absf(delta.y) else "fin"
		_:
			return "limb"


func _sample_points(points: PackedVector2Array, maximum: int) -> PackedVector2Array:
	if points.size() <= maximum:
		return points.duplicate()
	var sampled := PackedVector2Array()
	for index in range(maximum):
		var source_index := int(round(float(index) * float(points.size() - 1) / float(maximum - 1)))
		sampled.append(points[source_index])
	return sampled


func _mass_for_stroke(stroke: Dictionary, multiplier: float = 1.0) -> float:
	return _mass_for_points(stroke["points"], float(stroke.get("width", 5.0))) * multiplier


func _mass_for_points(points: PackedVector2Array, width: float) -> float:
	return clampf(_stroke_length(points) * width * 0.0018, 0.22, 3.2)


func _stroke_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for index in range(points.size() - 1):
		total += points[index].distance_to(points[index + 1])
	return total


func _stroke_is_closed(points: PackedVector2Array, width: float) -> bool:
	if points.size() < 3:
		return false
	var tolerance := maxf(width * 1.5, get_stroke_bounds().size.length() * 0.055)
	return points[0].distance_to(points[points.size() - 1]) <= tolerance


func _polygon_area(points: PackedVector2Array) -> float:
	if points.size() < 3:
		return 0.0
	var area := 0.0
	for index in range(points.size()):
		var next := (index + 1) % points.size()
		area += points[index].x * points[next].y - points[next].x * points[index].y
	return area * 0.5


func _points_center(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds.get_center()


func _point_pool_distance(point: Vector2, pool: PackedVector2Array) -> float:
	var best := INF
	for other in pool:
		best = minf(best, point.distance_to(other))
	return best


func _point_polyline_distance(point: Vector2, points: PackedVector2Array) -> float:
	if points.is_empty():
		return INF
	if points.size() == 1:
		return point.distance_to(points[0])
	var best := INF
	for index in range(points.size() - 1):
		var nearest := Geometry2D.get_closest_point_to_segment(point, points[index], points[index + 1])
		best = minf(best, point.distance_to(nearest))
	return best
