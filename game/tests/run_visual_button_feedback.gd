extends SceneTree
## Eyes on the press animation. Needs a real viewport:
##   godot --path game --script res://tests/run_visual_button_feedback.gd
## Frames land in /tmp/obra_btn_*.png
##
## ⚠ THIS IS THE ONLY THING THAT CAN SEE IT. A press animation is four frames long and
## leaves nothing behind; a headless assertion can prove a tween was created and cannot
## prove it looks like a button answering. Four defects in this project passed green suites
## and were caught only by screenshotting, and motion is the easiest of all of them to get
## subtly wrong -- a scale about the wrong pivot slides the button sideways and still
## reports a running tween.

const OUTPUT_DIR := "/tmp"

var level: Node2D
var overlay: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://game_level.tscn") as PackedScene
	level = scene.instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	# ⚠ AUTOLOADS DO NOT EXIST IN A `--script` RUN. `/root/UIFeedback` is null here, so
	# without this the test photographs buttons with no feedback attached and reports the
	# animation as missing -- or worse, as present, if you only look at the still frames.
	var feedback: Node = (load("res://scripts/ui_feedback.gd") as Script).new()
	feedback.name = "UIFeedback"
	root.add_child(feedback)
	await _wait(1.2)

	# The three answers to Lolo's question: the biggest buttons in the game and the ones a
	# player presses at every node, so the animation is judged where it actually runs.
	level.call("_on_dialogue_node_approached")
	await _wait(0.9)
	overlay = level.get_node_or_null("DialogueChoiceOverlay")
	var button := _first_button(overlay)
	if button == null:
		print("no choice button to press")
		quit(1)
		return

	# ⚠ RELEASE FOCUS FIRST. The overlay grabs the first button on open, so "at rest" was
	# photographed already lifted and the focus frame was identical to it -- zero pixels of
	# difference between two states the test claimed to be comparing.
	button.call("release_focus")
	await _wait(0.20)
	await _capture("00_at_rest")

	# HOVER, which has to be visibly smaller than the press or the two read as one state.
	button.call("grab_focus")
	await _wait(0.20)
	await _capture("01_focused")

	# HELD. Captured while the button is down, not after -- the dip is the half of the
	# animation a screenshot taken on `pressed` would miss entirely.
	button.emit_signal("button_down")
	await _wait(PRESS_SETTLE)
	await _capture("02_held")

	# THE WAVE, one frame in. The ring leaves the click point and outruns its own fade, so
	# an early frame shows a small bright ring and a later one a wide faint ring -- two
	# captures, because a single one cannot show that it is travelling.
	# ⚠ NOT `pressed`. Emitting it on a real choice button commits the route and tears the
	# overlay down, so the wave frames photographed the level after the answer rather than
	# the button giving it. `button_up` runs the pop without answering anything, and the
	# ripple is asked for directly -- it is the thing under test, not the route.
	button.set_meta(&"ui_feedback_point", Vector2(90.0, 30.0))
	button.emit_signal("button_up")
	feedback.call("_ripple", button)
	# Three points along it. One capture cannot show that a ring is travelling, and the
	# first version's two were both taken after it had already crossed the button.
	await _wait(0.06)
	await _capture("03_wave_near")
	await _wait(0.10)
	await _capture("04_wave_mid")
	await _wait(0.12)
	await _capture("05_wave_wide")
	await _wait(0.6)
	await _capture("06_settled")

	print("OBRA_VISUAL_BUTTON_DONE")
	quit(0)


const PRESS_SETTLE := 0.10


func _first_button(node: Node) -> BaseButton:
	if node == null:
		return null
	for child in node.get_children():
		var button := child as BaseButton
		if button != null:
			return button
		var deeper := _first_button(child)
		if deeper != null:
			return deeper
	return null


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/obra_btn_%s.png" % [OUTPUT_DIR, label])


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout
