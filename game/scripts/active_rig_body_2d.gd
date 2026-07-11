class_name ActiveRigBody2D
extends RigidBody2D
## Contact-aware body used by generated rigs. It keeps direct-state reads in the
## physics callback and rejects runaway/non-finite velocities before they can
## destabilize the rest of a joint chain.

var grounded: bool = false
var wall_contact: bool = false
var ceiling_contact: bool = false
## Set by RuntimeRig2D on the primary body: true while the virtual-leg support is
## holding the creature standing. The torso itself never touches the ground once
## it is held up on its legs, so without this the controller would read the whole
## creature as permanently airborne (stuck in "fall": raised arms, no walk gait).
var standing_hint: bool = false
var dominant_surface_normal: Vector2 = Vector2.UP
var contact_points: Array[Vector2] = []
var max_linear_speed: float = 580.0
var max_angular_speed: float = 8.0
var last_safe_transform: Transform2D = Transform2D.IDENTITY


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 16
	can_sleep = false
	# Shape-cast CCD on every one of the (up to 24) rig bodies is what pushed the
	# 120 Hz solver past its real-time budget and dropped physics into slow motion.
	# Ray-cast CCD still stops the torso tunnelling through the floor for a small
	# fraction of the cost; the recovery pass handles any rare limb pass-through.
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	last_safe_transform = global_transform


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	grounded = false
	wall_contact = false
	ceiling_contact = false
	dominant_surface_normal = Vector2.UP
	contact_points.clear()
	var best_up := -1.0
	for index in range(state.get_contact_count()):
		# get_contact_local_normal already returns the contact normal in WORLD
		# space. The old code rotated it again by the body's own rotation, which
		# corrupted every contact on a rotated body: a leg lying flat on the floor
		# at 60-70 degrees reported up_dot ~0.31 and failed the >0.42 grounded gate,
		# so feet never registered ground, walk/jump/gait state never engaged, and
		# the spider's climb/balance surface normal was garbage.
		var normal := state.get_contact_local_normal(index)
		var point := state.get_contact_collider_position(index)
		contact_points.append(point)
		var up_dot := normal.dot(Vector2.UP)
		if up_dot > 0.42:
			grounded = true
		if up_dot < -0.42:
			ceiling_contact = true
		if absf(normal.x) > 0.55:
			wall_contact = true
		if up_dot > best_up:
			best_up = up_dot
			dominant_surface_normal = normal

	# The held-up torso has no ground contact of its own; treat an actively
	# supported creature as grounded so idle/walk/jump logic engages.
	if standing_hint:
		grounded = true

	var linear := state.linear_velocity
	var angular := state.angular_velocity
	if not _transform_is_finite(state.transform) or not is_finite(linear.x) or not is_finite(linear.y) or not is_finite(angular):
		state.transform = last_safe_transform
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		return
	if linear.length() > max_linear_speed:
		state.linear_velocity = linear.normalized() * max_linear_speed
	state.angular_velocity = clampf(angular, -max_angular_speed, max_angular_speed)
	if _transform_is_finite(state.transform) and absf(state.transform.origin.x) < 10000.0 and absf(state.transform.origin.y) < 10000.0:
		last_safe_transform = state.transform


func _transform_is_finite(value: Transform2D) -> bool:
	return is_finite(value.x.x) and is_finite(value.x.y) \
		and is_finite(value.y.x) and is_finite(value.y.y) \
		and is_finite(value.origin.x) and is_finite(value.origin.y)
