extends SceneTree
## Eyes on Level 1. Needs a REAL viewport, so no --headless:
##   godot --path game --script res://tests/run_visual_level1.gd
## Frames land in /tmp/obra_l1_*.png
##
## The headless suite proves the requirement strip says the right words. It cannot see
## whether those words are on top of the ink bar, clipped by their own box, or sitting
## in the middle of the drawing panel. Four defects in this project passed green suites
## and were caught only by screenshotting; a strip positioned by numbers picked without
## looking is exactly that risk.
##
## It also walks the tutorial in order -- approach, ask, be told, solve, be told again --
## because Level 1 is the level that teaches the game, and a tutorial that is correct but
## unreadable has still failed.

const OUTPUT_DIR := "/tmp"

var level: Node2D
var director
var strip
var player: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://game_level.tscn") as PackedScene
	level = scene.instantiate() as Node2D
	# No backend: the strip is driven from the director, and starting a Python process
	# to look at a HUD would make this test flaky for no gain.
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	await _wait(1.2)

	director = level.get("director")
	strip = level.get("requirement_strip")
	player = level.get("player") as Node2D
	if director == null or strip == null or player == null:
		push_error("level did not build its obstacle layer")
		quit(1)
		return

	# Give the player a drawing history, so T2 has something of their own to show. These
	# are classes a real player would have by Beat 0's end.
	var profile := root.get_node_or_null("PlayerProfile")
	for class_id in ["square", "circle", "triangle"]:
		profile.call("record_class_drawn", class_id)

	await _capture("00_spawn")

	# --- Beat 0, tier by tier ------------------------------------------------
	player.global_position = Vector2(700.0, 440.0)
	await _wait(0.8)
	print("at obstacle: '%s'" % director.current_obstacle())
	await _capture("01_t0_approach")

	director.note_canvas_opened()          # T1
	await _wait(0.5)
	print("T1 strip visible=%s text=%s" % [strip.visible, _strip_text()])
	await _capture("02_t1_names_the_tag")

	director.note_submission("frog")       # two misses -> T2
	director.note_submission("frog")
	await _wait(0.5)
	print("T2 tier=%d text=%s" % [director.hint_tier(), _strip_text()])
	await _capture("03_t2_own_classes")

	director.note_submission("frog")       # four misses -> T3
	director.note_submission("frog")
	await _wait(0.5)
	print("T3 tier=%d text=%s" % [director.hint_tier(), _strip_text()])
	await _capture("04_t3_widened")

	# --- solving it, which must clear the strip -------------------------------
	level.call("_judge_submission", "square")
	await _wait(0.6)
	print("after sub1: stage=%s text=%s" % [director.stage_id("B0_HAGDAN"), _strip_text()])
	await _capture("05_sub2_roll")

	level.call("_judge_submission", "circle")
	await _wait(0.6)
	print("solved=%s strip visible=%s" % [director.is_solved("B0_HAGDAN"), strip.visible])
	await _capture("06_beat0_solved")

	# --- the gorge: the node, its three buttons, and the committed requirement -
	player.global_position = Vector2(2360.0, 200.0)
	await _wait(1.0)
	print("at obstacle: '%s'" % director.current_obstacle())
	await _capture("07_node1_arrival")

	var node := level.get("dialogue_node") as DialogueNode2D
	if node != null:
		level.call("_on_dialogue_node_approached")
		await _wait(0.8)
		await _capture("08_node1_choice")
		# BEFORE answering: can the player open the canvas while the choice is up? The
		# overlay is modal and pauses the world, so R must do nothing here. If it opens
		# the panel, the tutorial's first real decision can be walked out of sideways.
		var overlay := level.get_node("DialogueChoiceOverlay")
		var panel_before := level.get_node("DrawPanel") as DrawPanel
		# Through Godot's own routing, NOT by calling _unhandled_input directly: the whole
		# question is whether the modal consumes the key first, and calling the handler by
		# hand skips exactly the step under test and always reports a bug.
		Input.parse_input_event(_key_event("redraw"))
		await _wait(0.4)
		print("R during the choice -> panel visible=%s (overlay still up=%s)"
			% [panel_before.visible, overlay.visible])
		await _capture("08b_R_during_choice")

		# Press the real button, the way a player does. The overlay closes itself in
		# _on_route_pressed, and bypassing that leaves a modal menu on screen that reads
		# as a stacking bug in a screenshot when it is only the test cheating.
		var buttons := overlay.get_node("Root/Center/Panel/VBox/Buttons") if overlay.has_node("Root/Center/Panel/VBox/Buttons") else null
		var pressed := false
		if buttons != null and buttons.get_child_count() > 0:
			(buttons.get_child(0) as Button).emit_signal("pressed")
			pressed = true
		else:
			for candidate in _all_buttons(overlay):
				if String(candidate.text).begins_with("Ibalik"):
					candidate.emit_signal("pressed")
					pressed = true
					break
		print("pressed the real button: %s" % pressed)
		await _wait(0.8)
		print("overlay closed after press: %s" % (not overlay.visible))
		print("committed=%s text=%s" % [director.committed_route("L1_N1"), _strip_text()])
		await _capture("09_artist_committed")

	# --- the drawing panel over the strip, which is the real overlap risk ------
	var panel := level.get_node("DrawPanel") as DrawPanel
	panel.open_panel()
	await _wait(0.8)
	await _capture("10_panel_open_over_strip")

	print("OBRA_VISUAL_L1_DONE")
	quit(0)


## A synthetic key press for the action, so input goes through the same path a player's
## keyboard does rather than calling the handler behind it.
func _key_event(action: String) -> InputEventKey:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			var press := key.duplicate() as InputEventKey
			press.pressed = true
			return press
	return InputEventKey.new()


func _all_buttons(node: Node) -> Array[Button]:
	var out: Array[Button] = []
	for child in node.get_children():
		if child is Button:
			out.append(child as Button)
		out.append_array(_all_buttons(child))
	return out


func _strip_text() -> String:
	return _collect_labels(strip).strip_edges()


func _collect_labels(node: Node) -> String:
	var out := ""
	for child in node.get_children():
		if child is Label and (child as Label).visible:
			out += "[%s] " % (child as Label).text
		out += _collect_labels(child)
	return out


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/obra_l1_%s.png" % [OUTPUT_DIR, label])


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout
