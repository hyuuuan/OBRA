extends SceneTree
## Renders a creature standing idle so limb tension (vs dead-bone collapse) is
## visible. Run without --headless. OBRA_ENTITY selects the creature.

const OUTPUT_DIR := "/tmp"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var entity_id := OS.get_environment("OBRA_ENTITY")
	if entity_id.is_empty():
		entity_id = "humanoid"
	var packed := load("res://game_level.tscn") as PackedScene
	var level := packed.instantiate()
	var supervisor := level.get_node("BackendSupervisor") as BackendSupervisor
	supervisor.auto_start_backend = false
	supervisor.startup_timeout_sec = 0.01
	root.add_child(level)
	await process_frame
	await process_frame

	var panel := level.get_node("DrawPanel") as DrawPanel
	panel.open_panel()
	panel.set("_pending_strokes", _fixture_for(entity_id))
	level.get_node("InkManager").call("reserve_attempt", 1.0)
	panel.call("_on_entity_prediction", entity_id, entity_id.capitalize(), 0.99, _blank_image(), {})

	for _f in range(150):
		await physics_frame
	await _capture("obra_idle_%s.png" % entity_id)

	level.queue_free()
	await process_frame
	print("OBRA_IDLE_OK %s" % entity_id)
	quit(0)


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(OUTPUT_DIR.path_join(file_name))


func _blank_image() -> Image:
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return image


func _stroke(points: PackedVector2Array) -> Dictionary:
	return {"points": points, "width": 8.0, "color": Color.BLACK}


func _fixture_for(entity_id: String) -> Array:
	if entity_id == "humanoid":
		# Upright body with two arms out and two legs down, as drawn.
		var body := PackedVector2Array([
			Vector2(240, 150), Vector2(272, 150), Vector2(280, 220),
			Vector2(272, 285), Vector2(240, 285), Vector2(232, 220), Vector2(240, 150)
		])
		var strokes: Array = [_stroke(body)]
		strokes.append(_stroke(PackedVector2Array([Vector2(240, 180), Vector2(200, 210), Vector2(176, 250)])))  # left arm
		strokes.append(_stroke(PackedVector2Array([Vector2(272, 180), Vector2(312, 210), Vector2(336, 250)])))  # right arm
		strokes.append(_stroke(PackedVector2Array([Vector2(248, 285), Vector2(244, 330), Vector2(240, 372)])))  # left leg
		strokes.append(_stroke(PackedVector2Array([Vector2(264, 285), Vector2(268, 330), Vector2(272, 372)])))  # right leg
		return strokes
	var strokes: Array = [_stroke(_closed_body())]
	var limb_count := 8 if entity_id == "spider" else 4
	for index in range(limb_count):
		var angle := TAU * float(index) / float(limb_count)
		var start := Vector2(256.0, 256.0) + Vector2(cos(angle) * 58.0, sin(angle) * 38.0)
		var mid := start + Vector2(cos(angle) * 42.0, sin(angle) * 42.0)
		var tip := mid + Vector2(cos(angle) * 34.0, sin(angle) * 34.0)
		strokes.append(_stroke(PackedVector2Array([start, mid, tip])))
	return strokes


func _closed_body() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for index in range(9):
		var a := TAU * float(index) / 8.0
		pts.append(Vector2(256.0, 250.0) + Vector2(cos(a) * 58.0, sin(a) * 54.0))
	return pts
