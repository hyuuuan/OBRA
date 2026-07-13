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
const MAX_JOINT_ERROR := 22.0
const RECOVERY_PADDING := 180.0

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
var _body_bounds: Rect2 = Rect2()
var _body_polylines: Array = []
var _shape_count: int = 0
var _gait_phase: float = 0.0
var _build_generation: int = 0
var _rest_transforms: Dictionary = {}
var _world_bounds: Rect2 = Rect2(0.0, -520.0, 3760.0, 1200.0)
var _physics_frames_since_build: int = 0
var _recovery_count: int = 0
var _gravity: float = 980.0
var _stand_height: float = 0.0
var _support_blend: float = 0.0
var _stand_target_y: float = 0.0


func configure_rig(new_profile: Dictionary, new_entity_metadata: Dictionary = {}) -> void:
	configure_skin(new_profile, new_entity_metadata)
	_rig_type = _profile_string("rig_type", String(new_entity_metadata.get("rig_type", "none")))
	_entity_id = String(new_entity_metadata.get("id", ""))


func set_motion_state(state: String, params: Dictionary = {}) -> void:
	_motion_state = state
	_motion_params = params.duplicate(true)


func set_world_bounds(bounds: Rect2) -> void:
	if bounds.size.x > 1.0 and bounds.size.y > 1.0:
		_world_bounds = bounds


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


func debug_drive_torques() -> Array[float]:
	var torques: Array[float] = []
	for segment_value in _segments:
		torques.append(float((segment_value as Dictionary).get("last_drive_torque", 0.0)))
	return torques


func debug_max_joint_error() -> float:
	var maximum := 0.0
	for segment_value in _segments:
		maximum = maxf(maximum, _segment_joint_error(segment_value as Dictionary))
	return maximum


func debug_max_body_distance() -> float:
	if _primary_body == null:
		return 0.0
	var maximum := 0.0
	for body in _bodies:
		if is_instance_valid(body):
			maximum = maxf(maximum, body.global_position.distance_to(_primary_body.global_position))
	return maximum


func debug_recovery_count() -> int:
	return _recovery_count


func debug_primary_mass() -> float:
	return _primary_body.mass if _primary_body != null else 0.0


func debug_limb_layout() -> Array[Dictionary]:
	var layout: Array[Dictionary] = []
	for segment_value in _segments:
		var segment: Dictionary = segment_value
		if int(segment.get("chain_index", -1)) == 0:
			layout.append({
				"role": String(segment.get("role", "")),
				"limb_index": int(segment.get("limb_index", -1)),
				"side": float(segment.get("side", 0.0)),
				"attachment": Vector2(segment.get("attachment", Vector2.ZERO))
			})
	return layout


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
			_ensure_articulation(get_vector_strokes())
	else:
		_build_bitmap_fallback()
	_finalize_rig()
	analysis["physics_bodies"] = _bodies.size()
	analysis["physics_joints"] = _joints.size()
	analysis["active_ragdoll"] = _joints.size() > 0
	rig_built.emit(_primary_body != null)


func _physics_process(delta: float) -> void:
	if _primary_body == null:
		return
	_physics_frames_since_build += 1
	if _physics_frames_since_build > 4 and _rig_needs_recovery():
		_recover_rig()
		return
	if _segments.is_empty():
		return
	_update_stand_state(delta)
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

		# ONE coherent muscle per joint. It has exactly two jobs: (1) a stiff PD that
		# holds this joint at its drawn rest angle plus any gait offset, and (2) a
		# feedforward that cancels the static droop of everything hanging off it.
		# The PD is a Newton-correct couple (+child / -parent); for the ground rig
		# types the torso is lock_rotation, so those reactions are absorbed by the
		# rotation lock while the legs hold and the ground reaction through the
		# planted feet carries the body weight. No competing servos.
		var target := _target_angle_for(segment)
		var current := wrapf(child.rotation - parent.rotation - float(segment["rest_relative"]), -PI, PI)
		var error := wrapf(target - current, -PI, PI)
		var relative_velocity := child.angular_velocity - parent.angular_velocity
		# PinJoint motors do not expose a useful per-joint impulse cap in this
		# setup. Driving the motor and applying PD torque at the same time made
		# light limbs fight two solvers and launch the complete rig. Use one
		# bounded muscle controller instead.
		var mass_scale := clampf(minf(parent.mass, child.mass) / 0.4, 0.45, 1.35)
		var distal_scale := 1.0 / (1.0 + float(int(segment["chain_index"])) * 0.35)
		var spring := clampf(float(profile.get("joint_spring", 1050.0)) * 0.7 * mass_scale * distal_scale, 350.0, 1500.0)
		# Damping tracks sqrt(spring) so the stiff pose spring stays near-critically
		# damped instead of ringing itself unstable at 60 Hz.
		var damping := clampf(sqrt(spring) * 6.5 * mass_scale, 45.0, 240.0)
		var torque_limit := clampf(float(profile.get("joint_torque_limit", 2600.0)) * 0.7 * mass_scale * distal_scale, 1000.0, 4200.0)
		var pd := clampf(error * spring - relative_velocity * damping, -torque_limit, torque_limit)
		# Gravity compensation: the muscle PD above is far too weak to hold a limb
		# out against its own weight (a horizontal limb needs ~mass*g*lever, which
		# dwarfs the PD's bounded output), so without this the limbs droop to the
		# floor like dead bones. Add the static torque that holds this joint's whole
		# distal subtree up, leaving the PD free to supply pose/gait tension.
		# While the stand-support carries the creature it cancels gravity, so the
		# compensation is faded out in lockstep to avoid over-rotating a weightless
		# limb (residual effective gravity is (1 - _support_blend) * g).
		var gravity_comp := _gravity_hold_torque(segment, joint) * (1.0 - _support_blend)
		segment["last_drive_torque"] = pd + gravity_comp
		# The PD muscle spans the joint, so it is a couple: equal and opposite on the
		# two bodies. Gravity compensation is an EXTERNAL anti-droop assist on the limb,
		# not a muscle, so it acts on the child only -- reacting it back onto the parent
		# torso is what summed into a net torque and spun multi-limb creatures in place.
		child.apply_torque(pd + gravity_comp)
		parent.apply_torque(-pd)
		# gravity_comp is an undamped, position-dependent feed-forward torque that
		# excites a whole-limb swing the joint's relative-velocity PD cannot see. When
		# the limb has no active gait target it is meant to hold still, so bleed that
		# swing and any residual drift with drag on the child's ABSOLUTE angular and
		# linear velocity (child only, removing energy instead of redistributing it).
		# Skipped while actively driven, so gait and jumps are unaffected.
		if absf(target) < 0.0001:
			child.apply_torque(-child.angular_velocity * child.mass * 900.0)
			child.apply_central_force(-child.linear_velocity * child.mass * 6.0)

	_apply_stand_support()


## Decide whether the creature is standing on ground within leg reach and update
## the smooth support blend. A downward ray from the torso finds the floor; if it
## is within reach and the torso is not sailing well above stand height (a jump),
## the blend ramps toward 1. move_toward keeps on/off transitions gradual so the
## creature does not pop when it leaves or lands on the ground.
func _update_stand_state(delta: float) -> void:
	var want := 0.0
	# Never suppress a jump: while jumping the ground reaction must be gone so the
	# impulse actually lifts the creature.
	if _rig_type in ["walker", "biped", "hopper"] and _motion_state != "jump" \
			and _primary_body != null and _stand_height > 1.0 and _primary_body.gravity_scale > 0.01:
		var from := _primary_body.global_position
		if is_finite(from.x) and is_finite(from.y):
			var space := _primary_body.get_world_2d().direct_space_state
			var reach := _stand_height + 48.0
			var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, reach))
			var exclude: Array[RID] = []
			for body in _bodies:
				if is_instance_valid(body):
					exclude.append(body.get_rid())
			query.exclude = exclude
			query.collide_with_areas = false
			var hit := space.intersect_ray(query)
			if not hit.is_empty():
				_stand_target_y = float((hit["position"] as Vector2).y) - _stand_height
				if from.y - _stand_target_y > -14.0:
					want = 1.0
	_support_blend = move_toward(_support_blend, want, delta * 6.0)
	if _primary_body != null:
		_primary_body.standing_hint = _support_blend > 0.5


## Virtual-leg support. Pin-jointed legs cannot rigidly hold an upright torso up
## (a straight leg under a top load is an inverted pendulum needing unphysical
## joint stiffness), so the torso would pancake onto its own body shape. Instead,
## while standing the whole rig is made weightless (each body's own gravity is
## cancelled, scaled by the blend) and an over-damped spring servos it to its
## natural drawn standing height. The creature therefore holds the exact pose the
## player drew, feet on the floor, with no torso-versus-legs bounce because every
## body receives the same positioning acceleration. It is static while standing
## (no perpetual motion) and disengages for jumps/falls when ground leaves reach.
func _apply_stand_support() -> void:
	if _support_blend <= 0.001 or _primary_body == null:
		return
	var vertical_velocity := _primary_body.linear_velocity.y
	var height_error := _primary_body.global_position.y - _stand_target_y
	# Positioning acceleration: over-damped spring on height. With gravity already
	# cancelled below, equilibrium is zero error (no sag). Bounded so a hard landing
	# is absorbed, not bounced.
	var position_accel := clampf(height_error * 60.0 + vertical_velocity * 30.0, -_gravity * 0.5, _gravity * 0.6)
	for body in _bodies:
		if not is_instance_valid(body):
			continue
		# Cancel most of this body's own gravity (respecting its gravity_scale) plus
		# the shared positioning term, all faded by the blend. A small fraction of
		# weight is deliberately left uncancelled so the feet keep pressing on the
		# floor and stay registered as grounded.
		var accel_up := (_gravity * body.gravity_scale * 0.9 + position_accel) * _support_blend
		body.apply_central_force(Vector2(0.0, -accel_up * body.mass))


## Static hold torque for a joint: the gravitational torque of its whole distal
## subtree taken about the joint pivot, negated so the muscle cancels the droop.
## apply_torque is a free couple, so a torque computed about the pivot balances the
## limb's rotation about that pinned point. gravity_scale folds in float states.
func _gravity_hold_torque(segment: Dictionary, joint: PinJoint2D) -> float:
	var support: Array = segment.get("support", [])
	if support.is_empty():
		support = [segment["body"]]
	var pivot := joint.global_position
	var torque := 0.0
	for support_value in support:
		var body := support_value as ActiveRigBody2D
		if not is_instance_valid(body):
			continue
		torque -= (body.global_position.x - pivot.x) * body.mass * _gravity * body.gravity_scale
	# Cap by the joint's muscle scale, not by the raw cantilever demand. Holding a
	# long horizontal subtree (e.g. a snake stretched out) would otherwise need
	# tens of thousands of torque and blow the light chain pins apart; physically
	# such a limb should just sag/rest, which this clamp allows. Standing walkers
	# do not rely on this term at all (the stand-support fades it to zero), so a
	# tight cap costs them nothing while keeping every rig's pins stable.
	var hold_limit := float(profile.get("joint_torque_limit", 3000.0)) * 1.5
	return clampf(torque, -hold_limit, hold_limit)


func _target_angle_for(segment: Dictionary) -> float:
	var role := String(segment["role"])
	var chain_index := int(segment["chain_index"])
	var phase := _gait_phase + float(segment["phase"]) + float(chain_index) * 0.28
	var moving := bool(_motion_params.get("moving", false))
	# Species-specific gait wins; then a generic per-rig_type gait so a creature whose
	# entity_id is not hardcoded still animates while moving. When neither has an
	# opinion the limb holds its rest pose (0) so an uncontrolled creature stands still
	# rather than twitching.
	var species := _species_target_angle(segment, role, phase, moving)
	if not is_nan(species):
		return species
	var generic := _generic_target_angle(segment, role, phase, moving)
	if not is_nan(generic):
		return generic
	return 0.0


## Tuned per-species gait. Returns NAN to mean "no active opinion" so the caller
## can fall through to the generic net and then the idle pose.
func _species_target_angle(segment: Dictionary, role: String, phase: float, moving: bool) -> float:
	var limb_index := int(segment["limb_index"])
	var chain_index := int(segment["chain_index"])
	var side := signf(float(segment.get("side", 1.0)))
	var direction := float(_motion_params.get("direction", 0.0))

	if _entity_id == "spider" and role == "leg":
		if _motion_state in ["walk", "climb"] and moving:
			var alternating := 0.0 if limb_index % 2 == 0 else PI
			var stride := sin(phase + alternating)
			# Proximal segments reach while distal segments bend in the opposite
			# direction. Driving both the same way turns an articulated leg into a
			# rigid paddle and pulls the abdomen onto the floor.
			return deg_to_rad(18.0) * stride if chain_index == 0 else deg_to_rad(-26.0) * stride
		return NAN

	if _entity_id in ["cat", "dog"] and role == "leg":
		if _motion_state == "walk" and moving:
			var amplitude := deg_to_rad(19.0 if _entity_id == "cat" else 17.0)
			var stride := sin(phase + (PI if limb_index % 2 else 0.0))
			return amplitude * stride if chain_index == 0 else amplitude * -0.72 * stride
		if _motion_state in ["jump", "fall"]:
			return deg_to_rad(10.0) * (-1.0 if limb_index % 2 else 1.0)
		return NAN

	if _rig_type == "biped":
		if _motion_state == "walk" and moving:
			var amp := deg_to_rad(30.0 if role == "leg" else 18.0)
			var swing := sin(phase)
			return amp * swing if chain_index == 0 else amp * -0.62 * swing
		if _motion_state in ["jump", "fall"]:
			return deg_to_rad(-24.0 if role == "leg" else -35.0) * side
		if _motion_state == "climb":
			return deg_to_rad(28.0) * sin(phase + (PI if limb_index % 2 else 0.0))
		return NAN

	if _rig_type == "hopper" and role == "leg":
		match _motion_state:
			"charge":
				return deg_to_rad(-34.0) * maxf(0.15, float(_motion_params.get("charge_ratio", 0.0))) * side
			"jump":
				return deg_to_rad(38.0) * side
			"fall":
				return deg_to_rad(18.0) * side
			_:
				return NAN

	if _rig_type == "flier":
		if role == "wing":
			if _motion_state in ["fly", "flap"]:
				var hz_scale := 1.25 if _entity_id == "butterfly" else 1.0
				return deg_to_rad(48.0) * sin(phase * hz_scale) * side
			if _motion_state == "glide":
				return deg_to_rad(-18.0) * side
			# Grounded and moving: gentle wing beat; standing still holds the wing.
			if moving:
				return deg_to_rad(12.0) * sin(phase) * side
			return NAN
		if role == "leg" and _motion_state not in ["walk", "idle"]:
			return deg_to_rad(-20.0) * side
		return NAN

	if _entity_id == "fish" and role in ["tail", "fin", "limb"]:
		if _motion_state == "swim":
			return deg_to_rad(22.0) * sin(phase + float(limb_index) * 0.55)
		return NAN

	if _entity_id == "snake" and role == "chain":
		if moving or _motion_state == "swim":
			return deg_to_rad(28.0) * sin(phase + float(chain_index) * 0.72) * (1.0 if direction >= 0.0 else -1.0)
		return NAN

	return NAN


## Generic gait keyed on rig_type only, so a drawing whose entity_id is not one of
## the hardcoded species still animates. Returns NAN when it has no opinion.
func _generic_target_angle(segment: Dictionary, role: String, phase: float, moving: bool) -> float:
	var limb_index := int(segment["limb_index"])
	var chain_index := int(segment["chain_index"])
	match _rig_type:
		"walker":
			if role == "leg" and moving:
				var stride := sin(phase + (PI if limb_index % 2 else 0.0))
				return deg_to_rad(18.0) * stride if chain_index == 0 else deg_to_rad(18.0) * -0.7 * stride
		"swimmer":
			if (moving or _motion_state == "swim") and role in ["tail", "fin", "limb", "chain"]:
				return deg_to_rad(22.0) * sin(phase + float(chain_index) * 0.6)
		_:
			if moving and role in ["leg", "arm", "wing", "tail", "fin", "chain", "limb"]:
				return deg_to_rad(14.0) * sin(phase + (PI if limb_index % 2 else 0.0))
	return NAN


func _build_standard_rig(strokes: Array) -> void:
	_create_physics_root()
	var body_index := _select_body_stroke(strokes)
	var body_stroke: Dictionary = strokes[body_index]
	# The torso may be drawn as several overlapping strokes; gather them all so a
	# multi-stroke body reads as one torso and limbs touching any of its sub-strokes
	# still detect attachment.
	var body_info := _gather_body_strokes(strokes, body_index)
	var body_indices: Dictionary = body_info["indices"]
	_body_pool = body_info["pool"]
	_body_polylines = body_info["polylines"]
	_body_bounds = _bounds_for_points(_body_pool)
	var body_center := _points_center(_body_pool)
	_primary_body = _create_body("Torso", body_center, _mass_for_stroke(body_stroke, 1.5))
	_primary_body.angular_damp = 4.8
	# Ground animals use the abdomen/torso as an active reference frame. Letting
	# that reference freely roll makes every correctly inferred limb follow the
	# roll and turns a walker into a wheel. Climbing code temporarily releases the
	# spider root when it needs to align to a wall or ceiling.
	_primary_body.lock_rotation = _rig_type in ["walker", "biped", "hopper"]
	for gathered_index in body_indices:
		_add_stroke_to_body(_primary_body, strokes[gathered_index], body_center, gathered_index == body_index)

	var attachment_radius := clampf(get_stroke_bounds().size.length() * 0.14, 12.0, 40.0)
	var candidates: Array[Dictionary] = []
	var body_decorations: Array[Dictionary] = []
	for index in range(strokes.size()):
		if body_indices.has(index):
			continue
		var stroke: Dictionary = strokes[index]
		var points: PackedVector2Array = stroke["points"]
		# A closed, roundish stroke that is not the torso is a head / eye / blob.
		# Weld it to the torso as decoration instead of articulating it: a closed
		# loop otherwise splits into two limb "paths" that flop around AND steal the
		# limb-count budget from the real arms and legs (which then fail to attach,
		# leaving the creature with no feet and nothing to stand on).
		if _stroke_is_closed(points, float(stroke.get("width", 5.0))):
			var blob_bounds := _bounds_for_points(points)
			var blob_compactness := minf(blob_bounds.size.x, blob_bounds.size.y) / maxf(1.0, maxf(blob_bounds.size.x, blob_bounds.size.y))
			if blob_compactness > 0.55:
				body_decorations.append(stroke)
				continue
		var paths := _paths_attached_to_body(points, attachment_radius)
		if paths.is_empty() or _stroke_length(points) < MIN_SEGMENT_LENGTH:
			body_decorations.append(stroke)
			continue
		for path_value in paths:
			var path: PackedVector2Array = path_value
			if _stroke_length(path) >= MIN_SEGMENT_LENGTH:
				candidates.append({"path": path, "stroke": stroke, "attachment": path[0]})
	# Stroke order is drawing-order, not anatomy. Stable spatial ordering gives
	# left/right counterparts predictable gait phases regardless of when the
	# player happened to draw each leg.
	candidates.sort_custom(_appendage_candidate_less)
	var next_limb_index := 0
	var limb_limit := _limb_limit_for_entity()
	for candidate in candidates:
		if next_limb_index >= limb_limit:
			body_decorations.append(candidate["stroke"])
			continue
		_build_limb_path(candidate["path"], candidate["stroke"], next_limb_index, body_center)
		next_limb_index += 1
	for stroke in body_decorations:
		_add_stroke_to_body(_primary_body, stroke, body_center, false)


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
					"side": 1.0,
					"angle_limit": deg_to_rad(58.0),
					"parent_anchor": _body_local_anchor(parent, sampled[index]),
					"child_anchor": _body_local_anchor(body, sampled[index]),
					"last_drive_torque": 0.0
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
	var tip := path[path.size() - 1]
	var role := _role_for_limb(path[0], tip, body_center)
	var per_limb_cap := 2 if _entity_id != "snake" else MAX_SEGMENTS_PER_LIMB
	var segment_count := clampi(int(ceil(length / 38.0)), 1, per_limb_cap)
	if _minimum_limb_segments(role) >= 2 and length >= MIN_SEGMENT_LENGTH * 1.25:
		segment_count = maxi(segment_count, 2)
	segment_count = mini(segment_count, MAX_BODIES - _bodies.size())
	if segment_count <= 0:
		return
	var parent := _primary_body
	var side := (-1.0 if limb_index < 4 else 1.0) if _entity_id == "spider" else (-1.0 if tip.x < body_center.x else 1.0)
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
		var raw_mass := _mass_for_points(chunk, float(stroke.get("width", 5.0)))
		var limb_mass := clampf(raw_mass * (0.62 if segment_index == 0 else 0.48), 0.16, 0.62)
		var body := _create_body("Limb%02d_%d" % [limb_index, segment_index], center, limb_mass)
		body.gravity_scale = 0.48 if segment_index == 0 else 0.32
		body.angular_damp = 3.8 if segment_index == 0 else 4.6
		_configure_limb_contact(body, role, segment_index, segment_count)
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
			"phase": _phase_for_limb(limb_index, side),
			"side": side,
			"angle_limit": limit,
			"attachment": path[0],
			"parent_anchor": _body_local_anchor(parent, chunk[0]),
			"child_anchor": _body_local_anchor(body, chunk[0]),
			"last_drive_torque": 0.0
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


## Recover articulation for a creature drawn as a single continuous scribble. Runs only
## after the standard rig and only when it produced no joints; it never fabricates limbs
## the player did not draw — if the stroke has no clear radial appendages it leaves the
## single-body rig alone. Skipped entirely for rig_type "none" (physics objects and
## utilities), which must stay rigid, and for the empty-strokes bitmap path.
func _ensure_articulation(strokes: Array) -> void:
	if _joints.size() > 0 or strokes.is_empty():
		return
	if _rig_type == "none":
		return
	if get_stroke_bounds().size.length() < _target_size.length() * 0.5:
		return
	var body_index := _select_body_stroke(strokes)
	var body_stroke: Dictionary = strokes[body_index]
	var decomposition := _decompose_scribble(body_stroke)
	var limbs: Array = decomposition["limbs"]
	if limbs.is_empty():
		return
	# A single continuous scribble split into a torso core + its actual drawn spikes.
	_clear_rig()
	_create_physics_root()
	var body_pts: PackedVector2Array = decomposition["body"]
	var width := float(body_stroke.get("width", 6.0))
	var color := Color(body_stroke.get("color", Color.BLACK))
	_body_pool = body_pts.duplicate()
	_body_polylines = [body_pts]
	var body_center := _points_center(body_pts)
	_primary_body = _create_body("Torso", body_center, _mass_for_stroke(body_stroke, 1.5))
	_add_polyline_to_body(_primary_body, body_pts, width, color, body_center)
	var limb_limit := _limb_limit_for_entity()
	var limb_index := 0
	for limb_value in limbs:
		if limb_index >= limb_limit or _joints.size() >= MAX_JOINTS:
			break
		_build_limb_path(limb_value as PackedVector2Array, body_stroke, limb_index, body_center)
		limb_index += 1


## Detect limb-like radial spikes in a single continuous stroke and split it into a
## torso core plus outgoing limb paths (each from the valley near the body out to the
## peak tip). Returns empty limbs when the stroke has no clear appendages.
func _decompose_scribble(stroke: Dictionary) -> Dictionary:
	var empty := {"body": PackedVector2Array(), "limbs": []}
	var pts: PackedVector2Array = stroke["points"]
	if pts.size() < 7:
		return empty
	var center := _points_center(pts)
	var diag := _points_bounds(pts).size.length()
	if diag < 1.0:
		return empty
	var radii := PackedFloat32Array()
	for point in pts:
		radii.append(point.distance_to(center))
	var median_r := _median(radii)
	var prominence := 0.22 * diag
	var limbs: Array = []
	var i := 1
	while i < pts.size() - 1:
		if radii[i] > radii[i - 1] and radii[i] >= radii[i + 1]:
			var left := i
			while left > 0 and radii[left - 1] <= radii[left]:
				left -= 1
			var right := i
			while right < pts.size() - 1 and radii[right + 1] <= radii[right]:
				right += 1
			var valley := minf(radii[left], radii[right])
			if radii[i] - valley >= prominence and valley <= median_r * 1.15:
				var limb := pts.slice(left, i + 1)
				if _stroke_length(limb) >= MIN_SEGMENT_LENGTH * 2.0:
					limbs.append(limb)
				i = right + 1
				continue
		i += 1
	if limbs.is_empty():
		return empty
	var body := PackedVector2Array()
	for j in range(pts.size()):
		if radii[j] <= median_r * 1.25:
			body.append(pts[j])
	if body.size() < 3:
		body = pts
	return {"body": body, "limbs": limbs}


func _median(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


func _create_physics_root() -> void:
	_physics_root = Node2D.new()
	_physics_root.name = "GeneratedPhysicsRig"
	get_parent().add_child(_physics_root)


func _create_body(body_name: String, at: Vector2, body_mass: float) -> ActiveRigBody2D:
	var body := ActiveRigBody2D.new()
	body.name = body_name
	body.position = at
	body.mass = clampf(body_mass, 0.16, 5.0)
	body.gravity_scale = 1.0
	body.linear_damp = 0.55
	body.angular_damp = 2.2
	body.max_linear_speed = clampf(float(profile.get("max_linear_speed", 580.0)), 300.0, 620.0)
	body.max_angular_speed = clampf(float(profile.get("max_angular_speed", 8.0)), 5.0, 9.0)
	var material := PhysicsMaterial.new()
	material.friction = float(profile.get("friction", 0.78))
	material.bounce = float(profile.get("bounce", 0.02))
	body.physics_material_override = material
	_physics_root.add_child(body)
	# The bodies are physics-authoritative: the server drives their global
	# transform every tick. While parented under the (moving) morph node, any
	# transform activity elsewhere in that subtree — e.g. the per-frame camera
	# anchor update — re-syncs each body from its stale LOCAL transform, silently
	# teleporting it back in place and cancelling all locomotion. top_level makes
	# the global transform independent of the parent; preserve the world transform
	# across the switch so the built rig geometry stays put.
	var world_transform := body.global_transform
	body.top_level = true
	body.global_transform = world_transform
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
	joint.softness = clampf(float(profile.get("joint_softness", 0.0)), 0.0, 0.02)
	# Hard angular limits add a second constraint at the same anchor and become
	# numerically singular on short, light stroke segments. The bounded muscle
	# controller below provides a soft limit without poisoning the solver.
	joint.angular_limit_enabled = false
	joint.angular_limit_lower = -angular_limit
	joint.angular_limit_upper = angular_limit
	joint.motor_enabled = false
	joint.motor_target_velocity = 0.0
	_joints.append(joint)
	return joint


func _configure_limb_contact(
	body: ActiveRigBody2D,
	role: String,
	segment_index: int,
	segment_count: int
) -> void:
	var material := body.physics_material_override
	if material == null:
		material = PhysicsMaterial.new()
		body.physics_material_override = material
	var is_foot := role == "leg" and segment_index == segment_count - 1
	# Only feet should strongly grip the ground. High friction on every capsule in
	# a leg pins knees and hips to the terrain and makes the rig somersault around
	# whichever segment touched first.
	material.friction = clampf(
		float(profile.get("foot_friction", 1.05)) if is_foot else float(profile.get("limb_friction", 0.24)),
		0.05,
		1.4
	)
	material.bounce = 0.0


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
		_capture_rest_pose()
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	_compute_support_sets()
	_compute_stand_height()
	_physics_frames_since_build = 0


## Vertical distance from the torso centre down to the lowest drawn body in the
## rest pose. Holding the torso this far above the ground lands the drawn feet on
## the floor and keeps the torso body clear of it, so the creature stands in the
## exact pose the player drew instead of pancaking onto its own belly.
func _compute_stand_height() -> void:
	_stand_height = 0.0
	if _primary_body == null:
		return
	for body in _bodies:
		if not is_instance_valid(body):
			continue
		var relative: Transform2D = _rest_transforms.get(body.get_instance_id(), Transform2D.IDENTITY)
		_stand_height = maxf(_stand_height, relative.origin.y)
	# Sit low enough that the drawn feet press a few px into the floor instead of
	# grazing it, so contact actually registers and the controller reads the
	# creature as grounded (idle/walk/jump) rather than perpetually "falling".
	_stand_height -= 4.0


## For every joint, record the child body plus its whole distal subtree. The
## muscle controller uses this to hold each limb up against the weight of
## everything hanging off it (gravity compensation), so limbs keep tension
## instead of drooping to the floor like dead bones.
func _compute_support_sets() -> void:
	var children_of: Dictionary = {}
	for segment_value in _segments:
		var seg: Dictionary = segment_value
		var parent_id := (seg["parent"] as Object).get_instance_id()
		if not children_of.has(parent_id):
			children_of[parent_id] = []
		children_of[parent_id].append(seg)
	for segment_value in _segments:
		var seg: Dictionary = segment_value
		var support: Array = []
		var stack: Array = [seg["body"]]
		while not stack.is_empty():
			var body := stack.pop_back() as ActiveRigBody2D
			support.append(body)
			var body_id := body.get_instance_id()
			if children_of.has(body_id):
				for child_seg in children_of[body_id]:
					stack.append(child_seg["body"])
		seg["support"] = support
		# A leaf segment owns no further joints: it is the tip of its limb (a foot,
		# a hand, a fin end). The hybrid foot-plant only acts on leg leaves.
		seg["is_leaf"] = not children_of.has((seg["body"] as Object).get_instance_id())


func _clear_rig() -> void:
	_primary_body = null
	_bodies.clear()
	_joints.clear()
	_segments.clear()
	_body_pool = PackedVector2Array()
	_body_bounds = Rect2()
	_body_polylines = []
	_shape_count = 0
	_rest_transforms.clear()
	_physics_frames_since_build = 0
	_recovery_count = 0
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
		var points: PackedVector2Array = stroke["points"]
		max_length = maxf(max_length, _stroke_length(points))
		# Shoelace area is meaningless for an open bent limb because it silently
		# closes tip-to-root. That made a large spider leg look like the abdomen.
		if _stroke_is_closed(points, float(stroke.get("width", 5.0))):
			max_area = maxf(max_area, absf(_polygon_area(points)))
	var drawing_center := get_stroke_bounds().get_center()
	var drawing_radius := maxf(1.0, get_stroke_bounds().size.length() * 0.5)
	for index in range(strokes.size()):
		var stroke: Dictionary = strokes[index]
		var points: PackedVector2Array = stroke["points"]
		var stroke_bounds := _bounds_for_points(points)
		var stroke_center := stroke_bounds.get_center()
		var incoming := 0
		var attach_above := false
		var attach_below := false
		var radius := clampf(get_stroke_bounds().size.length() * 0.08, 6.0, 18.0)
		for other_index in range(strokes.size()):
			if index == other_index:
				continue
			var other: PackedVector2Array = strokes[other_index]["points"]
			var head_gap := _point_polyline_distance(other[0], points)
			var tail_gap := _point_polyline_distance(other[other.size() - 1], points)
			if head_gap <= radius or tail_gap <= radius:
				incoming += 1
				# Which end of the other stroke touches, and is that contact above or
				# below this stroke's centre? The torso is the hub that limbs radiate
				# from ABOVE (head/arms) and BELOW (legs); a head only has the body
				# joining it from below. This above-and-below test is what stops a big
				# round head from being chosen as the body of a stick figure.
				var contact := other[0] if head_gap <= tail_gap else other[other.size() - 1]
				if contact.y < stroke_center.y:
					attach_above = true
				else:
					attach_below = true
		var closed := _stroke_is_closed(points, float(stroke.get("width", 5.0)))
		var area_ratio := absf(_polygon_area(points)) / max_area if closed else 0.0
		var compactness := minf(stroke_bounds.size.x, stroke_bounds.size.y) / maxf(1.0, maxf(stroke_bounds.size.x, stroke_bounds.size.y))
		var centrality := 1.0 - clampf(stroke_center.distance_to(drawing_center) / drawing_radius, 0.0, 1.0)
		# A stroke that limbs join from both above and below is almost certainly the
		# torso. Weighted strongly so it beats the roundness bonus a head collects.
		var hub_bonus := 5.0 if attach_above and attach_below else 0.0
		var closed_weight := 7.0 if _entity_id in ["spider", "cat", "dog", "frog", "rabbit", "fish"] else 4.5
		var score := (closed_weight if closed else 0.0) + float(incoming) * 2.2 + hub_bonus \
			+ area_ratio * 1.6 + compactness * 0.7 + centrality * 1.8 \
			+ _stroke_length(points) / max_length * 0.25
		if score > best_score:
			best_score = score
			best_index = index
	return best_index


func _appendage_candidate_less(a: Dictionary, b: Dictionary) -> bool:
	var a_point := Vector2(a["attachment"])
	var b_point := Vector2(b["attachment"])
	var center := _body_bounds.get_center()
	if _entity_id == "spider":
		# A spider's four legs per side are a stronger anatomical constraint than
		# tiny floating-point differences around a near-vertical attachment.
		if not is_equal_approx(a_point.x, b_point.x):
			return a_point.x < b_point.x
		return a_point.y < b_point.y
	var a_side := 0 if a_point.x < center.x else 1
	var b_side := 0 if b_point.x < center.x else 1
	if a_side != b_side:
		return a_side < b_side
	if not is_equal_approx(a_point.y, b_point.y):
		return a_point.y < b_point.y
	return a_point.x < b_point.x


func _phase_for_limb(limb_index: int, _side: float) -> float:
	if _entity_id == "spider":
		# Candidates are sorted four left, four right. Opposite-side counterparts
		# alternate as a stable tetrapod gait: 0,2,5,7 versus 1,3,4,6.
		var side_group := limb_index / 4
		var rank_on_side := limb_index % 4
		return 0.0 if (rank_on_side + side_group) % 2 == 0 else PI
	if _rig_type in ["biped", "walker"]:
		return 0.0 if limb_index % 2 == 0 else PI
	return float(limb_index) * 0.47


func _paths_attached_to_body(points: PackedVector2Array, radius: float) -> Array:
	var result: Array = []
	if points.size() < 2:
		return result
	var start_gap := _point_body_distance(points[0])
	var end_gap := _point_body_distance(points[points.size() - 1])
	if minf(start_gap, end_gap) <= radius:
		var ordered := points.duplicate()
		if end_gap < start_gap:
			ordered.reverse()
		result.append(ordered)
		return result
	var closest_index := -1
	var closest_gap := radius
	for index in range(1, points.size() - 1):
		var gap := _point_body_distance(points[index])
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


## Distance from a point to the whole torso, measured against the body polylines
## (true segment distance) rather than only the nearest torso vertex, so a limb that
## lands on a torso edge attaches instead of being dropped as decoration.
func _point_body_distance(point: Vector2) -> float:
	if _body_polylines.is_empty():
		return _point_pool_distance(point, _body_pool)
	var best := INF
	for polyline_value in _body_polylines:
		best = minf(best, _point_polyline_distance(point, polyline_value as PackedVector2Array))
	return best


## Start from the picked body stroke and absorb other body-like strokes: centroid
## inside the current body bounds, either closed or substantially overlapping the body
## bounds, and not limb-shaped (elongation < 2.2 so legs/arms are never swallowed).
func _gather_body_strokes(strokes: Array, body_index: int) -> Dictionary:
	var indices := {body_index: true}
	var pool := PackedVector2Array()
	var polylines: Array = []
	var body_points: PackedVector2Array = strokes[body_index]["points"]
	pool.append_array(body_points)
	polylines.append(body_points)
	var body_bounds := _points_bounds(body_points)
	for index in range(strokes.size()):
		if index == body_index:
			continue
		var pts: PackedVector2Array = strokes[index]["points"]
		if pts.size() < 2:
			continue
		var b := _points_bounds(pts)
		var longside := maxf(b.size.x, b.size.y)
		var shortside := maxf(1.0, minf(b.size.x, b.size.y))
		var elongation := longside / shortside
		var closed := _stroke_is_closed(pts, float(strokes[index].get("width", 5.0)))
		var overlaps := _bounds_overlap_ratio(body_bounds, b) > 0.6
		if body_bounds.has_point(b.get_center()) and (closed or overlaps) and elongation < 2.2:
			indices[index] = true
			pool.append_array(pts)
			polylines.append(pts)
			body_bounds = body_bounds.merge(b)
	return {"indices": indices, "pool": pool, "polylines": polylines}


func _points_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


## Area of the intersection over the smaller of the two boxes (0..1).
func _bounds_overlap_ratio(a: Rect2, b: Rect2) -> float:
	var inter := a.intersection(b)
	var inter_area := inter.size.x * inter.size.y
	var min_area := maxf(1.0, minf(a.size.x * a.size.y, b.size.x * b.size.y))
	return inter_area / min_area


func _role_for_limb(joint: Vector2, tip: Vector2, body_center: Vector2) -> String:
	var delta := tip - joint
	match _rig_type:
		"walker":
			return "leg"
		"biped":
			# Attachment height is more reliable than tip height: a raised foot can
			# end above the torso center, while an arm drawn downward can end below it.
			var hip_line := _body_bounds.position.y + _body_bounds.size.y * 0.56
			return "leg" if joint.y >= hip_line else "arm"
		"hopper":
			# Hoppers (frog/rabbit) treat every attached limb as a driven leg so
			# each one articulates into 2 segments; upward-pointing limbs used to
			# demote to the passive "limb" role and collapse to a single segment.
			return "leg"
		"flier":
			if absf(delta.x) >= absf(delta.y) * 0.7 or delta.y < 0.0:
				return "wing"
			return "leg"
		"swimmer":
			return "tail" if absf(delta.x) > absf(delta.y) else "fin"
		_:
			return "limb"


func _limb_limit_for_entity() -> int:
	match _entity_id:
		"spider": return 8
		"cat", "dog": return 5
		"humanoid", "frog", "rabbit": return 4
		"bird", "butterfly": return 6
		"fish": return 4
		_: return 6


func _minimum_limb_segments(role: String) -> int:
	if role == "leg" and _entity_id in ["spider", "cat", "dog", "humanoid", "frog", "rabbit"]:
		return 2
	if role == "limb" and _entity_id in ["frog", "rabbit"]:
		return 2
	if role == "arm" and _entity_id == "humanoid":
		return 2
	return 1


func _body_local_anchor(body: ActiveRigBody2D, rig_point: Vector2) -> Vector2:
	return body.to_local(_physics_root.to_global(rig_point))


func _segment_joint_error(segment: Dictionary) -> float:
	var parent := segment.get("parent") as ActiveRigBody2D
	var child := segment.get("body") as ActiveRigBody2D
	if not is_instance_valid(parent) or not is_instance_valid(child):
		return INF
	var parent_anchor := Vector2(segment.get("parent_anchor", Vector2.ZERO))
	var child_anchor := Vector2(segment.get("child_anchor", Vector2.ZERO))
	var parent_point := parent.to_global(parent_anchor)
	var child_point := child.to_global(child_anchor)
	if not _vector_is_finite(parent_point) or not _vector_is_finite(child_point):
		return INF
	return parent_point.distance_to(child_point)


func _capture_rest_pose() -> void:
	_rest_transforms.clear()
	if _primary_body == null:
		return
	var primary_inverse := _primary_body.global_transform.affine_inverse()
	for body in _bodies:
		if is_instance_valid(body):
			_rest_transforms[body.get_instance_id()] = primary_inverse * body.global_transform


func _rig_needs_recovery() -> bool:
	if _primary_body == null:
		return false
	var primary_position := _primary_body.global_position
	if not is_finite(primary_position.x) or not is_finite(primary_position.y):
		return true
	if not _world_bounds.grow(RECOVERY_PADDING).has_point(primary_position):
		return true
	var maximum_radius := maxf(120.0, get_stroke_bounds().size.length() * 2.2)
	for body in _bodies:
		if not is_instance_valid(body):
			continue
		if not _transform_is_finite(body.global_transform):
			return true
		var position := body.global_position
		if position.distance_to(primary_position) > maximum_radius:
			return true
	for segment_value in _segments:
		var error := _segment_joint_error(segment_value as Dictionary)
		if not is_finite(error) or error > MAX_JOINT_ERROR:
			return true
	return false


func _recover_rig() -> void:
	if _primary_body == null:
		return
	_recovery_count += 1
	var bounds_end := _world_bounds.end
	var current := _primary_body.global_position
	if not is_finite(current.x) or not is_finite(current.y):
		current = _world_bounds.get_center()
	var safe_position := Vector2(
		clampf(current.x, _world_bounds.position.x + 42.0, bounds_end.x - 42.0),
		clampf(current.y, _world_bounds.position.y + 42.0, bounds_end.y - 42.0)
	)
	var safe_rotation := _primary_body.global_rotation
	if not is_finite(safe_rotation):
		safe_rotation = 0.0
	var primary_transform := Transform2D(safe_rotation, safe_position)
	# Freeze the complete graph first so the constraint solver never observes a
	# half-restored chain. Releasing bodies one-by-one was able to immediately
	# re-contaminate repaired transforms through a still-invalid joint partner.
	for body in _bodies:
		if not is_instance_valid(body):
			continue
		body.freeze = true
	for body in _bodies:
		if not is_instance_valid(body):
			continue
		var relative: Transform2D = _rest_transforms.get(body.get_instance_id(), Transform2D.IDENTITY)
		body.global_transform = primary_transform * relative
		body.linear_velocity = Vector2.ZERO
		body.angular_velocity = 0.0
	for body in _bodies:
		if not is_instance_valid(body):
			continue
		body.freeze = false
		body.sleeping = false
	_physics_frames_since_build = 0


func _vector_is_finite(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


func _transform_is_finite(value: Transform2D) -> bool:
	return _vector_is_finite(value.x) and _vector_is_finite(value.y) and _vector_is_finite(value.origin)


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


func _bounds_for_points(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


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
