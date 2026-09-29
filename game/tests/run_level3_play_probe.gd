extends SceneTree
## Dagat, played the way a player plays it: walked, drawn where the objective says, chosen at
## the fork with the overlay, boarded with the key the prompt names.
##
##   godot --headless --path game --script res://tests/run_level3_play_probe.gd
##
## ⚠ WHY THIS EXISTS WHEN SIX OTHER DAGAT PROBES DO. Every one of them enters each beat by NAME
## -- director.enter_obstacle("L3_B0_SHORE"), then note_submission, then the next -- which is the
## one thing a player never does. A player walks, and the volumes they walk through overlap. Played
## that way, the shore could not be passed (the practice's swimmer answered the crossing, so the
## fork never opened and the boat could not be taken), the dive could not be started (a swimmer
## drawn on the sand lies there draining and cannot move), the lessons that teach the level's one
## new rule never showed, and the objective named the creature to a player still on the beach.
## Every suite was green through all of it. This probe walks.

const RosterFixtures = preload("res://tests/roster_fixtures.gd")
const ControlsKeys = preload("res://scripts/controls_overlay.gd")

var level: Node2D
var results: Array[String] = []
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	results.append("  %s  %s -- %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	print("\n===== PLAYING DAGAT =====")
	await _play("boat")
	await _play("dive")
	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_LEVEL3_PLAY_OK")
		quit(0)
	else:
		print("OBRA_LEVEL3_PLAY_FAILED=%d" % failures)
		quit(1)


func _play(route: String) -> void:
	level = (load("res://level_3.tscn") as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	await _wait(0.6)
	if level.has_method("_end_the_opening"):
		level.call("_end_the_opening", true)
	var director = level.get("director")
	var tutorial = level.get("tutorial")
	var lines = level.get("script_lines")
	# The brush is the PROFILE's once found, so a second play -- this probe's dive, a player's
	# replay -- never meets it or its lesson. Asked of the first play only.
	var first_play := route == "boat"

	# ⚠ ONE THING AT A TIME. The shore's instruction went up on walking onto the beach, about a
	# brush not yet found; the crossing's opening line fired on picking the brush up, beside the
	# brush's own line, its lesson and a checkpoint. Asked on the way, before the brush.
	if first_play:
		await _walk_to_x(520.0)
		await _drain_dialogue(route)
		_check(not bool(lines.call("has_heard", "L3_B0_SHORE.sub1")),
			"the shore's instruction waits for the brush (%s)" % route,
			"not said on walking onto the beach")

	# THE SHORE: the brush, then a swimmer drawn at the waterline -- where the objective points,
	# and inside the crossing's volume, which is the case that used to answer the crossing.
	await _walk_to_x(620.0)
	await _wait(0.6)
	await _drain_dialogue(route)
	var profile = root.get_node_or_null("PlayerProfile")
	_check(profile != null and bool(profile.call("has_new_brush")),
		"the brush is taken on foot (%s)" % route,
		"the drain is armed from here")
	if first_play:
		_check(tutorial != null and bool(tutorial.call("has_taught", "new_brush")),
			"and its lesson is shown (%s)" % route, "it used to wait on a busy hint bar forever")
		_check(bool(lines.call("has_heard", "L3_B0_SHORE.sub1"))
				and not bool(lines.call("has_heard", "L3_N1.enter")),
			"and it brings the instruction, not the crossing (%s)" % route,
			"the crossing's opening waits for the practice")
		level.call("refresh_objective")
		var objective := String((level.get("objective_banner") as Control).call("text"))
		_check(objective.begins_with("Press %s " % ControlsKeys.key_cap_for("redraw")),
			"and the objective says which key draws (%s)" % route, "\"%s\"" % objective)
	await _walk_to_x(925.0)
	await _drain_dialogue(route)
	await _become("fish")
	await _wait(0.8)
	_check(bool(director.call("is_solved", "L3_B0_SHORE")),
		"the practice at the waterline answers the shore (%s)" % route,
		"committed at the crossing: '%s'" % String(director.call("committed_route", "L3_N1")))
	_check(String(director.call("committed_route", "L3_N1")).is_empty() \
			or route == "dive",
		"and does not choose the crossing for the player (%s)" % route,
		"route '%s'" % String(director.call("committed_route", "L3_N1")))
	# Press through what the practice says -- a DialogueBox stops the world, and the drain with
	# it -- and stop at the fork without answering it.
	var overlay_seen := await _drain_dialogue("")
	if first_play:
		_check(tutorial != null and bool(tutorial.call("has_taught", "drain")),
			"the drain lesson lands during the practice (%s)" % route,
			"that bar is your ink now")

	# THE FORK, answered with the overlay the way a player answers it.
	overlay_seen = await _drain_dialogue(route) or overlay_seen
	_check(overlay_seen, "the fork is offered after the practice (%s)" % route,
		"the choice overlay opened")
	# ⚠ AFTER ITS OWN INTRODUCTION. The two ways across were hint-bar lines, and the bar stands
	# down while a choice is open -- so they were read after the crossing had been chosen, out
	# at sea. Asked of what the box SHOWED before the choice, not of what had fired: lines fired
	# on the frame the choice opens are said behind it.
	if first_play:
		_check(bool(fork_shown.get("opening", false)) and bool(fork_shown.get("ways", false)),
			"and only after the way across has been said (%s)" % route,
			"opening line %s, the two ways %s, before the choice opened" % [
				"shown" if fork_shown.get("opening", false) else "NOT shown",
				"shown" if fork_shown.get("ways", false) else "NOT shown"])

	if route == "boat":
		await _boat(director)
	else:
		await _dive(director)
	level.queue_free()
	level = null
	await process_frame


func _boat(director) -> void:
	var tutorial = level.get("tutorial")
	_check(tutorial != null and bool(tutorial.call("has_taught", "revert_is_free")),
		"choosing the boat as a swimmer teaches how to change back (boat)",
		"the apo cannot walk the sand as a fish")
	# Out of the practice's body: Q, the way the lesson says.
	await _press(&"revert_form")
	await _wait(0.6)
	var card := level.get("morph_card") as Control
	_check(card == null or not card.visible, "changing back takes the form card away (boat)",
		"it said FISH over the apo rowing, before")
	await _walk_to_x(840.0)
	await _press(&"interact")
	await _wait(0.8)
	await _drain_dialogue("boat")
	_check(bool(director.call("is_solved", "L3_N1")), "the boat is found with E (boat)",
		"the crossing is answered by what washed up")
	await _walk_to_x(990.0)
	await _wait(0.4)
	await _press(&"interact")
	await _wait(0.8)
	await _drain_dialogue("boat")
	_check(String((level.call("_current_objective") as Dictionary).get("key", "")) == "cross_by_boat",
		"the objective is about rowing, not the creature (boat)",
		"key '%s'" % String((level.call("_current_objective") as Dictionary).get("key", "")))
	await _walk_to_x(2200.0)
	_check(_anchor_x() > 2000.0, "and the boat actually carries the apo out (boat)",
		"x %.0f" % _anchor_x())


func _dive(director) -> void:
	# The fork overlay chose the dive while the practice's swimmer was still on the sand.
	var body_x := _anchor_x()
	var body_y := _anchor_y()
	_check(body_x > 1000.0 and body_y > 560.0, "choosing the dive puts that swimmer in the sea (dive)",
		"at (%.0f, %.0f); the shore ends at 1000 and the sea's surface is 560" % [body_x, body_y])
	_check(bool(director.call("is_solved", "L3_N1")), "and it answers the crossing (dive)",
		"route '%s'" % String(director.call("committed_route", "L3_N1")))
	_check(String((level.call("_current_objective") as Dictionary).get("key", "")) == "cross_by_dive",
		"the objective is about the swim, not the creature (dive)",
		"key '%s'" % String((level.call("_current_objective") as Dictionary).get("key", "")))
	var start_x := _anchor_x()
	Input.action_press(&"move_down")
	await _walk_to_x(1500.0)
	Input.action_release(&"move_down")
	_check(_anchor_x() > start_x + 300.0, "and the swimmer can actually swim away (dive)",
		"from %.0f to %.0f" % [start_x, _anchor_x()])


func _anchor() -> Node2D:
	var player := level.get("player") as Node2D
	if player != null and player.has_method("get_physics_anchor"):
		var anchor := player.call("get_physics_anchor") as Node2D
		if anchor != null:
			return anchor
	return player


func _anchor_x() -> float:
	var node := _anchor()
	return node.global_position.x if node != null else 0.0


func _anchor_y() -> float:
	var node := _anchor()
	return node.global_position.y if node != null else 0.0


## Held input, stopping to read whatever comes up on the way.
func _walk_to_x(x: float) -> void:
	var dir := &"move_right" if _anchor_x() < x else &"move_left"
	var guard := 0.0
	while (dir == &"move_right" and _anchor_x() < x) or (dir == &"move_left" and _anchor_x() > x):
		if paused:
			Input.action_release(dir)
			await _drain_dialogue("")
		Input.action_press(dir)
		await process_frame
		guard += get_root().get_process_delta_time()
		if guard > 30.0:
			break
	Input.action_release(dir)


## Every line the dialogue box put up, in the order it put them up, as they were pressed through.
var box_lines: Array[String] = []
## What had been SHOWN about the crossing when its choice first opened -- not merely fired: lines
## fired on the frame the choice opens are said behind it. See the fork's check.
var fork_shown := {}


## Press through any open dialogue, and answer the fork's overlay with the route being played.
## Returns whether the overlay was seen.
func _drain_dialogue(route: String) -> bool:
	var saw_overlay := false
	for _i in range(16):
		var overlay := level.get_node_or_null(^"DialogueChoiceOverlay")
		if overlay != null and overlay.has_method("is_open") and bool(overlay.call("is_open")):
			saw_overlay = true
			if fork_shown.is_empty():
				var shown := "\n".join(box_lines)
				fork_shown["opening"] = shown.contains("That is the whole of it")
				fork_shown["ways"] = shown.contains("Two ways across") \
					and shown.contains("Or walk the sand")
			if route.is_empty():
				return true
			overlay.call("_on_route_pressed", "artist" if route == "boat" else "pragmatist")
			await _wait(0.4)
			continue
		var open := false
		for node in get_nodes_in_group(DialogueBox.GROUP):
			if node.has_method("is_open") and bool(node.call("is_open")):
				open = true
				var line := String(node.call("current_line"))
				if box_lines.is_empty() or box_lines.back() != line:
					box_lines.append(line)
		if not open and not paused:
			return saw_overlay
		await _press(&"ui_accept")
		await _wait(0.3)
	return saw_overlay


func _press(action: StringName) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


func _become(entity: String) -> void:
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	level.call("_spawn_or_replace", entity, entity.capitalize(), sheet,
		RosterFixtures.for_rig("swimmer", entity))
	await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout
