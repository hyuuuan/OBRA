extends SceneTree
## Replays realistic freehand stroke fixtures (game/tests/fixtures/*.json) and reports
## rig stats, so limb detection and animation can be measured on messy input rather than
## only clean synthetic fixtures.
## Run: godot --headless --path game --script res://tests/rig_probe.gd

var world: Node2D
var registry: EntityRegistry
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = Node2D.new()
	world.name = "ProbeWorld"
	root.add_child(world)
	_add_floor()
	registry = EntityRegistry.new()
	world.add_child(registry)
	registry.load_manifest()

	var dir := DirAccess.open("res://tests/fixtures")
	if dir == null:
		print("RIG_PROBE_NO_FIXTURES")
		quit(1)
		return
	var names := dir.get_files()
	names.sort()
	for file_name in names:
		if file_name.ends_with(".json"):
			await _probe_fixture("res://tests/fixtures/" + file_name)

	if failures == 0:
		print("RIG_PROBE_OK")
		quit(0)
	else:
		print("RIG_PROBE_FAILED=%d" % failures)
		quit(1)


func _probe_fixture(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		print("RIG_PROBE %s PARSE_ERROR" % path.get_file())
		failures += 1
		return
	var label := String(data.get("description", path.get_file()))
	var entity_id := String(data.get("entity_id", "pig"))
	var strokes := _strokes_from_json(data.get("strokes", []))
	var states: Array = data.get("states", ["walk", "idle"])

	var instance := registry.instantiate_entity(entity_id) as Node2D
	if instance == null:
		print("RIG_PROBE %s NO_ENTITY(%s)" % [label, entity_id])
		failures += 1
		return
	world.add_child(instance)
	instance.global_position = Vector2(300.0, 200.0)
	if instance.has_method("set_world_bounds"):
		instance.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1200.0))
	instance.call("apply_drawing", _blank_image(), strokes)
	var skin := instance.get_node("DrawingSkin") as RuntimeRig2D

	var mode := skin.skin_mode()
	var joints := skin.get_joint_count()
	var roles := skin.debug_segment_roles()

	# Per-state: does any joint receive a nonzero drive torque (i.e. it animates)?
	instance.set_physics_process(false)
	var state_report := ""
	var any_animates := false
	for state in states:
		skin.set_motion_state(String(state), {"moving": true, "speed_ratio": 1.0, "direction": 1.0, "charge_ratio": 1.0})
		skin._physics_process(0.1)
		var animated := false
		for torque in skin.debug_drive_torques():
			if absf(torque) > 0.01:
				animated = true
				break
		any_animates = any_animates or animated
		state_report += " %s=%s" % [state, "ANIM" if animated else "STILL"]

	# Stress the primary state to confirm the rig stays stable.
	var primary_state := String(states[0]) if not states.is_empty() else "walk"
	var max_err := 0.0
	for _frame in range(120):
		skin.set_motion_state(primary_state, {"moving": true, "speed_ratio": 1.0, "direction": 1.0})
		await physics_frame
		max_err = maxf(max_err, skin.debug_max_joint_error())

	print("RIG_PROBE %s | mode=%s joints=%d bodies=%d roles=%s |%s | maxerr=%.1f recov=%d" % [
		label, mode, joints, skin.get_rigid_bodies().size(), str(roles),
		state_report, max_err, skin.debug_recovery_count()
	])

	# A vector-mode drawing that produced no joints, or one that never animates, is a
	# failure of the pipeline we are hardening here.
	if mode == "vector" and joints == 0:
		print("  -> FAIL: vector drawing produced no articulation")
		failures += 1
	elif joints > 0 and not any_animates:
		print("  -> FAIL: articulated rig never animates in any state")
		failures += 1
	elif max_err > 22.5:
		print("  -> FAIL: rig unstable (joint error %.1f)" % max_err)
		failures += 1

	instance.queue_free()
	await process_frame


func _strokes_from_json(raw: Array) -> Array:
	var strokes: Array = []
	for stroke_value in raw:
		var stroke: Dictionary = stroke_value
		var points := PackedVector2Array()
		for pair in stroke.get("points", []):
			points.append(Vector2(float(pair[0]), float(pair[1])))
		var color := Color.BLACK
		if stroke.has("color"):
			var channels: Array = stroke["color"]
			color = Color(float(channels[0]), float(channels[1]), float(channels[2]),
				float(channels[3]) if channels.size() > 3 else 1.0)
		strokes.append({"points": points, "width": float(stroke.get("width", 8.0)), "color": color})
	return strokes


func _blank_image() -> Image:
	var image := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return image


func _add_floor() -> void:
	var floor := StaticBody2D.new()
	floor.position = Vector2(500.0, 420.0)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1000.0, 40.0)
	collision.shape = shape
	floor.add_child(collision)
	world.add_child(floor)
