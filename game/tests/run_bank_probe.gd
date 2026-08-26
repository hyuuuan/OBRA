extends SceneTree
## Walk the level and report which obstacle the director sees at each standable x, so a
## beat whose solving position sits outside its own volume is visible rather than silent.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := (load("res://game_level.tscn") as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await create_timer(1.5, true).timeout

	var director = level.get("director")
	var player := level.get("player") as Node2D

	for node in level.get_tree().get_nodes_in_group(&"level_obstacles"):
		var area := node as LevelObstacle2D
		var half: float = area.trigger_size.x * 0.5
		print("VOLUME %-10s x %.0f .. %.0f" % [area.obstacle_id,
			area.global_position.x - half, area.global_position.x + half])

	var last := "?"
	var x := 240.0
	while x < 3900.0:
		player.global_position = Vector2(x, -40.0)
		for _f in range(10):
			await physics_frame
		var here: String = director.current_obstacle()
		if here != last:
			print("  x %4d  ->  '%s'" % [int(x), here])
			last = here
		x += 20.0

	print("OBRA_BANK_PROBE_DONE")
	quit()
