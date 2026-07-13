extends SceneTree
## Non-gating developer probe for the dedicated spider stance pipeline.
## godot --headless --path game --script res://tests/run_spider_probe.gd

const SpiderReferenceFixtures = preload("res://tests/spider_reference_fixtures.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node2D.new()
	world.name = "SpiderProbeWorld"
	root.add_child(world)
	_add_floor(world)

	var registry := EntityRegistry.new()
	world.add_child(registry)
	registry.load_manifest()
	var spider := registry.instantiate_entity("spider") as Node2D
	if spider == null:
		print("SPIDER_PROBE ERROR could not instantiate spider")
		await _finish(world)
		return
	world.add_child(spider)
	spider.global_position = Vector2(300.0, 360.0)
	spider.call("set_world_bounds", Rect2(-500.0, -1000.0, 3000.0, 2000.0))
	spider.call("apply_drawing", _blank_image(), SpiderReferenceFixtures.separate_legs())
	var skin := spider.get_node_or_null("DrawingSkin") as RuntimeRig2D
	var anchor := spider.call("get_physics_anchor") as ActiveRigBody2D
	if skin == null or anchor == null:
		print("SPIDER_PROBE ERROR missing runtime skin/torso")
		await _finish(world)
		return

	for action in ["move_left", "move_right", "move_up", "move_down", "jump"]:
		Input.action_release(action)
	_print_checkpoint("spawn", skin)
	for frame in range(1, 301):
		await physics_frame
		if frame in [30, 120, 300]:
			_print_checkpoint("frame_%03d" % frame, skin)
	var load_start := anchor.global_position
	anchor.apply_central_impulse(Vector2(0.0, 60.0) * anchor.mass)
	var load_max_tilt := 0.0
	for _load_frame in range(120):
		await physics_frame
		load_max_tilt = maxf(load_max_tilt, rad_to_deg(absf(wrapf(anchor.global_rotation, -PI, PI))))
	print("SPIDER_PROBE LOAD_120 displacement=%s max_tilt=%.2f contacts=%d support=%s" % [
		str(anchor.global_position - load_start), load_max_tilt,
		_contacting_feet(skin.get_contact_summary()), skin.get_contact_summary().get("support_active", false)
	])

	var walk_start := anchor.global_position
	var walk_max_tilt := 0.0
	var walk_max_vertical := 0.0
	var walk_max_tilt_frame := -1
	var walk_max_tilt_state: Dictionary = {}
	Input.action_release("jump")
	Input.action_press("move_right")
	for walk_frame in range(180):
		await physics_frame
		# Match the regression suite and gameplay controller's per-frame contact
		# inspection; contact sampling must not change locomotion behaviour.
		skin.get_contact_summary()
		var sampled_snapshot := skin.debug_spider_snapshot()
		var current_tilt := rad_to_deg(absf(wrapf(anchor.global_rotation, -PI, PI)))
		if current_tilt > walk_max_tilt:
			walk_max_tilt = current_tilt
			walk_max_tilt_frame = walk_frame
			walk_max_tilt_state = sampled_snapshot
		walk_max_vertical = maxf(walk_max_vertical, absf(anchor.global_position.y - walk_start.y))
	Input.action_release("move_right")
	var displacement := anchor.global_position - walk_start
	var contact := skin.get_contact_summary()
	print("SPIDER_PROBE RIGHT_180 displacement=%s grounded=%s contacting_feet=%d support=%s torso_contact=%s tilt_deg=%.2f max_tilt=%.2f@%d max_tilt_group=%s max_tilt_contacts=%d max_vertical=%.2f recoveries=%d joint_error=%.2f" % [
		str(displacement), contact.get("grounded", false), _contacting_feet(contact),
		contact.get("support_active", false), contact.get("torso_contact", false),
		rad_to_deg(absf(wrapf(anchor.global_rotation, -PI, PI))),
		walk_max_tilt, walk_max_tilt_frame, walk_max_tilt_state.get("stance_group", -1),
		_contacting_feet({"feet": walk_max_tilt_state.get("feet", [])}), walk_max_vertical,
		skin.debug_recovery_count(), skin.debug_max_joint_error()
	])
	var max_foot_state: Array[Dictionary] = []
	for foot_value in walk_max_tilt_state.get("feet", []):
		var foot := foot_value as Dictionary
		max_foot_state.append({
			"leg": foot.get("leg_index", -1), "group": foot.get("phase_group", -1),
			"stance": foot.get("stance", false), "contact": foot.get("contact", false),
			"target_deg": rad_to_deg(float(foot.get("target_angle", 0.0)))
		})
	print("SPIDER_PROBE MAX_TILT_FEET %s" % str(max_foot_state))
	_print_checkpoint("right_180", skin)

	spider.queue_free()
	await _finish(world)


func _print_checkpoint(label: String, skin: RuntimeRig2D) -> void:
	var snapshot := skin.debug_spider_snapshot()
	var contact := skin.get_contact_summary()
	var legs_report: Array[Dictionary] = []
	for leg_value in snapshot.get("legs", []):
		var leg: Dictionary = leg_value
		legs_report.append({
			"root": leg.get("root", Vector2.ZERO),
			"sole": leg.get("sole", Vector2.ZERO),
			"side": leg.get("side", 0),
			"rank": leg.get("side_rank", -1),
			"phase": leg.get("phase_group", -1),
			"support": leg.get("support_candidate", false),
			"bend": leg.get("bend_index", -1)
		})
	var anatomy := {
		"valid": snapshot.get("valid", false),
		"reason": snapshot.get("reason", ""),
		"torso_center": snapshot.get("torso_center", Vector2.ZERO),
		"torso_bounds": snapshot.get("torso_bounds", Rect2()),
		"support_height": snapshot.get("support_height", 0.0),
		"torso_clearance": snapshot.get("torso_clearance", 0.0),
		"stance_group": snapshot.get("stance_group", -1),
		"gait_phase": snapshot.get("gait_phase", 0.0),
		"legs": legs_report
	}
	var bodies: Array[Dictionary] = []
	for body_value in skin.get_rigid_bodies():
		var body := body_value as ActiveRigBody2D
		if body == null or not is_instance_valid(body):
			continue
		bodies.append({
			"name": String(body.name),
			"position": body.global_position,
			"velocity": body.linear_velocity,
			"rotation_deg": rad_to_deg(body.global_rotation),
			"grounded": body.grounded,
			"wall": body.wall_contact,
			"gravity": body.gravity_scale
		})
	print("SPIDER_PROBE %s ANATOMY %s" % [label, str(anatomy)])
	print("SPIDER_PROBE %s CONTACT %s" % [label, str(contact)])
	print("SPIDER_PROBE %s BODIES %s" % [label, str(bodies)])


func _contacting_feet(summary: Dictionary) -> int:
	var count := 0
	for foot_value in summary.get("feet", []):
		if foot_value is Dictionary and bool((foot_value as Dictionary).get("contact", false)):
			count += 1
	return count


func _add_floor(world: Node2D) -> void:
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(500.0, 420.0)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2000.0, 40.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	floor_body.add_child(collision)
	world.add_child(floor_body)


func _blank_image() -> Image:
	var image := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return image


func _finish(world: Node2D) -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump"]:
		Input.action_release(action)
	if is_instance_valid(world):
		world.queue_free()
	await process_frame
	print("SPIDER_PROBE_DONE")
	quit(0)
