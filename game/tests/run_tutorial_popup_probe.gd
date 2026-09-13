extends SceneTree
## The pointing tutorial, without a viewport.
##   godot --headless --path game --script res://tests/run_tutorial_popup_probe.gd
##
## It cannot judge where a bubble looks like it is pointing -- `run_visual_tutorial_popups`
## is for that -- but it can hold the contract that makes the visual right:
##
##   anchored lessons are anchored to something this level actually has
##   a callout does NOT wait for the hint bar, because it does not use the hint bar
##   an anchor that cannot be resolved falls back to the bar instead of vanishing
##   the canvas briefing is authored, and is said once
##   the morph card's two readings are taught, pointed at the card that shows them

var level: Node2D
var tutorial
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-46s %s" % ["OK  " if ok else "FAIL", what, detail])


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
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.2)
	tutorial = level.get("tutorial")
	if tutorial == null:
		print("OBRA_TUTORIAL_POPUP_FAILED=1  (no tutorial director)")
		quit(1)
		return

	_audit_every_anchor_resolves()
	# ⚠ THE FALLBACK IS CHECKED FIRST, while the bar has never been written to. The busy-bar
	# audit below deliberately occupies it, and the bar does not let go on demand -- `clear()`
	# fades over 0.14s and re-asserts `visible` while it does. Ordering is cheaper and more
	# honest than fighting a widget's own animation to prove something unrelated to it.
	_audit_an_unknown_anchor_falls_back()
	await _audit_a_callout_does_not_wait_for_the_bar()
	await _audit_a_callout_goes_away()
	await _audit_a_callout_leaves_with_its_target()
	_audit_the_canvas_is_explained()
	await _audit_the_two_readings_are_explained()

	print("OBRA_TUTORIAL_POPUP_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)


## ⚠ AN ANCHOR NAMING SOMETHING THIS LEVEL DOES NOT HAVE IS SILENT. The lesson still gets
## taught -- it falls back to the hint bar -- so a typo in `tutorial.json`, or a HUD node
## renamed under it, costs the pointing and says nothing. Two of the first three anchors
## written were wrong this way: `ink_gauge` named the authored ProgressBar the visible gauge
## replaced, which is in the scene and invisible, so it resolved to an empty rect forever.
func _audit_every_anchor_resolves() -> void:
	# ⚠ READ OFF THE RUNNING LEVEL, NOT AS `LevelBase.TUTORIAL_ANCHORS`. Naming the class
	# makes this file depend on it at COMPILE time, and a `--script` run has no autoloads --
	# the whole suite failed to load on `LevelManager` and reported "no tutorial director".
	# The same lesson `run_level2_scene_probe` already carries for `GOAL_RADIUS`.
	var known: Array = _level_constant("TUTORIAL_ANCHORS", [])
	_check(not known.is_empty(), "the level declares its anchor vocabulary",
		"%d names" % known.size())
	var unresolved: Array[String] = []
	var anchored := 0
	for id in tutorial.call("lesson_ids"):
		var lesson: Dictionary = tutorial.call("_find", String(id))
		var anchor := String(lesson.get("anchor", ""))
		if anchor.is_empty():
			continue
		anchored += 1
		# ⚠ CHECKED AGAINST THE VOCABULARY, NOT AGAINST THE RECT. An unknown name resolves to
		# an empty Rect2 -- exactly like a known one whose target is hidden, which the bag is
		# whenever it is empty -- so a check on the rect passes for a typo and is vacuous.
		# Mutation-tested: renaming `ink_gauge` in the resolver now fails this.
		if not known.has(anchor):
			unresolved.append(anchor)
	_check(anchored > 0, "some lessons point at a control", "%d anchored" % anchored)
	_check(unresolved.is_empty(), "and every anchor is a name the level knows",
		"%d anchors" % anchored if unresolved.is_empty()
		else "unknown: %s" % ", ".join(unresolved))


## The callout does not touch the HintBar, so the bar being busy must not defer it. This was
## wrong first: every lesson about a button waited for Lolo to stop talking, and at the start
## of Level 1 he is talking for most of the time the player is first looking at the HUD.
func _audit_a_callout_does_not_wait_for_the_bar() -> void:
	var bar = level.get("hint_bar")
	if bar == null:
		_check(false, "the level has a hint bar", "-")
		return
	bar.call("show_hint", "Lolo is in the middle of something.", "Lolo")
	await _wait(0.2)
	_check(bool(bar.call("is_showing")), "the bar is busy for this check", "occupied")
	var lesson: Dictionary = tutorial.call("_find", "draw")
	tutorial.call("_teach", lesson)
	await process_frame
	_check(tutorial.call("callout") != null,
		"a pointed lesson is taught over a busy bar",
		"it stands beside its button and never touches the bar")
	_check(bool(tutorial.call("has_taught", "draw")), "and is spent", "not re-offered")
	tutorial.call("dismiss_callout")


func _audit_an_unknown_anchor_falls_back() -> void:
	tutorial.call("dismiss_callout")
	# A lesson whose anchor names nothing: it must still be TAUGHT.
	var lesson := {"id": "_probe_unknown", "at": "never", "anchor": "no_such_control",
		"text": "This still has to reach the player."}
	tutorial.call("_teach", lesson)
	_check(tutorial.call("callout") == null, "an unknown anchor points at nothing",
		"no callout, as expected")
	# ⚠ NOT SPENT, WHICH IS THE GUARANTEE THAT MATTERS. The first version asserted the
	# lesson had been TAUGHT -- and Lolo is mid-sentence on the hint bar for the first
	# several seconds of Level 1, so the bar path correctly deferred it and the check read
	# as "the lesson was lost". Deferral is the design: an unspent lesson arrives the next
	# time its event comes round. What must never happen is a lesson marked taught by a
	# callout that could not be built, which is silent loss.
	_check(not bool(tutorial.call("has_taught", "_probe_unknown")),
		"and an unbuildable callout does not spend it",
		"still unspent, so its event brings it back")


## ⚠ A CALLOUT THAT NEVER LEAVES IS WORSE THAN NO CALLOUT. It stands over the HUD it points
## at, so one that outstays its dwell covers the bag it is explaining -- reported as "the
## inventory popup never stops". Two things have to hold: it takes itself down on its own,
## and the same lesson never comes back.
func _audit_a_callout_goes_away() -> void:
	tutorial.call("dismiss_callout")
	var lesson: Dictionary = tutorial.call("_find", "bag")
	if lesson.is_empty():
		_check(false, "there is a bag lesson to teach", "-")
		return
	# The bag is hidden while empty, so give it something -- the anchor resolves to an empty
	# rect otherwise and this measures the wrong thing.
	var bagged := DrawnItemData.new()
	bagged.entity_id = "square"
	bagged.display_name = "Square"
	(level.get("inventory_manager") as Node).call("add_item", bagged)
	await _wait(0.4)
	tutorial.call("_teach", lesson)
	await process_frame
	_check(tutorial.call("callout") != null, "the bag lesson points at the bag",
		"a callout is up")
	await _wait(TutorialCallout.DWELL + 1.2)
	_check(tutorial.call("callout") == null, "and it takes itself down",
		"gone after its dwell" if tutorial.call("callout") == null
		else "STILL UP -- it covers the bag it is pointing at")

	# AND IT DOES NOT COME BACK. `note` is called on every store, and a lesson that is not
	# spent is re-offered every single time.
	for again in range(4):
		tutorial.call("note", "item_stored")
		await process_frame
	var repeated := tutorial.call("callout") != null \
		and String(tutorial.call("callout").name) != ""
	_check(not repeated or bool(tutorial.call("has_taught", "bag_open")),
		"and storing again does not re-teach the same lesson",
		"only an unspent lesson may appear")


## ⚠ AND IT GOES WHEN THE THING IT POINTS AT GOES. The requirement lesson is aimed at the
## strip, the strip clears the moment its beat is answered, and the bubble used to stand on
## for the rest of its dwell with its beak aimed at nothing -- then ride along into the next
## beat and sit half under the route choice. Hiding the target has to take it down at once.
func _audit_a_callout_leaves_with_its_target() -> void:
	tutorial.call("dismiss_callout")
	await _wait(0.4)
	var bag := level.get("inventory_hud") as Control
	if bag == null or not bag.is_visible_in_tree():
		_check(false, "the bag is up to point at", "-")
		return
	tutorial.call("_teach", {"id": "_probe_target_goes", "at": "never",
		"anchor": "inventory_bar", "text": "Pointing at the bag."})
	await process_frame
	await process_frame
	_check(tutorial.call("callout") != null, "a callout points at the bag", "up")
	bag.visible = false
	await _wait(0.5)
	_check(tutorial.call("callout") == null, "and hiding the bag takes it down",
		"gone" if tutorial.call("callout") == null
		else "STILL UP -- pointing at a control that is not on screen")
	bag.visible = true


func _audit_the_canvas_is_explained() -> void:
	var lines: Array = tutorial.call("canvas_briefing")
	_check(not lines.is_empty(), "Lolo has something to say about the canvas",
		"%d lines" % lines.size())
	var panel = level.get("draw_panel")
	_check(panel != null and (panel.get("briefing_lines") as Array).size() == lines.size(),
		"and the panel was handed them",
		"the panel does not read tutorial.json itself")


## THE TWO NUMBERS ON THE MORPH CARD, which the game showed from the day the card existed
## and never once explained: the bar is how long this drawing has left, and the percentage
## beside the name is how sure the recogniser was of it.
##
## ⚠ THEY MUST NOT ARRIVE TOGETHER. One callout is up at a time -- a second in the same
## frame dismisses the first before it has been read -- so `clock` waits for `morph_running`
## (two seconds into a ten-second life, by which point the bar it points at has visibly
## moved) and `sure` waits for the morph after that. Asserting only that both are eventually
## taught would pass with both firing on one frame, so the ORDER is what is checked.
func _audit_the_two_readings_are_explained() -> void:
	var life: Node = level.get("morph_life")
	var card: Control = level.get("morph_card")
	if life == null or card == null:
		_check(false, "the level has a morph card and a clock", "-")
		return
	var order: Array[String] = []
	tutorial.lesson_taught.connect(func(id: String) -> void:
		if id == "clock" or id == "sure":
			order.append(id))

	# ⚠ THE CARD IS SHOWN AT THE MORPH SITE, NOT BY THE CLOCK. `begin` starts the life and
	# emits, and that is all it does -- the plate is filled in where the submitted drawing is
	# in hand, because MorphLife only knows names. A probe that starts the clock and expects
	# a visible card is anchoring a lesson to a control nobody made visible, which resolves
	# empty and quietly falls back to the hint bar.
	var sketch := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	sketch.fill(Color.WHITE)

	# First drawing: `revert` takes the frame it starts on, and `clock` arrives once the
	# life has visibly gone down.
	card.call("show_form", "Spider", sketch, 0.87)
	life.call("begin", "Spider", "spider")
	await _wait(0.2)
	_check(card.visible, "the card is up while she is a drawing",
		"visible" if card.visible else "the plate is hidden, so the lesson has nothing to point at")
	_check(not tutorial.has_taught("clock"), "the clock is not explained on the first frame",
		"revert has that frame")
	await _wait(3.0)
	_check(tutorial.has_taught("clock"), "the clock is explained once the bar has moved",
		"taught" if tutorial.has_taught("clock") else "morph_running never reached a lesson")
	_check(not tutorial.has_taught("sure"),
		"and the second reading does not land on top of it", "still waiting for a morph")

	# Back to the apo, then a second drawing: now `sure` has its own frame.
	life.call("clear")
	card.call("hide_form")
	await _wait(0.4)
	card.call("show_form", "Frog", sketch, 0.62)
	life.call("begin", "Frog", "frog")
	await _wait(0.5)
	_check(tutorial.has_taught("sure"), "the confidence reading is explained on the next one",
		"taught" if tutorial.has_taught("sure") else "sure never fired")
	_check(order == ["clock", "sure"], "and they arrive in that order",
		", ".join(order) if not order.is_empty() else "neither fired")
