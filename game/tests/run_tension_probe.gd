extends SceneTree
## Measures whether limbs hold tension: spawns each creature, lets it settle idle
## (no input), and reports how far the torso stays above the floor and the rig's
## vertical span. Collapsed "dead bone" limbs let the torso sink onto the floor
## and flatten the rig.

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
	var floor_body := level.get_node("EnvironmentBaseplate/GameplayPlane/Floor") as StaticBody2D
	var cs := floor_body.get_node("CollisionShape2D") as CollisionShape2D
	var floor_top: float = floor_body.global_position.y - (cs.shape as RectangleShape2D).size.y * 0.5

	for entity_id in ["humanoid", "spider", "cat", "frog"]:
		await _probe(level, entity_id, floor_top)

	level.queue_free()
	await process_frame
	quit(0)


func _probe(level: Node, entity_id: String, floor_top: float) -> void:
	var registry := level.get_node("EntityRegistry") as EntityRegistry
	var instance := registry.instantiate_entity(entity_id) as Node2D
	level.get_node("EnvironmentBaseplate/GameplayPlane/EntityRoot").add_child(instance)
	instance.global_position = Vector2(920, 430)
	if instance.has_method("set_world_bounds"):
		instance.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1200.0))
	var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
	instance.call("apply_drawing", _blank_image(), _fixture_for(entity_id))
	var anchor := skin.get_primary_body()

	# Settle at rest, no input.
	for _f in range(160):
		await physics_frame

	var bodies := skin.get_rigid_bodies()
	var min_y := INF
	var max_y := -INF
	var min_x := INF
	var max_x := -INF
	for b in bodies:
		if not is_instance_valid(b):
			continue
		min_y = minf(min_y, b.global_position.y)
		max_y = maxf(max_y, b.global_position.y)
		min_x = minf(min_x, b.global_position.x)
		max_x = maxf(max_x, b.global_position.x)
	var torso_height := floor_top - anchor.global_position.y
	print("TENSION %-9s torso_tilt=%3.0f  v_span=%3.0f h_span=%3.0f  torso_above_floor=%.0f joints=%d recov=%d" % [
		entity_id, rad_to_deg(anchor.rotation), max_y - min_y, max_x - min_x, torso_height, skin.get_joint_count(), skin.debug_recovery_count()
	])
	instance.queue_free()
	await process_frame


func _blank_image() -> Image:
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return image


func _stroke(points: PackedVector2Array) -> Dictionary:
	return {"points": points, "width": 8.0, "color": Color.BLACK}


func _closed_body() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for index in range(9):
		var a := TAU * float(index) / 8.0
		pts.append(Vector2(256.0, 250.0) + Vector2(cos(a) * 58.0, sin(a) * 54.0))
	return pts


func _fixture_for(entity_id: String) -> Array:
	var strokes: Array = [_stroke(_closed_body())]
	var limb_count := 8 if entity_id == "spider" else 4
	for index in range(limb_count):
		var angle := TAU * float(index) / float(limb_count)
		var start := Vector2(256.0, 256.0) + Vector2(cos(angle) * 58.0, sin(angle) * 38.0)
		var mid := start + Vector2(cos(angle) * 42.0, sin(angle) * 42.0)
		var tip := mid + Vector2(cos(angle) * 34.0, sin(angle) * 34.0)
		strokes.append(_stroke(PackedVector2Array([start, mid, tip])))
	return strokes
