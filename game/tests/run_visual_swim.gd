extends SceneTree
## View all supplied swim frames, then capture real swimming input in Dagat.
## godot --path game --script res://tests/run_visual_swim.gd
## Saves /tmp/obra_swim_*.png. Run alone; probes share isolated user data.

const FIGURE := preload("res://scripts/wanderer_figure.gd")
const WATER_POSES: Array[StringName] = [
	&"swim", &"swim_idle_side", &"swim_idle_front", &"swim_float"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.set_content_scale_size(Vector2i(1152, 648))
	var background := ColorRect.new()
	background.color = Color(0.08, 0.35, 0.48)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var figures: Array[Node2D] = []
	for row in range(5):
		var pose: StringName = &"swim" if row < 2 else WATER_POSES[row - 1]
		var count := 6 if row < 2 else 4
		for frame in range(count):
			var figure := Node2D.new()
			figure.set_script(FIGURE)
			figure.position = Vector2(95.0 + frame * 185.0, 125.0 + row * 115.0)
			figure.scale = Vector2(-1.0 if row == 1 else 1.0, 1.0)
			figure.set("pose", pose)
			figure.set("stride", (float(frame) + 0.01) / float(count))
			root.add_child(figure)
			figures.append(figure)
	await _shot("frames")
	for figure in figures:
		figure.queue_free()
	background.queue_free()
	await process_frame
	root.set_content_scale_size(Vector2i(1152, 648))
	var level := (load("res://level_3.tscn") as PackedScene).instantiate()
	level.get_node("BackendSupervisor").set("auto_start_backend", false)
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	# Action state alone is not an input event: let the opening finish its camera move.
	await create_timer(5.0).timeout
	for path in ["EnvironmentBaseplate/GameplayPlane/DialogueNode",
			"EnvironmentBaseplate/GameplayPlane/BakunawaNode"]:
		var fork := level.get_node_or_null(path)
		if fork != null:
			fork.process_mode = Node.PROCESS_MODE_DISABLED
	var player := level.get("player") as CharacterBody2D
	if player == null or not bool(player.get("can_swim")):
		push_error("Harness: Dagat must spawn the swimming apo")
		quit(1)
		return
	for action in [&"move_right", &"move_left", &"jump", &"move_down", &""]:
		player.global_position = Vector2(1850.0, 1400.0)
		player.velocity = Vector2.ZERO
		if action != &"":
			Input.action_press(action)
		await create_timer(0.8).timeout
		if not player.call("is_in_water"):
			push_error("Harness: screenshot player must be in Dagat's sea")
			quit(1)
			return
		var screen_point := player.get_global_transform_with_canvas().origin
		if not root.get_visible_rect().has_point(screen_point):
			push_error("Harness: swimming apo must be in the photographed viewport")
			quit(1)
			return
		await _shot("level3_%s" % (action if action != &"" else &"idle"))
		if action != &"":
			Input.action_release(action)
	print("OBRA_VISUAL_SWIM_DONE")
	quit()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/obra_swim_%s.png" % label)
