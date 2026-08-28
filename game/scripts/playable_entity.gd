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
## One visual environment per water source, for the same reason body overlap counts are
## additive: a long vector creature can straddle more than one Area2D at once.
var _underwater_sources: Dictionary = {}


## A DRAWN CREATURE IS THE PLAYER, AND NOTHING IN THE WORLD KNEW IT.
##
## `player_character` is the group every trigger in the game asks -- checkpoints, obstacle
## volumes, the door of Ang Bale, the bulul, the room that decides whether to draw itself --
## and the wanderer was the only thing that had ever joined it. So the moment the apo became
## something she had drawn, the level stopped recognising her: she could walk through a
## checkpoint and it would not fire, stand in an obstacle and it would not arm, and the
## inside of the heap would go dark around her.
##
## The rig's bodies are children of this node, and every one of those triggers walks up the
## parent chain looking for a member -- so one membership here covers the whole creature.
func _ready() -> void:
	add_to_group(&"player_character")


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
	# NOT _follow_anchor here. Until the first physics step this node's transform is still
	# the frame the DRAWING was authored in, and that is the reference the ink-fidelity check
	# measures the rendered strokes against (run_tests, "renders its first frame N px off the
	# drawing"). Moving it on the way out of apply_drawing would move the ruler. From the
	# first physics frame the root means "where the creature is", which is what every caller
	# outside the rig actually asks it for.
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
	# AND THE ROOT GOES WITH THEM. See _follow_anchor: the rig bodies are top_level, so
	# moving them leaves this node behind at whatever position it was created at.
	global_position = target
	var inherited_velocity := Vector2(state.get("linear_velocity", Vector2.ZERO))
	if not _vector_is_finite(inherited_velocity):
		inherited_velocity = Vector2.ZERO
	var skin := _get_skin()
	# ⚠ THROUGH THE RIG, NOT BY WRITING POSITIONS. This used to set `global_position` on each
	# live RigidBody2D, which the physics server overwrites the same frame -- trap 7. Over the
	# handful of pixels between one morph and the next it survived long enough to look like it
	# worked; over the two thousand units into a room it did nothing at all, so pressing down
	# at the straw heap as an ant moved nobody and the door into Ang Bale was the same.
	# `translate_rig` freezes the whole graph first, which is the only thing that works.
	if skin != null and skin.has_method("translate_rig"):
		skin.call("translate_rig", offset, inherited_velocity.limit_length(520.0))
	elif skin != null and skin.has_method("get_rigid_bodies"):
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


## The same contract the wanderer answers, so a utility pushes "the player" without
## caring which of the two it is. A drawn creature is a whole rig, so the force goes
## to every body: pushing only the torso drags a creature out of its own drawing.
func apply_external_force(acceleration: Vector2) -> void:
	_rig_force(acceleration)


func apply_external_impulse(velocity_change: Vector2) -> void:
	_rig_impulse(velocity_change)


func limit_fall_speed(limit: float) -> void:
	for candidate in _drive_targets():
		var body := candidate as RigidBody2D
		if body != null and is_instance_valid(body) and body.linear_velocity.y > limit:
			body.linear_velocity.y = limit


func is_in_water() -> bool:
	var skin := _get_skin()
	return skin != null and skin.has_method("is_in_water") and bool(skin.call("is_in_water"))


func set_underwater_appearance(
	source_id: int,
	active: bool,
	surface_y: float,
	bottom_y: float,
	shallow: Color,
	deep: Color,
	highlight: Color
) -> void:
	if active:
		_underwater_sources[source_id] = {
			"surface_y": surface_y,
			"bottom_y": bottom_y,
			"shallow": shallow,
			"deep": deep,
			"highlight": highlight,
		}
	else:
		_underwater_sources.erase(source_id)
	_apply_underwater_appearance()


func _apply_underwater_appearance() -> void:
	var skin := _get_skin()
	if skin == null or not skin.has_method("set_underwater_appearance"):
		return
	if _underwater_sources.is_empty():
		skin.call(&"set_underwater_appearance", false, 0.0, 1.0,
			Color.TRANSPARENT, Color.TRANSPARENT, Color.TRANSPARENT)
		return
	var environment: Dictionary = _underwater_sources.values()[0]
	skin.call(&"set_underwater_appearance", true,
		float(environment["surface_y"]), float(environment["bottom_y"]),
		environment["shallow"] as Color, environment["deep"] as Color,
		environment["highlight"] as Color)


func _physics_process(delta: float) -> void:
	var body := get_physics_anchor()
	if body == null:
		return
	var horizontal := Input.get_axis("move_left", "move_right")
	var vertical := Input.get_axis("move_up", "move_down")
	var entity_id := String(entity_metadata.get("id", ""))
	# Drive is selected by archetype rig_type; spider keeps its bespoke stance
	# controller. Species nuances (flutter/soar, slither/swim, bound/charge) come
	# from rig-profile flags, so new creatures move through the generic gait
	# without an entity_id branch.
	var rig_type := String(rig_profile.get("rig_type", entity_metadata.get("rig_type", "")))
	var state := "idle"
	var moving := absf(horizontal) > 0.05 or absf(vertical) > 0.05

	if _ladder != null and is_instance_valid(_ladder):
		state = _drive_ladder(body, vertical)
	elif entity_id == "spider":
		state = _drive_spider(body, horizontal, vertical)
	elif rig_type == "flier":
		state = _drive_flier(body, horizontal, delta, String(rig_profile.get("flight_style", "")) == "flutter")
	elif rig_type == "swimmer":
		if String(rig_profile.get("swim_style", "")) == "slither":
			state = _drive_snake(body, Vector2(horizontal, vertical))
		else:
			state = _drive_fish(body, Vector2(horizontal, vertical))
	elif rig_type == "hopper":
		state = _drive_hopper(body, horizontal, delta, String(rig_profile.get("hop_style", "")) == "bound")
	else:
		state = _drive_grounded(body, horizontal)

	if _umbrella_open and body.linear_velocity.y > 130.0:
		var excess := body.linear_velocity.y - 130.0
		_rig_force(Vector2(0.0, -excess * 5.5))

	# The dedicated spider stance controller owns torso attitude. Applying the
	# generic root servo as well makes the two controllers fight each other and
	# was a major source of the old rolling/locked-body behaviour.
	if entity_id != "spider":
		_apply_balance(body, rig_type)
	var max_speed := maxf(1.0, _profile_float("move_speed", _default_speed(entity_id)))
	set_rig_state(state, {
		"direction": horizontal,
		"moving": moving,
		"speed_ratio": clampf(body.linear_velocity.length() / max_speed, 0.0, 1.5),
		"charge_ratio": clampf(_charge / maxf(0.01, _profile_float("charge_time", 0.8)), 0.0, 1.0),
		"vertical_speed": body.linear_velocity.y
	})
	# BEFORE the camera anchor, which is a plain child and would otherwise be dragged by
	# the move this line makes -- _update_camera_anchor writes its global position outright,
	# so it has to run second.
	_follow_anchor()
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
	var skin := _get_skin()
	var contacts: Dictionary = {}
	var has_contact_summary := false
	if skin != null and skin.has_method("get_contact_summary"):
		var summary_value: Variant = skin.call("get_contact_summary")
		if summary_value is Dictionary:
			contacts = summary_value
			has_contact_summary = true

	var feet_value: Variant = contacts.get("feet", [])
	var has_terminal_feet := feet_value is Array and not (feet_value as Array).is_empty()
	# A valid spider is grounded exclusively by terminal feet. The body flags are
	# retained only for a legacy/malformed compound-rig fallback with no feet.
	var grounded := bool(contacts.get("grounded", body.grounded))
	if not has_terminal_feet:
		grounded = body.grounded
	var wall_contact := bool(contacts.get("wall_contact", body.wall_contact))
	var ceiling_contact := bool(contacts.get("ceiling_contact", body.ceiling_contact))
	var surface_normal := body.dominant_surface_normal
	var normal_value: Variant = contacts.get("dominant_surface_normal", surface_normal)
	if normal_value is Vector2:
		surface_normal = normal_value

	# Normal gravity remains enabled in every mode. Stance support and adhesion are
	# forces, not gravity cancellation or direct transform writes.
	_set_rig_gravity(1.0)
	if Input.is_action_just_pressed("jump") and (grounded or wall_contact):
		if skin != null and skin.has_method("release_stance"):
			skin.call("release_stance")
		var jump_horizontal := _profile_float("jump_horizontal_impulse", 90.0)
		var jump_impulse := _profile_float("jump_impulse", 300.0)
		_rig_impulse(Vector2(horizontal * jump_horizontal, -jump_impulse))
		return "jump"

	if (wall_contact or ceiling_contact) and absf(vertical) > 0.05:
		if skin != null and skin.has_method("release_stance"):
			skin.call("release_stance")
		var climb_speed := _profile_float("climb_speed", 155.0)
		var climb_gain := _profile_float("climb_velocity_gain", 12.0)
		var climb_force := _profile_float("climb_force", 1850.0)
		var climb_error := vertical * climb_speed - body.linear_velocity.y
		_apply_spider_torso_acceleration(
			skin,
			body,
			Vector2(0.0, clampf(climb_error * climb_gain, -climb_force, climb_force))
		)
		if surface_normal.length_squared() > 0.01:
			var adhesion := _profile_float("climb_adhesion_force", 520.0)
			_apply_spider_torso_acceleration(skin, body, -surface_normal.normalized() * adhesion)
			if skin != null and skin.has_method("apply_spider_surface_attitude"):
				skin.call("apply_spider_surface_attitude", surface_normal)
		return "climb"

	var move_speed := _profile_float("move_speed", _default_speed("spider"))
	if not grounded:
		# A modest torso force provides air correction while no foot is planted.
		# Ground propulsion remains exclusively owned by the stance controller.
		var air_control := clampf(_profile_float("air_control", 0.22), 0.0, 1.0)
		if absf(horizontal) > 0.05 and air_control > 0.0:
			var air_error := horizontal * move_speed - body.linear_velocity.x
			var air_accel := clampf(air_error * 6.0 * air_control, -420.0, 420.0)
			_apply_spider_torso_acceleration(skin, body, Vector2(air_accel, 0.0))
		return "jump" if body.linear_velocity.y < 0.0 else "fall"

	# A safe compound fallback has no terminal feet or active stance controller.
	# Drive its torso only; never reinstate the old whole-rig dragging path.
	if (not has_contact_summary or not has_terminal_feet) and absf(horizontal) > 0.05:
		var target_speed := horizontal * move_speed
		var move_accel := _profile_float("move_acceleration", 1350.0)
		var torso_accel := clampf((target_speed - body.linear_velocity.x) * 6.0, -move_accel, move_accel)
		body.apply_central_force(Vector2(torso_accel * body.mass, 0.0))
	return "walk" if absf(horizontal) > 0.05 else "idle"


func _apply_spider_torso_acceleration(skin: Node, body: ActiveRigBody2D, acceleration: Vector2) -> void:
	if skin != null and skin.has_method("apply_spider_torso_acceleration"):
		skin.call("apply_spider_torso_acceleration", acceleration)
	elif is_instance_valid(body):
		body.apply_central_force(acceleration * body.mass)


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
		# Full weight, and let the water do the rest. Zeroing gravity here pinned the fish
		# to whatever depth it entered at; hand-picking a small value fought the buoyancy
		# instead of using it. At its own weight against the pool's lift it sinks from the
		# surface and settles a little under halfway down, and a held direction takes it
		# anywhere from there -- which is a fish, rather than a sprite on the surface.
		_set_rig_gravity(1.0)
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


func _apply_balance(body: ActiveRigBody2D, rig_type: String) -> void:
	if rig_type == "swimmer" or (rig_type == "flier" and not body.grounded):
		return
	var target_rotation := 0.0
	if _ladder != null and is_instance_valid(_ladder):
		target_rotation = _ladder.global_rotation
	# Right the torso only. The muscle controller already owns the limbs' angles;
	# torquing every body toward upright fought the gait and curled the creature
	# into a rollable ball. A strong torso-only righting spring keeps the root
	# upright and the joints carry the limbs along.
	var error := wrapf(target_rotation - body.rotation, -PI, PI)
	# The torso is the reference frame for every rest-relative joint. If it rolls,
	# the muscle system faithfully carries the complete anatomy into that roll.
	# Use a critically damped, mass-scaled root servo with enough authority to
	# resist the summed limb reactions, while retaining a hard cap.
	var torque_limit := body.mass * 4400.0
	var balance_spring := 3000.0
	var balance_damping := 360.0
	var torque := clampf(error * body.mass * balance_spring - body.angular_velocity * body.mass * balance_damping, -torque_limit, torque_limit)
	body.apply_torque(torque)


func _ensure_camera_anchor() -> void:
	if _camera_anchor != null and is_instance_valid(_camera_anchor):
		return
	_camera_anchor = Marker2D.new()
	_camera_anchor.name = "StableCameraAnchor"
	add_child(_camera_anchor)


## KEEP THE SCENE ROOT WHERE THE CREATURE ACTUALLY IS.
##
## This node is "only a lifetime container" (see the class doc) and for a long time it was
## treated as one: the level created it at the SPAWN POINT, the rig was built there, and
## `_apply_morph_state_now` then carried the creature to where the player was standing by
## offsetting the rig bodies -- which are `top_level`, so the root never moved. Every drawn
## creature in the game therefore reported `global_position` of (spawn point), for its whole
## life, no matter where on the map it was.
##
## Nine callers ask that question, and the expensive ones are the rooms: `_room_holding_player`
## tests this position against each interior's bounds, so a morph inside the straw heap or
## inside Ang Bale read as standing down in the valley. The camera dropped back to level
## framing and clamped itself a thousand units below the room, the room stopped drawing
## itself, and the box a placement may not leave was cleared -- which is the whole of
## "drawing something inside a small world breaks the game".
##
## Writing the root's position is safe precisely BECAUSE the bodies are top_level: nothing
## in the rig rides this transform. The ink lines hang off the primary body (RuntimeRig2D),
## and the camera anchor's global position is assigned outright every frame.
func _follow_anchor() -> void:
	var body := get_physics_anchor()
	if body == null:
		return
	var at := body.global_position
	if not _vector_is_finite(at):
		return
	global_position = at


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
