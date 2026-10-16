extends SceneTree
## The dark and the lights cut out of it: what gameplay counts as lit, what the dark layer draws,
## and the lantern whose light is her health.
##
##   godot --headless --path game --script res://tests/run_darkness_probe.gd
##
## Headless runs draw nothing, so this checks what the shader is GIVEN (the holes, in screen px)
## and the gameplay truth it shares with them. tests/run_visual_dilim_light.gd shows the picture.

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_how_lit_a_point_is()
	await _the_dark_cuts_what_lights_there_are()
	await _the_lantern_shrinks_with_the_flame()
	if failures == 0:
		print("OBRA_DARKNESS_OK")
		quit(0)
	else:
		print("OBRA_DARKNESS_FAILED=%d" % failures)
		quit(1)


func _how_lit_a_point_is() -> void:
	var lamp := {"position": Vector2(100.0, 100.0), "radius": 200.0, "strength": 1.0}
	_check(is_equal_approx(LightField.contribution(lamp, Vector2(200.0, 100.0)), 1.0)
			and LightField.contribution(lamp, Vector2(300.0, 100.0)) == 0.0
			and LightField.contribution(lamp, Vector2(250.0, 100.0)) > 0.0
			and LightField.contribution(lamp, Vector2(250.0, 100.0)) < 1.0,
		"a light is full inside its soft edge, fading to nothing at its radius",
		"%.2f at 175 px" % LightField.contribution(lamp, Vector2(275.0, 100.0)))
	var torch := {"position": Vector2.ZERO, "radius": 300.0, "strength": 1.0,
		"direction": Vector2.RIGHT, "half_angle": 0.4}
	_check(LightField.contribution(torch, Vector2(100.0, 0.0)) == 1.0
			and LightField.contribution(torch, Vector2(-100.0, 0.0)) == 0.0
			and LightField.contribution(torch, Vector2(100.0, 100.0)) == 0.0,
		"a cone lights what is ahead of it, not behind or off to the side", "0.4 rad half-angle")
	_check(LightField.light_from([lamp, torch], Vector2(150.0, 0.0), 0.1) >= 0.99
			and is_equal_approx(LightField.light_from([lamp], Vector2(900.0, 900.0), 0.1), 0.1),
		"two lights: the brighter wins; out of every light, the ambient floor", "max, then ambient")


func _the_dark_cuts_what_lights_there_are() -> void:
	var dark := DarknessLayer.new()
	root.add_child(dark)
	var lamp := HeldLantern2D.new()
	root.add_child(lamp)
	lamp.global_position = Vector2(400.0, 300.0)
	var hidden_lamp := HeldLantern2D.new()
	root.add_child(hidden_lamp)
	hidden_lamp.visible = false
	await process_frame
	await process_frame
	var shown := dark.shown()
	var hole := dark.first_hole()
	_check(dark.layer < 5 and dark.layer > 0, "the dark sits over the world and under the HUD",
		"layer %d" % dark.layer)
	_check(shown == Vector2i(1, 0) and Vector2(hole.x, hole.y).distance_to(Vector2(400.0, 300.0)) < 1.0
			and is_equal_approx(hole.z, HeldLantern2D.RADII[PlayerHealth.FULL]),
		"it cuts one hole per light that shows, where the light is, its size",
		"%d hole(s) at (%.0f, %.0f) r %.0f" % [shown.x, hole.x, hole.y, hole.z])
	_check(is_equal_approx(LightField.light_at(self, lamp.global_position), 1.0)
			and LightField.light_at(self, lamp.global_position + Vector2(600.0, 0.0)) == 0.0,
		"and gameplay counts the same light: lit at the lantern, dark past its reach", "light_at")
	dark.queue_free()
	lamp.queue_free()
	hidden_lamp.queue_free()
	await process_frame


func _the_lantern_shrinks_with_the_flame() -> void:
	var health := PlayerHealth.new()
	root.add_child(health)
	health.invulnerable_seconds = 0.0
	var lamp := HeldLantern2D.new()
	lamp.health = health
	root.add_child(lamp)
	var radii: Array[float] = [lamp.radius()]
	for _blow in range(3):
		health.take_hit()
		if health.stage > PlayerHealth.GUTTERING:
			radii.append(lamp.radius())
	var low := INF
	var high := -INF
	for _frame in range(30):
		await physics_frame
		low = minf(low, lamp.radius())
		high = maxf(high, lamp.radius())
	_check(radii == [380.0, 290.0, 200.0], "each stage the flame drops, the light she sees by shrinks",
		"%s, then guttering" % [radii])
	_check(high - low > 10.0 and low >= 130.0 - 14.0 - 0.01 and high <= 130.0 + 14.0 + 0.01,
		"guttering, it will not hold still", "%.0f to %.0f px" % [low, high])
	lamp.queue_free()
	health.queue_free()
	await physics_frame


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func _check(ok: bool, what: String, detail: String) -> void:
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
