extends SceneTree
## Nothing placed is ever set down on the player.
##
##   godot --headless --path game --script res://tests/run_placement_probe.gd
##
## Kent: "there are times i can get stuck in cases like i placed something above me, it
## automatically like puts me inside which is weird". The player is left out of the placement's
## climb and settle on purpose -- a step is aimed at your own feet -- so a box aimed over the
## apo's head settled straight down THROUGH it to the floor it stood on, and every placement
## turned the apo's collision with the new body off until the apo walked out: the box was set
## down around the apo, and the apo was inside it.
##
## Played the real way: drawn, taken from the bag with its slot, aimed, confirmed.

var level: Node
var results: Array[String] = []
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	results.append("  %s  %-48s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	print("\n===== PLACING THINGS NEAR YOURSELF =====")
	for case: Array in [["square", Vector2(0.0, -170.0), "over its head"],
			["square", Vector2(0.0, -40.0), "on it"],
			["ladder", Vector2(0.0, -60.0), "on it"]]:
		await _place_near_the_apo(String(case[0]), case[1], String(case[2]))
	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_PLACEMENT_OK")
		quit(0)
	else:
		print("OBRA_PLACEMENT_FAILED=%d" % failures)
		quit(1)


func _place_near_the_apo(entity_id: String, offset: Vector2, where: String) -> void:
	level = (load("res://game_level.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(40)
	await _unpause()
	var apo := level.get("player") as Node2D
	var spawn := (level.get_node("EnvironmentBaseplate/GameplayPlane/SpawnPoint") as Node2D).global_position
	apo.call("apply_morph_state", {"position": spawn + Vector2(200.0, -10.0), "velocity": Vector2.ZERO})
	await _frames(60)
	var stood := apo.global_position
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	var points := PackedVector2Array([Vector2(0, 0), Vector2(90, 0), Vector2(90, 90), Vector2(0, 90),
		Vector2(0, 0)])
	if entity_id == "ladder":
		points = PackedVector2Array([Vector2(0, 0), Vector2(0, 180), Vector2(40, 180), Vector2(40, 0)])
	level.call("_on_drawing_ready", entity_id, entity_id.capitalize(), sheet, {"confidence": 0.9},
		[{"points": points, "width": 6.0, "color": Color.BLACK}], 1.0)
	await _unpause()
	level.call("_on_inventory_slot_pressed", int(level.call("_slot_holding", entity_id)))
	var placement = level.get("placement_controller")
	placement.call("update_target", stood + offset)
	await physics_frame
	placement.call("update_target", stood + offset)
	var confirmed: bool = placement.call("confirm_placement")
	await _unpause()
	var placed: PhysicsShapeObject = null
	for node in get_nodes_in_group(&"placed_drawings"):
		var shape := node as PhysicsShapeObject
		if shape != null and shape.item_data != null and shape.item_data.entity_id == entity_id \
				and not shape.is_preview:
			placed = shape
	await _frames(120)
	var label := "%s %s" % [entity_id, where]
	_check(confirmed and placed != null, "%s: it can be placed" % label,
		"confirmed" if confirmed else "refused")
	if placed == null:
		await _close()
		return
	var body := Rect2(apo.global_position - Vector2(15.0, 80.0), Vector2(30.0, 80.0)).grow(-2.0)
	var box := placed.world_extent()
	_check(not box.intersects(body), "%s: it is not set down on the apo" % label,
		"%s beside the apo at x %.0f" % [box, apo.global_position.x] if not box.intersects(body)
			else "the apo is inside it: %s around %s" % [box, body])
	_check(absf(box.end.y - stood.y) < 6.0, "%s: and it rests on the floor" % label,
		"its foot at %.0f, the floor at %.0f" % [box.end.y, stood.y])
	# The apo is free, and walks away the way it is not blocked.
	var before := apo.global_position.x
	var away := &"move_left" if box.get_center().x > before else &"move_right"
	Input.action_press(away)
	await _frames(60)
	Input.action_release(away)
	_check(absf(apo.global_position.x - before) > 60.0, "%s: and the apo walks away" % label,
		"%.0f px" % absf(apo.global_position.x - before))
	if entity_id == "ladder":
		apo.call("apply_morph_state", {"position": Vector2(before, stood.y), "velocity": Vector2.ZERO})
		await _frames(10)
		_check(bool(placed.call("climb_reaches", apo)), "%s: and it can still be climbed" % label,
			"from beside it")
	await _close()


func _close() -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
	await _frames(4)


func _frames(count: int) -> void:
	for _i in range(count):
		await physics_frame


func _unpause() -> void:
	for _attempt in range(20):
		for node in get_nodes_in_group(&"modal_overlays"):
			if node.has_method("is_open") and node.has_method("close") and bool(node.call("is_open")):
				node.call("close")
		call_group(DialogueBox.GROUP, &"hide_line")
		paused = false
		await physics_frame
