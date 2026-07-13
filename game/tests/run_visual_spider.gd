extends SceneTree
## Real-renderer diagnostic for the complete prediction -> spider path.
## Run without --headless so viewport captures include the actual world.

const OUTPUT_DIR := "/tmp"
const SpiderReferenceFixtures = preload("res://tests/spider_reference_fixtures.gd")

var _visual_failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://game_level.tscn") as PackedScene
	var level := packed.instantiate()
	var supervisor := level.get_node("BackendSupervisor") as BackendSupervisor
	supervisor.auto_start_backend = false
	supervisor.startup_timeout_sec = 0.01
	root.add_child(level)
	await process_frame
	await process_frame

	var drawing := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	drawing.fill(Color.WHITE)
	var panel := level.get_node("DrawPanel") as DrawPanel
	panel.open_panel()
	panel.set("_pending_strokes", _spider_fixture())
	level.get_node("InkManager").call("reserve_attempt", 1.0)
	panel.call("_on_entity_prediction", "spider", "Spider", 0.99, drawing, {})
	var player := level.get("player") as Node2D
	var skin := player.get_node("DrawingSkin") as RuntimeRig2D
	var anchor := player.call("get_physics_anchor") as ActiveRigBody2D
	if OS.get_environment("OBRA_HIDE_RIG") == "1":
		for body in skin.get_rigid_bodies():
			body.visible = false
	await _capture("obra_spider_spawn.png")

	# Establish a real foot-supported idle before measuring locomotion. The first
	# movement pass deliberately never presses jump: a spider that only moves via
	# its jump impulse has failed this probe.
	Input.action_release("jump")
	for _settle_frame in range(180):
		await physics_frame
	await _capture("obra_spider_supported_idle.png")
	var idle_contacts := skin.get_contact_summary()
	var idle_snapshot := skin.debug_spider_snapshot()
	print("VISUAL_IDLE_METRICS grounded=%s support=%s torso_contact=%s contacts=%d clearance=%.1f" % [
		idle_contacts.get("grounded", false), idle_contacts.get("support_active", false),
		idle_contacts.get("torso_contact", false), _contacting_foot_count(idle_contacts),
		idle_snapshot.get("torso_clearance", 0.0)
	])
	if not bool(idle_contacts.get("grounded", false)) or not bool(idle_contacts.get("support_active", false)) or bool(idle_contacts.get("torso_contact", true)):
		_visual_failed = true
		push_error("Rendered spider never established real foot-only support")
	if float(idle_snapshot.get("torso_clearance", 0.0)) < float(idle_snapshot.get("support_height", 0.0)) * 0.6:
		_visual_failed = true
		push_error("Rendered spider torso remained below its load-bearing stance height")
	var walk_start := anchor.global_position if anchor != null else Vector2.ZERO
	Input.action_press("move_right")
	for frame in range(180):
		if frame in [0, 45, 90, 135, 179]:
			await _capture("obra_spider_no_jump_%03d.png" % frame)
		await physics_frame
	Input.action_release("move_right")
	var no_jump_distance := anchor.global_position.x - walk_start.x if anchor != null else 0.0
	if no_jump_distance < 90.0:
		_visual_failed = true
		push_error("Spider moved only %.1f px during the 180-frame no-jump walk" % no_jump_distance)

	# Jump is a separate transition so it cannot hide a broken grounded gait.
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	Input.action_release("jump")
	for jump_frame in range(120):
		if jump_frame in [0, 30, 60, 119]:
			await _capture("obra_spider_jump_%03d.png" % jump_frame)
		await physics_frame
	for _frame in range(120):
		await physics_frame
	await _capture("obra_spider_settled.png")
	var contacts := skin.get_contact_summary()
	var snapshot := skin.debug_spider_snapshot()
	print("VISUAL_RIG_METRICS distance=%.1f recoveries=%d joint_error=%.3f body_distance=%.3f grounded=%s support=%s clearance=%.1f" % [
		no_jump_distance, skin.debug_recovery_count(), skin.debug_max_joint_error(), skin.debug_max_body_distance(),
		contacts.get("grounded", false), contacts.get("support_active", false), snapshot.get("torso_clearance", 0.0)
	])
	if skin.debug_recovery_count() != 0 or skin.debug_max_joint_error() > 22.5:
		_visual_failed = true
		push_error("Rendered spider was not physically stable")

	level.queue_free()
	await process_frame
	if _visual_failed:
		quit(1)
	else:
		print("OBRA_VISUAL_SPIDER_OK")
		quit(0)


func _capture(file_name: String) -> void:
	if OS.get_environment("OBRA_NO_SCREENSHOTS") == "1":
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if _frame_is_corrupt(image):
		_visual_failed = true
		push_error("Rendered frame became black/gray: %s" % file_name)
	var error := image.save_png(OUTPUT_DIR.path_join(file_name))
	if error != OK:
		push_error("Could not save rendered frame %s: %s" % [file_name, error_string(error)])


func _frame_is_corrupt(image: Image) -> bool:
	var dark := 0
	var neutral_gray := 0
	var samples := 0
	for y in range(0, image.get_height(), 16):
		for x in range(0, image.get_width(), 16):
			var color := image.get_pixel(x, y)
			var maximum := maxf(color.r, maxf(color.g, color.b))
			var minimum := minf(color.r, minf(color.g, color.b))
			var brightness := (color.r + color.g + color.b) / 3.0
			if maximum < 0.07:
				dark += 1
			if maximum - minimum < 0.025 and brightness > 0.18 and brightness < 0.86:
				neutral_gray += 1
			samples += 1
	return samples > 0 and (float(dark) / samples > 0.12 or float(neutral_gray) / samples > 0.45)


func _spider_fixture() -> Array:
	return SpiderReferenceFixtures.separate_legs()


func _contacting_foot_count(summary: Dictionary) -> int:
	var count := 0
	for foot_value in summary.get("feet", []):
		if bool((foot_value as Dictionary).get("contact", false)):
			count += 1
	return count
