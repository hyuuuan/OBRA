extends SceneTree
## Look at Mayon's ash taking the world: the meadow, the ground and the bell tower drained to
## 0, 0.3, 0.5, 0.7 and 0.9, with the ash falling over them, at play framing.
##
##   godot -t --path game --script res://tests/run_visual_mayon_drain.gd
##
## Windowed. Writes /tmp/obra_mayon_drain_<n>.png for a person to look at; run_drain_probe
## checks the numbers.

const CAMERA := Vector2(1400.0, 300.0)
const STAGES := [0.0, 0.3, 0.5, 0.7, 0.9]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var camera := Camera2D.new()
	world.add_child(camera)
	camera.global_position = CAMERA
	camera.make_current()
	var ash := AshFall2D.new()
	ash.density = 0.6
	camera.add_child(ash)
	var taken: Array[Drainable] = []
	for row in [["sky", 0.02, -170.0, -10], ["volcano", 0.05, -330.0, -9], ["meadow", 0.22, -90.0, -8]]:
		var band := MayonBackdrop2D.new()
		band.plate = row[0]
		band.scroll_scale = row[1]
		band.rise_scale = row[1]
		band.plate_top = row[2]
		band.z_index = row[3]
		band.mirrored = row[0] == "sky"
		band.single = row[0] == "volcano"
		band.single_offset = 300.0
		world.add_child(band)
		band.set_camera_origin(CAMERA)
		if row[0] == "meadow":
			taken.append(_drainable(band))
	var ground := MayonTerrain2D.new()
	ground.platforms = [Rect2(0.0, 600.0, 3000.0, 300.0)]
	world.add_child(ground)
	taken.append(_drainable(ground))
	var tower := Sprite2D.new()
	tower.texture = load("res://assets/Level5/props/bell_tower.png")
	tower.centered = false
	tower.position = Vector2(1650.0, 600.0 - tower.texture.get_height())
	world.add_child(tower)
	taken.append(_drainable(tower))
	for index in range(STAGES.size()):
		for drainable in taken:
			drainable.drain_to(STAGES[index], 0.0)
		for _frame in range(8):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/obra_mayon_drain_%d.png" % index)
	print("OBRA_MAYON_DRAIN_SHOT_DONE")
	quit(0)


func _drainable(target: Node) -> Drainable:
	var drainable := Drainable.new()
	target.add_child(drainable)
	return drainable
