extends SceneTree
## Non-destructive terrain tour; real viewport required. No profile writes or submissions.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var level: Node = load("res://game_level.tscn").instantiate()
	level.get_node("BackendSupervisor").auto_start_backend = false
	root.add_child(level)
	call_group(&"dialogue_box", &"set_auto_dismiss", true)
	await create_timer(0.5, true).timeout
	paused = false
	level.set_physics_process(false)
	level.get("player").set_physics_process(false)
	for path in ["CanvasLayer", "DialogueLayer"]:
		level.get_node(path).visible = false
	var camera := level.get_node("EnvironmentBaseplate/WorldCamera") as Camera2D
	camera.set_script(null)
	camera.position_smoothing_enabled = false
	camera.zoom = Vector2.ONE
	for shot in [{"name": "gorge", "at": Vector2(3230, 280)},
		{"name": "hay", "at": Vector2(3960, 280)},
		{"name": "stairs", "at": Vector2(1230, 430)}]:
		camera.global_position = shot.at - Vector2(0, 70)
		level.get_node("EnvironmentBaseplate").call("_on_camera_moved", camera.global_position)
		camera.force_update_scroll()
		await create_timer(0.4, true).timeout
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/obra_terrain_%s.png" % shot.name)
	print("OBRA_TERRAIN_TOUR_DONE")
	quit()
