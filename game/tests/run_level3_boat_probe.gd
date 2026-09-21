extends SceneTree
## The boat crossing, SAILED. Needs no window:
##   godot --headless --path game --script res://tests/run_level3_boat_probe.gd
##
## Every other Dagat probe crosses the sea by putting the apo at points along it. That proves
## the lore fires and the encounter resolves, and it proves nothing about the boat -- and the
## boat had four faults that every one of those probes was green through:
##
##  1. It crawled. It reported 240 px/s and moved at 14, because the gameplay plane was
##     re-setting its own (unchanged) position every frame the camera moved, and that snapped
##     every rigid body under it back to where its node last saw it. See DepthLayer2D.
##  2. It sank, about twelve pixels a second, until the passenger went under, the drowning
##     rescue fired, and the checkpoint it restored took the boat away. See UtilityObject.
##  3. It could not reach the island: it kept the physics script's 3760px default world and
##     was stopped dead at x 3940.
##  4. It kept its passenger. Landing the apo on the sand lasted one frame before the hull
##     seated them back on the deck.
##
## So this one does what a player does: takes the fork, finds the boat with E, boards it with
## E, holds right, and taps through Lolo.

const Bakunawa = preload("res://scripts/bakunawa_2d.gd")

var level: Node
var results: Array[String] = []
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	results.append("  %s  %-46s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	print("\n===== SAILING DAGAT =====")
	level = (load("res://level_3.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(40):
		await physics_frame
	var director = level.get("director")
	var creature := level.get_node(^"EnvironmentBaseplate/GameplayPlane/Bakunawa") as Node2D
	var surface := level.get_node(^"EnvironmentBaseplate/GameplayPlane/Marks/SurfaceMark") as Node2D

	# The shore and the fork, answered the way the finish probe answers them.
	director.call("enter_obstacle", "L3_B0_SHORE")
	director.call("note_submission", "fish")
	director.call("exit_obstacle", "L3_B0_SHORE")
	director.call("enter_obstacle", "L3_N1")
	director.call("commit_route", "L3_N1", "artist")
	await _unpause()

	# FOUND, WITH E. Standing beside the beached one is what launches the real one.
	var beached := level.get("_bangka") as Node2D
	_place(beached.global_position + Vector2(-40.0, -20.0))
	await _frames(10)
	level.call("press_interact")
	await _unpause()
	var boat := level.get("_launched_boat") as RigidBody2D
	_check(boat != null and bool(director.call("is_solved", "L3_N1")),
		"E at the beached bangka puts a real one in the water",
		"L3_N1 solved with the found boat")
	if boat == null:
		_finish()
		return
	_check(absf(creature.global_position.y - surface.global_position.y) < 40.0,
		"and the encounter comes up to meet it", "staged at y %.0f" % creature.global_position.y)

	# BOARDED, WITH E.
	await _frames(30)
	_place(boat.global_position + Vector2(0.0, -40.0))
	await _frames(4)
	level.call("press_interact")
	await _unpause()
	var player := level.get("player") as Node2D
	_check(bool(boat.call("has_passenger", player)), "E at the boat puts the apo aboard",
		"riding=%s" % player.call("is_riding"))

	# SAILED, UNDER POWER, to the edge of the encounter.
	var start := boat.global_position
	# Where a hull should ride: its draft under the surface. Measured once it is under way,
	# because boarding sets it bobbing and a bob is not a sink.
	var water := level.get_node(^"EnvironmentBaseplate/GameplayPlane/Sea")
	var rest := float(water.call("surface_y")) + UtilityObject.HULL_DRAFT
	var lowest := rest
	var highest := rest
	var seconds := 0.0
	Input.action_press(&"move_right")
	while boat != null and is_instance_valid(boat) and boat.global_position.x < 3300.0 \
			and seconds < 60.0:
		await physics_frame
		if paused:
			Input.action_release(&"move_right")
			await _unpause()
			Input.action_press(&"move_right")
			continue
		seconds += 1.0 / 60.0
		if seconds > 2.0:
			lowest = maxf(lowest, boat.global_position.y)
			highest = minf(highest, boat.global_position.y)
	Input.action_release(&"move_right")
	var kept := boat != null and is_instance_valid(boat)
	_check(kept and boat.global_position.x >= 3300.0 and seconds < 25.0,
		"it sails, not crawls", "%.0f px in %.1f s under sail" % [
			(boat.global_position.x if kept else 0.0) - start.x, seconds])
	_check(kept and lowest - rest < 16.0 and rest - highest < 16.0,
		"and it floats rather than sinking", "rode between %.0f and %.0f, its waterline %.0f"
			% [highest, lowest, rest])
	_check(kept and bool(boat.call("has_passenger", player)),
		"and nobody is fished out of the sea on the way", "the apo is still aboard")
	if not kept:
		_finish()
		return

	# THE CHANNEL HOLDS until the encounter is resolved, at the surface as well as below it.
	var coils_x := creature.global_position.x + Bakunawa.BODY_LENGTH * 0.5 - 40.0 - 80.0
	await _hold_right(4.0, boat)
	_check(boat.global_position.x < coils_x, "and the coils stop it while it is unresolved",
		"held at x %.0f, coils at %.0f" % [boat.global_position.x, coils_x + 80.0])

	# RESOLVED WITH LIGHT, the way the finish probe resolves it, and then on to the sand.
	director.call("enter_obstacle", "L3_N2")
	director.call("commit_route", "L3_N2", "artist")
	await _unpause()
	director.call("note_submission", "flashlight")
	for _frame in range(900):
		await physics_frame
		if paused:
			await _unpause()
		if bool(director.call("is_solved", "L3_N2")) \
				and String(root.get_node("PlayerProfile").call("bakunawa_outcome")) == "LIT":
			break
	director.call("exit_obstacle", "L3_N2")
	_check(bool(director.call("is_solved", "L3_N2")), "the light resolves it",
		"outcome '%s'" % root.get_node("PlayerProfile").call("bakunawa_outcome"))

	await _hold_right(14.0, boat, true)
	var sand := level.get_node(^"EnvironmentBaseplate/GameplayPlane/Marks/IslandMark") as Node2D
	player = level.get("player") as Node2D
	_check(bool(level.get("_arrived")), "and the boat carries the apo to the island",
		"the arrival fired")
	await _frames(20)
	_check(not bool(boat.call("has_passenger", player)) and absf(player.global_position.x
			- sand.global_position.x) < 120.0,
		"and they step off onto the sand", "apo at %s, the sand at x %.0f"
			% [player.global_position.round(), sand.global_position.x])
	_finish()


func _finish() -> void:
	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_LEVEL3_BOAT_OK")
		quit(0)
	else:
		print("OBRA_LEVEL3_BOAT_FAILED=%d" % failures)
		quit(1)


func _hold_right(seconds: float, boat: Node2D, until_arrival: bool = false) -> void:
	var elapsed := 0.0
	Input.action_press(&"move_right")
	while elapsed < seconds:
		await physics_frame
		if paused:
			Input.action_release(&"move_right")
			await _unpause()
			Input.action_press(&"move_right")
			continue
		elapsed += 1.0 / 60.0
		if until_arrival and bool(level.get("_arrived")):
			break
	Input.action_release(&"move_right")


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func _place(at: Vector2) -> void:
	var body := level.get("player") as Node2D
	if body == null or not is_instance_valid(body):
		return
	if body.has_method("apply_morph_state"):
		body.call("apply_morph_state", {"position": at, "linear_velocity": Vector2.ZERO})
	else:
		body.global_position = at


## ⚠ DRAIN THE QUEUE, DO NOT HIDE ONE LINE -- the boat's lore is the DialogueBox, which stops
## the world on purpose, and a probe that hides one line watches the next one re-pause it.
func _unpause() -> void:
	for _attempt in range(60):
		for node in get_nodes_in_group(&"modal_overlays"):
			if node.name == "LevelCompleteOverlay":
				continue
			if node.has_method("is_open") and node.has_method("close") \
					and bool(node.call("is_open")):
				node.call("close")
		call_group(DialogueBox.GROUP, &"hide_line")
		paused = false
		await physics_frame
		if not paused:
			await physics_frame
			if not paused:
				return
