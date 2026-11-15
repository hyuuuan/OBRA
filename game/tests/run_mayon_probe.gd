extends SceneTree
## Mayon's painted world: every backdrop band covers the screen at every camera position, along
## AND up, at its own rates; the ground is solid where it is drawn; the cone grows no grass.
##
##   godot --headless --path game --script res://tests/run_mayon_probe.gd

const FLOOR_TOP := 400.0

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _a_band_covers_every_camera_position()
	await _a_band_rises_with_the_camera_at_its_own_rate()
	await _there_is_one_mayon_and_it_stays_in_view()
	await _the_ground_holds_her()
	await _the_cone_grows_no_grass()
	await _the_ground_has_no_seams()
	if failures == 0:
		print("OBRA_MAYON_OK")
		quit(0)
	else:
		print("OBRA_MAYON_FAILED=%d" % failures)
		quit(1)


func _band(plate: String, scroll: float, rise: float) -> MayonBackdrop2D:
	var band := MayonBackdrop2D.new()
	band.plate = plate
	band.scroll_scale = scroll
	band.rise_scale = rise
	band.span = Vector2(0.0, 16000.0)
	band.mirrored = plate == "sky"
	root.add_child(band)
	band.set_camera_origin(Vector2(800.0, 300.0))
	return band


func _a_band_covers_every_camera_position() -> void:
	var gaps: Array[String] = []
	for row in [["sky", 0.02], ["meadow", 0.25], ["ground", 0.45]]:
		var band := _band(row[0], row[1], row[1])
		for camera_x: float in [800.0, 4000.0, 9000.0, 15500.0]:
			band.update_for_camera(Vector2(camera_x, -900.0))
			for edge: float in [camera_x - 800.0, camera_x + 800.0]:
				var covered := false
				for sprite: Sprite2D in band.get_children():
					var left: float = band.position.x + sprite.position.x
					covered = covered or (edge >= left and edge <= left + MayonBackdrop2D.PLATE_WIDTH)
				if not covered:
					gaps.append("%s leaves x %.0f bare at camera %.0f" % [row[0], edge, camera_x])
		if row[0] == "sky":
			var flips: Array[bool] = []
			for sprite: Sprite2D in band.get_children():
				flips.append(sprite.flip_h)
			if not (flips.has(true) and flips.has(false)):
				gaps.append("the sky is not mirrored on every other repeat")
		band.queue_free()
	await process_frame
	_check(gaps.is_empty(), "every band covers the screen along the whole climb",
		"no gaps" if gaps.is_empty() else "; ".join(gaps.slice(0, 3)))


func _a_band_rises_with_the_camera_at_its_own_rate() -> void:
	# Start from the camera's origin and climb 1200 px: a far band hardly moves on screen, a near
	# one sinks away -- drive it UP, the way the old band (pinned in y) could not follow.
	var wrong: Array[String] = []
	for row in [["volcano", 0.06], ["meadow", 0.25]]:
		var band := _band(row[0], 0.1, row[1])
		band.update_for_camera(Vector2(2000.0, 300.0 - 1200.0))
		var expected := Vector2((2000.0 - 800.0) * 0.9, -1200.0 * (1.0 - float(row[1])))
		if band.position.distance_to(expected) > 0.01:
			wrong.append("%s at (%.0f, %.0f), not (%.0f, %.0f)" % [row[0], band.position.x,
				band.position.y, expected.x, expected.y])
		# On screen, the band has moved down by rise_scale of the climb.
		var on_screen := band.position.y - (-1200.0)
		if absf(on_screen - 1200.0 * float(row[1])) > 0.01:
			wrong.append("%s sank %.0f px on screen, not %.0f" % [row[0], on_screen, 1200.0 * float(row[1])])
		band.queue_free()
	await process_frame
	_check(wrong.is_empty(), "a band follows the camera up at its own rate",
		"volcano sinks 72 px, meadow 300 px over a 1200 px climb" if wrong.is_empty() else "; ".join(wrong))


func _there_is_one_mayon_and_it_stays_in_view() -> void:
	# Repeated like the other bands, the volcano stood beside a second volcano. One plate, its
	# cone drifting from right of centre to left of it across the whole climb.
	var band := MayonBackdrop2D.new()
	band.plate = "volcano"
	band.scroll_scale = 0.05
	band.rise_scale = 0.05
	band.single = true
	band.single_offset = 400.0
	root.add_child(band)
	band.set_camera_origin(Vector2(800.0, 300.0))
	var lost: Array[String] = []
	for camera_x: float in [800.0, 6000.0, 11000.0, 16000.0]:
		band.update_for_camera(Vector2(camera_x, 300.0))
		var sprite := band.get_child(0) as Sprite2D
		var cone := band.position.x + sprite.position.x + MayonBackdrop2D.PLATE_WIDTH * 0.5
		if absf(cone - camera_x) > 560.0:
			lost.append("cone %.0f px from the middle at camera %.0f" % [cone - camera_x, camera_x])
	_check(band.repeats() == 1 and lost.is_empty(), "there is one Mayon, in view the whole climb",
		"%d plate(s); %s" % [band.repeats(), "always within 560 px of the middle" if lost.is_empty() else "; ".join(lost)])
	band.queue_free()
	await process_frame


func _the_ground_holds_her() -> void:
	var terrain := MayonTerrain2D.new()
	terrain.platforms = [Rect2(0.0, FLOOR_TOP, 2000.0, 200.0)]
	root.add_child(terrain)
	var apo := (load("res://creatures/wanderer.tscn") as PackedScene).instantiate() as Wanderer
	apo.set_world_bounds(Rect2(-1000.0, -2000.0, 6000.0, 4000.0))
	root.add_child(apo)
	apo.global_position = Vector2(200.0, FLOOR_TOP - 150.0)
	await _frames(60)
	_check(apo.is_on_floor() and absf(apo.global_position.y - FLOOR_TOP) < 2.0,
		"she lands on the ground where it is drawn",
		"feet at %.1f, top at %.0f" % [apo.global_position.y, FLOOR_TOP])
	terrain.queue_free()
	apo.queue_free()
	await process_frame


func _the_cone_grows_no_grass() -> void:
	var slope := MayonTerrain2D.new()
	slope.platforms = [Rect2(0.0, 0.0, 300.0, 100.0)]
	root.add_child(slope)
	var cone := MayonTerrain2D.new()
	cone.platforms = [Rect2(0.0, 0.0, 300.0, 100.0)]
	cone.grassed = false
	root.add_child(cone)
	await process_frame
	_check(slope.get("_grass") != null and cone.get("_grass") == null,
		"the slopes are grassed and the bare cone is not",
		"slope grass %s, cone grass %s" % [slope.get("_grass") != null, cone.get("_grass") != null])
	slope.queue_free()
	cone.queue_free()
	await process_frame


## Every column of the real mountain is rock near the walk line. Each cliff tile is clear at its
## ends and tapers with depth, so tiles laid edge to edge showed a dark V that read as a pit.
func _the_ground_has_no_seams() -> void:
	var world := (load("res://levels/level_5/level_5_environment.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var columns := 0
	var holes := 0
	var first: Array[String] = []
	for terrain: MayonTerrain2D in world.find_children("*", "MayonTerrain2D", true, false):
		if terrain.one_way:
			continue
		for rect: Rect2 in terrain.platforms:
			var cliff: Texture2D = MayonTerrain2D.CLIFFS[terrain.call("_zone", rect)]
			var art := cliff.get_image()
			if art.is_compressed():
				art.decompress()
			var pieces := terrain.tiles_across(rect, float(cliff.get_width()), 0.0)
			var x := rect.position.x + 1.0
			while x < rect.end.x - 1.0:
				columns += 1
				for row in [30, 60]:
					var solid := false
					for piece in pieces:
						if x >= piece.x and x < piece.x + piece.z:
							solid = solid or art.get_pixel(int(piece.y + x - piece.x), row).a >= 0.5
					if not solid:
						holes += 1
						if first.size() < 4:
							first.append("%s x%.0f row %d" % [terrain.name, x + terrain.global_position.x, row])
				x += 2.0
	_check(columns > 1000 and holes == 0, "the ground has no see-through seam along the climb",
		"%d columns, %d holes %s" % [columns, holes, first])
	world.queue_free()
	await process_frame


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func _check(ok: bool, what: String, detail: String) -> void:
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
