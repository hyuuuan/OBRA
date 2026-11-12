extends SceneTree
## LEVEL 1 TEACHES THE GAME AT THE DOOR, AND THEN NOTHING IS LEFT.
##   godot --headless --path game --script res://tests/run_tutorial_coverage_probe.gd
##
## Kent: "i want the pop ups to all be done right before the player does something in level 1
## like the moment the player enters level 1, i want all tutorial pop ups to be present from
## movement to drawing to checking inventory, make sure nothing is left". `run_tutorial_audit`
## reads the ledger; this plays it, with somebody at the keys:
##
##   every card in the ledger plays the moment Payyo opens, in its order, one at a time
##   each a look card lighting something real, the world held still and the dim up throughout
##   she cannot take a step until the last one goes, and then she can
##   after it no card comes, whatever happens: nothing is left, and nothing is owed
##   SKIP TUTORIAL ends the run at the door and lets the world go
##   what an older save owes still shows once in a later level, without Lolo

const CHECKS := 28

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
	await _and_then_nothing_is_left()
	await _free_level()
	await _skip_at_the_door_ends_the_run()
	await _free_level()
	await _with_nobody_at_the_keys()
	await _free_level()
	await _load_level(load("res://game_level.tscn") as PackedScene, "level_1")
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


## Every card the ledger holds, in its order: what the run at the door owes the player.
func _cards() -> Array[String]:
	var out: Array[String] = []
	for id in tutorial.lesson_ids():
		if String((tutorial.call("_find", id) as Dictionary).get("mode", "")) != "say":
			out.append(id)
	return out


func _on_taught(id: String) -> void:
	var spot := _spot()
	var lesson: Dictionary = tutorial.call("_find", id)
	var anchor := tutorial.entry_anchor_of(lesson)
	_shown.append({"id": id, "mode": spot.lesson_mode(), "anchor": anchor,
		"target": level.call("_tutorial_target", anchor),
		"x": (level.get("player") as Node2D).global_position.x, "paused": paused,
		"bag": (level.get("inventory_hud") as Control).is_visible_in_tree()})
	# Lolo's own lines (`say`) are not cards, and keep their moments.
	if not tutorial.is_teaching_everything() and String(lesson.get("mode", "")) != "say":
		_cards_after_the_run += 1


func _note_where_she_stands() -> void:
	_x_at_the_end = (level.get("player") as Node2D).global_position.x


## Every frame of the run: the world held, and once the first card is in, the dim never dropping.
func _watch_the_run() -> void:
	if level == null or not tutorial.is_teaching_everything():
		return
	if not paused:
		_unpaused_in_run += 1
	var spot := _spot()
	if _shown.size() > 1 or (spot.is_showing() and float(spot.get("_age")) > TutorialSpotlight.FADE_SEC):
		_dim_low = minf(_dim_low, float(spot.get("_fade")))


## Wait for a card to have been up long enough to be dismissed, then press. Returns false if
## none came.
func _dismiss_the_card(where: Array) -> bool:
	var spot := _spot()
	var since := Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < 4000 \
			and not (spot.is_showing() and float(spot.get("_age")) > TutorialSpotlight.LOOK_MIN_SEC + 0.05):
		await process_frame
	if not spot.is_showing():
		return false
	# Where the card stands and what is lit, once the hole has closed on its target.
	var target: Rect2 = level.call("_tutorial_target", _shown[-1]["anchor"])
	var hole := spot.hole_rect()
	where.append({"lit": target.has_area() and hole.encloses(target)
		and hole.size.x <= target.size.x + TutorialSpotlight.HOLE_PAD * 2.0 + 2.0,
		"clear": not spot.card_rect().intersects(target)})
	_press(&"ui_accept")
	await process_frame
	return true


func _every_card_plays_at_the_door() -> void:
	_profile().call("set_lessons_owed", [])
	_shown.clear()
	_open_payyo_at_the_keys()
	tutorial.lesson_taught.connect(_on_taught)
	process_frame.connect(_watch_the_run)
	await process_frame
	_check(tutorial.is_teaching_everything() and _spot().is_showing() and paused,
		"Payyo opens on a card, with the world held", "card '%s', paused %s" % [_spot().lesson_id(), paused])
	# Held from here to the last card: she walks the moment she is let go, and not before.
	var start_x := (level.get("player") as Node2D).global_position.x
	tutorial.everything_taught.connect(_note_where_she_stands)
	Input.action_press(&"move_right")
	var where: Array = []
	var guard := 0
	while tutorial.is_teaching_everything() and guard < 60:
		guard += 1
		if not await _dismiss_the_card(where):
			break
	var ids: Array[String] = []
	for card in _shown:
		ids.append(String(card["id"]))
	_check(ids == _cards(), "every card in the ledger plays, in its order",
		", ".join(ids) if ids != _cards() else "%d cards" % ids.size())
	var not_look: Array[String] = []
	var unlit: Array[String] = []
	var moved := false
	var bag_ok := true
	for i in _shown.size():
		var card: Dictionary = _shown[i]
		if String(card["mode"]) != "look":
			not_look.append(card["id"])
		if not (card["target"] as Rect2).has_area() or (i < where.size() and not bool(where[i]["lit"])):
			unlit.append(card["id"])
		moved = moved or (i > 0 and absf(float(card["x"]) - start_x) > 0.5) or not bool(card["paused"])
		bag_ok = bag_ok and bool(card["bag"]) == (String(card["anchor"]) == "inventory_bar")
	_check(not_look.is_empty(), "each is a card she reads, the world stopped under it",
		"do cards: %s" % ", ".join(not_look) if not not_look.is_empty() else "all look")
	_check(unlit.is_empty(), "each lights something real on the screen",
		"unlit: %s" % ", ".join(unlit) if not unlit.is_empty() else "all lit")
	var covered := where.filter(func(w: Dictionary) -> bool: return not bool(w["clear"]))
	_check(where.size() == _shown.size() and covered.is_empty(), "and no card stands over what it lights",
		"%d of %d measured, %d covered" % [where.size(), _shown.size(), covered.size()])
	_check(bag_ok, "the empty bag comes up for the cards about it, and only those",
		"bag shown only under inventory_bar cards" if bag_ok else "BAG SHOWN WRONG")
	_check(_unpaused_in_run == 0, "the world stays still between cards", "%d frames ran" % _unpaused_in_run)
	_check(_dim_low > 0.99, "and the screen stays dim from one card to the next", "lowest %.2f" % _dim_low)
	var player := level.get("player") as Node2D
	_check(not moved and absf(_x_at_the_end - start_x) < 0.5,
		"with walking held the whole time, she has not taken a step", "x %.1f -> %.1f"
			% [start_x, _x_at_the_end])
	await _wait(0.6)
	_check(not paused and player.global_position.x > start_x + 4.0,
		"the last card gone, she walks", "x %.1f -> %.1f, paused %s" % [start_x, player.global_position.x, paused])
	Input.action_release(&"move_right")
	_check(not (level.get("inventory_hud") as Control).is_visible_in_tree(),
		"and the empty bag goes away again", "bag hidden")


## NOTHING IS LEFT. Every moment a lesson used to wait for comes, and no card comes with it.
func _and_then_nothing_is_left() -> void:
	var spot := _spot()
	_cards_after_the_run = 0
	var events := {}
	for id in tutorial.lesson_ids():
		events[String((tutorial.call("_find", id) as Dictionary).get("at", ""))] = true
	for event: String in events:
		tutorial.note(event)
	# And for real: a drawing she becomes, which is the moment four of them waited for.
	var drawing := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	drawing.fill(Color.WHITE)
	level.call("_on_drawing_ready", "frog", "Frog", drawing, {}, [], 0.0)
	var up := false
	var waited := 0.0
	while waited < 3.0:
		up = up or spot.is_busy()
		await _wait(0.1)
		waited += 0.1
	var waiting_cards := tutorial.pending_ids().filter(func(id: String) -> bool:
		return String((tutorial.call("_find", id) as Dictionary).get("mode", "")) != "say")
	_check(_cards_after_the_run == 0 and not up and waiting_cards.is_empty(),
		"after the last card, no card comes, whatever happens",
		"%d shown after, cards waiting %s" % [_cards_after_the_run, str(waiting_cards)])
	_profile().call("set_lessons_owed", [])
	level.call("mark_finished", "level_1")
	_check((_profile().call("lessons_owed") as Array).is_empty(), "and nothing is owed to a later level",
		str(_profile().call("lessons_owed")))


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
	await _dismiss_the_card(where)
	await _dismiss_the_card(where)
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
	_check(not tutorial.is_teaching_everything() and not paused and not spot.is_holding()
		and not bool(level.get("_opening_running")),
		"SKIP at the door ends the run and lets the world go",
		"run on %s, paused %s, opening running %s" % [tutorial.is_teaching_everything(), paused,
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


func _revert() -> void:
	if not (level.get("player") is Wanderer):
		level.call("_revert_to_base_form")
		await _wait(0.2)


func _become(entity_id: String) -> void:
	var drawing := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	drawing.fill(Color.WHITE)
	level.call("_on_drawing_ready", entity_id, entity_id.capitalize(), drawing, {}, [], 0.0)
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
	while tutorial.is_teaching_everything() and Time.get_ticks_msec() - since < 10000:
		await process_frame
	var took := (Time.get_ticks_msec() - since) / 1000.0
	# Past the breath after a card (GAP_AFTER), a lead and a delay: long enough for anything
	# queued to have come back.
	await _wait(6.0)
	var wrong: Array[String] = []
	for id in _cards():
		if int(_counts.get(id, 0)) != 1:
			wrong.append("%s x%d" % [id, int(_counts.get(id, 0))])
	_check(not tutorial.is_teaching_everything() and took < 6.0 and wrong.is_empty(),
		"with nobody at the keys, the run goes by itself, each card once",
		"%.1f s; %s" % [took, ", ".join(wrong) if not wrong.is_empty() else "all once"])


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
