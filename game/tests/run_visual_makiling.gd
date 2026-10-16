extends SceneTree
## Look at Dilim's painted world: the Makiling bands and the ground, composed at play framing.
##
##   godot -t --path game --script res://tests/run_visual_makiling.gd
##
## Windowed. Writes /tmp/obra_makiling.png for a person to look at; run_makiling_probe checks the
## numbers.

const CAMERA := Vector2(1400.0, 300.0)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var camera := Camera2D.new()
	world.add_child(camera)
	camera.global_position = CAMERA
	camera.make_current()
	# Back to front, as EnvironmentBaseplate would sort them by depth.
	var rows := [["sky", 0.02, -160.0, -10], ["mountain_far", 0.08, -120.0, -9],
		["mountain_near", 0.18, 10.0, -8], ["ground_far", 0.38, 260.0, -7], ["frame", 1.08, -160.0, 5]]
	for row in rows:
		var band := MakilingBackdrop2D.new()
		band.plate = row[0]
		band.scroll_scale = row[1]
		band.plate_top = row[2]
		band.z_index = row[3]
		world.add_child(band)
		band.set_camera_origin(CAMERA)
	var terrain := MakilingTerrain2D.new()
	terrain.platforms = [Rect2(0.0, 600.0, 3000.0, 300.0), Rect2(1650.0, 470.0, 260.0, 130.0)]
	terrain.branches = [Rect2(1100.0, 470.0, 220.0, 18.0)]
	world.add_child(terrain)
	for _frame in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/obra_makiling.png")
	print("OBRA_MAKILING_SHOT_DONE")
	quit(0)
