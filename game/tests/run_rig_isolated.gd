extends SceneTree
## Isolated physics harness: NO level terrain. One flat floor + one creature so
## the controller's real settle behavior is measurable without terrace confounds.
## The shipped tension probe spawns on terraces that can wedge a collapsed rig
## upright and hide the failure; this asserts each creature actually stands on
## flat ground. Exits non-zero if any creature collapses.

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for entity_id in ["humanoid", "spider", "cat", "frog"]:
		await _probe(entity_id, entity_id, _fixture_for(entity_id))
	# A stick figure (big round head on a thin body, arms, legs) is what players
	# actually draw; it must resolve to a standing figure, not a headless tangle.
	await _probe("humanoid", "stickman", _stick_fixture())
	print("OBRA_RIG_ISOLATED_%s" % ("FAILED" if _failed else "OK"))
	quit(1 if _failed else 0)


func _probe(entity_id: String, label: String, fixture: Array) -> void:
	var world := Node2D.new()
	root.add_child(world)

	var floor_top := 500.0
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(600, floor_top + 40)
	var fshape := RectangleShape2D.new()
	fshape.size = Vector2(4000, 80)
	var fcol := CollisionShape2D.new()
	fcol.shape = fshape
	floor_body.add_child(fcol)
	world.add_child(floor_body)

	var registry := EntityRegistry.new()
	var instance := registry.instantiate_entity(entity_id) as Node2D
	world.add_child(instance)
	instance.global_position = Vector2(600, floor_top - 150)
	if instance.has_method("set_world_bounds"):
		instance.call("set_world_bounds", Rect2(-2000, -2000, 8000, 4000))
	var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
	instance.call("apply_drawing", _blank_image(), fixture)
	var anchor := skin.get_primary_body()

	for _f in range(400):
		await physics_frame

	# A creature that stands (rather than pancaking onto its own body) keeps its
	# torso well above the floor, stays upright, and does not need runaway recovery.
	var torso_above := floor_top - anchor.global_position.y
	var tilt := absf(rad_to_deg(anchor.rotation))
	var recov := skin.debug_recovery_count()
	var stand_height := float(skin.get("_stand_height"))
	var ok := torso_above > stand_height * 0.6 and tilt < 30.0 and recov <= 1
	if not ok:
		_failed = true
	print("%-9s torso_above_floor=%3.0f (stand_height=%2.0f) tilt=%2.0f recov=%d  -> %s" % [
		label, torso_above, stand_height, tilt, recov, "STAND" if ok else "COLLAPSE"])
	instance.queue_free()
	world.queue_free()
	await process_frame


func _blank_image() -> Image:
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return image


func _stroke(points: PackedVector2Array) -> Dictionary:
	return {"points": points, "width": 8.0, "color": Color.BLACK}


func _stick_fixture() -> Array:
	# Big round head (closed loop) on a thin body line, plus arms and legs.
	var head := PackedVector2Array()
	for i in range(13):
		var a := TAU * float(i) / 12.0
		head.append(Vector2(256, 170) + Vector2(cos(a) * 40.0, sin(a) * 40.0))
	var strokes: Array = [_stroke(head)]
	strokes.append(_stroke(PackedVector2Array([Vector2(256, 210), Vector2(256, 258), Vector2(256, 306)])))
	strokes.append(_stroke(PackedVector2Array([Vector2(256, 232), Vector2(214, 250), Vector2(200, 284)])))
	strokes.append(_stroke(PackedVector2Array([Vector2(256, 232), Vector2(300, 250), Vector2(316, 236)])))
	strokes.append(_stroke(PackedVector2Array([Vector2(256, 306), Vector2(236, 344), Vector2(228, 384)])))
	strokes.append(_stroke(PackedVector2Array([Vector2(256, 306), Vector2(276, 344), Vector2(284, 384)])))
	return strokes


func _fixture_for(entity_id: String) -> Array:
	if entity_id == "humanoid":
		var body := PackedVector2Array([
			Vector2(240, 150), Vector2(272, 150), Vector2(280, 220),
			Vector2(272, 285), Vector2(240, 285), Vector2(232, 220), Vector2(240, 150)
		])
		var strokes: Array = [_stroke(body)]
		strokes.append(_stroke(PackedVector2Array([Vector2(240, 180), Vector2(200, 210), Vector2(176, 250)])))
		strokes.append(_stroke(PackedVector2Array([Vector2(272, 180), Vector2(312, 210), Vector2(336, 250)])))
		strokes.append(_stroke(PackedVector2Array([Vector2(248, 285), Vector2(244, 330), Vector2(240, 372)])))
		strokes.append(_stroke(PackedVector2Array([Vector2(264, 285), Vector2(268, 330), Vector2(272, 372)])))
		return strokes
	var body := PackedVector2Array([
		Vector2(198, 220), Vector2(230, 196), Vector2(282, 196),
		Vector2(314, 220), Vector2(314, 278), Vector2(282, 304),
		Vector2(230, 304), Vector2(198, 278), Vector2(198, 220)
	])
	var strokes: Array = [_stroke(body)]
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var start := Vector2(256, 250) + Vector2(cos(angle) * 56.0, sin(angle) * 42.0)
		var knee := start + Vector2(cos(angle) * 62.0, sin(angle) * 48.0 + (12.0 if index % 2 == 0 else -12.0))
		var tip := knee + Vector2(cos(angle) * 44.0, sin(angle) * 38.0)
		strokes.append(_stroke(PackedVector2Array([start, knee, tip])))
	return strokes
