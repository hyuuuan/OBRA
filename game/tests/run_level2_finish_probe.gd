extends SceneTree
## CAN PIYESTA ACTUALLY BE FINISHED? Nothing asked.
##   godot --headless --path game --script res://tests/run_level2_finish_probe.gd
##
## `run_level2_chain_probe` proves the chain of places is joined -- door to church, church
## to alley, alley to alley -- and it stops one step short on purpose: it OPENS Scene 3 and
## then closes it again, because leaving a modal up leaves the tree paused under every audit
## after it. So the last thing the level does has never been done.
##
## That gap is exactly the one Level 1 shipped with. `run_level1_audit` proved Beat 0
## accepted a square while the level was unplayable, and the finish probe written afterwards
## is what found that the ladder ate the key press. Bookkeeping is not an ending.
##
## What is held here:
##   the three beats can be answered, in order, by drawing at them
##   answering the last one is what opens the table -- not walking anywhere
##   the seventh piece going home ends the level and shows the player it did
##   the ending Lolo was written for is actually said
##   and Piyesta is the level that reaches the ending screen

var level: Node2D
var director
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-46s %s" % ["OK  " if ok else "FAIL", what, detail])


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout


## Clear whatever is on screen and hand the world back.
##
## ⚠ WRITING `paused` IS NOT ENOUGH. UIRouter DERIVES the pause from whichever modals are
## open and re-asserts it, so a probe that unpauses by hand is overruled on the next refresh.
## The overlays have to be closed, which is what a player pressing on does.
func _clear() -> void:
	for node in level.get_tree().get_nodes_in_group(ModalOverlay.GROUP):
		if node.has_method(&"is_open") and bool(node.call(&"is_open")) \
				and node.has_method(&"close"):
			node.call("close")
	UIRouter.refresh_pause(level.get_tree())
	level.get_tree().paused = false


func _run() -> void:
	level = (load("res://level_2.tscn") as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.4)
	director = level.get("director")
	if director == null:
		print("OBRA_LEVEL2_FINISH_FAILED=1  (no obstacle layer)")
		quit(1)
		return

	await _audit_the_three_beats_answer()
	await _audit_the_table_ends_it()
	_audit_the_ending_is_spoken()
	_audit_piyesta_is_the_last_level()

	print("OBRA_LEVEL2_FINISH_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)


## THE THREE BEATS, ANSWERED BY DRAWING AT THEM, in the order a player meets them.
##
## Every route is checked for at least one class the tag layer actually resolves, because a
## route whose accept set is empty after exclusions is a beat with no answer -- the fault
## `AbilityTags` exists to make impossible and the one `run_level2_audit` checks in the data.
## This checks it in the running level, which is where a class that has no rig, no mechanism
## or no entry in `entities.json` shows up instead.
func _audit_the_three_beats_answer() -> void:
	for beat in [
		{"id": "L2_N1", "route": "pragmatist"},
		{"id": "L2_N2", "route": "artist"},
		{"id": "L2_N3", "route": "artist"},
	]:
		var id := String(beat["id"])
		var route := String(beat["route"])
		# ⚠ THE ACCEPT SET IS READ AFTER ENTERING AND COMMITTING, because that is what
		# narrows it to this route. Asking the director cold returns the union over every
		# route on the beat, which would let a class that answers a DIFFERENT route pass for
		# this one.
		director.enter_obstacle(id)
		director.commit_route(id, route)
		await _wait(0.2)
		var accepted: PackedStringArray = director.accept_set(id)
		_check(accepted.size() >= 2, "%s/%s has more than one answer" % [id, route],
			", ".join(accepted) if accepted.size() > 0 else "NOTHING can answer it")
		if accepted.is_empty():
			continue
		level.call("_judge_submission", accepted[0])
		await _wait(0.6)
		_clear()
		_check(director.is_solved(id), "%s is answered by drawing a %s" % [id, accepted[0]],
			"solved" if director.is_solved(id) else "the drawing was not accepted")


## THE LAST BEAT OPENS THE TABLE, AND THE TABLE ENDS THE LEVEL.
##
## ⚠ NOT A PLACE. Piyesta had a GoalMarker inherited from `game_level.tscn` -- a text copy --
## parked past the east wall of Alley 2 and clearing the alley floor by thirty-five units. It
## is gone, and this is the audit that says the ending is the seventh piece going home rather
## than a spot somebody walks to.
func _audit_the_table_ends_it() -> void:
	var table := level.get("assembly_screen") as AssemblyOverlay
	var assembly = level.get("assembly")
	var overlay := level.get_node_or_null("LevelCompleteOverlay")
	if table == null or assembly == null or overlay == null:
		_check(false, "the level has a table and a completion screen", "-")
		return

	level.call("_open_scene_3")
	await _wait(0.5)
	_check(table.is_open(), "the last beat opens Scene 3", "the table is up")
	_check(not bool(overlay.call("is_open")),
		"and an open table has not ended anything yet",
		"seven pieces still to place")

	# ⚠ DRAGGED, NOT PLACED ON THE MODEL. `ScrapAssembly.place_now` writes the model and
	# nothing else -- the overlay finishes from its own DROP handler -- so a probe that fills
	# the model directly assembles a whole painting behind a table that never notices. The
	# first version of this did exactly that and reported "the painting is whole and the
	# level has not ended", which was true of the probe and not of the game.
	var ids: Array = table.call("piece_ids")
	_check(ids.size() == assembly.slot_count(), "the table lays out every piece",
		"%d on the board, %d slots" % [ids.size(), assembly.slot_count()])

	# ONE SHORT FIRST. Dropping the last piece in the same pass as the first six would let a
	# completion that fired on ANY placement pass. It has to be the SEVENTH.
	for index in range(ids.size() - 1):
		table.call("drag_to", ids[index], table.call("slot_of", ids[index]))
	await _wait(0.3)
	_check(not assembly.is_complete() and not bool(overlay.call("is_open")),
		"six of seven does not end it",
		"%d of %d placed, the screen is down" % [assembly.placed(), assembly.slot_count()])

	table.call("drag_to", ids[ids.size() - 1], table.call("slot_of", ids[ids.size() - 1]))
	await _wait(0.4)
	_check(assembly.is_complete(), "the seventh piece goes home",
		"%d of %d" % [assembly.placed(), assembly.slot_count()])

	# ⚠ AND THE TABLE HAS TO OFFER THE WAY OUT. The level ends on CONTINUE, not on the last
	# drop -- so a `_finish` that placed the piece and never revealed the button would leave
	# the player looking at a whole painting with nothing to press.
	_check(bool(table.call("is_finished")), "and the table offers the way out",
		"CONTINUE is up" if bool(table.call("is_finished"))
		else "the painting is whole and there is nothing to press")
	table.call("_on_continue")
	await _wait(1.6)
	_check(bool(overlay.call("is_open")), "and THAT is what ends Piyesta",
		"the completion screen is up" if bool(overlay.call("is_open"))
		else "the painting is whole and the level has not ended")
	_clear()


## Piyesta is the last level that is built, so it is the one that carries the run's ending.
## Payyo held the flag while it was the only level there was, and a flag left behind is a
## player sent to the ending screen with this level unplayed.
func _audit_piyesta_is_the_last_level() -> void:
	var manager := root.get_node_or_null("LevelManager")
	if manager == null:
		_check(false, "Piyesta ends the run", "no LevelManager")
		return
	var mine := bool((manager.call("get_level", "level_2") as Dictionary).get("ends_run", false))
	var payyo := bool((manager.call("get_level", "level_1") as Dictionary).get("ends_run", false))
	_check(mine and not payyo, "Piyesta ends the run and Payyo does not",
		"piyesta=%s payyo=%s" % [mine, payyo])
	_check(ResourceLoader.exists("res://ui/ending_screen.tscn"),
		"and there is an ending for it to reach", "ending_screen.tscn")


## ⚠ THE LEVEL'S WHOLE ENDING WAS AUTHORED AND NEVER FIRED.
##
## `dialogue_l2.json` has carried four EXIT_MARKER lines since the file was written -- the
## table ("Lay them out. Corners first"), the painting whole ("There she is. Piyesta."), the
## crease, and the line that hands the player on to Level 3 -- and nothing in `level_2.gd`
## called any of them. The level went from the table to a completion screen in silence.
##
## Asked of the SCRIPT rather than of the box, because the box is a queue with a key to
## advance it and the point is that the hooks were reached at all.
func _audit_the_ending_is_spoken() -> void:
	var lines = level.get("script_lines")
	if lines == null:
		_check(false, "the ending is spoken", "no dialogue script")
		return
	# ⚠ THE OPENING IS ON THIS LIST TOO, and `L2_START.teach` is the important one: it is the
	# only place the player is told that the bandaritas are a ceiling and that small animals
	# are refused. Without it the first violation arrives with Lolo saying "Hoy! I told you"
	# to somebody he never told.
	for hook in ["L2_START.enter", "L2_START.teach",
			"EXIT_MARKER.enter", "EXIT_MARKER.assembled", "EXIT_MARKER"]:
		_check(bool(lines.call("has_heard", hook)), "%s is said" % hook,
			"heard" if bool(lines.call("has_heard", hook))
			else "authored, and nothing fires it")
