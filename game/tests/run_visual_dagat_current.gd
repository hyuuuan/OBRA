extends "res://tests/run_level3_sea_probe.gd"
## Windowed visual check. Saves /tmp/obra_current_{surface,deep,reduced_motion}.png.


func _run() -> void:
	root.size = Vector2i(1600, 900)
	root.set_content_scale_size(Vector2i(1600, 900))
	await _open_the_level()
	await create_timer(5.0).timeout
	var surface := float(level.get("_waterline_y"))
	var camera := level.call("_world_camera") as Camera2D
	for shot in [["surface", Vector2(2530.0, surface + 18.0)],
			["deep", Vector2(2850.0, 1100.0)]]:
		_place(shot[1])
		camera.call("release_focus")
		await _seconds(0.4)
		await _unpause()
		camera.call("snap_to_target")
		await _current_shot(shot[0])
	var profile := root.get_node_or_null(^"/root/PlayerProfile")
	profile.call("set_setting", "reduce_motion", true)
	await _seconds(0.2)
	await _current_shot("reduced_motion")
	await _close_the_level()
	print("OBRA_VISUAL_CURRENT_OK")
	quit(0)


func _current_shot(label: String) -> void:
	var body := level.get("player") as Node2D
	if body == null or not bool(body.call("is_in_water")) \
			or not root.get_visible_rect().has_point(body.get_global_transform_with_canvas().origin):
		push_error("Harness: the photographed apo must be visible in the sea")
		quit(1)
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("/tmp/obra_current_%s.png" % label)
	if error != OK:
		push_error("Could not save the current's visual check")
		quit(1)
