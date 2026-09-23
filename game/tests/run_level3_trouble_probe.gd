extends SceneTree
## Dagat GOING WRONG, on purpose:
##   godot --headless --path game --script res://tests/run_level3_trouble_probe.gd
##
## Every other probe in this level plays it correctly. That is the wrong half of the work: a
## level with no death state can only fail by leaving the player somewhere they cannot get out
## of, and none of those places are on the happy path. The boat route's two soft locks were
## both found by going wrong deliberately -- stepping off into open sea, and a restore to
## before a boat that was no longer on the sand. This does the same for the dive.
##
## Three ways to lose, and the same question about all three: afterwards, can the player still
## play? Not "did the right message appear" -- can they go on.
##
##   1. THE INK RUNS OUT ON THE SEABED. The design's zero case is "revert, carry the apo up,
##      lose the crossing, never die". Reverting at the bottom of a thousand-pixel water
##      column leaves a body that cannot swim in a place it cannot leave, and the ink that
##      would buy another one is the ink that just ran out. The way back is the checkpoint
##      restore handing the spend back; if it ever stops doing that, this is the level's
##      first unwinnable state and nothing else would notice.
##   2. BEING SEEN ON THE STEALTH ROUTE. Costs the stretch, not the approach. The reset must
##      put the player somewhere west of the creature with something left to swim with.
##   3. THREE KNOCKS IN THE FIGHT. Same reset, and the fight has to come back FRESH -- a
##      knock count that survived the restart would make the third loss permanent.

const RosterFixtures = preload("res://tests/roster_fixtures.gd")
const Bakunawa = preload("res://scripts/bakunawa_2d.gd")
const InkManagerClass = preload("res://scripts/ink_manager.gd")

var level: Node
var results: Array[String] = []
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	results.append("  %s  %-48s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	print("\n===== GOING WRONG IN DAGAT =====")
	await _out_of_ink_on_the_seabed()
	await _seen_on_the_stealth_route()
	await _three_knocks_in_the_fight()
	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_LEVEL3_TROUBLE_OK")
		quit(0)
	else:
		print("OBRA_LEVEL3_TROUBLE_FAILED=%d" % failures)
		quit(1)


# --- 1. The ink runs out on the seabed --------------------------------------------------

func _out_of_ink_on_the_seabed() -> void:
	await _open_the_level()
	var director = level.get("director")
	await _take_the_brush()
	await _answer_the_shore(director)
	director.call("enter_obstacle", "L3_N1")
	director.call("commit_route", "L3_N1", "pragmatist")
	director.call("note_submission", "fish")
	director.call("exit_obstacle", "L3_N1")
	await _unpause()
	await _become_a_fish()

	# ⚠ ON THE BED, NOT IN MID-WATER, and west of the first refill: this is the crossing
	# running out under a player who is doing everything right, not one who swam into a wall.
	var ink = level.get("ink_manager")
	var emptied := false
	var seconds := 0.0
	while seconds < 60.0:
		_place(Vector2(1200.0, 1650.0))
		await physics_frame
		if paused:
			await _unpause()
			continue
		seconds += 1.0 / 60.0
		if float(ink.call("remaining")) <= 0.0001:
			emptied = true
			break
	_check(emptied, "holding a body on the seabed empties the ink",
		"empty after %.1f s of swimming" % seconds)

	# The level's own zero case, not the generic screen.
	var overlay := level.get_node_or_null(^"OutOfInkOverlay")
	_check(overlay == null or not overlay.has_method("is_open")
			or not bool(overlay.call("is_open")),
		"and no out-of-ink screen opens over it", "Dagat answers for itself")

	# Then the rescue, which is the base's and fires on an un-morphed apo in water.
	for _frame in range(280):
		await physics_frame
		if paused:
			await _unpause()
	var apo := level.get("player") as Node2D
	_check(apo is Wanderer, "the body is given up rather than drowned in",
		"the apo is %s" % apo.get_class())
	var waterline := float(level.get("_waterline_y"))
	_check(apo.global_position.y <= waterline + 40.0,
		"and the apo is carried back up, not left on the bed",
		"at y %.0f, the surface at %.0f" % [apo.global_position.y, waterline])

	# ⚠ AND THE RUN IS STILL WINNABLE, which is the only thing here that is not cosmetic. The
	# ink that would buy another body is the ink that just ran out, and the only way back is
	# the checkpoint restore handing the spend back. If it stops, Dagat has its first
	# unwinnable state and every other probe in the level stays green through it.
	var left := float(ink.call("remaining"))
	_check(left > 0.5, "and there is ink to try again with",
		"%.2f of %.0f back" % [left, InkManagerClass.BUDGET])
	_check(not bool(level.get("_level_completed")), "and the level did not end on a loss",
		"still playing")
	await _close_the_level()


# --- 2. Being seen ------------------------------------------------------------------------

func _seen_on_the_stealth_route() -> void:
	await _open_the_level()
	var director = level.get("director")
	await _take_the_brush()
	await _answer_the_shore(director)
	director.call("enter_obstacle", "L3_N1")
	director.call("commit_route", "L3_N1", "pragmatist")
	director.call("note_submission", "fish")
	director.call("exit_obstacle", "L3_N1")
	await _unpause()
	await _become_a_fish()
	var creature := level.get_node(^"EnvironmentBaseplate/GameplayPlane/Bakunawa") as Node2D
	# Reach the mid-encounter checkpoint first, so what is lost is the stretch and not the
	# approach -- which is the thing CP3b exists for.
	_place(Vector2(3760.0, 1240.0))
	for _frame in range(30):
		await physics_frame
	director.call("enter_obstacle", "L3_N2")
	director.call("commit_route", "L3_N2", "pragmatist")
	await _unpause()

	# Into its space, and wait for the sweep to come round.
	#
	# ⚠ WATCH _reset_cooldown, NOT THE DISTANCE. Losing the stretch speaks a line, which stops
	# the tree -- so a loop that only looks at where the apo is drains the dialogue, comes
	# round, and puts them straight back in the creature's face before it has read anything.
	# The first version of this probe held a fish inside the sweep for fourteen seconds and
	# reported that the sweep does not work.
	var caught := false
	var seconds := 0.0
	while seconds < 14.0:
		if float(level.get("_reset_cooldown")) > 0.0:
			caught = true
			break
		_place(creature.global_position + Vector2(120.0, -40.0))
		await physics_frame
		if float(level.get("_reset_cooldown")) > 0.0:
			caught = true
			break
		if paused:
			await _unpause()
			continue
		seconds += 1.0 / 60.0
	_check(caught, "swimming into the sweep costs the stretch",
		"moved off after %.1f s in its space" % seconds)
	if caught:
		for _frame in range(40):
			await physics_frame
			if paused:
				await _unpause()
		var apo := level.get("player") as Node2D
		_check(apo.global_position.x < creature.global_position.x,
			"and puts the apo back west of it, not past it",
			"at x %.0f, the creature at %.0f" % [apo.global_position.x,
				creature.global_position.x])
		_check(not bool(director.call("is_solved", "L3_N2")),
			"and the encounter is not quietly resolved by losing it",
			"L3_N2 still open")
		_check(float((level.get("ink_manager")).call("remaining")) > 0.5,
			"and there is ink to swim back with",
			"%.2f left" % float((level.get("ink_manager")).call("remaining")))

		# ⚠ AND THE PLACE IT PUTS THEM IS OUT OF ITS REACH. A checkpoint inside the sweep is
		# not a checkpoint: the grace runs out, the cone comes round, and the player is reset
		# again from the same spot without having done anything. Not a soft lock -- they can
		# swim -- but a player who lets go of the controller is in a loop, and the design's
		# whole reason for a mid-encounter checkpoint is that losing costs the stretch ONCE.
		# ⚠ LET THE GRACE RUN OUT FIRST. _reset_cooldown is 1.4 s and is still counting down
		# while the line is being read, so a watch armed straight away counts the reset that
		# has just happened as a second one.
		for _frame in range(120):
			await physics_frame
			if paused:
				await _unpause()
			if float(level.get("_reset_cooldown")) <= 0.0:
				break
		var again := 0
		var watching := 0.0
		var armed := true
		while watching < 10.0:
			await physics_frame
			if paused:
				await _unpause()
				continue
			watching += 1.0 / 60.0
			var cooling := float(level.get("_reset_cooldown")) > 0.0
			if cooling and armed:
				again += 1
				armed = false
			elif not cooling:
				armed = true
		_check(again == 0, "and it cannot see them there", "%d further resets in 10 s" % again)
		var resting := (level.get("player") as Node2D).global_position
		_check(resting.distance_to(creature.global_position) > Bakunawa.CONE_LENGTH,
			"which is measured, not hoped for",
			"%.0f px away, its cone reaches %.0f"
				% [resting.distance_to(creature.global_position), Bakunawa.CONE_LENGTH])
	await _close_the_level()


# --- 3. Three knocks ----------------------------------------------------------------------

func _three_knocks_in_the_fight() -> void:
	await _open_the_level()
	var director = level.get("director")
	await _take_the_brush()
	await _answer_the_shore(director)
	director.call("enter_obstacle", "L3_N1")
	director.call("commit_route", "L3_N1", "pragmatist")
	director.call("note_submission", "fish")
	director.call("exit_obstacle", "L3_N1")
	await _unpause()
	await _become_a_fish()
	var creature := level.get_node(^"EnvironmentBaseplate/GameplayPlane/Bakunawa") as Node2D
	_place(Vector2(3760.0, 1240.0))
	for _frame in range(30):
		await physics_frame
	director.call("enter_obstacle", "L3_N2")
	director.call("commit_route", "L3_N2", "protector")
	await _unpause()
	_check(int(creature.call("state")) == Bakunawa.State.FIGHTING,
		"committing Protector wakes it up", "state FIGHTING")

	# Three contacts, a knock cooldown apart. The first two are a warning.
	var thrown := false
	var seconds := 0.0
	var counted := 0
	while seconds < 14.0:
		if float(level.get("_reset_cooldown")) > 0.0:
			thrown = true
			break
		_place(creature.global_position + Vector2(40.0, 0.0))
		await physics_frame
		counted = maxi(counted, int(level.get("_knocks")))
		if float(level.get("_reset_cooldown")) > 0.0:
			thrown = true
			break
		if paused:
			await _unpause()
			continue
		seconds += 1.0 / 60.0
	_check(thrown and counted >= 2, "three contacts put the apo back, and not before three",
		"warned at %d, thrown after %.1f s of standing in it" % [counted, seconds])
	if thrown:
		for _frame in range(40):
			await physics_frame
			if paused:
				await _unpause()
		_check(int(level.get("_knocks")) == 0, "and the fight comes back fresh",
			"the count is back to zero")
		_check(int(creature.call("state")) == Bakunawa.State.FIGHTING,
			"with the creature still up for it", "state FIGHTING")
		_check(String(root.get_node("PlayerProfile").call("bakunawa_outcome")) != "FOUGHT",
			"and losing is not recorded as winning", "no outcome written")
	await _close_the_level()


# --- The machinery -----------------------------------------------------------------------

func _open_the_level() -> void:
	level = (load("res://level_3.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(40):
		await physics_frame
	for node_name in ["DialogueNode", "BakunawaNode"]:
		var fork := level.get_node_or_null(
			NodePath("EnvironmentBaseplate/GameplayPlane/%s" % node_name)) as Node2D
		if fork != null:
			fork.set_process_mode(Node.PROCESS_MODE_DISABLED)
	await _unpause()


func _close_the_level() -> void:
	level.queue_free()
	for _frame in range(4):
		await physics_frame


## ⚠ THE BRUSH IS WHAT ARMS THE DRAIN. _morph_has_a_life() answers false only once new_brush
## is on the profile, so a probe that skips the pickup plays Dagat on Payyo's ten-second clock
## with no drain at all -- and reports a crossing as affordable without ever paying for it.
func _take_the_brush() -> void:
	var mark := level.get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/Marks/BrushMark") as Node2D
	if mark == null:
		return
	_place(mark.global_position)
	for _frame in range(20):
		await physics_frame
	await _unpause()


func _answer_the_shore(director: Variant) -> void:
	director.call("enter_obstacle", "L3_B0_SHORE")
	director.call("note_submission", "fish")
	director.call("exit_obstacle", "L3_B0_SHORE")
	await _unpause()


func _become_a_fish() -> void:
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	level.call("_spawn_or_replace", "fish", "Fish", sheet,
		RosterFixtures.for_rig("swimmer", "fish"))
	for _frame in range(6):
		await physics_frame


## ⚠ THROUGH apply_morph_state, NEVER global_position. A rig's bodies are top_level, so
## writing the node's position moves the node and leaves the physics at the origin -- the trap
## run_water_audit.gd documents and the one that made three code states report the same
## numbers.
func _place(at: Vector2) -> void:
	var body := level.get("player") as Node2D
	if body == null or not is_instance_valid(body):
		return
	if body.has_method("apply_morph_state"):
		body.call("apply_morph_state", {"position": at, "linear_velocity": Vector2.ZERO})
	else:
		body.global_position = at


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
