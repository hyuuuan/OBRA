extends SceneTree
## The tutorial and the companion, photographed. Needs a real viewport:
##   godot --path game --script res://tests/run_visual_tutorial.gd
## Frames land in /tmp/obra_tut_*.png
##
## NONE OF THIS IS CHECKABLE HEADLESS. A key cap sitting under a word, a lesson wider than
## the bar, a turnaround playing backwards or holding on the wrong cell -- every one of them
## loads clean, passes every assertion in the suite, and is obvious in a picture. This
## project has now been caught that way more times than any other.

var level: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://game_level.tscn") as PackedScene
	level = scene.instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	await _wait(1.6)
	level.get("dialogue_box").call("hide_line")
	await _wait(0.3)

	var bar = level.get("hint_bar")
	var tutorial = level.get("tutorial")

	# EVERY LESSON, one frame each. The cap is built per lesson and the sentence wraps
	# around it, so the failure mode is per lesson rather than global.
	var ledger: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://config/tutorial.json"))
	var lessons: Array = ledger["levels"]["level_1"]["lessons"]
	for value: Variant in lessons:
		var lesson: Dictionary = value
		var caps: String = tutorial.call("caps_for", lesson)
		bar.call("show_lesson", String(lesson["text"]), "Lolo", 0.0, caps)
		await _wait(0.45)
		await _capture("lesson_%s" % String(lesson["id"]))

	# An ordinary hint, for comparison: the two share a bar and must not look identical.
	bar.call("show_hint", "There is a way in under the straw.", "Lolo", 0.0)
	await _wait(0.4)
	await _capture("00_plain_hint")

	# THE ACQUISITION CARD, ACROSS ITS RISE. It is driven by one property (see
	# AcquiredOverlay._reveal), so the whole animation can be stepped by writing that -- the
	# overshoot past 1.0 and the gold settling to white are the two things to look at, and
	# both are invisible in any headless run.
	var acquired = level.get("acquired_overlay")
	acquired.call("present", "Lola's canvas", "The second painting. Pista is open.")
	await _wait(0.05)
	# KILL ITS OWN TWEEN FIRST. present() starts the rise immediately, and a probe that
	# writes _reveal while that is running is photographing the tween rather than the curve:
	# the first cut of this produced five identical frames of a fully-arrived card.
	var run = acquired.get("_run")
	if run != null and run.is_valid():
		run.kill()
	for step in [0.0, 0.25, 0.5, 0.75, 1.0]:
		acquired.set("_reveal", step)
		await _wait(0.1)
		await _capture("acquire_%02d" % int(step * 100.0))
	await _wait(0.2)

	# THE TURNAROUND, CELL BY CELL. Five frames that had never been drawn on screen. Driven
	# by hand rather than by waiting on him to speak, so each cell can actually be seen.
	var lolo := level.get("lolo") as Node2D
	var figure := lolo.get_node("Figure")
	level.set_physics_process(false)
	lolo.set_process(false)
	for step in range(5):
		figure.set("pose", &"face")
		figure.set("pose_time", float(step) / 14.0 + 0.001)
		figure.call("refresh")
		await _wait(0.12)
		await _capture("turn_%d" % step)
	for step in range(5):
		figure.set("pose", &"turn_back")
		figure.set("pose_time", float(step) / 16.0 + 0.001)
		figure.call("refresh")
		await _wait(0.12)
		await _capture("back_%d" % step)
	for named in ["still", "wave", "cheer", "float"]:
		figure.set("pose", StringName(named))
		figure.set("pose_time", 0.0)
		figure.call("refresh")
		await _wait(0.12)
		await _capture("pose_%s" % named)

	print("OBRA_VISUAL_TUTORIAL_DONE")
	quit()


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/obra_tut_%s.png" % label)


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout
