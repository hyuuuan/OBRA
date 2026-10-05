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
## How fast a swimmer goes along the bed, measured -- the same figure run_bakunawa_probe holds
## the sweep to.
const BED_SWIM := 100.0

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
	await _out_of_ink_past_a_seabed_checkpoint()
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
	# ⚠ HEARD FROM THE DRAIN, NOT READ OFF THE BAR. The rescue now comes on the frame the ink
	# runs out, and the restore hands the spend back with it -- so the bar is never seen at zero
	# by anything that looks a frame later.
	var ran_dry := [false]
	(level.get_node("InkDrain") as Object).connect(&"ink_emptied",
		func() -> void: ran_dry[0] = true, CONNECT_ONE_SHOT)
	var emptied := false
	var seconds := 0.0
	# Up to three minutes: a shape drinks half as fast since 2026-10-05, about 140 s on a full bar.
	while seconds < 180.0:
		# Open water off the home beach, which runs to 1600 since it grew (2026-10-05).
		_place(Vector2(1900.0, 1650.0))
		await physics_frame
		if paused:
			await _unpause()
			continue
		seconds += 1.0 / 60.0
		if ran_dry[0] or float(ink.call("remaining")) <= 0.0001:
			emptied = true
			break
	_check(emptied, "holding a body on the seabed empties the ink",
		"empty after %.1f s of swimming" % seconds)

	# The level's own zero case, not the generic screen.
	var overlay := level.get_node_or_null(^"OutOfInkOverlay")
	_check(overlay == null or not overlay.has_method("is_open")
			or not bool(overlay.call("is_open")),
		"and no out-of-ink screen opens over it", "Dagat answers for itself")

	# ⚠ NO CHECKPOINT IN THE WATER (2026-10-05). Kent: "the return to last checkpoint should not
	# work here if it is underwater" -- it rolled the whole run back, the bakunawa sent home
	# included. The body goes, the apo is where it was, and swims up on a breath.
	var checkpoints = level.get("checkpoints")
	var restored_before := int(checkpoints.call("restore_count", String(checkpoints.call("latest_id"))))
	var waterline := float(level.get("_waterline_y"))
	var surfaced := false
	for _frame in range(int(14.0 * 60.0)):
		await physics_frame
		if paused:
			await _unpause()
		if level.get("player") is Wanderer and (level.get("player") as Node2D).global_position.y \
				<= waterline + 40.0:
			surfaced = true
			break
	var apo := level.get("player") as Node2D
	_check(apo is Wanderer, "the body is given up rather than drowned in",
		"the apo is %s" % apo.get_class())
	_check(surfaced and apo.global_position.x > 1650.0,
		"and the apo comes up where they were, not back on the beach",
		"at %s, the surface at %.0f" % [apo.global_position.round(), waterline])
	_check(int(checkpoints.call("restore_count", String(checkpoints.call("latest_id")))) == restored_before,
		"and nothing is rolled back to a checkpoint", "no restore")

	# ⚠ AND THE RUN IS STILL WINNABLE. The restore used to be what handed the spent ink back; the
	# ink is handed back without it -- to where it stood at the last checkpoint, and never under
	# one unit -- so there is a swimmer to draw.
	var left := float(ink.call("remaining"))
	_check(left >= 0.99, "and there is ink to try again with",
		"%.2f of %.0f back" % [left, InkManagerClass.BUDGET])
	_check(not bool(level.get("_level_completed")), "and the level did not end on a loss",
		"still playing")
	await _close_the_level()


## ⚠ AND PAST A CHECKPOINT ON THE SEABED, WHERE THE RESCUE USED TO DROWN THEM AGAIN -- and where,
## since 2026-10-05, nothing is restored at all. CP3b is
## on the bed in the middle of the bakunawa's waters. Run dry past it, the apo was carried up,
## sank, and the rescue restored CP3b -- as the apo, who cannot swim, on the seabed. They drowned
## on arrival and the rescue fired again, about once a second, for good. The checkpoint gives
## back the shape that was held there now, and the rescue comes at once instead of after a sink.
func _out_of_ink_past_a_seabed_checkpoint() -> void:
	await _open_the_level()
	var director = level.get("director")
	var checkpoints = level.get("checkpoints")
	await _take_the_brush()
	await _answer_the_shore(director)
	director.call("enter_obstacle", "L3_N1")
	director.call("commit_route", "L3_N1", "pragmatist")
	director.call("note_submission", "fish")
	director.call("exit_obstacle", "L3_N1")
	await _unpause()
	await _become_a_fish()
	var mid := level.get_node_or_null(^"EnvironmentBaseplate/GameplayPlane/Obstacles/CP3b") \
		as Node2D
	for _frame in range(40):
		_place(mid.global_position)
		await physics_frame
		if paused:
			await _unpause()
		if String(checkpoints.call("latest_id")) == "CP3b":
			break
	_check(String(checkpoints.call("latest_id")) == "CP3b",
		"(past the seabed checkpoint) CP3b is written as a swimmer", "the fish is held there")
	var ink = level.get("ink_manager")
	_place(Vector2(5800.0, 1600.0))
	await physics_frame
	# Something of Lolo's still waiting its turn when the ink goes -- the dive's lore usually is.
	var first: Array[Dictionary] = [{"text": "A line being read.", "speaker": "lolo"}]
	var waiting: Array[Dictionary] = [{"text": "A line still waiting its turn.", "speaker": "lolo"}]
	level.call("_post_advice", first)
	level.call("_post_advice", waiting)
	ink.call("drain", float(ink.call("remaining")) - 0.02)
	var before := int(checkpoints.call("restore_count", "CP3b"))
	for _frame in range(300):
		await physics_frame
		if paused:
			await _unpause()
	var apo := level.get("player") as Node2D
	# ⚠ NOT A RESTORE AT ALL NOW (2026-10-05) -- and so not a loop of them either. Before, the apo
	# was put back on the seabed at CP3b and drowned again once a second; then CP3b gave back the
	# swimmer. Now nothing is restored in the water: the apo swims up from where they were.
	_check(int(checkpoints.call("restore_count", "CP3b")) == before,
		"running dry there restores nothing", "no restore of CP3b")
	_check(apo is Wanderer and absf(apo.global_position.x - 5800.0) < 300.0,
		"and the apo is in the water where the body was", "at %s" % apo.global_position.round())
	_check(float(ink.call("remaining")) >= 0.99, "with ink to draw a swimmer again",
		"%.2f left" % float(ink.call("remaining")))
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
	var creature := level.get_node(^"EnvironmentBaseplate/GameplayPlane/Bakunawa") as Bakunawa
	# Reach the mid-encounter checkpoint first, so what is lost is the stretch and not the
	# approach -- which is the thing CP3b exists for.
	_place(Vector2(6160.0, 1240.0))
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
		# ⚠ IN ITS LIGHT, NOT IN ITS BODY. Touching the body costs the stretch too now, with its own
		# words (level_3.gd _watch_the_bakunawa); this is about the sweep, so it is clear of the coils.
		_place(creature.global_position + Vector2(480.0, -60.0))
		await physics_frame
		if float(level.get("_reset_cooldown")) > 0.0:
			caught = true
			break
		if paused:
			await _unpause()
			continue
		seconds += 1.0 / 60.0
	# Read on the frame it happened: what the player is told when the light finds them.
	var told := (level.get("hint_bar") as HintBar).current_text() if caught else ""
	_check(caught, "swimming into the sweep costs the stretch",
		"moved off after %.1f s in its space" % seconds)
	if caught:
		# ⚠ WHAT TO DO, NOT ONLY WHAT HAPPENED. "It turned. Back to where you were" was the whole
		# of it, said to a player who then swam straight back into the same beam.
		_check(told.contains("Wait until its light turns away"),
			"and says what to do about it, not only what happened", "\"%s\"" % told)
		for _frame in range(40):
			await physics_frame
			if paused:
				await _unpause()
		var apo := level.get("player") as Node2D
		_check(apo.global_position.x < creature.global_position.x,
			"and puts the apo back west of it, not past it",
			"at x %.0f, the creature at %.0f" % [apo.global_position.x,
				creature.global_position.x])
		# ⚠ AND FAR ENOUGH BACK TO READ THAT BEFORE IT CAN SEE THEM AGAIN. A player still holding
		# forward when the reset lands -- every player, the first time -- was back inside its reach
		# a second later from a hundred pixels out, and was caught again: played, four times in
		# five seconds.
		var anchor := level.call("_anchor_now") as Vector2
		var to_reach := creature.global_position.x - creature.reach() - anchor.x
		_check(to_reach / BED_SWIM >= 2.0,
			"and far enough back to read that before it can see them again",
			"%.0f px short of its reach: %.1f s of swimming at %.0f px/s"
				% [to_reach, to_reach / BED_SWIM, BED_SWIM])
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
		_check(resting.distance_to(creature.global_position) > creature.reach(),
			"which is measured, not hoped for",
			"%.0f px away, its cone reaches %.0f"
				% [resting.distance_to(creature.global_position), creature.reach()])
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
	_place(Vector2(6160.0, 1240.0))
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
	# The shore is the brush, and taking it answers the beat with nothing drawn.
	director.call("solve_with_item", "L3_B0_SHORE", "new_brush")
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
