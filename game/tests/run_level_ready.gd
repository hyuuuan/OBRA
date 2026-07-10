extends SceneTree
## Instantiates the real main scene without allowing backend process launch.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://game_level.tscn") as PackedScene
	if packed == null:
		push_error("Could not load game_level.tscn")
		quit(1)
		return
	var level := packed.instantiate()
	var supervisor := level.get_node("BackendSupervisor") as BackendSupervisor
	supervisor.auto_start_backend = false
	supervisor.startup_timeout_sec = 0.01
	root.add_child(level)
	await process_frame
	await process_frame
	var ok := level.get_node_or_null("CanvasLayer/InventoryHUD") != null \
		and level.get_node_or_null("EnvironmentBaseplate/GameplayPlane/WorldItemRoot") != null \
		and level.get_node_or_null("DrawPanel") != null
	level.queue_free()
	await process_frame
	if ok:
		print("OBRA_LEVEL_READY_OK")
		quit(0)
	else:
		push_error("Game level ready contract failed")
		quit(1)

