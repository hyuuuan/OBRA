extends "res://scripts/drawing_skin_2d.gd"
class_name RuntimeRig2D
## Builds a skeleton out of the player's actual drawn strokes and animates the
## drawn ink directly — no template limbs are ever added.
##
## Joint resolution: the stroke cluster with the most attachments (plus closed
## shapes and contained marks like eyes) becomes the body. Every open stroke
## touching the body becomes a limb pivoting at the exact contact point; a
## stroke that crosses the body (one line drawn through it) is split into two
## limbs at the crossing; strokes touching a limb extend that limb as a chain.
##
## Motion: gait phase advances with distance actually traveled, wings beat only
## on flap impulses, the swim wave scales with speed — and every pose eases
## back to the drawn rest pose the moment movement stops. Nothing oscillates on
## a wall clock.

const LIMB_EASE_RATE := 14.0
const BODY_EASE_RATE := 10.0

var _rig_type: String = "none"
var _motion_state: String = "idle"
var _motion_params: Dictionary = {}

var _rig_root: Node2D
var _pose_root: Node2D
var _body_group: Node2D
var _limbs: Array = [] # see _create_limb_node for the dictionary layout
var _wave_lines: Array = [] # [{line: Line2D, base: PackedVector2Array}]
var _wave_dirty: bool = false
var _body_center: Vector2 = Vector2.ZERO

var _gait_phase: float = 0.0
var _flap_phase: float = 0.0
var _wave_phase: float = 0.0
var _wave_amp: float = 0.0
var _impact_timer: float = 0.0
var _impact_duration: float = 0.18
var _facing: float = 1.0

var _target_offset: Vector2 = Vector2.ZERO
var _target_squash: Vector2 = Vector2.ONE
var _target_tilt: float = 0.0

var _character: CharacterBody2D


func configure_rig(new_profile: Dictionary, new_entity_metadata: Dictionary = {}) -> void:
	configure_skin(new_profile, new_entity_metadata)
	_rig_type = _profile_string("rig_type", String(new_entity_metadata.get("rig_type", "")))
	if _rig_type.is_empty():
		_rig_type = _legacy_rig_type()


func set_motion_state(state: String, params: Dictionary = {}) -> void:
	_motion_state = state
	_motion_params = params.duplicate(true)
	var direction := _param_float("direction", 0.0)
	if absf(direction) > 0.05 and _rig_type != "swimmer":
		_facing = 1.0 if direction > 0.0 else -1.0
	if state == "landed":
		_impact_timer = _impact_duration


func _on_skin_rebuilt() -> void:
	_clear_rig()
	if skin_mode() != "vector":
		return
	_build_vector_rig()


func _process(delta: float) -> void:
	if skin_mode() == "none":
		return

	_impact_timer = maxf(0.0, _impact_timer - delta)
	_target_offset = Vector2.ZERO
	_target_squash = Vector2.ONE
	_target_tilt = 0.0

	var speed := _parent_speed()
	if skin_mode() == "bitmap":
		_tick_bitmap(delta, speed)
	else:
		match _rig_type:
			"walker":
				_tick_walker(delta, speed)
			"biped":
				_tick_biped(delta, speed)
			"flier":
				_tick_flier(delta)
			"swimmer":
				_tick_swimmer(delta, speed)
			"hopper":
				_tick_hopper(delta)
			_:
				pass

	_apply_pose(delta)


# --- Rig construction -------------------------------------------------------


func _clear_rig() -> void:
	if _rig_root != null and is_instance_valid(_rig_root):
		_rig_root.queue_free()
	_rig_root = null
	_pose_root = null
	_body_group = null
	_limbs.clear()
	_wave_lines.clear()
	_wave_dirty = false
	_gait_phase = 0.0
	_flap_phase = 0.0
	_wave_phase = 0.0
	_wave_amp = 0.0


func _build_vector_rig() -> void:
	var strokes := get_vector_strokes()
	if strokes.is_empty():
		return

	_rig_root = Node2D.new()
	_rig_root.name = "RigRoot"
	add_child(_rig_root)
	_pose_root = Node2D.new()
	_pose_root.name = "Pose"
	_rig_root.add_child(_pose_root)
	_body_group = Node2D.new()
	_body_group.name = "BodyGroup"
	_pose_root.add_child(_body_group)

	# The swimmer deforms every stroke with a traveling wave; it needs no limb
	# graph, just the drawn lines and their rest positions.
	if _rig_type == "swimmer":
		for stroke in strokes:
			var line := _make_line(stroke, Vector2.ZERO)
			_body_group.add_child(line)
			_wave_lines.append({"line": line, "base": line.points.duplicate()})
		_body_center = get_stroke_bounds().get_center()
		return

	var plan := _resolve_skeleton(strokes)
	_body_center = plan["body_center"]

	for stroke_index in plan["body_indices"]:
		_body_group.add_child(_make_line(strokes[stroke_index], Vector2.ZERO))

	for record in plan["limbs"]:
		_create_limb_node(record)

	_assign_limb_roles()


## Groups strokes into a body cluster plus limb chains with resolved joints.
func _resolve_skeleton(strokes: Array) -> Dictionary:
	var count := strokes.size()
	var radius := clampf(get_stroke_bounds().size.length() * 0.07, 4.0, 18.0)

	var lengths: Array = []
	var areas: Array = []
	var is_closed: Array = []
	var max_area := 0.001
	var max_length := 0.001
	for index in range(count):
		var points: PackedVector2Array = strokes[index]["points"]
		var length := _polyline_length(points)
		var box := _points_bounds(points)
		lengths.append(length)
		areas.append(box.size.x * box.size.y)
		is_closed.append(points[0].distance_to(points[points.size() - 1]) < maxf(radius, length * 0.2))
		max_area = maxf(max_area, areas[index])
		max_length = maxf(max_length, length)

	var incoming: Array = []
	incoming.resize(count)
	incoming.fill(0)
	for index in range(count):
		var points: PackedVector2Array = strokes[index]["points"]
		for other in range(count):
			if other == index:
				continue
			var other_points: PackedVector2Array = strokes[other]["points"]
			var gap := minf(
				_distance_to_points(points[0], other_points),
				_distance_to_points(points[points.size() - 1], other_points)
			)
			if gap < radius:
				incoming[other] += 1

	# The body root is the stroke everything else hangs off.
	var root := 0
	var best_score := -INF
	for index in range(count):
		var score := 2.0 * float(incoming[index]) \
			+ (2.0 if is_closed[index] else 0.0) \
			+ 1.5 * float(areas[index]) / max_area \
			+ 0.5 * float(lengths[index]) / max_length
		if score > best_score:
			best_score = score
			root = index

	var in_body: Array = []
	in_body.resize(count)
	in_body.fill(false)
	in_body[root] = true

	# A biped's torso is a single stroke hanging from the head with limbs
	# attached along it, so one junction already marks it as structural.
	var junction_threshold := 1 if _rig_type == "biped" else 2

	var changed := true
	while changed:
		changed = false
		var body_box := _body_bounds(strokes, in_body).grow(radius)
		for index in range(count):
			if in_body[index]:
				continue
			var points: PackedVector2Array = strokes[index]["points"]
			var gap_start := _gap_to_body(points[0], strokes, in_body)
			var gap_end := _gap_to_body(points[points.size() - 1], strokes, in_body)
			var absorb := false
			if is_closed[index] and _min_gap_to_body(points, strokes, in_body) < radius:
				absorb = true # closed shape touching the body (head, body scribble)
			elif gap_start < radius and gap_end < radius:
				absorb = true # both ends anchored (mouth line, structural stroke)
			elif _containment_ratio(points, body_box) > 0.8:
				absorb = true # floating mark inside the body (eyes, patterns)
			elif minf(gap_start, gap_end) < radius \
					and _junction_count(index, strokes, radius * 0.5, gap_start <= gap_end) >= junction_threshold:
				# Structural member other strokes hang off (torso). The tighter
				# radius means an actual touch/cross, not two limbs drawn close.
				absorb = true
			if absorb:
				in_body[index] = true
				changed = true

	# Everything left is limb material.
	var limbs: Array = []
	var pending: Array = []
	for index in range(count):
		if in_body[index]:
			continue
		var points: PackedVector2Array = strokes[index]["points"]
		var gap_start := _gap_to_body(points[0], strokes, in_body)
		var gap_end := _gap_to_body(points[points.size() - 1], strokes, in_body)
		if minf(gap_start, gap_end) < radius:
			var joint := points[0] if gap_start <= gap_end else points[points.size() - 1]
			var ordered := points.duplicate()
			if gap_end < gap_start:
				ordered.reverse()
			limbs.append(_new_limb_record(strokes[index], ordered, joint))
			continue

		# One line drawn across the body: split it into two limbs at the
		# point closest to the body.
		var best_interior := -1
		var best_gap := radius
		for point_index in range(1, points.size() - 1):
			var gap := _gap_to_body(points[point_index], strokes, in_body)
			if gap < best_gap:
				best_gap = gap
				best_interior = point_index
		if best_interior != -1:
			var joint := points[best_interior]
			var first := points.slice(0, best_interior + 1)
			first.reverse()
			var second := points.slice(best_interior)
			if _polyline_length(first) > radius:
				limbs.append(_new_limb_record(strokes[index], first, joint))
			if _polyline_length(second) > radius:
				limbs.append(_new_limb_record(strokes[index], second, joint))
			continue

		pending.append(index)

	# Chain remaining strokes onto the limb they touch (lower leg, foot, ...).
	var progressed := true
	while progressed and not pending.is_empty():
		progressed = false
		for pending_position in range(pending.size() - 1, -1, -1):
			var stroke_index: int = pending[pending_position]
			var points: PackedVector2Array = strokes[stroke_index]["points"]
			for record in limbs:
				var pool: PackedVector2Array = record["pool"]
				var gap := minf(
					_distance_to_points(points[0], pool),
					_distance_to_points(points[points.size() - 1], pool)
				)
				if gap < radius:
					record["segments"].append(strokes[stroke_index])
					record["pool"].append_array(points)
					pending.remove_at(pending_position)
					progressed = true
					break

	# Whatever never connected rides rigidly with the body.
	var body_indices: Array = []
	for index in range(count):
		if in_body[index]:
			body_indices.append(index)
	for stroke_index in pending:
		body_indices.append(stroke_index)

	# Fold stubs too short to read as limbs back into the body.
	for record_index in range(limbs.size() - 1, -1, -1):
		var record: Dictionary = limbs[record_index]
		if _farthest_distance(record["pool"], record["joint"]) < radius * 1.2:
			for segment in record["segments"]:
				_body_group_extra(segment)
			limbs.remove_at(record_index)

	var body_points := PackedVector2Array()
	for stroke_index in body_indices:
		body_points.append_array(strokes[stroke_index]["points"])
	var center := get_stroke_bounds().get_center()
	if body_points.size() > 0:
		center = _points_bounds(body_points).get_center()

	return {"body_indices": body_indices, "limbs": limbs, "body_center": center}


func _new_limb_record(stroke: Dictionary, ordered_points: PackedVector2Array, joint: Vector2) -> Dictionary:
	var segment := {
		"points": ordered_points,
		"width": stroke["width"],
		"color": stroke["color"]
	}
	return {
		"segments": [segment],
		"pool": ordered_points.duplicate(),
		"joint": joint
	}


func _body_group_extra(segment: Dictionary) -> void:
	if _body_group != null:
		_body_group.add_child(_make_line(segment, Vector2.ZERO))


func _create_limb_node(record: Dictionary) -> void:
	var joint: Vector2 = record["joint"]
	var node := Node2D.new()
	node.name = "Limb%02d" % _limbs.size()
	node.position = joint
	_pose_root.add_child(node)

	for segment in record["segments"]:
		node.add_child(_make_line(segment, joint))

	var tip := joint
	var best := 0.0
	for point in record["pool"]:
		var distance: float = joint.distance_to(point)
		if distance > best:
			best = distance
			tip = point

	_limbs.append({
		"node": node,
		"joint": joint,
		"tip": tip,
		"length": best,
		"role": "rigid",
		"phase": 0.0,
		"amp_scale": 1.0,
		"current": 0.0,
		"target": 0.0
	})


func _make_line(stroke: Dictionary, origin: Vector2) -> Line2D:
	var points: PackedVector2Array = stroke["points"]
	var line := Line2D.new()
	var local := PackedVector2Array()
	local.resize(points.size())
	for index in range(points.size()):
		local[index] = points[index] - origin
	line.points = local
	line.width = float(stroke["width"])
	line.default_color = stroke["color"]
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	return line


func _assign_limb_roles() -> void:
	if _limbs.is_empty():
		return
	var diag := get_stroke_bounds().size.length()
	_limbs.sort_custom(func(a, b): return a["joint"].x < b["joint"].x)

	match _rig_type:
		"walker":
			var leg_index := 0
			var ripple := _profile_float("leg_phase_ripple", 0.35)
			for limb in _limbs:
				var reaches_up: bool = limb["tip"].y < _body_center.y - diag * 0.18 \
					and limb["tip"].y < limb["joint"].y
				limb["role"] = "leg"
				limb["amp_scale"] = 0.35 if reaches_up else 1.0
				limb["phase"] = PI * float(leg_index % 2) + float(leg_index) * ripple
				leg_index += 1
		"biped":
			var candidates: Array = []
			for limb in _limbs:
				if limb["tip"].y > limb["joint"].y and limb["joint"].y > _body_center.y:
					candidates.append(limb)
			candidates.sort_custom(func(a, b): return a["length"] > b["length"])
			var legs := candidates.slice(0, 2)
			legs.sort_custom(func(a, b): return a["joint"].x < b["joint"].x)
			var hip_y := _body_center.y + diag * 0.1
			if not legs.is_empty():
				hip_y = INF
			for leg_index in range(legs.size()):
				legs[leg_index]["role"] = "leg"
				legs[leg_index]["phase"] = PI * float(leg_index)
				hip_y = minf(hip_y, legs[leg_index]["joint"].y)
			for limb in _limbs:
				if limb["role"] == "leg":
					continue
				# Anything jointed above the hip line swings as an arm.
				if limb["joint"].y <= hip_y - diag * 0.03:
					limb["role"] = "arm"
					limb["phase"] = PI if limb["joint"].x < _body_center.x else 0.0
		"flier":
			for limb in _limbs:
				var spread_x: float = absf(limb["tip"].x - limb["joint"].x)
				var drop_y: float = limb["tip"].y - limb["joint"].y
				if (limb["tip"].y < limb["joint"].y or spread_x > absf(drop_y)) \
						and limb["length"] > diag * 0.1:
					limb["role"] = "wing"
				elif drop_y > 0.0 and limb["length"] <= diag * 0.35:
					limb["role"] = "leg"
		"hopper":
			for limb in _limbs:
				if limb["tip"].y > limb["joint"].y:
					limb["role"] = "leg"
		_:
			pass


# --- Motion (all driven by real movement, easing to rest) --------------------


func _tick_walker(delta: float, speed: float) -> void:
	var moving := (_motion_state == "walk" or _motion_state == "climb") and speed > 4.0
	var airborne := _motion_state == "jump" or _motion_state == "fall"
	var stride := maxf(8.0, _profile_float("stride_length", 44.0))
	var swing := deg_to_rad(_profile_float("leg_swing_degrees", 15.0))
	var splay := deg_to_rad(_profile_float("air_splay_degrees", 10.0))

	if moving:
		_gait_phase += speed * delta / stride

	for limb in _limbs:
		if limb["role"] != "leg":
			limb["target"] = 0.0
			continue
		if airborne:
			limb["target"] = _rotation_sign(limb, _outward_dir(limb)) * splay
		elif moving:
			limb["target"] = swing * limb["amp_scale"] * sin(TAU * _gait_phase + limb["phase"])
		else:
			limb["target"] = 0.0

	if moving:
		_target_offset.y = -absf(sin(TAU * _gait_phase)) * _profile_float("walk_bob", 1.6)
		_target_tilt = deg_to_rad(_param_float("direction", 0.0) * _profile_float("tilt_degrees", 3.0))
	_apply_impact_squash(_profile_float("landing_squash", 0.1))


func _tick_biped(delta: float, speed: float) -> void:
	var moving := _motion_state == "walk" and speed > 4.0
	var stride := maxf(8.0, _profile_float("stride_length", 60.0))
	var leg_swing := deg_to_rad(_profile_float("leg_swing_degrees", 25.0))
	var arm_swing := deg_to_rad(_profile_float("arm_swing_degrees", 15.0))
	var tuck := deg_to_rad(_profile_float("jump_tuck_degrees", 26.0))
	var air_arm := deg_to_rad(_profile_float("air_arm_degrees", 30.0))

	if moving:
		_gait_phase += speed * delta / stride

	for limb in _limbs:
		var role: String = limb["role"]
		limb["target"] = 0.0
		match _motion_state:
			"walk":
				if moving and role == "leg":
					limb["target"] = leg_swing * sin(TAU * _gait_phase + limb["phase"])
				elif moving and role == "arm":
					limb["target"] = arm_swing * sin(TAU * _gait_phase + limb["phase"])
			"jump":
				if role == "leg":
					limb["target"] = _rotation_sign(limb, Vector2.UP) * tuck
				elif role == "arm":
					limb["target"] = _rotation_sign(limb, Vector2.UP) * air_arm
			"fall":
				if role == "leg":
					limb["target"] = _rotation_sign(limb, Vector2.UP) * tuck * 0.4
				elif role == "arm":
					limb["target"] = _rotation_sign(limb, Vector2.UP) * air_arm
			_:
				pass

	if moving:
		_target_offset.y = -absf(sin(TAU * _gait_phase)) * _profile_float("walk_bob", 2.2)
		_target_tilt = deg_to_rad(_param_float("direction", 0.0) * _profile_float("tilt_degrees", 3.0))
	_apply_impact_squash(_profile_float("landing_squash", 0.12))


func _tick_flier(delta: float) -> void:
	var flap_deg := deg_to_rad(_profile_float("wing_flap_degrees", 34.0))
	var glide_raise := deg_to_rad(_profile_float("glide_raise_degrees", 12.0))
	var direction := _param_float("direction", 0.0)
	var vertical_speed := _param_float("vertical_speed", 0.0)
	var airborne := _motion_state in ["flap", "glide", "fly", "fall"]

	var beat := 0.0
	if _motion_state == "flap":
		_flap_phase += delta * _profile_float("flap_cycle_hz", 6.5)
		beat = sin(TAU * _flap_phase)
		var pulse := absf(beat) * _profile_float("flap_squash", 0.1)
		_target_squash = Vector2(1.0 + pulse, 1.0 - pulse)
		_target_offset.y = -absf(beat) * _profile_float("flap_lift", 4.0)

	for limb in _limbs:
		limb["target"] = 0.0
		match limb["role"]:
			"wing":
				if _motion_state == "flap":
					limb["target"] = _rotation_sign(limb, Vector2.DOWN) * flap_deg * beat
				elif _motion_state == "glide":
					limb["target"] = _rotation_sign(limb, Vector2.UP) * glide_raise
				elif _motion_state == "fly":
					limb["target"] = _rotation_sign(limb, Vector2.UP) * glide_raise * 0.35
				elif _motion_state == "fall":
					limb["target"] = _rotation_sign(limb, Vector2.UP) * glide_raise * 0.15
			"leg":
				if airborne:
					limb["target"] = _rotation_sign(limb, Vector2.UP) * deg_to_rad(8.0)
			_:
				pass

	if airborne:
		_target_tilt = deg_to_rad(direction * _profile_float("tilt_degrees", 8.0))
		if _motion_state == "glide" or _motion_state == "fall":
			var pitch := clampf(vertical_speed / 500.0, -1.0, 1.0)
			_target_tilt += deg_to_rad(pitch * _profile_float("dive_pitch_degrees", 6.0) * _facing)


func _tick_swimmer(delta: float, speed: float) -> void:
	if _wave_lines.is_empty():
		return
	var swimming := _motion_state == "swim" and speed > 4.0
	var speed_ratio := clampf(_param_float("speed_ratio", 0.0), 0.0, 1.0)
	var wave_length := maxf(20.0, _profile_float("wave_length", 70.0))
	var amplitude := _profile_float("wave_amplitude", 5.0)
	var target_amp := amplitude * (0.35 + 0.65 * speed_ratio) if swimming else 0.0
	_wave_amp = lerpf(_wave_amp, target_amp, 1.0 - exp(-6.0 * delta))

	if _wave_amp <= 0.05:
		if _wave_dirty:
			for entry in _wave_lines:
				(entry["line"] as Line2D).points = entry["base"]
			_wave_dirty = false
		return

	_wave_phase += speed * delta / wave_length
	var head := _profile_vector2("head_direction", Vector2(-1.0, 0.0))
	var tail_sign := 1.0 if head.x <= 0.0 else -1.0
	var bounds := get_stroke_bounds()

	for entry in _wave_lines:
		var line := entry["line"] as Line2D
		var base: PackedVector2Array = entry["base"]
		var displaced := PackedVector2Array()
		displaced.resize(base.size())
		for index in range(base.size()):
			var point := base[index]
			var along := (point.x - bounds.position.x) / maxf(0.001, bounds.size.x)
			var toward_tail := along if tail_sign > 0.0 else 1.0 - along
			var envelope := 0.12 + 0.88 * toward_tail
			point.y += _wave_amp * envelope \
				* sin(TAU * (point.x / wave_length) * tail_sign - TAU * _wave_phase)
			displaced[index] = point
		line.points = displaced
	_wave_dirty = true


func _tick_hopper(_delta: float) -> void:
	var fold := deg_to_rad(_profile_float("leg_fold_degrees", 22.0))
	var extend := deg_to_rad(_profile_float("leg_extend_degrees", 24.0))
	var charge_ratio := clampf(_param_float("charge_ratio", 0.0), 0.0, 1.0)
	var direction := _param_float("direction", 0.0)

	match _motion_state:
		"charge":
			var crouch := _profile_float("charge_squash", 0.22) * charge_ratio
			_target_squash = Vector2(1.0 + crouch, 1.0 - crouch)
			_target_offset.y = crouch * 20.0
		"jump":
			var stretch := _profile_float("jump_stretch", 0.14)
			_target_squash = Vector2(1.0 - stretch * 0.5, 1.0 + stretch)
			_target_tilt = deg_to_rad(direction * _profile_float("tilt_degrees", 4.0))
		"fall":
			var stretch := _profile_float("jump_stretch", 0.14) * 0.5
			_target_squash = Vector2(1.0 - stretch * 0.4, 1.0 + stretch)
			_target_tilt = deg_to_rad(direction * _profile_float("tilt_degrees", 4.0))
		_:
			pass
	_apply_impact_squash(_profile_float("landing_squash", 0.18))

	for limb in _limbs:
		limb["target"] = 0.0
		if limb["role"] != "leg":
			continue
		match _motion_state:
			"charge":
				limb["target"] = _rotation_sign(limb, Vector2.UP) * fold * charge_ratio
			"jump":
				limb["target"] = _rotation_sign(limb, Vector2.DOWN) * extend
			"fall":
				limb["target"] = _rotation_sign(limb, Vector2.DOWN) * extend * 0.45
			"landed":
				limb["target"] = _rotation_sign(limb, Vector2.UP) * fold * _impact_ratio()
			_:
				pass


## Bitmap fallback: no limbs to articulate, so only grounded squash/tilt cues.
func _tick_bitmap(delta: float, speed: float) -> void:
	var direction := _param_float("direction", 0.0)
	match _motion_state:
		"walk", "climb":
			if speed > 4.0:
				_gait_phase += speed * delta / maxf(8.0, _profile_float("stride_length", 44.0))
				_target_offset.y = -absf(sin(TAU * _gait_phase)) * _profile_float("walk_bob", 2.0)
				_target_tilt = deg_to_rad(direction * _profile_float("tilt_degrees", 3.0))
		"charge":
			var crouch := _profile_float("charge_squash", 0.2) * clampf(_param_float("charge_ratio", 0.0), 0.0, 1.0)
			_target_squash = Vector2(1.0 + crouch, 1.0 - crouch)
		"jump":
			var stretch := _profile_float("jump_stretch", 0.12)
			_target_squash = Vector2(1.0 - stretch * 0.5, 1.0 + stretch)
		"fall":
			var stretch := _profile_float("jump_stretch", 0.12) * 0.5
			_target_squash = Vector2(1.0 - stretch * 0.4, 1.0 + stretch)
		"flap":
			_flap_phase += delta * _profile_float("flap_cycle_hz", 6.5)
			var pulse := absf(sin(TAU * _flap_phase)) * _profile_float("flap_squash", 0.1)
			_target_squash = Vector2(1.0 + pulse, 1.0 - pulse)
		"swim":
			_target_tilt = deg_to_rad(direction * _profile_float("tilt_degrees", 3.0))
		_:
			pass
	_apply_impact_squash(_profile_float("landing_squash", 0.12))


func _apply_pose(delta: float) -> void:
	var limb_ease := 1.0 - exp(-LIMB_EASE_RATE * delta)
	var body_ease := 1.0 - exp(-BODY_EASE_RATE * delta)

	for limb in _limbs:
		limb["current"] = lerp_angle(limb["current"], limb["target"], limb_ease)
		(limb["node"] as Node2D).rotation = limb["current"]

	if skin_mode() == "vector" and _pose_root != null:
		_pose_root.position = _pose_root.position.lerp(_target_offset, body_ease)
		_pose_root.scale = _pose_root.scale.lerp(_target_squash, body_ease)
		_pose_root.rotation = lerp_angle(_pose_root.rotation, _target_tilt, body_ease)
		_rig_root.scale.x = _facing
	elif skin_mode() == "bitmap" and _body != null:
		_body.position = _body.position.lerp(_body_base_position + _target_offset, body_ease)
		var goal_scale := Vector2(
			_body_base_scale.x * _target_squash.x * _facing,
			_body_base_scale.y * _target_squash.y
		)
		_body.scale = _body.scale.lerp(goal_scale, body_ease)
		_body.rotation = lerp_angle(_body.rotation, _target_tilt, body_ease)


func _apply_impact_squash(amount: float) -> void:
	var ratio := _impact_ratio()
	if ratio <= 0.0:
		return
	var crouch := amount * ratio
	_target_squash = Vector2(1.0 + crouch, 1.0 - crouch)
	_target_offset.y += crouch * 16.0


# --- Helpers -----------------------------------------------------------------


func _parent_speed() -> float:
	if _character == null:
		_character = get_parent() as CharacterBody2D
	if _character == null:
		return 0.0
	return _character.velocity.length()


func _impact_ratio() -> float:
	if _impact_duration <= 0.0:
		return 0.0
	return clampf(_impact_timer / _impact_duration, 0.0, 1.0)


func _param_float(key: String, default_value: float) -> float:
	var value: Variant = _motion_params.get(key, default_value)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return default_value


## Sign of the joint rotation that initially moves the limb tip toward `dir`.
func _rotation_sign(limb: Dictionary, dir: Vector2) -> float:
	var rel: Vector2 = limb["tip"] - limb["joint"]
	var swept := Vector2(-rel.y, rel.x)
	return 1.0 if swept.dot(dir) >= 0.0 else -1.0


func _outward_dir(limb: Dictionary) -> Vector2:
	return Vector2(signf(limb["tip"].x - _body_center.x + 0.001), 0.0)


func _legacy_rig_type() -> String:
	var legacy := _profile_string(
		"deform_strategy",
		String(entity_metadata.get("deform_strategy", "none"))
	)
	match legacy:
		"spline":
			return "swimmer"
		"squash":
			return "hopper"
		"flap":
			return "flier"
		"limb_template":
			return "walker"
		_:
			return "none"


func _polyline_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for index in range(points.size() - 1):
		total += points[index].distance_to(points[index + 1])
	return total


func _points_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


func _distance_to_points(point: Vector2, points: PackedVector2Array) -> float:
	var best := INF
	for candidate in points:
		best = minf(best, point.distance_squared_to(candidate))
	return sqrt(best)


func _gap_to_body(point: Vector2, strokes: Array, in_body: Array) -> float:
	var best := INF
	for index in range(strokes.size()):
		if not in_body[index]:
			continue
		best = minf(best, _distance_to_points(point, strokes[index]["points"]))
	return best


func _min_gap_to_body(points: PackedVector2Array, strokes: Array, in_body: Array) -> float:
	var best := INF
	for point in points:
		best = minf(best, _gap_to_body(point, strokes, in_body))
		if best <= 0.0:
			break
	return best


## How many other strokes touch this stroke away from its anchored end.
## A high count means the stroke is a structural member (e.g. a torso with
## arms and legs hanging off it) rather than a free-swinging limb.
func _junction_count(index: int, strokes: Array, radius: float, attached_at_start: bool) -> int:
	var points: PackedVector2Array = strokes[index]["points"]
	var total_length := _polyline_length(points)
	if total_length <= 0.0:
		return 0

	var arc: Array = []
	arc.resize(points.size())
	arc[0] = 0.0
	var running := 0.0
	for point_index in range(1, points.size()):
		running += points[point_index - 1].distance_to(points[point_index])
		arc[point_index] = running

	var count := 0
	for other in range(strokes.size()):
		if other == index:
			continue
		var other_points: PackedVector2Array = strokes[other]["points"]
		for point_index in range(points.size()):
			var from_anchor: float = arc[point_index] if attached_at_start else total_length - arc[point_index]
			if from_anchor < total_length * 0.3:
				continue
			if _distance_to_points(points[point_index], other_points) < radius:
				count += 1
				break
	return count


func _containment_ratio(points: PackedVector2Array, body_box: Rect2) -> float:
	if points.is_empty() or body_box.size == Vector2.ZERO:
		return 0.0
	var inside := 0
	for point in points:
		if body_box.has_point(point):
			inside += 1
	return float(inside) / float(points.size())


func _body_bounds(strokes: Array, in_body: Array) -> Rect2:
	var combined := PackedVector2Array()
	for index in range(strokes.size()):
		if in_body[index]:
			combined.append_array(strokes[index]["points"])
	return _points_bounds(combined)


func _farthest_distance(points: PackedVector2Array, from: Vector2) -> float:
	var best := 0.0
	for point in points:
		best = maxf(best, from.distance_to(point))
	return best
