extends SceneTree
## Real-renderer diagnostic for the complete prediction -> spider path.
## Run without --headless so viewport captures include the actual world.

const OUTPUT_DIR := "/tmp"

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
	if OS.get_environment("OBRA_HIDE_RIG") == "1":
		for body in skin.get_rigid_bodies():
			body.visible = false
	await _capture("obra_spider_spawn.png")

	Input.action_press("move_right")
	for frame in range(240):
		if frame == 70:
			Input.action_press("jump")
		if frame == 72:
			Input.action_release("jump")
		if frame in [40, 70, 100, 130, 180, 230]:
			await _capture("obra_spider_walk_%03d.png" % frame)
		await physics_frame
	Input.action_release("move_right")
	for _frame in range(120):
		await physics_frame
	await _capture("obra_spider_settled.png")
	print("VISUAL_RIG_METRICS recoveries=%d joint_error=%.3f body_distance=%.3f" % [
		skin.debug_recovery_count(), skin.debug_max_joint_error(), skin.debug_max_body_distance()
	])
	if skin.debug_recovery_count() != 0 or skin.debug_max_joint_error() > 1.0:
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
	var body := PackedVector2Array([
		Vector2(198, 220), Vector2(230, 196), Vector2(282, 196),
		Vector2(314, 220), Vector2(314, 278), Vector2(282, 304),
		Vector2(230, 304), Vector2(198, 278), Vector2(198, 220)
	])
	var strokes: Array = [{"points": body, "width": 8.0, "color": Color.BLACK}]
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var start := Vector2(256, 250) + Vector2(cos(angle) * 56.0, sin(angle) * 42.0)
		var knee := start + Vector2(cos(angle) * 62.0, sin(angle) * 48.0 + (12.0 if index % 2 == 0 else -12.0))
		var tip := knee + Vector2(cos(angle) * 44.0, sin(angle) * 38.0)
		strokes.append({"points": PackedVector2Array([start, knee, tip]), "width": 8.0, "color": Color.BLACK})
	return strokes
