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
	var base_contract := level.get_node_or_null("CanvasLayer/InventoryHUD") != null \
		and level.get_node_or_null("EnvironmentBaseplate/GameplayPlane/WorldItemRoot") != null \
		and level.get_node_or_null("DrawPanel") != null
	var drawing := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	drawing.fill(Color.WHITE)
	var draw_panel := level.get_node("DrawPanel") as DrawPanel
	draw_panel.open_panel()
	draw_panel.set("_pending_strokes", _spider_fixture())
	level.get_node("InkManager").call("reserve_attempt", 1.0)
	# Exercise the actual prediction callback: it must remove the gray scrim,
	# unpause, and only then hand the drawing to the level for rig construction.
	draw_panel.call("_on_entity_prediction", "spider", "Spider", 0.99, drawing, {})
	var spawned: bool = level.get("player") != null
	for _frame in range(180):
		await physics_frame
	var player := level.get("player") as Node2D
	var camera := level.get_node("EnvironmentBaseplate/WorldCamera") as WorldCameraController
	var skin := player.get_node_or_null("DrawingSkin") as RuntimeRig2D if player != null else null
	var camera_position := camera.global_position
	var morph_contract := spawned and player != null and skin != null \
		and camera.target != null and camera.target.name == "StableCameraAnchor" \
		and is_finite(camera_position.x) and is_finite(camera_position.y) \
		and skin.debug_max_joint_error() <= 22.5 \
		and skin.debug_recovery_count() <= 1 \
		and not bool(draw_panel.visible) \
		and not paused
	var ok := base_contract and morph_contract
	level.queue_free()
	await process_frame
	if ok:
		print("OBRA_LEVEL_READY_OK")
		quit(0)
	else:
		push_error("Game level ready contract failed")
		quit(1)


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
