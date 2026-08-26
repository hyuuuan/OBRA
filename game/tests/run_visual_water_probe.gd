extends SceneTree
## Frames of the apo in the lower paddy, walking in and jumping, to see what follows her.

var level: Node2D
var player: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	level = (load("res://game_level.tscn") as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	# A conversation stops the tree, and nobody is here to turn the page.
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.5)

	player = level.get("player") as Node2D
	if player == null:
		push_error("no player")
		quit(1)
		return

	# Beside the lower paddy: it spans x 340..640, surface at y 560.
	player.global_position = Vector2(300.0, 500.0)
	await _wait(0.8)
	await _shot("00_beside")

	# The very edge of the paddy, so the drown rescue does not fire mid-probe.
	player.global_position = Vector2(352.0, 520.0)
	await _wait(0.7)
	await _shot("01_wading")

	# Eight frames across one jump, which is what catches something moving WITH her.
	Input.action_press("jump")
	for frame in range(8):
		await _wait(0.05)
		await _shot("02_jump_%02d" % frame)
	Input.action_release("jump")
	await _wait(0.4)
	await _shot("03_after")
	print("OBRA_WATER_PROBE_DONE")
	quit()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/obra_water_%s.png" % label)


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout
