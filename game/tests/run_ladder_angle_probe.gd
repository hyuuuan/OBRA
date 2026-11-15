extends SceneTree
## Real W/S input must follow the placed ladder, including its angle and resized length.
## godot --headless --path game --script res://tests/run_ladder_angle_probe.gd

var world: Node2D
var registry: EntityRegistry
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = Node2D.new()
	root.add_child(world)
	registry = EntityRegistry.new()
	world.add_child(registry)
	registry.load_manifest()
	for angle in [0.0, 30.0, -30.0, 60.0, 150.0]:
		await _climb_at_angle(angle, 1.0)
	await _climb_at_angle(40.0, 2.0)
	await _mount_and_leave()
	await _climb_onto_ledge()
	world.free()
	await process_frame
	print("OBRA_LADDER_ANGLE_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(0 if failures == 0 else 1)


func _ladder(angle: float, size: float) -> UtilityObject:
	var ladder := registry.instantiate_entity("ladder") as UtilityObject
	world.add_child(ladder)
	var item := DrawnItemData.new()
	item.entity_id = "ladder"
	item.display_name = "Ladder"
	item.size_scale = size
	for x in [0.0, 90.0]:
		item.strokes.append({"points": PackedVector2Array([Vector2(x, 0), Vector2(x, 380)]),
			"width": 7.0, "color": Color.BLACK})
	for y in [60.0, 140.0, 220.0, 300.0, 360.0]:
		item.strokes.append({"points": PackedVector2Array([Vector2(0, y), Vector2(90, y)]),
			"width": 7.0, "color": Color.BLACK})
	ladder.apply_item_data(item)
	ladder.set_preview(true)
	ladder.position = Vector2(650.0, 500.0)
	ladder.rotation = deg_to_rad(angle)
	ladder.confirm_placement()
	ladder.freeze = true
	return ladder


func _hero(at: Vector2) -> Wanderer:
	var hero := (load("res://creatures/wanderer.tscn") as PackedScene).instantiate() as Wanderer
	world.add_child(hero)
	hero.set_world_bounds(Rect2(-2000, -2000, 4000, 4000))
	hero.position = at
	return hero


func _climb_at_angle(angle: float, size: float) -> void:
	var ladder := _ladder(angle, size)
	# The expected trajectory comes from the placement, independently of the controller.
	var down := Vector2.DOWN.rotated(deg_to_rad(angle))
	if down.y < 0.0:
		down = -down
	var across := Vector2(down.y, -down.x)
	var hero := _hero(ladder.position + down * 75.0 * size)
	var start := hero.position
	Input.action_press("move_up")
	await _frames(28)
	Input.action_release("move_up")
	var displacement := hero.position - start
	var label := "%.0f degrees at %.0f%%" % [angle, size * 100.0]
	_check(hero.is_using_ladder(ladder), label + ": W takes hold without E")
	_check(displacement.dot(-down) > 65.0 and absf(displacement.dot(across)) < 5.0,
		label + ": W moves along the ladder (%s)" % displacement)
	var above := hero.position
	Input.action_press("move_down")
	await _frames(20)
	Input.action_release("move_down")
	var descent := hero.position - above
	_check(descent.dot(down) > 45.0 and absf(descent.dot(across)) < 5.0,
		label + ": S follows the same ladder down (%s)" % descent)
	Input.action_press("move_up")
	var highest := 0.0
	for _frame in range(180):
		await physics_frame
		highest = maxf(highest, -(hero.position - ladder.position).dot(down))
	Input.action_release("move_up")
	# 244px of ladder, 40px to step off, then at most 19px of ballistic rise as gravity
	# catches the 190px/s climb velocity, plus a few pixels for the physics step.
	_check(highest < 122.0 * size + 65.0,
		label + ": holding W stays bounded by the ladder (peak %.1fpx)" % highest)
	hero.free()
	ladder.free()
	await process_frame


func _mount_and_leave() -> void:
	var ladder := _ladder(30.0, 1.0)
	var down := Vector2.DOWN.rotated(deg_to_rad(30.0))
	var across := Vector2(down.y, -down.x)
	var hero := _hero(ladder.position + down * 70.0 - across * 65.0)
	Input.action_press("move_up")
	await _frames(30)
	Input.action_release("move_up")
	_check(absf((hero.position - ladder.position).dot(across)) < 5.0,
		"mounting from beside the ladder brings the player onto its centerline")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/obra_ladder_angle.png")
	Input.action_press("move_right")
	await _frames(120)
	Input.action_release("move_right")
	_check(not hero.is_using_ladder(ladder), "walking sideways steps off the angled ladder")
	hero.apply_morph_state({"position": ladder.position, "velocity": Vector2.ZERO})
	Input.action_press("move_up")
	await _frames(4)
	Input.action_release("move_up")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	_check(not hero.is_using_ladder(ladder) and hero.velocity.y < -200.0,
		"jumping lets go of the angled ladder")
	hero.apply_morph_state({"position": ladder.position - down * 180.0, "velocity": Vector2.ZERO})
	_check(not ladder.climb_reaches(hero), "the HUD offers no climb beyond the ladder's top")
	hero.free()
	ladder.free()
	await process_frame


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func _climb_onto_ledge() -> void:
	var floor_body := _block(Vector2(650.0, 760.0), Vector2(1300.0, 80.0))
	var ledge := _block(Vector2(1000.0, 650.0), Vector2(530.0, 300.0))
	var ladder := _ladder(30.0, 1.0)
	ladder.position = Vector2(700.0, 595.0)
	var hero := _hero(Vector2(630.0, 720.0))
	Input.action_press("move_up")
	await _frames(110)
	Input.action_release("move_up")
	_check(hero.position.x > 750.0 and hero.position.y < 501.0,
		"W follows a leaning ladder past the lip of a solid ledge (%s)" % hero.position)
	Input.action_press("move_right")
	await _frames(45)
	Input.action_release("move_right")
	await _frames(60)
	_check(hero.is_on_floor() and absf(hero.position.y - 500.0) < 3.0,
		"the player can step off onto the ledge after an angled climb")
	hero.free()
	ladder.free()
	ledge.free()
	floor_body.free()
	await process_frame


func _block(at: Vector2, dimensions: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	body.position = at
	return body


func _check(ok: bool, label: String) -> void:
	print("  %s  %s" % ["OK" if ok else "FAIL", label])
	if not ok:
		failures += 1
