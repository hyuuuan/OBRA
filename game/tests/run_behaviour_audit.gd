extends SceneTree
## Behavioural audit: does each class actually DO its thing in a live world, with the
## wanderer as the player? Not part of run_tests.gd -- it is a report, not a gate, and
## two of its rows are currently expected to fail (see the vehicle note below).
##   godot --headless --path game --script res://tests/run_behaviour_audit.gd
##
## KNOWN FAILING: sailboat and submarine "left the player behind". The hull sails and
## the passenger is attached (begin_ride stops them walking off), but the seat is not
## holding them across a long run in this harness. Not yet diagnosed.

var world: Node2D
var registry: EntityRegistry
var results: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = Node2D.new()
	root.add_child(world)
	registry = EntityRegistry.new()
	world.add_child(registry)
	registry.load_manifest()
	_ground(Vector2(1200.0, 700.0), Vector2(4000.0, 120.0))

	await _check_ladder()
	await _check_mushroom()
	await _check_door()
	await _check_umbrella()
	await _check_axe_on_wood()
	await _check_vehicle("sailboat")
	await _check_vehicle("submarine")
	await _check_held_tools_reach_the_hand()

	print("\n===== BEHAVIOUR AUDIT =====")
	for line in results:
		print(line)
	quit(0)


func _pass(what: String, detail: String) -> void:
	results.append("  OK    %-22s %s" % [what, detail])


func _fail(what: String, detail: String) -> void:
	results.append("  FAIL  %-22s %s" % [what, detail])


func _ground(at: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	world.add_child(body)
	return body


func _wanderer(at: Vector2) -> Node2D:
	var node := (load("res://creatures/wanderer.tscn") as PackedScene).instantiate() as Node2D
	world.add_child(node)
	node.global_position = at
	return node


func _utility(entity_id: String, at: Vector2) -> UtilityObject:
	var node := registry.instantiate_entity(entity_id) as UtilityObject
	world.add_child(node)
	node.apply_item_data(DrawnItemData.from_prediction(
		entity_id, entity_id.capitalize(), _blank(), [_box_stroke()], 0.5, registry.get_entity(entity_id)))
	node.global_position = at
	node.confirm_placement()
	return node


func _blank() -> Image:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return image


func _box_stroke() -> Dictionary:
	return {
		"points": PackedVector2Array([Vector2(0, 0), Vector2(70, 0), Vector2(70, 90), Vector2(0, 90), Vector2(0, 0)]),
		"width": 6.0, "color": Color.BLACK,
	}


func _settle(frames: int = 30) -> void:
	for i in range(frames):
		await physics_frame


func _check_ladder() -> void:
	var hero := _wanderer(Vector2(400.0, 600.0))
	var ladder := _utility("ladder", Vector2(430.0, 600.0))
	await _settle(140)
	hero.global_position = Vector2(ladder.global_position.x, hero.global_position.y)
	await _settle(4)
	ladder.interact(hero)
	await physics_frame
	if not bool(hero.call("is_using_ladder", ladder)):
		_fail("ladder", "E did not attach the wanderer to it")
	else:
		var start := hero.global_position.y
		Input.action_press("move_up")
		await _settle(60)
		Input.action_release("move_up")
		var climbed := start - hero.global_position.y
		if climbed > 40.0:
			_pass("ladder", "climbed %.0fpx up" % climbed)
		else:
			_fail("ladder", "attached but only rose %.0fpx" % climbed)
	hero.queue_free()
	ladder.queue_free()
	await process_frame


func _check_mushroom() -> void:
	var hero := _wanderer(Vector2(800.0, 480.0))
	var shroom := _utility("mushroom", Vector2(800.0, 640.0))
	await _settle(90)
	var lowest := hero.global_position.y
	for i in range(90):
		await physics_frame
		lowest = maxf(lowest, hero.global_position.y)
	var rebound := lowest - hero.global_position.y
	if rebound > 20.0:
		_pass("mushroom", "bounced the player %.0fpx back up" % rebound)
	else:
		_fail("mushroom", "player landed and stayed (rebound %.0fpx)" % rebound)
	hero.queue_free()
	shroom.queue_free()
	await process_frame


func _check_door() -> void:
	var hero := _wanderer(Vector2(1500.0, 600.0))
	var near := _utility("door", Vector2(1500.0, 640.0))
	var far := _utility("door", Vector2(2000.0, 640.0))
	await _settle(60)
	var moved := hero.global_position.distance_to(far.global_position)
	if moved < 200.0:
		_pass("door", "teleported the player to its pair")
	else:
		_fail("door", "player stayed %.0fpx from the far door" % moved)
	hero.queue_free()
	near.queue_free()
	far.queue_free()
	await process_frame


func _check_umbrella() -> void:
	var hero := _wanderer(Vector2(2600.0, 100.0))
	var brolly := _utility("umbrella", Vector2(2600.0, 100.0))
	brolly.equip_to(hero)
	await physics_frame
	brolly.describe_use(hero)
	await _settle(40)
	var fall_speed: float = (hero.get("velocity") as Vector2).y
	if fall_speed <= 220.0:
		_pass("umbrella", "capped the fall at %.0f px/s" % fall_speed)
	else:
		_fail("umbrella", "falling at %.0f px/s with it open" % fall_speed)
	hero.queue_free()
	brolly.queue_free()
	await process_frame


func _check_axe_on_wood() -> void:
	var hero := _wanderer(Vector2(3000.0, 600.0))
	var tree: Node2D = load("res://scripts/dead_tree_2d.gd").new()
	tree.set("health", 60.0)
	world.add_child(tree)
	tree.global_position = Vector2(3040.0, 640.0)
	var axe := _utility("axe", Vector2(3000.0, 600.0))
	axe.equip_to(hero)
	await _settle(10)
	for swing in range(6):
		axe.describe_use(hero)
		await _settle(4)
	if bool(tree.get("is_destroyed")):
		_pass("axe on wood", "felled the dead tree")
	else:
		_fail("axe on wood", "tree survived at %.0f health" % float(tree.get("health")))
	hero.queue_free()
	axe.queue_free()
	tree.queue_free()
	await process_frame


func _check_vehicle(entity_id: String) -> void:
	var bed := _ground(Vector2(1200.0, 1200.0), Vector2(2400.0, 120.0))
	var pool := WaterArea2D.new()
	pool.surface_size = Vector2(2600.0, 240.0)
	world.add_child(pool)
	pool.global_position = Vector2(1500.0, 1030.0)
	var hero := _wanderer(Vector2(400.0, 980.0))
	var boat := _utility(entity_id, Vector2(420.0, 1000.0))
	await _settle(50)
	if not bool(boat.call("_is_in_water")):
		_fail(entity_id, "did not register as afloat")
	else:
		boat.interact(hero)
		await physics_frame
		var start := boat.global_position.x
		Input.action_press("move_right")
		await _settle(150)
		Input.action_release("move_right")
		var sailed := boat.global_position.x - start
		var carried := hero.global_position.distance_to(boat.global_position) < 120.0
		if absf(sailed) > 80.0 and carried:
			_pass(entity_id, "travelled %.0fpx carrying the player" % sailed)
		elif absf(sailed) > 80.0:
			_fail(entity_id, "moved %.0fpx but left the player behind" % sailed)
		else:
			_fail(entity_id, "only moved %.0fpx" % sailed)
	hero.queue_free()
	boat.queue_free()
	pool.queue_free()
	bed.queue_free()
	await process_frame


## Every held tool should end up at the hand, not at the character's feet.
func _check_held_tools_reach_the_hand() -> void:
	var hero := _wanderer(Vector2(3500.0, 600.0))
	await _settle(20)
	var grip := hero.call("get_grip_anchor") as Node2D
	var strays: Array[String] = []
	for entity_id in registry.get_entity_ids():
		var entry := registry.get_entity(entity_id)
		if String(entry.get("utility_behavior", "")) not in UtilityObject.HELD_TOOLS:
			continue
		var tool := _utility(entity_id, Vector2(3500.0, 600.0))
		tool.equip_to(hero)
		await physics_frame
		if tool.get_parent() != grip:
			strays.append(entity_id)
		tool.queue_free()
		await process_frame
	if strays.is_empty():
		_pass("held tools -> hand", "all 18 reparent to the grip anchor")
	else:
		_fail("held tools -> hand", "not in hand: %s" % ", ".join(strays))
	hero.queue_free()
	await process_frame
