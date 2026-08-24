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

	# Mid-stroke: some of the budget gone, some claimed by ink on the canvas that has not
	# been spent yet. The two-tone block is the whole reason the gauge is drawn by hand.
	var hud = level.get("hud_panel")
	hud.call("set_ink", 7.4, 12.0, 2.2)
	level.get("status_label").text = "Recognizing…"
	await _wait(0.4)
	await _capture("01_ink_reserved")

	hud.call("set_ink", 0.8, 12.0, 0.0)
	level.get("status_label").text = "No ink left — nothing more can be drawn in this level"
	await _wait(0.4)
	await _capture("02_ink_spent")
	# Both restored, or every frame after this one is photographed with a spent gauge and
	# a line about running out of ink that has nothing to do with what it is showing.
	hud.call("set_ink", 12.0, 12.0, 0.0)
	level.get("status_label").text = "Ready — draw a morph or utility"

	# The framed box, both voices, and the state that only exists for a second and a half:
	# a line still arriving. If the reveal ever breaks it breaks here and nowhere else.
	level.get("lolo").call("say", "Four hundred years. Maybe less. They built this while the Spanish were burning the lowlands — this was not left behind, apo. This is an answer.")
	await _wait(0.5)
	await _capture("03_dialogue_typing")
	await _wait(3.0)
	await _capture("04_dialogue_full")
	level.get("dialogue_box").call("show_line", "Her brush is still warm.", "Apo")
	await _wait(1.2)
	await _capture("05_dialogue_apo")
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


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/obra_hud_%s.png" % label)


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout
