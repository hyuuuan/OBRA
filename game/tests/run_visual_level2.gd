extends SceneTree
## Eyes on Piyesta. Needs a REAL viewport, so no --headless:
##   godot --path game --script res://tests/run_visual_level2.gd
## Frames land in /tmp/obra_l2_*.png
##
## The headless probes prove the plaza's numbers. They cannot see whether the six parallax
## layers register against each other, whether the collision agrees with the picture, or
## whether the bandarita line the flight ceiling is pinned to is actually on screen where
## the rule says it is. Four defects in this project passed green suites and were caught
## only by screenshotting, and this level's whole boundary is a painted string.

const OUTPUT_DIR := "/tmp"

var level: Node2D
var player: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://level_2.tscn") as PackedScene
	level = scene.instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.4)

	player = level.get("player") as Node2D
	if player == null:
		print("OBRA_VISUAL_L2_FAILED: no player")
		quit(1)
		return

	await _capture("01_spawn")

	# The dialogue node stands at the dancers, and walking into it opens the route choice
	# and PAUSES THE TREE -- which is exactly right, and is why the camera never moved on
	# the first two runs of this file: every frame after the first was the same paused
	# frame. Disarmed so the tour can pass through, not because it is wrong.
	var node := level.get("dialogue_node") as Node2D
	if node != null:
		node.set_process_mode(Node.PROCESS_MODE_DISABLED)
	var choice := level.get_node_or_null(^"DialogueChoiceOverlay")
	if choice != null and choice.has_method("close"):
		choice.call("close")
	await _wait(0.4)

	# A TOUR, not a walk. Walking east reaches the dialogue node, which opens the route
	# choice and stops the tree -- correct behaviour, and it froze five of the six frames
	# on the first run of this file. Teleporting past it is what a camera does.
	for step in [[560.0, "02_dancers"], [1000.0, "03_plaza"], [1600.0, "04_houses"],
			[2400.0, "05_church"]]:
		var at := Vector2(float(step[0]), 480.0)
		if player.has_method("apply_morph_state"):
			player.call("apply_morph_state", {"position": at, "linear_velocity": Vector2.ZERO})
		else:
			player.global_position = at
		await _wait(0.9)
		var cam := level.get_node_or_null(^"EnvironmentBaseplate/WorldCamera") as Camera2D
		print("  %s: asked for x=%.0f, player at %s, camera at %s"
			% [step[1], at.x, player.global_position,
			   cam.global_position if cam != null else Vector2.ZERO])
		await _capture(String(step[1]))

	print("OBRA_VISUAL_L2_OK")
	quit(0)


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/obra_l2_%s.png" % [OUTPUT_DIR, label])


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout
