extends SceneTree
## Every popup in the game, one screenshot each. Needs a real viewport:
##   godot --path game --script res://tests/run_visual_popups.gd
## Frames land in /tmp/obra_pop_*.png
##
## They were each pinned to a hand-picked rect far larger than their content, so the text
## sat marooned in an empty slab. That is not visible from any headless assertion -- the
## labels say the right words at the right size either way.

var level: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://game_level.tscn") as PackedScene
	level = scene.instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	await _wait(1.2)

	var d = level.get("director")
	var player := level.get("player") as Node2D
	player.global_position = Vector2(700.0, 440.0)
	await _wait(0.6)
	await _capture("00_lolo_short")

	# A long line, to prove the bubble grows rather than cramming.
	level.get("lolo").say("Four hundred. Maybe less. They built this while the Spanish were burning the lowlands. This was not left behind, apo. This is an answer.")
	await _wait(0.6)
	await _capture("01_lolo_long")

	level.call("_on_dialogue_node_approached")
	await _wait(0.8)
	await _capture("02_dialogue_choice")
	level.get_node("DialogueChoiceOverlay").call("close")
	await _wait(0.5)

	level.get_node("MemoryOverlay").call("present", "A memory", [
		"She is younger here, and the light is the same gold it is now.",
		"Lola is painting this crossing — the ropes first, then the planks, one at a time.",
		"She looks up from the canvas, straight out of it, and smiles.",
	])
	await _wait(0.8)
	await _capture("03_memory")
	level.get_node("MemoryOverlay").call("close")
	await _wait(0.5)

	level.get_node("OutOfInkOverlay").call("open")
	await _wait(0.8)
	await _capture("04_out_of_ink")
	level.get_node("OutOfInkOverlay").call("close")
	await _wait(0.5)

	level.get_node("LevelCompleteOverlay").call("present", level.call("run_stats"))
	await _wait(0.8)
	await _capture("05_level_complete")
	level.get_node("LevelCompleteOverlay").call("close")
	await _wait(0.5)

	level.get_node("PauseMenu").call("open")
	await _wait(0.8)
	await _capture("06_pause")

	# The two the pause menu opens. Pressed as real buttons -- an earlier version called a
	# handler by name behind a has_method() guard, and when the name was wrong the guard
	# silently did nothing and the screenshot was just the pause menu again.
	var pause := level.get_node("PauseMenu")
	pause.get("settings_button").emit_signal("pressed")
	await _wait(1.0)
	await _capture("07_settings")
	var settings := level.get_node_or_null("SettingsOverlay")
	if settings != null:
		settings.call("close")
	await _wait(0.6)
	pause.get("controls_button").emit_signal("pressed")
	await _wait(1.0)
	await _capture("08_controls")

	print("OBRA_VISUAL_POPUPS_DONE")
	quit(0)

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/obra_pop_%s.png" % label)

func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout
