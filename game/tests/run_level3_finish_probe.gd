extends SceneTree
## Can Dagat be finished, and does finishing it leave the run in the right state?
##
##   godot --headless --path game --script res://tests/run_level3_finish_probe.gd
##
## The other half of T1. That one proves the level cannot be finished without drawing; this
## one proves it CAN be finished with drawing, which is the failure a no-draw suite is
## structurally incapable of catching -- an unbeatable level passes it perfectly.
##
## It also checks the two things the level owes the rest of the game on the way out: Lolo
## stops here, and the lore lands in full whichever way the player crossed.

var level: Node
var results: Array[String] = []
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	results.append("  %s  %-44s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	print("\n===== FINISHING DAGAT =====")
	# BOTH CROSSINGS, because the island delivers whichever half of the lore the player has
	# not heard and that is a different half on each route.
	await _finish_by("pragmatist", "artist")
	await _finish_by("artist", "protector")
	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_LEVEL3_FINISH_OK")
		quit(0)
	else:
		print("OBRA_LEVEL3_FINISH_FAILED=%d" % failures)
		quit(1)


func _finish_by(crossing: String, encounter: String) -> void:
	level = (load("res://level_3.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(40):
		await physics_frame
	var director = level.get("director")
	var profile = root.get_node_or_null("PlayerProfile")
	var script_lines = level.get("script_lines")
	var tag := "%s / %s" % [crossing, encounter]

	# The shore, which nothing gets past without drawing.
	director.call("enter_obstacle", "L3_B0_SHORE")
	director.call("note_submission", "fish")
	director.call("exit_obstacle", "L3_B0_SHORE")
	_check(bool(director.call("is_solved", "L3_B0_SHORE")),
		"the shore is answered by a drawing (%s)" % tag, "a Swim answer solves it")

	# THE CORAL FIELD, on the dive only. Free, ungated and uncounted -- so the only thing
	# that can be checked is that swimming past one makes Lolo say something, which is
	# exactly the thing that silently stops working when a hook is renamed.
	if crossing == "pragmatist":
		var spoken := 0
		for spot: Vector2 in [Vector2(1360.0, 1020.0), Vector2(1780.0, 900.0),
				Vector2(2900.0, 820.0)]:
			(level.get("player") as Node2D).global_position = spot
			for _frame in range(12):
				await physics_frame
		for key: String in ["jelly", "lola1", "shaft"]:
			if bool(script_lines.call("has_heard", "CORAL.%s" % key)):
				spoken += 1
		_check(spoken == 3, "the coral field speaks (%s)" % tag,
			"%d of 3 facts fired by swimming past them" % spoken)

	# The crossing.
	director.call("enter_obstacle", "L3_N1")
	director.call("commit_route", "L3_N1", crossing)
	if crossing == "pragmatist":
		director.call("note_submission", "fish")
	else:
		director.call("solve_with_item", "L3_N1", "bangka")
	director.call("exit_obstacle", "L3_N1")
	_check(bool(director.call("is_solved", "L3_N1")), "the sea is crossed (%s)" % tag,
		"route '%s'" % String(director.call("committed_route", "L3_N1")))

	# The encounter.
	director.call("enter_obstacle", "L3_N2")
	director.call("commit_route", "L3_N2", encounter)
	await _unpause()
	if encounter == "artist":
		# ⚠ WAIT FOR THE GIFT, NOT FOR THE SOLVE. Drawing the light answers the beat
		# immediately -- that is what note_submission does -- but the creature has not found
		# anything yet, and the flower, the outcome and the open channel all come from what
		# it does next. Waiting on is_solved here returned on the first frame and reported an
		# empty outcome.
		director.call("note_submission", "flashlight")
		for _frame in range(600):
			await physics_frame
			if String(profile.call("bakunawa_outcome")) == "LIT":
				break
	else:
		var creature = level.get_node_or_null(
			^"EnvironmentBaseplate/GameplayPlane/Bakunawa")
		director.call("note_submission", "cannon")
		for _swing in range(6):
			creature.call("apply_tool_hit", "cannon", 420.0, null)
			await physics_frame
	director.call("exit_obstacle", "L3_N2")
	_check(bool(director.call("is_solved", "L3_N2")), "the encounter resolves (%s)" % tag,
		"outcome '%s'" % String(profile.call("bakunawa_outcome")))

	# The far sand.
	var player := level.get("player") as Node2D
	var arrival := level.get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/IslandArrival") as Node2D
	player.global_position = arrival.global_position
	# _complete_level stages the cinematic bars and holds for 1.1s before the panel arrives,
	# so that the one moment the game acknowledges the player is not a single frame long.
	# Thirty frames is half of it.
	for _frame in range(140):
		await physics_frame
	var overlay := level.get_node_or_null("LevelCompleteOverlay")

	_check(overlay != null and bool(overlay.call("is_open")),
		"and the level ends on the island (%s)" % tag, "the completion panel is up")
	_check(bool(profile.call("is_level_completed", "level_3")),
		"and is recorded as completed (%s)" % tag, "level_3 in levels_completed")
	# ⚠ THE WHOLE OF THE LORE, WHICHEVER WAY THEY CAME. The reveal splits across the two
	# routes and both halves land here, so no player leaves Dagat without all of it.
	_check(bool(script_lines.call("has_heard", "ISLAND.how_he_died"))
			or bool(script_lines.call("is_flag_set", "heard_how_he_died")),
		"and the first half of the lore landed (%s)" % tag, "on the boat or at the island")
	_check(bool(script_lines.call("has_heard", "ISLAND.about_lola"))
			or bool(script_lines.call("is_flag_set", "heard_about_lola")),
		"and the second half did too (%s)" % tag, "on the dive or at the island")
	# And he stops.
	_check(not bool(profile.call("lolo_is_present")),
		"and Lolo does not go on to Dilim (%s)" % tag, "lolo_present is false")

	if overlay != null and bool(overlay.call("is_open")):
		overlay.call("close")
	level.queue_free()
	level = null
	await process_frame


func _unpause() -> void:
	for node in root.get_tree().get_nodes_in_group(&"modal_overlays"):
		if node.has_method("is_open") and bool(node.call("is_open")):
			node.call("close")
	call_group(DialogueBox.GROUP, &"hide_line")
	root.get_tree().paused = false
	for _frame in range(4):
		await physics_frame
