extends SceneTree
## Heavy things sink; light things float.
##
##   godot --headless --path game --script res://tests/run_sinking_probe.gd
##
## Water lifts a body by a multiple of its own weight, the same multiple for every body, so mass
## cancelled out of it and an anvil floated exactly as a ladder did -- in Terraces' paddies, Dagat's
## sea, anywhere with water. config/object_weights.json now lists what is too heavy to float, and
## a listed drawing tells the water how little it lifts it. Dropped into one pool together: the
## metal sinks to the bottom, and wood, cloth and a drawn shape stay at the top.

const CHECKS := 4
const SURFACE_Y := 200.0
const BOTTOM_Y := 700.0
const SINKS := ["anvil", "key", "sword"]
const FLOATS := ["ladder", "umbrella", "circle"]

var world: Node2D
var registry: EntityRegistry
var failures := 0
var checked := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		print("OBRA_SINKING_FAILED=watchdog")
		quit(2))
	world = Node2D.new()
	root.add_child(world)
	_add_pool()
	registry = EntityRegistry.new()
	world.add_child(registry)
	registry.load_manifest()
	_the_list_is_real_classes()
	var dropped: Dictionary = {}
	var x := 200.0
	for id: String in SINKS + FLOATS:
		dropped[id] = _drop(id, Vector2(x, SURFACE_Y - 60.0))
		x += 210.0
	await create_timer(6.0).timeout
	var sunk: Array[String] = []
	var afloat: Array[String] = []
	for id: String in SINKS:
		if (dropped[id] as Node2D).global_position.y > BOTTOM_Y - 120.0:
			sunk.append(id)
	# A floating body rests where the water's lift meets its weight -- buoyancy 2.4 of it at the pool's
	# full depth -- which is a little under halfway down a pool this deep. Held there, not on the bed.
	var rests := SURFACE_Y + (BOTTOM_Y - SURFACE_Y) / 2.4
	for id: String in FLOATS:
		if absf((dropped[id] as Node2D).global_position.y - rests) < 70.0:
			afloat.append(id)
	_check(sunk.size() == SINKS.size(), "metal sinks to the bottom", "sunk %s of %s; %s" % [
		str(sunk), str(SINKS), _where(dropped, SINKS)])
	_check(afloat.size() == FLOATS.size(), "wood, cloth and a drawn shape float where the water holds them", "afloat %s of %s; %s" % [
		str(afloat), str(FLOATS), _where(dropped, FLOATS)])
	var anvil := dropped["anvil"] as Node
	var ladder := dropped["ladder"] as Node
	_check(anvil.has_meta(&"water_lift") and float(anvil.get_meta(&"water_lift")) < 1.0
			and not ladder.has_meta(&"water_lift"),
		"a heavy drawing tells the water it lifts it less than its weight; a light one says nothing",
		"anvil %s, ladder %s" % [anvil.get_meta(&"water_lift", "none"), ladder.get_meta(&"water_lift", "none")])
	if failures == 0 and checked == CHECKS:
		print("OBRA_SINKING_OK")
		quit(0)
	else:
		print("OBRA_SINKING_FAILED=%d (%d of %d checks)" % [failures, checked, CHECKS])
		quit(1)


func _the_list_is_real_classes() -> void:
	var weights: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/object_weights.json"))
	var unknown: Array[String] = []
	for id: Variant in (weights as Dictionary).get("sinks", []):
		if registry.get_entity(String(id)).is_empty():
			unknown.append(String(id))
	_check(unknown.is_empty() and float((weights as Dictionary).get("sinking_lift", 9.0)) < 1.0,
		"what sinks is real classes, lifted less than their weight", "none unknown" if unknown.is_empty()
			else "NOT CLASSES: " + ", ".join(unknown))


func _add_pool() -> void:
	var floor := StaticBody2D.new()
	var ground := CollisionShape2D.new()
	var slab := RectangleShape2D.new()
	slab.size = Vector2(3000.0, 40.0)
	ground.shape = slab
	floor.add_child(ground)
	floor.position = Vector2(800.0, BOTTOM_Y + 20.0)
	world.add_child(floor)
	var water := WaterArea2D.new()
	water.surface_size = Vector2(1600.0, BOTTOM_Y - SURFACE_Y)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = water.surface_size
	shape.shape = box
	water.add_child(shape)
	water.position = Vector2(800.0, (SURFACE_Y + BOTTOM_Y) * 0.5)
	world.add_child(water)


func _drop(id: String, at: Vector2) -> Node2D:
	var thing := registry.instantiate_entity(id) as Node2D
	var page := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	page.fill(Color.WHITE)
	if thing.has_method("apply_item_data"):
		thing.call("apply_item_data", DrawnItemData.from_prediction(id, id.capitalize(), page,
			[{"points": PackedVector2Array([Vector2(30, 30), Vector2(98, 30), Vector2(98, 98), Vector2(30, 98), Vector2(30, 30)]),
				"width": 6.0, "color": Color.BLACK}], 1.0, registry.get_entity(id)))
	if thing.has_method("set_world_bounds"):
		thing.call("set_world_bounds", Rect2(-200.0, -400.0, 3000.0, 1400.0))
	thing.position = at
	world.add_child(thing)
	return thing


func _where(dropped: Dictionary, ids: Array) -> String:
	var out: Array[String] = []
	for id: String in ids:
		out.append("%s y %.0f" % [id, (dropped[id] as Node2D).global_position.y])
	return ", ".join(out)


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
