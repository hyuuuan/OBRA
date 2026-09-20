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

const RosterFixtures = preload("res://tests/roster_fixtures.gd")
const InkManagerClass = preload("res://scripts/ink_manager.gd")

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

	# ⚠ TAKE THE BRUSH FIRST, BY TOUCHING IT, THE WAY A PLAYER DOES. Everything about this
	# level's economy hangs off it: _morph_has_a_life() answers false only once new_brush is
	# on the profile, so a probe that skips the pickup plays Dagat under PAYYO's ten-second
	# clock with no drain at all -- and reports a crossing as affordable without ever having
	# charged for it. It went unnoticed until something finally read the ink meter.
	var brush_mark := level.get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/Marks/BrushMark") as Node2D
	_place(brush_mark.global_position)
	for _frame in range(20):
		await physics_frame
	_check(bool(profile.call("has_new_brush")), "the new brush is found on the shore (%s)" % tag,
		"the drain is armed from here")

	# The shore, which nothing gets past without drawing.
	director.call("enter_obstacle", "L3_B0_SHORE")
	director.call("note_submission", "fish")
	director.call("exit_obstacle", "L3_B0_SHORE")
	_check(bool(director.call("is_solved", "L3_B0_SHORE")),
		"the shore is answered by a drawing (%s)" % tag, "a Swim answer solves it")

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
	# ⚠ AND THE TREE IS STILL PAUSED HERE. The commit speaks the apo's line, a DialogueBox
	# stops the world, and a player presses a key to move on -- so the probe has to as well.
	# Without it nothing below simulates: the fish is driven by held input and does not move a
	# pixel, no Area2D monitoring runs, and the coral field reports itself silent while every
	# one of its triggers is correctly placed. This project has now been caught by a paused
	# tree three times; it looks exactly like broken physics every time.
	await _unpause()
	# ⚠ AFTER THE COMMIT, NOT BEFORE IT. Both blocks below depend on the route having been
	# taken -- the lore is gated on committed_route and the staging happens at the solve --
	# and running them first was a probe that crossed a sea nobody had chosen to cross. It
	# reported the shadow as never seen and let the island quietly cover for the missing half.
	# ⚠ CROSS IT, DO NOT TELEPORT PAST IT. The lore is paced along the crossing and fires
	# from _level_physics, so a probe that jumps from the shore to the island skips the whole
	# of it -- and, before the flags were fixed, still reported the lore as heard.
	#
	# ⚠ AND CROSS IT IN A BODY THE PLAYER WOULD ACTUALLY HAVE. Dragging a bare apo through
	# deep water is not a crossing, it is drowning: the base rescues an un-morphed Wanderer
	# after 1.1s submerged, and the rescue restores a checkpoint, which rolls the director's
	# obstacle state back. That silently un-solved the encounter a frame after it was solved
	# and reported it as never resolving. On the dive the player is a fish; on the boat they
	# are on the deck, above the waterline.
	if crossing == "pragmatist":
		var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		sheet.fill(Color.WHITE)
		level.call("_spawn_or_replace", "fish", "Fish", sheet,
			RosterFixtures.for_rig("swimmer", "fish"))
		await physics_frame
	# ⚠ THE DIVE FOLLOWS THE SEABED, WHERE THE REFILLS ARE. A path down the middle of the
	# water column crosses the level without passing a single one of them, which is a probe
	# proving that a crossing nobody would swim is affordable.
	var ink = level.get("ink_manager")
	var spent_low := 999.0
	var path: Array = []
	if crossing == "artist":
		for x in [1300.0, 1900.0, 2500.0, 3050.0, 3350.0, 3420.0]:
			path.append(Vector2(x, 520.0))
	else:
		for pair: Variant in (director.call("level_data") as Dictionary) \
				.get("ink_economy", {}).get("refill_spots", []):
			var xy: Array = pair
			path.append(Vector2(float(xy[0]), float(xy[1])))
		path.append(Vector2(3420.0, 1150.0))
	for spot: Vector2 in path:
		_place(spot)
		# Long enough that a per-SECOND charge is readable. Ten frames is a sixth of a
		# second, and at the cheapest rate that is three hundredths of a unit.
		for _frame in range(30):
			await physics_frame
			if ink != null:
				spent_low = minf(spent_low, float(ink.call("remaining")))

	if crossing == "pragmatist":
		# THE TUNED ECONOMY, IN THE LEVEL RATHER THAN IN THE PROBE'S POOL. Holding a form
		# has to cost something, and the seabed has to hand some of it back -- a drain that
		# never bites and refills nobody can reach both look like a working crossing.
		_check(spent_low < InkManagerClass.BUDGET,
			"holding a form costs ink while crossing (%s)" % tag,
			"fell to %.2f of %.0f at its lowest" % [spent_low, InkManagerClass.BUDGET])
		_check(float(ink.call("remaining")) > spent_low,
			"and the seabed hands some back (%s)" % tag,
			"ended at %.2f after passing the refills" % float(ink.call("remaining")))

	# THE CORAL FIELD, on the dive only. Free, ungated and uncounted -- so the only thing
	# that can be checked is that swimming past one makes Lolo say something, which is
	# exactly the thing that silently stops working when a hook is renamed.
	if crossing == "pragmatist":
		var spoken := 0
		for spot: Vector2 in [Vector2(1360.0, 1020.0), Vector2(1780.0, 900.0),
				Vector2(2900.0, 820.0)]:
			await _swim_to(spot)
		for key: String in ["jelly", "lola1", "shaft"]:
			if bool(script_lines.call("has_heard", "CORAL.%s" % key)):
				spoken += 1
		_check(spoken == 3, "the coral field speaks (%s)" % tag,
			"%d of 3 facts fired by swimming past them" % spoken)

	var creature := level.get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/Bakunawa") as Node2D
	var surface := level.get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/Marks/SurfaceMark") as Node2D
	if crossing == "artist":
		# ⚠ THE SURFACE STAGING. From the boat it is silhouette and back; a creature left at
		# depth is an encounter a boat player cannot reach at all.
		_check(absf(creature.global_position.y - surface.global_position.y) < 40.0,
			"and the encounter comes up to meet the boat (%s)" % tag,
			"staged at y %.0f" % creature.global_position.y)
		_check(bool(script_lines.call("has_heard", "L3_BOAT.shadow")),
			"and its shadow crosses first (%s)" % tag,
			"seen before the creature is")
	else:
		_check(creature.global_position.y > surface.global_position.y + 200.0,
			"and the encounter stays down there (%s)" % tag,
			"staged at y %.0f" % creature.global_position.y)

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
		director.call("note_submission", "cannon")
		for _swing in range(6):
			creature.call("apply_tool_hit", "cannon", 420.0, null)
			await physics_frame
	director.call("exit_obstacle", "L3_N2")
	_check(bool(director.call("is_solved", "L3_N2")), "the encounter resolves (%s)" % tag,
		"outcome '%s'" % String(profile.call("bakunawa_outcome")))

	# The far sand.
	var arrival := level.get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/IslandArrival") as Node2D
	_place(arrival.global_position)
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
	# ⚠ THE WHOLE OF THE LORE, WHICHEVER WAY THEY CAME, AND A FLAG IS NOT EVIDENCE OF IT.
	#
	# This used to accept `is_flag_set` as proof, and the flags were set at the moment the
	# route was taken rather than when a word was spoken -- so it passed while BOTH halves
	# were missing from both routes and the island skipped them for being "already heard".
	# The only thing that proves a line landed is the line having been fired.
	var how_he_died := bool(script_lines.call("has_heard", "ISLAND.how_he_died")) \
		or bool(script_lines.call("has_heard", "L3_BOAT.lore4"))
	var about_lola := bool(script_lines.call("has_heard", "ISLAND.about_lola")) \
		or bool(script_lines.call("has_heard", "L3_DIVE.lore4"))
	_check(how_he_died, "and how he died was actually spoken (%s)" % tag,
		"on the boat or, failing that, at the island")
	_check(about_lola, "and what it did to lola was too (%s)" % tag,
		"on the dive or, failing that, at the island")
	# And he stops.
	_check(not bool(profile.call("lolo_is_present")),
		"and Lolo does not go on to Dilim (%s)" % tag, "lolo_present is false")

	if overlay != null and bool(overlay.call("is_open")):
		overlay.call("close")
	level.queue_free()
	level = null
	await process_frame


## ⚠ THROUGH apply_morph_state WHEN THERE IS ONE. A rig's bodies are top_level, so writing
## the morph node's global_position moves the node and leaves the physics at the origin --
## the trap run_water_audit.gd documents and the reason its fish readings were once identical
## across three code states.
## ⚠ SWIM IN UNDER POWER. DO NOT TELEPORT ONTO IT.
##
## An Area2D reports body_entered on a transition its monitoring actually observes, and a rig
## moved by apply_morph_state is written straight into place while frozen -- so the pair is
## never re-evaluated. Measured, not assumed: with the fish's own physics anchor 65px inside a
## 150px circle, the area reported ZERO overlapping bodies while a direct space query at the
## same point and mask found SIXTEEN. Every pickup in this level is an Area2D, so a probe that
## teleports proves nothing about any of them.
##
## Held input, the way a player arrives. Slow, and the only thing that is actually a test.
func _swim_to(at: Vector2) -> void:
	_place(at + Vector2(-420.0, 0.0))
	for _frame in range(6):
		await physics_frame
	Input.action_press(&"move_right")
	for _frame in range(240):
		await physics_frame
		# ⚠ AND KEEP PRESSING THE KEY. Lolo talks during the crossing -- that is the whole
		# point of the scene -- and a lore line stops the tree, so a swim that does not
		# advance the dialogue stalls on the frame he starts speaking and never arrives. The
		# player is holding a direction and tapping through him; so is this.
		if root.get_tree().paused:
			Input.action_release(&"move_right")
			await _unpause()
			Input.action_press(&"move_right")
		var body := level.get("player") as Node
		if body == null or not is_instance_valid(body):
			break
		var anchor := body.call("get_physics_anchor") as Node2D
		if anchor != null and anchor.global_position.distance_to(at) < 60.0:
			break
	Input.action_release(&"move_right")
	for _frame in range(4):
		await physics_frame


func _place(at: Vector2) -> void:
	var body := level.get("player") as Node2D
	if body == null or not is_instance_valid(body):
		return
	if body.has_method("apply_morph_state"):
		body.call("apply_morph_state", {"position": at, "linear_velocity": Vector2.ZERO})
	else:
		body.global_position = at


## ⚠ DRAIN THE QUEUE, DO NOT HIDE ONE LINE. A beat speaks several lines and the box holds the
## rest; hiding the current one and setting paused=false lets the NEXT line re-pause on the
## following frame, so the world stops again a frame after the probe decided it was running.
## The symptom is a fish that will not move and areas that report nothing -- physics that
## looks broken and is simply not being stepped.
func _unpause() -> void:
	for _attempt in range(60):
		for node in root.get_tree().get_nodes_in_group(&"modal_overlays"):
			if node.name == "LevelCompleteOverlay":
				continue
			if node.has_method("is_open") and bool(node.call("is_open")):
				node.call("close")
		call_group(DialogueBox.GROUP, &"hide_line")
		root.get_tree().paused = false
		await physics_frame
		if not root.get_tree().paused:
			# Two clear frames in a row, or the next queued line has simply not landed yet.
			await physics_frame
			if not root.get_tree().paused:
				return
