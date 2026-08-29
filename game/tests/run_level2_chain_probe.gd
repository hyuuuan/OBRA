extends SceneTree
## Piyesta is a CHAIN, and this asks whether the chain is joined.
##
##	 godot --headless --path game --script res://tests/run_level2_chain_probe.gd
##
## Level 1 is a walk east: everything in it is reachable by holding a direction. This level
## is not. Three of its four beats happen inside rooms parked thousands of units above the
## plaza, and the only things that carry a player between them are a door and two openings.
## `run_level2_scene_probe` measures those rooms -- their floors, their bounds, where they
## put a body down. It cannot tell you whether anybody can get into one.
##
## That distinction has already cost this project a level. `run_level1_audit` proved Beat 0
## ACCEPTED a square by calling `_judge_submission` and reading the director's answer, and
## the level was unplayable at the time, because every click aimed at the stair was landing
## in the inventory bar. Bookkeeping is not passage.
##
## So this one drives the body: stand at the door, press what a player presses, and look at
## where the body ends up.

var results: Array[String] = []
var failures := 0
var level: Node
var player: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	results.append("  %s  %-40s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	var packed := load("res://level_2.tscn") as PackedScene
	if packed == null:
		print("  FAIL  level_2.tscn does not load")
		print("OBRA_LEVEL2_CHAIN_FAILED=1")
		quit(1)
		return
	level = packed.instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	# A conversation stops the tree until somebody turns the page, and nobody is here to
	# press a key. Same guard `run_walk_level1` opens with.
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(30):
		await physics_frame
	player = level.get("player") as Node2D
	if player == null:
		print("OBRA_LEVEL2_CHAIN_FAILED=1  (no player)")
		quit(1)
		return

	print("\n===== LEVEL 2 CHAIN =====")
	_audit_the_doors_are_on_the_plaza()
	await _audit_the_church_is_shut_until_the_candle()
	await _audit_the_lit_house_hands_over_the_candle()
	await _audit_the_way_back_works()
	await _audit_the_chain_runs_to_alley_2()

	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_LEVEL2_CHAIN_OK")
		quit(0)
	else:
		print("OBRA_LEVEL2_CHAIN_FAILED=%d" % failures)
		quit(1)


func _doors() -> Array[Node]:
	return level.get_tree().get_nodes_in_group(&"piyesta_doors")


func _door(door_id: String) -> PiyestaDoor2D:
	for node in _doors():
		var door := node as PiyestaDoor2D
		if door != null and door.door_id == door_id:
			return door
	return null


## Put the body in front of something and let the physics server catch up, which is what
## arms an Area2D. Teleporting and asking in the same frame answers about the frame before.
func _stand_at(at: Vector2) -> void:
	player.call("apply_morph_state", {"position": at, "linear_velocity": Vector2.ZERO})
	for _frame in range(8):
		await physics_frame


## Where the player is, through the same door the level asks: `_room_holding_player` reads
## each room's own bounds rather than a flag, so this is the level's own answer and not a
## second opinion that can drift from it.
func _room_name() -> String:
	var room := level.call("_room_holding_player") as Node2D
	return room.name if room != null else "plaza"


## A door standing in mid-air is a door nobody reaches, and the marks it is built on are
## authored by hand.
func _audit_the_doors_are_on_the_plaza() -> void:
	var doors := _doors()
	_check(doors.size() == 4, "four doors on the plaza", "%d built" % doors.size())
	var space := (level as Node2D).get_world_2d().direct_space_state
	var floating: Array[String] = []
	for node in doors:
		var door := node as PiyestaDoor2D
		var from := door.global_position - Vector2(0.0, 40.0)
		var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 300.0))
		query.collision_mask = 1
		if space.intersect_ray(query).is_empty():
			floating.append("%s over nothing" % door.door_id)
	_check(floating.is_empty(), "and every one of them stands on it",
		"4 doorsteps" if floating.is_empty() else "; ".join(floating))
	# THE MISDIRECTION IS CONTENT. The design asks for the lit house to sit past two or
	# three dark doors so the search reads as a search; if all four opened, or if only one
	# existed, there would be nothing to search.
	var lit := 0
	for node in doors:
		if (node as PiyestaDoor2D).lit:
			lit += 1
	_check(lit == 1, "and exactly one of them has a light on inside",
		"%d lit, %d dark" % [lit, doors.size() - lit])


## THE CHURCH IS THE LEVEL'S SECOND HALF, and the candle is what buys it. A church that
## opens before the kandila skips Problem 1 entirely -- the player could walk past the
## dancers, into the church, and on to the alleys having drawn nothing.
func _audit_the_church_is_shut_until_the_candle() -> void:
	var door := _door("church")
	if door == null:
		_check(false, "the church has a door", "no door with id church")
		return
	_check(not door.open, "the church starts shut", "no candle yet")
	await _stand_at(door.global_position + Vector2(-30.0, -40.0))
	_check(door.standing_here(), "and it notices somebody standing at it",
		"the reach volume armed")
	# Pressed, and it must refuse: E at a shut door is the level's own rule, not a bug.
	var used: bool = bool(level.call("_interact_with_level"))
	_check(not used and _room_name() == "plaza", "pressing E at it does nothing yet",
		"still on the %s" % _room_name())

	level.call("_hold_the_kandila")
	_check(door.open, "the candle opens it", "one door for all three routes")
	used = bool(level.call("_interact_with_level"))
	for _frame in range(12):
		await physics_frame
	_check(used and _room_name() == "ChurchInterior", "and now E steps through it",
		"the apo is in the %s" % _room_name())


## Path C's whole reason for existing. Committing that route means the drawn key imitated
## the lock -- the candle is still on a table in a room nobody has walked into yet, and if
## the commit granted it the room behind the door would be a corridor with nothing in it.
func _audit_the_lit_house_hands_over_the_candle() -> void:
	var fresh := (load("res://level_2.tscn") as PackedScene).instantiate()
	(fresh.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(fresh)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(30):
		await physics_frame
	var body := fresh.get("player") as Node2D
	var door: PiyestaDoor2D = null
	for node in fresh.get_tree().get_nodes_in_group(&"piyesta_doors"):
		var candidate := node as PiyestaDoor2D
		if candidate != null and candidate.door_id == "lit_house" and candidate.is_inside_tree() \
				and fresh.is_ancestor_of(candidate):
			door = candidate
	if body == null or door == null:
		_check(false, "the lit house has a door", "no door with id lit_house")
		fresh.queue_free()
		return
	_check(not door.open, "the lit house starts shut", "the key has not been drawn")
	_check(not bool(fresh.get("_has_kandila")), "and the candle is not in hand",
		"nothing granted at load")

	fresh.call("_on_route_solved", "L2_N1", "pragmatist")
	_check(door.open, "committing the key route opens it", "the lock imitated")
	# ⚠ AND THAT COMMIT MUST NOT HAVE HANDED OVER THE CANDLE. This is the assertion the
	# whole route turns on, and it is the one a future edit is most likely to break by
	# making `grants_item` fire for every route the way the level data reads as if it does.
	_check(not bool(fresh.get("_has_kandila")),
		"but it does NOT hand over the candle", "that is what the room is for")

	var house := fresh.get("house") as Node2D
	body.call("apply_morph_state",
		{"position": house.call("entry_point"), "linear_velocity": Vector2.ZERO})
	for _frame in range(10):
		await physics_frame
	var candle := house.get_node_or_null(^"Kandila") as Kandila2D
	_check(candle != null and candle.present, "the candle is on the table in there",
		"and the room is walked to reach it")
	# Walked into, not pressed. Same contract as the brass key in the heap.
	if candle != null:
		body.call("apply_morph_state",
			{"position": candle.global_position, "linear_velocity": Vector2.ZERO})
		for _frame in range(10):
			await physics_frame
	_check(bool(fresh.get("_has_kandila")), "and walking into it is what grants it",
		"Path C pays off inside the house")
	var church_door: PiyestaDoor2D = null
	for node in fresh.get_tree().get_nodes_in_group(&"piyesta_doors"):
		var candidate := node as PiyestaDoor2D
		if candidate != null and candidate.door_id == "church" \
				and fresh.is_ancestor_of(candidate):
			church_door = candidate
	_check(church_door != null and church_door.open,
		"which opens the church, exactly as the other two do",
		"one door, three routes")
	fresh.queue_free()
	await physics_frame


## A room you can enter and not leave is a trap, and the way out is the one thing a player
## cannot work around by drawing something.
func _audit_the_way_back_works() -> void:
	var church := level.get("church") as Node2D
	if church == null or _room_name() != "ChurchInterior":
		_check(false, "the apo is in the church to walk out of it", _room_name())
		return
	var back := Rect2(church.call("exit_rect"))
	await _stand_at(church.global_position + back.get_center())
	for _frame in range(16):
		await physics_frame
	_check(_room_name() == "plaza", "walking into the way back leaves the church",
		"the apo is on the %s" % _room_name())
	# AND IT PUTS THEM WHERE THEY CAME FROM, not at the spawn. Level 1's straw room put
	# people back inside the mouth they had just walked out of, which reads as the exit
	# being broken.
	var door := _door("church")
	_check(door != null and absf(player.global_position.x - door.global_position.x) < 260.0,
		"and beside the door they went in by",
		"%.0fpx from it" % absf(player.global_position.x - door.global_position.x)
		if door != null else "-")


## The second half of the level, end to end. Both alleys are shut until the beat before
## them is answered, so this walks the arming as well as the passage.
func _audit_the_chain_runs_to_alley_2() -> void:
	var church := level.get("church") as PiyestaRoom2D
	var alley_1 := level.get("alley_1") as PiyestaRoom2D
	var alley_2 := level.get("alley_2") as PiyestaRoom2D
	if church == null or alley_1 == null or alley_2 == null:
		_check(false, "the level has both alleys", "one of the rooms is missing")
		return
	_check(not church.onward_open and not alley_1.onward_open,
		"every way onward starts shut", "nothing is skippable")

	# Back into the church, and out the far end.
	await _stand_at(church.entry_point())
	church.open_onward()
	await _stand_at(church.global_position + Rect2(church.onward_rect()).get_center())
	for _frame in range(16):
		await physics_frame
	_check(_room_name() == "Alley1", "the church's far door reaches the first alley",
		"the apo is in the %s" % _room_name())

	alley_1.open_onward()
	await _stand_at(alley_1.global_position + Rect2(alley_1.onward_rect()).get_center())
	for _frame in range(16):
		await physics_frame
	_check(_room_name() == "Alley2", "and the first alley reaches the second",
		"the apo is in the %s" % _room_name())

	# ⚠ AND ALLEY 2 IS THE END OF IT. A fourth link would step the player into whatever
	# `_next_after` returns, and a null there used to be a silent no-op rather than a
	# deliberate end.
	alley_2.open_onward()
	await _stand_at(alley_2.global_position + Rect2(alley_2.onward_rect()).get_center())
	for _frame in range(16):
		await physics_frame
	_check(_room_name() == "Alley2", "and the chain stops there",
		"nothing past the second alley yet -- Scene 3 is an overlay, not a room")
