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
	await _the_ground_catches_moonlight()
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
	var by_stage := HeldLantern2D.RADII
	_check(radii == [by_stage[PlayerHealth.FULL], by_stage[PlayerHealth.DIM], by_stage[PlayerHealth.LOW]]
			and radii[0] > radii[1] and radii[1] > radii[2],
		"each stage the flame drops, the light she sees by shrinks", "%s, then guttering" % [radii])
	var gutter: float = by_stage[PlayerHealth.GUTTERING]
	var flicker := HeldLantern2D.GUTTER_FLICKER
	_check(high - low > 10.0 and low >= gutter - flicker - 0.01 and high <= gutter + flicker + 0.01,
		"guttering, it will not hold still", "%.0f to %.0f px" % [low, high])
	lamp.queue_free()
	health.queue_free()
	await physics_frame


func _a_level_that_is_dark() -> void:
	var plain := await _open_level(null)
	_check(plain.get("darkness_layer") == null and plain.get("held_lantern") == null
			and plain.get("lantern_hud") == null and Rect2(plain.call("_tutorial_target", "lantern")) == Rect2(),
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
	var lit_up := Rect2(level.call("_tutorial_target", "lantern"))
	_check(chip != null and lit_up.has_area() and lit_up.is_equal_approx(chip.get_global_rect()),
		"the lamp's lesson lights the lantern chip itself", "%s" % lit_up)
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
	if layer != null:
		await _a_ghost_is_seen_in_the_dark(level, layer)
		await _a_placed_drawing_is_seen_in_the_dark(level, layer)
	level.queue_free()
	await _frames(3)


## The ghost of a thing being placed is cut out of the dark, so she can see where it goes -- and
## only seen: gameplay's light never counts it, and it is gone when the placing is.
func _a_ghost_is_seen_in_the_dark(level: Node, layer: DarknessLayer) -> void:
	var apo := level.get("player") as Node2D
	var placement := level.get_node("PlacementController") as PlacementController
	var item := DrawnItemData.new()
	item.entity_id = "square"
	item.display_name = "Square"
	item.ink_committed = true
	item.entity_metadata = (level.get("registry") as Node).call("get_entity", "square")
	await _frames(2)
	var lights_before := layer.shown().x
	var gameplay_before := LightField.holes_in(self).size()
	if not placement.begin_placement(item, apo, -1):
		_check(false, "a placement ghost is seen through the dark", "placement would not start")
		return
	placement.update_target(apo.global_position + Vector2(260.0, -40.0))
	await _frames(2)
	await process_frame
	var reveal := placement.dark_reveal()
	var ghost := placement.get("_preview") as Node2D
	var cut := layer.shown().x
	var where: Vector2 = reveal.get("position", Vector2.INF)
	_check(cut == lights_before + 1 and LightField.holes_in(self).size() == gameplay_before
			and ghost != null and where.distance_to(ghost.global_position) < 80.0
			and float(reveal.get("radius", 0.0)) >= PlacementController.DARK_REVEAL_MARGIN,
		"a placement ghost is cut out of the dark where it is, and gameplay's light does not count it",
		"%d holes -> %d; gameplay %d -> %d; %.0f px from the ghost" % [lights_before, cut,
			gameplay_before, LightField.holes_in(self).size(), where.distance_to(ghost.global_position)
			if ghost != null else -1.0])
	var guide_layer := placement.guides.get_parent() as CanvasLayer if placement.guides != null else null
	var hud := level.get_node_or_null(^"CanvasLayer") as CanvasLayer
	_check(guide_layer != null and guide_layer.layer > layer.layer
			and hud != null and guide_layer.layer < hud.layer and guide_layer.follow_viewport_enabled
			and placement.guides.is_visible_in_tree(),
		"its reach ring and drop line are drawn over the dark, under the HUD, where the world is",
		"guides on layer %d, dark %d" % [guide_layer.layer if guide_layer != null else -1, layer.layer])
	placement.cancel_placement()
	await _frames(2)
	await process_frame
	_check(placement.dark_reveal().is_empty() and layer.shown().x == lights_before,
		"and once the placing is over the dark closes again", "%d holes" % layer.shown().x)


## Set down, what she drew is seen in the dark round itself -- and, again, only seen.
func _a_placed_drawing_is_seen_in_the_dark(level: Node, layer: DarknessLayer) -> void:
	var apo := level.get("player") as Node2D
	var placement := level.get_node("PlacementController") as PlacementController
	var item := DrawnItemData.new()
	item.entity_id = "square"
	item.display_name = "Square"
	item.ink_committed = true
	item.entity_metadata = (level.get("registry") as Node).call("get_entity", "square")
	await process_frame
	var lights_before := layer.shown().x
	var gameplay_before := LightField.holes_in(self).size()
	placement.begin_placement(item, apo, -1)
	var ghost := placement.get("_preview") as PhysicsShapeObject
	placement.set_process(false)
	placement.update_target(apo.global_position + Vector2(200.0, -30.0))
	var ghost_own := ghost.dark_reveal() if ghost != null else {"none": true}
	var placed := placement.confirm_placement()
	placement.set_process(true)
	await _frames(20)
	await process_frame
	var reveal := ghost.dark_reveal() if is_instance_valid(ghost) else {}
	var box := ghost.world_extent() if is_instance_valid(ghost) else Rect2()
	_check(placed and ghost_own.is_empty() and layer.shown().x == lights_before + 1
			and LightField.holes_in(self).size() == gameplay_before
			and float(reveal.get("radius", 0.0)) > maxf(box.size.x, box.size.y) * 0.5
			and box.has_point(reveal.get("position", Vector2.INF)),
		"set down, a drawing is seen in the dark round itself -- not as a ghost, and not as light",
		"placed %s; ghost's own %s; holes %d -> %d; gameplay %d -> %d; r %.0f over a %.0f x %.0f box" % [
			placed, ghost_own, lights_before, layer.shown().x, gameplay_before,
			LightField.holes_in(self).size(), float(reveal.get("radius", 0.0)), box.size.x, box.size.y])
	if is_instance_valid(ghost):
		ghost.queue_free()
	await _frames(2)


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
	# THE POINT OF DRAWING A LIGHT: it opens the dark wider than the lamp she carries. When her lamp
	# lit 380 px and a campfire 300, a drawn light was the smaller of the two.
	var campfire := registry.instantiate_entity("campfire") as UtilityObject
	world.add_child(campfire)
	await _frames(2)
	var glow := float(campfire.light_hole().get("radius", 0.0))
	_check(glow >= HeldLantern2D.RADII[PlayerHealth.FULL] * 1.25,
		"a campfire drawn lights well past her own lamp at its fullest",
		"campfire %.0f px, her lamp %.0f" % [glow, HeldLantern2D.RADII[PlayerHealth.FULL]])
	var spare_square := registry.instantiate_entity("square") as PhysicsShapeObject
	world.add_child(spare_square)
	await _frames(2)
	_check(campfire.dark_reveal().is_empty() and not spare_square.dark_reveal().is_empty(),
		"a drawn light is seen by its own light, and cuts no second hole for it",
		"campfire %s, square %s" % [campfire.dark_reveal(), spare_square.dark_reveal()])
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


## Dilim's ground: every top edge she can stand on is traced over the dark, a ledge's ends turned
## down -- and none of it is light.
func _the_ground_catches_moonlight() -> void:
	var ground := MakilingTerrain2D.new()
	ground.platforms = [Rect2(0.0, 600.0, 400.0, 200.0)] as Array[Rect2]
	ground.branches = [Rect2(500.0, 450.0, 200.0, 18.0)] as Array[Rect2]
	ground.position = Vector2(100.0, 0.0)
	root.add_child(ground)
	await process_frame
	var rims := ground.rim_segments()
	var layer := ground.get_node_or_null(^"Rims") as CanvasLayer
	var lip := MakilingTerrain2D.LIP
	var top: Array = rims[0] if not rims.is_empty() else [Vector2.INF, Vector2.INF]
	var branch: Array = rims[-1] if not rims.is_empty() else [Vector2.INF, Vector2.INF]
	_check(rims.size() == 4 and top[0] == Vector2(100.0, 600.0 - lip) and top[1] == Vector2(500.0, 600.0 - lip)
			and branch[0] == Vector2(600.0, 450.0 - lip) and layer != null
			and layer.layer > DarknessLayer.LAYER and layer.layer < 5 and layer.follow_viewport_enabled
			and LightField.holes_in(self).is_empty(),
		"Dilim's ground catches a thread of moonlight on every edge she can stand on, over the dark",
		"%d rims, top %s, branch %s, layer %d" % [rims.size(), top, branch, layer.layer if layer else -1])
	ground.queue_free()
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
