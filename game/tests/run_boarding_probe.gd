extends SceneTree
## Aboard a drawn boat, the apo stands IN its hull -- not over it.
##
##   godot --headless --path game --script res://tests/run_boarding_probe.gd
##
## Kent: "adjust and fix how we board drawings that are boardable since it looks like im floating
## even tho im not". The seat was the boat's middle lifted by a quarter of its height, and the
## middle of a drawn boat is wherever the drawing's middle is: aboard a sailboat drawn the usual
## way -- a tall sail over a small hull -- the apo's feet were 82 px over the hull's rim, standing
## on nothing beside the sail, and 11 px over the rim of a plain hull.
##
## Boarded the way a player boards, with E, on Dagat's own sea.

var level: Node
var results: Array[String] = []
var failures := 0

const DRAWINGS := {
	"a plain hull": [[Vector2(0, 0), Vector2(120, 0), Vector2(100, 40), Vector2(20, 40), Vector2(0, 0)]],
	"a sail over a hull": [[Vector2(60, 0), Vector2(60, 110), Vector2(10, 100), Vector2(60, 0)],
		[Vector2(0, 112), Vector2(130, 112), Vector2(110, 150), Vector2(20, 150), Vector2(0, 112)]],
}


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	results.append("  %s  %-44s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	print("\n===== ABOARD =====")
	for drawing: String in DRAWINGS:
		await _board(drawing, DRAWINGS[drawing])
	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_BOARDING_OK")
		quit(0)
	else:
		print("OBRA_BOARDING_FAILED=%d" % failures)
		quit(1)


func _board(drawing: String, shapes: Array) -> void:
	level = (load("res://level_3.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(40)
	# OUT AT SEA, half a screen past where the home beach ends -- read off the level, because the
	# beach moves. It ran to 1000 until the 2026-10-05 rework made room to dig the bangka out and
	# ran it to 1600; a boat set down at the old 1500 sat on the sand, where E takes a drawing
	# back instead of boarding it, and this read a freed boat.
	var shore := level.find_child("ShoreBand", true, false)
	if shore == null:
		_check(false, "%s: the level has a home beach" % drawing, "no ShoreBand")
		level.queue_free()
		await _frames(4)
		return
	var sea_x := float((shore.get("home_ground") as Vector2).y) + 500.0
	var registry = level.get("registry")
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	var strokes := []
	for points: Array in shapes:
		strokes.append({"points": PackedVector2Array(points), "width": 6.0, "color": Color.BLACK})
	var boat := registry.call("instantiate_entity", "sailboat") as UtilityObject
	(level.get("world_item_root") as Node).add_child(boat)
	boat.set_world_bounds(Rect2(level.get("environment").get("world_bounds")))
	boat.apply_item_data(DrawnItemData.from_prediction("sailboat", "Sailboat", sheet, strokes, 0.9,
		registry.call("get_entity", "sailboat")))
	boat.global_position = Vector2(sea_x, 540.0)
	boat.confirm_placement()
	level.call("_connect_utility", boat)
	var apo := level.get("player") as Node2D
	apo.call("apply_morph_state", {"position": Vector2(sea_x, 380.0), "velocity": Vector2.ZERO})
	await _frames(90)
	boat.interact(apo)
	await _frames(120)
	if not is_instance_valid(boat):
		_check(false, "%s: E puts the apo aboard" % drawing,
			"the boat was TAKEN BACK at x %.0f -- it was not in the water" % sea_x)
		level.queue_free()
		await _frames(4)
		return
	# The hull is the lowest of the shapes the drawing was built into; its top is the rim.
	var rim := INF
	var keel := -INF
	for child in boat.get_children():
		var shape := child as CollisionShape2D
		if shape == null or shape.shape == null:
			continue
		var rect := shape.global_transform * shape.shape.get_rect()
		if rect.end.y > keel:
			keel = rect.end.y
			rim = rect.position.y
	var feet := apo.global_position.y
	var below := feet - rim
	_check(bool(apo.call("is_riding")), "%s: E puts the apo aboard" % drawing, "riding")
	_check(below >= 0.0 and below <= 12.0, "%s: and it stands in the hull" % drawing,
		"feet %.0f px below the rim (rim %.0f, keel %.0f)" % [below, rim, keel] if below >= 0.0
			else "feet %.0f px ABOVE the rim -- standing on nothing" % -below)
	level.queue_free()
	await _frames(4)


func _frames(count: int) -> void:
	for _i in range(count):
		await physics_frame
		if paused:
			for node in get_nodes_in_group(&"modal_overlays"):
				if node.has_method("is_open") and node.has_method("close") and bool(node.call("is_open")):
					node.call("close")
			call_group(DialogueBox.GROUP, &"hide_line")
			paused = false
