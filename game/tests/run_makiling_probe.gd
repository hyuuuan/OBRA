extends SceneTree
## Dilim's painted world: the backdrop bands cover every camera position at their own rates, and
## the ground is solid where it is drawn, with branches you can jump up through.
##
##   godot --headless --path game --script res://tests/run_makiling_probe.gd

const FLOOR_TOP := 400.0

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _a_band_covers_every_camera_position()
	await _the_ground_holds_and_a_branch_lets_her_up()
	if failures == 0:
		print("OBRA_MAKILING_OK")
		quit(0)
	else:
		print("OBRA_MAKILING_FAILED=%d" % failures)
		quit(1)


func _a_band_covers_every_camera_position() -> void:
	var world := (load("res://levels/level_4/level_4_environment.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var forest := world.get_node("ForestBand") as MakilingBackdrop2D
	_check(forest.plate_texture == preload("res://assets/Level4/trees/forest_plate.png"),
		"the near band uses the supplied forest trees", "ForestBand")
	var origin: Vector2 = world.get_node("WorldCamera").global_position
	var bands := ["SkyBand", "MountainBand", "CanopyBand", "ForestBand"]
	var gaps: Array[String] = []
	var previous_rate := 0.0
	var previous_z := -INF
	for band_name: String in bands:
		var band := world.get_node(band_name) as MakilingBackdrop2D
		_check(band.plate_texture != null and band.scroll_scale > previous_rate
			and band.z_index > previous_z and band.z_index < 0,
			"%s has its own texture and moves at its depth behind play" % band_name,
			"rate %.3f, z %d" % [band.scroll_scale, band.z_index])
		previous_rate = band.scroll_scale
		previous_z = band.z_index
		for camera_x: float in [origin.x, 6000.0, 11400.0, 17000.0, 21500.0]:
			band.update_for_camera(Vector2(camera_x, 0.0))
			var expected := (camera_x - origin.x) * (1.0 - band.scroll_scale)
			if absf(band.position.x - expected) > 0.01:
				gaps.append("%s drift at camera %.0f" % [band_name, camera_x])
		if band_name == "MountainBand":
			_check(band.repeats() == 1, "Makiling is a single landmark", "%d plate" % band.repeats())
			continue
		var right := -INF
		var previous: Sprite2D
		var should_mirror := band_name != "ForestBand"
		for sprite: Sprite2D in band.get_children():
			var left := sprite.position.x
			if previous != null:
				var mirrored := previous.flip_h != sprite.flip_h
				if not is_equal_approx(left, right) or mirrored != should_mirror:
					gaps.append("%s has a broken repeat at %.0f" % [band_name, left])
			right = left + sprite.get_rect().size.x * sprite.scale.x
			previous = sprite
		var first := band.get_child(0) as Sprite2D
		var view_left := origin.x - 800.0
		var view_right := 22300.0 - band.position.x
		if first.position.x > view_left or right < view_right:
			gaps.append("%s does not cover the camera's travel" % band_name)
	world.queue_free()
	await process_frame
	_check(gaps.is_empty(), "parallax tracks the camera and the repeated plates join across the route",
		"no gaps" if gaps.is_empty() else "; ".join(gaps.slice(0, 3)))


func _the_ground_holds_and_a_branch_lets_her_up() -> void:
	var terrain := MakilingTerrain2D.new()
	terrain.platforms = [Rect2(0.0, FLOOR_TOP, 2000.0, 200.0)]
	terrain.branches = [Rect2(500.0, FLOOR_TOP - 80.0, 200.0, 18.0)]
	root.add_child(terrain)
	var apo := (load("res://creatures/wanderer.tscn") as PackedScene).instantiate() as Wanderer
	apo.set_world_bounds(Rect2(-1000.0, -2000.0, 6000.0, 4000.0))
	root.add_child(apo)
	apo.global_position = Vector2(200.0, FLOOR_TOP - 150.0)
	await _frames(60)
	_check(apo.is_on_floor() and absf(apo.global_position.y - FLOOR_TOP) < 2.0,
		"she lands on the ground where it is drawn", "feet at %.1f, top at %.0f" % [apo.global_position.y, FLOOR_TOP])
	# Under the branch, jump: through it from below, onto it from above.
	apo.global_position = Vector2(600.0, FLOOR_TOP)
	await _frames(10)
	Input.action_press(&"jump")
	await _frames(14)
	Input.action_release(&"jump")
	await _frames(60)
	var on_branch := absf(apo.global_position.y - (FLOOR_TOP - 80.0)) < 2.0 and apo.is_on_floor()
	_check(on_branch, "a branch lets her jump up through it and stand on it",
		"feet at %.1f, branch top at %.0f" % [apo.global_position.y, FLOOR_TOP - 80.0])
	terrain.queue_free()
	apo.queue_free()
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
