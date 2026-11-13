extends SceneTree
## LEVEL 1 TEACHES WHAT IS THERE AT THE DOOR, AND THE REST IN ITS MOMENT.
##   godot --headless --path game --script res://tests/run_tutorial_coverage_probe.gd
##
## Kent: "the tutorial should pop up for when the moment happens but there should be tutorial that
## is appropriate at the start like the movement, inventory, jump, etc" -- and of cards any key
## moved on, "it does not let me experience the tutorial". `run_tutorial_audit` reads the ledger;
## this plays it, with somebody at the keys:
##
##   the door's cards play the moment Payyo opens, in their order, one at a time
##   each waits for her to do what it shows -- another key does nothing -- and ticks when she has
##   she walks and jumps for real under those two; the others hold the world, dim up
##   each lights something real, and the last gone, she walks on
##   the rest wait for their moments: R at the wall waits for R and opens the canvas; the lantern
##   card holds the world for a click; becoming, E, flying and swimming come when they can matter
##   the route a player did not take is owed, and only that
##   a later level shows what is owed once, without Lolo, and nothing else from Level 1
##   SKIP TUTORIAL, a replay and an old save all owe nothing

const CHECKS := 43
const TutorialDoor = preload("res://tests/tutorial_door.gd")

var level: Node2D
var tutorial: TutorialDirector
var failures := 0
var checked := 0
## The run at the door, as it was seen: one entry per card, in the order shown.
var _shown: Array[Dictionary] = []
var _cards_after_the_run := 0
var _unpaused_in_run := 0
var _dim_low := 1.0
var _watching := false
var _skipped_left := -1
## Where she stood the moment the last card went: after it she may walk, so it is caught then.
var _x_at_the_end := INF
## lesson id -> times shown, for the run nobody is at the keys for.
var _counts := {}
## lesson id -> how its card went (TutorialSpotlight.finish), and whether the card up is live.
var _hows := {}
var _last_live := false
## When each card went and when each came, in seconds: the tick on a card done is seen before
## the next one takes its place.
var _gone_at := {}
var _came_at: Array[float] = []


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
	await _every_card_plays_at_the_door()
	await _the_rest_wait_for_their_moments()
	await _free_level()
	await _skip_at_the_door_ends_the_run()
	await _free_level()
	await _with_nobody_at_the_keys()
	await _free_level()
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


## Payyo, opened as a player opens it: somebody at the keys, so a card waits for a press and
## holds the world. Set on the frame it is added, before the opening (deferred) runs.
func _open_payyo_at_the_keys() -> void:
	root.get_node(^"/root/LevelManager").set("current_level_id", "level_1")
	level = (load("res://game_level.tscn") as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", false)
	tutorial = level.get("tutorial") as TutorialDirector


## ⚠ AND WAIT. A level still in the tree when the next one loads hands it its obstacle volumes
## through the group they share, and Piyesta reports four obstacles it has never heard of.
func _free_level() -> void:
	if process_frame.is_connected(_watch_the_run):
		process_frame.disconnect(_watch_the_run)
	Input.action_release(&"move_right")
	level.queue_free()
	level = null
	await _wait(0.2)


func _spot() -> TutorialSpotlight:
	return level.get("tutorial_spotlight") as TutorialSpotlight


func _press(action: StringName) -> void:
	for down in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = down
		Input.parse_input_event(event)


## The door's cards, in ledger order: what the run at the door owes the player.
func _cards() -> Array[String]:
	var out: Array[String] = []
	for id in tutorial.lesson_ids():
		var lesson: Dictionary = tutorial.call("_find", id)
		if bool(lesson.get("door", false)) and String(lesson.get("mode", "")) != "say":
			out.append(id)
	return out


func _on_taught(id: String) -> void:
	var spot := _spot()
	var lesson: Dictionary = tutorial.call("_find", id)
	var anchor := tutorial.entry_anchor_of(lesson)
	_last_live = bool(lesson.get("entry_live", false))
	_came_at.append(Time.get_ticks_msec() / 1000.0)
	_shown.append({"id": id, "mode": spot.lesson_mode(), "anchor": anchor, "live": _last_live,
		"target": level.call("_tutorial_target", anchor),
		"x": (level.get("player") as Node2D).global_position.x, "paused": paused,
		"bag": (level.get("inventory_hud") as Control).is_visible_in_tree()})
	# Lolo's own lines (`say`) are not cards, and keep their moments.
	if not tutorial.is_teaching_the_door() and String(lesson.get("mode", "")) != "say":
		_cards_after_the_run += 1


func _note_where_she_stands() -> void:
	_x_at_the_end = (level.get("player") as Node2D).global_position.x


func _on_finished(id: String, how: String) -> void:
	_hows[id] = how
	_gone_at[id] = Time.get_ticks_msec() / 1000.0


## Every frame of the run: the world held under every card but walking and jumping, and once the
## first card is in, the dim never dropping.
func _watch_the_run() -> void:
	if level == null or not tutorial.is_teaching_the_door():
		return
	if not paused and not _last_live:
		_unpaused_in_run += 1
	var spot := _spot()
	if _shown.size() > 1 or (spot.is_showing() and float(spot.get("_age")) > TutorialSpotlight.FADE_SEC):
		_dim_low = minf(_dim_low, float(spot.get("_fade")))


## Wait for the card up to settle, note where it stands and what it lights, and do what it shows.
## With `wrong` first, a press the card does not show -- which must leave it up. Returns false if
## no card came.
func _do_the_card(where: Array, wrong_for := {}) -> bool:
	var spot := _spot()
	var since := Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < 4000 \
			and not (spot.is_showing() and float(spot.get("_age")) > TutorialSpotlight.IRIS_SEC + 0.1):
		await process_frame
	if not spot.is_showing():
		return false
	var id := spot.lesson_id()
	var wrong: StringName = wrong_for.get(id, StringName())
	# Where the card stands and what is lit, once the hole has closed on its target.
	var target: Rect2 = level.call("_tutorial_target", _shown[-1]["anchor"])
	var hole := spot.hole_rect()
	var entry := {"lit": target.has_area() and hole.encloses(target)
		and hole.size.x <= target.size.x + TutorialSpotlight.HOLE_PAD * 2.0 + 2.0,
		"clear": not spot.card_rect().intersects(target)}
	if not String(wrong).is_empty():
		TutorialDoor.press(wrong)
		await _wait(0.3)
		var panel := level.get("draw_panel") as DrawPanel
		entry["stayed"] = spot.is_showing() and spot.lesson_id() == id and not panel.is_open() \
			and not bool(level.get("inventory_screen").call("is_open"))
	where.append(entry)
	TutorialDoor.press_for(spot.get("_lesson") as Dictionary, root)
	since = Time.get_ticks_msec()
	while spot.is_showing() and spot.lesson_id() == id and Time.get_ticks_msec() - since < 2000:
		await process_frame
	return true


func _every_card_plays_at_the_door() -> void:
	_profile().call("set_lessons_owed", [])
	_shown.clear()
	_hows.clear()
	_gone_at.clear()
	_came_at.clear()
	_open_payyo_at_the_keys()
	tutorial.lesson_taught.connect(_on_taught)
	_spot().finished.connect(_on_finished)
	process_frame.connect(_watch_the_run)
	await process_frame
	_check(tutorial.is_teaching_the_door() and _spot().is_showing(),
		"Payyo opens on a card", "card '%s'" % _spot().lesson_id())
	# Walking held from here to the last card: she walks under Walk and Jump, and nowhere else.
	var start_x := (level.get("player") as Node2D).global_position.x
	tutorial.door_taught.connect(_note_where_she_stands)
	Input.action_press(&"move_right")
	var where: Array = []
	var guard := 0
	while tutorial.is_teaching_the_door() and guard < 60:
		guard += 1
		# A key the card does not show, first: R under Walk, where the world runs and R would open
		# the canvas; Space under the bag's card, where the world is held.
		if not await _do_the_card(where, {"move": &"redraw", "bag_open": &"jump"}):
			break
	var ids: Array[String] = []
	for card in _shown:
		ids.append(String(card["id"]))
	_check(ids == _cards(), "every card in the ledger plays, in its order",
		", ".join(ids) if ids != _cards() else "%d cards" % ids.size())
	var wrong_kind: Array[String] = []
	var unlit: Array[String] = []
	var bag_ok := true
	for i in _shown.size():
		var card: Dictionary = _shown[i]
		# Live: done for real, the world running. Otherwise held, the press spent on the card.
		var right := String(card["mode"]) == "do" and not bool(card["paused"]) if bool(card["live"]) \
			else String(card["mode"]) == "look" and bool(card["paused"])
		if not right:
			wrong_kind.append(card["id"])
		if not (card["target"] as Rect2).has_area() or (i < where.size() and not bool(where[i]["lit"])):
			unlit.append(card["id"])
		bag_ok = bag_ok and bool(card["bag"]) == (String(card["anchor"]) == "inventory_bar")
	var lives := _shown.filter(func(c: Dictionary) -> bool: return bool(c["live"])).map(
		func(c: Dictionary) -> String: return String(c["id"]))
	_check(wrong_kind.is_empty() and lives == ["move", "jump"],
		"walking and jumping are done for real; every other card holds the world",
		"wrong: %s" % ", ".join(wrong_kind) if not wrong_kind.is_empty() else "live: %s" % ", ".join(lives))
	var wrong_press := where.filter(func(w: Dictionary) -> bool: return w.has("stayed"))
	var stayed := wrong_press.filter(func(w: Dictionary) -> bool: return bool(w["stayed"]))
	_check(wrong_press.size() == 2 and stayed.size() == 2,
		"another key does nothing: R under Walk, Space under the bag's card",
		"both cards stayed, nothing opened" if stayed.size() == 2
			else "%d of %d stayed -- A CARD MOVED ON OR SOMETHING OPENED" % [stayed.size(), wrong_press.size()])
	var not_done: Array[String] = []
	var shortest := INF
	for i in ids.size():
		if String(_hows.get(ids[i], "")) != "done":
			not_done.append("%s %s" % [ids[i], _hows.get(ids[i], "never")])
		if i + 1 < _came_at.size() and _gone_at.has(ids[i]):
			shortest = minf(shortest, _came_at[i + 1] - float(_gone_at[ids[i]]))
	_check(not_done.is_empty() and ids.size() > 0 and shortest >= 0.35,
		"each goes only when she does what it shows, its tick seen before the next",
		", ".join(not_done) if not not_done.is_empty() else "all done; shortest tick %.2f s" % shortest)
	_check(unlit.is_empty(), "each lights something real on the screen",
		"unlit: %s" % ", ".join(unlit) if not unlit.is_empty() else "all lit")
	var covered := where.filter(func(w: Dictionary) -> bool: return not bool(w["clear"]))
	_check(where.size() == _shown.size() and covered.is_empty(), "and no card stands over what it lights",
		"%d of %d measured, %d covered" % [where.size(), _shown.size(), covered.size()])
	_check(bag_ok, "the empty bag comes up for the cards about it, and only those",
		"bag shown only under inventory_bar cards" if bag_ok else "BAG SHOWN WRONG")
	_check(_unpaused_in_run == 0, "the world stays still under and between the held cards",
		"%d frames ran" % _unpaused_in_run)
	_check(_dim_low > 0.99, "and the screen stays dim from one card to the next", "lowest %.2f" % _dim_low)
	var at_third := float(_shown[2]["x"]) if _shown.size() > 2 else INF
	_check(at_third > start_x + 4.0 and absf(_x_at_the_end - at_third) < 0.5,
		"with walking held, she walks under Walk and Jump and nowhere else",
		"x %.1f, at the third card %.1f, at the end %.1f" % [start_x, at_third, _x_at_the_end])
	var player := level.get("player") as Node2D
	await _wait(0.6)
	# ⚠ Not "nothing is paused": she walked under Walk and Jump, so the stair's opening line can
	# be close enough to stop the world now, and that is the story's pause, not the tutorial's.
	var story := (level.get("dialogue_box") as DialogueBox).is_open()
	_check(not _spot().is_holding() and not _spot().is_busy()
		and (player.global_position.x > _x_at_the_end + 4.0 or story),
		"the last card gone, the tutorial lets go and she walks on", "x %.1f -> %.1f%s" % [_x_at_the_end,
			player.global_position.x, ", into the stair's line" if story else ""])
	Input.action_release(&"move_right")
	_check(not (level.get("inventory_hud") as Control).is_visible_in_tree(),
		"and the empty bag goes away again", "bag hidden")


## Until a card is up with this id, turning the pages of any line that leads it in and doing any
## other card that comes first, as a player would. False if none.
func _card_up(id: String, seconds: float = 12.0) -> bool:
	var spot := _spot()
	var box := level.get("dialogue_box") as DialogueBox
	var since := Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < seconds * 1000.0:
		if box.is_open():
			box.skip_all()
		if spot.is_showing() and float(spot.get("_age")) > 0.5:
			if spot.lesson_id() == id:
				return true
			# Another moment's card got there first -- the requirement, at the stair. Do it.
			TutorialDoor.press_for(spot.get("_lesson") as Dictionary, root)
			await _wait(0.3)
		await process_frame
	return false


## THE REST IN THEIR MOMENTS. Kent: "the tutorial should pop up for when the moment happens". Nothing
## comes while nothing happens; the wall brings the R card, which waits for R -- another key does
## not end it, and the world goes on working under it -- and R both ends it and opens the canvas.
## The lantern brings its card, which holds the world and waits for a click or Enter.
func _the_rest_wait_for_their_moments() -> void:
	var spot := _spot()
	Input.action_release(&"move_right")
	await _wait(0.5)
	tutorial.set("_gap", 0.0)
	tutorial.note("first_obstacle")
	var draw_up := await _card_up("draw")
	# Past the grace after which any key used to let a `do` card go (TutorialSpotlight.GRACE_SEC).
	await _wait(TutorialSpotlight.GRACE_SEC)
	TutorialDoor.press(&"jump")
	await _wait(0.4)
	var stayed := spot.is_showing() and spot.lesson_id() == "draw"
	TutorialDoor.press(&"redraw")
	await _wait(0.4)
	var panel := level.get("draw_panel") as DrawPanel
	_check(draw_up and stayed and String(_hows.get("draw", "")) == "done" and panel.is_open(),
		"at the wall the R card waits for R, and R opens the canvas",
		"came %s, stayed through Space %s, %s, canvas open %s" % [draw_up, stayed,
			_hows.get("draw", "not done"), panel.is_open()])
	panel.close_panel()
	await _wait(0.6)
	tutorial.set("_gap", 0.0)
	tutorial.note("checkpoint")
	var lantern_up := await _card_up("checkpoint")
	TutorialDoor.press(&"jump")
	await _wait(0.4)
	stayed = spot.is_showing() and spot.lesson_id() == "checkpoint" and paused
	TutorialDoor.press(&"ui_accept")
	await _wait(0.4)
	_check(lantern_up and stayed and String(_hows.get("checkpoint", "")) == "done",
		"at the lantern, its card holds the world until a click or Enter",
		"came %s, held through Space %s, %s" % [lantern_up, stayed, _hows.get("checkpoint", "not done")])


## SKIP TUTORIAL AT THE DOOR: the run ends, every card left is spent unshown, and the world goes.
func _skip_at_the_door_ends_the_run() -> void:
	_shown.clear()
	_open_payyo_at_the_keys()
	var on_skip := func(left: int) -> void:
		_skipped_left = left
	tutorial.tutorial_skipped.connect(on_skip)
	tutorial.lesson_taught.connect(_on_taught)
	var where: Array = []
	await process_frame
	await _do_the_card(where)
	await _do_the_card(where)
	var spot := _spot()
	var since := Time.get_ticks_msec()
	while not (spot.is_showing() and float(spot.get("_age")) > 0.2) and Time.get_ticks_msec() - since < 4000:
		await process_frame
	_press(&"skip_tutorial")
	await _wait(0.4)
	var unshown := 0
	for id in tutorial.lesson_ids():
		if tutorial.has_taught(id) and not tutorial.was_shown(id):
			unshown += 1
	_check(not tutorial.is_teaching_the_door() and not paused and not spot.is_holding()
		and not bool(level.get("_opening_running")),
		"SKIP at the door ends the run and lets the world go",
		"run on %s, paused %s, opening running %s" % [tutorial.is_teaching_the_door(), paused,
			level.get("_opening_running")])
	_check(_shown.size() == 3 and _skipped_left == unshown and unshown == tutorial.lesson_ids().size() - 3,
		"every card left is spent unshown, and the skip says how many",
		"%d shown, %d left unshown, skip reported %d" % [_shown.size(), unshown, _skipped_left])


## A clean ledger with these already spent, and nothing up.
func _fresh(spent: Array) -> void:
	var spot := _spot()
	if spot.is_busy():
		spot.finish("skipped")
	while spot.is_busy():
		await process_frame
	await _revert()
	tutorial.set_enabled(true)
	tutorial.load_for("level_1")
	tutorial.set("_gap", 0.0)
	tutorial.mark_taught(spent)
	# The door's cards were taught at the start, before any of these moments could come.
	tutorial.mark_taught(_cards())


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


func _walk_a_step() -> void:
	(level.get("player") as Node2D).global_position = Vector2(1700.0, 200.0)
	Input.action_press(&"move_right")
	await _wait(0.1)
	Input.action_release(&"move_right")


## Wait until a lesson has been shown, or the time is up.
func _shown_within(id: String, seconds: float) -> bool:
	var waited := 0.0
	while waited < seconds:
		if tutorial.was_shown(id):
			return true
		await _wait(0.1)
		waited += 0.1
	return tutorial.was_shown(id)


func _count_taught(id: String) -> void:
	_counts[id] = int(_counts.get(id, 0)) + 1


## NOBODY AT THE KEYS -- every headless suite. The run goes by itself, quickly, and the world is
## not held under it, so the moments its cards are about can come while it plays: none of them
## may bring its card back.
func _with_nobody_at_the_keys() -> void:
	_counts.clear()
	root.get_node(^"/root/LevelManager").set("current_level_id", "level_1")
	level = (load("res://game_level.tscn") as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	tutorial = level.get("tutorial") as TutorialDirector
	tutorial.lesson_taught.connect(_count_taught)
	var since := Time.get_ticks_msec()
	while _counts.is_empty() and Time.get_ticks_msec() - since < 5000:
		await process_frame
	# Every moment at once, mid-run: a checkpoint reached, a prompt up, a drawing stored...
	var events := {}
	for id in tutorial.lesson_ids():
		events[String((tutorial.call("_find", id) as Dictionary).get("at", ""))] = true
	for event: String in events:
		tutorial.note(event)
	# And a suite that wants to read a line itself turns auto-dismiss off part-way through, as
	# run_level1_audit does: the run began with nobody at the keys and goes on as it began.
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", false)
	while tutorial.is_teaching_the_door() and Time.get_ticks_msec() - since < 10000:
		await process_frame
	var took := (Time.get_ticks_msec() - since) / 1000.0
	# Nobody at the keys again, for what comes after: a lead line left waiting for a key would hold
	# back the very card this is watching for.
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	# Past the breath after a card (GAP_AFTER), a lead and a delay: long enough for anything
	# queued to have come back.
	await _wait(6.0)
	var wrong: Array[String] = []
	for id in _cards():
		if int(_counts.get(id, 0)) != 1:
			wrong.append("%s x%d" % [id, int(_counts.get(id, 0))])
	# She has not moved from the spawn, and nothing there is any card's moment but the door's.
	var early: Array[String] = []
	for id: String in _counts:
		var lesson: Dictionary = tutorial.call("_find", id)
		if not bool(lesson.get("door", false)) and String(lesson.get("mode", "")) != "say":
			early.append(id)
	_check(not tutorial.is_teaching_the_door() and took < 6.0 and wrong.is_empty() and not paused,
		"with nobody at the keys, the run goes by itself, each card once",
		"%.1f s; %s" % [took, ", ".join(wrong) if not wrong.is_empty() else "all once"])
	_check(early.is_empty(), "and at the spawn, no other card comes before its moment",
		"shown: %s" % ", ".join(early) if not early.is_empty() else "none")


## After the first gate, on the way to the lake: the first place it can matter.
func _the_card_about_becoming_comes_after_the_first_gate() -> void:
	await _fresh(["move", "jump", "draw", "bag_open", "bag_hints", "quest", "marker", "map", "pause"])
	await _walk_a_step()
	await _wait(0.4)
	_check(not tutorial.is_coming("become"), "nothing about becoming before the first gate",
		"queue %s" % str(tutorial.pending_ids()))
	tutorial.mark_taught(["checkpoint"])
	_check(await _shown_within("become", 16.0), "past it, walking on, she is told she can become things",
		"become")


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


## OWED BEFORE THIS: a save from when Level 1 taught each card in its moment can carry the ones
## a route missed. Finished having placed things and never having become anything.
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
