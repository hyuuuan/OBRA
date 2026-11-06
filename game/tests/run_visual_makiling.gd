extends "res://tests/run_visual_dilim_creatures.gd"
## Look at the live parallax composition at the entrance, a repeat join, the ravine, and the far end.
##
##   godot -w --resolution 1600x900 --path game --script res://tests/run_visual_makiling.gd
##
## Windowed. Writes /tmp/obra_makiling.png and /tmp/obra_makiling_route.png.


func _run() -> void:
	level = (load("res://level_4.tscn") as PackedScene).instantiate()
	level.get_node("BackendSupervisor").auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(40)
	var camera := level.get_node("EnvironmentBaseplate/WorldCamera") as WorldCameraController
	var sheet := Image.create(1600, 900, false, Image.FORMAT_RGBA8)
	var points := [260.0, 2375.0, 19250.0, 21300.0]
	for index in range(points.size()):
		await _put_her(points[index])
		camera.snap_to_target()
		level.set_physics_process(false)
		level.call("_apply_dawn_visuals", 1.0)
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		if index == 0:
			shot.save_png("/tmp/obra_makiling.png")
		shot.convert(Image.FORMAT_RGBA8)
		shot.resize(800, 450, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()),
			Vector2i((index % 2) * 800, (index / 2) * 450))
		level.set_physics_process(true)
	sheet.save_png("/tmp/obra_makiling_route.png")
	print("OBRA_MAKILING_SHOT_DONE")
	quit(0)
