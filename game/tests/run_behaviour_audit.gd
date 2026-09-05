extends SceneTree
## Behavioural audit: does each class actually DO its thing in a live world, with the
## wanderer as the player? Not part of run_tests.gd -- it is a report, not a gate, and
## two of its rows are currently expected to fail (see the vehicle note below).
##   godot --headless --path game --script res://tests/run_behaviour_audit.gd
##
## The harness checks its own preconditions. Two earlier versions of it reported the
## ladder and the boats as broken when the fault was the setup: the ladder had slid away
## from where the player was standing, and the vehicle pool sat below the wanderer's
## world_bounds, where falling teleports it to the top of the world. Every row that can
## be wrecked by its own scaffolding now says "harness fault" when it is.

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
	await _check_climbable_props()
	await _check_wall_climbers()
	await _check_bread()
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


## Two rails and five rungs, tall: the shape the size table is sized for.
func _ladder_strokes() -> Array:
	var strokes: Array = []
	for x in [0.0, 90.0]:
		strokes.append({"points": PackedVector2Array([Vector2(x, 0.0), Vector2(x, 380.0)]),
			"width": 7.0, "color": Color.BLACK})
	for y in [60.0, 140.0, 220.0, 300.0, 360.0]:
		strokes.append({"points": PackedVector2Array([Vector2(0.0, y), Vector2(90.0, y)]),
			"width": 7.0, "color": Color.BLACK})
	return strokes


func _utility_shaped(entity_id: String, at: Vector2, strokes: Array) -> UtilityObject:
	var node := registry.instantiate_entity(entity_id) as UtilityObject
	world.add_child(node)
	node.apply_item_data(DrawnItemData.from_prediction(
		entity_id, entity_id.capitalize(), _blank(), strokes, 0.5, registry.get_entity(entity_id)))
	node.global_position = at
	node.confirm_placement()
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
	var ladder := _utility_shaped("ladder", Vector2(430.0, 600.0), _ladder_strokes())
	await _settle(140)
	hero.global_position = Vector2(ladder.global_position.x, hero.global_position.y)
	await _settle(4)
	# THE RANGE CHECK FIRST, and through the same measurement game_level uses. Calling
	# interact() straight was how this row passed while E could not reach a ladder at all
	# in the real game: the level measures to the utility and gives up past 96px, and a
	# standing ladder's ORIGIN is 122px above the ground the player is on. A row that
	# skips the way the player actually gets there is not testing the feature.
	var reach := ladder.distance_from(hero.global_position)
	if reach > 96.0:
		_fail("ladder reach", "E cannot reach it: %.0fpx away, limit is 96" % reach)
	else:
		_pass("ladder reach", "%.0fpx away, within E's 96px" % reach)
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


## ⚠ THE OTHER TWO THINGS THE CLIMB TAG SAYS YOU CAN GO UP. `stairs` and `tree` sat in that
## tag for the whole of Level 1 and 2 with no interaction of any kind: an obstacle asking for
## Climb accepted a drawn tree, took the ink, and left a shape on the ground. The ladder had
## the only implementation, so this is the ladder row run twice more against the classes that
## claimed the same ability.
func _check_climbable_props() -> void:
	for entity_id: String in ["stairs", "tree"]:
		var hero := _wanderer(Vector2(400.0, 600.0))
		var prop := _utility_shaped(entity_id, Vector2(430.0, 600.0), _ladder_strokes())
		await _settle(140)
		hero.global_position = Vector2(prop.global_position.x, hero.global_position.y)
		await _settle(4)
		prop.interact(hero)
		await physics_frame
		if not bool(hero.call("is_using_ladder", prop)):
			_fail("%s climb" % entity_id, "the Climb tag claims it, but E did not attach")
		else:
			var start := hero.global_position.y
			Input.action_press("move_up")
			await _settle(60)
			Input.action_release("move_up")
			var climbed := start - hero.global_position.y
			if climbed > 40.0:
				_pass("%s climb" % entity_id, "climbed %.0fpx up" % climbed)
			else:
				_fail("%s climb" % entity_id, "attached but only rose %.0fpx" % climbed)
		hero.queue_free()
		prop.queue_free()
		await process_frame


## ⚠ THE CLIMB TAG IS THE MOST REQUIRED TAG IN THE GAME -- four obstacles across two levels
## -- and for a long time five of its eight members could not climb. The wall drive lived
## inside `_drive_spider` behind `entity_id == "spider"`, so a player who drew a monkey at a
## Climb gate was told by the director that the monkey qualified, morphed into it, and then
## walked into the wall. The director agreeing and the world refusing is worse than a plain
## refusal, and this project has shipped it twice.
##
## So every creature the Climb tag claims is put against a wall here and asked to go up it.
## `tools/audit_abilities.py` checks that the profile flag is SET; this checks that setting
## it does something, which is a different question and the one that matters.
func _check_wall_climbers() -> void:
	var wall := _ground(Vector2(1900.0, 400.0), Vector2(60.0, 520.0))
	for entity_id: String in ["spider", "monkey", "crab"]:
		var climber := _creature(entity_id, Vector2(1852.0, 560.0))
		if climber == null:
			_fail("%s climb" % entity_id, "could not be instantiated")
			continue
		await _settle(30)
		# ⚠ PUT IT BACK ON THE WALL AFTER IT SETTLES. A rig walks itself about while it finds
		# its stance -- the spider ended up 145px away and this row read "rose 0px" for a
		# creature that climbs perfectly well. Same lesson as the ladder row above: measure
		# the feature, not where the scaffolding left the subject.
		climber.global_position = Vector2(1852.0, climber.global_position.y)
		await _settle(6)
		var start := climber.global_position.y
		Input.action_press("move_right")
		Input.action_press("move_up")
		await _settle(180)
		Input.action_release("move_up")
		Input.action_release("move_right")
		var risen := start - climber.global_position.y
		if risen > 40.0:
			_pass("%s climb" % entity_id, "went up the wall %.0fpx" % risen)
		else:
			_fail("%s climb" % entity_id,
				"the Climb tag claims it, but it rose %.0fpx" % risen)
		climber.queue_free()
		await process_frame
	wall.queue_free()
	await process_frame


## A drawn creature, built the way `run_morph_reach_probe` builds one.
##
## ⚠ IT MUST BE `apply_drawing` WITH A ROSTER FIXTURE, not a box stroke through
## `apply_item_data`. The first version of this used the object path and all four climbers
## reported "rose 0px" -- INCLUDING the spider, which climbs perfectly well in the game. A
## creature given a rectangle has no limbs to segment, so the rig comes up as one blob with
## no wall contact, and every row measured the fixture rather than the feature. The file's
## own preamble warns about exactly this; it caught me anyway.
func _creature(entity_id: String, at: Vector2) -> Node2D:
	var node := registry.instantiate_entity(entity_id) as Node2D
	if node == null:
		return null
	world.add_child(node)
	node.global_position = at
	if node.has_method("set_world_bounds"):
		node.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1600.0))
	if node.has_method("apply_drawing"):
		var rig_type := String(registry.get_entity(entity_id).get("rig_type", "none"))
		node.call("apply_drawing", _blank(), RosterFixtures.for_rig(rig_type, entity_id))
	node.global_position = at
	return node


## Bread took mushroom's slot in the roster, and this check is the inverse of the one
## it replaced: mushroom was a bounce pad, and the danger in reusing a slot is that the
## new class quietly inherits the old class's behaviour. Bread is inert -- the birds in
## Level 2 come to IT -- so landing on it must do nothing but stop the fall.
func _check_bread() -> void:
	var hero := _wanderer(Vector2(800.0, 480.0))
	var loaf := _utility("bread", Vector2(800.0, 640.0))
	var started_at := hero.global_position.y
	# y grows DOWNWARD, so the peak of a bounce is the SMALLEST y seen. Measuring the
	# span between the highest and lowest points instead would read the drop onto the
	# loaf as a bounce of the same size, and this check would fail on a prop doing
	# nothing at all -- which is exactly what it is here to allow.
	var peak := started_at
	for i in range(150):
		await physics_frame
		peak = minf(peak, hero.global_position.y)
	var rose := started_at - peak
	if rose <= 8.0:
		_pass("bread", "inert -- the player fell onto it and stayed (rose %.0fpx)" % rose)
	else:
		_fail("bread", "rose %.0fpx above the drop point%s" % [rose, " -- launched out of the level" if peak <= -400.0 else " -- it bounced; the mushroom effect was inherited"])
	hero.queue_free()
	loaf.queue_free()
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
	# Everything stays inside Rect2(0, -520, 3760, 1200): a wanderer that falls past
	# world_bounds.end.y (680) is teleported back to the top of the world, and a
	# passenger yanked out of the sky looks exactly like a boat leaving them behind.
	var bed := _ground(Vector2(1500.0, 620.0), Vector2(3000.0, 120.0))
	var pool := WaterArea2D.new()
	pool.surface_size = Vector2(2600.0, 260.0)
	pool.position = Vector2(1500.0, 430.0)
	world.add_child(pool)
	var hero := _wanderer(Vector2(900.0, 260.0))
	hero.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1200.0))
	var boat := _utility(entity_id, Vector2(920.0, 300.0))
	await _settle(50)
	if not bool(boat.call("_is_in_water")):
		_fail(entity_id, "did not register as afloat -- harness fault")
	elif boat.global_position.y > 560.0:
		_fail(entity_id, "sank to the bed at y=%.0f before boarding" % boat.global_position.y)
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
			_fail(entity_id, "moved %.0fpx but left the player behind (boat %s, player %s, riding=%s)" % [
				sailed, boat.global_position, hero.global_position,
				hero.call("is_riding") if hero.has_method("is_riding") else "n/a"])
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
