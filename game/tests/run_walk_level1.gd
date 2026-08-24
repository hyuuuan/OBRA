extends SceneTree
## Beat 0, walked rather than solved on paper.
##
##	 godot --headless --path game --script res://tests/run_walk_level1.gd
##
## run_level1_audit proves the obstacle ACCEPTS a square: it calls _judge_submission and
## reads the director's answer. That is a statement about bookkeeping. It says nothing
## about whether a player who draws the square can then put it somewhere and climb it,
## which is the only question Beat 0 actually asks -- and the answer was no, because every
## click aimed at the foot of the stair was landing in the inventory bar.
##
## So this one drives the character: place the step, then hold the keys a player holds and
## see where the body ends up.

const WandererClass = preload("res://scripts/wanderer.gd")
const StairTreadClass = preload("res://scripts/stair_tread_2d.gd")
## Read off the level, not restated here: a test that carries its own copy of the
## geometry stops testing the geometry the moment somebody moves it.
var tread_top := 0.0
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
	for _frame in range(30):
		await physics_frame
	player = level.get("player") as Node2D
	var hagdan := level.get_node_or_null("EnvironmentBaseplate/GameplayPlane/Hagdan")
	var bank := level.get_node_or_null(
		"EnvironmentBaseplate/GameplayPlane/Terrain/LowerRight") as Node2D
	if hagdan != null and bank != null:
		bank_top = bank.global_position.y
		for child in hagdan.get_children():
			if child.get_script() == StairTreadClass and not bool(child.get("is_broken")):
				tread_top = maxf(tread_top, float(child.call("surface_y")))
	if player == null:
		print("OBRA_WALK_L1_FAILED=1  (no player)")
		quit(1)
		return

	var jump_height: float = pow(WandererClass.JUMP_VELOCITY, 2.0) / (2.0 * float(
		ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)))
	_check(bank_top - tread_top > jump_height, "the stair is a real gate",
		"%.0fpx of rise against a %.0fpx jump" % [bank_top - tread_top, jump_height])

	await _the_paddy_needs_a_crossing()
	await _cannot_be_climbed_bare()
	await _can_be_climbed_with_a_step()
	await _a_placement_can_be_taken_back()
	await _the_ghost_is_where_it_lands()
	await _the_overlook_needs_a_climb()

	print("\n===== BEAT 0 WALKTHROUGH =====")
	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_WALK_L1_OK")
		quit(0)
	else:
		print("OBRA_WALK_L1_FAILED=%d" % failures)
		quit(1)


## The paddy is 300px of water, deeper than the apo can climb out of and wider than she
## can jump. That makes it a gate -- and a gate is only a gate if it OPENS. A crossing that
## cannot be crossed even with the right drawing is not a puzzle, it is a wall.
func _the_paddy_needs_a_crossing() -> void:
	var inventory := level.get("inventory_manager") as Node
	var placement := level.get("placement_controller") as Node2D
	player.set("velocity", Vector2.ZERO)
	player.global_position = Vector2(300.0, 500.0)
	for _frame in range(20):
		await physics_frame

	var item := DrawnItemData.new()
	item.entity_id = "bridge"
	item.display_name = "Bridge"
	var slot: int = inventory.call("add_item", item)
	level.call("_on_inventory_slot_pressed", slot)
	await process_frame
	if not bool(placement.call("is_placing")):
		_fail("bridging the paddy", "the placement never started")
		return
	placement.set_process(false)
	# Across the water, resting on both banks.
	placement.call("update_target", Vector2(490.0, 545.0))
	for _frame in range(4):
		await physics_frame
	var placed: bool = placement.call("confirm_placement")
	_check(placed, "something that spans it can be set across the paddy",
		"placed" if placed else "REFUSED -- the crossing cannot be built")
	if not placed:
		return
	for _frame in range(40):
		await physics_frame

	Input.action_press(&"move_right")
	var crossed := false
	for frame in range(300):
		if frame % 24 == 0:
			Input.action_press(&"jump")
		elif frame % 24 == 18:
			Input.action_release(&"jump")
		await physics_frame
		if player.global_position.x > 660.0:
			crossed = true
			break
	Input.action_release(&"move_right")
	Input.action_release(&"jump")
	_check(crossed, "and the player walks across it",
		"reached the far bank" if crossed
		else "STILL STUCK at x %.0f -- the paddy is a wall" % player.global_position.x)


## The beat has to ASK for something. If the bare stair can be climbed, Beat 0 is scenery.
func _cannot_be_climbed_bare() -> void:
	_stand_on_the_bank()
	var reached := await _run_at_the_stair()
	_check(not reached, "the bare stair cannot be climbed",
		"the player is still below it after 4s of running and jumping" if not reached
		else "CLIMBED IT -- the beat asks for nothing")


## And it has to be answerable. A step is placed at the foot of the stair, which is what
## the player does after drawing something that spans the gap.
func _can_be_climbed_with_a_step() -> void:
	var inventory := level.get("inventory_manager") as Node
	var placement := level.get("placement_controller") as Node2D
	_stand_on_the_bank()

	var item := DrawnItemData.new()
	item.entity_id = "square"
	item.display_name = "Square"
	var slot: int = inventory.call("add_item", item)
	level.call("_on_inventory_slot_pressed", slot)
	await process_frame
	if not bool(placement.call("is_placing")):
		_fail("placing the step", "the placement never started")
		return

	# At the foot of the stair, under open sky: the surviving tread overhangs the right
	# end of the bank, so the useful ground is west of it.
	# The controller re-aims at the live cursor every frame in _process, and a
	# headless run has no cursor -- the preview was being dragged to (0,0) and
	# clamped to the reach radius, which put the step in the paddy. Hold the aim.
	placement.set_process(false)
	placement.call("update_target", Vector2(810.0, 505.0))
	for _frame in range(4):
		await physics_frame
	var placed: bool = placement.call("confirm_placement")
	_check(placed, "a step can be set down at the foot of the stair",
		"placed" if placed else "REFUSED -- there is nowhere to put it")
	if not placed:
		return

	var reached := await _run_at_the_stair()
	_check(reached, "and the stair can then be climbed",
		"the player reached the top" if reached
		else "STILL STUCK -- the step is down and the beat is unbeatable")


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
## test of stacking, not of taking things back.
const CLEAR_GROUND := Vector2(1600.0, 236.0)


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


func _preview_in(world_items: Node2D) -> PhysicsShapeObject:
	for child in world_items.get_children():
		var prop := child as PhysicsShapeObject
		if prop != null and prop.is_preview:
			return prop
	return null


## The Overlook stands 140px over Terrace5, so the last stretch before the bale is a climb
## rather than a walk. Same rule as the paddy: prove it opens, or it is a wall.
func _the_overlook_needs_a_climb() -> void:
	var inventory := level.get("inventory_manager") as Node
	var placement := level.get("placement_controller") as Node2D
	player.set("velocity", Vector2.ZERO)
	player.global_position = Vector2(3230.0, 200.0)
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
	placement.call("update_target", Vector2(3280.0, 40.0))
	for _frame in range(4):
		await physics_frame
	var placed: bool = placement.call("confirm_placement")
	_check(placed, "something to climb can be stood against the Overlook",
		"placed" if placed else "REFUSED -- there is nowhere to stand it")
	if not placed:
		return
	for _frame in range(30):
		await physics_frame

	# Take hold of it, then climb. A ladder is not scenery you touch: it is grabbed with
	# the interact key, the same as every other utility.
	# Let it fall, land and settle: a utility freezes only once it has been grounded and
	# still for three quarters of a second, and an unfrozen ladder cannot be climbed.
	for _frame in range(110):
		await physics_frame
	for event in [_key(&"interact", true), _key(&"interact", false)]:
		Input.parse_input_event(event)
		await physics_frame
	for _frame in range(6):
		await physics_frame
	# Up, and leaning toward the cliff: a ladder allows slow sideways movement, and the
	# point of this one is the terrace beside it.
	Input.action_press(&"move_up")
	Input.action_press(&"move_right")
	for _frame in range(150):
		await physics_frame
		if player.global_position.y < 40.0:
			break
	Input.action_release(&"move_up")
	# Off the top and onto the terrace it leans against.
	var arrived := false
	for _frame in range(120):
		await physics_frame
		if player.global_position.x > 3340.0 and player.global_position.y < 120.0:
			arrived = true
			break
	Input.action_release(&"move_right")
	_check(arrived, "and the player climbs to the bale",
		"reached the Overlook" if arrived
		else "STILL BELOW at %s -- the last stretch is a wall" % player.global_position.round())


## Hold right, tap jump, the way a person does it. Polled input, so the actions are held
## through the Input singleton rather than fed as events.
func _run_at_the_stair() -> bool:
	Input.action_press(&"move_right")
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
		if bool(player.call("is_on_floor")) and player.global_position.y <= tread_top + 2.0:
			arrived = true
			break
	Input.action_release(&"move_right")
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


## On the bank below the gap, standing still.
func _stand_on_the_bank() -> void:
	player.set("velocity", Vector2.ZERO)
	player.global_position = Vector2(740.0, bank_top - 40.0)
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
