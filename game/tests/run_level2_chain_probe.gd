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
	await _audit_a_key_drawn_at_the_lit_door_is_judged()
	await _audit_the_church_is_shut_until_the_candle()
	await _audit_the_lit_house_hands_over_the_candle()
	await _audit_a_shut_door_stops_talking()
	await _audit_the_way_back_works()
	await _audit_scene_2_happens()
	await _audit_the_chain_runs_to_alley_2()
	if not OS.get_cmdline_user_args().has("--church"):
		await _audit_no_path_loses_a_scrap()
		await _audit_the_dancers_do_not_come_back()

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


## Wait for an alley's choice to come up, and answer it. False if it never came.
func _answer_the_alley(route: String, on: Node = null) -> bool:
	var host := on if on != null else level
	var choice := host.get_node_or_null(^"DialogueChoiceOverlay")
	for _frame in range(600):
		if choice != null and bool(choice.call("is_open")):
			choice.call("_on_route_pressed", route)
			for _settle in range(10):
				await physics_frame
			return true
		await physics_frame
	return false


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
	_check(doors.size() == 2, "the two live entrances are on the plaza", "%d built" % doors.size())
	var space := (level as Node2D).get_world_2d().direct_space_state
	var floating: Array[String] = []
	var ids: Array[String] = []
	for node in doors:
		var door := node as PiyestaDoor2D
		ids.append(door.door_id)
		var from := door.global_position - Vector2(0.0, 40.0)
		var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 300.0))
		query.collision_mask = 1
		if space.intersect_ray(query).is_empty():
			floating.append("%s over nothing" % door.door_id)
	_check(floating.is_empty(), "and every one of them stands on it",
		"2 doorsteps" if floating.is_empty() else "; ".join(floating))
	_check(ids.has("lit_house") and ids.has("church"),
		"and neither removed decoy keeps an invisible trigger",
		", ".join(ids))
	var lit := 0
	for node in doors:
		if (node as PiyestaDoor2D).lit:
			lit += 1
	_check(lit == 1, "and the house still has its identifying light",
		"%d lit entrance" % lit)


## ⚠ THE LIT HOUSE STOOD OUTSIDE THE BEAT IT BELONGS TO. "Something that can unlock gets you
## in", Lolo says, and the natural thing to do is walk to that door and draw one. The door was
## at x 1060 and Problem 1's volume ends at 980 -- so a player standing at it was standing at
## no obstacle, and `_judge_submission` is SILENT at no obstacle by design. The key appeared,
## nothing happened and nothing was said. Every probe that solves this route calls
## `enter_obstacle` directly, which is why none of them could see it.
func _audit_a_key_drawn_at_the_lit_door_is_judged() -> void:
	var door := _door("lit_house")
	var director = level.get("director")
	if door == null or director == null:
		_check(false, "the lit house and the director exist", "-")
		return
	var before := player.global_position
	player.global_position = door.global_position + Vector2(0.0, -60.0)
	for _frame in range(12):
		await physics_frame
	_check(String(director.call("current_obstacle")) == "L2_N1",
		"standing at the lit house is standing at Problem 1",
		"judged as %s" % (String(director.call("current_obstacle"))
			if not String(director.call("current_obstacle")).is_empty() else "NOTHING -- a key here is silent"))
	player.global_position = before
	for _frame in range(12):
		await physics_frame


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
	var hint_bar = level.get("hint_bar")
	var shown := String(hint_bar.call("current_text")) if hint_bar != null else ""
	_check(shown == door.prompt(), "and approaching it shows the church prompt",
		shown if not shown.is_empty() else "the hint bar stayed empty")
	# Pressed, and it must refuse: E at a shut door is the level's own rule, not a bug.
	var used: bool = bool(level.call("_interact_with_level"))
	_check(not used and _room_name() == "plaza", "pressing E at it does nothing yet",
		"still on the %s" % _room_name())

	level.call("_hold_the_kandila")
	_check(door.open, "the candle opens it", "one door for all three routes")
	# ⚠ WITH LOLO'S LINE LEFT UP, the way a player meets it. Walking in fires a line, a line in
	# the box pauses the game, and a room shows itself from `_process` -- so the church stayed
	# undrawn behind the box and the apo stood in the empty sky it is parked in.
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", false)
	used = bool(level.call("_interact_with_level"))
	for _frame in range(12):
		await process_frame
	var church := level.get("church") as CanvasItem
	_check(paused and church != null and church.visible, "and the church is drawn while Lolo speaks",
		"behind the box" if paused and church != null and church.visible
			else "not drawn -- the apo stands in the sky" if paused
			else "nothing paused: the line this is about never came")
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	call_group(DialogueBox.GROUP, &"hide_line")
	paused = false
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


## ⚠ A SENTENCE THAT NEVER COMES DOWN, which is the one kind of defect no other check here
## can see. Every room carries an `onward_note` for its shut far door, and it goes on the hint
## bar as a STANDING prompt -- no dwell, no fade. `PiyestaRoom2D` declared `notice_left` from
## the first day and never emitted it, and the base class's clearer only recognised Level 1's
## two interiors by name, so "Not yet -- the kandila first" followed the player out of the
## church, across the plaza, through both alleys and into the dance. Nothing failed. Nothing
## looked wrong in a frame taken anywhere but the hint bar.
func _audit_a_shut_door_stops_talking() -> void:
	var church := level.get("church") as PiyestaRoom2D
	var bar: Node = level.get("hint_bar") as Node
	if church == null or bar == null or _room_name() != "ChurchInterior":
		_check(false, "the apo is in the church to try its far door", _room_name())
		return
	_check(not church.onward_note.is_empty(), "the church's far door has something to say",
		church.onward_note)
	var onward := Rect2(church.call("onward_rect"))
	await _stand_at(church.global_position + onward.get_center())
	for _frame in range(10):
		await physics_frame
	_check(String(bar.call("current_text")) == church.onward_note,
		"walking into it says why it is shut", "'%s'" % bar.call("current_text"))
	# AND THEN AWAY AGAIN. The note is a standing prompt: if leaving does not take it down,
	# nothing else will until some other beat happens to write over it.
	# The centre now falls within reach of the supplied rack. Use clear aisle instead.
	var away := church.global_position + Vector2(-350.0, -40.0)
	var chancel := level.get("chancel") as ChurchInterior2D
	_check(absf(away.x - chancel.rack_point().x) > 150.0,
		"harness: the quiet spot is clear of the rack", str(away))
	await _stand_at(away)
	for _frame in range(10):
		await physics_frame
	# ⚠ ASSERTED ON `is_showing`, NOT ONLY ON THE TEXT. `clear()` fades the panel and leaves
	# the label alone, so a check that only read `current_text` would have gone on failing
	# after the fix landed -- and a check that only read it before the fix would have passed
	# on the first frame of a fade that never came.
	_check(not bool(bar.call("is_showing")), "and walking away takes it off the bar again",
		"the bar is down" if not bool(bar.call("is_showing"))
			else "still showing '%s'" % bar.call("current_text"))
	_check(String(bar.call("current_text")).is_empty(),
		"and it stops reporting what it used to say",
		"'%s'" % bar.call("current_text"))


## The second half of the level, end to end. Both alleys are shut until the beat before
## them is answered, so this walks the arming as well as the passage.
func _audit_the_chain_runs_to_alley_2() -> void:
	var church := level.get("church") as PiyestaRoom2D
	var alley_1 := level.get("alley_1") as PiyestaRoom2D
	var alley_2 := level.get("alley_2") as PiyestaRoom2D
	if church == null or alley_1 == null or alley_2 == null:
		_check(false, "the level has both alleys", "one of the rooms is missing")
		return
	_check(church.onward_open and not alley_1.onward_open,
		"the church is open and the first alley is not",
		"Scene 2 opened one door and no more")

	# Back into the church, and out the far end. NOT re-opened here: it was opened by the
	# priest in the audit above, which is the only thing that may open it.
	await _stand_at(church.entry_point())
	await _stand_at(church.global_position + Rect2(church.onward_rect()).get_center())
	for _frame in range(16):
		await physics_frame
	_check(_room_name() == "Alley1", "the church's far door reaches the first alley",
		"the apo is in the %s" % _room_name())
	# ⚠ AND THE ALLEY ASKS HOW, the moment the apo is in it. The choice is a modal, so it has to
	# be answered before anything after it can run -- it is what the player meets first.
	_check(await _answer_the_alley("artist"), "and the first alley asks how, at the way in",
		"the choice is up")

	alley_1.open_onward()
	await _stand_at(alley_1.global_position + Rect2(alley_1.onward_rect()).get_center())
	for _frame in range(16):
		await physics_frame
	_check(_room_name() == "Alley2", "and the first alley reaches the second",
		"the apo is in the %s" % _room_name())
	_check(await _answer_the_alley("artist"), "and the second asks how too", "the choice is up")

	# ⚠ AND THE FAR DOOR OF ALLEY 2 IS SCENE 3, NOT A FOURTH ROOM. The chain of places ends
	# here and becomes a table with seven pieces on it.
	alley_2.open_onward()
	await _stand_at(alley_2.global_position + Rect2(alley_2.onward_rect()).get_center())
	for _frame in range(16):
		await physics_frame
	var table := level.get("assembly_screen") as AssemblyOverlay
	_check(table != null and table.is_open(), "and the second alley opens Scene 3",
		"the chain of rooms ends and the assembly begins")
	_check(_room_name() == "Alley2", "without moving the player anywhere",
		"Scene 3 is an overlay, not a room")
	# ⚠ CLOSED AGAIN BEFORE ANYTHING ELSE RUNS. It is a modal, so leaving it up leaves the
	# TREE PAUSED -- and every audit after this one then measures a world where `_process`
	# never ticks. That is the failure mode the notes describe as "a stale path in a test can
	# look like twenty-seven engine failures", and it cost two green checks the first time.
	if table != null and table.is_open():
		table.close()
	for _frame in range(6):
		await physics_frame
	_check(not paused, "and closing it gives the world back",
		"nothing after this runs frozen")


## SCENE 2, PLAYED RATHER THAN ASSERTED. The design calls the priest's line "the only
## signpost for the second half of the level", and the way to both alleys is behind it. So
## the question is not whether `open_onward()` works -- it is whether anything ever calls it.
##
## It also carries the cultural guardrail, because that is a claim the level config makes
## about running code: sacred images have no collision, no interaction and no puzzle
## function, and the altar is reachable to place the kandila AND FOR NOTHING ELSE.
func _audit_scene_2_happens() -> void:
	var church := level.get("church") as PiyestaRoom2D
	var chancel := level.get("chancel") as ChurchInterior2D
	if church == null or chancel == null:
		_check(false, "the church is furnished", "no chancel")
		return

	# ⚠ THE GUARDRAIL. Asserted against the running tree, not against the source.
	var sacred := level.get_tree().get_nodes_in_group(&"sacred_images")
	var armed: Array[String] = []
	for node in sacred:
		for child in (node as Node).get_children():
			if child is CollisionObject2D or child is CollisionShape2D:
				armed.append("%s has %s" % [node.name, child.get_class()])
	_check(armed.is_empty(), "nothing sacred in here can be touched",
		"the retablo and the santo are drawn, not built" if armed.is_empty()
		else "; ".join(armed))
	var volumes := 0
	for child in chancel.get_children():
		if child is Area2D:
			volumes += 1
	_check(volumes == 1, "and the rack is the room\'s only approach volume",
		"%d volume(s) -- one on the altar would make the altar interactive" % volumes)
	_check(chancel.guardrail_holds(), "which is what the room says of itself",
		"level_02.json cultural_constraints.church, enforced in code")

	# The nave is furnished from the room, so the pews cannot outgrow the church.
	_check(is_equal_approx(chancel.nave_length, church.room_length),
		"the furniture is measured off the room", "%.0fpx of nave" % chancel.nave_length)
	var rack_in := Rect2(church.call("bounds")).grow(40.0).has_point(chancel.rack_point())
	_check(rack_in, "and the rack stands inside it", "left of the altar, against the wall")
	# These are measured on the packed artwork, independently of rack_point / exit_rect.
	var art_origin := church.global_position + Vector2(-1036.0, -790.0)
	_check(chancel.rack_point().distance_to(art_origin + Vector2(950.0, 790.0)) < 1.0,
		"the rack trigger follows the supplied rack", "source x 950, aisle row 790")
	_check(absf(church.to_local(art_origin + Vector2(204.0, 790.0)).x
		- church.exit_rect().get_center().x) < 1.0
		and absf(church.to_local(art_origin + Vector2(1868.0, 790.0)).x
		- church.onward_rect().get_center().x) < 1.0,
		"both painted doors own their live openings", "door centres 204 and 1868")
	var art_bounds := Rect2(art_origin + Vector2(0.0, 70.0), Vector2(2072.0, 820.0))
	_check(art_bounds.encloses(church.camera_rect()),
		"the church camera stays inside the supplied art", str(church.camera_rect()))

	await _stand_at(church.entry_point())
	_check(not church.onward_open, "the way to the alleys starts shut",
		"the priest has not spoken")
	await _stand_at(chancel.rack_point())
	_check(chancel.standing_at_rack(), "the rack notices somebody at it", "reach armed")
	var box: DialogueBox = level.get("dialogue_box")
	# Let any entry conversation finish before pressing E; input must honour modal pause.
	for _tick in range(30):
		if not box.is_open() and not paused:
			break
		await create_timer(0.1, true).timeout
	_check(not paused, "harness: the candle press is not under a modal", str(paused))
	# Conversations ON from here, so what the box shows can be read -- see below.
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", false)
	# Use this level's E handler (including pick-up priority), not the candle API.
	# run_visual_level2 --church additionally pushes the key through a real viewport.
	level.call("press_interact")
	_check(chancel.kandila_on_rack, "and E puts the candle on it",
		"Scene 2\'s one action")
	# ⚠ AND IT IS NO LONGER IN HAND. A candle placed and still carried would let the player
	# put it on the rack again, and would leave Problem 1 permanently solved for a rerun.
	_check(not bool(level.get("_has_kandila")), "which is no longer in hand",
		"placed, not copied")

	# Lolo speaks about the light, then the priest crosses the nave. Both are on real clocks --
	# the design asks for this scene to breathe -- so this waits them out rather than poking
	# past them.
	var lolo_said := ""
	for _frame in range(900):
		if church.onward_open:
			break
		if box.is_open():
			if lolo_said.is_empty():
				lolo_said = "%s: %s" % [box.current_speaker(), box.current_line()]
			box.hide_line()
		await physics_frame
	_check(church.onward_open, "the priest walks over and names the alleys",
		"and that is what opens the way on")
	_check(lolo_said.begins_with("Lolo:") and lolo_said.contains("burn"),
		"Lolo speaks about the light, and only that", "\"%s\"" % lolo_said)
	# ⚠ THE PRIEST SAYS IT, AS HIMSELF. His lines were printed under the APO's name, with the
	# apo's face above them and the camera on the apo -- the child telling himself where his
	# grandmother went. Read off the box on the frame he starts speaking.
	var said := "%s: %s" % [box.current_speaker(), box.current_line()] if box.is_open() else ""
	_check(said.begins_with("Padre:") and said.contains("She was here"),
		"and the priest is the one who says where she went", "\"%s\"" % said)
	var subject = level.call("_speaker_subject", "priest")
	_check(subject != null and subject == chancel.priest_figure(),
		"with the camera on him while he does", "subject %s" % subject)
	var gap := absf(chancel.priest_point().x - player.global_position.x)
	_check(chancel.priest_has_arrived() and gap <= ChurchInterior2D.PRIEST_STAND_OFF + 24.0,
		"having walked up to the apo rather than to a spot", "%.0f px from it" % gap)
	box.hide_line()
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	var checkpoints = level.get("checkpoints")
	_check(checkpoints != null and bool(checkpoints.call("has_checkpoint")),
		"and CP2 is written before the alleys", "a player who dies down there keeps this")


## THE ONE PROMISE THE WHOLE SCRAP ECONOMY RESTS ON: none of the seven can be permanently
## lost. `run_level2_systems_probe` proves every way down puts every piece on the floor, and
## `run_level2_alley_probe` plays each way in each alley. This asks the harder question --
## whether the LEVEL, which is what actually connects them, keeps it on every road to the table.
##
## Nine roads: three ways through Alley 1 and the same three through Alley 2, freely combined.
## Every one has to arrive at the table holding seven, with nothing counted that was not walked
## over. Each alley is answered through its own choice and brought down by its own route; the
## throwing route's birds are knocked down one by one, which is what that route is.
func _audit_no_path_loses_a_scrap() -> void:
	# ⚠ THE LEVEL THE CHAIN WAS WALKED IN GOES FIRST. Every Piyesta built in one tree shares one
	# world, so its alleys stand exactly where a fresh one's do -- and a room is found by where
	# the player is, so the fresh level's apo was found standing in the OLD level's alley, and
	# nothing it walked over was ever counted. Nothing after this needs that level.
	if level != null and is_instance_valid(level):
		level.queue_free()
		await process_frame
		await process_frame
	for first in ["artist", "pragmatist", "protector"]:
		for last in ["artist", "pragmatist", "protector"]:
			var held := await _walk_the_scraps(first, last)
			_check(held == ScrapLedger.TOTAL, "%s then %s reaches the table with all seven"
				% [first, last], "%d of %d" % [held, ScrapLedger.TOTAL])


## One run of the second half of the level, the two alleys answered by the routes given, and
## counted at the table. -1 if the table never opened.
func _walk_the_scraps(alley_1_route: String, alley_2_route: String) -> int:
	var fresh := (load("res://level_2.tscn") as PackedScene).instantiate()
	(fresh.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(fresh)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(20):
		await physics_frame
	fresh.set("_has_kandila", true)
	(fresh.get("chancel") as ChurchInterior2D).kandila_on_rack = true
	var church := fresh.get("church") as PiyestaRoom2D
	church.open_onward()
	fresh.call("_go_onward", church)
	for _frame in range(20):
		await physics_frame
	await _bring_the_flock_down(fresh, "L2_N2", alley_1_route)
	fresh.call("_go_onward", fresh.get("alley_1"))
	for _frame in range(20):
		await physics_frame
	await _bring_the_flock_down(fresh, "L2_N3", alley_2_route)
	# The far door of Alley 2 is the table, and it opens only once both alleys are done.
	fresh.call("_go_onward", fresh.get("alley_2"))
	for _frame in range(6):
		await physics_frame
	var table := fresh.get("assembly_screen") as AssemblyOverlay
	var ledger = fresh.get("ledger")
	var held: int = int(ledger.call("held")) if table != null and table.is_open() else -1
	if table != null and table.is_open():
		table.close()
	fresh.queue_free()
	await physics_frame
	await physics_frame
	paused = false
	return held


## Answer an alley by `route` and bring its flock down, then walk over every piece it dropped.
func _bring_the_flock_down(host: Node, obstacle_id: String, route: String) -> void:
	if not await _answer_the_alley(route, host):
		return
	var director = host.get("director")
	var alley = (host.get("_alleys") as Dictionary)[obstacle_id]
	var birds: Array = alley.get("birds")
	if route == "protector":
		# The route is every bird knocked down; the throw that does it is played elsewhere.
		for bird: ScrapBird2D in birds:
			bird.strike_down()
	else:
		# Fed, or cut down: answered the way the director records an answer, and the level does
		# what that route does with the flock.
		director.solve_with_item(obstacle_id, "probe")
	for _frame in range(600):
		if (alley.get("dropped") as Dictionary).size() >= birds.size():
			break
		await physics_frame
	var body := host.get("player") as Node2D
	for _i in range(20):
		var pieces: Dictionary = alley.get("pieces")
		if pieces.is_empty():
			break
		var piece: Node2D = pieces.values()[0]
		body.global_position = Vector2(piece.global_position.x, body.global_position.y)
		for _frame in range(6):
			await physics_frame


## THE ONE DESTRUCTIVE ACT IN PIYESTA, and the only thing the player can take from it that
## the level will not give back. Nothing is blocked by their going, which is exactly why it
## has to actually be permanent -- a cost that quietly undoes itself is not a cost.
func _audit_the_dancers_do_not_come_back() -> void:
	var fresh := (load("res://level_2.tscn") as PackedScene).instantiate()
	(fresh.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(fresh)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(20):
		await physics_frame
	var group := fresh.get("dancers") as DancerGroup2D
	if group == null:
		_check(false, "the plaza has dancers to scare", "no group")
		fresh.queue_free()
		return
	_check(group.state() == DancerGroup2D.State.DANCING, "the dancers start dancing",
		"%d of them" % group.dancers)
	fresh.call("_on_route_solved", "L2_N1", "protector")
	_check(group.state() == DancerGroup2D.State.FLEEING, "and the scare sends them off",
		"they run rather than vanish")
	# ⚠ AND THE CANDLE COMES WITH IT. The level is unloseable: whichever way Problem 1 is
	# answered, the kandila is in hand and the church opens.
	_check(bool(fresh.get("_has_kandila")), "and the kandila is still handed over",
		"the level cannot dead-end on this route")
	for _frame in range(240):
		if group.are_gone():
			break
		await physics_frame
	_check(group.are_gone(), "and they finish leaving", "the plaza is empty")
	# There is no unscatter, deliberately, and this is the assertion that keeps it that way.
	_check(not group.scatter(), "and nothing can bring them back",
		"scatter() refuses a second time -- there is no other door")
	var script_lines = fresh.get("script_lines")
	_check(script_lines != null and bool(script_lines.call("is_flag_set", "dancers_gone")),
		"and the level records it", "DANCERS_GONE, for every scene after this")
	fresh.queue_free()
	await physics_frame
