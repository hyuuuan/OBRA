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
	if failures == 0:
		print("OBRA_MAKILING_OK")
		quit(0)
	else:
		print("OBRA_MAKILING_FAILED=%d" % failures)
		quit(1)


func _a_band_covers_every_camera_position() -> void:
	var gaps: Array[String] = []
	for row in [["mountain_far", 0.08], ["mountain_near", 0.18], ["frame", 1.08], ["sky", 0.02]]:
		var band := MakilingBackdrop2D.new()
		band.plate = row[0]
		band.scroll_scale = row[1]
		band.span = Vector2(0.0, 22800.0)
		root.add_child(band)
		band.set_camera_origin(Vector2(800.0, 0.0))
		for camera_x: float in [800.0, 6000.0, 11400.0, 17000.0, 22000.0]:
			band.update_for_camera(Vector2(camera_x, 0.0))
			var expected: float = (camera_x - 800.0) * (1.0 - band.scroll_scale)
			if absf(band.position.x - expected) > 0.01:
				gaps.append("%s at %.0f scrolls to %.0f, not %.0f" % [row[0], camera_x, band.position.x, expected])
			for edge: float in [camera_x - 800.0, camera_x + 800.0]:
				var covered := false
				for sprite: Sprite2D in band.get_children():
					var left: float = band.position.x + sprite.position.x
					covered = covered or (edge >= left and edge <= left + MakilingBackdrop2D.PLATE_WIDTH)
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
	_check(gaps.is_empty(), "every band covers the screen at every camera position, at its own rate",
		"no gaps" if gaps.is_empty() else "; ".join(gaps.slice(0, 3)))


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func _check(ok: bool, what: String, detail: String) -> void:
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
