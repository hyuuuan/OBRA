extends SceneTree
## Can Dagat be crossed without drawing anything?
##
##   godot --headless --path game --script res://tests/run_nodraw_level3.gd
##
## The whole premise of the game is that the player draws to get past things. If a person can
## walk, jump and talk their way from the spawn to the far sand in their own body, every
## obstacle in the level is scenery. Level 1 has owned this question since
## run_nodraw_level1.gd and LEVEL_TEMPLATE.md calls it the single most important test in the
## project.
##
## DAGAT'S CLAIM IS THE STRONGEST OF THE THREE, and it rests on one fact: THE APO CANNOT
## SWIM. Between the shore and everything else is a thousand pixels of open water, and the
## only way across is to be something that can cross it. So unlike Piyesta -- where the dance
## legitimately answers a whole route with no drawing -- there is no no-draw path here at
## all, and both of Dagat's forks are behind the sea rather than in front of it.
##
## ⚠ TWO ROUTES IN THIS LEVEL ARE `answered_by` RATHER THAN DRAWINGS: the boat is found, and
## slipping past the bakunawa is not a summoning. On their own that is a path through the
## level with nothing drawn -- find the boat, steer wide, arrive. What closes it is the
## shore: L3_B0_SHORE is a tutorial beat requiring a Swim answer, it sits between the spawn
## and the water, and there is no way around it. **That is what makes Dagat a drawing game,
## and it is why the practice beat is at the waterline rather than on dry sand.** If this
## file ever goes red at "the sea cannot be waded", check that first.
##
## ⚠ KNOWN GAP, PRINTED EVERY RUN AND NOT COUNTED AS A PASS. The island, the exit and the
## level-complete beat are not built yet, so "the level does not finish" is currently true
## for a duller reason than it will be. It is still checked -- a level that completes itself
## by accident is worth catching -- but it does not yet prove what it will prove.

## Long enough to walk the shore end to end and try the water several times.
const SEGMENT_SECONDS := 22.0
const ROUTE_NAMES: Array[String] = ["the first answer", "the second answer"]

## Where the sea begins, and where the far sand does. Read off the scene in _open_level so a
## moved waterline cannot leave this asserting against a coastline that is not there.
var _waterline_y := 560.0
var _island_x := 4500.0

var level: Node
var player: CharacterBody2D
var completed := false
var answered := 0
var _route_choice := 0
var _travelled := 0.0
## The furthest east the body ever got. NOT its position when the segment ended: the apo
## wades in, is carried out and wades in again, so the final x is wherever that cycle
## happened to be on the last frame and says nothing about how far it reached.
var _furthest := -INF
## The deepest the body got below the waterline at any point in the segment. The interesting
## number: a rescue that works looks like a small one, and a rescue that does not looks like
## a body on the seabed.
var _deepest := 0.0

var results: Array[String] = []
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	results.append("  %s  %-46s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	print("\n===== NO-DRAW RUN, DAGAT =====")

	# From the level's own spawn point, answering the fork both ways. A bot that always
	# presses the first button tests half of this level's choices.
	for choice in range(2):
		_route_choice = choice
		var state := await _try_segment(Vector2.ZERO)
		if state.is_empty():
			_check(false, "the bot could be spawned", "no player")
			continue
		var route: String = ROUTE_NAMES[choice]
		_check(not bool(state["crossed"]),
			"the sea cannot be crossed on foot (%s)" % route,
			"furthest east x %.0f, the far sand starts at %.0f"
				% [float(state["reached"]), _island_x])
		_check(not bool(state["shore_solved"]),
			"and the practice beat needs a drawing (%s)" % route,
			"the button commits a route; a drawing is what solves it")
		_check(not bool(state["completed"]),
			"and the level does not finish (%s)" % route,
			"no drawing, no ending")
		# ⚠ THE CHECK ON THE CHECK. Every "cannot" above is worth nothing if the body never
		# moved; a bot standing in a wall passes all of them.
		_check(float(state["travelled"]) > 200.0,
			"and the bot really walked (%s)" % route,
			"%.0fpx from the spawn" % float(state["travelled"]))

	# AND FROM THE WATER'S EDGE, because testing only from the spawn tests the first gate and
	# nothing else. This is the segment that proves the rescue: an apo put in the shallows and
	# driven east must end up back on the sand, not on the seabed.
	_route_choice = 0
	var wet := await _try_segment(Vector2(1200.0, 500.0))
	if wet.is_empty():
		_check(false, "the bot could be put in the water", "no player")
	else:
		_check(not bool(wet["crossed"]), "nor from the water's edge",
			"furthest east x %.0f" % float(wet["reached"]))
		# ⚠ NOT "it ended out of the water". It wades in, is carried out, and wades in again
		# for the whole segment, so whether it happens to be wet on the last frame is a
		# coin toss -- the first version of this check asserted exactly that and failed on a
		# body 23px under the surface with the rescue working perfectly. What is not a coin
		# toss is that the cycle stays at the water's edge instead of drifting out to sea.
		_check(float(wet["reached"]) < _island_x - 2000.0,
			"and the apo never gets carried out to sea",
			"furthest east %.0f, still within sight of the sand"
				% float(wet["reached"]))
		# THE STRANDING CHECK. The seabed is a thousand pixels down and inside the world
		# bounds, so the fall limit never catches a body that sinks to it. This is the number
		# that went wrong when the drowning rescue was switched off.
		_check(float(wet["deepest"]) < 400.0, "and never sinks out of reach",
			"deepest %.0fpx below the waterline" % float(wet["deepest"]))

	for line in results:
		print(line)
	print("   questions answered: %d (answering Lolo costs no ink)" % answered)
	print("   KNOWN GAP: the island and the exit are not built, so 'does not finish' is")
	print("              true for a duller reason than it will be.")
	if failures == 0:
		print("   OK    the sea is what makes this a drawing game")
		print("OBRA_NODRAW_L3_OK")
		quit(0)
	else:
		print("OBRA_NODRAW_L3_FAILED=%d" % failures)
		quit(1)


func _open_level() -> void:
	var packed := load("res://level_3.tscn") as PackedScene
	level = packed.instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	# A conversation stops the tree until somebody turns the page, and nobody is here to
	# press a key. Without this the first beat the walker reaches stops the world and the run
	# reports the level as a wall when it is really a level nobody walked.
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(30):
		await physics_frame
	player = level.get("player") as CharacterBody2D
	var marks := level.get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/Marks") as Node2D
	if marks != null:
		var waterline := marks.get_node_or_null(^"WaterlineMark") as Node2D
		if waterline != null:
			_waterline_y = waterline.global_position.y
		var island := marks.get_node_or_null(^"IslandMark") as Node2D
		if island != null:
			_island_x = island.global_position.x


func _close_level() -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
	level = null
	player = null


func _state() -> Dictionary:
	var director = level.get("director")
	var here := player.global_position if player != null and is_instance_valid(player) \
		else Vector2.ZERO
	return {
		# THE ONE THAT MATTERS. Reaching the far sand in the apo's own body would mean the
		# sea is scenery.
		"crossed": _furthest > _island_x - 200.0,
		"shore_solved": director != null and bool(director.call("is_solved", "L3_B0_SHORE")),
		"completed": completed,
		"reached": _furthest,
		"in_water": player != null and is_instance_valid(player)
			and bool(player.call("is_in_water")),
		"depth": here.y - _waterline_y,
		"deepest": _deepest,
		"travelled": _travelled,
	}


func _try_segment(at: Vector2) -> Dictionary:
	completed = false
	_deepest = 0.0
	_furthest = -INF
	await _open_level()
	if player == null or not is_instance_valid(player):
		_close_level()
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


## Drive as hard as a determined player would: hold east, jump constantly, press E at
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
		if frame % 18 == 9:
			level.call("_interact_with_level")
		await physics_frame
		_answer_any_question()
		if player == null or not is_instance_valid(player):
			break
		_deepest = maxf(_deepest, player.global_position.y - _waterline_y)
		_furthest = maxf(_furthest, player.global_position.x)
		var here := player.global_position.x
		if absf(here - last) > 8.0:
			last = here
			stuck = 0
		else:
			stuck += 1
		if stuck > 150:
			# Turn round rather than holding into a wall for the rest of the segment.
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
