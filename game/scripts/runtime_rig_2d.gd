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
var _head_direction: Vector2 = Vector2.RIGHT

var _gait_phase: float = 0.0
var _flap_phase: float = 0.0
var _wave_phase: float = 0.0
var _wave_amp: float = 0.0
var _impact_timer: float = 0.0
var _impact_duration: float = 0.18
var _facing: float = 1.0
var _bird_style: String = "" # flier archetype resolved from the drawn build

var _target_offset: Vector2 = Vector2.ZERO
var _target_squash: Vector2 = Vector2.ONE
var _target_tilt: float = 0.0

var _character: CharacterBody2D

var _leg_phase_ripple := 0.35
var _walker_stride_length := 44.0
var _walker_leg_swing := deg_to_rad(15.0)
var _walker_air_splay := deg_to_rad(10.0)
var _walker_walk_bob := 1.6
var _walker_tilt := deg_to_rad(3.0)
var _walker_landing_squash := 0.1
var _biped_stride_length := 60.0
var _biped_leg_swing := deg_to_rad(25.0)
var _biped_arm_swing := deg_to_rad(15.0)
var _biped_jump_tuck := deg_to_rad(26.0)
var _biped_air_arm := deg_to_rad(30.0)
var _biped_walk_bob := 2.2
var _biped_tilt := deg_to_rad(3.0)
var _biped_landing_squash := 0.12
var _flier_ground_stride_length := 26.0
var _flier_leg_swing := deg_to_rad(22.0)
var _flier_walk_bob := 2.4
var _flier_ground_tilt := deg_to_rad(4.0)
var _flier_landing_squash := 0.12
var _flier_flap_cycle_hz := 6.5
var _flier_wing_flap := deg_to_rad(40.0)
var _flier_glide_raise := deg_to_rad(12.0)
var _flier_leg_tuck := deg_to_rad(12.0)
var _flier_flap_squash := 0.12
var _flier_flap_lift := 5.0
var _flier_tilt := deg_to_rad(8.0)
var _flier_dive_pitch := deg_to_rad(6.0)
var _flier_style := "auto"
var _flier_flap_hz_scale := 1.0
var _flier_flap_amp_scale := 1.0
var _flier_glide_scale := 1.0
var _flier_tuck_scale := 1.0
var _flier_stride_scale := 1.0
var _flier_leg_scale := 1.0
var _flier_bob_scale := 1.0
var _swimmer_wave_length := 70.0
var _swimmer_wave_amplitude := 5.0
var _swimmer_head_direction := Vector2.RIGHT
var _hopper_leg_fold := deg_to_rad(22.0)
var _hopper_leg_extend := deg_to_rad(24.0)
var _hopper_charge_squash := 0.22
var _hopper_jump_stretch := 0.14
var _hopper_tilt := deg_to_rad(4.0)
var _hopper_landing_squash := 0.18
var _bitmap_stride_length := 44.0
var _bitmap_walk_bob := 2.0
var _bitmap_tilt := deg_to_rad(3.0)
var _bitmap_charge_squash := 0.2
var _bitmap_jump_stretch := 0.12
var _bitmap_flap_cycle_hz := 6.5
var _bitmap_flap_squash := 0.1
var _bitmap_landing_squash := 0.12


func configure_rig(new_profile: Dictionary, new_entity_metadata: Dictionary = {}) -> void:
	configure_skin(new_profile, new_entity_metadata)
	_rig_type = _profile_string("rig_type", String(new_entity_metadata.get("rig_type", "")))
	if _rig_type.is_empty():
		_rig_type = _legacy_rig_type()
	_cache_profile_values()


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
				_tick_flier(delta, speed)
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
	var started := Time.get_ticks_usec()
	var strokes := get_vector_strokes()
	if strokes.is_empty():
		return
	_normalize_head_orientation(strokes)
	_refresh_vector_stroke_metrics(strokes)

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
		if debug_timing_logs:
			_print_rig_build_timing(started)
		return

	var plan := _resolve_skeleton(strokes)
	_body_center = plan["body_center"]

	for stroke_index in plan["body_indices"]:
		_body_group.add_child(_make_line(strokes[stroke_index], Vector2.ZERO))

	for record in plan["limbs"]:
		_create_limb_node(record)

	_assign_limb_roles()
	if debug_timing_logs:
		_print_rig_build_timing(started)


func _normalize_head_orientation(strokes: Array) -> void:
	match _rig_type:
		"biped":
			_normalize_biped_head_up(strokes)
		"swimmer":
			_normalize_swimmer_head_forward(strokes)
		_:
			pass


func _normalize_biped_head_up(strokes: Array) -> void:
	var head := _detect_biped_head(strokes)
	if not bool(head.get("found", false)):
		return

	var head_center: Vector2 = head["center"]
	var head_index := int(head.get("stroke_index", -1))
	var body_points := PackedVector2Array()
	for index in range(strokes.size()):
		if index == head_index:
			continue
		body_points.append_array(strokes[index]["points"])
	if body_points.is_empty():
		return

	var body_center := _points_bounds(body_points).get_center()
	var head_vector := head_center - body_center
	if head_vector.length() < 1.0:
		return

	var rotation := wrapf(Vector2.UP.angle() - head_vector.angle(), -PI, PI)
	if absf(rotation) < deg_to_rad(18.0):
		return
	_rotate_strokes(strokes, rotation, get_stroke_bounds().get_center())
	_realign_vector_strokes(strokes)


func _normalize_swimmer_head_forward(strokes: Array) -> void:
	var points := _all_stroke_points(strokes)
	if points.size() < 2:
		return

	var center := _points_bounds(points).get_center()
	var axis := _principal_axis(points, center)
	if axis.length() <= 0.001:
		return

	var head_sign := _detect_swimmer_head_sign(strokes, axis, center)
	var head_vector := axis * head_sign
	var rotation := wrapf(Vector2.RIGHT.angle() - head_vector.angle(), -PI, PI)
	if absf(rotation) > deg_to_rad(1.0):
		_rotate_strokes(strokes, rotation, center)
	_realign_vector_strokes(strokes)
	_head_direction = Vector2.RIGHT


## Groups strokes into a body cluster plus limb chains with resolved joints.
func _resolve_skeleton(strokes: Array) -> Dictionary:
	var count := strokes.size()
	var radius := clampf(get_stroke_bounds().size.length() * 0.07, 4.0, 18.0)
	var radius_sq := radius * radius

	var lengths: Array = []
	var areas: Array = []
	var is_closed: Array = []
	var max_area := 0.001
	var max_length := 0.001
	for index in range(count):
		var stroke: Dictionary = strokes[index]
		var points: PackedVector2Array = stroke["points"]
		var length := _cached_stroke_length(stroke)
		var area := _cached_stroke_area(stroke)
		lengths.append(length)
		areas.append(area)
		var closed_radius := maxf(radius, length * 0.2)
		is_closed.append(_cached_stroke_endpoint_gap_sq(stroke) < closed_radius * closed_radius)
		max_area = maxf(max_area, area)
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
			var gap_sq := minf(
				_distance_sq_to_points(points[0], other_points, radius_sq),
				_distance_sq_to_points(points[points.size() - 1], other_points, radius_sq)
			)
			if gap_sq < radius_sq:
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
	# attached along it, so one junction already marks it as structural, and
	# sloppy gaps between torso and limbs are common — count junctions more
	# generously. Walkers keep a tight junction radius so legs drawn close
	# together never absorb each other.
	var junction_threshold := 1 if _rig_type == "biped" else 2
	var junction_radius := radius * (1.5 if _rig_type == "biped" else 0.5)

	var changed := true
	while changed:
		changed = false
		var body_box := _body_bounds(strokes, in_body).grow(radius)
		for index in range(count):
			if in_body[index]:
				continue
			var points: PackedVector2Array = strokes[index]["points"]
			var gap_start_sq := _gap_sq_to_body(points[0], strokes, in_body)
			var gap_end_sq := _gap_sq_to_body(points[points.size() - 1], strokes, in_body)
			var absorb := false
			if is_closed[index] and _min_gap_sq_to_body(points, strokes, in_body, radius_sq) < radius_sq:
				absorb = true # closed shape touching the body (head, body scribble)
			elif gap_start_sq < radius_sq and gap_end_sq < radius_sq:
				# Both ends anchored (mouth line, structural stroke) — except a
				# flier's wing, drawn as an arc that leaves and rejoins the
				# body outline: that must stay a flappable limb.
				var wing_arc_radius := radius * 1.5
				var wing_arc: bool = _rig_type == "flier" and not is_closed[index] \
					and _max_gap_sq_to_body(points, strokes, in_body) > wing_arc_radius * wing_arc_radius
				absorb = not wing_arc
			elif _containment_ratio(points, body_box) > 0.8:
				absorb = true # floating mark inside the body (eyes, patterns)
			elif minf(gap_start_sq, gap_end_sq) < radius_sq \
					and _junction_count(
						index, strokes, in_body, junction_radius, radius * 0.6,
						gap_start_sq <= gap_end_sq, radius * 1.5
					) >= junction_threshold:
				# Structural member other strokes hang off (torso).
				absorb = true
			if absorb:
				in_body[index] = true
				changed = true

	# Everything left is limb material. Strict pass first (strokes actually
	# touching the body), then a soft pass so limbs drawn with sloppy gaps
	# still get a joint instead of riding rigidly with the body.
	var limbs: Array = []
	var soft_radius := radius * 2.5
	var work: Array = []
	for index in range(count):
		if not in_body[index]:
			work.append(index)

	for threshold: float in [radius, soft_radius]:
		var threshold_sq := threshold * threshold
		var deferred: Array = []
		for index: int in work:
			# Only strokes long enough to read as limbs may bridge a gap;
			# short marks (eyes, dots) stay decorations.
			if threshold > radius and float(lengths[index]) <= radius * 2.0:
				deferred.append(index)
				continue
			var points: PackedVector2Array = strokes[index]["points"]
			var gap_start_sq := _gap_sq_to_body(points[0], strokes, in_body)
			var gap_end_sq := _gap_sq_to_body(points[points.size() - 1], strokes, in_body)
			if minf(gap_start_sq, gap_end_sq) < threshold_sq:
				var joint := points[0] if gap_start_sq <= gap_end_sq else points[points.size() - 1]
				var ordered := points.duplicate()
				if gap_end_sq < gap_start_sq:
					ordered.reverse()
				limbs.append(_new_limb_record(strokes[index], ordered, joint))
				continue

			# One line drawn across the body: split it into two limbs at the
			# point closest to the body.
			var best_interior := -1
			var best_gap_sq := threshold_sq
			for point_index in range(1, points.size() - 1):
				var gap_sq := _gap_sq_to_body(points[point_index], strokes, in_body)
				if gap_sq < best_gap_sq:
					best_gap_sq = gap_sq
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

			deferred.append(index)
		work = deferred
	var pending: Array = work

	# Chain remaining strokes onto the limb they touch (lower leg, foot, ...).
	var progressed := true
	var soft_radius_sq := soft_radius * soft_radius
	while progressed and not pending.is_empty():
		progressed = false
		for pending_position in range(pending.size() - 1, -1, -1):
			var stroke_index: int = pending[pending_position]
			var points: PackedVector2Array = strokes[stroke_index]["points"]
			for record in limbs:
				var pool: PackedVector2Array = record["pool"]
				var gap_sq := minf(
					_distance_sq_to_points(points[0], pool, soft_radius_sq),
					_distance_sq_to_points(points[points.size() - 1], pool, soft_radius_sq)
				)
				if gap_sq < soft_radius_sq:
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
		var stub_radius := radius * 1.2
		if _farthest_distance_sq(record["pool"], record["joint"]) < stub_radius * stub_radius:
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
			for limb in _limbs:
				var reaches_up: bool = limb["tip"].y < _body_center.y - diag * 0.18 \
					and limb["tip"].y < limb["joint"].y
				limb["role"] = "leg"
				limb["amp_scale"] = 0.35 if reaches_up else 1.0
				limb["phase"] = PI * float(leg_index % 2) + float(leg_index) * _leg_phase_ripple
				leg_index += 1
		"biped":
			var candidates: Array = []
			for limb in _limbs:
				if limb["tip"].y > limb["joint"].y and limb["joint"].y > _body_center.y:
					candidates.append(limb)
			if candidates.is_empty():
				# Nothing jointed below the body center (big head skews it):
				# fall back to any downward-pointing limbs.
				for limb in _limbs:
					if limb["tip"].y > limb["joint"].y:
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
				elif drop_y > 0.0 and drop_y >= spread_x:
					limb["role"] = "leg"
			_assign_bird_style(diag)
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

	if moving:
		_gait_phase += speed * delta / _walker_stride_length

	for limb in _limbs:
		if limb["role"] != "leg":
			limb["target"] = 0.0
			continue
		if airborne:
			limb["target"] = _rotation_sign(limb, _outward_dir(limb)) * _walker_air_splay
		elif moving:
			limb["target"] = _walker_leg_swing * limb["amp_scale"] * sin(TAU * _gait_phase + limb["phase"])
		else:
			limb["target"] = 0.0

	if moving:
		_target_offset.y = -absf(sin(TAU * _gait_phase)) * _walker_walk_bob
		_target_tilt = _param_float("direction", 0.0) * _walker_tilt
	_apply_impact_squash(_walker_landing_squash)


func _tick_biped(delta: float, speed: float) -> void:
	var moving := _motion_state == "walk" and speed > 4.0

	if moving:
		_gait_phase += speed * delta / _biped_stride_length

	for limb in _limbs:
		var role: String = limb["role"]
		limb["target"] = 0.0
		match _motion_state:
			"walk":
				if moving and role == "leg":
					limb["target"] = _biped_leg_swing * sin(TAU * _gait_phase + limb["phase"])
				elif moving and role == "arm":
					limb["target"] = _biped_arm_swing * sin(TAU * _gait_phase + limb["phase"])
			"jump":
				if role == "leg":
					limb["target"] = _rotation_sign(limb, Vector2.UP) * _biped_jump_tuck
				elif role == "arm":
					limb["target"] = _rotation_sign(limb, Vector2.UP) * _biped_air_arm
			"fall":
				if role == "leg":
					limb["target"] = _rotation_sign(limb, Vector2.UP) * _biped_jump_tuck * 0.4
				elif role == "arm":
					limb["target"] = _rotation_sign(limb, Vector2.UP) * _biped_air_arm
			_:
				pass

	if moving:
		_target_offset.y = -absf(sin(TAU * _gait_phase)) * _biped_walk_bob
		_target_tilt = _param_float("direction", 0.0) * _biped_tilt
	_apply_impact_squash(_biped_landing_squash)


func _tick_flier(delta: float, speed: float) -> void:
	if _motion_state == "walk" or _motion_state == "idle":
		_tick_flier_ground(delta, speed)
	else:
		_tick_flier_air(delta)


## On the ground the wings fold and the feet actually step, phased per style:
## an alternating stride for soarers/striders, a two-footed bob for songbirds.
func _tick_flier_ground(delta: float, speed: float) -> void:
	var moving := _motion_state == "walk" and speed > 4.0
	var stride := _flier_ground_stride_length * _flier_stride_scale
	var swing := _flier_leg_swing * _flier_leg_scale

	if moving:
		_gait_phase += speed * delta / stride

	for limb in _limbs:
		limb["target"] = 0.0
		if limb["role"] == "leg" and moving:
			limb["target"] = swing * sin(TAU * _gait_phase + limb["phase"])

	if moving:
		_target_offset.y = -absf(sin(TAU * _gait_phase)) \
			* _flier_walk_bob * _flier_bob_scale
		_target_tilt = _param_float("direction", 0.0) * _flier_ground_tilt
	_apply_impact_squash(_flier_landing_squash)


## In the air the wings beat continuously for powered flight, or lock into a
## spread glide; the feet tuck up out of the way.
func _tick_flier_air(delta: float) -> void:
	var flap_hz := _flier_flap_cycle_hz * _flier_flap_hz_scale
	var flap_deg := _flier_wing_flap * _flier_flap_amp_scale
	var glide_raise := _flier_glide_raise * _flier_glide_scale
	var tuck := _flier_leg_tuck * _flier_tuck_scale
	var direction := _param_float("direction", 0.0)
	var vertical_speed := _param_float("vertical_speed", 0.0)
	var gliding := _motion_state == "glide"

	_flap_phase += delta * flap_hz
	var beat := sin(TAU * _flap_phase)
	if not gliding:
		# A fresh tap ("flap") is the strongest downstroke and gives the most lift.
		var power := 1.0 if _motion_state == "flap" else 0.72
		var pulse := absf(beat) * _flier_flap_squash * power
		_target_squash = Vector2(1.0 + pulse, 1.0 - pulse)
		_target_offset.y = -absf(beat) * _flier_flap_lift * power

	for limb in _limbs:
		limb["target"] = 0.0
		match limb["role"]:
			"wing":
				if gliding:
					var flex := sin(TAU * _flap_phase * 0.15) * deg_to_rad(2.0)
					limb["target"] = _rotation_sign(limb, Vector2.UP) * glide_raise + flex
				else:
					var power_amp := 1.0 if _motion_state == "flap" else 0.82
					limb["target"] = _rotation_sign(limb, Vector2.DOWN) * flap_deg * beat * power_amp
			"leg":
				limb["target"] = _rotation_sign(limb, Vector2.UP) * tuck
			_:
				pass

	_target_tilt = direction * _flier_tilt
	if gliding:
		var pitch := clampf(vertical_speed / 500.0, -1.0, 1.0)
		_target_tilt += pitch * _flier_dive_pitch * _facing


## Resolves the flier archetype from the drawn build (unless the profile forces
## one) and phases the legs for an alternating walk or a two-footed hop.
func _assign_bird_style(diag: float) -> void:
	_bird_style = ""
	if _flier_style == "auto":
		_bird_style = _detect_bird_style(diag)
	elif _flier_style != "":
		_bird_style = _flier_style
	_cache_flier_style_tuning()

	var legs: Array = []
	for limb in _limbs:
		if limb["role"] == "leg":
			legs.append(limb)
	legs.sort_custom(func(a, b): return a["joint"].x < b["joint"].x)
	var hop := _bird_style == "flitter"
	for leg_index in range(legs.size()):
		legs[leg_index]["phase"] = 0.0 if hop else PI * float(leg_index)


func _detect_bird_style(diag: float) -> String:
	var max_wing := 0.0
	var max_leg := 0.0
	for limb in _limbs:
		if limb["role"] == "wing":
			max_wing = maxf(max_wing, limb["length"])
		elif limb["role"] == "leg":
			max_leg = maxf(max_leg, limb["length"])
	var span := maxf(1.0, diag)
	var wing_ratio := max_wing / span
	var leg_ratio := max_leg / span
	var leg_vs_wing := max_leg / maxf(max_wing, 1.0)
	# Almost no wings -> a ground bird; legs rivalling the wings -> a strider;
	# prominent wings with tucked-up legs -> a soaring raptor; else a songbird.
	if wing_ratio < 0.16:
		return "strider" if leg_ratio > 0.12 else "flitter"
	if leg_vs_wing > 0.75 and leg_ratio > 0.20:
		return "strider"
	if wing_ratio > 0.33 and leg_ratio < 0.22:
		return "soarer"
	return "flitter"


func _flier_style_tuning() -> Dictionary:
	match _bird_style:
		"soarer":
			return {
				"flap_hz": 0.62, "flap_amp": 1.28, "glide": 1.5, "tuck": 1.6,
				"stride": 1.4, "leg": 1.0, "bob": 0.7
			}
		"strider":
			return {
				"flap_hz": 1.0, "flap_amp": 0.62, "glide": 0.5, "tuck": 0.35,
				"stride": 1.5, "leg": 1.35, "bob": 1.0
			}
		"flitter":
			return {
				"flap_hz": 1.32, "flap_amp": 0.88, "glide": 0.7, "tuck": 0.9,
				"stride": 0.8, "leg": 1.15, "bob": 1.5
			}
		_:
			return {
				"flap_hz": 1.0, "flap_amp": 1.0, "glide": 1.0, "tuck": 1.0,
				"stride": 1.0, "leg": 1.0, "bob": 1.0
			}


func _tick_swimmer(delta: float, speed: float) -> void:
	if _wave_lines.is_empty():
		return
	var swimming := _motion_state == "swim" and speed > 4.0
	var speed_ratio := clampf(_param_float("speed_ratio", 0.0), 0.0, 1.0)
	var target_amp := _swimmer_wave_amplitude * (0.35 + 0.65 * speed_ratio) if swimming else 0.0
	_wave_amp = lerpf(_wave_amp, target_amp, 1.0 - exp(-6.0 * delta))

	if _wave_amp <= 0.05:
		if _wave_dirty:
			for entry in _wave_lines:
				(entry["line"] as Line2D).points = entry["base"]
			_wave_dirty = false
		return

	_wave_phase += speed * delta / _swimmer_wave_length
	var head := _head_direction
	if head.length() <= 0.001:
		head = _swimmer_head_direction
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
				* sin(TAU * (point.x / _swimmer_wave_length) * tail_sign - TAU * _wave_phase)
			displaced[index] = point
		line.points = displaced
	_wave_dirty = true


func _tick_hopper(_delta: float) -> void:
	var charge_ratio := clampf(_param_float("charge_ratio", 0.0), 0.0, 1.0)
	var direction := _param_float("direction", 0.0)

	match _motion_state:
		"charge":
			var crouch := _hopper_charge_squash * charge_ratio
			_target_squash = Vector2(1.0 + crouch, 1.0 - crouch)
			_target_offset.y = crouch * 20.0
		"jump":
			var stretch := _hopper_jump_stretch
			_target_squash = Vector2(1.0 - stretch * 0.5, 1.0 + stretch)
			_target_tilt = direction * _hopper_tilt
		"fall":
			var stretch := _hopper_jump_stretch * 0.5
			_target_squash = Vector2(1.0 - stretch * 0.4, 1.0 + stretch)
			_target_tilt = direction * _hopper_tilt
		_:
			pass
	_apply_impact_squash(_hopper_landing_squash)

	for limb in _limbs:
		limb["target"] = 0.0
		if limb["role"] != "leg":
			continue
		match _motion_state:
			"charge":
				limb["target"] = _rotation_sign(limb, Vector2.UP) * _hopper_leg_fold * charge_ratio
			"jump":
				limb["target"] = _rotation_sign(limb, Vector2.DOWN) * _hopper_leg_extend
			"fall":
				limb["target"] = _rotation_sign(limb, Vector2.DOWN) * _hopper_leg_extend * 0.45
			"landed":
				limb["target"] = _rotation_sign(limb, Vector2.UP) * _hopper_leg_fold * _impact_ratio()
			_:
				pass


## Bitmap fallback: no limbs to articulate, so only grounded squash/tilt cues.
func _tick_bitmap(delta: float, speed: float) -> void:
	var direction := _param_float("direction", 0.0)
	match _motion_state:
		"walk", "climb":
			if speed > 4.0:
				_gait_phase += speed * delta / _bitmap_stride_length
				_target_offset.y = -absf(sin(TAU * _gait_phase)) * _bitmap_walk_bob
				_target_tilt = direction * _bitmap_tilt
		"charge":
			var crouch := _bitmap_charge_squash * clampf(_param_float("charge_ratio", 0.0), 0.0, 1.0)
			_target_squash = Vector2(1.0 + crouch, 1.0 - crouch)
		"jump":
			var stretch := _bitmap_jump_stretch
			_target_squash = Vector2(1.0 - stretch * 0.5, 1.0 + stretch)
		"fall":
			var stretch := _bitmap_jump_stretch * 0.5
			_target_squash = Vector2(1.0 - stretch * 0.4, 1.0 + stretch)
		"flap":
			_flap_phase += delta * _bitmap_flap_cycle_hz
			var pulse := absf(sin(TAU * _flap_phase)) * _bitmap_flap_squash
			_target_squash = Vector2(1.0 + pulse, 1.0 - pulse)
		"swim":
			_target_tilt = direction * _bitmap_tilt
		_:
			pass
	_apply_impact_squash(_bitmap_landing_squash)


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


func _cache_profile_values() -> void:
	_leg_phase_ripple = _profile_float("leg_phase_ripple", 0.35)
	_walker_stride_length = maxf(8.0, _profile_float("stride_length", 44.0))
	_walker_leg_swing = deg_to_rad(_profile_float("leg_swing_degrees", 15.0))
	_walker_air_splay = deg_to_rad(_profile_float("air_splay_degrees", 10.0))
	_walker_walk_bob = _profile_float("walk_bob", 1.6)
	_walker_tilt = deg_to_rad(_profile_float("tilt_degrees", 3.0))
	_walker_landing_squash = _profile_float("landing_squash", 0.1)

	_biped_stride_length = maxf(8.0, _profile_float("stride_length", 60.0))
	_biped_leg_swing = deg_to_rad(_profile_float("leg_swing_degrees", 25.0))
	_biped_arm_swing = deg_to_rad(_profile_float("arm_swing_degrees", 15.0))
	_biped_jump_tuck = deg_to_rad(_profile_float("jump_tuck_degrees", 26.0))
	_biped_air_arm = deg_to_rad(_profile_float("air_arm_degrees", 30.0))
	_biped_walk_bob = _profile_float("walk_bob", 2.2)
	_biped_tilt = deg_to_rad(_profile_float("tilt_degrees", 3.0))
	_biped_landing_squash = _profile_float("landing_squash", 0.12)

	_flier_ground_stride_length = maxf(8.0, _profile_float("ground_stride_length", 26.0))
	_flier_leg_swing = deg_to_rad(_profile_float("leg_swing_degrees", 22.0))
	_flier_walk_bob = _profile_float("walk_bob", 2.4)
	_flier_ground_tilt = deg_to_rad(_profile_float("ground_tilt_degrees", 4.0))
	_flier_landing_squash = _profile_float("landing_squash", 0.12)
	_flier_flap_cycle_hz = _profile_float("flap_cycle_hz", 6.5)
	_flier_wing_flap = deg_to_rad(_profile_float("wing_flap_degrees", 40.0))
	_flier_glide_raise = deg_to_rad(_profile_float("glide_raise_degrees", 12.0))
	_flier_leg_tuck = deg_to_rad(_profile_float("leg_tuck_degrees", 12.0))
	_flier_flap_squash = _profile_float("flap_squash", 0.12)
	_flier_flap_lift = _profile_float("flap_lift", 5.0)
	_flier_tilt = deg_to_rad(_profile_float("tilt_degrees", 8.0))
	_flier_dive_pitch = deg_to_rad(_profile_float("dive_pitch_degrees", 6.0))
	_flier_style = _profile_string("flight_style", "")
	_cache_flier_style_tuning()

	_swimmer_wave_length = maxf(20.0, _profile_float("wave_length", 70.0))
	_swimmer_wave_amplitude = _profile_float("wave_amplitude", 5.0)
	_swimmer_head_direction = _profile_vector2("head_direction", Vector2.RIGHT)

	_hopper_leg_fold = deg_to_rad(_profile_float("leg_fold_degrees", 22.0))
	_hopper_leg_extend = deg_to_rad(_profile_float("leg_extend_degrees", 24.0))
	_hopper_charge_squash = _profile_float("charge_squash", 0.22)
	_hopper_jump_stretch = _profile_float("jump_stretch", 0.14)
	_hopper_tilt = deg_to_rad(_profile_float("tilt_degrees", 4.0))
	_hopper_landing_squash = _profile_float("landing_squash", 0.18)

	_bitmap_stride_length = maxf(8.0, _profile_float("stride_length", 44.0))
	_bitmap_walk_bob = _profile_float("walk_bob", 2.0)
	_bitmap_tilt = deg_to_rad(_profile_float("tilt_degrees", 3.0))
	_bitmap_charge_squash = _profile_float("charge_squash", 0.2)
	_bitmap_jump_stretch = _profile_float("jump_stretch", 0.12)
	_bitmap_flap_cycle_hz = _profile_float("flap_cycle_hz", 6.5)
	_bitmap_flap_squash = _profile_float("flap_squash", 0.1)
	_bitmap_landing_squash = _profile_float("landing_squash", 0.12)


func _cache_flier_style_tuning() -> void:
	match _bird_style:
		"soarer":
			_flier_flap_hz_scale = 0.62
			_flier_flap_amp_scale = 1.28
			_flier_glide_scale = 1.5
			_flier_tuck_scale = 1.6
			_flier_stride_scale = 1.4
			_flier_leg_scale = 1.0
			_flier_bob_scale = 0.7
		"strider":
			_flier_flap_hz_scale = 1.0
			_flier_flap_amp_scale = 0.62
			_flier_glide_scale = 0.5
			_flier_tuck_scale = 0.35
			_flier_stride_scale = 1.5
			_flier_leg_scale = 1.35
			_flier_bob_scale = 1.0
		"flitter":
			_flier_flap_hz_scale = 1.32
			_flier_flap_amp_scale = 0.88
			_flier_glide_scale = 0.7
			_flier_tuck_scale = 0.9
			_flier_stride_scale = 0.8
			_flier_leg_scale = 1.15
			_flier_bob_scale = 1.5
		_:
			_flier_flap_hz_scale = 1.0
			_flier_flap_amp_scale = 1.0
			_flier_glide_scale = 1.0
			_flier_tuck_scale = 1.0
			_flier_stride_scale = 1.0
			_flier_leg_scale = 1.0
			_flier_bob_scale = 1.0


func _print_rig_build_timing(started_usec: int) -> void:
	var elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	print("%s rig build %.2f ms (%s, %d limbs)" % [name, elapsed_ms, _rig_type, _limbs.size()])


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


func _detect_biped_head(strokes: Array) -> Dictionary:
	var bounds := get_stroke_bounds()
	var bounds_center := bounds.get_center()
	var diag := maxf(1.0, bounds.size.length())
	var best_score := -INF
	var best := {"found": false}

	for index in range(strokes.size()):
		var stroke: Dictionary = strokes[index]
		var points: PackedVector2Array = stroke["points"]
		if points.size() < 2:
			continue
		var box := _cached_stroke_bounds(stroke)
		var center := box.get_center()
		var length := _cached_stroke_length(stroke)
		var area := maxf(1.0, _cached_stroke_area(stroke))
		var aspect := box.size.x / maxf(1.0, box.size.y)
		var roundness := 1.0 - clampf(absf(aspect - 1.0), 0.0, 1.0)
		var size_ratio := sqrt(area) / diag
		var size_score := 1.0 - clampf(absf(size_ratio - 0.24) / 0.28, 0.0, 1.0)
		var vertical_extreme := clampf(
			absf(center.y - bounds_center.y) / maxf(1.0, bounds.size.y * 0.5),
			0.0,
			1.0
		)
		var closed_radius := maxf(4.0, minf(box.size.x, box.size.y) * 0.45)
		var closed := _cached_stroke_endpoint_gap_sq(stroke) <= closed_radius * closed_radius
		var long_penalty := clampf(length / diag - 1.35, 0.0, 1.0) * 2.0
		var score := (5.0 if closed else 0.0) \
			+ roundness * 2.0 \
			+ size_score * 1.5 \
			+ vertical_extreme * 2.0 \
			- long_penalty

		if score > best_score:
			best_score = score
			best = {
				"found": true,
				"stroke_index": index,
				"center": center,
				"score": score
			}

	if best_score < 1.5:
		return {"found": false}
	return best


func _detect_swimmer_head_sign(strokes: Array, axis: Vector2, center: Vector2) -> float:
	var bounds := get_stroke_bounds()
	var diag := maxf(1.0, bounds.size.length())
	var all_points := _all_stroke_points(strokes)
	var min_proj := INF
	var max_proj := -INF
	for point in all_points:
		var projected := (point - center).dot(axis)
		min_proj = minf(min_proj, projected)
		max_proj = maxf(max_proj, projected)

	var span := maxf(1.0, max_proj - min_proj)
	var low_cut := min_proj + span * 0.38
	var high_cut := max_proj - span * 0.38
	var low_eye_score := 0.0
	var high_eye_score := 0.0
	var low_endpoint_count := 0
	var high_endpoint_count := 0
	var low_point_count := 0
	var high_point_count := 0
	var bounds_area := maxf(1.0, bounds.size.x * bounds.size.y)

	for stroke in strokes:
		var points: PackedVector2Array = stroke["points"]
		if points.is_empty():
			continue

		var box := _cached_stroke_bounds(stroke)
		var stroke_center_proj := (box.get_center() - center).dot(axis)
		var length := _cached_stroke_length(stroke)
		var area := _cached_stroke_area(stroke)
		var closed_radius := maxf(4.0, minf(box.size.x, box.size.y) * 0.45)
		var closed := _cached_stroke_endpoint_gap_sq(stroke) <= closed_radius * closed_radius
		var compact := (closed and area < bounds_area * 0.10 and length < diag * 0.55) \
			or length < diag * 0.16 \
			or area < bounds_area * 0.035
		if compact and stroke_center_proj <= low_cut:
			low_eye_score += 1.0
		elif compact and stroke_center_proj >= high_cut:
			high_eye_score += 1.0

		if not closed:
			var first_proj := (points[0] - center).dot(axis)
			var last_proj := (points[points.size() - 1] - center).dot(axis)
			if first_proj <= low_cut:
				low_endpoint_count += 1
			elif first_proj >= high_cut:
				high_endpoint_count += 1
			if last_proj <= low_cut:
				low_endpoint_count += 1
			elif last_proj >= high_cut:
				high_endpoint_count += 1

		for point in points:
			var projected := (point - center).dot(axis)
			if projected <= low_cut:
				low_point_count += 1
			elif projected >= high_cut:
				high_point_count += 1

	if absf(high_eye_score - low_eye_score) >= 0.75:
		return 1.0 if high_eye_score > low_eye_score else -1.0

	if absi(high_endpoint_count - low_endpoint_count) >= 1:
		var tail_sign := 1.0 if high_endpoint_count > low_endpoint_count else -1.0
		return -tail_sign

	if absi(high_point_count - low_point_count) >= 2:
		return 1.0 if high_point_count > low_point_count else -1.0

	var fallback := _profile_vector2("head_direction", Vector2.RIGHT)
	if fallback.length() <= 0.001:
		fallback = Vector2.RIGHT
	return 1.0 if axis.dot(fallback.normalized()) >= 0.0 else -1.0


func _all_stroke_points(strokes: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for stroke in strokes:
		points.append_array(stroke["points"])
	return points


func _principal_axis(points: PackedVector2Array, center: Vector2) -> Vector2:
	var xx := 0.0
	var xy := 0.0
	var yy := 0.0
	for point in points:
		var local := point - center
		xx += local.x * local.x
		xy += local.x * local.y
		yy += local.y * local.y
	if absf(xx) + absf(yy) <= 0.001:
		return Vector2.RIGHT
	var angle := 0.5 * atan2(2.0 * xy, xx - yy)
	return Vector2(cos(angle), sin(angle)).normalized()


func _rotate_strokes(strokes: Array, rotation: float, pivot: Vector2) -> void:
	for index in range(strokes.size()):
		var stroke: Dictionary = strokes[index]
		var points: PackedVector2Array = stroke["points"]
		for point_index in range(points.size()):
			points[point_index] = pivot + (points[point_index] - pivot).rotated(rotation)
		stroke["points"] = points
		strokes[index] = stroke
	_refresh_vector_bounds(strokes)


func _translate_strokes(strokes: Array, offset: Vector2) -> void:
	for index in range(strokes.size()):
		var stroke: Dictionary = strokes[index]
		var points: PackedVector2Array = stroke["points"]
		for point_index in range(points.size()):
			points[point_index] += offset
		stroke["points"] = points
		strokes[index] = stroke
	_refresh_vector_bounds(strokes)


func _realign_vector_strokes(strokes: Array) -> void:
	_refresh_vector_bounds(strokes)
	var bounds := get_stroke_bounds()
	var offset := Vector2(-bounds.get_center().x, 0.0)
	if _align == "bottom":
		offset.y = _ground_offset - (bounds.position.y + bounds.size.y)
	else:
		offset.y = -bounds.get_center().y
	if offset.length() > 0.001:
		_translate_strokes(strokes, offset)


func _refresh_vector_bounds(strokes: Array) -> void:
	_refresh_vector_stroke_metrics(strokes)
	var points := _all_stroke_points(strokes)
	if points.is_empty():
		return
	_stroke_bounds = _points_bounds(points)
	analysis["bounds"] = {
		"x": _stroke_bounds.position.x,
		"y": _stroke_bounds.position.y,
		"width": _stroke_bounds.size.x,
		"height": _stroke_bounds.size.y
	}
	analysis["aspect_ratio"] = _stroke_bounds.size.x / maxf(0.001, _stroke_bounds.size.y)


func _stroke_is_closed(points: PackedVector2Array, radius: float) -> bool:
	if points.size() < 3:
		return false
	return points[0].distance_to(points[points.size() - 1]) <= radius


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


func _cached_stroke_length(stroke: Dictionary) -> float:
	var value: Variant = stroke.get("length")
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return _polyline_length(stroke["points"])


func _cached_stroke_bounds(stroke: Dictionary) -> Rect2:
	var value: Variant = stroke.get("bounds")
	if value is Rect2:
		return value
	return _points_bounds(stroke["points"])


func _cached_stroke_area(stroke: Dictionary) -> float:
	var value: Variant = stroke.get("area")
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	var bounds := _cached_stroke_bounds(stroke)
	return bounds.size.x * bounds.size.y


func _cached_stroke_endpoint_gap_sq(stroke: Dictionary) -> float:
	var value: Variant = stroke.get("endpoint_gap_sq")
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	var points: PackedVector2Array = stroke["points"]
	if points.is_empty():
		return 0.0
	return points[0].distance_squared_to(points[points.size() - 1])


func _distance_sq_to_points(
	point: Vector2,
	points: PackedVector2Array,
	stop_at_sq: float = INF
) -> float:
	var best := INF
	for candidate in points:
		best = minf(best, point.distance_squared_to(candidate))
		if best <= stop_at_sq:
			return best
	return best


func _distance_to_points(point: Vector2, points: PackedVector2Array) -> float:
	return sqrt(_distance_sq_to_points(point, points))


func _gap_sq_to_body(
	point: Vector2,
	strokes: Array,
	in_body: Array,
	stop_at_sq: float = INF
) -> float:
	var best := INF
	for index in range(strokes.size()):
		if not in_body[index]:
			continue
		var points: PackedVector2Array = strokes[index]["points"]
		best = minf(best, _distance_sq_to_points(point, points, minf(best, stop_at_sq)))
		if best <= stop_at_sq:
			return best
	return best


func _gap_to_body(point: Vector2, strokes: Array, in_body: Array) -> float:
	return sqrt(_gap_sq_to_body(point, strokes, in_body))


func _min_gap_sq_to_body(
	points: PackedVector2Array,
	strokes: Array,
	in_body: Array,
	stop_at_sq: float = INF
) -> float:
	var best := INF
	for point in points:
		best = minf(best, _gap_sq_to_body(point, strokes, in_body, minf(best, stop_at_sq)))
		if best <= stop_at_sq:
			return best
	return best


func _min_gap_to_body(points: PackedVector2Array, strokes: Array, in_body: Array) -> float:
	return sqrt(_min_gap_sq_to_body(points, strokes, in_body))


func _max_gap_sq_to_body(points: PackedVector2Array, strokes: Array, in_body: Array) -> float:
	var worst := 0.0
	for point in points:
		worst = maxf(worst, _gap_sq_to_body(point, strokes, in_body))
	return worst


func _max_gap_to_body(points: PackedVector2Array, strokes: Array, in_body: Array) -> float:
	return sqrt(_max_gap_sq_to_body(points, strokes, in_body))


## How many other non-body strokes hang off this stroke away from its
## anchored end. A high count means the stroke is a structural member (e.g. a
## torso with arms and legs hanging off it) rather than a free-swinging limb.
## Two contact tiers: another stroke's ENDPOINT may anchor onto this one with
## a sloppy gap (endpoint_radius), but mid-stroke proximity only counts as an
## actual touch/cross (tight interior_radius) so limbs drawn close together
## never read as junctions. Contacts near this stroke's own anchor are
## ignored (limb pairs sharing one attachment point), as are body strokes (a
## limb diverging from the torso must not count the torso itself).
func _junction_count(
	index: int,
	strokes: Array,
	in_body: Array,
	endpoint_radius: float,
	interior_radius: float,
	attached_at_start: bool,
	anchor_exclusion: float
) -> int:
	var points: PackedVector2Array = strokes[index]["points"]
	var total_length := _polyline_length(points)
	if total_length <= 0.0:
		return 0
	var anchor := points[0] if attached_at_start else points[points.size() - 1]
	var endpoint_radius_sq := endpoint_radius * endpoint_radius
	var interior_radius_sq := interior_radius * interior_radius
	var anchor_exclusion_sq := anchor_exclusion * anchor_exclusion

	var arc: Array = []
	arc.resize(points.size())
	arc[0] = 0.0
	var running := 0.0
	for point_index in range(1, points.size()):
		running += points[point_index - 1].distance_to(points[point_index])
		arc[point_index] = running

	var count := 0
	for other in range(strokes.size()):
		if other == index or in_body[other]:
			continue
		var other_points: PackedVector2Array = strokes[other]["points"]
		var other_first := other_points[0]
		var other_last := other_points[other_points.size() - 1]
		for point_index in range(points.size()):
			var from_anchor: float = arc[point_index] if attached_at_start else total_length - arc[point_index]
			if from_anchor < total_length * 0.3:
				continue
			var mine := points[point_index]
			if mine.distance_squared_to(anchor) < anchor_exclusion_sq:
				continue
			if mine.distance_squared_to(other_first) < endpoint_radius_sq \
					or mine.distance_squared_to(other_last) < endpoint_radius_sq \
					or _distance_sq_to_points(mine, other_points, interior_radius_sq) < interior_radius_sq:
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
	return sqrt(_farthest_distance_sq(points, from))


func _farthest_distance_sq(points: PackedVector2Array, from: Vector2) -> float:
	var best := 0.0
	for point in points:
		best = maxf(best, from.distance_squared_to(point))
	return best


## Diagnostic string shown in the game HUD: skin mode, resolved style,
## and how many wing/leg limbs were articulated from the drawing.
func rig_summary() -> String:
	if skin_mode() != "vector":
		return skin_mode()
	var wings := 0
	var legs := 0
	for limb in _limbs:
		if limb["role"] == "wing":
			wings += 1
		elif limb["role"] == "leg":
			legs += 1
	var tag := _bird_style if _bird_style != "" else _rig_type
	return "%s W%d L%d" % [tag, wings, legs]
