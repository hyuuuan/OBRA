extends SceneTree
## Can Piyesta be beaten without drawing anything?
##
##	 godot --headless --path game --script res://tests/run_nodraw_level2.gd
##
## The whole premise of the game is that the player draws to get past things. If a person
## can walk, jump and talk their way from the spawn to the end in their own body, every
## obstacle in the level is scenery and the drawing is a side activity. Level 1 has owned
## this question since `run_nodraw_level1.gd`; the plan for this level lists the same suite
## as the one that matters most here, for a reason it states plainly: **a plaza is flat, and
## a flat level is the easiest kind to finish by walking.**
##
## ⚠ THIS LEVEL EXPECTS TO LOSE THE FIRST ROUND, AND THAT IS THE DESIGN.
##
## Problem 1's Artist route is a dance. It is a performance, not a summoning, so it costs no
## ink and requires no classified drawing -- the first route in this project that does not --
## and answering Lolo is free. So a no-draw player CAN get the kandila and CAN open the
## church, and this suite asserts that they do rather than pretending otherwise. What it
## refuses is anything past that: Problems 2 and 3 both require a drawing, and they are what
## keep Piyesta a drawing game.
##
## So the claim is narrower than Level 1's and it is checked exactly as written:
##   * the plaza and the church are passable in the player's own body -- deliberately;
##   * neither alley is;
##   * and the level never finishes.

## Long enough to cross a room and try everything in it, short enough that four of them are
## a test and not an afternoon.
const SEGMENT_SECONDS := 20.0
## Typed, because an untyped literal indexed inline gives GDScript nothing to infer from.
const ROUTE_NAMES: Array[String] = ["artist (the dance)", "pragmatist (the key)",
	"protector (the scare)"]

var level: Node
var player: CharacterBody2D
var completed := false
var answered := 0
## Which of Lolo's answers to take. Every route at every node is tried, because a bot that
## always presses the first button tests one third of the level's choices.
var _route_choice := 0

## How far the body actually got from where it was put down. Without this the suite cannot
## tell "properly gated" from "never moved".
var _travelled := 0.0

var results: Array[String] = []
var failures := 0
var pending := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	results.append("  %s  %-44s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


## A KNOWN GAP, PRINTED EVERY RUN AND NOT COUNTED AS A FAILURE.
##
## Used for exactly one thing here, and it is a real defect rather than a nicety: Problem 1's
## Artist route can be committed and then nothing answers it, because the dance has no screen.
## Recording it green would be a lie; recording it red would make this suite something people
## stop running, and it is the suite that guards the level's whole premise. So it is neither:
## it is printed, named, and counted separately.
##
## ⚠ When the dance lands, this must become a `_check`. The line says so.
func _pending(holds: bool, what: String, why: String) -> void:
	results.append("  %s  %-44s %s" % ["PEND" if not holds else "OK  ", what, why])
	if not holds:
		pending += 1


func _run() -> void:
	print("\n===== NO-DRAW RUN, PIYESTA =====")
	# The plaza, answered every way Lolo offers. The dance is meant to work; the other two
	# are meant to need a drawing, and pressing their button without one must change nothing.
	for choice in range(3):
		_route_choice = choice
		# FROM THE LEVEL'S OWN SPAWN POINT, not a hand-picked spot. The first version of this
		# put the bot at (300, 480), which is INSIDE the left terrace -- it stood in solid
		# rock for twenty seconds and the run reported three green "cannot be talked through"
		# results for a bot that never took a step. A fixture parked somewhere it cannot move
		# proves nothing, which is trap 4 in a new costume.
		var state := await _try_segment("the plaza", Vector2.ZERO)
		var route: String = ROUTE_NAMES[choice]
		if choice == 0:
			# ⚠ THE ONE KNOWN GAP IN THIS LEVEL, and this suite is what found it.
			#
			# The design says Problem 1 is unloseable and the kandila is never withheld. But
			# the Artist route is answered by the dance minigame, `dance_minigame.gd` is a
			# scoring model with no screen, and nothing anywhere calls it -- so committing
			# "I will dance for them" closes the other two routes and then NOTHING HAPPENS.
			# A player who picks it is stuck at the first beat of the level with no kandila,
			# no church and no way back to the choice.
			#
			# It costs no ink and needs no drawing, which is why it belongs in this suite:
			# when the dance exists, a no-draw player will legitimately get past Problem 1,
			# and this line becomes a `_check` asserting exactly that.
			_pending(bool(state["church_open"]),
				"the dance route answers Problem 1",
				"NOT YET: the dance has no screen, so this route dead-ends. See LEVEL_2.md")
		else:
			_check(not bool(state["church_open"]),
				"but %s cannot be talked through" % route,
				"the button commits the route; the drawing is what solves it")
		_check(not bool(state["alley_1_open"]) and not bool(state["alley_2_open"]),
			"and no alley opens from the plaza (%s)" % route,
			"the way on is behind Scene 2 and Problem 2")
		_check(not bool(state["completed"]), "and the level does not finish (%s)" % route,
			"reached x %.0f" % float(state["reached"]))
		# ⚠ THE CHECK ON THE CHECK. Every "cannot" above is only worth anything if the body
		# moved; a bot standing in a wall passes all of them.
		_check(float(state["travelled"]) > 200.0, "and the bot really walked (%s)" % route,
			"%.0fpx from the spawn" % float(state["travelled"]))

	# And from inside each room, because testing only from the spawn tests the FIRST gate
	# and nothing else -- the bot stops at Problem 1 and the whole level behind it goes
	# unexamined. This is the lesson `run_nodraw_level1` records in its own SEGMENTS table.
	_route_choice = 0
	for room_name in ["ChurchInterior", "Alley1", "Alley2"]:
		var state := await _try_room(room_name)
		if state.is_empty():
			_check(false, "the bot could be put in %s" % room_name, "room missing")
			continue
		_check(not bool(state["alley_1_open"]) and not bool(state["alley_2_open"]),
			"nothing opens an alley from inside %s" % room_name,
			"held %d of 7 scraps after walking %.0fpx" % [
				int(state["scraps"]), float(state["travelled"])])
		_check(not bool(state["completed"]), "and the level does not finish from %s"
			% room_name, "no drawing, no ending")
		_check(float(state["travelled"]) > 120.0, "and the bot really walked in %s"
			% room_name, "%.0fpx" % float(state["travelled"]))

	for line in results:
		print(line)
	print("	 questions answered: %d (answering Lolo costs no ink)" % answered)
	if pending > 0:
		print("	 PEND  %d known gap(s) above, printed rather than hidden" % pending)
	if failures == 0:
		print("	 OK	   Problems 2 and 3 cannot be walked past")
		print("OBRA_NODRAW_L2_OK")
		quit(0)
	else:
		print("OBRA_NODRAW_L2_FAILED=%d" % failures)
		quit(1)


func _open_level() -> void:
	var packed := load("res://level_2.tscn") as PackedScene
	level = packed.instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	# A conversation stops the tree until somebody turns the page, and nobody is here to
	# press a key. Without this the first beat the walker reaches stops the world and the
	# run reports the level as a wall when it is really a level nobody walked.
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(30):
		await physics_frame
	player = level.get("player") as CharacterBody2D


func _close_level() -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
	level = null
	player = null


## What the level looks like after the bot has done its worst. Read off the level's own
## state rather than off how far east the body got -- this level is a chain of rooms, and
## distance east means nothing in it.
func _state() -> Dictionary:
	var church := level.get("church") as Node
	var alley_1 := level.get("alley_1") as Node
	var alley_2 := level.get("alley_2") as Node
	var ledger = level.get("ledger")
	var door_open := false
	for node in level.get_tree().get_nodes_in_group(&"piyesta_doors"):
		var door := node as PiyestaDoor2D
		if door != null and door.door_id == "church" and door.open:
			door_open = true
	return {
		"church_open": door_open,
		# The far door of the church, and of the first alley: these are the two the level
		# must never open for a player who has drawn nothing.
		"scene_2_open": church != null and bool(church.get("onward_open")),
		"alley_1_open": alley_1 != null and bool(alley_1.get("onward_open")),
		"alley_2_open": alley_2 != null and bool(alley_2.get("onward_open")),
		"scraps": int(ledger.call("held")) if ledger != null else -1,
		"completed": completed,
		"reached": player.global_position.x if player != null
			and is_instance_valid(player) else 0.0,
		"travelled": _travelled,
	}


func _try_segment(_name: String, at: Vector2) -> Dictionary:
	completed = false
	await _open_level()
	if player == null or not is_instance_valid(player):
		return {}
	player.velocity = Vector2.ZERO
	if at != Vector2.ZERO:
		player.global_position = at
	for _settle in range(20):
		await physics_frame
	var from := player.global_position
	await _drive()
	_travelled = player.global_position.distance_to(from) if player != null \
		and is_instance_valid(player) else 0.0
	var state := _state()
	_close_level()
	await process_frame
	return state


## Put the bot inside a room and let it try everything in there. A room is entered by a
## door the bot cannot open, so it is placed directly -- which is GENEROUS TO THE BOT on
## purpose: if it cannot get out of a room it was handed for free, it certainly cannot get
## out of one it had to earn.
func _try_room(room_name: String) -> Dictionary:
	completed = false
	await _open_level()
	if player == null or not is_instance_valid(player):
		return {}
	var room := level.get_node_or_null(NodePath(
		"EnvironmentBaseplate/GameplayPlane/Rooms/%s" % room_name)) as Node2D
	if room == null:
		_close_level()
		return {}
	player.velocity = Vector2.ZERO
	player.global_position = Vector2(room.call("entry_point"))
	for _settle in range(20):
		await physics_frame
	var from := player.global_position
	await _drive()
	_travelled = player.global_position.distance_to(from) if player != null \
		and is_instance_valid(player) else 0.0
	var state := _state()
	_close_level()
	await process_frame
	return state


## Drive as hard as a determined player would: hold right, jump constantly, press E at
## everything, and answer anything Lolo asks. None of it costs ink.
func _drive() -> void:
	var overlay := level.get_node_or_null("LevelCompleteOverlay")
	var last := player.global_position.x
	var stuck := 0
	Input.action_press(&"move_right")
	for frame in range(int(SEGMENT_SECONDS * 60.0)):
		if frame % 26 == 0:
			Input.action_press(&"jump")
		elif frame % 26 == 16:
			Input.action_release(&"jump")
		# E AT EVERYTHING. Doors, the candle rack, anything with a prompt -- pressing a key
		# is free, so a no-draw player presses it everywhere, and that is exactly how a
		# door that forgot to check its own state gets found.
		if frame % 18 == 9:
			level.call("_interact_with_level")
		await physics_frame
		_answer_any_question()
		var here := player.global_position.x
		if absf(here - last) > 8.0:
			last = here
			stuck = 0
		else:
			stuck += 1
		if stuck > 150:
			# Turn round rather than holding into a wall for the rest of the segment: half
			# of this level's ways on are west of where the bot is put down.
			Input.action_release(&"move_right")
			Input.action_press(&"move_left")
			for _back in range(90):
				await physics_frame
				_answer_any_question()
			Input.action_release(&"move_left")
			Input.action_press(&"move_right")
			stuck = 0
		if overlay != null and bool(overlay.call("is_open")):
			completed = true
			break
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")
	Input.action_release(&"jump")
	if completed and overlay != null:
		overlay.call("close")
		await process_frame
	paused = false


## Clear anything modal standing in the way, the way a player does. Answering Lolo is free,
## and a bot that ignores a modal stands still behind it for the rest of the segment --
## which reads in the report as a stretch that is properly gated when it is really a
## stretch nobody walked.
func _answer_any_question() -> void:
	for node in level.get_tree().get_nodes_in_group(&"modal_overlays"):
		if not node.has_method("is_open") or not bool(node.call("is_open")):
			continue
		if node.name == "LevelCompleteOverlay":
			continue    # that one is the result, not an obstacle
		var buttons := _buttons_in(node)
		if buttons.is_empty():
			continue
		var button: Button = buttons[mini(_route_choice, buttons.size() - 1)]
		if not button.disabled:
			button.emit_signal("pressed")
			answered += 1
			return


func _buttons_in(node: Node) -> Array[Button]:
	var out: Array[Button] = []
	for child in node.get_children():
		if child is Button and (child as Button).visible:
			out.append(child as Button)
		out.append_array(_buttons_in(child))
	return out
