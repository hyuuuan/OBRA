extends SceneTree
## LEVEL 1 TEACHES THE GAME, WHATEVER ROUTE IS TAKEN THROUGH IT.
##   godot --headless --path game --script res://tests/run_tutorial_coverage_probe.gd
##
## Kent: "fix level 1 like tutorial part make sure it covers everything and other levels wont have
## any tutorials if necessary". `run_tutorial_audit` reads the ledger; this plays it:
##
##   the new lessons come in their moment, in the real level, with real input
##   somebody who already did the thing is not told
##   the route a player did not take is owed, and only that
##   a later level shows what is owed once, without Lolo, and nothing else from Level 1
##   SKIP TUTORIAL, a replay and an old save all owe nothing

const CHECKS := 26

var level: Node2D
var tutorial: TutorialDirector
var failures := 0
var checked := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if not ok:
		failures += 1
	print("  %s  %-58s %s" % ["OK  " if ok else "FAIL", what, detail])


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _profile() -> Node:
	return root.get_node(^"/root/PlayerProfile")


func _run() -> void:
	print("\n===== WHAT LEVEL 1 TEACHES =====")
	await _load_level(load("res://game_level.tscn") as PackedScene, "level_1")
	await _the_card_about_becoming_comes_after_the_first_gate()
	await _somebody_who_became_something_is_not_told()
	await _e_is_taught_once_past_the_first_gate()
	await _a_flier_is_taught_to_flap()
	await _somebody_already_flapping_is_not_told()
	await _a_swimmer_is_taught_to_swim()
	await _the_route_not_taken_is_owed()
	_a_replay_owes_nothing_new()
	_skipping_owes_nothing()
	await _free_level()
	await _a_later_level_shows_what_is_owed()
	await _an_old_save_owes_nothing()

	var ok := failures == 0 and checked == CHECKS
	print("OBRA_TUTORIAL_COVERAGE_%s" % ("OK" if ok
		else "FAILED=%d checked=%d of %d" % [failures, checked, CHECKS]))
	quit(0 if ok else 1)


func _load_level(scene: PackedScene, level_id: String) -> void:
	root.get_node(^"/root/LevelManager").set("current_level_id", level_id)
	level = scene.instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.2)
	tutorial = level.get("tutorial") as TutorialDirector
	# The opening conversation turns the tutorial off for a profile that has been here before,
	# and this probe's level_id is reused: whether it is on is each check's own business.
	tutorial.set_enabled(true)


## ⚠ AND WAIT. A level still in the tree when the next one loads hands it its obstacle volumes
## through the group they share, and Piyesta reports four obstacles it has never heard of.
func _free_level() -> void:
	level.queue_free()
	level = null
	await _wait(0.2)


## A clean ledger with these already spent, and nothing up.
func _fresh(spent: Array) -> void:
	var spot := level.get("tutorial_spotlight") as TutorialSpotlight
	if spot.is_busy():
		spot.finish("skipped")
	while spot.is_busy():
		await process_frame
	await _revert()
	tutorial.set_enabled(true)
	tutorial.load_for("level_1")
	tutorial.set("_gap", 0.0)
	tutorial.mark_taught(spent)


func _revert() -> void:
	if not (level.get("player") is Wanderer):
		level.call("_revert_to_base_form")
		await _wait(0.2)


func _become(entity_id: String) -> void:
	var drawing := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	drawing.fill(Color.WHITE)
	var strokes: Array = []
	if entity_id == "bird":
		strokes = preload("res://tests/drawn_like_people_fixtures.gd")._bird_side()
	level.call("_on_drawing_ready", entity_id, entity_id.capitalize(), drawing, {}, strokes, 0.0)
	await _wait(0.5)


## Wait until a lesson has been shown, or the time is up.
func _shown_within(id: String, seconds: float) -> bool:
	var waited := 0.0
	while waited < seconds:
		if tutorial.was_shown(id):
			return true
		await _wait(0.1)
		waited += 0.1
	return tutorial.was_shown(id)


func _walk_a_step() -> void:
	(level.get("player") as Node2D).global_position = Vector2(1700.0, 200.0)
	Input.action_press(&"move_right")
	await _wait(0.1)
	Input.action_release(&"move_right")


## After the first gate, on the way to the lake: the first place it can matter.
func _the_card_about_becoming_comes_after_the_first_gate() -> void:
	await _fresh(["move", "jump", "draw"])
	await _walk_a_step()
	await _wait(0.4)
	_check(not tutorial.is_coming("quest") and not tutorial.is_coming("become"),
		"nothing about quests or becoming before the first gate", "queue %s" % str(tutorial.pending_ids()))
	tutorial.mark_taught(["checkpoint"])
	_check(await _shown_within("quest", 6.0), "past it, the quest card is lit", "quest")
	var box := level.call("_tutorial_target", "quest_card") as Rect2
	_check(box.has_area(), "and it lights a card that is really there", str(box))
	_check(await _shown_within("become", 16.0), "and walking on, she is told she can become things", "become")


## NOT WHAT THEY ALREADY DID.
func _somebody_who_became_something_is_not_told() -> void:
	await _fresh(["move", "jump", "draw", "checkpoint", "quest"])
	await _become("frog")
	_check(tutorial.has_taught("become") and not tutorial.was_shown("become"),
		"somebody who already became something is not told they can",
		"spent, unshown" if not tutorial.was_shown("become") else "SHOWN")
	await _revert()


## E is first offered beside the first drawing she set down, in the middle of the seven lessons
## about it. Pressing it there pockets the thing she was about to climb, so it waits.
func _e_is_taught_once_past_the_first_gate() -> void:
	await _fresh(["move", "jump", "draw", "quest", "become"])
	tutorial.note("pickup_ready")
	_check(not tutorial.is_coming("interact"), "E waits until the first gate is behind her",
		"queue %s" % str(tutorial.pending_ids()))
	tutorial.mark_taught(["checkpoint"])
	tutorial.note("pickup_ready")
	_check(tutorial.is_coming("interact"), "past it, the E prompt brings the lesson",
		"queue %s" % str(tutorial.pending_ids()))
	var lesson: Dictionary = tutorial.call("_find", "interact")
	_check(String(lesson.get("mode", "")) == "look", "and it is a card she reads, not one she obeys",
		"a do card's E would pocket what she is standing at")


func _a_flier_is_taught_to_flap() -> void:
	await _fresh(["move", "jump", "draw", "checkpoint", "quest", "become", "revert", "clock"])
	await _become("bird")
	_check(await _shown_within("fly", 3.0), "a flier is shown the flap", "fly")
	await _revert()


func _somebody_already_flapping_is_not_told() -> void:
	await _fresh(["move", "jump", "draw", "checkpoint", "quest", "become", "clock"])
	await _become("bird")
	_check(tutorial.is_coming("revert") and not tutorial.is_coming("fly"), "and flapping waits its turn",
		"queue %s" % str(tutorial.pending_ids()))
	tutorial.mark_taught(["revert"])
	tutorial.note("can_fly")
	_check(tutorial.is_coming("fly"), "behind changing back", "queue %s" % str(tutorial.pending_ids()))
	var event := InputEventAction.new()
	event.action = &"jump"
	event.pressed = true
	Input.parse_input_event(event)
	await _wait(0.1)
	var release := InputEventAction.new()
	release.action = &"jump"
	release.pressed = false
	Input.parse_input_event(release)
	_check(tutorial.has_taught("fly") and not tutorial.was_shown("fly"),
		"and somebody already flapping is not told", "spent, unshown" if not tutorial.was_shown("fly") else "SHOWN")
	await _revert()


## In water it is W and S that move a swimmer; on land nothing about it is true.
func _a_swimmer_is_taught_to_swim() -> void:
	await _fresh(["move", "jump", "draw", "checkpoint", "quest", "become", "revert", "clock"])
	(level.get("player") as Node2D).global_position = Vector2(1700.0, 200.0)
	await _wait(0.2)
	await _become("fish")
	_check(not tutorial.is_coming("swim"), "a swimmer on dry land is not told to swim",
		"queue %s" % str(tutorial.pending_ids()))
	await _revert()
	await _fresh(["move", "jump", "draw", "checkpoint", "quest", "become", "revert", "clock"])
	(level.get("player") as Node2D).global_position = Vector2(2560.0, 400.0)
	await _wait(0.2)
	await _become("fish")
	var form := level.get("player") as Node2D
	var at := Vector2(2560.0, 480.0)
	if form.has_method("apply_morph_state"):
		form.call("apply_morph_state", {"position": at, "linear_velocity": Vector2.ZERO})
	_check(await _shown_within("swim", 4.0), "in the lake, W and S are shown", "swim")
	await _revert()


## Finished having placed things and never having become anything.
func _the_route_not_taken_is_owed() -> void:
	await _fresh(["move", "jump", "draw", "canvas", "transform", "checkpoint", "quest",
		"become", "place", "resize", "rotate", "undo", "ink", "climb", "interact"])
	_profile().call("set_lessons_owed", [])
	level.call("mark_finished", "level_1")
	var owed: Array = _profile().call("lessons_owed")
	_check(owed.has("revert") and owed.has("fly") and owed.has("clock"),
		"a run that never became anything owes those lessons", str(owed))
	_check(not owed.has("place") and not owed.has("climb"), "and not the ones it reached", str(owed))
	_check(not owed.has("ink") and not owed.has("move"), "and never one that does not carry", str(owed))


func _a_replay_owes_nothing_new() -> void:
	_profile().call("set_lessons_owed", ["revert"])
	tutorial.set_enabled(false)
	level.call("mark_finished", "level_1")
	_check(_profile().call("lessons_owed") == ["revert"], "a replay, its tutorial off, leaves the debt alone",
		str(_profile().call("lessons_owed")))
	tutorial.set_enabled(true)


func _skipping_owes_nothing() -> void:
	_profile().call("set_lessons_owed", ["revert"])
	tutorial.load_for("level_1")
	tutorial.skip_rest()
	_check((_profile().call("lessons_owed") as Array).is_empty(), "SKIP TUTORIAL owes nothing",
		str(_profile().call("lessons_owed")))
	level.call("mark_finished", "level_1")
	_check((_profile().call("lessons_owed") as Array).is_empty(), "and finishing the level does not put it back",
		str(_profile().call("lessons_owed")))


## Piyesta has no lessons of its own, so anything it shows came from what was owed.
func _a_later_level_shows_what_is_owed() -> void:
	_profile().call("set_lessons_owed", ["revert", "clock"])
	await _load_level(load("res://level_2.tscn") as PackedScene, "level_2")
	var ids := tutorial.lesson_ids()
	_check(ids.size() == 2 and ids.has("revert") and ids.has("clock"),
		"a later level takes on what is owed and nothing else", str(ids))
	_check(tutorial.has_taught("checkpoint") and not tutorial.was_shown("checkpoint"),
		"what Level 1 did teach counts as taught", "checkpoint")
	var lesson: Dictionary = tutorial.call("_find", "revert")
	_check(tutorial.lead_of(lesson).is_empty(), "and it comes without Lolo's lead", "no lead")
	await _become("horse")
	_check(await _shown_within("revert", 8.0), "and it shows the first time she becomes something",
		"revert")
	await _free_level()


func _an_old_save_owes_nothing() -> void:
	var snapshot: Dictionary = _profile().get("_data")
	snapshot.erase("lessons_owed")
	_check((_profile().call("lessons_owed") as Array).is_empty(), "a save from before this owes nothing",
		"no key")
	var director := TutorialDirector.new()
	root.add_child(director)
	director.load_for("level_2")
	_check(director.lesson_ids().is_empty(), "so a later level teaches it nothing from Level 1",
		str(director.lesson_ids()))
	director.queue_free()
	await process_frame
