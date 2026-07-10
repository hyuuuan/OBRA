class_name ActiveRigBody2D
extends RigidBody2D
## Contact-aware body used by generated rigs. It keeps direct-state reads in the
## physics callback and rejects runaway/non-finite velocities before they can
## destabilize the rest of a joint chain.

var grounded: bool = false
var wall_contact: bool = false
var ceiling_contact: bool = false
var dominant_surface_normal: Vector2 = Vector2.UP
var contact_points: Array[Vector2] = []
var max_linear_speed: float = 900.0
var max_angular_speed: float = 18.0
var last_safe_transform: Transform2D = Transform2D.IDENTITY


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 16
	can_sleep = false
	last_safe_transform = global_transform


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	grounded = false
	wall_contact = false
	ceiling_contact = false
	dominant_surface_normal = Vector2.UP
	contact_points.clear()
	var best_up := -1.0
	for index in range(state.get_contact_count()):
		var normal := state.get_contact_local_normal(index).rotated(state.transform.get_rotation())
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

	var linear := state.linear_velocity
	var angular := state.angular_velocity
	if not is_finite(linear.x) or not is_finite(linear.y) or not is_finite(angular):
		state.transform = last_safe_transform
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		return
	if linear.length() > max_linear_speed:
		state.linear_velocity = linear.normalized() * max_linear_speed
	state.angular_velocity = clampf(angular, -max_angular_speed, max_angular_speed)
	if absf(state.transform.origin.x) < 100000.0 and absf(state.transform.origin.y) < 100000.0:
		last_safe_transform = state.transform

