extends "res://tests/run_level4_seg3_probe.gd"

func _run() -> void:
	create_timer(20.0).timeout.connect(func() -> void: quit(2))
	level = await _open_level()
	await _put(16980.0, GROUND_Y, &"move_right")
	await _seconds(0.5)
	await _capture_match("baby")
	Input.action_press(&"move_right")
	var until := Time.get_ticks_msec() + 1500
	while _tiyanak().art.anim() == "idle" and Time.get_ticks_msec() < until:
		await _frames(1)
	Input.action_release(&"move_right")
	await _seconds(1.5)
	await _capture_match("monster")
	print("OBRA_TIYANAK_MATCH_VISUAL_DONE")
	quit(0)

func _capture_match(phase: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/obra_tiyanak_match_%s.png" % phase)
