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
	await _a_level_that_is_dark()
	await _a_flashlight_and_a_fire_light_the_dark()
	await _a_sound_shows_where_it_came_from()
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


func _a_level_that_is_dark() -> void:
	var plain := await _open_level(null)
	_check(plain.get("darkness_layer") == null and plain.get("held_lantern") == null
			and plain.get("lantern_hud") == null,
		"a level that is not dark builds no dark, no lantern and no lantern chip", "Payyo as it is")
	plain.queue_free()
	await _frames(3)
	var dark_script := GDScript.new()
	dark_script.source_code = "extends \"res://scripts/game_level.gd\"\n" \
		+ "func _darkness() -> float:\n\treturn 0.88\n" \
		+ "func _has_player_health() -> bool:\n\treturn true\n"
	dark_script.reload()
	var level := await _open_level(dark_script)
	var layer := level.get("darkness_layer") as DarknessLayer
	var lamp := level.get("held_lantern") as HeldLantern2D
	var apo := level.get("player") as Node2D
	_check(layer != null and is_equal_approx(layer.darkness, 0.88) and lamp != null
			and lamp.player == apo and lamp.health == level.get("player_health"),
		"told it is dark, the level hangs the dark and hands her a lantern that is her health",
		"darkness %.2f" % (layer.darkness if layer != null else -1.0))
	if lamp != null and apo != null:
		await _frames(2)
		_check(lamp.global_position.distance_to(PlayerHurtbox2D.middle_of(apo)) < 20.0,
			"and it hangs at her side", "%.0f px from her middle" % lamp.global_position.distance_to(
				PlayerHurtbox2D.middle_of(apo)))
	var chip := level.get("lantern_hud") as LanternHud
	var health := level.get("player_health") as PlayerHealth
	if chip != null and health != null:
		chip.gutter(1.0)
		chip.lean(0.8)
		await _frames(2)
		var calm_red := chip.red_edge()
		health.take_hit()
		await _frames(2)
		_check(chip.is_inside_tree() and calm_red == 0.0 and chip.is_shaking() and chip.red_edge() > 0.0
				and chip.stage() == PlayerHealth.DIM,
			"the lantern chip on the ink plate shakes and edges red on a hit, and only then",
			"guttering and leaning: red %.2f; hit: red %.2f" % [calm_red, chip.red_edge()])
	else:
		_check(false, "the lantern chip on the ink plate shakes and edges red on a hit, and only then",
			"no chip")
	level.queue_free()
	await _frames(3)


## A lit flashlight lights the cone ahead of it and not behind; a burning checkpoint lights round it.
func _a_flashlight_and_a_fire_light_the_dark() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var registry := EntityRegistry.new()
	world.add_child(registry)
	registry.load_manifest()
	var apo := (load("res://creatures/wanderer.tscn") as PackedScene).instantiate() as Wanderer
	world.add_child(apo)
	apo.global_position = Vector2(600.0, 400.0)
	var torch := await _flashlight_in_hand(registry, apo)
	var dark_before := torch.light_hole().is_empty()
	torch.describe_use(apo)
	await _frames(2)
	var ahead := torch.global_transform * Vector2(150.0, 0.0)
	var behind := torch.global_transform * Vector2(-150.0, 0.0)
	_check(dark_before and LightField.light_at(self, ahead) > 0.9 and LightField.light_at(self, behind) == 0.0,
		"a flashlight, switched on, lights the cone ahead of it and not behind",
		"%.2f ahead, %.2f behind" % [LightField.light_at(self, ahead), LightField.light_at(self, behind)])
	var spare := registry.instantiate_entity("flashlight") as UtilityObject
	world.add_child(spare)
	await _frames(2)
	var beam_a := torch.get_node_or_null(^"LightCone") as PointLight2D
	var beam_b := spare.get_node_or_null(^"LightCone") as PointLight2D
	_check(beam_a != null and beam_b != null and beam_a.texture == beam_b.texture,
		"every flashlight shares one beam picture, built once", "same texture")
	var fire := CheckpointLantern2D.new()
	fire.lit = true
	world.add_child(fire)
	fire.global_position = Vector2(200.0, 400.0)
	var cold := CheckpointLantern2D.new()
	world.add_child(cold)
	cold.global_position = Vector2(1200.0, 400.0)
	await _frames(2)
	var heart: Vector2 = fire.light_hole().get("position", Vector2.INF)
	_check(cold.light_hole().is_empty() and LightField.light_at(self, heart + Vector2(60.0, 0.0)) > 0.9,
		"a burning checkpoint lights the dark round it; a cold one does not", "lit at 60 px")
	world.queue_free()
	await _frames(3)


## A sound off screen ripples on the edge toward it, fades in its time, and a silent one shows nothing.
func _a_sound_shows_where_it_came_from() -> void:
	var ripple := EdgeRipple.new()
	root.add_child(ripple)
	await process_frame
	var screen := root.get_visible_rect()
	var far_right := ripple.screen_point(Vector2(screen.size.x * 3.0, screen.size.y * 0.5))
	var on_screen := ripple.screen_point(Vector2(300.0, 200.0))
	_check(absf(far_right.x - (screen.size.x - EdgeRipple.INSET)) < 1.0
			and absf(far_right.y - screen.size.y * 0.5) < 1.0 and on_screen.is_equal_approx(Vector2(300.0, 200.0)),
		"a sound off screen shows on the edge toward it; one on screen, where it is",
		"edge at (%.0f, %.0f)" % [far_right.x, far_right.y])
	ripple.cue("tiktik", Vector2(screen.size.x * 3.0, 100.0), 0.6)
	ripple.cue("tiyanak", Vector2(100.0, 100.0), 0.0)
	var started := ripple.active()
	await create_timer(EdgeRipple.LIFE + 0.2).timeout
	_check(started == 1 and ripple.active() == 0 and ripple.layer > 3 and ripple.layer < 5,
		"its rings fade in their time, a silent sound shows none, and it sits over the dark",
		"%d shown, %d left after %.1f s, layer %d" % [started, ripple.active(), EdgeRipple.LIFE + 0.2, ripple.layer])
	ripple.queue_free()
	await process_frame


func _flashlight_in_hand(registry: EntityRegistry, apo: Node2D) -> UtilityObject:
	var tool := registry.instantiate_entity("flashlight") as UtilityObject
	apo.get_parent().add_child(tool)
	var entry := registry.get_entity("flashlight")
	var page := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	page.fill(Color.WHITE)
	tool.apply_item_data(DrawnItemData.from_prediction("flashlight", "Flashlight", page,
		[{"points": PackedVector2Array([Vector2(0, 0), Vector2(40, 0)]), "width": 6.0,
			"color": Color.BLACK}], 0.9, entry))
	tool.global_position = apo.global_position + Vector2(30.0, -40.0)
	await physics_frame
	tool.interact(apo)
	await _frames(3)
	return tool


func _open_level(script: GDScript) -> Node:
	var level := (load("res://game_level.tscn") as PackedScene).instantiate()
	if script != null:
		level.set_script(script)
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(40):
		await physics_frame
	call_group(DialogueBox.GROUP, &"hide_line")
	paused = false
	await _frames(4)
	return level


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func _check(ok: bool, what: String, detail: String) -> void:
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
