extends SceneTree
## Renders a creature through its gait so the animation can be inspected by eye.
## Must run WITHOUT --headless so the viewport actually rasterises:
##   godot --path game --script res://tests/run_visual_gait.gd
## Frames land in /tmp/obra_gait_<entity>_<frame>.png

const OUTPUT_DIR := "/tmp"

var world: Node2D
var registry: EntityRegistry


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = Node2D.new()
	root.add_child(world)
	var camera := Camera2D.new()
	camera.position = Vector2(400.0, 380.0)
	camera.zoom = Vector2(1.6, 1.6)
	world.add_child(camera)
	camera.make_current()
	var background := ColorRect.new()
	background.size = Vector2(2000.0, 1400.0)
	background.position = Vector2(-600.0, -300.0)
	background.color = Color(0.97, 0.96, 0.92)
	background.z_index = -100
	world.add_child(background)
	_add_floor()
	registry = EntityRegistry.new()
	world.add_child(registry)
	registry.load_manifest()

	for entity_id in ["horse", "fish", "bird"]:
		await _capture_gait(entity_id)
	world.queue_free()
	await process_frame
	print("OBRA_VISUAL_GAIT_DONE")
	quit(0)


func _capture_gait(entity_id: String) -> void:
	var entry := registry.get_entity(entity_id)
	if entry.is_empty():
		return
	var state := _gait_for_rig(String(entry.get("rig_type", "")))
	var instance := registry.instantiate_entity(entity_id) as Node2D
	world.add_child(instance)
	instance.global_position = Vector2(400.0, 420.0)
	instance.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1200.0))
	instance.call("apply_drawing", _blank_image(), _fixture_for(entity_id))
	var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
	instance.set_physics_process(false)
	var params := {"moving": true, "speed_ratio": 1.0, "direction": 1.0}
	for frame in range(150):
		skin.set_motion_state(state, params)
		if frame in [0, 3, 8, 20, 60, 90, 120, 149]:
			await _capture("obra_gait_%s_%03d.png" % [entity_id, frame])
		await physics_frame
	instance.queue_free()
	await process_frame


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(OUTPUT_DIR.path_join(file_name))


func _add_floor() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0.0, 600.0)
	var collision := CollisionShape2D.new()
	var shape := WorldBoundaryShape2D.new()
	shape.normal = Vector2.UP
	collision.shape = shape
	floor_body.add_child(collision)
	world.add_child(floor_body)
	var visual := ColorRect.new()
	visual.size = Vector2(2000.0, 20.0)
	visual.position = Vector2(-600.0, 600.0)
	visual.color = Color(0.25, 0.3, 0.25)
	world.add_child(visual)


func _gait_for_rig(rig_type: String) -> String:
	match rig_type:
		"flier": return "fly"
		"swimmer": return "swim"
		"hopper": return "jump"
		_: return "walk"


func _blank_image() -> Image:
	var image := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return image


func _stroke(points: PackedVector2Array) -> Dictionary:
	return {"points": points, "width": 8.0, "color": Color.BLACK}


## Drawings shaped the way a player actually draws these animals, rather than
## limbs radiating in every direction.
func _fixture_for(entity_id: String) -> Array:
	var body := PackedVector2Array()
	for index in range(17):
		var angle := TAU * float(index) / 16.0
		body.append(Vector2(256.0 + cos(angle) * 70.0, 240.0 + sin(angle) * 38.0))
	var strokes: Array = [_stroke(body)]
	if entity_id == "fish":
		# Body plus a tail fin trailing behind it.
		strokes.append(_stroke(PackedVector2Array([
			Vector2(188.0, 240.0), Vector2(150.0, 214.0), Vector2(132.0, 240.0), Vector2(150.0, 266.0)
		])))
		return strokes
	if entity_id == "bird":
		# Body plus two wings sweeping out and slightly up.
		strokes.append(_stroke(PackedVector2Array([
			Vector2(240.0, 212.0), Vector2(206.0, 172.0), Vector2(170.0, 150.0)
		])))
		strokes.append(_stroke(PackedVector2Array([
			Vector2(276.0, 212.0), Vector2(310.0, 172.0), Vector2(346.0, 150.0)
		])))
		return strokes
	# Quadruped: four legs hanging down from the underside of the body.
	for offset in [-46.0, -16.0, 16.0, 46.0]:
		var hip := Vector2(256.0 + offset, 274.0)
		strokes.append(_stroke(PackedVector2Array([
			hip, hip + Vector2(0.0, 34.0), hip + Vector2(0.0, 68.0)
		])))
	return strokes
