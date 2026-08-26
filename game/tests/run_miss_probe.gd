extends SceneTree
## What does the game say when a drawing does not fit? It used to say nothing.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := (load("res://game_level.tscn") as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await create_timer(1.5, true).timeout

	var director = level.get("director")
	var hint = level.get("hint_bar")
	var player := level.get("player") as Node2D

	# On the left bank, where you stand to reach the plank.
	player.global_position = Vector2(320.0, 500.0)
	for _f in range(20):
		await physics_frame
	print("standing on the bank at x=320 -> director sees '%s'" % director.current_obstacle())

	# Beat 0 sub1 wants Roll. A frog leaps.
	level.call("_judge_submission", "frog")
	await process_frame
	print("tier after one miss: %d" % director.hint_tier())
	print("hint bar says: %s" % hint.call("current_text"))

	level.call("_judge_submission", "clock")
	await process_frame
	print("unhintable class says: %s" % hint.call("current_text"))

	await create_timer(0.5, true).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/obra_miss.png")
	print("OBRA_MISS_PROBE_DONE")
	quit()
