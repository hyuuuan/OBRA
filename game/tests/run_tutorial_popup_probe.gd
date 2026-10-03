extends SceneTree
## The tutorial's one place, without a viewport.
##   godot --headless --path game --script res://tests/run_tutorial_popup_probe.gd
##
## Kent, playing Level 1: "its just knowledge dumping ... why are the instructions popping
## everywhere ... it is better that the screen goes dim and then that part is highlighted".
## What can be held without eyes, this holds; `run_visual_tutorial_popups` is for the look.
##
##   every anchor, context and picture a lesson names is one the game has
##   one card at a time, and a breath after each
##   nothing over anyone talking, and it is not lost for having waited
##   a player who already did it is not told
##   a `do` card ends in the thing it taught: the press goes on and does it
##   a `look` card stops the world, waits, and spends the press that dismisses it
##   a card never stands over what it lights, and stands in one of two places
##   Lolo's line steps back while a card is up, and comes back after
##   a lesson only in its moment
##   with nobody at the keys, nothing waits for a key

var level: Node2D
var tutorial: TutorialDirector
var spot: TutorialSpotlight
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-58s %s" % ["OK  " if ok else "FAIL", what, detail])


## A constant off the level's own script chain, with no compile-time reference to its class.
func _level_constant(name: String, fallback: Variant) -> Variant:
	var script := level.get_script() as Script
	while script != null:
		var constants: Dictionary = script.get_script_constant_map()
		if constants.has(name):
			return constants[name]
		script = script.get_base_script()
	return fallback


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _run() -> void:
	level = (load("res://game_level.tscn") as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	_auto(true)
	await _wait(1.2)
	tutorial = level.get("tutorial") as TutorialDirector
	spot = level.get("tutorial_spotlight") as TutorialSpotlight
	if tutorial == null or spot == null:
		print("OBRA_TUTORIAL_POPUP_FAILED=1  (no tutorial director or spotlight)")
		quit(1)
		return

	_audit_the_ledger_matches_the_level()
	await _audit_one_card_at_a_time()
	await _audit_nothing_over_a_conversation()
	await _audit_a_player_who_already_did_it_is_not_told()
	await _audit_a_do_card_ends_in_what_it_taught()
	await _audit_a_look_card_stops_the_world()
	await _audit_a_card_never_covers_what_it_lights()
	await _audit_the_hint_bar_steps_back()
	await _audit_only_in_its_moment()
	await _audit_the_bar_clears_the_letterbox()
	await _audit_the_first_checkpoint_explains_itself()
	await _audit_nobody_at_the_keys()

	print("OBRA_TUTORIAL_POPUP_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)


func _auto(on: bool) -> void:
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", on)


## A clean slate: no card up, nothing queued, no gap, and the two lessons the level offers on
## its own every frame (walking, jumping) already spent so they do not wander into a check.
func _fresh() -> void:
	if spot.is_busy():
		spot.finish("skipped")
	while spot.is_busy():
		await process_frame
	tutorial.load_for("level_1")
	tutorial.set("_gap", 0.0)
	var seen: Dictionary = tutorial.get("_seen")
	seen["move"] = "shown"
	seen["jump"] = "shown"
	paused = false


func _show(id: String) -> void:
	tutorial.call("_show", tutorial.call("_find", id))


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)


## ⚠ A NAME THE GAME DOES NOT HAVE IS SILENT. An anchor nothing answers resolves empty, which
## reads exactly like a target that is off screen right now -- so a typo in tutorial.json would
## just mean a lesson that waits forever. Same for a context nothing answers.
func _audit_the_ledger_matches_the_level() -> void:
	var anchors: Array = _level_constant("TUTORIAL_ANCHORS", [])
	var contexts: Array = _level_constant("TUTORIAL_CONTEXTS", [])
	for id in tutorial.lesson_ids():
		var lesson: Dictionary = tutorial.call("_find", id)
		var anchor := String(lesson.get("anchor", ""))
		if not anchor.is_empty():
			_check(anchors.has(anchor), "'%s' lights something the level has" % id, anchor)
		var context := String(lesson.get("context", "world"))
		_check(contexts.has(context), "'%s' waits for a moment the level knows" % id, context)


## ONE AT A TIME, THEN A BREATH. Two lessons whose moments land together, neither of which
## waits for anything of its own: the second waits for the first to go, and then for a gap.
##
## ⚠ THE BREATH IS A NUMBER WRITTEN HERE, not GAP_AFTER read back. Compared against the
## constant, a gap set to nothing passed: the check moved with the thing it was checking.
func _audit_one_card_at_a_time() -> void:
	await _fresh()
	(tutorial.get("_seen") as Dictionary)["undo"] = "shown"
	var times := {}
	var on_finished := func(id: String, _how: String) -> void:
		times["gone_" + id] = Time.get_ticks_msec() / 1000.0
	var on_taught := func(id: String) -> void:
		times["shown_" + id] = Time.get_ticks_msec() / 1000.0
	spot.finished.connect(on_finished)
	tutorial.lesson_taught.connect(on_taught)
	tutorial.note("checkpoint")
	tutorial.note("ink_spent")
	_check(spot.lesson_id() == "checkpoint" and tutorial.pending_ids().has("ink"),
		"two moments at once: one card, the other waits",
		"up '%s', waiting %s" % [spot.lesson_id(), tutorial.pending_ids()])
	var waited := 0.0
	while not times.has("shown_ink") and waited < 12.0:
		await _wait(0.1)
		waited += 0.1
	_check(times.has("shown_ink"), "and the one that waited is still shown", "ink")
	var between := float(times.get("shown_ink", 0.0)) - float(times.get("gone_checkpoint", 0.0))
	_check(times.has("gone_checkpoint") and between >= 2.0,
		"two seconds of nothing between two cards", "%.2f s between them" % between)
	spot.finished.disconnect(on_finished)
	tutorial.lesson_taught.disconnect(on_taught)


## NOTHING OVER ANYONE TALKING -- and a one-off moment that lands under a menu is not lost.
func _audit_nothing_over_a_conversation() -> void:
	await _fresh()
	var menu := level.get_node_or_null(^"PauseMenu") as ModalOverlay
	if menu == null:
		_check(false, "the level has a pause menu to stand in for a conversation", "-")
		return
	menu.open()
	tutorial.note("checkpoint")
	await _wait(0.6)
	_check(not spot.is_open() and tutorial.pending_ids().has("checkpoint"),
		"no card over an open menu", "up '%s'" % spot.lesson_id())
	menu.close()
	await _wait(0.3)
	_check(spot.lesson_id() == "checkpoint", "and it is shown once the menu closes",
		"up '%s'" % spot.lesson_id())


## NOT WHAT THEY ALREADY DID. Walking waits two seconds; a player who walks in that time is
## never shown how.
func _audit_a_player_who_already_did_it_is_not_told() -> void:
	await _fresh()
	(tutorial.get("_seen") as Dictionary).erase("move")
	tutorial.note("level_start")
	await _wait(0.3)
	_check(tutorial.pending_ids().has("move") and not spot.is_open(),
		"walking waits a moment before it is taught", "pending")
	_press(&"move_right")
	await _wait(0.2)
	_check(tutorial.has_taught("move") and not tutorial.was_shown("move"),
		"a player who walks first is never shown how",
		"skipped" if tutorial.has_taught("move") and not tutorial.was_shown("move")
			else "shown %s, spent %s" % [tutorial.was_shown("move"), tutorial.has_taught("move")])
	await _wait(2.3)
	_check(spot.lesson_id() != "move", "and no walking card comes later", "up '%s'" % spot.lesson_id())


## A `do` CARD ENDS IN THE THING IT TAUGHT. The draw key closes the card -- and still opens
## the canvas, because the press is not spent on the card.
func _audit_a_do_card_ends_in_what_it_taught() -> void:
	await _fresh()
	var panel := level.get("draw_panel") as DrawPanel
	var result := {"how": ""}
	var on_finished := func(_id: String, why: String) -> void:
		result["how"] = why
	spot.finished.connect(on_finished)
	_show("draw")
	await _wait(0.4)
	_check(spot.lesson_id() == "draw" and spot.lesson_mode() == "do" and not paused,
		"the draw card is up, and the world is not stopped", "paused %s" % paused)
	_press(&"redraw")
	await _wait(0.2)
	_check(result["how"] == "done", "pressing the key it shows ends it", String(result["how"]))
	_check(panel.is_open(), "and the same press opens the canvas", "open %s" % panel.is_open())
	spot.finished.disconnect(on_finished)
	panel.close_panel()
	await _wait(0.2)


## A `look` CARD STOPS THE WORLD AND WAITS FOR YOU -- and the press that dismisses it does
## nothing else. Asked with somebody at the keys, which is the only time it may stop anything.
func _audit_a_look_card_stops_the_world() -> void:
	await _fresh()
	_auto(false)
	var panel := level.get("draw_panel") as DrawPanel
	_show("ink")
	await _wait(0.3)
	_check(spot.lesson_mode() == "look" and paused, "a look card stops the world",
		"paused %s" % paused)
	await _wait(TutorialSpotlight.AUTO_SEC + 0.5)
	_check(spot.lesson_id() == "ink", "and waits for the player, not for a clock", "still up")
	_press(&"redraw")
	await _wait(0.2)
	_check(not spot.is_open() and not paused, "a key lets it go, and the world back",
		"up %s, paused %s" % [spot.is_open(), paused])
	_check(not panel.is_open(), "and that key is spent on the card", "canvas open %s" % panel.is_open())
	if panel.is_open():
		panel.close_panel()
	_auto(true)


## THE CARD NEVER STANDS OVER WHAT IT LIGHTS, and it stands top-centre or bottom-centre --
## beside, only for a box too tall for either (the drawing page).
func _audit_a_card_never_covers_what_it_lights() -> void:
	var bagged := DrawnItemData.new()
	bagged.entity_id = "square"
	bagged.display_name = "Square"
	(level.get("inventory_manager") as Node).call("add_item", bagged)
	for id in ["move", "draw", "ink", "checkpoint", "bag"]:
		await _fresh()
		_show(id)
		await _wait(TutorialSpotlight.IRIS_SEC + 0.15)
		var card := spot.card_rect()
		var hole := spot.hole_rect()
		_check(hole.has_area() and not card.intersects(hole),
			"'%s': the card stands clear of what it lights" % id, "card %s, lit %s" % [card, hole])
		_check(spot.card_place() in ["top", "bottom"], "'%s': in one of the two places" % id,
			spot.card_place())
	var panel := level.get("draw_panel") as DrawPanel
	await _fresh()
	panel.open_panel()
	await _wait(0.6)
	_show("canvas")
	await _wait(TutorialSpotlight.IRIS_SEC + 0.15)
	var card := spot.card_rect()
	var hole := spot.hole_rect()
	_check(hole.has_area() and not card.intersects(hole),
		"the canvas card stands clear of the page", "card %s, page %s" % [card, hole])
	panel.close_panel()
	await _fresh()


## LOLO STEPS BACK FOR A CARD, AND COMES BACK. Two things to read at once is the overwhelm
## this answers; losing his line to it would be a new fault.
func _audit_the_hint_bar_steps_back() -> void:
	await _fresh()
	var bar := level.get("hint_bar") as HintBar
	var bar_panel := bar.get_node("Panel") as Control
	bar.show_hint("Draw something that can climb, apo.", Lolo.SPEAKER, 0.0)
	await _wait(0.3)
	# A `do` card, which stops nothing: the pause state cannot be what sends Lolo back.
	_show("draw")
	await _wait(0.2)
	_check(bar_panel.modulate.a < 0.01, "Lolo's line steps back while a card is up",
		"alpha %.2f" % bar_panel.modulate.a)
	spot.finish("seen")
	await _wait(TutorialSpotlight.CLOSE_SEC + 0.2)
	_check(bar_panel.modulate.a > 0.99 and bar.current_text().contains("climb"),
		"and comes back, still saying it", "'%s'" % bar.current_text())
	bar.clear()


## ONLY IN ITS MOMENT. The placement's lesson waits for a placement; offered without one, it
## does not show at all.
func _audit_only_in_its_moment() -> void:
	await _fresh()
	tutorial.note("placement_started")
	await _wait(1.5)
	_check(not spot.is_open() and tutorial.pending_ids().has("place"),
		"a placement lesson does not show with nothing being placed",
		"up '%s'" % spot.lesson_id())
	await _fresh()


## ⚠ THE CHECKPOINT LINE WAS PRINTED UNDER THE LETTERBOX. The bars come in over the top
## thirteenth of the screen at every checkpoint, and the hint that goes with one sat inside
## that band with its lower half showing. With the curtain in, the bar has to rest below it.
func _audit_the_bar_clears_the_letterbox() -> void:
	var bar := level.get("hint_bar") as HintBar
	var bars := level.get("cinematic") as CinematicBars
	if bar == null or bars == null:
		_check(false, "the level has a hint bar and a letterbox", "-")
		return
	bars.close("")
	await _wait(0.6)
	bar.show_hint("The level will remember you from here.", "", 4.0)
	await _wait(0.5)
	var panel := bar.get_node("Panel") as Control
	var depth := level.get_viewport().get_visible_rect().size.y * CinematicBars.BAR_FRACTION
	_check(panel.global_position.y >= depth,
		"a hint during the letterbox sits below the top bar",
		"panel top %d, bar bottom %d" % [int(panel.global_position.y), int(depth)])
	bars.open()
	await _wait(1.2)
	# OVER THE APO, NOT UNDER THE BADGE. Kent: the top "cant be seen knowing that the player is
	# focused at the center". With the bars gone it stands where she is: centred on her, its
	# lower edge over her head -- or under her feet where her head is too near the top.
	var feet := level.get_viewport().get_canvas_transform() * (level.get("player") as Node2D).global_position
	var bottom := panel.global_position.y + panel.size.y
	var over := absf(bottom - (feet.y - HintBar.OVER_THE_HEAD)) <= 3.0
	var under := absf(panel.global_position.y - (feet.y + HintBar.UNDER_THE_FEET)) <= 3.0
	var beside := absf(panel.global_position.x + panel.size.x * 0.5 - feet.x) <= 3.0 \
		or panel.global_position.x <= HintBar.EDGE + 1.0
	_check((over or under) and beside and panel.global_position.y > HintBar.TOP + 1.0,
		"and stands over the apo when the bars leave, not at the top",
		"panel at %s, the apo's feet at %s" % [panel.global_position.round(), feet.round()])
	bar.clear()


## ⚠ THE FIRST CHECKPOINT SAYS WHAT A CHECKPOINT IS. Kent: "when I do checkpoint, as a first
## time player, i dont know what it does". The first one is a card; the ones after are a line.
func _audit_the_first_checkpoint_explains_itself() -> void:
	await _fresh()
	var bar := level.get("hint_bar") as HintBar
	bar.show_hint("Walk with me, apo.", Lolo.SPEAKER, 0.0)
	await _wait(0.2)
	level.call("_say_checkpoint")
	await _wait(0.4)
	_check(spot.lesson_id() == "checkpoint" and spot.caption_text().contains("start again"),
		"the first checkpoint explains itself on a card", "'%s'" % spot.caption_text())
	_check(not bar.current_text().begins_with("Checkpoint."),
		"and is not said twice on the bar underneath", "'%s'" % bar.current_text())
	spot.finish("seen")
	await _wait(TutorialSpotlight.CLOSE_SEC + 0.2)
	level.call("_say_checkpoint")
	await _wait(0.4)
	var said := bar.current_text()
	_check(not spot.is_open() and said.begins_with("Checkpoint.") and said.contains("start again from here"),
		"and the ones after it say so in a line", said)
	bar.clear()


## ⚠ NOBODY AT THE KEYS. A run nobody is playing -- every headless suite -- must never be held
## by a card waiting for a key: it stops nothing and goes by itself.
func _audit_nobody_at_the_keys() -> void:
	await _fresh()
	_auto(true)
	_show("ink")
	await _wait(0.2)
	_check(spot.is_auto() and not paused, "with nobody at the keys a look card stops nothing",
		"paused %s" % paused)
	await _wait(TutorialSpotlight.AUTO_SEC + TutorialSpotlight.CLOSE_SEC + 0.3)
	_check(not spot.is_busy(), "and goes by itself", "up '%s'" % spot.lesson_id())
