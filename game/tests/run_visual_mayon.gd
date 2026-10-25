extends SceneTree
## Look at Mayon's painted world: the bands and the ground at play framing, at the foot of the
## mountain and twice further up, so the climb's parallax can be seen.
##
##   godot -t --path game --script res://tests/run_visual_mayon.gd
##
## Windowed. Writes /tmp/obra_mayon_<n>.png for a person to look at; run_mayon_probe checks the
## numbers.

const ORIGIN := Vector2(1400.0, 300.0)
## Camera stops: the foot, the mid slope, the cone.
const STOPS := [Vector2(1400.0, 300.0), Vector2(3400.0, -400.0), Vector2(5400.0, -1100.0)]

## [plate, scroll, rise, top, z]. Back to front, as EnvironmentBaseplate would sort them.
const ROWS := [["sky", 0.02, 0.02, -170.0, -10], ["volcano", 0.05, 0.05, -330.0, -9],
	["meadow", 0.22, 0.3, -90.0, -8], ["ground", 0.45, 0.6, 200.0, -7]]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var camera := Camera2D.new()
	world.add_child(camera)
	camera.global_position = ORIGIN
	camera.make_current()
	var bands: Array[MayonBackdrop2D] = []
	for row in ROWS:
		var band := MayonBackdrop2D.new()
		band.plate = row[0]
		band.scroll_scale = row[1]
		band.rise_scale = row[2]
		band.plate_top = row[3]
		band.z_index = row[4]
		band.mirrored = row[0] == "sky"
		band.single = row[0] == "volcano"
		band.single_offset = 300.0
		world.add_child(band)
		band.set_camera_origin(ORIGIN)
		bands.append(band)
	# A stepped climb: grassed at the foot, bare on the cone.
	var slopes := MayonTerrain2D.new()
	slopes.platforms = [Rect2(0.0, 600.0, 2600.0, 600.0), Rect2(2600.0, 520.0, 500.0, 680.0),
		Rect2(3100.0, 300.0, 700.0, 900.0), Rect2(3800.0, 0.0, 700.0, 1200.0)]
	world.add_child(slopes)
	var cone := MayonTerrain2D.new()
	cone.grassed = false
	cone.platforms = [Rect2(4500.0, -300.0, 800.0, 1500.0), Rect2(5300.0, -600.0, 900.0, 1800.0)]
	world.add_child(cone)
	for index in range(STOPS.size()):
		var stop: Vector2 = STOPS[index]
		camera.global_position = stop
		for band in bands:
			band.update_for_camera(stop)
		for _frame in range(6):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/obra_mayon_%d.png" % index)
	print("OBRA_MAYON_SHOT_DONE")
	quit(0)
