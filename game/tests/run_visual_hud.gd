extends SceneTree
## Every piece of the HUD, photographed. Needs a real viewport:
##   godot --path game --script res://tests/run_visual_hud.gd
## Frames land in /tmp/obra_hud_*.png
##
## THE SKIN IS ONLY CHECKABLE BY LOOKING AT IT. Nothing here is a pass/fail assertion and
## it deliberately is not one: a stylebox with the wrong colour, a frame whose rings have
## collapsed into each other, a label sitting under an icon, a gauge that reads as one bar
## instead of twelve blocks -- all of them load without error and all of them are obvious
## in a screenshot. Eight defects in this project have now passed green suites and been
## caught only this way.
##
## The states are chosen to be the ones that differ: a full gauge and a nearly-spent one,
## ink reserved mid-stroke, a line still typing and the same line finished, and both of
## the voices that share the framed box.

var level: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://game_level.tscn") as PackedScene
	level = scene.instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	await _wait(1.4)

	var player := level.get("player") as Node2D
	player.global_position = Vector2(760.0, 430.0)
	await _wait(0.6)
	await _capture("00_hud_full")

	# THE ACTIONS ARE STATES, not one legend. Hold the level's state refresh for these
	# three photographs so each presentation can be inspected without fabricating a whole
	# placed drawing, held tool and morph merely to reach the same UI state.
	var prompts = level.get("action_prompts")
	# The opening story pauses the tree. End it before photographing controls whose pop and
	# follow motion intentionally belongs to gameplay time.
	level.get("dialogue_box").call("hide_line")
	await _wait(0.25)
	level.set_physics_process(false)
	prompts.call("set_pickup_available", true, "Ladder")
	await _wait(0.45)
	await _capture("00e_action_pickup")
	prompts.call("set_pickup_available", false)
	prompts.call("set_use_available", true, "Axe")
	await _wait(0.45)
	await _capture("00f_action_use")
	prompts.call("set_pickup_available", true, "Ladder")
	prompts.call("set_revert_available", true)
	await _wait(0.45)
	await _capture("00g_actions_all_contexts")
	prompts.call("set_pickup_available", false)
	prompts.call("set_use_available", false)
	prompts.call("set_revert_available", false)
	await _wait(0.25)
	level.set_physics_process(true)

	# Mid-stroke: some of the budget gone, some claimed by ink on the canvas that has not
	# been spent yet. The two-tone block is the whole reason the gauge is drawn by hand.
	var hud = level.get("hud_panel")

	# THE NAMEPLATE, which only exists while the player is a drawing. Three frames, because
	# the bar changes colour twice on the way down and a still of the full one proves none
	# of that. The apo's own state -- no plate at all -- is what 00 above already shows.
	# THE CARD IN THE OPPOSITE CORNER, which is where what-you-are lives now. Three frames,
	# because the bar changes colour twice on the way down and a still of the full one proves
	# none of that. Fed a stand-in drawing rather than a real submission: what is being
	# photographed is the card, and a real morph would also move the camera.
	var card = level.get("morph_card")
	var sketch := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	sketch.fill(Color(0.96, 0.94, 0.88, 1.0))
	for i in range(18, 78):
		sketch.set_pixel(i, 48, Color.BLACK)
		sketch.set_pixel(48, i, Color.BLACK)
		sketch.set_pixel(i, i, Color.BLACK)
		sketch.set_pixel(96 - i, i, Color.BLACK)
	card.call("show_form", "Spider", sketch, 0.94)
	card.call("set_life", 10.0, 10.0)
	await _wait(0.4)
	await _capture("00a_form_full")

	card.call("set_life", 4.2, 10.0)
	await _wait(0.4)
	await _capture("00b_form_low")

	card.call("set_life", 1.4, 10.0)
	level.get("status_label").text = "The spider is fading"
	await _wait(0.4)
	await _capture("00c_form_critical")

	# And gone: the corner is empty again the moment the drawing expires.
	card.call("hide_form")
	level.get("status_label").text = "Checking backend…"
	await _wait(0.3)
	await _capture("00d_form_expired")

	hud.call("set_ink", 7.4, 12.0, 2.2)
	level.get("status_label").text = "Recognizing…"
	await _wait(0.4)
	await _capture("01_ink_reserved")

	# Running low, which is now a state with a COLOUR and not just a length: the brush warms
	# toward amber under a third of the budget and goes red under an eighth, so these are two
	# separate frames rather than one nearly-empty one.
	hud.call("set_ink", 3.4, 12.0, 0.0)
	level.get("status_label").text = "Ink running low"
	await _wait(0.4)
	await _capture("02a_ink_low")

	hud.call("set_ink", 0.8, 12.0, 0.0)
	level.get("status_label").text = "No ink left — nothing more can be drawn in this level"
	await _wait(0.4)
	await _capture("02_ink_spent")

	hud.call("set_ink", 0.0, 12.0, 0.0)
	await _wait(0.4)
	await _capture("02b_ink_dry")
	# Both restored, or every frame after this one is photographed with a spent gauge and
	# a line about running out of ink that has nothing to do with what it is showing.
	hud.call("set_ink", 12.0, 12.0, 0.0)
	level.get("status_label").text = "Ready — draw a morph or utility"

	# A real beat: three lines, queued, with the world stopped and the camera pushed in on
	# the speaker. Photographed mid-type and again once the arrow is up, because those are
	# the two states the player actually sees.
	level.call("_focus_camera_for", "lolo")
	level.get("dialogue_box").call("speak", [
		{"text": "Four hundred years. Maybe less. They built this while the Spanish were burning the lowlands.", "speaker": "Lolo"},
		{"text": "This was not left behind, apo. This is an answer.", "speaker": "Lolo"},
		{"text": "Her brush is still warm.", "speaker": "Apo"},
	])
	await _wait(0.5)
	await _capture("03_dialogue_typing")
	await _wait(3.0)
	await _capture("04_dialogue_full")
	# Through to the apo's line, so the other portrait and the other side are both
	# photographed -- a portrait system that only ever shows one face is untested.
	# Pressed until the apo's line is up rather than a fixed count: the greeting is already
	# queued ahead of this beat, and counting presses means recounting them whenever the
	# script changes.
	for _press in range(12):
		if String(level.get("dialogue_box").call("current_speaker")).begins_with("Apo"):
			break
		await _press_advance()
	await _wait(2.6)
	await _capture("04b_dialogue_apo")
	level.get("dialogue_box").call("skip_all")
	await _wait(0.8)

	# The other channel: a hint, which never stops play and needs no key.
	level.get("lolo").call("say", "Draw something that can SPAN it — anything that will cross the gap.")
	await _wait(0.6)
	await _capture("05_hint_bar")
	level.get("lolo").call("hush")
	await _wait(0.4)

	level.get_node("DrawPanel").call("open_panel")
	await _wait(0.9)
	await _capture("06_draw_panel")
	level.get_node("DrawPanel").call("close_panel")
	await _wait(0.5)

	level.get_node("PauseMenu").call("open")
	await _wait(0.8)
	await _capture("07_pause")
	level.get_node("PauseMenu").get("settings_button").emit_signal("pressed")
	await _wait(1.0)
	await _capture("08_settings")
	var settings := level.get_node_or_null("SettingsOverlay")
	if settings != null:
		settings.call("close")
	await _wait(0.4)
	level.get_node("PauseMenu").call("close")
	await _wait(0.5)

	print("OBRA_VISUAL_HUD_DONE")
	quit(0)


func _press_advance() -> void:
	var press := InputEventAction.new()
	press.action = &"ui_accept"
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventAction.new()
	release.action = &"ui_accept"
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
	await process_frame


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/obra_hud_%s.png" % label)


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout
