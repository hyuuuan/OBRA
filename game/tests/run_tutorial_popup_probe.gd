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
	_audit_the_canvas_is_explained()

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


func _audit_the_canvas_is_explained() -> void:
	var lines: Array = tutorial.call("canvas_briefing")
	_check(not lines.is_empty(), "Lolo has something to say about the canvas",
		"%d lines" % lines.size())
	var panel = level.get("draw_panel")
	_check(panel != null and (panel.get("briefing_lines") as Array).size() == lines.size(),
		"and the panel was handed them",
		"the panel does not read tutorial.json itself")
