extends SceneTree
## THE HINTS: where they appear, when they stop, and what the third one is allowed to say.
##   godot --headless --path game --script res://tests/run_hint_probe.gd
##
## Three complaints, one file, because they are all the same organ.
##
## 1. A SOLVED BEAT KEPT TALKING. `LevelDirector.enter_obstacle` re-emits `obstacle_entered`
##    every time the player crosses back into a trigger, and the level answered it by
##    speaking the beat's current stage line -- with no check that the beat was over. Level
##    1's triggers are wide on purpose (the straw heap sits inside L1_N2's), so walking on
##    after solving Beat 0 re-fired its tutorial line at somebody who had just finished it.
##
## 2. THE STRIP WAS THE SIZE OF A DIALOGUE BOX. It is a persistent panel, not a beat, and it
##    sat in the middle-left of the play area at body size over the thing the player was
##    trying to look at.
##
## 3. THE THIRD CLUE HAS TO NAME A CLASS. Thesis 4.5.4: the clue system "escalates in three
##    stages: the first restates the affordance in plainer language, the second names the
##    category of thing that would satisfy it, and the third NAMES ONE CLASS THAT DOES."
##    The build widened what it ACCEPTED instead and never named anything, which is a
##    defensible design and is not the one the manuscript describes.

var level: Node2D
var director
var strip
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-46s %s" % ["OK  " if ok else "FAIL", what, detail])


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _run() -> void:
	var scene := load("res://game_level.tscn") as PackedScene
	level = scene.instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.2)

	director = level.get("director")
	strip = level.get("requirement_strip")
	if director == null or strip == null:
		print("OBRA_HINT_PROBE_FAILED=1  (no obstacle layer)")
		quit(1)
		return

	await _audit_a_solved_beat_stops_talking()
	_audit_the_strip_is_not_a_dialogue_box()
	_audit_the_third_clue_names_a_class()

	print("OBRA_HINT_PROBE_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)


## ⚠ RE-ENTERING A SOLVED BEAT MUST SAY NOTHING. Counted through the script's own record of
## what it has fired, because that is what actually reaches the player -- asserting on the
## director alone would pass while the level spoke anyway.
func _audit_a_solved_beat_stops_talking() -> void:
	var lines = level.get("script_lines")
	if lines == null or not lines.has_method("lines_spoken"):
		_check(false, "the script can count what it has said",
			"DialogueScript.lines_spoken is missing -- this audit cannot run")
		return
	var first := "B0_HAGDAN"
	director.enter_obstacle(first)
	# Solved the way the level solves it, through the director's own door. `solve_with_item`
	# is what a non-drawing solve uses and it takes the obstacle by name, which is what this
	# needs -- `note_submission` reads the CURRENT obstacle and would drift with the harness.
	while not bool(director.is_solved(first)):
		var before_stage := String(director.stage_id(first))
		director.solve_with_item(first, "circle")
		if String(director.stage_id(first)) == before_stage and not bool(director.is_solved(first)):
			break
	_check(bool(director.is_solved(first)), "beat 0 can be solved in the harness",
		"solved" if director.is_solved(first) else "%s would not solve" % first)
	if not bool(director.is_solved(first)):
		return

	var before := int(lines.call("lines_spoken"))
	director.exit_obstacle(first)
	director.enter_obstacle(first)
	await process_frame
	var after := int(lines.call("lines_spoken"))
	_check(after == before, "re-entering a solved beat says nothing",
		"%d lines spoken before, %d after" % [before, after])


func _spoken_count(lines) -> int:
	if lines == null or not lines.has_method("lines_spoken"):
		return 0
	return int(lines.call("lines_spoken"))


## The strip is a persistent panel the player reads at a glance while playing, not a beat
## that stops the world. It has to be small, and it has to be out of the way.
func _audit_the_strip_is_not_a_dialogue_box() -> void:
	var tag_size := int(strip.call("tag_font_size"))
	var body_size := int(strip.call("gloss_font_size"))
	_check(tag_size <= UISkin.FONT_CAPTION, "the strip's tag line is caption-sized or smaller",
		"%dpx against the %dpx body the dialogue box uses" % [tag_size, UISkin.FONT_BODY])
	_check(body_size < tag_size or body_size <= UISkin.FONT_CAPTION,
		"and its gloss is no louder than its tag", "%dpx" % body_size)
	var width := float(strip.call("wrap_width"))
	_check(width <= 340.0, "it wraps well inside the left third of the frame",
		"%.0fpx of a 1600px frame" % width)


## ⚠ THE MANUSCRIPT SAYS THE THIRD STAGE NAMES A CLASS. Thesis 4.5.4, and it is not a
## throwaway: the stage reached is recorded in telemetry precisely so a completion after a
## third-stage clue can be told apart from an unaided one. A T3 that names nothing makes
## that distinction meaningless, because the assistance it is supposed to mark never
## happened.
func _audit_the_third_clue_names_a_class() -> void:
	# ⚠ AN UNSOLVED ONE. The audit above finishes Beat 0, and `clue_class` returns nothing
	# for a beat that is over -- correctly. Asking it about B0 here measured the test order.
	var id := "L1_N1"
	var suggestion := String(director.call("clue_class", id))
	_check(not suggestion.is_empty(), "the director can name a class that would work",
		suggestion if not suggestion.is_empty() else "clue_class returned nothing")
	var accepted: PackedStringArray = director.accept_set(id)
	_check(suggestion.is_empty() or accepted.has(suggestion),
		"and it is one the obstacle would actually take",
		"%s in %d accepted" % [suggestion, accepted.size()])
