extends SceneTree
## The dance, played rather than scored on paper.
##
##	 godot --headless --path game --script res://tests/run_dance_probe.gd
##
## `run_level2_systems_probe` already proves `DanceMinigame` counts correctly: two attempts,
## four cues to clear, the kandila never withheld. Every one of those was true for weeks
## while the route DEAD-ENDED, because nothing anywhere called any of it. That is the same
## gap as `run_level1_audit` proving Beat 0 accepted a square while the level was
## unplayable -- bookkeeping is not playing.
##
## So this drives the screen: commit the route, wait for the overlay, and finish strokes at
## real times against the real clock. What it asserts is the thing the design cares about --
## **this node can never dead-end the run** -- on the path where the player is good at it and
## on the path where they are hopeless.

## ⚠ REACHED BY PATH, NOT BY NAME. A `--script` run does not register autoload identifiers,
## so `PlayerProfile` is not a compile-time symbol here even though the node exists. Same
## reason `level_2.gd` extends its base by path.
func _profile() -> Node:
	return root.get_node_or_null(^"/root/PlayerProfile")


var results: Array[String] = []
var failures := 0
var level: Node


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	results.append("  %s  %-42s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	print("\n===== THE DANCE =====")
	await _audit_the_route_opens_the_screen()
	await _audit_dancing_well_earns_the_flower()
	await _audit_dancing_badly_still_ends_the_beat()

	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_DANCE_OK")
		quit(0)
	else:
		print("OBRA_DANCE_FAILED=%d" % failures)
		quit(1)


func _open() -> Node:
	var fresh := (load("res://level_2.tscn") as PackedScene).instantiate()
	(fresh.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(fresh)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(30):
		await physics_frame
	return fresh


## Commit the Artist route the way the choice screen does, and wait for the lane to come up.
## The overlay opens on a timer -- deliberately, so the rhythm screen does not land on top
## of the sentence the apo just said -- so this waits rather than asking on the next frame.
func _reach_the_screen(fresh: Node) -> DanceOverlay:
	var director = fresh.get("director")
	director.call("commit_route", "L2_N1", "artist")
	var screen := fresh.get("dance_screen") as DanceOverlay
	for _frame in range(240):
		if screen != null and screen.is_open():
			break
		await physics_frame
	return screen


## Finish a stroke at `at` seconds into the attempt, waiting the clock out rather than
## poking the model directly -- the whole point is that the screen's own clock is what the
## verdict comes from.
func _stroke_at(screen: DanceOverlay, at: float) -> String:
	for _frame in range(900):
		if screen.clock() >= at:
			break
		if not screen.is_open():
			return "closed"
		await physics_frame
	return screen.perform_stroke()


func _audit_the_route_opens_the_screen() -> void:
	var fresh := await _open()
	var screen := await _reach_the_screen(fresh)
	# ⚠ THE ASSERTION THE WHOLE COMMIT EXISTS FOR. Before this, committing "I will dance for
	# them" closed the other two routes and nothing happened at all.
	_check(screen != null and screen.is_open(),
		"committing the route opens the dance", "the route that had no answer now has one")
	_check(screen != null and not screen.closes_on_cancel,
		"and Escape cannot dismiss it",
		"it is the only door out of a route already committed to")
	var director = fresh.get("director")
	_check(not bool(director.call("is_solved", "L2_N1")),
		"and nothing is solved just by opening it", "the performance has not happened yet")
	fresh.queue_free()
	await process_frame


## Four of six lands it, which is the model's own threshold. Struck on the beat, so the
## verdicts should be perfect and the flower should follow.
func _audit_dancing_well_earns_the_flower() -> void:
	var fresh := await _open()
	var screen := await _reach_the_screen(fresh)
	if screen == null or not screen.is_open():
		_check(false, "the dance screen came up to be played", "no screen")
		fresh.queue_free()
		return
	var dance := fresh.get("dance") as DanceMinigame
	var track := dance.track()
	var perfect := 0
	for index in range(track.size()):
		var verdict := await _stroke_at(screen, track[index])
		if verdict == "perfect":
			perfect += 1
	_check(perfect >= DanceMinigame.CUES_TO_CLEAR,
		"a stroke on the beat is judged perfect",
		"%d of %d on the nose" % [perfect, track.size()])
	# The screen holds the result up for a moment before it closes, and the level solves
	# the beat off its `run_finished`.
	for _frame in range(420):
		if not screen.is_open():
			break
		await physics_frame
	_check(dance.cleared(), "and clearing it is what earns the flower",
		"landed %d, needed %d" % [dance.landed(), DanceMinigame.CUES_TO_CLEAR])
	_check(bool(_profile().call("is_collectible_found", "L2_HF")),
		"which is recorded on the profile", "L2_HF, for the ending resolver")
	await _the_beat_is_closed(fresh, "cleared")
	fresh.queue_free()
	await process_frame


## ⚠ THE ONE THAT MATTERS. The design says the level is unloseable: fail both goes and the
## dancers hand over the kandila anyway, withholding only the flower, and say nothing about
## it. A player who is bad at rhythm games must not be stuck at the first beat of the level.
func _audit_dancing_badly_still_ends_the_beat() -> void:
	var fresh := await _open()
	var screen := await _reach_the_screen(fresh)
	if screen == null or not screen.is_open():
		_check(false, "the dance screen came up to be failed", "no screen")
		fresh.queue_free()
		return
	var dance := fresh.get("dance") as DanceMinigame
	# Both goes, every cue missed by a mile. Nothing is struck at all -- the cues simply go
	# past, which is what a player who does not understand the screen actually does.
	for _attempt in range(DanceMinigame.MAX_ATTEMPTS):
		for _frame in range(2400):
			if dance.is_finished() or not screen.is_open():
				break
			await physics_frame
		if dance.is_finished():
			break
	_check(dance.is_finished(), "both goes run out on their own",
		"%d attempts used, nothing struck" % dance.attempts_used())
	_check(not dance.cleared(), "and it is not cleared", "landed %d" % dance.landed())
	# ⚠ ASSERTED ON THE MODEL, NOT ON THE PROFILE, and the first version of this got it
	# wrong. `L2_HF` is written to the PROFILE, which is global and outlives a level
	# instance -- and the audit above has just earned it on a run that cleared. So
	# "the profile does not have the flower" is false here for a reason that has nothing to
	# do with this run, and the compound that tried to allow for it (`had_flower or not
	# found`) short-circuited to true and could never fail. What is actually being claimed
	# is that this run did not earn one, and `flower_earned()` says exactly that.
	_check(not dance.flower_earned(),
		"so the flower is withheld", "and nothing on screen says so -- it is a secret")
	# THE KANDILA IS NEVER WITHHELD.
	for _frame in range(420):
		if not screen.is_open():
			break
		await physics_frame
	_check(dance.kandila_earned(), "but the kandila is handed over anyway",
		"the level cannot dead-end at its first beat")
	await _the_beat_is_closed(fresh, "failed twice")
	fresh.queue_free()
	await process_frame


## Whichever way the dance went, the beat has to be finished and the level has to move on:
## the obstacle solved, the candle in hand, and the church open. This is the difference
## between a screen that runs and a screen that resolves.
func _the_beat_is_closed(fresh: Node, how: String) -> void:
	var director = fresh.get("director")
	for _frame in range(240):
		if bool(director.call("is_solved", "L2_N1")):
			break
		await physics_frame
	_check(bool(director.call("is_solved", "L2_N1")),
		"the beat is closed either way (%s)" % how,
		"solved without a submission -- a dance is not a drawing")
	_check(bool(fresh.get("_has_kandila")), "the candle is in hand (%s)" % how,
		"which is what opens the church")
	var open := false
	for node in fresh.get_tree().get_nodes_in_group(&"piyesta_doors"):
		var door := node as PiyestaDoor2D
		if door != null and door.door_id == "church" and fresh.is_ancestor_of(door) and door.open:
			open = true
	_check(open, "and the church is open (%s)" % how, "the level goes on")
