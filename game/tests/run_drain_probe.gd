extends SceneTree
## Mayon's ash: a drained thing goes white then blank and loses its collision at blank, comes back
## whole on a restore, holds still while the game is paused; the ash falls at its density and
## surges on a pulse; the tremor shakes whole pixels and stops dead.
##
##   godot --headless --path game --script res://tests/run_drain_probe.gd

const FLOOR_TOP := 400.0

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _a_drained_thing_wears_the_drain_and_so_do_its_parts()
	await _blank_takes_the_ground_from_under_her_and_restore_gives_it_back()
	await _the_ash_holds_still_while_the_game_is_paused()
	await _the_ash_falls_at_its_density_and_surges_on_a_pulse()
	await _a_tremor_shakes_whole_pixels_and_stops_dead()
	if failures == 0:
		print("OBRA_DRAIN_OK")
		quit(0)
	else:
		print("OBRA_DRAIN_FAILED=%d" % failures)
		quit(1)


func _prop() -> Node2D:
	var prop := Node2D.new()
	var body := Sprite2D.new()
	body.texture = load("res://assets/Level5/props/rock_big.png")
	prop.add_child(body)
	var top := Sprite2D.new()
	top.texture = load("res://assets/Level5/props/fern.png")
	prop.add_child(top)
	var drainable := Drainable.new()
	drainable.name = "Drainable"
	prop.add_child(drainable)
	root.add_child(prop)
	return prop


func _a_drained_thing_wears_the_drain_and_so_do_its_parts() -> void:
	var prop := _prop()
	await process_frame
	var drainable := prop.get_node("Drainable") as Drainable
	drainable.drain_to(0.5, 0.0)
	var material := prop.material as ShaderMaterial
	var parts := true
	for child in prop.get_children():
		if child is CanvasItem and not (child as CanvasItem).use_parent_material:
			parts = false
	var read := float(material.get_shader_parameter("drain")) if material != null else -1.0
	_check(material != null and material.shader == Drainable.SHADER and absf(read - 0.5) < 0.001
		and parts, "a drained thing wears the drain shader, and every part of it does",
		"drain %.2f, parts share it %s" % [read, parts])
	prop.queue_free()
	await process_frame


func _blank_takes_the_ground_from_under_her_and_restore_gives_it_back() -> void:
	var ground := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(800.0, 100.0)
	shape.shape = box
	shape.position = Vector2(400.0, FLOOR_TOP + 50.0)
	ground.add_child(shape)
	var drawn := Polygon2D.new()
	drawn.polygon = PackedVector2Array([Vector2(0, FLOOR_TOP), Vector2(800, FLOOR_TOP),
		Vector2(800, FLOOR_TOP + 100), Vector2(0, FLOOR_TOP + 100)])
	ground.add_child(drawn)
	var drainable := Drainable.new()
	ground.add_child(drainable)
	root.add_child(ground)
	var counts := {"blanked": 0, "restored": 0}
	drainable.blanked.connect(func() -> void: counts["blanked"] += 1)
	drainable.restored.connect(func() -> void: counts["restored"] += 1)
	var apo := (load("res://creatures/wanderer.tscn") as PackedScene).instantiate() as Wanderer
	apo.set_world_bounds(Rect2(-1000.0, -2000.0, 6000.0, 6000.0))
	root.add_child(apo)
	apo.global_position = Vector2(400.0, FLOOR_TOP - 120.0)
	await _frames(60)
	var stood := apo.is_on_floor() and absf(apo.global_position.y - FLOOR_TOP) < 2.0
	# White is not blank: at 0.9 it is paper, and still there to stand on.
	drainable.drain_to(0.9, 0.0)
	await _frames(20)
	var still_stood := apo.is_on_floor() and absf(apo.global_position.y - FLOOR_TOP) < 2.0
	drainable.drain_to(1.0, 0.0)
	await _frames(40)
	var fell := apo.global_position.y > FLOOR_TOP + 60.0
	_check(stood and still_stood and fell and counts["blanked"] == 1 and drainable.is_blank(),
		"white is still ground; blank is not, and she falls through it",
		"stood %s, stood at white %s, fell at blank %s (y %.0f), blanked %d" % [stood, still_stood,
			fell, apo.global_position.y, counts["blanked"]])
	drainable.restore()
	apo.global_position = Vector2(400.0, FLOOR_TOP - 120.0)
	apo.velocity = Vector2.ZERO
	await _frames(60)
	var back := apo.is_on_floor() and absf(apo.global_position.y - FLOOR_TOP) < 2.0
	_check(back and counts["restored"] == 1 and ground.collision_layer == 1 and drainable.drain == 0.0,
		"a restore brings it back whole, solid again",
		"stands again %s, layer %d, restored %d" % [back, ground.collision_layer, counts["restored"]])
	apo.queue_free()
	ground.queue_free()
	await process_frame


func _the_ash_holds_still_while_the_game_is_paused() -> void:
	# A line of dialogue pauses the tree; the ash must not keep working behind it.
	var prop := _prop()
	await process_frame
	var drainable := prop.get_node("Drainable") as Drainable
	drainable.drain_to(1.0, 1.0)
	await create_timer(0.25).timeout
	paused = true
	var at_pause := drainable.drain
	await create_timer(0.5).timeout
	var while_paused := drainable.drain
	paused = false
	await create_timer(1.2).timeout
	_check(at_pause > 0.05 and absf(while_paused - at_pause) < 0.001 and drainable.is_blank(),
		"the drain holds while the game is paused, then finishes",
		"%.2f at the pause, %.2f half a second later, blank after %s" % [at_pause, while_paused,
			drainable.is_blank()])
	prop.queue_free()
	await process_frame


func _the_ash_falls_at_its_density_and_surges_on_a_pulse() -> void:
	var camera := Camera2D.new()
	root.add_child(camera)
	camera.make_current()
	var ash := AshFall2D.new()
	ash.density = 0.5
	camera.add_child(ash)
	await _frames(5)
	var half := ash.falling()
	ash.density = 0.0
	var none := ash.falling()
	ash.density = 0.6
	await create_timer(1.5).timeout
	var view := ash.view_size()
	var strays := 0
	var below_top := 0
	for at in ash.flake_positions():
		if at.x < -AshFall2D.MARGIN * 1.5 or at.x > view.x + AshFall2D.MARGIN * 1.5 \
				or at.y < -AshFall2D.MARGIN * 1.5 or at.y > view.y + AshFall2D.MARGIN * 1.5:
			strays += 1
		if at.y > 0.0:
			below_top += 1
	var before := ash.falling()
	ash.pulse(1.0)
	var surged := ash.falling()
	await create_timer(1.2).timeout
	var settled := ash.falling()
	_check(half == AshFall2D.FLAKES / 2 and none == 0 and strays == 0 and below_top > 0
		and surged > before and settled == before,
		"the ash falls at its density, stays in view, and surges on a pulse",
		"%d at half, %d at none, %d strays, %d -> %d on a pulse -> %d after" % [half, none, strays,
			before, surged, settled])
	camera.queue_free()
	await process_frame


func _a_tremor_shakes_whole_pixels_and_stops_dead() -> void:
	var camera := Camera2D.new()
	root.add_child(camera)
	camera.make_current()
	var tremor := ScreenTremor.new()
	tremor.every = 0.0
	root.add_child(tremor)
	var heard: Array[float] = []
	tremor.trembled.connect(func(strength: float) -> void: heard.append(strength))
	tremor.tremble(1.0)
	var moved := false
	var whole := true
	for _frame in range(12):
		await process_frame
		if camera.offset != Vector2.ZERO:
			moved = true
		if camera.offset != camera.offset.round():
			whole = false
	await create_timer(tremor.length + 0.2).timeout
	var still := camera.offset == Vector2.ZERO
	_check(moved and whole and still and heard.size() == 1,
		"a tremor shakes the view in whole pixels, says so, and stops dead",
		"moved %s, whole %s, still after %s, heard %d" % [moved, whole, still, heard.size()])
	# On its own, every so often.
	tremor.every = 0.4
	heard.clear()
	await create_timer(1.0).timeout
	_check(heard.size() == 2, "it rumbles on its own every few seconds", "%d in 1.0 s at every 0.4" % heard.size())
	tremor.queue_free()
	camera.queue_free()
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
