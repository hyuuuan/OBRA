extends SceneTree
## Dependency-free headless regression suite:
## godot --headless --path game --script res://tests/run_tests.gd

const SpiderRigAnalyzer = preload("res://scripts/spider_rig_analyzer.gd")
const SpiderReferenceFixtures = preload("res://tests/spider_reference_fixtures.gd")

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
	await _test_level_framework()
	await _test_banaue_environment()
	_test_camera_non_finite_guard()
	_test_target_contracts()
	await _test_placement_collision()
	_test_anatomy_inference()
	await _test_spider_stance_controller()
	await _test_active_ragdolls()
	await _test_archetype_coverage()
	await _test_idle_stability()
	await _test_messy_fixtures()
	await _test_ink_integrity()
	await _test_grazing_stroke_not_split()
	await _test_limb_angle_discipline()
	await _test_stick_figure_anatomy()
	await _test_compound_fallback_recovery()
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
	for entity_id in registry.get_entity_ids():
		var entry := registry.get_entity(entity_id)
		_expect(not entry.is_empty(), "manifest missing %s" % entity_id)
		match String(entry.get("runtime_role", "")):
			"active_ragdoll_morph": living += 1
			"physics_morph": shapes += 1
			"utility": utilities += 1
	_expect(living == 20, "expected 20 living morphs, got %d" % living)
	_expect(shapes == 3, "expected 3 physics morphs, got %d" % shapes)
	_expect(utilities == 27, "expected 27 utilities, got %d" % utilities)


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
	manager.reserve_attempt(1.0)
	var hidden_panel := DrawPanel.new()
	hidden_panel.ink_manager = manager
	hidden_panel.call("_on_stroke_cost_changed", 0.0)
	_expect(is_equal_approx(manager.reserved, 1.0), "hidden canvas clear erased a pending utility reservation")
	hidden_panel.free()
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
		"CanvasLayer/InkBar", "CanvasLayer/InventoryHUD", "PauseMenu"
	]:
		_expect(level.get_node_or_null(path) != null, "game level missing %s" % path)
	level.free()


func _test_level_framework() -> void:
	var level_manager := root.get_node_or_null("LevelManager")
	_expect(level_manager != null, "LevelManager autoload is unavailable")
	if level_manager == null:
		return
	var levels: Array = level_manager.call("get_levels")
	_expect(levels.size() == 5, "level catalog must contain exactly five levels")
	var unlocked_count := 0
	for index in range(levels.size()):
		var entry: Dictionary = levels[index] as Dictionary
		_expect(int(entry.get("number", 0)) == index + 1, "level catalog order is not stable")
		if bool(entry.get("unlocked", false)):
			unlocked_count += 1
	_expect(unlocked_count == 1 and bool(level_manager.call("is_unlocked", "level_1")), "only Level 1 should be unlocked")
	_expect(not bool(level_manager.call("open_level", "level_2")), "locked Level 2 initiated a transition")
	_expect(not bool(level_manager.call("open_level", "missing")), "invalid level initiated a transition")

	var menu_scene := load("res://ui/main_menu.tscn") as PackedScene
	_expect(menu_scene != null, "main menu scene did not load")
	if menu_scene == null:
		return
	var menu := menu_scene.instantiate()
	root.add_child(menu)
	await process_frame
	_expect(not bool(menu.call("is_selector_open")), "menu did not start in Play state")
	menu.call("_show_selector")
	await create_timer(0.7).timeout
	_expect(bool(menu.call("is_selector_open")), "Play did not expand into the level selector")
	var cards := menu.get_node("MenuLayer/MenuRoot/MorphPanel/Selector").get_children()
	var disabled_cards := 0
	for card in cards:
		if card is Button and (card as Button).disabled:
			disabled_cards += 1
	_expect(disabled_cards == 4, "selector does not expose exactly four locked cards")
	menu.call("_hide_selector")
	await create_timer(0.5).timeout
	_expect(not bool(menu.call("is_selector_open")), "selector did not collapse back into Play")
	menu.queue_free()
	await process_frame


func _test_banaue_environment() -> void:
	var environment_scene := load("res://levels/level_1/level_1_environment.tscn") as PackedScene
	_expect(environment_scene != null, "Banaue environment scene did not load")
	if environment_scene == null:
		return
	var environment := environment_scene.instantiate() as Node2D
	world.add_child(environment)
	await process_frame
	var bounds: Rect2 = environment.get("world_bounds")
	_expect(bounds.size == Vector2(3760.0, 1200.0), "Banaue world bounds changed unexpectedly")
	var spawn := environment.get_node("GameplayPlane/SpawnPoint") as Marker2D
	_expect(spawn.position == Vector2(260.0, 500.0), "Banaue spawn is not on the opening terrace")

	var terrace_count := 0
	for node in get_nodes_in_group("terrace_ground"):
		if environment.is_ancestor_of(node):
			terrace_count += 1
	_expect(terrace_count == 12, "Banaue terrain does not contain the expected terrace segments")
	var water_count := 0
	for node in get_nodes_in_group("water_medium"):
		if environment.is_ancestor_of(node):
			water_count += 1
	_expect(water_count == 2, "Banaue must contain exactly two physical paddies")

	var camera_delta := Vector2(100.0, 0.0)
	var far_layer := environment.get_node("FarMountainLayer") as DepthLayer2D
	var green_layer := environment.get_node("GreenMountainLayer") as DepthLayer2D
	var near_layer := environment.get_node("NearSceneryLayer") as DepthLayer2D
	for layer in [far_layer, green_layer, near_layer]:
		layer.set_camera_origin(Vector2.ZERO)
		layer.update_for_camera(camera_delta)
	var far_screen_motion := absf(camera_delta.x - far_layer.position.x)
	var green_screen_motion := absf(camera_delta.x - green_layer.position.x)
	var near_screen_motion := absf(camera_delta.x - near_layer.position.x)
	_expect(far_screen_motion < green_screen_motion and green_screen_motion < near_screen_motion, "Banaue parallax depth ordering is reversed")

	var probe := RigidBody2D.new()
	var lower_paddy := environment.get_node("GameplayPlane/WaterAreas/LowerPaddy") as WaterArea2D
	lower_paddy.call("_on_body_entered", probe)
	_expect(probe.has_meta("water_area") and int(probe.get_meta("water_overlap_count", 0)) == 1, "paddy did not apply water metadata")
	lower_paddy.call("_on_body_exited", probe)
	_expect(not probe.has_meta("water_area") and int(probe.get_meta("water_overlap_count", 0)) == 0, "paddy did not clear water metadata")
	probe.free()
	environment.queue_free()
	await process_frame


func _test_camera_non_finite_guard() -> void:
	var camera := WorldCameraController.new()
	var bad_target := Node2D.new()
	world.add_child(camera)
	world.add_child(bad_target)
	camera.set_target(bad_target)
	bad_target.global_position = Vector2(NAN, INF)
	var desired: Vector2 = camera.call("_clamped_target_position")
	_expect(is_finite(desired.x) and is_finite(desired.y), "camera accepted a non-finite physics target")
	camera.queue_free()
	bad_target.queue_free()


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
	for entity_id in _living_entity_ids():
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
		var rig_type := String(registry.get_entity(entity_id).get("rig_type", ""))
		if entity_id == "spider":
			_expect(skin.get_joint_count() >= 12, "spider legs regressed to single rigid segments")
		else:
			_expect(skin.get_joint_count() > 0, "%s did not articulate fixture strokes" % entity_id)
		var expected_roles := _expected_roles_for_rig(rig_type)
		if not expected_roles.is_empty():
			var role_found := false
			for role_name in expected_roles:
				role_found = role_found or role_name in skin.debug_segment_roles()
			_expect(role_found, "%s did not assign any expected role %s (got %s)" % [entity_id, str(expected_roles), str(skin.debug_segment_roles())])
		var motion_state: String = _gait_for_rig(rig_type)
		var motion_params := {"moving": true, "speed_ratio": 1.0, "direction": 1.0}
		# Keep the fixture in its species gait; the normal controller would read
		# zero headless input and replace this state with idle every frame.
		instance.set_physics_process(false)
		skin.set_motion_state(motion_state, motion_params)
		skin._physics_process(0.1)
		if skin.get_joint_count() > 0 and entity_id != "spider":
			var muscle_active := false
			for torque in skin.debug_drive_torques():
				muscle_active = muscle_active or absf(torque) > 0.01
			_expect(muscle_active, "%s gait did not drive bounded joint muscles" % entity_id)
		var stress_frames := 120
		var maximum_joint_error := 0.0
		var maximum_body_distance := 0.0
		for frame in range(stress_frames):
			skin.set_motion_state(motion_state, motion_params)
			if entity_id != "spider" and frame % 90 == 30 and anchor != null:
				anchor.apply_central_impulse(Vector2(55.0, -35.0) * anchor.mass)
			await physics_frame
			maximum_joint_error = maxf(maximum_joint_error, skin.debug_max_joint_error())
			maximum_body_distance = maxf(maximum_body_distance, skin.debug_max_body_distance())
		if anchor != null:
			_expect(is_finite(anchor.global_position.x) and is_finite(anchor.global_position.y), "%s physics became non-finite" % entity_id)
			_expect(anchor.linear_velocity.length() <= anchor.max_linear_speed + 1.0, "%s exceeded velocity safety bound" % entity_id)
			_expect(Rect2(-180.0, -700.0, 4120.0, 1560.0).has_point(anchor.global_position), "%s escaped the playable world" % entity_id)
			var camera_target := instance.call("get_camera_target") as Node2D
			_expect(camera_target != anchor, "%s camera still follows the raw rigidbody" % entity_id)
			_expect(camera_target != null and is_finite(camera_target.global_position.x) and is_finite(camera_target.global_position.y), "%s camera target became invalid" % entity_id)
		_expect(maximum_joint_error <= 22.5, "%s joint separated by %.2f px" % [entity_id, maximum_joint_error])
		_expect(maximum_body_distance <= maxf(125.0, skin.get_stroke_bounds().size.length() * 2.25), "%s rig scattered to %.2f px" % [entity_id, maximum_body_distance])
		_expect(skin.debug_recovery_count() <= 1, "%s needed repeated automatic recovery (%d)" % [entity_id, skin.debug_recovery_count()])
		for rig_body in skin.get_rigid_bodies():
			_expect(is_finite(rig_body.global_position.x) and is_finite(rig_body.global_position.y), "%s segment became non-finite" % entity_id)
		instance.queue_free()
		await process_frame


func _test_anatomy_inference() -> void:
	var reference_signature: Array[String] = []
	var reference_center := Vector2.ZERO
	var reference_bounds := Rect2()
	var reference_support_height := 0.0
	for fixture_value in SpiderReferenceFixtures.variants():
		var fixture: Dictionary = fixture_value
		var fixture_name := String(fixture.get("name", "unnamed"))
		var anatomy: Dictionary = SpiderRigAnalyzer.analyze(fixture.get("strokes", []))
		_expect(bool(anatomy.get("valid", false)), "spider analyzer rejected %s fixture: %s" % [fixture_name, anatomy.get("reason", "")])
		for field in ["torso_paths", "torso_bounds", "torso_center", "support_height", "legs"]:
			_expect(anatomy.has(field), "spider anatomy '%s' omitted %s" % [fixture_name, field])
		var torso_bounds: Rect2 = anatomy.get("torso_bounds", Rect2())
		var torso_center: Vector2 = anatomy.get("torso_center", Vector2.ZERO)
		var support_height := float(anatomy.get("support_height", 0.0))
		var has_open_torso_path := false
		for torso_path_value in anatomy.get("torso_paths", []):
			var torso_path: PackedVector2Array = torso_path_value
			if torso_path.size() >= 2 and torso_path[0].distance_to(torso_path[-1]) > 8.0:
				has_open_torso_path = true
		_expect(torso_bounds.size.x > torso_bounds.size.y * 1.5, "spider '%s' did not infer the open horizontal hub as torso" % fixture_name)
		_expect(has_open_torso_path, "spider '%s' did not preserve its open torso ink" % fixture_name)
		_expect(torso_bounds.grow(2.0).has_point(torso_center), "spider '%s' torso center lies outside its core" % fixture_name)
		_expect(support_height > 1.0, "spider '%s' has no sole-based support height" % fixture_name)

		var legs: Array = anatomy.get("legs", [])
		_expect(legs.size() == 6, "spider '%s' inferred %d legs instead of six" % [fixture_name, legs.size()])
		var side_counts := {-1: 0, 1: 0}
		var side_ranks := {-1: {}, 1: {}}
		var phase_by_leg: Dictionary = {}
		var support_candidates := 0
		var signature: Array[String] = []
		for leg_value in legs:
			var leg: Dictionary = leg_value
			for field in ["path", "root", "sole", "side", "side_rank", "phase_group", "support_candidate", "bend_index"]:
				_expect(leg.has(field), "spider '%s' leg omitted %s" % [fixture_name, field])
			var path: PackedVector2Array = leg.get("path", PackedVector2Array())
			var side := int(leg.get("side", 0))
			var side_rank := int(leg.get("side_rank", -1))
			var phase_group := int(leg.get("phase_group", -1))
			var bend_index := int(leg.get("bend_index", -1))
			_expect(side in [-1, 1], "spider '%s' emitted an invalid leg side" % fixture_name)
			_expect(phase_group in [0, 1], "spider '%s' emitted an invalid gait phase" % fixture_name)
			_expect(path.size() >= 3 and bend_index > 0 and bend_index < path.size() - 1, "spider '%s' leg has no usable drawn bend" % fixture_name)
			if side in [-1, 1]:
				side_counts[side] = int(side_counts[side]) + 1
				var ranks: Dictionary = side_ranks[side]
				ranks[side_rank] = true
				phase_by_leg["%d:%d" % [side, side_rank]] = phase_group
			if bool(leg.get("support_candidate", false)):
				support_candidates += 1
			signature.append("%d:%d:%d:%d" % [side, side_rank, phase_group, int(bool(leg.get("support_candidate", false)))])
		signature.sort()
		_expect(int(side_counts[-1]) == 3 and int(side_counts[1]) == 3, "spider '%s' did not infer three legs per side" % fixture_name)
		_expect((side_ranks[-1] as Dictionary).size() == 3 and (side_ranks[1] as Dictionary).size() == 3, "spider '%s' side ranks are not unique" % fixture_name)
		_expect(support_candidates == 4, "spider '%s' identified %d support candidates instead of four" % [fixture_name, support_candidates])
		for rank in range(3):
			_expect(int(phase_by_leg.get("-1:%d" % rank, -1)) != int(phase_by_leg.get("1:%d" % rank, -1)), "spider '%s' paired same-rank legs into one gait phase" % fixture_name)
		if phase_by_leg.size() == 6:
			_expect(int(phase_by_leg["-1:0"]) != int(phase_by_leg["-1:1"]) and int(phase_by_leg["-1:1"]) != int(phase_by_leg["-1:2"]), "spider '%s' left gait phases do not alternate" % fixture_name)
			_expect(int(phase_by_leg["1:0"]) != int(phase_by_leg["1:1"]) and int(phase_by_leg["1:1"]) != int(phase_by_leg["1:2"]), "spider '%s' right gait phases do not alternate" % fixture_name)
		if reference_signature.is_empty():
			reference_signature = signature
			reference_center = torso_center
			reference_bounds = torso_bounds
			reference_support_height = support_height
		else:
			_expect(signature == reference_signature, "spider anatomy changed with stroke ownership/order for '%s'" % fixture_name)
			_expect(torso_center.distance_to(reference_center) <= 5.0, "spider torso center changed for '%s'" % fixture_name)
			_expect(absf(torso_bounds.size.x - reference_bounds.size.x) <= 8.0 and absf(torso_bounds.size.y - reference_bounds.size.y) <= 8.0, "spider torso bounds changed for '%s'" % fixture_name)
			_expect(absf(support_height - reference_support_height) <= 8.0, "spider support height changed for '%s'" % fixture_name)
	for expected_leg_count in [4, 5, 7, 8]:
		var variable_anatomy := SpiderRigAnalyzer.analyze(SpiderReferenceFixtures.variable_leg_count(expected_leg_count))
		var variable_legs: Array = variable_anatomy.get("legs", [])
		_expect(bool(variable_anatomy.get("valid", false)), "spider analyzer rejected %d-leg topology: %s" % [expected_leg_count, variable_anatomy.get("reason", "")])
		_expect(variable_legs.size() == expected_leg_count, "spider analyzer inferred %d/%d variable legs" % [variable_legs.size(), expected_leg_count])
		var supported_phases := {0: false, 1: false}
		for leg_value in variable_legs:
			var leg := leg_value as Dictionary
			if bool(leg.get("support_candidate", false)):
				supported_phases[int(leg.get("phase_group", -1))] = true
		_expect(bool(supported_phases.get(0, false)) and bool(supported_phases.get(1, false)), "%d-leg spider cannot hand support across both gait phases" % expected_leg_count)
	var split_anatomy := SpiderRigAnalyzer.analyze(SpiderReferenceFixtures.split_leg_segments())
	_expect(bool(split_anatomy.get("valid", false)) and (split_anatomy.get("legs", []) as Array).size() == 6, "split-stroke spider legs lost topology")
	for leg_value in split_anatomy.get("legs", []):
		var leg := leg_value as Dictionary
		_expect((leg.get("ink_paths", []) as Array).size() >= 2, "split-stroke leg lost per-source ink ownership")
	var straight_anatomy := SpiderRigAnalyzer.analyze(SpiderReferenceFixtures.straight_leg_segments())
	var straight_legs: Array = straight_anatomy.get("legs", [])
	_expect(bool(straight_anatomy.get("valid", false)) and straight_legs.size() == 6, "straight two-point legs were rejected as spider anatomy")
	for leg_value in straight_legs:
		var leg := leg_value as Dictionary
		var path := PackedVector2Array(leg.get("path", PackedVector2Array()))
		var bend_index := int(leg.get("bend_index", -1))
		_expect(path.size() >= 3 and bend_index > 0 and bend_index < path.size() - 1, "straight leg received no midpoint articulation")
		if path.size() >= 3 and bend_index > 0 and bend_index < path.size() - 1:
			var arc_before := _test_path_length(path.slice(0, bend_index + 1))
			var arc_after := _test_path_length(path.slice(bend_index, path.size()))
			_expect(absf(arc_before - arc_after) <= 0.5, "straight leg articulation is not at its arc-length midpoint")
	var self_cross_anatomy := SpiderRigAnalyzer.analyze(SpiderReferenceFixtures.self_crossing_hub_leg())
	var self_cross_legs: Array = self_cross_anatomy.get("legs", [])
	_expect(bool(self_cross_anatomy.get("valid", false)) and self_cross_legs.size() == 6, "same-stroke hub intersection lost spider anatomy")
	var recovered_self_cross_leg := false
	for leg_value in self_cross_legs:
		var leg := leg_value as Dictionary
		var sole: Vector2 = leg.get("sole", Vector2.ZERO)
		if sole.distance_to(Vector2(154.0, 266.0)) <= 3.0:
			var root: Vector2 = leg.get("root", Vector2.ZERO)
			recovered_self_cross_leg = root.distance_to(Vector2(236.0, 256.0)) <= 8.0
			break
	_expect(recovered_self_cross_leg, "same-stroke self-intersection did not become the drawn leg root")

	var spider := registry.instantiate_entity("spider") as Node2D
	world.add_child(spider)
	spider.call("apply_drawing", _blank_image(), SpiderReferenceFixtures.separate_legs())
	var spider_skin := spider.get_node("DrawingSkin") as RuntimeRig2D
	var spider_total_mass := 0.0
	var terminal_collision_bodies := 0
	for rig_body in spider_skin.get_rigid_bodies():
		spider_total_mass += rig_body.mass
		if rig_body != spider_skin.get_primary_body():
			_expect(spider_skin.debug_primary_mass() > rig_body.mass, "spider leg outweighed its torso")
		if String(rig_body.name).ends_with("_1"):
			var has_terminal_collision := false
			for child in rig_body.get_children():
				if child is CollisionShape2D and (child as CollisionShape2D).shape != null:
					has_terminal_collision = true
					break
			_expect(has_terminal_collision, "%s has no physical distal-foot collision" % rig_body.name)
			if has_terminal_collision:
				terminal_collision_bodies += 1
	_expect(terminal_collision_bodies == 6, "spider did not build six colliding terminal feet")
	_expect(spider_skin.debug_primary_mass() >= spider_total_mass * 0.4, "spider torso owns less than 40%% of total rig mass")
	var initial_spider_body_count := spider_skin.get_rigid_bodies().size()
	var base_torso_mass := spider_skin.debug_primary_mass()
	var overdrawn_torso := SpiderReferenceFixtures.separate_legs()
	overdrawn_torso.append(_stroke(PackedVector2Array([
		Vector2(226.0, 247.0), Vector2(296.0, 247.0),
		Vector2(226.0, 252.0), Vector2(296.0, 252.0)
	])))
	spider.call("apply_drawing", _blank_image(), overdrawn_torso)
	_expect(spider_skin.debug_primary_mass() > base_torso_mass + 0.1, "spider torso mass ignored additional core ink")
	spider.call("apply_drawing", _blank_image(), SpiderReferenceFixtures.paired_through_body())
	_expect(spider_skin.get_rigid_bodies().size() == initial_spider_body_count, "rebuilding spider retained stale physics bodies")
	_expect(int(spider_skin.debug_spider_snapshot().get("leg_count", 0)) == 6, "rebuilding spider retained stale foot metadata")
	spider.free()
	var malformed_strokes := [_stroke(PackedVector2Array([Vector2(180.0, 250.0), Vector2(332.0, 260.0)]))]
	var malformed_anatomy: Dictionary = SpiderRigAnalyzer.analyze(malformed_strokes)
	_expect(not bool(malformed_anatomy.get("valid", true)), "spider analyzer fabricated anatomy from a lone stroke")
	var fallback_spider := registry.instantiate_entity("spider") as Node2D
	world.add_child(fallback_spider)
	fallback_spider.call("apply_drawing", _blank_image(), malformed_strokes)
	var fallback_skin := fallback_spider.get_node("DrawingSkin") as RuntimeRig2D
	_expect(fallback_skin.skin_mode() == "vector", "malformed spider discarded the player's vector ink")
	_expect(fallback_skin.get_rigid_bodies().size() == 1 and fallback_skin.get_joint_count() == 0, "malformed spider fabricated limbs instead of a safe compound body")
	fallback_spider.free()

	var torso := PackedVector2Array([
		Vector2(228, 160), Vector2(284, 160), Vector2(284, 330),
		Vector2(228, 330), Vector2(228, 160)
	])
	var human_strokes: Array = [
		_stroke(PackedVector2Array([Vector2(228, 215), Vector2(190, 245), Vector2(166, 286)])),
		_stroke(PackedVector2Array([Vector2(284, 215), Vector2(322, 245), Vector2(346, 286)])),
		_stroke(PackedVector2Array([Vector2(242, 328), Vector2(230, 382), Vector2(224, 438)])),
		_stroke(PackedVector2Array([Vector2(270, 328), Vector2(282, 382), Vector2(288, 438)])),
		_stroke(torso)
	]
	var human := registry.instantiate_entity("monkey") as Node2D
	world.add_child(human)
	human.call("apply_drawing", _blank_image(), human_strokes)
	var human_skin := human.get_node("DrawingSkin") as RuntimeRig2D
	var arms := 0
	var legs := 0
	for limb in human_skin.debug_limb_layout():
		if String(limb.get("role", "")) == "arm":
			arms += 1
		elif String(limb.get("role", "")) == "leg":
			legs += 1
	_expect(arms == 2 and legs == 2, "humanoid did not infer two shoulder arms and two hip legs")
	human.free()


func _test_spider_stance_controller() -> void:
	var wall := _add_spider_test_wall()
	var spider := registry.instantiate_entity("spider") as Node2D
	_expect(spider != null, "could not instantiate spider for stance regression")
	if spider == null:
		wall.queue_free()
		return
	world.add_child(spider)
	spider.global_position = Vector2(300.0, 360.0)
	spider.call("set_world_bounds", Rect2(0.0, -520.0, 1000.0, 1200.0))
	spider.call("apply_drawing", _blank_image(), SpiderReferenceFixtures.separate_legs())
	var skin := spider.get_node("DrawingSkin") as RuntimeRig2D
	var anchor := spider.call("get_physics_anchor") as ActiveRigBody2D
	_expect(anchor != null, "spider stance regression has no torso body")
	if anchor == null:
		spider.queue_free()
		wall.queue_free()
		await process_frame
		return
	_expect(not anchor.lock_rotation, "spider torso rotation is still locked")
	for rig_body in skin.get_rigid_bodies():
		_expect(is_equal_approx(rig_body.gravity_scale, 1.0), "spider segment is still using gravity cancellation")

	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")
	Input.action_release("jump")
	# Let the drawing fall onto its actual distal soles, then measure a full
	# 180-frame idle window after contacts and stance have had time to settle.
	for _settle_frame in range(120):
		await physics_frame
	var idle_start := anchor.global_position
	for _idle_frame in range(180):
		await physics_frame
	var idle_summary := skin.get_contact_summary()
	var idle_snapshot := skin.debug_spider_snapshot()
	_expect(bool(idle_snapshot.get("valid", false)), "runtime spider snapshot reports invalid anatomy")
	_expect(int(idle_snapshot.get("leg_count", 0)) == 6, "runtime spider did not preserve the six inferred legs")
	for field in ["torso_center", "torso_bounds", "support_height", "torso_clearance", "support_active", "stance_group", "gait_phase", "gait_targets", "torso_contact", "legs", "feet"]:
		_expect(idle_snapshot.has(field), "runtime spider snapshot omitted %s" % field)
	var feet_value: Variant = idle_summary.get("feet", [])
	_expect(feet_value is Array and (feet_value as Array).size() == 6, "contact summary did not expose six terminal feet")
	if feet_value is Array:
		for foot_value in feet_value as Array:
			var foot: Dictionary = foot_value
			for field in ["leg_index", "side", "side_rank", "phase_group", "support_candidate", "stance", "contact", "position", "plant_target", "gait_target", "target_angle", "normal", "drive_reaction"]:
				_expect(foot.has(field), "spider foot contact state omitted %s" % field)
	var idle_contact_sides := _spider_contact_sides(idle_summary)
	_expect(bool(idle_summary.get("grounded", false)), "spider torso settled without real foot grounding")
	_expect(bool(idle_summary.get("support_active", false)), "spider never activated foot-supported stance")
	_expect(not anchor.standing_hint, "spider stance still relies on the legacy torso standing hint")
	_expect(_contacting_spider_feet(idle_summary) >= 2, "spider settled with fewer than two contacting feet")
	_expect(bool(idle_contact_sides[-1]) and bool(idle_contact_sides[1]), "spider has no real foot contact on one side")
	_expect(not bool(idle_summary.get("torso_contact", true)), "spider is resting its torso on the floor")
	var support_height := float(idle_snapshot.get("support_height", 0.0))
	var torso_clearance := float(idle_snapshot.get("torso_clearance", 0.0))
	_expect(support_height > 1.0 and torso_clearance >= support_height * 0.6, "spider torso clearance %.1f is below 60%% of %.1f support height" % [torso_clearance, support_height])
	var idle_tilt := rad_to_deg(absf(wrapf(anchor.global_rotation, -PI, PI)))
	var idle_drift := anchor.global_position.distance_to(idle_start)
	_expect(idle_tilt < 20.0, "spider torso idled at %.1f degrees" % idle_tilt)
	_expect(idle_drift < 15.0, "spider drifted %.1f px during supported idle" % idle_drift)
	_expect(skin.debug_recovery_count() == 0, "spider needed automatic recovery while establishing stance")

	# A downward 60 px/s mass-scaled impulse must be absorbed by the stance and
	# return the torso to its supported height without invoking runaway recovery.
	var load_height := anchor.global_position.y
	anchor.apply_central_impulse(Vector2(0.0, 60.0) * anchor.mass)
	var load_contacts_restored := false
	for _load_frame in range(120):
		await physics_frame
		var load_summary := skin.get_contact_summary()
		if absf(anchor.global_position.y - load_height) <= 12.0 and _contacting_spider_feet(load_summary) >= 2:
			load_contacts_restored = true
	_expect(absf(anchor.global_position.y - load_height) <= 12.0, "spider torso did not recover its load-bearing height")
	_expect(load_contacts_restored, "spider did not restore real foot contacts within 120 frames of downward load")
	_expect(skin.debug_recovery_count() == 0, "downward load triggered spider runaway recovery")

	# Exercise the real PlayableEntity input path. Jump is explicitly released so
	# forward progress can only come from the grounded stance/gait controller.
	Input.action_release("jump")
	var walk_start := anchor.global_position
	var maximum_vertical_deviation := 0.0
	var maximum_tilt := 0.0
	var grounded_samples := 0
	var observed_stance_groups := {0: false, 1: false}
	var phase_transition_stage := {0: 0, 1: 0}
	var phase_target_excursion := {0: 0.0, 1: 0.0}
	var observed_leg_drive := false
	var drive_on_unplanted_foot := false
	var maximum_leg_drive := 0.0
	var maximum_drive_balance_error := 0.0
	Input.action_press("move_right")
	for _walk_frame in range(180):
		await physics_frame
		var walk_summary := skin.get_contact_summary()
		var walk_snapshot := skin.debug_spider_snapshot()
		var reported_stance_group := int(walk_snapshot.get("stance_group", -1))
		if reported_stance_group in [0, 1]:
			observed_stance_groups[reported_stance_group] = true
		if bool(walk_summary.get("grounded", false)):
			grounded_samples += 1
		maximum_vertical_deviation = maxf(maximum_vertical_deviation, absf(anchor.global_position.y - walk_start.y))
		maximum_tilt = maxf(maximum_tilt, rad_to_deg(absf(wrapf(anchor.global_rotation, -PI, PI))))
		var phase_has_stance := {0: false, 1: false}
		var phase_has_swing_target := {0: false, 1: false}
		var leg_drive_force := Vector2(walk_summary.get("leg_drive_force", Vector2.ZERO))
		var drive_reaction_sum := Vector2.ZERO
		maximum_leg_drive = maxf(maximum_leg_drive, leg_drive_force.length())
		for foot_value in (walk_summary.get("feet", []) as Array):
			var foot: Dictionary = foot_value
			var drive_reaction := Vector2(foot.get("drive_reaction", Vector2.ZERO))
			drive_reaction_sum += drive_reaction
			if drive_reaction.length_squared() > 1.0:
				observed_leg_drive = true
				drive_on_unplanted_foot = drive_on_unplanted_foot or not bool(foot.get("stance", false))
			var phase_group := int(foot.get("phase_group", -1))
			if phase_group not in [0, 1] or not bool(foot.get("support_candidate", false)):
				continue
			if bool(foot.get("stance", false)):
				phase_has_stance[phase_group] = true
			else:
				var gait_target: Vector2 = foot.get("gait_target", Vector2.ZERO)
				var plant_target: Vector2 = foot.get("plant_target", gait_target)
				var target_excursion := gait_target.distance_to(plant_target)
				phase_target_excursion[phase_group] = maxf(float(phase_target_excursion[phase_group]), target_excursion)
				if target_excursion >= 6.0:
					phase_has_swing_target[phase_group] = true
		maximum_drive_balance_error = maxf(maximum_drive_balance_error, (leg_drive_force + drive_reaction_sum).length())
		for phase_group in [0, 1]:
			var stage := int(phase_transition_stage[phase_group])
			if stage == 0 and bool(phase_has_stance[phase_group]):
				phase_transition_stage[phase_group] = 1
			elif stage == 1 and bool(phase_has_swing_target[phase_group]):
				phase_transition_stage[phase_group] = 2
			elif stage == 2 and bool(phase_has_stance[phase_group]):
				phase_transition_stage[phase_group] = 3
	Input.action_release("move_right")
	var forward_travel := anchor.global_position.x - walk_start.x
	_expect(forward_travel >= 90.0, "spider moved only %.1f px during 180 no-jump frames" % forward_travel)
	_expect(maximum_vertical_deviation < 35.0, "spider torso deviated %.1f px vertically while walking" % maximum_vertical_deviation)
	_expect(maximum_tilt < 35.0, "spider torso tilted %.1f degrees while walking" % maximum_tilt)
	_expect(grounded_samples >= 90, "spider had real foot contact for only %d/180 walk samples" % grounded_samples)
	_expect(observed_leg_drive and maximum_leg_drive > 1.0, "spider walked without stance-leg drive forces")
	_expect(not drive_on_unplanted_foot, "spider applied locomotion drive through an unplanted foot")
	_expect(maximum_drive_balance_error <= maxf(0.5, maximum_leg_drive * 0.001), "spider leg drive injected an unbalanced %.2f N torso force" % maximum_drive_balance_error)
	_expect(bool(observed_stance_groups[0]) and bool(observed_stance_groups[1]), "spider never handed stance between both gait groups")
	_expect(int(phase_transition_stage[0]) >= 3 and int(phase_transition_stage[1]) >= 3, "both gait groups did not complete stance-swing-stance transitions (%d, %d; targets %.1f, %.1f)" % [phase_transition_stage[0], phase_transition_stage[1], phase_target_excursion[0], phase_target_excursion[1]])
	_expect(skin.debug_max_joint_error() <= 22.5, "spider joint separated by %.2f px during walking" % skin.debug_max_joint_error())
	_expect(skin.debug_recovery_count() == 0, "spider locomotion invoked automatic recovery")

	# Jump must release active stance, travel upward, and reacquire support only
	# after real terminal feet land again.
	var jump_start_y := anchor.global_position.y
	var minimum_jump_y := jump_start_y
	var stance_released := false
	var became_airborne := false
	var stance_reacquired := false
	var airborne_leg_drive := false
	Input.action_press("jump")
	# Hold across one complete physics callback; SceneTree.physics_frame resumes
	# before node _physics_process callbacks in the same tick.
	await physics_frame
	await physics_frame
	Input.action_release("jump")
	for _jump_frame in range(240):
		var jump_summary := skin.get_contact_summary()
		minimum_jump_y = minf(minimum_jump_y, anchor.global_position.y)
		if not bool(jump_summary.get("support_active", false)):
			stance_released = true
		if not bool(jump_summary.get("grounded", false)):
			became_airborne = true
			airborne_leg_drive = airborne_leg_drive \
				or Vector2(jump_summary.get("leg_drive_force", Vector2.ZERO)).length_squared() > 1.0
		elif became_airborne and bool(jump_summary.get("support_active", false)) and _contacting_spider_feet(jump_summary) >= 2:
			stance_reacquired = true
		await physics_frame
	_expect(stance_released, "spider jump never released stance anchors")
	_expect(jump_start_y - minimum_jump_y >= 12.0, "spider jump produced no meaningful upward travel")
	_expect(stance_reacquired, "spider did not reacquire real foot support after landing")
	_expect(not airborne_leg_drive, "spider retained stance-leg propulsion while airborne")
	_expect(skin.debug_recovery_count() == 0, "spider jump/landing invoked automatic recovery")

	# Wall climbing remains a fallback transition and must consume aggregated rig
	# contact instead of relying on the torso alone.
	var wall_seen := false
	Input.action_press("move_right")
	for _wall_approach_frame in range(180):
		await physics_frame
		if bool(skin.get_contact_summary().get("wall_contact", false)):
			wall_seen = true
			break
	var climb_start_y := anchor.global_position.y
	var climb_min_y := climb_start_y
	Input.action_press("move_up")
	for _climb_frame in range(90):
		await physics_frame
		var climb_summary := skin.get_contact_summary()
		wall_seen = wall_seen or bool(climb_summary.get("wall_contact", false))
		climb_min_y = minf(climb_min_y, anchor.global_position.y)
	Input.action_release("move_up")
	Input.action_release("move_right")
	_expect(wall_seen, "spider never reported aggregated wall contact")
	_expect(climb_start_y - climb_min_y >= 6.0, "spider wall-climb fallback produced no upward travel")
	_expect(skin.debug_max_joint_error() <= 22.5 and skin.debug_recovery_count() == 0, "spider became unstable during wall-climb smoke test")

	spider.queue_free()
	wall.queue_free()
	await process_frame


## An uncontrolled, grounded creature must stay put. The active ragdoll must not pump
## energy through its limbs (via undamped gravity compensation) and wander/spin on its
## own when the player gives no input.
func _test_idle_stability() -> void:
	for entity_id in ["spider", "horse", "monkey"]:
		var instance := registry.instantiate_entity(entity_id) as Node2D
		world.add_child(instance)
		instance.global_position = Vector2(400.0, 360.0)
		instance.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1200.0))
		instance.call("apply_drawing", _blank_image(), _fixture_for(entity_id))
		var anchor := instance.call("get_physics_anchor") as ActiveRigBody2D
		for _settle in range(90):
			await physics_frame
		var start := anchor.global_position
		var start_rotation := anchor.global_rotation
		for _hold in range(180):
			await physics_frame
		var drift := anchor.global_position.distance_to(start)
		var spin := rad_to_deg(absf(wrapf(anchor.global_rotation - start_rotation, -PI, PI)))
		_expect(drift < 40.0, "%s wandered %.1f px with zero input (self-propelling ragdoll)" % [entity_id, drift])
		_expect(spin < 45.0, "%s spun %.1f deg with zero input" % [entity_id, spin])
		instance.queue_free()
		await process_frame


## Messy real-world-style drawings (single scribbles, gapped limbs, multi-stroke bodies,
## jittery input, lone blobs) must still articulate, animate, and stay stable. Fixtures
## live in res://tests/fixtures/ and are also inspectable via res://tests/rig_probe.gd.
func _test_messy_fixtures() -> void:
	var dir := DirAccess.open("res://tests/fixtures")
	if dir == null:
		return
	var names := dir.get_files()
	names.sort()
	for file_name in names:
		if file_name.ends_with(".json"):
			await _check_messy_fixture("res://tests/fixtures/" + file_name)


func _check_messy_fixture(path: String) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		_expect(false, "fixture %s did not parse" % path)
		return
	var label := String(data.get("description", path.get_file()))
	var entity_id := String(data.get("entity_id", "horse"))
	var strokes := _messy_strokes(data.get("strokes", []))
	var states: Array = data.get("states", ["walk"])
	var primary_state := String(states[0]) if not states.is_empty() else "walk"
	var motion := {"moving": true, "speed_ratio": 1.0, "direction": 1.0, "charge_ratio": 1.0}

	var instance := registry.instantiate_entity(entity_id) as Node2D
	_expect(instance != null, "could not instantiate %s for fixture '%s'" % [entity_id, label])
	if instance == null:
		return
	world.add_child(instance)
	instance.global_position = Vector2(300.0, 200.0)
	if instance.has_method("set_world_bounds"):
		instance.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1200.0))
	instance.call("apply_drawing", _blank_image(), strokes)
	var skin := instance.get_node("DrawingSkin") as RuntimeRig2D

	_expect(skin.skin_mode() == "vector", "'%s' collapsed to bitmap" % label)
	_expect(skin.get_joint_count() > 0, "'%s' produced no articulation" % label)
	_expect(skin.get_rigid_bodies().size() <= 24 and skin.get_joint_count() <= 23, "'%s' exceeded rig caps" % label)

	instance.set_physics_process(false)
	skin.set_motion_state(primary_state, motion)
	skin._physics_process(0.1)
	if entity_id == "spider":
		_expect(bool(skin.debug_spider_snapshot().get("valid", false)), "'%s' did not produce spider anatomy" % label)
	else:
		var animated := false
		for torque in skin.debug_drive_torques():
			animated = animated or absf(torque) > 0.01
		_expect(animated, "'%s' did not animate in state %s" % [label, primary_state])

	var maximum_joint_error := 0.0
	for _frame in range(90):
		skin.set_motion_state(primary_state, motion)
		await physics_frame
		maximum_joint_error = maxf(maximum_joint_error, skin.debug_max_joint_error())
	_expect(maximum_joint_error <= 22.5, "'%s' rig unstable (%.2f px)" % [label, maximum_joint_error])
	_expect(skin.debug_recovery_count() <= 1, "'%s' needed repeated recovery" % label)

	instance.queue_free()
	await process_frame


func _messy_strokes(raw: Array) -> Array:
	var strokes: Array = []
	for stroke_value in raw:
		var stroke: Dictionary = stroke_value
		var points := PackedVector2Array()
		for pair in stroke.get("points", []):
			points.append(Vector2(float(pair[0]), float(pair[1])))
		strokes.append({"points": points, "width": float(stroke.get("width", 8.0)), "color": Color.BLACK})
	return strokes


## Everything the rig renders must be the player's ink: on-stroke (no fabricated
## chords slashing across the figure) and length-conserving (no ink silently
## dropped or duplicated). Checked for every living entity's clean fixture and
## every messy fixture — spider included, since its analyzer claims exact slices.
func _test_ink_integrity() -> void:
	var cases: Array = []
	for entity_id in _living_entity_ids():
		cases.append({"label": "clean %s" % entity_id, "entity_id": entity_id, "strokes": _fixture_for(entity_id)})
	var dir := DirAccess.open("res://tests/fixtures")
	if dir != null:
		var names := dir.get_files()
		names.sort()
		for file_name in names:
			if not file_name.ends_with(".json"):
				continue
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/" + file_name))
			if typeof(data) != TYPE_DICTIONARY:
				continue
			var fixture := data as Dictionary
			cases.append({
				"label": String(fixture.get("description", file_name)),
				"entity_id": String(fixture.get("entity_id", "horse")),
				"strokes": _messy_strokes(fixture.get("strokes", []))
			})
	for case_value in cases:
		var case_data := case_value as Dictionary
		var label := String(case_data["label"])
		var instance := registry.instantiate_entity(String(case_data["entity_id"])) as Node2D
		if instance == null:
			_expect(false, "ink integrity could not instantiate %s" % label)
			continue
		world.add_child(instance)
		instance.global_position = Vector2(300.0, 200.0)
		instance.call("apply_drawing", _blank_image(), case_data["strokes"])
		var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
		var strokes := skin.get_vector_strokes()
		var rendered := skin.debug_rendered_ink()
		_expect(not rendered.is_empty(), "'%s' rendered no ink" % label)
		_expect(skin.get_rigid_bodies().size() <= 24 and skin.get_joint_count() <= 23, "'%s' exceeded rig caps" % label)
		_expect(
			skin.get_joint_count() > 0 or skin.get_rigid_bodies().size() == 1,
			"'%s' degraded partially: %d jointless bodies" % [label, skin.get_rigid_bodies().size()]
		)
		var input_length := 0.0
		for stroke_value in strokes:
			input_length += _test_path_length((stroke_value as Dictionary)["points"])
		var core_length := 0.0
		var off_ink := 0
		for entry_value in rendered:
			var entry := entry_value as Dictionary
			var points: PackedVector2Array = entry["points"]
			if points.size() < 2:
				continue
			for index in range(points.size()):
				if not _point_is_on_ink(points[index], strokes):
					off_ink += 1
				if index > 0 and not _point_is_on_ink((points[index - 1] + points[index]) * 0.5, strokes):
					off_ink += 1
			var prefix := int(entry.get("overlap_prefix", 0))
			var suffix := int(entry.get("overlap_suffix", 0))
			var core := points.slice(prefix, points.size() - suffix)
			if core.size() >= 2:
				core_length += _test_path_length(core)
		_expect(off_ink == 0, "'%s' rendered %d points off the drawn ink" % [label, off_ink])
		if input_length > 0.0:
			var ratio := core_length / input_length
			_expect(
				ratio >= 0.92 and ratio <= 1.08,
				"'%s' rendered %.0f%% of the drawn ink length" % [label, ratio * 100.0]
			)
		instance.queue_free()
		await process_frame


func _point_is_on_ink(point: Vector2, strokes: Array) -> bool:
	for stroke_value in strokes:
		var points: PackedVector2Array = (stroke_value as Dictionary)["points"]
		for index in range(points.size() - 1):
			var nearest := Geometry2D.get_closest_point_to_segment(point, points[index], points[index + 1])
			if point.distance_to(nearest) <= 2.0:
				return true
	return false


## Joints must HOLD their gait poses, not just keep their pin anchors together.
## Before the continuous-angle muscles, limbs windmilled in full circles (pin
## error stayed at zero, so no other test saw it): birds could not flap and
## walkers flailed. A disciplined rig keeps every joint's integrated angle within
## its drawn limit plus bounded overshoot.
func _test_limb_angle_discipline() -> void:
	var cases := [
		{"entity_id": "horse", "state": "walk", "limit_deg": 250.0},
		{"entity_id": "bird", "state": "fly", "limit_deg": 250.0},
		{"entity_id": "monkey", "state": "walk", "limit_deg": 250.0},
		{"entity_id": "spider", "state": "walk", "limit_deg": 280.0}
	]
	for case_value in cases:
		var case_data := case_value as Dictionary
		var entity_id := String(case_data["entity_id"])
		var instance := registry.instantiate_entity(entity_id) as Node2D
		if instance == null:
			_expect(false, "angle discipline could not instantiate %s" % entity_id)
			continue
		world.add_child(instance)
		instance.global_position = Vector2(300.0, 200.0)
		instance.call("apply_drawing", _blank_image(), _fixture_for(entity_id))
		var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
		instance.set_physics_process(false)
		var params := {"moving": true, "speed_ratio": 1.0, "direction": 1.0}
		for _frame in range(120):
			skin.set_motion_state(String(case_data["state"]), params)
			await physics_frame
		var max_angle := rad_to_deg(skin.debug_max_tracked_angle())
		_expect(
			max_angle <= float(case_data["limit_deg"]),
			"%s joints windmilled to %.0f deg (limit %.0f)" % [entity_id, max_angle, float(case_data["limit_deg"])]
		)
		instance.queue_free()
		await process_frame


## A stick figure must rig as spine-torso with articulated arms and legs. Two
## regressions guarded here: the closed head circle out-scoring the spine as the
## torso (its stroke seam hid it from the hub test), and arms drawn as one stroke
## crossing the spine being welded rigid instead of split into two limbs.
func _test_stick_figure_anatomy() -> void:
	var instance := registry.instantiate_entity("monkey") as Node2D
	_expect(instance != null, "could not instantiate monkey for stick figure check")
	if instance == null:
		return
	world.add_child(instance)
	instance.global_position = Vector2(300.0, 200.0)
	instance.call("apply_drawing", _blank_image(), _stick_figure_fixture())
	var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
	_expect(skin.get_joint_count() >= 6, "stick figure articulated only %d joints" % skin.get_joint_count())
	var roles := skin.debug_segment_roles()
	_expect(roles.count("arm") >= 2, "stick figure arms did not split into limbs (roles: %s)" % str(roles))
	_expect(roles.count("leg") >= 2, "stick figure legs missing (roles: %s)" % str(roles))
	instance.queue_free()
	await process_frame


func _stick_figure_fixture() -> Array:
	var strokes: Array = []
	var head := PackedVector2Array()
	for index in range(19):
		var angle := TAU * float(index) / 18.0
		head.append(Vector2(256.0 + cos(angle) * 30.0, 150.0 + sin(angle) * 30.0))
	strokes.append(_stroke(head))
	strokes.append(_stroke(_dense_line(Vector2(256.0, 180.0), Vector2(256.0, 300.0))))
	strokes.append(_stroke(_dense_line(Vector2(180.0, 230.0), Vector2(332.0, 230.0))))
	strokes.append(_stroke(_dense_line(Vector2(256.0, 300.0), Vector2(208.0, 404.0))))
	strokes.append(_stroke(_dense_line(Vector2(256.0, 300.0), Vector2(304.0, 404.0))))
	return strokes


func _dense_line(from: Vector2, to: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := maxi(2, int(from.distance_to(to) / 6.0))
	for index in range(count + 1):
		points.append(from.lerp(to, float(index) / float(count)))
	return points


## A limb stroke whose midpoint merely grazes the torso must stay one limb; the
## old interior split cut it into two half-limbs that tore the drawing apart.
func _test_grazing_stroke_not_split() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/grazing_limb.json"))
	if typeof(data) != TYPE_DICTIONARY:
		_expect(false, "grazing_limb fixture did not parse")
		return
	var strokes := _messy_strokes((data as Dictionary).get("strokes", []))
	var instance := registry.instantiate_entity("horse") as Node2D
	_expect(instance != null, "could not instantiate horse for grazing check")
	if instance == null:
		return
	world.add_child(instance)
	instance.global_position = Vector2(300.0, 200.0)
	instance.call("apply_drawing", _blank_image(), strokes)
	var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
	# The grazing stroke is the fixture's last stroke; normalization keeps order.
	var normalized := skin.get_vector_strokes()
	var graze: Dictionary = normalized[normalized.size() - 1]
	var radius := clampf(skin.get_stroke_bounds().size.length() * 0.14, 12.0, 40.0)
	var paths: Array = skin._paths_attached_to_body(graze["points"], radius)
	_expect(paths.size() <= 1, "grazing stroke split into %d limb paths" % paths.size())
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


func _test_compound_fallback_recovery() -> void:
	var instance := registry.instantiate_entity("spider") as Node2D
	world.add_child(instance)
	instance.global_position = Vector2(320.0, 160.0)
	instance.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1200.0))
	instance.call("apply_drawing", _blank_image(), [])
	var anchor := instance.call("get_physics_anchor") as ActiveRigBody2D
	var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
	_expect(anchor != null and skin.get_joint_count() == 0, "bitmap fallback did not build one compound body")
	if anchor != null:
		anchor.global_position = Vector2(9000.0, 9000.0)
		for _frame in range(8):
			await physics_frame
		_expect(Rect2(0.0, -520.0, 3760.0, 1200.0).has_point(anchor.global_position), "compound fallback escaped without recovery")
	instance.queue_free()
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


func _living_entity_ids() -> Array:
	var ids: Array = []
	for entity_id in registry.get_entity_ids():
		if String(registry.get_entity(entity_id).get("runtime_role", "")) == "active_ragdoll_morph":
			ids.append(entity_id)
	return ids


func _expected_roles_for_rig(rig_type: String) -> Array:
	match rig_type:
		"flier":
			return ["wing"]
		"swimmer":
			return ["tail", "fin", "chain"]
		"walker", "biped", "hopper":
			return ["leg"]
		_:
			return []


func _gait_for_rig(rig_type: String) -> String:
	match rig_type:
		"flier":
			return "fly"
		"swimmer":
			return "swim"
		"hopper":
			return "jump"
		_:
			return "walk"


## Per-archetype coverage: every enabled entity must spawn, rig, and step physics
## without erroring, keep its ink intact, stay in bounds, and not windmill. Results
## are grouped by rig_type archetype, matching the thesis's per-archetype plan.
func _test_archetype_coverage() -> void:
	var groups: Dictionary = {}
	var order: Array = []
	for entity_id in registry.get_entity_ids():
		var entry := registry.get_entity(entity_id)
		var rig_type := String(entry.get("rig_type", "none"))
		if not groups.has(rig_type):
			groups[rig_type] = {"pass": 0, "fail": 0}
			order.append(rig_type)
		var before := failures.size()
		await _cover_entity(entity_id, entry, rig_type)
		if failures.size() == before:
			groups[rig_type]["pass"] += 1
		else:
			groups[rig_type]["fail"] += 1
	order.sort()
	print("--- Per-archetype coverage summary (rig_type) ---")
	for rig_type in order:
		var g: Dictionary = groups[rig_type]
		print("  %-8s : %d passed, %d failed" % [rig_type, int(g["pass"]), int(g["fail"])])


func _cover_entity(entity_id: String, entry: Dictionary, rig_type: String) -> void:
	var is_creature := String(entry.get("runtime_role", "")) == "active_ragdoll_morph"
	var fixture: Array = _fixture_for(entity_id) if is_creature else _utility_fixture(entity_id)
	var instance := registry.instantiate_entity(entity_id) as Node2D
	_expect(instance != null, "coverage: could not instantiate %s" % entity_id)
	if instance == null:
		return
	world.add_child(instance)
	instance.global_position = Vector2(400.0, 200.0)
	if instance.has_method("set_world_bounds"):
		instance.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1200.0))
	instance.call("apply_drawing", _blank_image(), fixture)
	var anchor := instance.call("get_physics_anchor") as RigidBody2D
	var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
	_expect(anchor != null and skin != null, "coverage: %s missing anchor/skin" % entity_id)
	if anchor == null or skin == null:
		instance.queue_free()
		await process_frame
		return
	_expect(skin.get_rigid_bodies().size() <= 24 and skin.get_joint_count() <= 23, "coverage: %s exceeded rig caps" % entity_id)
	if skin.skin_mode() == "vector":
		_expect(bool(skin.call("_rig_ink_is_intact")), "coverage: %s violated the ink-integrity audit" % entity_id)
	if is_creature and entity_id != "spider":
		_expect(skin.get_joint_count() > 0 or skin.skin_mode() != "vector", "coverage: %s did not articulate" % entity_id)
	instance.set_physics_process(false)
	var motion := {"moving": true, "speed_ratio": 1.0, "direction": 1.0, "charge_ratio": 1.0}
	var gait := _gait_for_rig(rig_type)
	for _frame in range(90):
		if is_creature:
			skin.set_motion_state(gait, motion)
		await physics_frame
	for rig_body in skin.get_rigid_bodies():
		_expect(is_finite(rig_body.global_position.x) and is_finite(rig_body.global_position.y), "coverage: %s segment became non-finite" % entity_id)
	_expect(is_finite(anchor.global_position.x) and is_finite(anchor.global_position.y), "coverage: %s anchor became non-finite" % entity_id)
	_expect(Rect2(-180.0, -700.0, 4120.0, 1560.0).has_point(anchor.global_position), "coverage: %s escaped the playable world" % entity_id)
	if is_creature:
		var max_angle := rad_to_deg(skin.debug_max_tracked_angle())
		_expect(max_angle <= 360.0, "coverage: %s joints windmilled to %.0f deg" % [entity_id, max_angle])
	instance.queue_free()
	await process_frame


func _fixture_for(entity_id: String) -> Array:
	if entity_id == "snake":
		var wave := PackedVector2Array()
		for index in range(18):
			wave.append(Vector2(90.0 + index * 19.0, 256.0 + sin(float(index) * 0.75) * 28.0))
		return [_stroke(wave)]
	if entity_id == "spider":
		return SpiderReferenceFixtures.separate_legs()
	var strokes: Array = [_stroke(_closed_body())]
	var limb_count := 4
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


func _test_path_length(points: PackedVector2Array) -> float:
	var length := 0.0
	for index in range(1, points.size()):
		length += points[index - 1].distance_to(points[index])
	return length


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


func _add_spider_test_wall() -> StaticBody2D:
	var wall := StaticBody2D.new()
	# Keep the wall reachable within the fixed smoke-test window now that grounded
	# translation comes from traction-limited stance legs instead of free torso thrust.
	wall.position = Vector2(500.0, 250.0)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(30.0, 300.0)
	collision.shape = shape
	wall.add_child(collision)
	world.add_child(wall)
	return wall


func _contacting_spider_feet(summary: Dictionary) -> int:
	var count := 0
	var feet_value: Variant = summary.get("feet", [])
	if feet_value is Array:
		for foot_value in feet_value as Array:
			if foot_value is Dictionary and bool((foot_value as Dictionary).get("contact", false)):
				count += 1
	return count


func _spider_contact_sides(summary: Dictionary) -> Dictionary:
	var result := {-1: false, 1: false}
	var feet_value: Variant = summary.get("feet", [])
	if feet_value is Array:
		for foot_value in feet_value as Array:
			if not (foot_value is Dictionary):
				continue
			var foot: Dictionary = foot_value
			if bool(foot.get("contact", false)):
				var side := int(foot.get("side", 0))
				if side in [-1, 1]:
					result[side] = true
	return result


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
