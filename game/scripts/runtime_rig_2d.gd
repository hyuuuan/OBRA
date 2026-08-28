class_name RuntimeRig2D
extends "res://scripts/drawing_skin_2d.gd"
## Converts normalized drawing strokes into a bounded active-ragdoll graph.
## Every visible articulated section is parented to the RigidBody2D that owns
## its collision, so vector ink and physics can never drift apart.

signal rig_built(success: bool)

const SpiderRigAnalyzer = preload("res://scripts/spider_rig_analyzer.gd")
const UNDERWATER_SHADER := preload("res://shaders/underwater_character.gdshader")
const MAX_BODIES := 24
const MAX_JOINTS := 23
const MAX_SHAPES := 64
const MAX_SEGMENTS_PER_LIMB := 3
const MIN_SEGMENT_LENGTH := 8.0
const MAX_JOINT_ERROR := 22.0
const RECOVERY_PADDING := 180.0
# Largest angle any gait asks a joint for. Used to scale the hold damping down
# while a limb is actively swinging, so the stabiliser never fights the gait.
const MAX_GAIT_TARGET := deg_to_rad(48.0)
# Frames spent easing the muscles in after a build. A rig starts exactly in its
# drawn pose; applying full torque on frame one is what made limbs whip around at
# the angular-velocity cap for the first second of a creature's life.
const MUSCLE_SETTLE_FRAMES := 14.0
# Ceiling on limb spin. A gait swings a limb at roughly amplitude * gait rate
# (~3 rad/s), so this leaves headroom for impacts while making the sustained
# high-speed thrash that reads on screen as "spinning" impossible. The torso keeps
# the higher default so jumps and knockback still read.
const LIMB_MAX_ANGULAR_SPEED := 5.5
## How quickly drawn ink follows its gait target (higher == snappier limbs).
# --- Pose leash --------------------------------------------------------------
# The muscles control joint ANGLES only, which is not enough to keep a drawing
# looking like itself: a broad appendage pinned at its edge sweeps a long way when
# it rotates, so over time the pieces migrate and a butterfly drawn as four loops
# around a body ends up an asymmetric cluster. The leash pulls every piece back
# toward the offset it was DRAWN at, relative to the torso. It is slack inside a
# deadzone so ordinary gait travel is untouched, and only pulls once a piece has
# wandered far enough to break the silhouette.
const POSE_LEASH_SLACK_RATIO := 0.12
const POSE_LEASH_MIN_SLACK := 12.0
const POSE_LEASH_STIFFNESS := 55.0
const POSE_LEASH_DAMPING := 8.0
# --- Fidelity guarantee ------------------------------------------------------
# Whether a drawing survives being articulated cannot be predicted from its
# strokes: it depends on how the physics happens to resolve, so any rule based on
# stroke shape is guessing. Instead the rig is MEASURED against the pose it was
# drawn in, and if it strays this far for this long it stops being a ragdoll and
# locks into the drawn pose, animating as a whole body from then on. Ordinary
# gaits stay far below the bound (walkers reach ~30 degrees, fliers ~14), so only
# a rig that is genuinely coming apart trips it: a limb more than a right angle
# past where it was drawn is not animating any more, it has fallen off the pose.
## The spider keeps its shape through a tighter drawn envelope rather than the
## pose lock, because its legs are what move it.
const SPIDER_LEG_LIMIT := deg_to_rad(78.0)
# Extra resampled points rendered past each limb chunk boundary so the ink stays
# continuous across a joint even while the PD muscle lets the bodies drift a little.
const LIMB_JOINT_OVERLAP_POINTS := 2
# Every rendered polyline must stay within this distance of the drawn strokes and
# the total rendered length within this tolerance of the drawn length, or the rig
# is rebuilt as one intact compound body.
const INK_AUDIT_EPSILON := 2.0
const INK_AUDIT_LENGTH_TOLERANCE := 0.08
# Visual-only stroke presentation: the physics width (masses, capsule radii,
# analyzer weld radius) keeps the skin's stored width; only the Line2D is floored
# and haloed so thin downscaled ink stays legible over the level art.
const INK_MIN_DRAW_WIDTH := 3.5
const INK_HALO_EXTRA_WIDTH := 3.0
const INK_HALO_LIGHT := Color(1.0, 1.0, 1.0, 0.78)
const INK_HALO_DARK := Color(0.08, 0.08, 0.08, 0.62)
# Above WaterAreas (3) and Decor (5), below ForegroundLayer (30).
const INK_Z_INDEX := 10

var _rig_type: String = "none"
var _entity_id: String = ""
var _motion_state: String = "idle"
var _motion_params: Dictionary = {}

var _physics_root: Node2D
var _primary_body: ActiveRigBody2D
## rig_type "none": the graph is welded to the object body instead of simulating.
var _rigid_object_rig: bool = false

# --- skinned ink: the class-driven rig ----------------------------------------
# What the player sees is rendered from a skeleton looked up by the RECOGNISED CLASS
# and deformed by smooth skinning, instead of from anatomy guessed off the strokes.
# One Line2D per drawn stroke, for the life of the creature: a stroke is never split
# between bodies or reparented, so it cannot tear in half or shed part of itself.
# _skin_active is false only where there is no vector ink to skin -- the bitmap
# fallback, which carries its own sprite and is the one thing this does not draw.
var _skin_active: bool = false
var _skin_rig: Skeleton2D_Rig = null
var _skin_binding: SkinBinding = null
var _skin_driver: GaitDriver = null
var _skin_root: Node2D = null
var _skin_lines: Array[Line2D] = []
var _skin_halos: Array[Line2D] = []
## Shared by every stroke so the complete drawing sees one continuous world-space
## waterline and one moving light field, even though its ink is several CanvasItems.
var _underwater_material: ShaderMaterial
var _underwater_strength := 0.0
## The torso's origin in rig space, for cancelling its spin out of a flier's drawing.
var _skin_anchor_local: Vector2 = Vector2.ZERO
## True once the rig has been locked into its drawn pose because it strayed too far.
var _bodies: Array[ActiveRigBody2D] = []
var _joints: Array[PinJoint2D] = []
var _segments: Array = []
var _body_pool: PackedVector2Array = PackedVector2Array()
var _body_bounds: Rect2 = Rect2()
var _body_polylines: Array = []
## Which slice of the drawn ink each physics body was built from. Bookkeeping for
## the decomposition audit only -- nothing renders from it.
var _body_ink: Array[Dictionary] = []
var _max_tracked_angle: float = 0.0
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

# Spider-only semantic and stance state. Other entities continue through the
# legacy active-ragdoll path above/below; keeping the state separate prevents a
# second controller from silently fighting the spider stance solver.
var _spider_anatomy: Dictionary = {}
var _spider_feet: Array[Dictionary] = []
var _spider_support_height: float = 0.0
var _spider_support_active: bool = false
var _spider_stance_group: int = 0
var _spider_gait_phase: float = 0.0
var _spider_total_mass: float = 0.0
var _spider_floor_y: float = 0.0
var _spider_floor_normal: Vector2 = Vector2.UP
var _spider_force_release_frames: int = 0
var _spider_leg_drive_force: Vector2 = Vector2.ZERO


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


func get_contact_summary() -> Dictionary:
	if _entity_id != "spider" or _spider_feet.is_empty():
		return {
			"grounded": _primary_body != null and _primary_body.grounded,
			"wall_contact": _primary_body != null and _primary_body.wall_contact,
			"ceiling_contact": _primary_body != null and _primary_body.ceiling_contact,
			"support_active": false,
			"torso_contact": _primary_body != null and _primary_body.grounded,
			"dominant_surface_normal": _primary_body.dominant_surface_normal if _primary_body != null else Vector2.UP,
			"leg_drive_force": Vector2.ZERO,
			"feet": []
		}
	_update_spider_contact_cache()
	var feet_report: Array[Dictionary] = []
	var grounded := false
	var wall_contact := false
	var ceiling_contact := false
	var dominant_normal := Vector2.UP
	var floor_normal := Vector2.UP
	var wall_normal := Vector2.ZERO
	var ceiling_normal := Vector2.DOWN
	var best_floor_score := -INF
	var best_wall_score := -INF
	var best_ceiling_score := -INF
	for foot_value in _spider_feet:
		var foot: Dictionary = foot_value
		var body := foot.get("body") as ActiveRigBody2D
		if not is_instance_valid(body):
			continue
		var contacted := bool(foot.get("contact", false))
		grounded = grounded or contacted
		wall_contact = wall_contact or body.wall_contact
		ceiling_contact = ceiling_contact or body.ceiling_contact
		var normal := body.floor_surface_normal if contacted else body.dominant_surface_normal
		if contacted:
			var floor_score := body.floor_surface_normal.dot(Vector2.UP)
			if floor_score > best_floor_score:
				best_floor_score = floor_score
				floor_normal = body.floor_surface_normal
		if body.wall_contact:
			var wall_score := absf(body.wall_surface_normal.x)
			if wall_score > best_wall_score:
				best_wall_score = wall_score
				wall_normal = body.wall_surface_normal
		if body.ceiling_contact:
			var ceiling_score := body.ceiling_surface_normal.dot(Vector2.DOWN)
			if ceiling_score > best_ceiling_score:
				best_ceiling_score = ceiling_score
				ceiling_normal = body.ceiling_surface_normal
		feet_report.append({
			"leg_index": int(foot.get("leg_index", -1)),
			"side": float(foot.get("side", 0.0)),
			"side_rank": int(foot.get("side_rank", -1)),
			"phase_group": int(foot.get("phase_group", 0)),
			"support_candidate": bool(foot.get("support_candidate", false)),
			"stance": bool(foot.get("stance", false)),
			"contact": contacted,
			"position": _spider_sole_global(foot),
			"plant_target": Vector2(foot.get("plant_target", _spider_sole_global(foot))),
			"gait_target": Vector2(foot.get("last_target", _spider_sole_global(foot))),
			"normal": normal,
			"target_angle": _spider_foot_target_angle(foot),
			"drive_reaction": Vector2(foot.get("drive_reaction", Vector2.ZERO))
		})
	for rig_body in _bodies:
		if not is_instance_valid(rig_body):
			continue
		wall_contact = wall_contact or rig_body.wall_contact
		ceiling_contact = ceiling_contact or rig_body.ceiling_contact
		if rig_body.wall_contact:
			var wall_score := absf(rig_body.wall_surface_normal.x)
			if wall_score > best_wall_score:
				best_wall_score = wall_score
				wall_normal = rig_body.wall_surface_normal
		if rig_body.ceiling_contact:
			var ceiling_score := rig_body.ceiling_surface_normal.dot(Vector2.DOWN)
			if ceiling_score > best_ceiling_score:
				best_ceiling_score = ceiling_score
				ceiling_normal = rig_body.ceiling_surface_normal
	if wall_contact and wall_normal.length_squared() > 0.01:
		dominant_normal = wall_normal.normalized()
	elif ceiling_contact and ceiling_normal.length_squared() > 0.01:
		dominant_normal = ceiling_normal.normalized()
	elif grounded:
		dominant_normal = floor_normal.normalized()
	return {
		"grounded": grounded,
		"wall_contact": wall_contact,
		"ceiling_contact": ceiling_contact,
		"support_active": _spider_support_active,
		"torso_contact": _primary_body != null and _primary_body.grounded,
		"dominant_surface_normal": dominant_normal,
		"leg_drive_force": _spider_leg_drive_force,
		"feet": feet_report
	}
func release_stance() -> void:
	_spider_support_active = false
	_spider_force_release_frames = 8
	for foot_value in _spider_feet:
		var foot: Dictionary = foot_value
		foot["stance"] = false
		_set_spider_foot_friction(foot, false)
	if _primary_body != null:
		_primary_body.standing_hint = false


func apply_spider_torso_acceleration(acceleration: Vector2) -> void:
	if _entity_id != "spider" or not is_instance_valid(_primary_body):
		return
	var total_mass := maxf(_spider_total_mass, _primary_body.mass)
	_primary_body.apply_central_force(acceleration * total_mass)


func apply_spider_surface_attitude(surface_normal: Vector2) -> void:
	if _entity_id != "spider" or not is_instance_valid(_primary_body) \
	or surface_normal.length_squared() <= 0.01:
		return
	var tangent := Vector2(-surface_normal.y, surface_normal.x).normalized()
	var target_a := tangent.angle()
	var target_b := (-tangent).angle()
	var error_a := wrapf(target_a - _primary_body.global_rotation, -PI, PI)
	var error_b := wrapf(target_b - _primary_body.global_rotation, -PI, PI)
	var attitude_error := error_a if absf(error_a) <= absf(error_b) else error_b
	var spring := float(profile.get("climb_attitude_spring", 18000.0))
	var damping := float(profile.get("climb_attitude_damping", 4500.0))
	var torque_limit := float(profile.get("climb_attitude_torque_limit", 65000.0))
	var torque := clampf(
		attitude_error * spring - _primary_body.angular_velocity * damping,
		-torque_limit,
		torque_limit
	)
	_primary_body.apply_torque(torque)


func debug_spider_snapshot() -> Dictionary:
	var contact := get_contact_summary()
	var safe_anatomy := _spider_anatomy.duplicate(true)
	# Runtime objects are deliberately not part of the test/debug contract.
	var legs_report: Array[Dictionary] = []
	for leg_value in safe_anatomy.get("legs", []):
		var leg: Dictionary = leg_value
		legs_report.append({
			"root": Vector2(leg.get("root", Vector2.ZERO)),
			"sole": Vector2(leg.get("sole", Vector2.ZERO)),
			"side": float(leg.get("side", 0.0)),
			"side_rank": int(leg.get("side_rank", -1)),
			"phase_group": int(leg.get("phase_group", 0)),
			"support_candidate": bool(leg.get("support_candidate", false)),
			"bend_index": int(leg.get("bend_index", -1)),
			"path": PackedVector2Array(leg.get("path", PackedVector2Array()))
		})
	var clearance := 0.0
	if _primary_body != null and is_finite(_spider_floor_y):
		clearance = _spider_floor_y - _primary_body.global_position.y
	var gait_targets: Array[Vector2] = []
	for foot_value in contact.get("feet", []):
		if foot_value is Dictionary:
			gait_targets.append(Vector2((foot_value as Dictionary).get("gait_target", Vector2.ZERO)))
	return {
		"valid": bool(_spider_anatomy.get("valid", false)),
		"reason": String(_spider_anatomy.get("reason", "not-spider")),
		"torso_center": Vector2(_spider_anatomy.get("torso_center", Vector2.ZERO)),
		"torso_bounds": Rect2(_spider_anatomy.get("torso_bounds", Rect2())),
		"support_height": _spider_support_height,
		"torso_clearance": clearance,
		"support_active": _spider_support_active,
		"stance_group": _spider_stance_group,
		"gait_phase": _spider_gait_phase,
		"gait_targets": gait_targets,
		"torso_contact": bool(contact.get("torso_contact", false)),
		"leg_drive_force": _spider_leg_drive_force,
		"leg_count": legs_report.size(),
		"legs": legs_report,
		"feet": contact.get("feet", [])
	}


func debug_segment_roles() -> Array[String]:
	var roles: Array[String] = []
	for value in _segments:
		roles.append(String((value as Dictionary).get("role", "")))
	return roles


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


## Every polyline the rig renders, in rig space, at rest. One entry per DRAWN STROKE:
## the skinned layer never divides a stroke, so the overlap padding that used to
## account for slices meeting across a joint is always zero now. Tests assert these
## against the player's strokes.
func debug_rendered_ink() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _skin_binding == null:
		return out
	var strokes := get_vector_strokes()
	for index in range(_skin_binding.stroke_count()):
		var stroke: Dictionary = strokes[index] if index < strokes.size() else {}
		out.append({
			"points": _skin_binding.rest_points(index),
			"width": float(stroke.get("width", 8.0)),
			"color": stroke.get("color", Color.BLACK),
			"overlap_prefix": 0,
			"overlap_suffix": 0
		})
	return out


## True when the drawing is rendered from the recognised class's skeleton.
func debug_skin_active() -> bool:
	return _skin_active


## What is on screen right now, in rig space: one entry per drawn stroke, deformed by
## the current pose. This is the only honest thing to measure a creature's animation
## against -- a pivot node can turn while the ink it holds sits still.
func debug_skin_points() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for line in _skin_lines:
		if is_instance_valid(line):
			out.append(line.points)
	return out


## Where the skinned ink sits in the world. debug_skin_points is in this space, so the
## two together say where on screen the drawing actually is.
func debug_skin_transform() -> Transform2D:
	if _skin_root == null or not is_instance_valid(_skin_root):
		return Transform2D.IDENTITY
	return _skin_root.global_transform


## Share of the drawing each bone carries, by bone name. A bone that owns almost no
## ink can swing as hard as it likes and the player sees nothing move.
func debug_bone_ink_mass() -> Dictionary:
	var out: Dictionary = {}
	if _skin_binding == null or _skin_rig == null:
		return out
	var mass := _skin_binding.bone_ink_mass()
	for index in range(_skin_rig.bones.size()):
		if index < mass.size():
			out[_skin_rig.bones[index].name] = mass[index]
	return out


func debug_max_tracked_angle() -> float:
	return _max_tracked_angle


func is_in_water() -> bool:
	return _primary_body != null and int(_primary_body.get_meta("water_overlap_count", 0)) > 0


func set_underwater_appearance(
	active: bool,
	surface_y: float,
	bottom_y: float,
	shallow: Color,
	deep: Color,
	highlight: Color
) -> void:
	_ensure_underwater_material()
	_underwater_strength = 1.0 if active else 0.0
	_underwater_material.set_shader_parameter(&"effect_strength", _underwater_strength)
	_underwater_material.set_shader_parameter(&"surface_y", surface_y)
	_underwater_material.set_shader_parameter(&"bottom_y", bottom_y)
	_underwater_material.set_shader_parameter(&"shallow_water", shallow)
	_underwater_material.set_shader_parameter(&"deep_water", deep)
	_underwater_material.set_shader_parameter(&"caustic_light", highlight)
	_apply_underwater_material()


func _ensure_underwater_material() -> void:
	if _underwater_material != null:
		return
	_underwater_material = ShaderMaterial.new()
	_underwater_material.shader = UNDERWATER_SHADER


func _apply_underwater_material() -> void:
	if _underwater_material == null:
		return
	if _body != null:
		_body.material = _underwater_material
	for line in _skin_halos:
		if is_instance_valid(line):
			line.material = _underwater_material
	for line in _skin_lines:
		if is_instance_valid(line):
			line.material = _underwater_material


func debug_underwater_strength() -> float:
	return _underwater_strength


func rig_summary() -> String:
	if _primary_body == null:
		return "%s/no-body" % skin_mode()
	return "%s/%d bodies/%d joints" % [skin_mode(), _bodies.size(), _joints.size()]


func _on_skin_rebuilt() -> void:
	_build_generation += 1
	_clear_rig()
	if skin_mode() == "vector" and not get_vector_strokes().is_empty():
		if _entity_id == "spider":
			_build_spider_rig(get_vector_strokes())
		else:
			if _entity_id == "snake":
				_build_chain_rig(get_vector_strokes())
			else:
				_build_standard_rig(get_vector_strokes())
			# Decomposition gate: if a builder cut bodies out of geometry the player did
			# not draw, or lost some of it, degrade to one intact compound body. It no
			# longer guards what is DRAWN -- the skinned layer draws the player's own
			# strokes whatever the physics does -- but a body built from a fabricated
			# chord still carries a collider the drawing cannot account for. The spider
			# branch is exempt: its analyzer only emits exact ink slices and self-falls-back.
			if not _rig_ink_is_intact():
				push_warning("RuntimeRig2D: %s rig diverged from the drawn ink; rebuilding as compound body." % _entity_id)
				_clear_rig()
				_build_compound_rig(
					get_vector_strokes(),
					"CompoundBody",
					_rig_type in ["walker", "biped", "hopper"]
				)
	else:
		_build_bitmap_fallback()
	# Every rig, every class: the drawing is rendered from the pose it was drawn in
	# while the physics underneath keeps its full freedom to walk, jump and collide.
	# A bitmap-fallback drawing has no strokes to skin, and renders as its own sprite
	# carried by the body -- there is nothing else left that draws a creature.
	_bind_skinned_ink()
	_finalize_rig()
	if _rig_type == "none":
		_pin_rig_to_owner()
	analysis["physics_bodies"] = _bodies.size()
	analysis["physics_joints"] = _joints.size()
	analysis["active_ragdoll"] = _joints.size() > 0 and not _rigid_object_rig
	rig_built.emit(_primary_body != null)


func _physics_process(delta: float) -> void:
	if _primary_body == null:
		return
	_physics_frames_since_build += 1
	if _rigid_object_rig:
		# Pinned to its owner: nothing simulates, so there is no drift to recover from
		# and no gait to run. The ink still updates so a utility that changes pose
		# (an umbrella opening) redraws.
		_animate_skinned_ink(delta)
		return
	if _physics_frames_since_build > 4 and _rig_needs_recovery():
		_recover_rig()
		return
	# The drawing is rendered from its drawn pose, so the creature animates while the
	# rig below simulates freely. Runs for every class, articulated or not.
	_animate_skinned_ink(delta)
	if _segments.is_empty():
		return
	if _entity_id == "spider" and not _spider_feet.is_empty():
		_physics_process_spider(delta)
		return
	_update_stand_state(delta)
	# Ease the muscles in over the rig's first few frames, and hold the gait until
	# they are in. A freshly built rig sits exactly in its drawn pose, so driving it
	# at full torque immediately is what kicked the limbs into their opening thrash.
	var settle := clampf(float(_physics_frames_since_build) / MUSCLE_SETTLE_FRAMES, 0.0, 1.0)
	var speed_ratio := clampf(float(_motion_params.get("speed_ratio", 0.0)), 0.0, 1.5)
	if settle >= 1.0 and (bool(_motion_params.get("moving", false)) \
			or _motion_state in ["swim", "fly", "flap", "climb"]):
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
		# Track the CONTINUOUS relative angle instead of a wrapped one. With the
		# wrapped error a limb knocked past 180deg was pulled the short way onward
		# around, so limbs windmilled in full circles instead of holding the gait
		# pose; the unwrapped error always pulls back the way the limb came.
		var current := _tracked_joint_angle(segment)
		var error := target - current
		var relative_velocity := child.angular_velocity - parent.angular_velocity
		# PinJoint motors do not expose a useful per-joint impulse cap in this
		# setup. Driving the motor and applying PD torque at the same time made
		# light limbs fight two solvers and launch the complete rig. Use one
		# bounded muscle controller instead.
		var mass_scale := clampf(minf(parent.mass, child.mass) / 0.4, 0.45, 1.35)
		var distal_scale := 1.0 / (1.0 + float(int(segment["chain_index"])) * 0.35)
		# A standing creature's own weight presses its feet into the floor, and the
		# ground reaction on a splayed limb is a torque of order 2000 about the hip.
		# The old envelope (spring <= 1500, i.e. ~400 of restoring torque at a 40 deg
		# error) lost that argument outright, so limbs splayed and stayed splayed:
		# the drawing collapsed into a heap and no amount of gait tuning showed,
		# because the pose it was animating around was already gone. This envelope is
		# stiff enough to hold the drawn pose against ground reaction, while staying
		# far below the stiffness at which the pin solver tears its own joints apart.
		var spring := clampf(float(profile.get("joint_spring", 1050.0)) * 0.7 * mass_scale * distal_scale, 2600.0, 4200.0)
		# Damping tracks sqrt(spring) so the stiff pose spring stays near-critically
		# damped instead of ringing itself unstable at 60 Hz.
		var damping := clampf(sqrt(spring) * 6.5 * mass_scale, 45.0, 380.0)
		var torque_limit := clampf(float(profile.get("joint_torque_limit", 2600.0)) * 0.7 * mass_scale * distal_scale, 8000.0, 14000.0)
		var pd := clampf(error * spring - relative_velocity * damping, -torque_limit, torque_limit)
		# Gravity compensation: the muscle PD above is far too weak to hold a limb
		# out against its own weight (a horizontal limb needs ~mass*g*lever, which
		# dwarfs the PD's bounded output), so without this the limbs droop to the
		# floor like dead bones. Add the static torque that holds this joint's whole
		# distal subtree up, leaving the PD free to supply pose/gait tension.
		# While the stand-support carries the creature it cancels gravity, so the
		# compensation is faded out in lockstep to avoid over-rotating a weightless
		# limb (residual effective gravity is (1 - _support_blend) * g).
		# Soft angular limit. Hard PinJoint limits are numerically singular on short
		# light segments, and the bounded PD saturates under impacts, so past the
		# drawn limit a strong unbounded restoring couple takes over. Without it a
		# kicked limb winds up turn after turn.
		var angle_limit := float(segment.get("angle_limit", deg_to_rad(68.0)))
		var excess := 0.0
		if current > angle_limit:
			excess = current - angle_limit
		elif current < -angle_limit:
			excess = current + angle_limit
		var limit_torque := 0.0
		if excess != 0.0:
			# Softer than a wall. At spring*4.0 this term dwarfed the PD and switched
			# hard on/off at the boundary, so a limb resting near its limit buzzed
			# between the two states -- the chatter that read on screen as a
			# vibrating, scattering limb. A gentler restoring couple with more
			# damping brings the limb back without exciting it.
			limit_torque = clampf(
				-excess * spring * 1.6 - relative_velocity * damping * 2.4,
				-torque_limit * 1.5,
				torque_limit * 1.5
			)
		# Gravity compensation rotates with the limb, so past the angular limit it
		# stops being a hold and becomes a propeller that out-muscles the soft limit.
		# It is faded with excess -- but NOT to zero: cutting the hold completely at
		# the boundary latched limbs in a permanent droop (a limb sagged past the
		# limit, lost the only torque holding it up, and could never climb back), which
		# is why limbs settled tens of degrees below the pose the player drew. Keeping
		# a floor of hold keeps the limb recoverable while still letting the limit win.
		var comp_fade := clampf(1.0 - absf(excess) / deg_to_rad(30.0), 0.0, 1.0)
		var gravity_comp := _gravity_hold_torque(segment, joint) \
			* (1.0 - _support_blend) * lerpf(0.55, 1.0, comp_fade)
		# Fade the whole drive in while the rig settles into its drawn pose.
		var muscle := (pd + limit_torque) * settle
		var assist := gravity_comp * settle
		segment["last_drive_torque"] = muscle + assist
		# The PD muscle spans the joint, so it is a couple: equal and opposite on the
		# two bodies. Gravity compensation is an EXTERNAL anti-droop assist on the limb,
		# not a muscle, so it acts on the child only -- reacting it back onto the parent
		# torso is what summed into a net torque and spun multi-limb creatures in place.
		child.apply_torque(muscle + assist)
		parent.apply_torque(-muscle)
		# Light always-on relative drag (a pure dissipative couple) bleeds spin
		# energy the clamped PD cannot absorb, even while a gait target is active.
		var drag := -relative_velocity * 22.0 * mass_scale
		child.apply_torque(drag)
		parent.apply_torque(-drag)
		# gravity_comp is an undamped, position-dependent feed-forward torque that
		# excites a whole-limb swing the joint's relative-velocity PD cannot see, so
		# bleed that swing off the child's ABSOLUTE angular velocity (child only,
		# removing energy instead of redistributing it). This used to be gated on
		# "no gait target", which meant it snapped on and off every time the gait
		# sinusoid crossed zero -- a discontinuity that fed the very chatter it was
		# meant to remove. It is now continuous, and simply eases off while the limb
		# is being actively driven so the gait keeps its swing.
		# Strong while the limb is meant to hold still, easing to almost nothing at
		# full gait so the stabiliser never damps out the animation it is protecting.
		var drive_ratio := clampf(absf(target) / MAX_GAIT_TARGET, 0.0, 1.0)
		var hold_damping: float = lerpf(900.0, 40.0, sqrt(drive_ratio))
		child.apply_torque(-child.angular_velocity * child.mass * hold_damping)
		child.apply_central_force(-child.linear_velocity * child.mass * 6.0)

	_apply_pose_leash(settle)
	_apply_stand_support()


func _physics_process_spider(delta: float) -> void:
	if _primary_body == null:
		return
	_primary_body.standing_hint = false
	_spider_leg_drive_force = Vector2.ZERO
	for foot_value in _spider_feet:
		(foot_value as Dictionary)["drive_reaction"] = Vector2.ZERO
	if _spider_force_release_frames > 0:
		_spider_force_release_frames -= 1
	_update_spider_contact_cache()
	var grounded_mode := _motion_state in ["idle", "walk"] \
		and _primary_body.gravity_scale > 0.01 and _spider_force_release_frames <= 0
	if grounded_mode:
		_update_spider_gait(delta)
	else:
		_spider_support_active = false
		for foot_value in _spider_feet:
			var foot: Dictionary = foot_value
			foot["stance"] = false
			_set_spider_foot_friction(foot, false)
			var rest_target := _primary_body.global_position + Vector2(foot.get("rest_offset", Vector2.ZERO)).rotated(_primary_body.rotation)
			foot["last_target"] = rest_target
			_set_spider_leg_target(foot, rest_target)
	_apply_spider_joint_muscles()
	# Called whenever the spider is in grounded mode, not only when the gait already
	# believes it is supported. _spider_support_active was both the gate here AND the
	# thing the stance forces compute, so the one frame the gait lost its stance set was
	# the frame the torso stopped being held up -- and a spider on its belly can never
	# satisfy the condition that would switch its own support back on.
	if grounded_mode:
		_apply_spider_stance_forces()


func _update_spider_contact_cache() -> void:
	var floor_total := 0.0
	var floor_count := 0
	var normal_total := Vector2.ZERO
	for foot_value in _spider_feet:
		var foot: Dictionary = foot_value
		var body := foot.get("body") as ActiveRigBody2D
		if not is_instance_valid(body):
			foot["contact"] = false
			continue
		# Only a terminal leg body can contribute floor support. The primary torso's
		# grounded flag is exposed separately and never promoted into foot contact.
		var contacted := body.grounded
		foot["contact"] = contacted
		if contacted:
			var sole := _spider_sole_global(foot)
			floor_total += sole.y
			floor_count += 1
			normal_total += body.dominant_surface_normal
	if floor_count > 0:
		_spider_floor_y = floor_total / float(floor_count)
		if normal_total.length_squared() > 0.001:
			_spider_floor_normal = normal_total.normalized()


func _update_spider_gait(delta: float) -> void:
	var moving := bool(_motion_params.get("moving", false))
	var direction := clampf(float(_motion_params.get("direction", 0.0)), -1.0, 1.0)
	if absf(direction) <= 0.05:
		moving = false
	var support_contacts_by_group := [0, 0]
	var support_contacts := 0
	for foot_value in _spider_feet:
		var foot: Dictionary = foot_value
		if bool(foot.get("support_candidate", false)) and _spider_foot_reached_ground_target(foot):
			var group := clampi(int(foot.get("phase_group", 0)), 0, 1)
			support_contacts_by_group[group] += 1
			support_contacts += 1

	if not moving:
		_spider_support_active = support_contacts > 0
		for foot_value in _spider_feet:
			var foot: Dictionary = foot_value
			var can_stance := bool(foot.get("support_candidate", false)) and bool(foot.get("contact", false))
			if can_stance and not bool(foot.get("stance", false)):
				foot["plant_target"] = _spider_sole_global(foot)
			foot["stance"] = can_stance
			_set_spider_foot_friction(foot, can_stance)
			var target := Vector2(foot.get("plant_target", _spider_sole_global(foot))) if can_stance \
				else _primary_body.global_position + Vector2(foot.get("rest_offset", Vector2.ZERO)).rotated(_primary_body.rotation)
			foot["last_target"] = target
			_set_spider_leg_target(foot, target)
		return

	var gait_frequency := clampf(float(profile.get("gait_frequency", 2.2)), 0.4, 4.0)
	_spider_gait_phase = fposmod(_spider_gait_phase + delta * gait_frequency * TAU, TAU)
	var desired_swing_group := 0 if _spider_gait_phase < PI else 1
	var desired_stance_group := 1 - desired_swing_group
	# Do not lift the currently supporting group until its counterpart has made
	# real contact. This prevents a sketch with uneven legs from entering a frame
	# where every foot is in swing.
	if support_contacts_by_group[desired_stance_group] > 0:
		_spider_stance_group = desired_stance_group
	elif support_contacts_by_group[_spider_stance_group] <= 0 and support_contacts_by_group[1 - _spider_stance_group] > 0:
		_spider_stance_group = 1 - _spider_stance_group
	var swing_group := 1 - _spider_stance_group
	var half_progress := fposmod(_spider_gait_phase, PI) / PI
	var smooth_progress := half_progress * half_progress * (3.0 - 2.0 * half_progress)
	_spider_support_active = support_contacts_by_group[_spider_stance_group] > 0
	var stride := float(profile.get("stride_length", 42.0))
	var clearance := float(profile.get("swing_clearance", 18.0))
	for foot_value in _spider_feet:
		var foot: Dictionary = foot_value
		var group := clampi(int(foot.get("phase_group", 0)), 0, 1)
		var support_candidate := bool(foot.get("support_candidate", false))
		var should_stance := support_candidate and group == _spider_stance_group and _spider_foot_reached_ground_target(foot)
		if should_stance and not bool(foot.get("stance", false)):
			var plant_target := _spider_sole_global(foot)
			plant_target.y = _spider_floor_y
			foot["plant_target"] = plant_target
		foot["stance"] = should_stance
		_set_spider_foot_friction(foot, should_stance)
		var target: Vector2
		if should_stance:
			target = Vector2(foot.get("plant_target", _spider_sole_global(foot)))
		elif _spider_leg_overstrained(foot):
			# A wound-up leg gets a calm rest-pose target instead of the striding
			# swing arc, so it unwinds instead of being whipped further around.
			target = _primary_body.global_position + Vector2(foot.get("rest_offset", Vector2.ZERO)).rotated(_primary_body.rotation)
		elif group == swing_group or not support_candidate:
			var rest_offset := Vector2(foot.get("rest_offset", Vector2.ZERO)).rotated(_primary_body.rotation)
			target = _primary_body.global_position + rest_offset
			target.x += direction * lerpf(-stride * 0.35, stride * 0.55, smooth_progress)
			target.y = _spider_floor_y - sin(half_progress * PI) * clearance
		else:
			# A stance-group foot can momentarily lose contact after the phase handoff.
			# Drive its drawn sole back to the measured floor instead of returning it
			# to an airborne rest pose; support is enabled only after contact returns.
			target = _primary_body.global_position + Vector2(foot.get("rest_offset", Vector2.ZERO)).rotated(_primary_body.rotation)
			target.y = _spider_floor_y
		foot["last_target"] = target
		_set_spider_leg_target(foot, target)


## A leg wound well past its drawn envelope is on its way over-center; it needs
## a recovery target, not a stride target.
func _spider_leg_overstrained(foot: Dictionary) -> bool:
	for record_value in foot.get("segments", []):
		if absf(float((record_value as Dictionary).get("tracked_angle", 0.0))) > deg_to_rad(140.0):
			return true
	return false


func _spider_foot_reached_ground_target(foot: Dictionary) -> bool:
	if not bool(foot.get("contact", false)):
		return false
	if bool(foot.get("stance", false)):
		return true
	var sole := _spider_sole_global(foot)
	var target := Vector2(foot.get("last_target", sole))
	var plant_distance := clampf(float(profile.get("plant_distance", 14.0)), 4.0, 24.0)
	return sole.distance_to(target) <= plant_distance \
		and absf(sole.y - _spider_floor_y) <= plant_distance


func _set_spider_leg_target(foot: Dictionary, world_target: Vector2) -> void:
	var records: Array = foot.get("segments", [])
	if records.size() < 2 or _primary_body == null:
		return
	var torso_center := Vector2(_spider_anatomy.get("torso_center", Vector2.ZERO))
	var root_rig := Vector2(foot.get("root_rig", torso_center))
	var root_local := root_rig - torso_center
	var root_world := _primary_body.to_global(root_local)
	var target_vector := world_target - root_world
	var length_a := maxf(2.0, float(foot.get("length_a", 2.0)))
	var length_b := maxf(2.0, float(foot.get("length_b", 2.0)))
	var distance := clampf(target_vector.length(), absf(length_a - length_b) + 0.5, length_a + length_b - 0.5)
	if distance <= 0.001:
		return
	var elbow_cos := clampf((distance * distance - length_a * length_a - length_b * length_b) / (2.0 * length_a * length_b), -1.0, 1.0)
	# Cap the commanded fold: a target passing near the leg root asks for a
	# ~180deg elbow, and driving that folds the leg over its own root and flips
	# it a full turn. A spider leg never needs more than a deep crouch.
	var elbow := clampf(acos(elbow_cos), 0.0, deg_to_rad(148.0)) * signf(float(foot.get("bend_sign", 1.0)))
	var shoulder := target_vector.angle() - atan2(length_b * sin(elbow), length_a + length_b * cos(elbow))
	var first: Dictionary = records[0]
	var second: Dictionary = records[1]
	var first_parent := first.get("parent") as ActiveRigBody2D
	var second_parent := second.get("parent") as ActiveRigBody2D
	if not is_instance_valid(first_parent) or not is_instance_valid(second_parent):
		return
	var desired_first_body_rotation := shoulder - float(first.get("rest_axis_angle", 0.0))
	var desired_second_body_rotation := shoulder + elbow - float(second.get("rest_axis_angle", 0.0))
	# Express each target in the winding closest to the muscle's continuous
	# tracked angle. A plain wrapf here could flip the target by a full turn
	# against a leg that had been forced past 180deg, and the muscle then spun it
	# the long way around instead of settling.
	var tracked_first := float(first.get("tracked_angle", 0.0))
	var raw_first := desired_first_body_rotation - first_parent.rotation - float(first.get("rest_relative", 0.0))
	first["target_angle"] = tracked_first + wrapf(raw_first - tracked_first, -PI, PI)
	var tracked_second := float(second.get("tracked_angle", 0.0))
	var raw_second := desired_second_body_rotation - second_parent.rotation - float(second.get("rest_relative", 0.0))
	second["target_angle"] = tracked_second + wrapf(raw_second - tracked_second, -PI, PI)


func _apply_spider_joint_muscles() -> void:
	for segment_value in _segments:
		var segment: Dictionary = segment_value
		var parent := segment.get("parent") as ActiveRigBody2D
		var child := segment.get("body") as ActiveRigBody2D
		var joint := segment.get("joint") as PinJoint2D
		if not is_instance_valid(parent) or not is_instance_valid(child) or not is_instance_valid(joint):
			continue
		var limit := float(segment.get("angle_limit", deg_to_rad(78.0)))
		var target := clampf(float(segment.get("target_angle", 0.0)), -limit, limit)
		# Continuous angle, same reasoning as the generic muscle: a wrapped error
		# let a knocked leg segment wind up full turns instead of coming back.
		var current := _tracked_joint_angle(segment)
		var error := target - current
		var relative_velocity := child.angular_velocity - parent.angular_velocity
		var mass_scale := clampf(minf(parent.mass, child.mass) / 0.24, 0.55, 1.4)
		var distal_scale := 1.0 if int(segment.get("chain_index", 0)) == 0 else 0.78
		var spring := float(profile.get("joint_spring", 1250.0)) * mass_scale * distal_scale
		var damping := float(profile.get("joint_damping", 78.0)) * mass_scale
		var torque_limit := float(profile.get("joint_torque_limit", 3000.0)) * distal_scale
		var torque := clampf(error * spring - relative_velocity * damping, -torque_limit, torque_limit)
		# Soft limit anchored at the drawn envelope. Besides preventing full-turn
		# windup, the restoring couple doubles as tendon-like recoil that returns
		# a deep stance sweep through its power stroke — widening this envelope
		# measurably REDUCED the stance gait's forward travel.
		var excess := 0.0
		if current > limit:
			excess = current - limit
		elif current < -limit:
			excess = current + limit
		var limit_torque := 0.0
		if excess != 0.0:
			limit_torque = clampf(
				-excess * spring * 4.0 - relative_velocity * damping * 2.0,
				-torque_limit * 2.5,
				torque_limit * 2.5
			)
		segment["last_drive_torque"] = torque + limit_torque
		child.apply_torque(torque + limit_torque)
		parent.apply_torque(-torque - limit_torque)
		# Past the soft limit, drag and brake the segment's spin (dissipative
		# only) so a whipped leg sheds the momentum of a would-be full turn.
		if absf(excess) > deg_to_rad(15.0):
			var drag := -relative_velocity * 44.0 * mass_scale
			child.apply_torque(drag)
			parent.apply_torque(-drag)
			child.apply_torque(-child.angular_velocity * child.mass * 520.0)


func _apply_spider_stance_forces() -> void:
	if _primary_body == null:
		return
	var stance_feet: Array[Dictionary] = []
	var contacting_feet: Array[Dictionary] = []
	for foot_value in _spider_feet:
		var foot: Dictionary = foot_value
		if not bool(foot.get("contact", false)):
			continue
		contacting_feet.append(foot)
		if bool(foot.get("stance", false)):
			stance_feet.append(foot)
	# WHAT CARRIES THE SPIDER IS GROUND CONTACT, NOT THE GAIT'S BOOKKEEPING. "stance"
	# additionally requires a foot to be within plant_distance of the target it was
	# last sent to -- and mid-stride the gait has already moved that target on, so a
	# foot flat on the floor routinely reads as not-stance. When both leg groups were
	# between targets at once this returned early, skipped the torso lift entirely, and
	# the spider dropped onto its belly under plain gravity. From there it could not
	# recover: with the abdomen down the legs cannot reach their targets, so no foot
	# ever became stance again, and the walk turned into a 0.4px-per-frame drag.
	var carrying_feet := stance_feet if not stance_feet.is_empty() else contacting_feet
	if carrying_feet.is_empty():
		_spider_support_active = false
		return
	_spider_support_active = true

	var stance_spring := float(profile.get("stance_spring", 850.0))
	var stance_damping := float(profile.get("stance_damping", 70.0))
	var stance_limit := float(profile.get("stance_force_limit", 2200.0))
	for foot in stance_feet:
		var body := foot.get("body") as ActiveRigBody2D
		if not is_instance_valid(body):
			continue
		var error := Vector2(foot.get("plant_target", _spider_sole_global(foot))) - _spider_sole_global(foot)
		var force := (error * stance_spring - body.linear_velocity * stance_damping) * body.mass
		force = force.limit_length(stance_limit * body.mass)
		body.apply_central_force(force)

	var desired_y := _spider_floor_y - _spider_support_height
	var height_error := _primary_body.global_position.y - desired_y
	var support_spring := float(profile.get("support_spring", 65.0))
	var support_damping := float(profile.get("support_damping", 30.0))
	var support_limit := float(profile.get("support_force", 2250.0))
	var support_accel := clampf(_gravity + height_error * support_spring + _primary_body.linear_velocity.y * support_damping, 0.0, support_limit)
	var total_mass := maxf(_spider_total_mass, _primary_body.mass)
	var upward_force := total_mass * support_accel
	# The hidden stance actuator is an equal-and-opposite pair: the torso receives
	# the bounded lift and physically contacted feet receive the complete downward
	# reaction, divided across the current stance set. Ground reaction, not a net
	# levitation force, is what then carries the rig's weight.
	var reaction_weights := _spider_reaction_weights(carrying_feet)
	_primary_body.apply_central_force(Vector2(0.0, -upward_force))
	for foot_index in range(carrying_feet.size()):
		var foot := carrying_feet[foot_index]
		var body := foot.get("body") as ActiveRigBody2D
		if is_instance_valid(body):
			var reaction_force := upward_force * float(reaction_weights[foot_index])
			body.apply_central_force(Vector2(0.0, reaction_force))

	var attitude_spring := float(profile.get("attitude_spring", 2600.0))
	var attitude_damping := float(profile.get("attitude_damping", 300.0))
	var attitude_limit := float(profile.get("attitude_torque_limit", 5200.0))
	var attitude_torque := clampf(
		-_primary_body.rotation * attitude_spring
		- _primary_body.angular_velocity * attitude_damping,
		-attitude_limit,
		attitude_limit
	)
	_primary_body.apply_torque(attitude_torque)

	var direction := clampf(float(_motion_params.get("direction", 0.0)), -1.0, 1.0)
	var target_speed := direction * float(profile.get("move_speed", 180.0))
	var move_acceleration := float(profile.get("leg_drive_acceleration", 1350.0))
	var drive_gain := float(profile.get("leg_drive_velocity_gain", 8.5))
	var drive_accel := clampf((target_speed - _primary_body.linear_velocity.x) * drive_gain, -move_acceleration, move_acceleration)
	var drive_force := Vector2(drive_accel * total_mass, 0.0)
	# Horizontal drive is an internal leg-muscle pair, never a free force on the
	# torso. The torso-side force is matched by an opposite push through the
	# contacting stance feet. Only the ground reaction at those feet can propel
	# the rig; if contact disappears, this entire controller stops running.
	# WEIGHT AND PROPULSION REST ON DIFFERENT FEET. Anything touching the ground helps
	# hold the body up, but only a PLANTED foot has anything to push against -- driving
	# through one that is still swinging is pushing on a foot that would simply slide.
	# So the drive uses the stance set and its own weights, and on a frame with no
	# planted feet there is no drive at all, rather than a free force on the torso.
	if stance_feet.is_empty():
		_spider_leg_drive_force = Vector2.ZERO
		return
	var drive_weights := _spider_reaction_weights(stance_feet)
	_spider_leg_drive_force = drive_force
	_primary_body.apply_central_force(drive_force)
	for foot_index in range(stance_feet.size()):
		var foot := stance_feet[foot_index]
		var body := foot.get("body") as ActiveRigBody2D
		if is_instance_valid(body):
			var drive_reaction := -drive_force * float(drive_weights[foot_index])
			foot["drive_reaction"] = drive_reaction
			body.apply_central_force(drive_reaction)


func _spider_reaction_weights(stance_feet: Array[Dictionary]) -> PackedFloat32Array:
	var count := stance_feet.size()
	var weights := PackedFloat32Array()
	weights.resize(count)
	if count <= 0:
		return weights
	var equal_weight := 1.0 / float(count)
	var mean_x := 0.0
	var foot_x := PackedFloat32Array()
	foot_x.resize(count)
	var minimum_x := INF
	var maximum_x := -INF
	var has_left := false
	var has_right := false
	for index in range(count):
		foot_x[index] = _spider_sole_global(stance_feet[index]).x
		mean_x += foot_x[index]
		minimum_x = minf(minimum_x, foot_x[index])
		maximum_x = maxf(maximum_x, foot_x[index])
		has_left = has_left or float(stance_feet[index].get("side", 0.0)) < 0.0
		has_right = has_right or float(stance_feet[index].get("side", 0.0)) > 0.0
	mean_x /= float(count)
	# Moment balancing is safe only for a real cross-side support polygon. When a
	# gait transition briefly leaves one side in contact, keep an even reaction
	# instead of concentrating the complete load into its outermost foot.
	if not has_left or not has_right \
	or _primary_body.global_position.x <= minimum_x or _primary_body.global_position.x >= maximum_x:
		for index in range(count):
			weights[index] = equal_weight
		return weights
	var spread := 0.0
	for index in range(count):
		spread += pow(foot_x[index] - mean_x, 2.0)
	var adjustment := 0.0
	if count >= 2 and spread > 1.0:
		adjustment = (_primary_body.global_position.x - mean_x) / spread
	var total := 0.0
	for index in range(count):
		weights[index] = maxf(0.0, equal_weight + adjustment * (foot_x[index] - mean_x))
		total += weights[index]
	if total <= 0.001:
		for index in range(count):
			weights[index] = equal_weight
	else:
		for index in range(count):
			weights[index] /= total
	return weights


func _spider_sole_global(foot: Dictionary) -> Vector2:
	var body := foot.get("body") as ActiveRigBody2D
	if not is_instance_valid(body):
		return Vector2.ZERO
	return body.to_global(Vector2(foot.get("sole_local", Vector2.ZERO)))


func _spider_foot_target_angle(foot: Dictionary) -> float:
	var records: Array = foot.get("segments", [])
	if records.is_empty():
		return 0.0
	return float((records[0] as Dictionary).get("target_angle", 0.0))


func _set_spider_foot_friction(foot: Dictionary, stance: bool) -> void:
	var body := foot.get("body") as ActiveRigBody2D
	if not is_instance_valid(body):
		return
	var material := body.physics_material_override
	if material == null:
		material = PhysicsMaterial.new()
		body.physics_material_override = material
	material.friction = clampf(
		float(profile.get("stance_friction", 1.25)) if stance else float(profile.get("swing_friction", 0.08)),
		0.02,
		4.0
	)
	material.rough = stance
	material.bounce = 0.0


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
## Holds the drawing's LAYOUT, not just its joint angles. Each piece is pulled back
## toward where it was drawn relative to the torso, but only once it has strayed
## past a slack radius, so gait travel is unaffected and only genuine drift — the
## slow migration that turns a drawing into an unrecognisable cluster — is pulled in.
func _apply_pose_leash(settle: float) -> void:
	if _primary_body == null or _rest_transforms.is_empty():
		return
	var slack := maxf(POSE_LEASH_MIN_SLACK, get_stroke_bounds().size.length() * POSE_LEASH_SLACK_RATIO)
	var primary_transform := _primary_body.global_transform
	for body in _bodies:
		if body == _primary_body or not is_instance_valid(body):
			continue
		var rest: Variant = _rest_transforms.get(body.get_instance_id())
		if rest == null:
			continue
		var desired: Vector2 = primary_transform * (rest as Transform2D).origin
		var offset := desired - body.global_position
		var distance := offset.length()
		if distance <= slack or not is_finite(distance):
			continue
		# Only the excess past the slack radius is corrected.
		var pull := offset.normalized() * (distance - slack)
		var relative_velocity := body.linear_velocity - _primary_body.linear_velocity
		var force := (pull * POSE_LEASH_STIFFNESS - relative_velocity * POSE_LEASH_DAMPING) * body.mass
		body.apply_central_force(force * settle)


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
## Integrate the continuous (unwrapped) joint angle relative to the drawn rest
## pose. wrapf on the raw measurement loses full turns; integrating the minimal
## per-tick step keeps them, so the muscles can pull a wound-up limb back the way
## it came and the soft limit knows how far the limb really strayed.
func _tracked_joint_angle(segment: Dictionary) -> float:
	var parent := segment["parent"] as ActiveRigBody2D
	var child := segment["body"] as ActiveRigBody2D
	var measured := wrapf(child.rotation - parent.rotation - float(segment["rest_relative"]), -PI, PI)
	var tracked := float(segment.get("tracked_angle", 0.0))
	tracked += wrapf(measured - wrapf(tracked, -PI, PI), -PI, PI)
	segment["tracked_angle"] = tracked
	_max_tracked_angle = maxf(_max_tracked_angle, absf(tracked))
	return tracked


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
				# Kept inside the wing's angle envelope: a beat commanded wider than
				# the joint allows just pins the wing against its limit every cycle.
				# A broad loop-shaped wing swings its far side a long way for very
				# little rotation, so a wide beat visibly walks it off the body. Small
				# enough to stay attached, large enough to read as a flap.
				return deg_to_rad(24.0) * sin(phase * hz_scale) * side
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


func _build_spider_rig(strokes: Array) -> void:
	_spider_anatomy = SpiderRigAnalyzer.analyze(strokes)
	if not bool(_spider_anatomy.get("valid", false)):
		_build_spider_compound(strokes)
		return

	_create_physics_root()
	var torso_paths: Array = _spider_anatomy.get("torso_paths", [])
	var decoration_paths: Array = _spider_anatomy.get("decoration_paths", [])
	var torso_owners: Array = _spider_anatomy.get("torso_path_owners", [])
	var decoration_owners: Array = _spider_anatomy.get("decoration_path_owners", [])
	var torso_center := Vector2(_spider_anatomy.get("torso_center", get_stroke_bounds().get_center()))
	_body_bounds = Rect2(_spider_anatomy.get("torso_bounds", get_stroke_bounds()))
	_body_pool = PackedVector2Array()
	_body_polylines = []
	for path_value in torso_paths:
		var path := PackedVector2Array(path_value)
		if path.size() < 2:
			continue
		_body_pool.append_array(path)
		_body_polylines.append(path)
	for path_value in decoration_paths:
		var path := PackedVector2Array(path_value)
		if path.size() >= 2:
			_body_pool.append_array(path)
	if _body_pool.is_empty():
		_build_spider_compound(strokes)
		return

	var legs: Array = _spider_anatomy.get("legs", [])
	# Mass starts with every real core/decor ink interval assigned to the compound
	# torso. After the legs are built below, a structural floor guarantees the
	# torso still carries at least forty percent of the complete articulated rig.
	var torso_mass := clampf(
		_spider_path_mass(torso_paths, torso_owners, strokes)
		+ _spider_path_mass(decoration_paths, decoration_owners, strokes),
		0.8,
		8.0
	)
	_primary_body = _create_body("Torso", torso_center, torso_mass)
	_primary_body.lock_rotation = false
	_primary_body.angular_damp = 4.0
	_primary_body.linear_damp = 0.7
	var torso_collision_paths: Array[Dictionary] = []
	for path_index in range(torso_paths.size()):
		var path := PackedVector2Array(torso_paths[path_index])
		if path.size() < 2:
			continue
		var source_index := _spider_owner_source(torso_owners, path_index)
		var width := _spider_stroke_width(strokes, source_index)
		var color := _spider_stroke_color(strokes, source_index)
		_record_ink_slice(path)
		torso_collision_paths.append({"path": path, "width": width})
	for path_index in range(decoration_paths.size()):
		var path := PackedVector2Array(decoration_paths[path_index])
		if path.size() < 2:
			continue
		var source_index := _spider_owner_source(decoration_owners, path_index)
		var width := _spider_stroke_width(strokes, source_index)
		var color := _spider_stroke_color(strokes, source_index)
		_record_ink_slice(path)
		torso_collision_paths.append({"path": path, "width": width})

	# Build every real leg before spending the shared shape budget on decorative
	# torso detail. This guarantees each terminal body retains a colliding capsule
	# even for an overdrawn hub with many unclassified ink fragments.
	for leg_index in range(legs.size()):
		_build_spider_leg(legs[leg_index] as Dictionary, leg_index, strokes, torso_center)
	if _spider_feet.size() < 4:
		# The analyzer should have guarded this already. Keep a defensive non-phantom
		# fallback so a malformed result cannot enter a half-built stance solver.
		_clear_rig()
		_spider_anatomy["valid"] = false
		_spider_anatomy["reason"] = "fewer-than-four-built-legs"
		_build_spider_compound(strokes)
		return
	var total_leg_mass := 0.0
	var maximum_leg_mass := 0.0
	for body in _bodies:
		if not is_instance_valid(body) or body == _primary_body:
			continue
		total_leg_mass += body.mass
		maximum_leg_mass = maxf(maximum_leg_mass, body.mass)
	_primary_body.mass = maxf(
		_primary_body.mass,
		maxf(maximum_leg_mass + 0.05, total_leg_mass * (2.0 / 3.0))
	)
	for collision_value in torso_collision_paths:
		var collision_info := collision_value as Dictionary
		_add_capsules(
			_primary_body,
			_sample_points(PackedVector2Array(collision_info.get("path", PackedVector2Array())), 4),
			float(collision_info.get("width", 5.0)),
			torso_center
		)
	_spider_support_height = maxf(8.0, float(_spider_anatomy.get("support_height", 0.0)))
	_spider_total_mass = 0.0
	for body in _bodies:
		if is_instance_valid(body):
			_spider_total_mass += body.mass
	_spider_floor_y = torso_center.y + _spider_support_height


func _build_spider_compound(strokes: Array) -> void:
	_build_compound_rig(strokes, "SpiderCompound", false)
	_spider_support_height = 0.0
	_spider_total_mass = _primary_body.mass if _primary_body != null else 0.0


## recognised, and every stroke stays whole.
func _bind_skinned_ink() -> bool:
	_release_skinned_ink()
	if _primary_body == null or _physics_root == null:
		return false
	var strokes := get_vector_strokes()
	if strokes.is_empty():
		return false
	var skeleton := SkeletonLibrary.resolve(_entity_id, _rig_type)
	if skeleton.is_empty():
		push_warning("RuntimeRig2D: no skeleton for %s/%s; keeping the pivot path." % [_entity_id, _rig_type])
		return false
	var rig := Skeleton2D_Rig.build(skeleton, get_stroke_bounds(), profile)
	if rig.bones.is_empty():
		return false
	var binding := SkinBinding.new()
	binding.bind(strokes, rig)
	if binding.stroke_count() == 0:
		return false

	_skin_root = Node2D.new()
	_skin_root.name = "SkinRoot"
	_primary_body.add_child(_skin_root)
	# Called while the bodies still sit exactly where the strokes were drawn, so this
	# makes the skin root's local space the space the strokes are authored in: their
	# coordinates are then used directly, and the whole layer rides the torso.
	_skin_root.global_transform = _physics_root.global_transform
	_skin_anchor_local = _skin_root.to_local(_primary_body.global_position)

	for index in range(binding.stroke_count()):
		var stroke: Dictionary = strokes[index]
		var points := binding.rest_points(index)
		var width := float(stroke.get("width", 8.0))
		var color: Color = stroke.get("color", Color.BLACK)
		var draw_width := maxf(width, INK_MIN_DRAW_WIDTH)
		var halo := _new_ink_line(draw_width + INK_HALO_EXTRA_WIDTH * 2.0, 0)
		halo.default_color = INK_HALO_LIGHT if color.get_luminance() < 0.55 else INK_HALO_DARK
		halo.points = points
		_skin_root.add_child(halo)
		_skin_halos.append(halo)
		var line := _new_ink_line(draw_width, 1)
		line.default_color = color
		line.points = points
		_skin_root.add_child(line)
		_skin_lines.append(line)

	_skin_rig = rig
	_skin_binding = binding
	_skin_driver = GaitDriver.new()
	_skin_driver.prepare(rig, profile)
	_skin_active = true
	# Pose once at zero delta so the first rendered frame is the drawn pose exactly,
	# rather than whatever the gait happens to be a frame later.
	_animate_skinned_ink(0.0)
	return true


func _new_ink_line(width: float, layer: int) -> Line2D:
	var line := Line2D.new()
	if _underwater_material != null:
		line.material = _underwater_material
	line.width = width
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	# Relative z, so every halo stays under every ink line across the whole drawing.
	line.z_index = layer
	return line


func _release_skinned_ink() -> void:
	_skin_active = false
	_skin_rig = null
	_skin_binding = null
	_skin_driver = null
	_skin_lines.clear()
	_skin_halos.clear()
	_skin_anchor_local = Vector2.ZERO
	# Freed with its body on a rebuild; clearing the reference keeps a stale node from
	# being animated after the rig it belonged to is gone.
	_skin_root = null


## Pose the skeleton for this frame's gait and redraw every stroke through the skin.
func _animate_skinned_ink(delta: float) -> void:
	if not _skin_active or _skin_rig == null or _skin_binding == null or _skin_driver == null:
		return
	if _skin_root == null or not is_instance_valid(_skin_root):
		return
	_skin_driver.advance(delta, _motion_state, _motion_params)
	var anchor_rotation := _primary_body.global_rotation if is_instance_valid(_primary_body) else 0.0
	var posed := _skin_rig.pose(
		_skin_driver.angles(),
		_skin_driver.body_transform(anchor_rotation, _skin_anchor_local)
	)
	for index in range(_skin_lines.size()):
		var points := _skin_binding.deform(index, posed)
		# Reassigned rather than written through: Line2D.points hands back a copy.
		_skin_lines[index].points = points
		_skin_halos[index].points = points


func _build_compound_rig(strokes: Array, body_name: String, lock_upright: bool) -> void:
	if _physics_root == null:
		_create_physics_root()
	var pool := PackedVector2Array()
	for stroke_value in strokes:
		var stroke: Dictionary = stroke_value
		var points := PackedVector2Array(stroke.get("points", PackedVector2Array()))
		pool.append_array(points)
	if pool.is_empty():
		_build_bitmap_fallback()
		return
	var center := _points_center(pool)
	_body_pool = pool
	_body_bounds = _bounds_for_points(pool)
	_body_polylines = []
	_primary_body = _create_body(body_name, center, clampf(_mass_for_points(pool, 5.0), 1.4, 3.8))
	_primary_body.angular_damp = 4.0
	_primary_body.lock_rotation = lock_upright
	for stroke_value in strokes:
		var stroke: Dictionary = stroke_value
		var points := PackedVector2Array(stroke.get("points", PackedVector2Array()))
		if points.size() < 2:
			continue
		_body_polylines.append(points)
		_add_spider_polyline_to_body(
			_primary_body,
			points,
			float(stroke.get("width", 5.0)),
			Color(stroke.get("color", Color.BLACK)),
			center,
			8
		)


func _build_spider_leg(leg: Dictionary, leg_index: int, strokes: Array, torso_center: Vector2) -> void:
	var path := PackedVector2Array(leg.get("path", PackedVector2Array()))
	if path.size() < 3 or _stroke_length(path) < MIN_SEGMENT_LENGTH * 1.25:
		return
	var bend_index := clampi(int(leg.get("bend_index", path.size() / 2)), 1, path.size() - 2)
	var first := path.slice(0, bend_index + 1)
	var second := path.slice(bend_index, path.size())
	if first.size() < 2 or second.size() < 2:
		return
	var source_index := int(leg.get("source_index", leg.get("source_stroke_index", -1)))
	var width := _spider_stroke_width(strokes, source_index)
	var color := _spider_stroke_color(strokes, source_index)
	var chunks: Array[PackedVector2Array] = [first, second]
	var segment_ink_paths := _spider_segment_ink_paths(leg, path, bend_index)
	var segment_records: Array[Dictionary] = []
	var parent := _primary_body
	for segment_index in range(2):
		if _bodies.size() >= MAX_BODIES or _joints.size() >= MAX_JOINTS:
			return
		var chunk := chunks[segment_index]
		var center := _points_center(chunk)
		var raw_mass := _mass_for_points(chunk, width)
		var segment_mass := clampf(raw_mass * 0.34, 0.16, 0.26)
		var body := _create_body("SpiderLeg%02d_%d" % [leg_index, segment_index], center, segment_mass)
		body.gravity_scale = 1.0
		body.angular_damp = 3.2
		body.linear_damp = 0.65
		var ink_descriptors: Array = segment_ink_paths[segment_index]
		if ink_descriptors.is_empty():
			# Defensive compatibility for analyzer results created before ink ownership
			# metadata existed. Current results always take the exact-path branch below.
			_add_spider_polyline_to_body(body, chunk, width, color, center, 3)
		else:
			var collision_descriptor: Dictionary = {}
			for descriptor_value in ink_descriptors:
				var descriptor := descriptor_value as Dictionary
				var ink_points := PackedVector2Array(descriptor.get("points", PackedVector2Array()))
				if ink_points.size() < 2:
					continue
				_record_ink_slice(ink_points)
				# The proximal body collides along its root-most real piece; the distal
				# body uses its sole-most piece so every terminal foot is guaranteed a
				# shape. Other welded pieces remain exact visible ink but cannot consume
				# the bounded shape budget ahead of later feet.
				if collision_descriptor.is_empty() or segment_index == 1:
					collision_descriptor = descriptor
			if not collision_descriptor.is_empty():
				var collision_points := PackedVector2Array(collision_descriptor.get("points", PackedVector2Array()))
				_add_capsules(
					body,
					_sample_points(collision_points, 3),
					float(collision_descriptor.get("width", width)),
					center
				)
		var joint := _create_joint(parent, body, chunk[0], SPIDER_LEG_LIMIT)
		if joint == null:
			body.queue_free()
			return
		var record := {
			"parent": parent,
			"body": body,
			"joint": joint,
			"rest_relative": wrapf(body.rotation - parent.rotation, -PI, PI),
			"role": "leg",
			"limb_index": leg_index,
			"chain_index": segment_index,
			"phase": float(int(leg.get("phase_group", 0))) * PI,
			"phase_group": int(leg.get("phase_group", 0)),
			"side": float(leg.get("side", 1.0)),
			"side_rank": int(leg.get("side_rank", 0)),
			"support_candidate": bool(leg.get("support_candidate", false)),
			"angle_limit": SPIDER_LEG_LIMIT,
			"attachment": Vector2(leg.get("root", path[0])),
			"parent_anchor": _body_local_anchor(parent, chunk[0]),
			"child_anchor": _body_local_anchor(body, chunk[0]),
			"rest_axis_angle": (chunk[chunk.size() - 1] - chunk[0]).angle(),
			"target_angle": 0.0,
			"last_drive_torque": 0.0
		}
		_segments.append(record)
		segment_records.append(record)
		parent = body
	var sole := Vector2(leg.get("sole", path[path.size() - 1]))
	var foot := {
		"leg_index": leg_index,
		"side": float(leg.get("side", 1.0)),
		"side_rank": int(leg.get("side_rank", 0)),
		"phase_group": int(leg.get("phase_group", 0)),
		"support_candidate": bool(leg.get("support_candidate", false)),
		"body": parent,
		"sole_local": _body_local_anchor(parent, sole),
		"rest_offset": sole - torso_center,
		"root_rig": Vector2(leg.get("root", path[0])),
		"bend_rig": path[bend_index],
		"sole_rig": sole,
		"length_a": maxf(2.0, path[0].distance_to(path[bend_index])),
		"length_b": maxf(2.0, path[bend_index].distance_to(sole)),
		"bend_sign": _spider_bend_sign(path[0], path[bend_index], sole),
		"segments": segment_records,
		"stance": false,
		"contact": false,
		"plant_target": sole,
		"last_target": sole,
		"drive_reaction": Vector2.ZERO
	}
	_spider_feet.append(foot)
	_set_spider_foot_friction(foot, false)


func _spider_owner_source(owners: Array, index: int) -> int:
	if index < 0 or index >= owners.size():
		return -1
	var owner: Variant = owners[index]
	if owner is Dictionary:
		return int((owner as Dictionary).get("source_index", (owner as Dictionary).get("stroke_index", -1)))
	return int(owner) if typeof(owner) == TYPE_INT else -1


func _spider_path_mass(paths: Array, owners: Array, strokes: Array) -> float:
	var mass := 0.0
	for path_index in range(paths.size()):
		var path := PackedVector2Array(paths[path_index])
		if path.size() < 2:
			continue
		var source_index := _spider_owner_source(owners, path_index)
		var width := _spider_stroke_width(strokes, source_index)
		mass += _stroke_length(path) * width * 0.0018
	return mass


func _spider_segment_ink_paths(leg: Dictionary, composite_path: PackedVector2Array, bend_index: int) -> Array:
	var proximal: Array[Dictionary] = []
	var distal: Array[Dictionary] = []
	var ink_paths: Array = leg.get("ink_paths", [])
	if ink_paths.is_empty():
		return [proximal, distal]
	var total_ink_length := 0.0
	for descriptor_value in ink_paths:
		var descriptor := descriptor_value as Dictionary
		total_ink_length += _stroke_length(PackedVector2Array(descriptor.get("points", PackedVector2Array())))
	if total_ink_length <= 0.01:
		return [proximal, distal]
	var composite_length := maxf(0.01, _stroke_length(composite_path))
	var bend_length := _stroke_length(composite_path.slice(0, bend_index + 1))
	var split_length := total_ink_length * clampf(bend_length / composite_length, 0.05, 0.95)
	var traveled := 0.0
	for descriptor_value in ink_paths:
		var descriptor := (descriptor_value as Dictionary).duplicate(true)
		var points := PackedVector2Array(descriptor.get("points", PackedVector2Array()))
		var piece_length := _stroke_length(points)
		if points.size() < 2 or piece_length <= 0.01:
			continue
		if traveled + piece_length <= split_length + 0.01:
			proximal.append(descriptor)
		elif traveled >= split_length - 0.01:
			distal.append(descriptor)
		else:
			var local_split := split_length - traveled
			var proximal_points := _spider_slice_polyline(points, 0.0, local_split)
			var distal_points := _spider_slice_polyline(points, local_split, piece_length)
			if proximal_points.size() >= 2:
				var proximal_descriptor := descriptor.duplicate(true)
				proximal_descriptor["points"] = proximal_points
				proximal.append(proximal_descriptor)
			if distal_points.size() >= 2:
				var distal_descriptor := descriptor.duplicate(true)
				distal_descriptor["points"] = distal_points
				distal.append(distal_descriptor)
		traveled += piece_length
	return [proximal, distal]


func _spider_slice_polyline(points: PackedVector2Array, from_length: float, to_length: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	if points.size() < 2 or to_length <= from_length:
		return result
	var total_length := _stroke_length(points)
	var clamped_from := clampf(from_length, 0.0, total_length)
	var clamped_to := clampf(to_length, clamped_from, total_length)
	var traveled := 0.0
	for index in range(points.size() - 1):
		var start := points[index]
		var finish := points[index + 1]
		var segment_length := start.distance_to(finish)
		if segment_length <= 0.001:
			continue
		var segment_start := traveled
		var segment_end := traveled + segment_length
		if segment_end < clamped_from:
			traveled = segment_end
			continue
		if segment_start > clamped_to:
			break
		var local_from := clampf((clamped_from - segment_start) / segment_length, 0.0, 1.0)
		var local_to := clampf((clamped_to - segment_start) / segment_length, 0.0, 1.0)
		var first_point := start.lerp(finish, local_from)
		var last_point := start.lerp(finish, local_to)
		if result.is_empty() or result[result.size() - 1].distance_squared_to(first_point) > 0.0001:
			result.append(first_point)
		if result[result.size() - 1].distance_squared_to(last_point) > 0.0001:
			result.append(last_point)
		traveled = segment_end
		if segment_end >= clamped_to:
			break
	return result


func _spider_stroke_width(strokes: Array, source_index: int) -> float:
	if source_index >= 0 and source_index < strokes.size() and strokes[source_index] is Dictionary:
		return float((strokes[source_index] as Dictionary).get("width", 5.0))
	return float((strokes[0] as Dictionary).get("width", 5.0)) if not strokes.is_empty() else 5.0


func _spider_stroke_color(strokes: Array, source_index: int) -> Color:
	if source_index >= 0 and source_index < strokes.size() and strokes[source_index] is Dictionary:
		return Color((strokes[source_index] as Dictionary).get("color", Color.BLACK))
	return Color.BLACK


func _spider_bend_sign(root: Vector2, bend: Vector2, sole: Vector2) -> float:
	var cross := (bend - root).cross(sole - bend)
	if absf(cross) < 0.001:
		return 1.0 if sole.x >= root.x else -1.0
	return signf(cross)


func _add_spider_polyline_to_body(
	body: ActiveRigBody2D,
	points: PackedVector2Array,
	width: float,
	color: Color,
	body_center: Vector2,
	maximum_collision_points: int
) -> void:
	_record_ink_slice(points)
	_add_capsules(body, _sample_points(points, maxi(2, maximum_collision_points)), width, body_center)


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
				# A wing drawn meeting the body in the middle has no lateral offset, so
				# the head/eye/blob rule welded it. Being one of a pair settles it.
				if not _is_wing_like(strokes, index) \
						and not _closed_stroke_is_appendage(blob_bounds, body_center):
					body_decorations.append(stroke)
					continue
				# Keep a loop-shaped appendage INTACT on one body, hinged where it
				# meets the torso. Splitting it the usual way leaves part of the loop
				# welded to the torso and part on the limb, so the moment the wing
				# beats, the drawn loop visibly tears open into a "C".
				var hinged := _loop_from_attachment(points)
				if not hinged.is_empty():
					candidates.append({
						"path": hinged, "stroke": stroke, "attachment": hinged[0]
					})
					continue
		var paths := _paths_attached_to_body(points, attachment_radius)
		if paths.is_empty() or _stroke_length(points) < MIN_SEGMENT_LENGTH:
			body_decorations.append(stroke)
			continue
		# ONE stroke hinges in ONE place. A stroke that touches the body more than
		# once -- a wing loop crossing the body line, which is how a butterfly is
		# normally drawn -- was cut into an arc per contact, and each arc became its
		# own limb hinged separately. The halves of one drawn line then swung apart
		# and the wing visibly tore. The longest reach becomes the limb; anything
		# left over stays on the torso as intact ink rather than a second hinge.
		var longest_path := PackedVector2Array()
		for path_value in paths:
			var path: PackedVector2Array = path_value
			if _stroke_length(path) > _stroke_length(longest_path):
				longest_path = path
		if _stroke_length(longest_path) >= MIN_SEGMENT_LENGTH:
			candidates.append({
				"path": longest_path, "stroke": stroke, "attachment": longest_path[0]
			})
		for path_value in paths:
			var leftover: PackedVector2Array = path_value
			if leftover != longest_path and leftover.size() >= 2:
				body_decorations.append({
					"points": leftover,
					"width": stroke.get("width", 5.0),
					"color": stroke.get("color", Color.BLACK)
				})
	# Stroke order is drawing-order, not anatomy. Stable spatial ordering gives
	# left/right counterparts predictable gait phases regardless of when the
	# player happened to draw each leg.
	candidates.sort_custom(_appendage_candidate_less)
	var next_limb_index := 0
	var limb_limit := _limb_limit_for_entity()
	for candidate in candidates:
		if next_limb_index >= limb_limit:
			# Weld the overflowing candidate's own path, not its whole stroke: a
			# split stroke may already have its other half built as a limb, and
			# re-welding the full stroke would duplicate that ink on a second body.
			var source: Dictionary = candidate["stroke"]
			body_decorations.append({
				"points": candidate["path"],
				"width": source.get("width", 5.0),
				"color": source.get("color", Color.BLACK)
			})
			continue
		_build_limb_path(candidate["path"], candidate["stroke"], next_limb_index, body_center)
		next_limb_index += 1
	for stroke in body_decorations:
		_add_stroke_to_body(_primary_body, stroke, body_center, false)


## Wings and fins are drawn as closed roundish loops, exactly like a head is, so
## the head/eye/blob rule welded them rigidly to the torso and a drawn butterfly
## could never flap. Two things separate an appendage from a head: it comes off the
## SIDE of the body rather than sitting on its axis, and it is comparable in size to
## the body rather than a small feature on it. Only creatures whose gait is actually
## driven by paired appendages take this path, so a bird's or fish's head still welds.
## Re-orders a closed loop so it begins at the point nearest the torso. That point
## becomes the limb's hinge, and because the whole loop travels on a single body the
## drawn shape stays intact through the beat.
func _loop_from_attachment(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3 or _body_polylines.is_empty():
		return PackedVector2Array()
	var best_index := 0
	var best_distance := INF
	for index in range(points.size()):
		for polyline_value in _body_polylines:
			var distance := _point_polyline_distance(points[index], polyline_value as PackedVector2Array)
			if distance < best_distance:
				best_distance = distance
				best_index = index
	var ordered := PackedVector2Array()
	for offset in range(points.size()):
		ordered.append(points[(best_index + offset) % points.size()])
	ordered.append(points[best_index])  # close the loop back onto its hinge
	return ordered


func _closed_stroke_is_appendage(blob_bounds: Rect2, body_center: Vector2) -> bool:
	if _rig_type not in ["flier", "swimmer"]:
		return false
	var lateral := absf(blob_bounds.get_center().x - body_center.x)
	var body_extent := maxf(1.0, _body_bounds.size.length())
	var big_enough := blob_bounds.size.length() >= body_extent * 0.35
	var off_axis := lateral >= maxf(6.0, _body_bounds.size.x * 0.35)
	return big_enough and off_axis


func _build_chain_rig(strokes: Array) -> void:
	_create_physics_root()
	var longest: Dictionary = strokes[0]
	for stroke_value in strokes:
		var stroke: Dictionary = stroke_value
		if _stroke_length(stroke["points"]) > _stroke_length(longest["points"]):
			longest = stroke
	var chain_points: PackedVector2Array = longest["points"]
	var link_indices := _sample_indices(chain_points, 13)
	if link_indices.size() < 2:
		_build_standard_rig(strokes)
		return
	var width := float(longest.get("width", 5.0))
	var parent: ActiveRigBody2D
	for index in range(link_indices.size() - 1):
		if _bodies.size() >= MAX_BODIES:
			break
		var from_index := link_indices[index]
		var to_index := link_indices[index + 1]
		var from_point := chain_points[from_index]
		var to_point := chain_points[to_index]
		var center := (from_point + to_point) * 0.5
		var body := _create_body("Chain%02d" % index, center, 0.35)
		# Joints and the collision capsule stay on the straight sampled pair; the
		# visible ink is the exact drawn slice between the samples so the snake
		# renders the wave the player drew, padded a little past each joint.
		var visual_start := maxi(0, from_index - LIMB_JOINT_OVERLAP_POINTS)
		var visual_end := mini(chain_points.size() - 1, to_index + LIMB_JOINT_OVERLAP_POINTS)
		_record_ink_slice(chain_points.slice(visual_start, visual_end + 1), from_index - visual_start, visual_end - to_index)
		_add_capsules(body, PackedVector2Array([from_point, to_point]), width, center)
		if index == 0:
			_primary_body = body
			_body_pool = PackedVector2Array([from_point, to_point])
		else:
			var joint := _create_joint(parent, body, from_point, deg_to_rad(58.0))
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
					"parent_anchor": _body_local_anchor(parent, from_point),
					"child_anchor": _body_local_anchor(body, from_point),
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
	body_center: Vector2,
	extra_ink: Array = []
) -> void:
	var length := _stroke_length(path)
	# Classify from the point that reaches FURTHEST from the attachment, not from
	# the last point drawn. Players draw wings, fins and flippers as closed loops,
	# and a loop's last point comes back to its start -- so the limb reported a
	# near-zero direction and a butterfly's wings were classified as legs, which
	# meant the wing flap gait never ran on them and they hung and folded instead.
	var role := _role_for_limb(path[0], _furthest_point(path), body_center)
	var width := float(stroke.get("width", 5.0))
	var per_limb_cap := 2 if _entity_id != "snake" else MAX_SEGMENTS_PER_LIMB
	var segment_count := clampi(int(ceil(length / 38.0)), 1, per_limb_cap)
	if _minimum_limb_segments(role) >= 2 and length >= MIN_SEGMENT_LENGTH * 1.25:
		segment_count = maxi(segment_count, 2)
	# A wing is one surface, and a drawn loop is one closed shape. Splitting either
	# along its length puts halves of the same ink on bodies that then rotate apart,
	# so the wing visibly breaks in the middle -- which is what "the wings detach"
	# was. Both stay a single piece. (The closed-loop test alone was not enough: once
	# a loop is trimmed to the arc that attaches, it is no longer closed, so a wing
	# was still being cut in two.)
	if role == "wing":
		segment_count = 1
	elif path.size() > 2 and path[0].distance_to(path[path.size() - 1]) <= maxf(6.0, width * 1.5):
		segment_count = 1
	segment_count = mini(segment_count, MAX_BODIES - _bodies.size())
	if segment_count <= 0:
		# No body budget left: keep the limb's ink intact on the torso.
		_record_ink_slice(path)
		for extra_value in extra_ink:
			_record_ink_slice(extra_value as PackedVector2Array)
		return
	var parent := _primary_body
	# Which side of the body this limb reaches towards. Taken from the point that
	# reaches FURTHEST, because a loop-shaped wing ends where it began -- at its
	# hinge, next to the body -- so the last point put both wings on the same side
	# and they beat together instead of mirroring.
	var side := -1.0 if _furthest_point(path).x < body_center.x else 1.0
	# Built chunk records drive the trailing-ink weld and the extra-ink split below.
	var built: Array[Dictionary] = []
	# First path index whose ink has not been rendered on a limb body yet. Skipped
	# short chunks stay pending and ride the next built body (or the trailing weld).
	var pending_index := 0
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
		var raw_mass := _mass_for_points(chunk, width)
		var limb_mass := clampf(raw_mass * (0.62 if segment_index == 0 else 0.48), 0.16, 0.62)
		var body := _create_body("Limb%02d_%d" % [limb_index, segment_index], center, limb_mass)
		body.gravity_scale = 0.48 if segment_index == 0 else 0.32
		body.angular_damp = 3.8 if segment_index == 0 else 4.6
		body.max_angular_speed = LIMB_MAX_ANGULAR_SPEED
		_configure_limb_contact(body, role, segment_index, segment_count)
		# Collision, mass, and the joint anchor use the exact chunk; the visible
		# ink covers everything pending plus a little padding past each joint so
		# the drawing stays continuous while the PD muscle lets bodies drift.
		var visual_start := maxi(0, pending_index - LIMB_JOINT_OVERLAP_POINTS)
		var visual_end := mini(path.size() - 1, end_index + LIMB_JOINT_OVERLAP_POINTS)
		_record_ink_slice(path.slice(visual_start, visual_end + 1), pending_index - visual_start, visual_end - end_index)
		_add_capsules(body, chunk, width, center)
		# A wing is often drawn as a broad loop pinned along the body, so a wide
		# envelope does not read as flapping -- it reads as the wing tumbling off
		# the creature. Keep wing travel tight enough that the silhouette stays a
		# butterfly/bird through the whole beat.
		# The drawing has to keep looking like the drawing. Every gait in the game asks
		# for at most ~38 degrees (a hopper's jump), so an envelope just above that
		# leaves every animation intact while making it impossible for a limb to fold
		# far enough that the silhouette stops reading as the thing the player drew.
		# A wing is tighter still: it is usually a broad loop, so the same rotation
		# distorts it much more than it distorts a thin leg.
		var limit := deg_to_rad(30.0 if role == "wing" else 46.0)
		var joint := _create_joint(parent, body, chunk[0], limit)
		if joint == null:
			body.queue_free()
			_bodies.erase(body)
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
		built.append({"body": body, "center": center, "start_index": pending_index, "end_index": end_index})
		pending_index = end_index
		parent = body
	# Any trailing ink the loop could not give a body (joint budget, short chunk)
	# is welded onto the last built body so no part of the drawing disappears.
	if pending_index < path.size() - 1:
		var weld_target := parent if parent != null else _primary_body
		var weld_center := weld_target.position
		if not built.is_empty():
			weld_center = built[built.size() - 1]["center"]
		var weld_start := maxi(0, pending_index - LIMB_JOINT_OVERLAP_POINTS)
		_record_ink_slice(path.slice(weld_start, path.size()), pending_index - weld_start, 0)
		if not built.is_empty():
			built[built.size() - 1]["end_index"] = path.size() - 1
	if built.is_empty():
		for extra_value in extra_ink:
			_record_ink_slice(extra_value as PackedVector2Array)
		return
	# Split companion ink (e.g. the return side of a scribble spike) at the same
	# arc ratios as the built chunks so each limb segment carries its share.
	var arc_total := maxf(length, 0.001)
	for extra_value in extra_ink:
		var extra := extra_value as PackedVector2Array
		var extra_length := _stroke_length(extra)
		if extra.size() < 2 or extra_length <= 0.001:
			continue
		for build_index in range(built.size()):
			var info: Dictionary = built[build_index]
			var from_ratio := 0.0 if build_index == 0 else _stroke_length(path.slice(0, int(info["start_index"]) + 1)) / arc_total
			var to_ratio := 1.0 if build_index == built.size() - 1 else _stroke_length(path.slice(0, int(info["end_index"]) + 1)) / arc_total
			var piece := _spider_slice_polyline(extra, from_ratio * extra_length, to_ratio * extra_length)
			if piece.size() >= 2:
				_record_ink_slice(piece)


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
		if _underwater_material != null:
			sprite.material = _underwater_material
		_primary_body.add_child(sprite)
		_body.visible = false


## Recover articulation for a creature drawn as a single continuous scribble. Runs only
## after the standard rig and only when it produced no joints; it never fabricates limbs
## the player did not draw — if the stroke has no clear radial appendages it leaves the
## single-body rig alone. Skipped entirely for rig_type "none" (physics objects and
## utilities), which must stay rigid, and for the empty-strokes bitmap path.


func _create_physics_root() -> void:
	_physics_root = Node2D.new()
	_physics_root.name = "GeneratedPhysicsRig"
	# top_level on the rig bodies detaches transforms, not canvas z, so this lifts
	# all rendered ink above the level decor sprites.
	_physics_root.z_index = INK_Z_INDEX
	get_parent().add_child(_physics_root)


## Objects and utilities are rigid by definition, but the builders articulate them
## anyway -- a drawn key or ramp goes through the same stroke rig a horse does. Every
## rig body is top_level, so those bodies simulate INDEPENDENTLY of the object that
## owns them, and the skinned ink is parented to the torso. What the player saw was the
## drawing sliding off its own collider: a placement preview whose collision followed
## the cursor while the picture stayed on the floor where the torso had fallen, and a
## placed object whose picture wandered away from the thing it was supposed to be.
## Worse, those loose bodies are on the same collision layer as the terrain, so the
## placement overlap test found them -- an object reported "no room" wherever it was
## pointed, which is what made shapes and utilities feel unplaceable.
##
## Pinning the graph back onto the owning body and switching its collision off leaves
## exactly one physics representation: the object's own, whose shapes
## PhysicsShapeObject already rebuilds from these same strokes.
func _pin_rig_to_owner() -> void:
	if _bodies.is_empty():
		return
	_rigid_object_rig = true
	for body in _bodies:
		if not is_instance_valid(body):
			continue
		body.freeze = true
		body.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		body.collision_layer = 0
		body.collision_mask = 0
		body.linear_velocity = Vector2.ZERO
		body.angular_velocity = 0.0
		# Runs before the first physics step, so the body is still exactly where the
		# strokes put it; re-assigning the global transform after clearing top_level
		# is what converts that world pose into the local offset it keeps from here on.
		var world := body.global_transform
		body.top_level = false
		body.global_transform = world


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
	_record_ink_slice(points)
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


## Record which slice of the drawn ink a body was built from. The builders used to
## RENDER these slices, one Line2D per body, and that is what the skinned layer
## replaced -- so they are only bookkeeping now, and the audit below is what reads
## them: a decomposition that invents geometry the player never drew, or loses some of
## it, gives that body a collider the drawing does not account for.
func _record_ink_slice(
	points: PackedVector2Array,
	overlap_prefix: int = 0,
	overlap_suffix: int = 0
) -> void:
	_body_ink.append({
		"points": points.duplicate(),
		"overlap_prefix": overlap_prefix,
		"overlap_suffix": overlap_suffix
	})


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
	if _entity_id == "spider" and not _spider_feet.is_empty():
		_stand_height = _spider_support_height
		return
	for body in _bodies:
		if not is_instance_valid(body):
			continue
		var relative: Transform2D = _rest_transforms.get(body.get_instance_id(), Transform2D.IDENTITY)
		# Measure to the bottom of the body's COLLISION SHAPES, not to its origin.
		# Using the origin measured to the middle of the foot segment, so the rig was
		# parked with the lower half of every leg buried in the floor: the ground then
		# shoved the legs backwards until the drawing lay splayed flat, which is the
		# collapse that made creatures look broken no matter how the gait was tuned.
		_stand_height = maxf(_stand_height, relative.origin.y + _body_lower_extent(body, relative))
	# Sit low enough that the drawn feet press a few px into the floor instead of
	# grazing it, so contact actually registers and the controller reads the
	# creature as grounded (idle/walk/jump) rather than perpetually "falling".
	_stand_height -= 4.0


## How far the lowest point of a body's collision shapes sits below its origin,
## expressed in the rest frame (so a rotated limb reports its true reach).
func _body_lower_extent(body: PhysicsBody2D, relative: Transform2D) -> float:
	var lowest := 0.0
	for child in body.get_children():
		var collision := child as CollisionShape2D
		if collision == null or collision.shape == null:
			continue
		var extents := Vector2.ZERO
		var shape := collision.shape
		if shape is CapsuleShape2D:
			var capsule := shape as CapsuleShape2D
			extents = Vector2(capsule.radius, capsule.height * 0.5)
		elif shape is RectangleShape2D:
			extents = (shape as RectangleShape2D).size * 0.5
		elif shape is CircleShape2D:
			var radius := (shape as CircleShape2D).radius
			extents = Vector2(radius, radius)
		else:
			continue
		# Corners of the shape's bounding box, taken into the rest frame.
		var basis := Transform2D(relative.get_rotation(), Vector2.ZERO) * collision.transform
		for corner in [
			Vector2(-extents.x, -extents.y), Vector2(extents.x, -extents.y),
			Vector2(-extents.x, extents.y), Vector2(extents.x, extents.y)
		]:
			lowest = maxf(lowest, (basis * corner).y)
	return lowest


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
	_rigid_object_rig = false
	_release_skinned_ink()
	_bodies.clear()
	_joints.clear()
	_segments.clear()
	_body_pool = PackedVector2Array()
	_body_bounds = Rect2()
	_body_polylines = []
	_body_ink.clear()
	_max_tracked_angle = 0.0
	_shape_count = 0
	_rest_transforms.clear()
	_physics_frames_since_build = 0
	_recovery_count = 0
	_spider_anatomy = {}
	_spider_feet.clear()
	_spider_support_height = 0.0
	_spider_support_active = false
	_spider_stance_group = 0
	_spider_gait_phase = 0.0
	_spider_total_mass = 0.0
	_spider_floor_y = 0.0
	_spider_floor_normal = Vector2.UP
	_spider_force_release_frames = 0
	_spider_leg_drive_force = Vector2.ZERO
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
		var attach_left := false
		var attach_right := false
		var radius := clampf(get_stroke_bounds().size.length() * 0.08, 6.0, 18.0)
		for other_index in range(strokes.size()):
			if index == other_index:
				continue
			var other: PackedVector2Array = strokes[other_index]["points"]
			# Which point of the other stroke comes closest to this one? Endpoints
			# alone are not enough: a closed head circle's seam sits wherever the
			# player happened to start drawing it, and an arm stroke crosses the
			# spine mid-stroke. Missing those contacts made the head out-score the
			# spine as a stick figure's torso.
			var best_gap := _point_polyline_distance(other[0], points)
			var contact := other[0]
			var tail_gap := _point_polyline_distance(other[other.size() - 1], points)
			if tail_gap < best_gap:
				best_gap = tail_gap
				contact = other[other.size() - 1]
			for sample in _sample_points(other, 17):
				var gap := _point_polyline_distance(sample, points)
				if gap < best_gap:
					best_gap = gap
					contact = sample
			# Also measure THIS stroke's points against the other one. Sampling only
			# the other stroke misses a thin line crossed by a big loop: the loop's
			# samples land around its rim and step over the crossing entirely, so a
			# butterfly's body line saw only one of its two wings, collected no
			# hub bonus, and lost the torso to a wing.
			for sample in _sample_points(points, 17):
				var gap := _point_polyline_distance(sample, other)
				if gap < best_gap:
					best_gap = gap
					contact = sample
			if best_gap <= radius:
				incoming += 1
				# Is the contact above or below this stroke's centre? The torso is
				# the hub that limbs radiate from ABOVE (head/arms) and BELOW (legs);
				# a head only has the body joining it from below. This above-and-below
				# test is what stops a big round head from being chosen as the body
				# of a stick figure.
				if contact.y < stroke_center.y:
					attach_above = true
				else:
					attach_below = true
				if contact.x < stroke_center.x:
					attach_left = true
				else:
					attach_right = true
		var closed := _stroke_is_closed(points, float(stroke.get("width", 5.0)))
		var area_ratio := absf(_polygon_area(points)) / max_area if closed else 0.0
		var compactness := minf(stroke_bounds.size.x, stroke_bounds.size.y) / maxf(1.0, maxf(stroke_bounds.size.x, stroke_bounds.size.y))
		var centrality := 1.0 - clampf(stroke_center.distance_to(drawing_center) / drawing_radius, 0.0, 1.0)
		# A stroke that limbs join from opposite sides is almost certainly the torso.
		# Weighted strongly so it beats the roundness bonus a head collects.
		# BOTH axes count: limbs radiate above/below on a stick figure, but a
		# butterfly's or bird's wings radiate left/right off a thin body line. With
		# only the vertical test, a drawn wing loop out-scored the body on its closed
		# and area bonuses, became the torso, absorbed the other wing, and left the
		# body line flailing as a "leg" -- so the butterfly could never flap.
		# Outweighs closed+area+compactness combined, because being the hub that
		# appendages radiate from is stronger evidence of a torso than being the
		# roundest or largest closed shape in the drawing.
		var hub_bonus := 7.5 if (attach_above and attach_below) or (attach_left and attach_right) else 0.0
		var bodied := _entity_id == "spider" or _rig_type in ["walker", "hopper", "swimmer"]
		var closed_weight := 7.0 if bodied else 4.5
		var score := (closed_weight if closed else 0.0) + float(incoming) * 2.2 + hub_bonus \
			+ area_ratio * 1.6 + compactness * 0.7 + centrality * 1.8 \
			+ _stroke_length(points) / max_length * 0.25
		# On a flier, the closed round shapes are the WINGS and the body is the thing
		# they hang off. Scored purely on roundness and area a wing outscores a thin
		# body line, becomes the torso, and then both wings sit on the same side of
		# it -- so they beat together instead of mirroring and the drawing reads
		# lopsided. An off-centre closed shape is disqualified from being the body.
		if _is_wing_like(strokes, index):
			score -= 9.0
		if score > best_score:
			best_score = score
			best_index = index
	return best_index


## A flier's wings are recognised by coming in PAIRS: a closed round shape that has a
## closed round twin of comparable size is one of a pair, and a body never is.
## Position deliberately plays no part -- a butterfly's wings meet in the middle,
## exactly where its body is, so anything based on being off-centre cannot tell them
## apart. A lone closed shape is not wing-like, so a bird's oval body still reads as
## a body. This one answer drives all three decisions that were disagreeing: what
## becomes the torso, what gets absorbed into it, and what gets hinged.
func _is_wing_like(strokes: Array, index: int) -> bool:
	if _rig_type != "flier":
		return false
	var stroke: Dictionary = strokes[index]
	var points := PackedVector2Array(stroke.get("points", PackedVector2Array()))
	if points.size() < 3 or not _stroke_is_closed(points, float(stroke.get("width", 5.0))):
		return false
	var bounds := _bounds_for_points(points)
	var compactness := minf(bounds.size.x, bounds.size.y) / maxf(1.0, maxf(bounds.size.x, bounds.size.y))
	if compactness <= 0.45:
		return false
	var mine := bounds.size.length()
	if mine <= 0.001:
		return false
	for other in range(strokes.size()):
		if other == index:
			continue
		var sibling: Dictionary = strokes[other]
		var sibling_points := PackedVector2Array(sibling.get("points", PackedVector2Array()))
		if sibling_points.size() < 3 or not _stroke_is_closed(sibling_points, float(sibling.get("width", 5.0))):
			continue
		var theirs := _bounds_for_points(sibling_points).size.length()
		if theirs > 0.001 and maxf(mine, theirs) / minf(mine, theirs) <= 1.7:
			return true
	return false


func _appendage_candidate_less(a: Dictionary, b: Dictionary) -> bool:
	var a_point := Vector2(a["attachment"])
	var b_point := Vector2(b["attachment"])
	var center := _body_bounds.get_center()
	var a_side := 0 if a_point.x < center.x else 1
	var b_side := 0 if b_point.x < center.x else 1
	if a_side != b_side:
		return a_side < b_side
	if not is_equal_approx(a_point.y, b_point.y):
		return a_point.y < b_point.y
	return a_point.x < b_point.x


func _phase_for_limb(limb_index: int, _side: float) -> float:
	if _rig_type in ["biped", "walker"]:
		return 0.0 if limb_index % 2 == 0 else PI
	if _rig_type == "flier":
		# Wings beat TOGETHER, mirrored left against right by the gait's `side` term.
		# Giving each wing its own phase offset is right for a walker's legs but
		# turns a butterfly drawn as four loops into an asymmetric scramble: each
		# loop sat at a different angle instead of the pairs sweeping as one.
		return 0.0
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
	# Both endpoints are free. Splitting at an interior torso contact is only
	# justified for a genuine limb pair drawn in one stroke (down one leg, up to
	# the hip, down the other leg): the stroke must touch the torso closely, both
	# halves must be limb-sized, and the stroke must fold back at the contact. A
	# long stroke that merely grazes the torso mid-way keeps going in the same
	# direction and must never be cut in half.
	var closest_index := -1
	var closest_gap := radius * 0.6
	for index in range(1, points.size() - 1):
		var gap := _point_body_distance(points[index])
		if gap < closest_gap:
			closest_gap = gap
			closest_index = index
	if closest_index > 0:
		var first := points.slice(0, closest_index + 1)
		first.reverse()
		var second := points.slice(closest_index, points.size())
		if _stroke_length(first) >= MIN_SEGMENT_LENGTH * 2.0 \
				and _stroke_length(second) >= MIN_SEGMENT_LENGTH * 2.0 \
				and (_halves_form_limb_pair(first, second, radius) or _halves_cross_body(first, second, radius)):
			result.append(first)
			result.append(second)
			return result
	# Near-miss endpoint attachment rescues a limb drawn with a small gap to the
	# body (previously dropped to decoration or, worse, split at the graze point).
	if minf(start_gap, end_gap) <= radius * 1.8:
		var near_ordered := points.duplicate()
		if end_gap < start_gap:
			near_ordered.reverse()
		result.append(near_ordered)
	return result


## Both halves start at the interior torso contact. A limb pair folds back there,
## so the two halves leave the contact in a similar direction; a grazing stroke
## continues onward, so its halves leave in opposite directions.
func _halves_form_limb_pair(first: PackedVector2Array, second: PackedVector2Array, radius: float) -> bool:
	var contact := first[0]
	var out_a := _point_at_arc_length(first, radius) - contact
	var out_b := _point_at_arc_length(second, radius) - contact
	if out_a.length() < 0.5 or out_b.length() < 0.5:
		return false
	return out_a.normalized().dot(out_b.normalized()) > 0.2


func _point_at_arc_length(points: PackedVector2Array, distance: float) -> Vector2:
	var traveled := 0.0
	for index in range(points.size() - 1):
		var segment := points[index].distance_to(points[index + 1])
		if traveled + segment >= distance and segment > 0.001:
			return points[index].lerp(points[index + 1], (distance - traveled) / segment)
		traveled += segment
	return points[points.size() - 1]


## True when the stroke actually CROSSES the torso ink at the contact: the two
## halves continue on opposite sides of the nearest torso segment's line. Arms
## drawn straight across a stick figure's spine cross (and must split into two
## limbs); a tail passing beside the torso outline stays on one side (and must
## stay whole).
func _halves_cross_body(first: PackedVector2Array, second: PackedVector2Array, radius: float) -> bool:
	var contact := first[0]
	var body_segment := _nearest_body_segment(contact)
	if body_segment.is_empty():
		return false
	var segment_start := Vector2(body_segment["start"])
	var direction := Vector2(body_segment["end"]) - segment_start
	if direction.length() < 0.001:
		return false
	var probe := maxf(radius * 0.5, MIN_SEGMENT_LENGTH)
	var side_a := direction.cross(_point_at_arc_length(first, probe) - segment_start)
	var side_b := direction.cross(_point_at_arc_length(second, probe) - segment_start)
	return side_a * side_b < -0.001


func _nearest_body_segment(point: Vector2) -> Dictionary:
	var best := INF
	var result := {}
	for polyline_value in _body_polylines:
		var polyline := polyline_value as PackedVector2Array
		for index in range(polyline.size() - 1):
			var nearest := Geometry2D.get_closest_point_to_segment(point, polyline[index], polyline[index + 1])
			var gap := point.distance_to(nearest)
			if gap < best:
				best = gap
				result = {"start": polyline[index], "end": polyline[index + 1]}
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
		# A wing overlapping the body must stay a separate, hingeable piece; absorbing
		# it welds it rigid and the creature flies with one wing.
		if _is_wing_like(strokes, index):
			continue
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


## The point of a limb path lying furthest from where it attaches. For an open
## stroke this is essentially the tip; for a closed loop (a drawn wing or fin) it
## is the far side of the loop, which is what the limb actually reaches towards.
func _furthest_point(path: PackedVector2Array) -> Vector2:
	if path.is_empty():
		return Vector2.ZERO
	var origin := path[0]
	var best := path[path.size() - 1]
	var best_distance := origin.distance_squared_to(best)
	for point in path:
		var distance := origin.distance_squared_to(point)
		if distance > best_distance:
			best_distance = distance
			best = point
	return best


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
			# Every appendage on a flier is a wing, the same way a hopper treats every
			# appendage as a driven leg. A butterfly is drawn as several loops around a
			# body and the lower pair read as "downward" limbs, so the old direction
			# test called them legs -- which on a flier means a static -20 degree pose
			# and no animation at all. Half the wings simply hung there.
			return "wing"
		"swimmer":
			return "tail" if absf(delta.x) > absf(delta.y) else "fin"
		_:
			return "limb"


func _limb_limit_for_entity() -> int:
	if _entity_id == "spider":
		return 8
	match _rig_type:
		"walker": return 6
		"biped": return 4
		"hopper": return 4
		"flier": return 6
		"swimmer": return 4
		_: return 6


func _minimum_limb_segments(role: String) -> int:
	if role == "leg" and (_entity_id == "spider" or _rig_type in ["walker", "biped", "hopper"]):
		return 2
	if role == "limb" and _rig_type == "hopper":
		return 2
	if role == "arm" and _rig_type == "biped":
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


## MOVE THE WHOLE RIG, KEEPING ITS POSE. The only correct way to teleport one.
##
## ⚠ Writing `global_position` on a live RigidBody2D does nothing -- the physics server
## overwrites it the same frame, which is trap 7 in LEVEL_1.md and has now bitten this
## project twice. `PlayableEntity._apply_morph_state_now` was doing exactly that, so every
## teleport of a drawn creature silently failed: pressing down at the straw heap as an ant
## refused nothing and moved nobody, and the same was true of the door into Ang Bale and of
## both ways back out. Over a few pixels the write survives long enough to look like it
## worked, which is why it was only visible on the two thousand-unit hops.
##
## Frozen as a COMPLETE GRAPH before anything moves, for the reason _recover_rig gives:
## releasing bodies one at a time lets the solver observe a half-moved chain through a joint
## whose partner is still where it was, and pull the repaired half back.
func translate_rig(offset: Vector2, velocity: Vector2 = Vector2.ZERO) -> void:
	if _bodies.is_empty() or not _vector_is_sane(offset):
		return
	for body in _bodies:
		if is_instance_valid(body):
			body.freeze = true
	for body in _bodies:
		if not is_instance_valid(body):
			continue
		# Its own transform plus the offset, not a rest pose: a teleport moves the creature
		# the player is looking at, and snapping it back to rest would be a different animal
		# arriving at the far end.
		body.global_position += offset
		body.linear_velocity = velocity
		body.angular_velocity = 0.0
	for body in _bodies:
		if not is_instance_valid(body):
			continue
		body.freeze = false
		body.sleeping = false
	_physics_frames_since_build = 0


func _vector_is_sane(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


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
	# Bodies snapped back to the rest pose: the integrated joint angles are zero
	# again by construction.
	for segment_value in _segments:
		(segment_value as Dictionary)["tracked_angle"] = 0.0
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


func _sample_indices(points: PackedVector2Array, maximum: int) -> PackedInt32Array:
	var indices := PackedInt32Array()
	if points.size() <= maximum:
		for index in range(points.size()):
			indices.append(index)
		return indices
	for index in range(maximum):
		indices.append(int(round(float(index) * float(points.size() - 1) / float(maximum - 1))))
	return indices


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


## True when everything the rig rendered is the player's ink: every rendered
## polyline lies on a drawn stroke (no fabricated chords) and the total rendered
## length, excluding joint-overlap padding, conserves the drawn length (no ink
## silently dropped or duplicated).
func _rig_ink_is_intact() -> bool:
	var strokes := get_vector_strokes()
	var input_length := 0.0
	for stroke_value in strokes:
		input_length += _stroke_length((stroke_value as Dictionary)["points"])
	if input_length <= 0.001:
		return true
	if _body_ink.is_empty():
		return false
	var core_length := 0.0
	for entry_value in _body_ink:
		var entry := entry_value as Dictionary
		var points: PackedVector2Array = entry["points"]
		if points.size() < 2:
			continue
		if not _polyline_lies_on_ink(points, strokes):
			return false
		var prefix := int(entry.get("overlap_prefix", 0))
		var suffix := int(entry.get("overlap_suffix", 0))
		var core := points.slice(prefix, points.size() - suffix)
		if core.size() >= 2:
			core_length += _stroke_length(core)
	return absf(core_length - input_length) <= input_length * INK_AUDIT_LENGTH_TOLERANCE


## A rendered polyline is always a slice of exactly one drawn stroke. Find that
## stroke with a few probe points, then require every vertex and every segment
## midpoint to sit on it (full-stroke fallback keeps overlapping strokes from
## producing false alarms).
func _polyline_lies_on_ink(points: PackedVector2Array, strokes: Array) -> bool:
	var candidate := PackedVector2Array()
	var candidate_score := INF
	var probe_count := mini(points.size(), 5)
	for stroke_value in strokes:
		var source: PackedVector2Array = (stroke_value as Dictionary)["points"]
		var score := 0.0
		for probe_index in range(probe_count):
			var probe := points[int(round(float(probe_index) * float(points.size() - 1) / float(maxi(1, probe_count - 1))))]
			score = maxf(score, _point_polyline_distance(probe, source))
			if score >= candidate_score:
				break
		if score < candidate_score:
			candidate_score = score
			candidate = source
	if candidate_score > INK_AUDIT_EPSILON:
		return false
	for index in range(points.size()):
		if not _point_near_ink(points[index], candidate, strokes):
			return false
		if index > 0 and not _point_near_ink((points[index - 1] + points[index]) * 0.5, candidate, strokes):
			return false
	return true


func _point_near_ink(point: Vector2, candidate: PackedVector2Array, strokes: Array) -> bool:
	if _point_polyline_distance(point, candidate) <= INK_AUDIT_EPSILON:
		return true
	for stroke_value in strokes:
		var source: PackedVector2Array = (stroke_value as Dictionary)["points"]
		if source != candidate and _point_polyline_distance(point, source) <= INK_AUDIT_EPSILON:
			return true
	return false
