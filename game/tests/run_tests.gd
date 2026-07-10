extends SceneTree
## Dependency-free headless regression suite:
## godot --headless --path game --script res://tests/run_tests.gd

var failures: Array[String] = []
var world: Node2D
var registry: EntityRegistry


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = Node2D.new()
	world.name = "TestWorld"
	root.add_child(world)
	_add_floor()
	registry = EntityRegistry.new()
	world.add_child(registry)
	registry.load_manifest()

	_test_manifest_roles()
	_test_ink_accounting()
	_test_inventory()
	_test_canvas_clipping()
	_test_game_level_contract()
	_test_target_contracts()
	await _test_placement_collision()
	await _test_active_ragdolls()
	await _test_physics_morphs()
	await _test_utilities()
	world.queue_free()
	registry = null
	world = null
	await process_frame
	await process_frame

	if failures.is_empty():
		print("OBRA_HEADLESS_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("OBRA_HEADLESS_TESTS_FAILED=%d" % failures.size())
		quit(1)


func _test_manifest_roles() -> void:
	var living := 0
	var shapes := 0
	var utilities := 0
	for entity_id in [
		"fish", "frog", "spider", "bird", "humanoid", "cat", "dog",
		"rabbit", "butterfly", "snake", "circle", "square", "triangle",
		"axe", "ladder", "key", "umbrella", "flashlight", "sailboat"
	]:
		var entry := registry.get_entity(entity_id)
		_expect(not entry.is_empty(), "manifest missing %s" % entity_id)
		match String(entry.get("runtime_role", "")):
			"active_ragdoll_morph": living += 1
			"physics_morph": shapes += 1
			"utility": utilities += 1
	_expect(living == 10, "expected 10 living morphs, got %d" % living)
	_expect(shapes == 3, "expected 3 physics morphs, got %d" % shapes)
	_expect(utilities == 6, "expected 6 utilities, got %d" % utilities)


func _test_ink_accounting() -> void:
	var sparse := [{"points": PackedVector2Array([Vector2.ZERO, Vector2(512.0, 0.0)])}]
	var dense_points := PackedVector2Array()
	for index in range(65):
		dense_points.append(Vector2(float(index) * 8.0, 0.0))
	var dense := [{"points": dense_points}]
	var sparse_cost := InkManager.static_cost_for_strokes(sparse)
	var dense_cost := InkManager.static_cost_for_strokes(dense)
	_expect(is_equal_approx(sparse_cost, dense_cost), "ink cost changes with sample density")
	var manager := InkManager.new()
	manager.begin_level(12.0)
	_expect(manager.reserve_attempt(2.0), "could not reserve valid ink")
	_expect(is_equal_approx(manager.remaining(), 10.0), "ink reservation not reflected")
	manager.release_attempt()
	_expect(is_equal_approx(manager.remaining(), 12.0), "released ink was not refunded")
	manager.reserve_attempt(3.0)
	manager.commit_attempt()
	_expect(is_equal_approx(manager.remaining(), 9.0), "committed ink was refunded")
	manager.free()


func _test_inventory() -> void:
	var inventory := InventoryManager.new()
	inventory.capacity = 6
	world.add_child(inventory)
	inventory.begin_level()
	var ids: Array[int] = []
	for index in range(6):
		var item := DrawnItemData.new()
		item.entity_id = "key"
		ids.append(item.instance_id)
		_expect(inventory.add_item(item) == index, "inventory did not fill in slot order")
	_expect(inventory.is_full(), "six-slot inventory did not report full")
	_expect(inventory.add_item(DrawnItemData.new()) == -1, "inventory accepted a seventh item")
	var recovered := inventory.take_item(2)
	_expect(recovered != null and recovered.instance_id == ids[2], "inventory lost item identity")
	inventory.queue_free()


func _test_canvas_clipping() -> void:
	var canvas_script := load("res://scripts/drawing_canvas.gd")
	var canvas := Control.new()
	canvas.set_script(canvas_script)
	world.add_child(canvas)
	canvas.call("set_ink_budget", 0.1, Vector2(512.0, 512.0))
	canvas.call("_start_stroke", Vector2.ZERO)
	canvas.call("_append_point", Vector2(512.0, 0.0), true)
	var maximum := Vector2(512.0, 512.0).length() * 0.1
	_expect(float(canvas.call("get_drawn_length")) <= maximum + 0.01, "canvas exceeded exact ink limit")
	canvas.queue_free()


func _test_game_level_contract() -> void:
	var packed := load("res://game_level.tscn") as PackedScene
	_expect(packed != null, "game level scene did not load")
	if packed == null:
		return
	var level := packed.instantiate()
	for path in [
		"InkManager", "InventoryManager", "PlacementController",
		"EnvironmentBaseplate/GameplayPlane/EntityRoot",
		"EnvironmentBaseplate/GameplayPlane/WorldItemRoot",
		"CanvasLayer/InkBar", "CanvasLayer/InventoryHUD"
	]:
		_expect(level.get_node_or_null(path) != null, "game level missing %s" % path)
	level.free()


func _test_target_contracts() -> void:
	var axe_target: Node = load("res://scripts/destructible_2d.gd").new()
	axe_target.set("health", 50.0)
	world.add_child(axe_target)
	_expect(bool(axe_target.call("apply_tool_hit", "axe", 400.0, world)), "axe target rejected axe hit")
	_expect(bool(axe_target.get("is_destroyed")), "axe target did not apply impulse-scaled damage")
	axe_target.queue_free()

	var item := DrawnItemData.new()
	item.entity_id = "key"
	var lock: Node = load("res://scripts/lockable_2d.gd").new()
	lock.set("consume_key", true)
	world.add_child(lock)
	var result: Dictionary = lock.call("try_unlock", "drawn_key", item)
	_expect(bool(result.get("unlocked", false)), "lock rejected drawn key")
	_expect(bool(result.get("consumed", false)), "consuming lock omitted consumption result")
	lock.queue_free()

	var requirement := UtilityRequirement2D.new()
	requirement.required_utility = "flashlight"
	world.add_child(requirement)
	_expect(requirement.report_utility_used("flashlight", item), "utility requirement did not satisfy")
	_expect(not requirement.report_utility_used("flashlight", item), "utility requirement satisfied twice")
	requirement.queue_free()


func _test_placement_collision() -> void:
	var item := DrawnItemData.from_prediction("key", "Key", _blank_image(), _utility_fixture("key"), 0.4, registry.get_entity("key"))
	var utility := registry.instantiate_entity("key") as UtilityObject
	world.add_child(utility)
	utility.apply_item_data(item)
	utility.set_preview(true)
	var obstacle := StaticBody2D.new()
	obstacle.position = Vector2(760.0, 120.0)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(120.0, 120.0)
	collision.shape = shape
	obstacle.add_child(collision)
	world.add_child(obstacle)
	utility.global_position = obstacle.global_position
	var placement := PlacementController.new()
	world.add_child(placement)
	placement.set("_preview", utility)
	await physics_frame
	_expect(not bool(placement.call("_position_is_clear")), "placement accepted overlapping solid collision")
	utility.global_position = Vector2(1800.0, -500.0)
	await physics_frame
	_expect(bool(placement.call("_position_is_clear")), "placement rejected clear world position")
	placement.set("_preview", null)
	utility.queue_free()
	obstacle.queue_free()
	placement.queue_free()


func _test_active_ragdolls() -> void:
	for entity_id in ["fish", "frog", "spider", "bird", "humanoid", "cat", "dog", "rabbit", "butterfly", "snake"]:
		var instance := registry.instantiate_entity(entity_id) as Node2D
		_expect(instance != null, "could not instantiate %s" % entity_id)
		if instance == null:
			continue
		world.add_child(instance)
		instance.global_position = Vector2(300.0, 200.0)
		instance.call("apply_drawing", _blank_image(), _fixture_for(entity_id))
		var anchor := instance.call("get_physics_anchor") as ActiveRigBody2D
		_expect(anchor != null, "%s has no physics anchor" % entity_id)
		var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
		_expect(skin.get_rigid_bodies().size() <= 24, "%s exceeded body cap" % entity_id)
		_expect(skin.get_joint_count() <= 23, "%s exceeded joint cap" % entity_id)
		if entity_id in ["spider", "cat", "dog", "frog", "rabbit", "bird", "butterfly", "humanoid", "snake"]:
			_expect(skin.get_joint_count() > 0, "%s did not articulate fixture strokes" % entity_id)
		var expected_role: String = String({
			"spider": "leg", "cat": "leg", "dog": "leg", "frog": "leg",
			"rabbit": "leg", "bird": "wing", "butterfly": "wing",
			"humanoid": "arm", "fish": "tail", "snake": "chain"
		}.get(entity_id, ""))
		_expect(expected_role in skin.debug_segment_roles(), "%s did not assign expected %s role" % [entity_id, expected_role])
		var motion_state: String = String({
			"spider": "walk", "cat": "walk", "dog": "walk", "frog": "jump",
			"rabbit": "jump", "bird": "fly", "butterfly": "fly",
			"humanoid": "walk", "fish": "swim", "snake": "walk"
		}.get(entity_id, "walk"))
		skin.set_motion_state(motion_state, {"moving": true, "speed_ratio": 1.0, "direction": 1.0})
		skin._physics_process(0.1)
		if skin.get_joint_count() > 0:
			var motor_active := false
			for velocity in skin.debug_motor_velocities():
				motor_active = motor_active or absf(velocity) > 0.01
			_expect(motor_active, "%s gait did not drive joint motors" % entity_id)
		for _frame in range(60):
			await physics_frame
		if anchor != null:
			_expect(is_finite(anchor.global_position.x) and is_finite(anchor.global_position.y), "%s physics became non-finite" % entity_id)
			_expect(anchor.linear_velocity.length() <= anchor.max_linear_speed + 1.0, "%s exceeded velocity safety bound" % entity_id)
		for rig_body in skin.get_rigid_bodies():
			_expect(is_finite(rig_body.global_position.x) and is_finite(rig_body.global_position.y), "%s segment became non-finite" % entity_id)
		instance.queue_free()
		await process_frame


func _test_utilities() -> void:
	for entity_id in ["axe", "ladder", "key", "umbrella", "flashlight", "sailboat"]:
		var item := DrawnItemData.from_prediction(entity_id, entity_id.capitalize(), _blank_image(), _utility_fixture(entity_id), 0.5, registry.get_entity(entity_id))
		var utility := registry.instantiate_entity(entity_id) as UtilityObject
		_expect(utility != null, "could not instantiate utility %s" % entity_id)
		if utility == null:
			continue
		world.add_child(utility)
		utility.global_position = Vector2(600.0, 180.0)
		utility.apply_item_data(item)
		_expect(not utility.controllable, "%s retained player controls" % entity_id)
		_expect(utility.utility_behavior == entity_id, "%s behavior metadata missing" % entity_id)
		_expect(utility.find_children("*", "CollisionShape2D", true, false).size() > 0, "%s has no vector collision" % entity_id)
		if entity_id == "axe":
			var target: Node2D = load("res://scripts/destructible_2d.gd").new()
			target.set("health", 50.0)
			target.global_position = utility.global_position
			world.add_child(target)
			_add_target_body(target)
			await physics_frame
			utility.use_utility(utility)
			_expect(bool(target.get("is_destroyed")), "axe utility did not invoke destructible contract")
			target.queue_free()
		if entity_id == "key":
			var target: Node2D = load("res://scripts/lockable_2d.gd").new()
			target.global_position = utility.global_position
			world.add_child(target)
			_add_target_body(target)
			await physics_frame
			utility.use_utility(utility)
			_expect(not bool(target.get("is_locked")), "key utility did not invoke lock contract")
			target.queue_free()
		if entity_id in ["umbrella", "flashlight"]:
			_expect(utility.use_utility(utility), "%s could not toggle" % entity_id)
			_expect(bool(utility.serialize_utility_state().get("active", false)), "%s state did not persist" % entity_id)
		if entity_id == "sailboat":
			utility.set_meta("water_overlap_count", 1)
			utility.sleeping = false
			for _water_frame in range(3):
				await physics_frame
			_expect(bool(utility.call("_is_in_water")), "sailboat did not detect water medium")
			_expect(utility.gravity_scale < 0.5, "sailboat did not switch to buoyancy physics")
		utility.queue_free()
		await process_frame


func _test_physics_morphs() -> void:
	for entity_id in ["circle", "square", "triangle"]:
		var instance := registry.instantiate_entity(entity_id) as PhysicsShapeObject
		_expect(instance != null, "could not instantiate physics morph %s" % entity_id)
		if instance == null:
			continue
		world.add_child(instance)
		instance.global_position = Vector2(450.0, 120.0)
		instance.apply_drawing(_blank_image(), [_stroke(_closed_body())])
		_expect(instance.controllable, "%s is no longer controllable" % entity_id)
		_expect(instance.get_physics_anchor() == instance, "%s physics anchor is incorrect" % entity_id)
		_expect(instance.find_children("*", "CollisionShape2D", true, false).size() > 0, "%s has no drawing collision" % entity_id)
		var state := instance.capture_morph_state()
		instance.apply_morph_state(state)
		await physics_frame
		_expect(is_finite(instance.global_position.x), "%s physics became non-finite" % entity_id)
		instance.queue_free()
		await process_frame


func _fixture_for(entity_id: String) -> Array:
	if entity_id == "snake":
		var wave := PackedVector2Array()
		for index in range(18):
			wave.append(Vector2(90.0 + index * 19.0, 256.0 + sin(float(index) * 0.75) * 28.0))
		return [_stroke(wave)]
	var strokes: Array = [_stroke(_closed_body())]
	var limb_count := 8 if entity_id == "spider" else 4
	if entity_id == "fish":
		limb_count = 2
	for index in range(limb_count):
		var angle := TAU * float(index) / float(limb_count)
		var start := Vector2(256.0, 256.0) + Vector2(cos(angle) * 58.0, sin(angle) * 38.0)
		var mid := start + Vector2(cos(angle) * 42.0, sin(angle) * 42.0)
		var tip := mid + Vector2(cos(angle) * 34.0, sin(angle) * 34.0)
		strokes.append(_stroke(PackedVector2Array([start, mid, tip])))
	return strokes


func _utility_fixture(entity_id: String) -> Array:
	if entity_id == "ladder":
		return [
			_stroke(PackedVector2Array([Vector2(210, 100), Vector2(210, 410)])),
			_stroke(PackedVector2Array([Vector2(302, 100), Vector2(302, 410)])),
			_stroke(PackedVector2Array([Vector2(210, 180), Vector2(302, 180)])),
			_stroke(PackedVector2Array([Vector2(210, 260), Vector2(302, 260)])),
			_stroke(PackedVector2Array([Vector2(210, 340), Vector2(302, 340)]))
		]
	return [_stroke(PackedVector2Array([Vector2(130, 256), Vector2(382, 256)]))]


func _closed_body() -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(17):
		var angle := TAU * float(index) / 16.0
		points.append(Vector2(256.0 + cos(angle) * 62.0, 256.0 + sin(angle) * 42.0))
	return points


func _stroke(points: PackedVector2Array) -> Dictionary:
	return {"points": points, "width": 8.0, "color": Color.BLACK}


func _blank_image() -> Image:
	var image := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return image


func _add_floor() -> void:
	var floor := StaticBody2D.new()
	floor.position = Vector2(500.0, 420.0)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1000.0, 40.0)
	collision.shape = shape
	floor.add_child(collision)
	world.add_child(floor)


func _add_target_body(parent: Node2D) -> void:
	var body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28.0, 28.0)
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
