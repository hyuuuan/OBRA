extends "res://tests/run_level3_sea_probe.gd"
## The real sea fixture, with current-specific input checks. Run through tools/run_suites.sh.


func _run() -> void:
	await _the_current_moves_the_apo()
	await _aquatic_forms_handle_the_current()
	await _the_boat_and_the_water_are_separate()
	for line in results:
		print(line)
	print("OBRA_LEVEL3_CURRENT_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(0 if failures == 0 else 1)


func _the_current_moves_the_apo() -> void:
	await _open_the_level()
	var current := level.get_node_or_null(^"EnvironmentBaseplate/GameplayPlane/StrongCurrent")
	_check(current != null and current.has_method("_draw"),
		"the force has a visible current in the real sea", "StrongCurrent")
	if current == null:
		await _close_the_level()
		return
	var rect: Rect2 = current.get("water_rect")
	var surface := float(level.get("_waterline_y"))
	_place(Vector2(rect.position.x + 700.0, surface + 18.0))
	var start := _anchor().x
	await _seconds(0.15)
	var early := start - _anchor().x
	await _seconds(1.85)
	var later := start - _anchor().x
	_check(early >= 0.0 and early < 15.0 and later > 100.0,
		"an idle apo is gradually carried left", "%.1f px at 0.15 s, %.1f px at 2 s" % [early, later])
	_check(_anchor().y > surface and not bool((level.get("player") as Wanderer).surfacing),
		"the current does not need breath exhaustion", "afloat with air")
	_place(Vector2(rect.position.x + 1200.0, surface + 18.0))
	start = _anchor().x
	Input.action_press(&"move_right")
	await _seconds(2.5)
	Input.action_release(&"move_right")
	_check(_anchor().x < start - 100.0, "the current pushes left against right input",
		"from %.0f to %.0f" % [start, _anchor().x])
	_place(Vector2(rect.end.x - 700.0, surface + 18.0))
	start = _anchor().x
	await _seconds(2.0)
	_check(_anchor().x < start - 100.0, "the island half also flows left",
		"from %.0f to %.0f" % [start, _anchor().x])
	_place(Vector2(rect.position.x - 120.0, surface + 18.0))
	start = _anchor().x
	await _seconds(1.0)
	_check(absf(_anchor().x - start) < 5.0, "the calm shore water does not push",
		"moved %.1f px" % (_anchor().x - start))
	_place(Vector2(rect.position.x + 1200.0, surface + 18.0))
	start = _anchor().x
	Input.action_press(&"move_left")
	await _seconds(1.5)
	Input.action_release(&"move_left")
	_check(_anchor().x < start - 180.0, "left input swims with the current",
		"moved %.1f px" % (_anchor().x - start))
	var profile := root.get_node_or_null(^"/root/PlayerProfile")
	var before := float(current.get("_flow_time"))
	await _seconds(0.1)
	_check(float(current.get("_flow_time")) > before, "the direction marks animate with the water", "moving left")
	profile.call("set_setting", "reduce_motion", true)
	before = float(current.get("_flow_time"))
	await _seconds(0.2)
	_check(is_equal_approx(float(current.get("_flow_time")), before),
		"Reduce Motion keeps the direction marks still", "left-pointing marks remain drawn")
	profile.call("set_setting", "reduce_motion", false)
	await _close_the_level()


func _aquatic_forms_handle_the_current() -> void:
	await _open_the_level()
	await _take_the_brush()
	for pair in [["fish", "swimmer"], ["frog", "hopper"]]:
		await _become(pair[0], pair[1])
		_place(Vector2(3200.0, 1000.0))
		var start := _anchor().x
		Input.action_press(&"move_right")
		await _seconds(1.5)
		Input.action_release(&"move_right")
		_check(String(level.get("_current_form_id")) == pair[0] and _anchor().x > start + 80.0,
			"%s swims right through the current" % pair[0], "moved %.1f px" % (_anchor().x - start))
		_check(is_zero_approx(float(level.get("_current_strength"))),
			"%s is exempt from the current force" % pair[0], "no leftward pull")
	for pair in [["ant", "walker"], ["circle", ""]]:
		await _become(pair[0], pair[1])
		_place(Vector2(3200.0, 1000.0))
		var start := _anchor().x
		await _seconds(0.6)
		_check(String(level.get("_current_form_id")) == pair[0],
			"harness: %s is tested before floundering" % pair[0], String(level.get("_current_form_id")))
		_check(_anchor().x < start - 15.0,
			"the non-aquatic %s is pushed left" % pair[0], "moved %.1f px" % (_anchor().x - start))
	await _close_the_level()


func _the_boat_and_the_water_are_separate() -> void:
	await _open_the_level()
	level.call("_launch_the_bangka")
	await _seconds(0.2)
	var boat := level.get("_launched_boat") as RigidBody2D
	var surface := float(level.get("_waterline_y"))
	_check(boat != null, "harness: a real bangka is afloat", "launched")
	if boat == null:
		await _close_the_level()
		return
	boat.call("apply_morph_state", {"position": Vector2(3500.0, surface + 10.0), "linear_velocity": Vector2.ZERO})
	await _seconds(0.3)
	_place(Vector2(boat.global_position.x + 200.0, surface + 18.0))
	var start := _anchor().x
	await _seconds(1.2)
	_check(_anchor().x < start - 50.0, "swimming near a boat still feels the current",
		"moved %.1f px" % (_anchor().x - start))
	_place(boat.global_position + Vector2(0.0, -40.0))
	await _seconds(0.1)
	await _tap_current_action(&"interact")
	await _unpause()
	_check(bool(boat.call("has_passenger", level.get("player"))), "E boards the boat in the current", "aboard")
	start = boat.global_position.x
	Input.action_press(&"move_right")
	await _seconds(2.0)
	Input.action_release(&"move_right")
	_check(boat.global_position.x > start + 200.0 and is_zero_approx(float(level.get("_current_strength"))),
		"a boat passenger can still row right", "moved %.1f px" % (boat.global_position.x - start))
	await _close_the_level()


func _tap_current_action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await physics_frame
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await physics_frame
