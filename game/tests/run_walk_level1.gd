extends SceneTree

const RosterFixtures = preload("res://tests/roster_fixtures.gd")
## Beat 0, walked rather than solved on paper.
##
##	 godot --headless --path game --script res://tests/run_walk_level1.gd
##
## run_level1_audit proves the obstacle ACCEPTS a stair: it calls _judge_submission and
## reads the director's answer. That is a statement about bookkeeping. It says nothing
## about whether a player who draws one can then put it somewhere and climb it, which is
## the only question Beat 0 actually asks -- and once the answer was no, because every
## click aimed at the foot of the stair was landing in the inventory bar.
##
## So this one drives the character: stand the stair up, then hold the keys a player holds
## and see where the body ends up.

const WandererClass = preload("res://scripts/wanderer.gd")
## Read off the level, not restated here: a test that carries its own copy of the
## geometry stops testing the geometry the moment somebody moves it.
## The bank Beat 0 is answered from, and the top of Ang Hagdan's wall -- Terrace1.
var ledge_top := 0.0
var bank_top := 0.0

var passes := 0
var failures := 0
var results: Array[String] = []

var level: Node
var player: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://game_level.tscn") as PackedScene
	level = packed.instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	# The level opens on a line of dialogue, and a conversation stops the tree until the
	# player turns the page. Nobody is here to press a key, so dismiss it the way a skip
	# button would, and keep dismissing them -- otherwise the first obstacle the
	# walker reaches stops the world and it reports the level as a wall.
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(30):
		await physics_frame
	player = level.get("player") as Node2D
	var bank := level.get_node_or_null(
		"EnvironmentBaseplate/GameplayPlane/Terrain/LowerLeft") as Node2D
	var ledge := level.get_node_or_null(
		"EnvironmentBaseplate/GameplayPlane/Terrain/Terrace1") as Node2D
	if bank != null and ledge != null:
		bank_top = bank.global_position.y
		ledge_top = ledge.global_position.y
	if player == null:
		print("OBRA_WALK_L1_FAILED=1  (no player)")
		quit(1)
		return

	var jump_height: float = pow(WandererClass.JUMP_VELOCITY, 2.0) / (2.0 * float(
		ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)))
	_check(bank_top - ledge_top > jump_height, "the stair is a real gate",
		"%.0fpx of rise against a %.0fpx jump" % [bank_top - ledge_top, jump_height])

	# ⚠ THIS FIXTURE RUNS WITH A FULL PURSE, DELIBERATELY, and the reason is worth writing
	# down. Thesis FR-7 gives a level six units and prices a placeable at one unit per
	# placement, and this walkthrough makes about seven placements -- three of which exist
	# only to test the mechanism (two squares to prove E and right-click take a placement
	# back, one to prove the ghost lands where it is aimed) and are not moves a player would
	# make. Left to pay its own way it ran out at the Overlook and reported Payyo's last
	# stretch as a wall, which is a statement about the fixture and not about the level.
	#
	# Whether the level can actually be FINISHED inside six units is a real question and it
	# has its own answer: `run_level1_finish_probe` plays all three routes to the end and
	# asserts what it spent. This one is about whether the mechanisms work at all.
	for beat in [_cannot_be_climbed_bare, _one_step_is_not_enough, _can_be_climbed_with_a_stair,
			_a_placement_can_be_taken_back, _the_ghost_is_where_it_lands,
			_the_lake_is_a_lake, _the_lake_is_crossed_by_boat,
			_the_apo_goes_into_the_straw, _her_chest_opens, _the_heap_has_an_inside,
			_the_overlook_needs_a_climb,
			_the_gorge_flower_and_return_are_reachable]:
		_refill_the_purse()
		await beat.call()

	print("\n===== BEAT 0 WALKTHROUGH =====")
	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_WALK_L1_OK")
		quit(0)
	else:
		print("OBRA_WALK_L1_FAILED=%d" % failures)
		quit(1)


## The cave floor is somewhere a player can deliberately visit, not a one-way fall. The
## Artist route used to put a solid 60x332 dirt post across the flower's approach, while the
## only ledges back out belonged to Pragmatist and disappeared on the other two choices.
## Drive the real character through the former pillar footprint, then jump the shared stair
## one ledge at a time and land back on the near lip.
func _the_gorge_flower_and_return_are_reachable() -> void:
	player.velocity = Vector2.ZERO
	player.global_position = Vector2(3350.0, 632.0)
	for _frame in range(10):
		await physics_frame
	Input.action_press(&"move_right")
	var furthest := player.global_position.x
	for _frame in range(80):
		await physics_frame
		furthest = maxf(furthest, player.global_position.x)
		if furthest >= 3410.0:
			break
	Input.action_release(&"move_right")
	_check(furthest >= 3410.0, "the flower can be approached across the cave floor",
		"walked through the old pillar footprint to x %.0f" % furthest
		if furthest >= 3410.0 else "blocked at x %.0f" % furthest)

	player.velocity = Vector2.ZERO
	player.global_position = Vector2(3360.0, 632.0)
	for _frame in range(10):
		await physics_frame
	var landings := [
		{"name": "Bottom", "rect": Rect2(3224.0, 572.0, 104.0, 28.0), "aim": 3276.0},
		{"name": "Lower", "rect": Rect2(3080.0, 512.0, 104.0, 28.0), "aim": 3132.0},
		{"name": "MiddleLower", "rect": Rect2(3224.0, 452.0, 104.0, 28.0), "aim": 3276.0},
		{"name": "MiddleUpper", "rect": Rect2(3080.0, 392.0, 104.0, 28.0), "aim": 3132.0},
		{"name": "Upper", "rect": Rect2(3224.0, 332.0, 104.0, 28.0), "aim": 3276.0},
		{"name": "Top", "rect": Rect2(3080.0, 272.0, 104.0, 28.0), "aim": 3132.0},
		{"name": "NearLip", "rect": Rect2(2880.0, 240.0, 200.0, 440.0),
			"aim": 3060.0, "accept_above": true},
	]
	var missed: Array[String] = []
	for landing: Dictionary in landings:
		if not await _jump_to_gorge_landing(landing):
			missed.append("%s (stopped at %s)" % [landing["name"], player.global_position])
			break
	_check(missed.is_empty(), "the player can climb the missing steps back out",
		"floor -> six ledges -> near lip" if missed.is_empty() else "; ".join(missed))


func _jump_to_gorge_landing(landing: Dictionary) -> bool:
	var target := float(landing["aim"])
	var rect := Rect2(landing["rect"])
	# Clear the previous release on a physics tick. The controller reads just-released in
	# _physics_process; pressing again before that reader has consumed the edge cuts the new
	# jump to JUMP_CUT and turns a 94px jump into a 19px hop.
	Input.action_release(&"jump")
	await physics_frame
	Input.action_press(&"jump")
	for frame in range(120):
		Input.action_release(&"move_left")
		Input.action_release(&"move_right")
		# Rise clear of the ledge's vertical face before steering around it. The stair
		# alternates sides specifically so no tread becomes a ceiling over the one below.
		if frame >= 8:
			if player.global_position.x > target + 4.0:
				Input.action_press(&"move_left")
			elif player.global_position.x < target - 4.0:
				Input.action_press(&"move_right")
		if frame == 38:
			Input.action_release(&"jump")
		await physics_frame
		var landed: bool = bool(player.is_on_floor()) \
			and absf(player.global_position.y - rect.position.y) <= 3.0 \
			and player.global_position.x >= rect.position.x + 8.0 \
			and player.global_position.x <= rect.end.x - 8.0
		# Crossing the lip enters its dialogue trigger, which intentionally locks player
		# physics before the body descends onto the bank. Being above and inside that edge
		# is the successful traversal; once the line closes, gravity completes the landing.
		var reached_dialogue_lip: bool = bool(landing.get("accept_above", false)) \
			and player.global_position.y <= rect.position.y \
			and player.global_position.x >= rect.position.x \
			and player.global_position.x <= rect.end.x
		if frame > 8 and (landed or reached_dialogue_lip):
			Input.action_release(&"move_left")
			Input.action_release(&"move_right")
			Input.action_release(&"jump")
			player.velocity = Vector2.ZERO
			for _settle in range(4):
				await physics_frame
			return true
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	Input.action_release(&"jump")
	return false


## THE APO GOES INTO THE STRAW HERSELF, ON E. Kent: "the haybale world, its gone like where is
## it? why cant i go to it?" Only a burrowing drawing fitted, and Level 1 never names `burrow`.
## At the mouth the E prompt over her head says GO IN, and a real E press takes her inside.
func _the_apo_goes_into_the_straw() -> void:
	var pile: Node2D = null
	for node in level.get_tree().get_nodes_in_group(&"straw_piles"):
		if bool((node as Node2D).get("entrance")):
			pile = node as Node2D
	var room := level.get_tree().get_first_node_in_group(&"straw_rooms") as Node2D
	if pile == null or room == null:
		_fail("the apo goes into the straw", "no heap with a way in, or no room behind it")
		return
	var mouth := Rect2(pile.call("mouth_rect"))
	player.set("velocity", Vector2.ZERO)
	player.global_position = pile.global_position + Vector2(mouth.get_center().x, 0.0)
	for _frame in range(30):
		await physics_frame
	var prompts := level.get("action_prompts") as Node
	var chip := prompts.find_child("PickupPrompt", true, false) as Control if prompts != null else null
	var offered: bool = bool(level.call("_fits_through_the_straw")) and bool(level.get("_at_straw_mouth"))
	var says := (chip as Button).text if chip is Button and chip.is_visible_in_tree() else ""
	_check(offered and says.contains("GO IN"), "at the mouth, E offers to go in",
		says.strip_edges() if offered else "the apo does not fit, or is not at the mouth")
	Input.parse_input_event(_key(&"interact", true))
	await physics_frame
	Input.parse_input_event(_key(&"interact", false))
	for _frame in range(60):
		await physics_frame
	var held: Node = level.call("_room_holding_player")
	_check(held == room, "and E takes the apo herself inside",
		"in the straw room" if held == room else "still on the terrace")
	if held == room:
		level.call("_on_straw_exit")
		for _frame in range(30):
			await physics_frame


## THE ROUND TRIP, and both halves of it. Node 2's heap is the only thing in Level 1 with an
## inside, and the inside is a room in the empty sky above the level rather than a cutaway
## where the heap stands -- so getting in is a fade and a teleport, and getting out is
## another one. A room you can enter and not leave is worse than no room, and the way back
## is a hole in a wall rather than a key press, so nothing tells the player it is broken.
func _the_heap_has_an_inside() -> void:
	var pile: Node2D = null
	for node in level.get_tree().get_nodes_in_group(&"straw_piles"):
		if bool((node as Node2D).get("entrance")):
			pile = node as Node2D
	var room := level.get_tree().get_first_node_in_group(&"straw_rooms") as Node2D
	if pile == null or room == null:
		_fail("the heap has an inside", "no heap with a way in, or no room behind it")
		return
	var outside := pile.global_position
	var mouth := Rect2(pile.call("mouth_rect"))
	player.set("velocity", Vector2.ZERO)
	player.global_position = outside + Vector2(mouth.get_center().x, 0.0)
	for _frame in range(10):
		await physics_frame
	# AS SOMETHING THAT BURROWS, which still fits; the apo herself goes in on E -- see
	# _the_apo_goes_into_the_straw.
	var drawing := Image.create_empty(400, 400, false, Image.FORMAT_RGBA8)
	drawing.fill(Color.WHITE)
	level.call("_spawn_or_replace", "ant", "Ant", drawing,
		RosterFixtures.for_rig("walker", "ant"))
	for _frame in range(30):
		await physics_frame
	player = level.get("player") as Node2D
	player.global_position = outside + Vector2(mouth.get_center().x, 0.0)
	for _frame in range(20):
		await physics_frame
	# GOING IN IS A PRESS. Standing in the doorway only makes the offer -- the mouth is on
	# the path east and a heap that swallows passers-by is a hole in the floor of the level.
	Input.parse_input_event(_key(&"move_down", true))
	await physics_frame
	Input.parse_input_event(_key(&"move_down", false))
	# The fade is 0.16 in and 0.24 out, and the teleport is on the turn between them.
	for _frame in range(80):
		await physics_frame
	var size := Vector2(room.get("room_size"))
	var inside := Rect2(room.global_position - Vector2(size.x * 0.5, size.y), size)
	_check(inside.grow(60.0).has_point(player.global_position),
		"ducking into the heap puts her inside it",
		"at %s, in a room at %s" % [player.global_position.round(), inside])
	if not inside.grow(60.0).has_point(player.global_position):
		return

	Input.action_press(&"move_left")
	var out := false
	for _frame in range(140):
		await physics_frame
		if player.global_position.distance_to(outside) < 400.0:
			out = true
			break
	Input.action_release(&"move_left")
	for _frame in range(30):
		await physics_frame
	_check(out and not inside.has_point(player.global_position),
		"and the way out puts her back on the terrace",
		"at %s, beside the heap at %s" % [player.global_position.round(), outside.round()]
		if out else "STILL INSIDE at %s -- the room is a trap" % player.global_position.round())
	# And she must not be standing in the mouth when she lands, or walking out walks her
	# straight back in and the heap is a revolving door.
	_check(not mouth.has_point(player.global_position - outside),
		"and not standing in the doorway she just came out of",
		"clear of the mouth by %.0fpx"
		% absf(player.global_position.x - (outside.x + mouth.position.x)))


## The beat has to ASK for something. If the bare stair can be climbed, Beat 0 is scenery.
func _cannot_be_climbed_bare() -> void:
	_stand_on_the_bank()
	var reached := await _run_at_the_stair()
	_check(not reached, "the bare stair cannot be climbed",
		"the player is still below it after 4s of running and jumping" if not reached
		else "CLIMBED IT -- the beat asks for nothing")


## AND ONE STEP IS NOT THE ANSWER. Kent wanted the emphasis on the part that needs a stair:
## the wall is 220px, and an 80px square and a jump fall short of it, so a player who
## reaches for the smallest thing that might do is told by the wall rather than let past.
func _one_step_is_not_enough() -> void:
	var placed := await _stand_up("square", Vector2(1140.0, 520.0))
	if placed == null:
		_fail("a single step", "a square could not be set down at the wall")
		return
	var reached := await _run_at_the_stair()
	_check(not reached, "one square at the wall is not enough",
		"still below it -- it wants a stair" if not reached
		else "CLIMBED IT on one square -- the stair is not what it asks for")
	placed.queue_free()
	for _frame in range(4):
		await physics_frame


## And it has to be answerable, with what it asks for: a drawn stair stood against the wall,
## climbed by holding up, the way a placed ladder is. Placing it answers Beat 0.
func _can_be_climbed_with_a_stair() -> void:
	var placed := await _stand_up("stairs", Vector2(1120.0, 440.0))
	_check(placed != null, "a stair can be stood up against Ang Hagdan",
		"placed" if placed != null else "REFUSED -- there is nowhere to put it")
	if placed == null:
		return
	var director = level.get("director")
	_check(director != null and bool(director.call("is_solved", "B0_HAGDAN")),
		"and standing it up answers Beat 0", "B0_HAGDAN solved")
	var reached := await _run_at_the_stair()
	_check(reached, "and Ang Hagdan can then be climbed",
		"the player reached the top" if reached
		else "STILL STUCK -- the stair is up and the beat is unbeatable")


## Draw `entity_id` the way the canvas hands it over, take it out of the bag and set it down
## at `aim` from the bank. Returns what was placed, or null.
func _stand_up(entity_id: String, aim: Vector2) -> PhysicsShapeObject:
	var placement := level.get("placement_controller") as Node2D
	_stand_on_the_bank()
	for _frame in range(20):
		await physics_frame
	var points := PackedVector2Array([Vector2(0, 0), Vector2(90, 0), Vector2(90, 90),
		Vector2(0, 90), Vector2(0, 0)])
	if entity_id == "stairs":
		points = PackedVector2Array()
		for i in range(5):
			points.append(Vector2(i * 50.0, 200.0 - i * 50.0))
			points.append(Vector2((i + 1) * 50.0, 200.0 - i * 50.0))
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	level.call("_on_drawing_ready", entity_id, entity_id.capitalize(), sheet, {"confidence": 0.9},
		[{"points": points, "width": 6.0, "color": Color.BLACK}], 1.0)
	await process_frame
	level.call("_on_inventory_slot_pressed", int(level.call("_slot_holding", entity_id)))
	await process_frame
	if not bool(placement.call("is_placing")):
		return null
	# The controller re-aims at the live cursor every frame in _process, and a headless run
	# has no cursor -- hold the aim.
	placement.set_process(false)
	placement.call("update_target", aim)
	for _frame in range(4):
		await physics_frame
	placement.call("update_target", aim)
	var ok: bool = placement.call("confirm_placement")
	placement.set_process(true)
	if not ok:
		return null
	for _frame in range(60):
		await physics_frame
	var found: PhysicsShapeObject = null
	for node in level.get_tree().get_nodes_in_group(&"placed_drawings"):
		var shape := node as PhysicsShapeObject
		if shape != null and not shape.is_preview and shape.item_data != null \
				and shape.item_data.entity_id == entity_id:
			found = shape
	return found


## A PLACEMENT THE PLAYER CANNOT UNDO IS A TRAP. Ink is committed when the object is set
## down, the slot is emptied when it is taken out of the bag, and a placed body is solid --
## so one misjudged click used to cost a drawing, cost the ink that made it, and leave the
## thing standing in the level for the rest of the run.
##
## Both ways in are tested, because they are two mechanisms and only one of them is the one
## a stuck player reaches for. E walks the `placed_drawings` group and needs the object
## within 96px of the body; right-click hit-tests under the cursor and works wherever the
## mouse can point. Before this pass NEITHER worked for a square, a circle or a triangle:
## pick-up lived on UtilityObject, and the three primitives are not utilities.
##
## Run on an empty terrace on purpose. The bank at Beat 0 is littered with the step from the
## case above by the time this runs, and a square set down on top of another square is a
## test of stacking, not of taking things back. Terrace2: it was Terrace3 at x 2280, which is
## the lake's edge since the lake was lengthened, and a square set down there slid into it.
const CLEAR_GROUND := Vector2(1900, 276.0)
## Where the Overlook's west face is. Node 3's climb is measured against this rather than
## typed as an absolute, so the next time the level is stretched the ladder still leans on
## the cliff instead of standing in the middle of a terrace.
const OVERLOOK_EDGE := 4340.0


func _a_placement_can_be_taken_back() -> void:
	var inventory := level.get("inventory_manager") as Node
	var placement := level.get("placement_controller") as Node2D
	var world_items := level.get_node_or_null(
		"EnvironmentBaseplate/GameplayPlane/WorldItemRoot") as Node2D
	if world_items == null:
		_fail("taking a placement back", "WorldItemRoot is not in the scene")
		return

	for pass_index in range(2):
		var by_hand := pass_index == 0
		var how := "E" if by_hand else "right-click"
		player.set("velocity", Vector2.ZERO)
		player.global_position = CLEAR_GROUND
		for _frame in range(30):
			await physics_frame
		var before := _squares_in(world_items)

		var item := DrawnItemData.new()
		item.entity_id = "square"
		item.display_name = "Square"
		var slot: int = inventory.call("add_item", item)
		level.call("_on_inventory_slot_pressed", slot)
		await process_frame
		if not bool(placement.call("is_placing")):
			_fail("placing a square to take back (%s)" % how, "the placement never started")
			return
		placement.set_process(false)
		# Right beside the character, which is where a player building a step aims -- and
		# which used to be refused outright, because their own body counted as an obstacle.
		placement.call("update_target", player.global_position + Vector2(84.0, -40.0))
		for _frame in range(4):
			await physics_frame
		if not bool(placement.call("confirm_placement")):
			placement.call("cancel_placement")
			_fail("placing a square to take back (%s)" % how, "REFUSED beside the player")
			return
		for _frame in range(30):
			await physics_frame
		_check(_squares_in(world_items) == before + 1,
			"the square is in the world (%s)" % how,
			"%d placed square(s)" % _squares_in(world_items))

		var target := _last_square_in(world_items)
		if target == null:
			_fail("taking it back (%s)" % how, "no square to take")
			return
		# WIRED UP AT CONFIRM, not the first time somebody presses a key. Both take-back
		# paths call _connect_utility themselves, so a placement that binds nothing still
		# works and the regression hides -- until something else that only confirm connects
		# (equipping, using, consuming) is the thing that goes quiet. Assert the contract
		# where it is made: `placed as UtilityObject` is null for all three primitives, and
		# Godot refuses a mistyped bind without a word.
		_check(target.pickup_requested.get_connections().size() > 0,
			"confirming a placement wires it up (%s)" % how,
			"the level is listening for it to be taken back" if target.pickup_requested.get_connections().size() > 0
			else "NOTHING BOUND -- the object was cast to a type it is not")
		# THE REACH IS PART OF THE TEST. E is a 96px surface measure, so a square the
		# placement dropped somewhere else than the ghost is one E cannot answer.
		var reach: float = target.distance_from(player.global_position)
		_check(by_hand == false or reach <= 96.0, "and it is within arm's reach (%s)" % how,
			"%.0fpx from the body" % reach)
		var where := target.global_position
		if by_hand:
			level.call("_interact_with_nearest_utility")
		else:
			level.call("_take_back_under_cursor", where)
		for _frame in range(10):
			await physics_frame

		var left := _squares_in(world_items)
		_check(left == before, "%s takes the square out of the world" % how,
			"gone" if left == before
			else "STILL THERE -- a bad placement is permanent")
		var back := _slot_holding(inventory, "square")
		_check(back >= 0, "and puts it back in the bag (%s)" % how,
			"slot %d" % (back + 1) if back >= 0
			else "LOST -- the drawing and the ink that made it are both gone")

		# Empty the bag before the second pass so the count means the same thing twice.
		if back >= 0:
			inventory.call("take_item", back)


## Freed nodes stay in the child list until the tree flushes them, so a count that does not
## ask is_instance_valid reports a picked-up object as still standing there.
func _squares_in(world_items: Node2D) -> int:
	var count := 0
	for child in world_items.get_children():
		var prop := child as PhysicsShapeObject
		if prop != null and is_instance_valid(prop) and not prop.is_queued_for_deletion() \
			and not prop.is_preview and prop.item_data != null \
			and prop.item_data.entity_id == "square":
			count += 1
	return count


func _last_square_in(world_items: Node2D) -> PhysicsShapeObject:
	var found: PhysicsShapeObject = null
	for child in world_items.get_children():
		var prop := child as PhysicsShapeObject
		if prop != null and is_instance_valid(prop) and not prop.is_queued_for_deletion() \
			and not prop.is_preview and prop.item_data != null \
			and prop.item_data.entity_id == "square":
			found = prop
	return found


func _slot_holding(inventory: Node, entity_id: String) -> int:
	var items: Array = inventory.call("items")
	for index in range(items.size()):
		var item := items[index] as DrawnItemData
		if item != null and item.entity_id == entity_id:
			return index
	return -1


## AIM AT YOUR OWN FEET, WHICH IS WHERE A PLAYER BUILDING A STEP AIMS. Two faults met here
## and each made the other invisible. The player stands on collision layer 1 like the terrain,
## so the preview called the ground under them occupied; the climb out of "solid" ground then
## lifted the object a body's height over their head and stopped, went green up there, and
## confirming dropped it back down on them. The object did not land where the ghost was, and
## the ghost was not somewhere the player had asked for.
##
## So this asserts both halves at once: the spot under the body is placeable, and what gets
## placed ends up where the ghost was standing.
func _the_ghost_is_where_it_lands() -> void:
	var inventory := level.get("inventory_manager") as Node
	var placement := level.get("placement_controller") as Node2D
	var world_items := level.get_node_or_null(
		"EnvironmentBaseplate/GameplayPlane/WorldItemRoot") as Node2D
	player.set("velocity", Vector2.ZERO)
	player.global_position = CLEAR_GROUND
	for _frame in range(30):
		await physics_frame

	var item := DrawnItemData.new()
	item.entity_id = "square"
	item.display_name = "Square"
	var slot: int = inventory.call("add_item", item)
	level.call("_on_inventory_slot_pressed", slot)
	await process_frame
	if not bool(placement.call("is_placing")):
		_fail("aiming at the player's feet", "the placement never started")
		return
	placement.set_process(false)
	placement.call("update_target", player.global_position)
	for _frame in range(4):
		await physics_frame

	var ghost := _preview_in(world_items)
	if ghost == null:
		placement.call("cancel_placement")
		_fail("aiming at the player's feet", "there is no preview to look at")
		return
	var ghost_at := ghost.global_position
	var lifted: float = player.global_position.y - ghost_at.y
	# Half the square is under the aim point, so it rests about 40px up. Anything near a body
	# height means the climb went over the player's head instead.
	_check(lifted < 72.0, "the ghost sits at the player's feet",
		"%.0fpx above the aim" % lifted)

	var placed: bool = placement.call("confirm_placement")
	_check(placed, "the ground under the player is placeable",
		"placed" if placed else "REFUSED -- your own body is vetoing the spot")
	if not placed:
		placement.call("cancel_placement")
		return
	for _frame in range(40):
		await physics_frame
	var landed_at := ghost_at if not is_instance_valid(ghost) else ghost.global_position
	var drift: float = ghost_at.distance_to(landed_at)
	# The settle puts it on the surface exactly, so a passing run measures about a pixel.
	# The climb it replaced steps in 12px rungs, so the failure it guards against is a
	# whole rung out -- 4px separates the two with room on both sides.
	_check(drift <= 4.0, "and the square lands where the ghost was",
		"%.1fpx of drift" % drift)

	# Leave the terrace as it was found: the runs after this one place things too.
	if is_instance_valid(ghost):
		level.call("_take_back_under_cursor", ghost.global_position)
		for _frame in range(10):
			await physics_frame
	var back := _slot_holding(inventory, "square")
	if back >= 0:
		inventory.call("take_item", back)


## Hand the level its ink back between beats. See the note in _run.
func _refill_the_purse() -> void:
	var ink := level.get("ink_manager") as InkManager
	if ink == null:
		return
	ink.committed = 0.0
	ink.reserved = 0.0


func _preview_in(world_items: Node2D) -> PhysicsShapeObject:
	for child in world_items.get_children():
		var prop := child as PhysicsShapeObject
		if prop != null and prop.is_preview:
			return prop
	return null


## The Overlook stands 140px over Terrace5, so the last stretch before the bale is a climb
## rather than a walk. Same rule as Ang Hagdan: prove it opens, or it is a wall.
func _the_overlook_needs_a_climb() -> void:
	var inventory := level.get("inventory_manager") as Node
	var placement := level.get("placement_controller") as Node2D
	player.set("velocity", Vector2.ZERO)
	# MEASURED OFF THE CLIFF, not carried along by the level stretch. These two were authored
	# 90 and 40 units west of the Overlook's edge; the piecewise shift moved them +680 while
	# the edge itself moved +1020, so the ladder ended up standing in the middle of Terrace5
	# with nothing to lean against and the climb had nowhere to go.
	# BACK TO HERSELF FIRST. The heap round-trip above becomes an ant to get in -- see the
	# `burrow` tag -- and never changes back, and writing `global_position` on a morph moves
	# the scene root only: the rig re-syncs it to its own anchor on the next frame, so the
	# creature stays exactly where it was. Every beat after the heap was quietly being run on
	# a player still standing at the haystack.
	if not (level.get("player") is Wanderer):
		level.call("_revert_to_base_form")
		for _frame in range(20):
			await physics_frame
	player = level.get("player") as Node2D
	player.global_position = Vector2(OVERLOOK_EDGE - 90.0, 200.0)
	for _frame in range(20):
		await physics_frame

	var item := DrawnItemData.new()
	item.entity_id = "ladder"
	item.display_name = "Ladder"
	var slot: int = inventory.call("add_item", item)
	level.call("_on_inventory_slot_pressed", slot)
	await process_frame
	if not bool(placement.call("is_placing")):
		_fail("climbing to the bale", "the placement never started")
		return
	placement.set_process(false)
	# Standing ON Terrace5 against the cliff face, not overlapping the Overlook -- a
	# ladder that clips the cliff gets lifted clear of it and ends up on top, which is no
	# use to somebody standing at the bottom.
	# Set down ON the terrace against the cliff, not dropped from two hundred pixels up: a
	# ladder falling that far lands hard, slides, and shoves whoever put it there.
	placement.call("update_target", Vector2(OVERLOOK_EDGE - 44.0, 196.0))
	for _frame in range(4):
		await physics_frame
	var placed: bool = placement.call("confirm_placement")
	_check(placed, "something to climb can be stood against the Overlook",
		"placed" if placed else "REFUSED -- there is nowhere to stand it")
	if not placed:
		return
	for _frame in range(30):
		await physics_frame

	# ⚠ NOT THE INTERACT KEY. This block used to press E here, which is what the climb took
	# when it was written, and E has meant PICK THIS UP since. So the walker pocketed the
	# ladder it had just stood against the cliff and then held up at an empty terrace, and
	# reported the last stretch of Payyo as a wall. The game was fine; the test was pressing
	# the retired verb, and had been red ever since.
	#
	# You climb by standing at it and holding up. That is the whole interaction, and holding
	# the test to it is the only way the next person to change that key finds out here.
	# Let it fall, land and settle: a utility freezes only once it has been grounded and
	# still for three quarters of a second, and an unfrozen ladder cannot be climbed.
	for _frame in range(110):
		await physics_frame
	# WALK BACK TO IT. A ladder is 72 wide and falls two hundred pixels onto the terrace; it
	# lands on top of whoever set it down and shoves them clear, which is what a heavy thing
	# dropping next to you does. Standing where it was aimed and pressing interact was only
	# ever going to work while nothing moved, so the walker closes the distance the way a
	# player would rather than assuming it is still in arm's reach.
	# THE LADDER, by what it is. Earlier beats leave squares in WorldItemRoot, so "the last
	# PhysicsShapeObject" is whichever one happened to be added most recently.
	var ladder: Node2D = null
	var world_items := level.get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/WorldItemRoot") as Node2D
	for child in (world_items.get_children() if world_items != null else []):
		var prop := child as PhysicsShapeObject
		if prop != null and prop.item_data != null and prop.item_data.entity_id == "ladder":
			ladder = prop
	if ladder != null:
		Input.action_press(&"move_right")
		for _frame in range(90):
			await physics_frame
			player = level.get("player") as Node2D
			if player != null and absf(player.global_position.x - ladder.global_position.x) < 40.0:
				break
		Input.action_release(&"move_right")
		for _frame in range(10):
			await physics_frame
	# AND THE INTERFACE HAS TO SAY SO. A verb with no key cap is a verb the player does not
	# have: standing here, the HUD offered E -- PICK UP -- and nothing else, so the one move
	# that reaches Ang Bale was advertised only by the prompt that undoes it.
	var prompts := level.get("action_prompts") as ActionPromptHUD
	for _frame in range(4):
		await physics_frame
	var offered := prompts != null and prompts.climb_is_available()
	_check(offered, "the interface offers the climb where the climb works",
		"CLIMB is up" if offered else "only E, which puts the ladder back in the bag")
	# ⚠ AND IT IS ON THE GLASS, not merely decided on. The cap lives inside a row that hides
	# itself, so "available" and "visible" are two different questions with one obvious way
	# to come apart. Asking only the first cannot tell a working prompt from an invisible one.
	var cap := prompts.climb_prompt_rect() if prompts != null else Rect2()
	_check(cap.get_area() > 0.0, "and the player can see it",
		"cap at %s" % cap.position.round() if cap.get_area() > 0.0
		else "the cap is wanted, laid out, and not on screen")
	# Up, and leaning toward the cliff: a ladder allows slow sideways movement, and the
	# point of this one is the terrace beside it.
	# ⚠ RE-READ EACH FRAME. The level frees the old body whenever it swaps the player -- a
	# morph, a revert, or a checkpoint restore after a fall -- so a reference taken before a
	# climb goes stale. This loop was holding one, and reading `global_position` on a freed
	# node threw, which ABORTED THE COROUTINE: the suite finished, reported green, and
	# silently never ran its last assertion. A stale reference in a test can look like a
	# passing test, which is worse than looking like engine failure.
	Input.action_press(&"move_up")
	Input.action_press(&"move_right")
	for _frame in range(150):
		await physics_frame
		player = level.get("player") as Node2D
		if player == null or player.global_position.y < 40.0:
			break
	Input.action_release(&"move_up")
	# Off the top and onto the terrace it leans against. 4360 since the stretch -- it was
	# 3340, which is now most of a screen short of the Overlook.
	var arrived := false
	var last := Vector2.ZERO
	for _frame in range(120):
		await physics_frame
		player = level.get("player") as Node2D
		if player == null:
			continue
		last = player.global_position
		if last.x > 4360.0 and last.y < 120.0:
			arrived = true
			break
	Input.action_release(&"move_right")
	_check(arrived, "and the player climbs to the bale",
		"reached the Overlook" if arrived
		else "STILL BELOW at %s -- the last stretch is a wall" % last.round())


## Hold right, tap jump, the way a person does it. Polled input, so the actions are held
## through the Input singleton rather than fed as events.
func _run_at_the_stair() -> bool:
	Input.action_press(&"move_right")
	# AND UP, which is how a placed stair or ladder is climbed. On a bare wall it only looks up.
	Input.action_press(&"move_up")
	# STANDING on the stone, not passing over it. A peak height alone is satisfied by a
	# jump that clears the tread and lands back where it started, which is the failure
	# this is meant to catch.
	var arrived := false
	for frame in range(240):
		if frame % 24 == 0:
			Input.action_press(&"jump")
		elif frame % 24 == 18:
			Input.action_release(&"jump")
		await physics_frame
		if bool(player.call("is_on_floor")) and player.global_position.y <= ledge_top + 2.0:
			arrived = true
			break
	Input.action_release(&"move_right")
	Input.action_release(&"move_up")
	Input.action_release(&"jump")
	return arrived


## A real key press for an action, so it goes through the same routing a keyboard does.
func _key(action: StringName, pressed: bool) -> InputEventKey:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			var copy := key.duplicate() as InputEventKey
			copy.pressed = pressed
			return copy
	return InputEventKey.new()


## THE LAKE BEFORE THE GORGE IS A LAKE. Kent: "make the lake in level 1 longer instead of a
## puddle". It was 300px -- a drawn bridge's length -- and is 600 now, grown west into the bank
## before it so the gorge and everything after it stay where they are. Its water, its floor and
## its clay basin are three nodes, and a lake whose water ran past its floor would be water
## over a hole, so all three are held to the same span, between the two banks.
##
## AND NOTHING STANDS IN IT. The gorge's story board is planted at the leading edge of the
## gorge's trigger, which is over the water, so it settled on the lake bed where nobody can
## reach it -- under the old paddy as well. It stands on the shelf before the gorge now.
func _the_lake_is_a_lake() -> void:
	var plane := "EnvironmentBaseplate/GameplayPlane/"
	var water := level.get_node_or_null(plane + "WaterAreas/CentralPaddy") as WaterArea2D
	var floor_body := level.get_node_or_null(plane + "Terrain/CentralPaddyFloor") as Node2D
	var basin := level.get_node_or_null(plane + "WaterAreas/CentralPaddyBack") as Node2D
	var west := level.get_node_or_null(plane + "Terrain/CentralLeft") as Node2D
	var east := level.get_node_or_null(plane + "Terrain/CentralRight") as Node2D
	if water == null or floor_body == null or basin == null or west == null or east == null:
		_fail("the lake", "a piece of it is missing")
		return
	var lake := Rect2(water.global_position - water.surface_size * 0.5, water.surface_size)
	_check(lake.size.x >= 600.0, "the lake is a lake, not a puddle",
		"%.0fpx of water" % lake.size.x)
	var floor_x := Vector2(floor_body.global_position.x,
		floor_body.global_position.x + Vector2(floor_body.get("segment_size")).x)
	var opening := Rect2(basin.get("opening"))
	var basin_x := Vector2(basin.global_position.x + opening.position.x,
		basin.global_position.x + opening.end.x)
	var banks := Vector2(west.global_position.x + Vector2(west.get("segment_size")).x,
		east.global_position.x)
	var span := Vector2(lake.position.x, lake.end.x)
	_check(span.is_equal_approx(floor_x) and span.is_equal_approx(basin_x)
			and span.is_equal_approx(banks),
		"and its water, bed and basin run bank to bank",
		"water %s, bed %s, basin %s, banks %s" % [span, floor_x, basin_x, banks])
	var drowned: Array[String] = []
	for node in level.get_tree().get_nodes_in_group(&"signposts"):
		var post := node as Node2D
		if post != null and lake.grow_individual(0.0, 0.0, 0.0, 8.0).has_point(post.global_position):
			drowned.append("%s at x %.0f" % [post.get_parent().name, post.global_position.x])
	_check(drowned.is_empty(), "and no signpost stands in it",
		"all on dry ground" if drowned.is_empty() else ", ".join(drowned))


## AND IT CAN STILL BE CROSSED. A 340px drawn bridge spanned the old paddy and does not span
## this one; a boat does, and this rides one: put in at the west bank, E aboard, steer east to
## the far wall, E off, and up onto the shelf before the gorge.
func _the_lake_is_crossed_by_boat() -> void:
	var plane := "EnvironmentBaseplate/GameplayPlane/"
	var water := level.get_node_or_null(plane + "WaterAreas/CentralPaddy") as WaterArea2D
	var east := level.get_node_or_null(plane + "Terrain/CentralRight") as Node2D
	if water == null or east == null:
		_fail("the lake is crossed by boat", "no lake")
		return
	var west_edge := water.global_position.x - water.surface_size.x * 0.5
	var surface := water.global_position.y - water.surface_size.y * 0.5
	var registry = level.get("registry")
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	var hull := PackedVector2Array([Vector2(0, 0), Vector2(120, 0), Vector2(100, 40), Vector2(20, 40),
		Vector2(0, 0)])
	var boat := registry.call("instantiate_entity", "sailboat") as UtilityObject
	(level.get("world_item_root") as Node).add_child(boat)
	boat.set_world_bounds(Rect2(level.get("environment").get("world_bounds")))
	boat.apply_item_data(DrawnItemData.from_prediction("sailboat", "Sailboat", sheet,
		[{"points": hull, "width": 6.0, "color": Color.BLACK}], 0.9,
		registry.call("get_entity", "sailboat")))
	boat.global_position = Vector2(west_edge + 80.0, surface - 10.0)
	boat.confirm_placement()
	level.call("_connect_utility", boat)
	player.call("apply_morph_state", {"position": Vector2(west_edge - 30.0, surface - 10.0),
		"velocity": Vector2.ZERO})
	await _carry_on(90)
	boat.interact(player)
	await _carry_on(20)
	_check(bool(player.call("is_riding")), "the lake: E puts the apo in the boat", "aboard")
	Input.action_press(&"move_right")
	var ashore := false
	for _frame in range(360):
		await _carry_on(1)
		if absf(boat.linear_velocity.x) < 5.0 and boat.global_position.x > east.global_position.x - 140.0:
			break
	Input.action_release(&"move_right")
	_check(boat.global_position.x > east.global_position.x - 140.0, "and it sails to the far bank",
		"the boat at x %.0f, the bank at %.0f" % [boat.global_position.x, east.global_position.x])
	boat.interact(player)
	await _carry_on(10)
	Input.action_press(&"move_right")
	Input.action_press(&"jump")
	for frame in range(90):
		if frame == 12:
			Input.action_release(&"jump")
		await _carry_on(1)
		if bool(player.call("is_on_floor")) and absf(player.global_position.y - east.global_position.y) < 4.0 \
				and player.global_position.x > east.global_position.x + 4.0:
			ashore = true
			break
	Input.action_release(&"move_right")
	Input.action_release(&"jump")
	_check(ashore, "and the apo steps off onto the shelf before the gorge",
		"standing at x %.0f" % player.global_position.x if ashore
			else "at %s, on floor %s" % [player.global_position.round(), player.call("is_on_floor")])
	boat.queue_free()
	await _carry_on(2)


## HER CHEST OPENS -- with something that can CUT or UNLOCK, and nothing else. Kent's friend:
## "the box in level 1 is not openable". Found in the straw and called "Locked. Of course.", and
## nothing in the game ever opened it. Played with the apo, inside the heap, with F.
func _her_chest_opens() -> void:
	var chest := level.get_tree().get_first_node_in_group(&"baul") as Baul2D
	if chest == null:
		_fail("her chest opens", "there is no chest")
		return
	player = level.get("player") as Node2D
	level.call("_on_straw_entered")
	await _carry_on(60)
	_check(chest.is_found() and not chest.is_opened(), "inside the heap her chest is found, locked",
		"found" if chest.is_found() else "not found")
	player.call("apply_morph_state", {"position": chest.global_position + Vector2(-50.0, -4.0),
		"velocity": Vector2.ZERO})
	await _carry_on(20)
	level.call("_use_equipped_utility")
	await _carry_on(4)
	_check(not chest.is_opened(), "with nothing in hand, F does not open it", "still locked")

	_draw_tool("rake")
	await _carry_on(20)
	var said := _use_prompt()
	level.call("_use_equipped_utility")
	await _carry_on(4)
	_check(not chest.is_opened() and said != "OPEN", "something that cannot cut or unlock does not",
		"a rake: F says %s, and it stays locked" % said)

	_draw_tool("axe")
	await _carry_on(20)
	said = _use_prompt()
	_check(said == "OPEN", "holding something that can cut, F offers to OPEN it", "F %s" % said)
	level.call("_use_equipped_utility")
	await physics_frame
	var card := level.get("memory_overlay") as Node
	var title := ""
	var body := ""
	for label in card.find_children("*", "Label", true, false):
		if (label as Label).text == "HER SKETCHBOOK PAGE":
			title = (label as Label).text
		elif (label as Label).text.contains("The valley will believe you"):
			body = (label as Label).text
	_check(chest.is_opened(), "and F opens it", "the padlock comes off" if chest.is_opened() else "still locked")
	_check(bool(card.call("is_open")) and not title.is_empty() and not body.is_empty(),
		"and her sketchbook page is inside",
		"a memory card: \"%s\"" % title if not title.is_empty() else "no card")
	_check(int(level.call("_slot_holding", "axe")) < 0 and level.get("_equipped_utility") == null,
		"and the axe is used up, as every tool is", "gone")
	var reads := ""
	for child in chest.get_children():
		if child is Signpost2D:
			reads = (child as Signpost2D).reads
	_check(reads == "L1_N2.chest.opened", "and its sign stops saying it is locked", reads)
	_check(bool(level.call("_opens_the_chest", "key")), "something that can unlock opens it too",
		"key")
	await _carry_on(10)
	level.call("_on_straw_exit")
	await _carry_on(20)


## Drawn, and taken out of the bag into her hand with its number key, as a player does.
func _draw_tool(entity_id: String) -> void:
	_refill_the_purse()
	level.call("_on_drawing_ready", entity_id, entity_id.capitalize(),
		Image.create(28, 28, false, Image.FORMAT_RGBA8), {"confidence": 0.9}, [], 1.0)
	var slot := int(level.call("_slot_holding", entity_id))
	if slot >= 0:
		level.call("_on_inventory_slot_pressed", slot)


## What the F prompt over the apo says.
func _use_prompt() -> String:
	var hud := level.get("action_prompts") as Node
	var use := hud.get("_use") as Button
	return use.text if use != null and use.visible else "(nothing)"


## Frames that keep going through whatever stops the tree: the gorge's lines as the apo
## comes ashore, or a choice. Nobody is here to turn the page.
func _carry_on(count: int) -> void:
	for _i in range(count):
		await physics_frame
		if paused:
			for node in get_nodes_in_group(&"modal_overlays"):
				if node.has_method("is_open") and node.has_method("close") and bool(node.call("is_open")):
					node.call("close")
			call_group(DialogueBox.GROUP, &"hide_line")
			paused = false


## On the bank below the gap, standing still.
func _stand_on_the_bank() -> void:
	player.set("velocity", Vector2.ZERO)
	player.global_position = Vector2(1000, bank_top - 40.0)
	for _frame in range(20):
		await physics_frame


func _check(ok: bool, what: String, detail: String) -> void:
	if ok:
		passes += 1
		results.append("  OK	%s	%s" % [what, detail])
	else:
		_fail(what, detail)


func _fail(what: String, detail: String) -> void:
	failures += 1
	results.append("  FAIL	%s	%s" % [what, detail])
