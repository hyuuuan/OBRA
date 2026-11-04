extends "res://tests/run_visual_dilim_creatures.gd"
## Windowed: real finale lighting sampled at 0, 60, 75 and 90 seconds.
## The physics clock is held at each sample; the level still runs its real lighting controller.
## Writes /tmp/obra_dawn_<seconds>.png and /tmp/obra_dawn_progression.png.


func _run() -> void:
	level = (load("res://level_4.tscn") as PackedScene).instantiate()
	level.get_node("BackendSupervisor").auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(40)
	await _put_her(21700)
	# Keep the protected review character visible in every sample instead of blinking.
	(level.get("player_health") as PlayerHealth).set_flicker_target(null)
	await _frames(15)
	var finale := level.get("_finale") as DilimFinale2D
	if not finale.is_running():
		push_error("HARNESS FAULT: finale never started")
		quit(1)
		return
	finale.set_physics_process(false)
	for foe in finale.alive():
		foe.process_mode = Node.PROCESS_MODE_DISABLED
	var sheet := Image.create(1600, 900, false, Image.FORMAT_RGBA8)
	var index := 0
	for seconds: float in [0.0, 60.0, 75.0, 90.0]:
		finale.elapsed = seconds
		if seconds == 90.0:
			finale.call("_dawn")
		await _frames(65 if seconds == 90.0 else 3)
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		shot.save_png("/tmp/obra_dawn_%d.png" % int(seconds))
		shot.convert(Image.FORMAT_RGBA8)
		shot.resize(800, 450, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()),
			Vector2i((index % 2) * 800, (index / 2) * 450))
		index += 1
	sheet.save_png("/tmp/obra_dawn_progression.png")
	print("OBRA_DAWN_VISUAL_OK")
	quit(0)
