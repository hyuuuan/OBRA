extends SceneTree
## Real E-key entry, the horizontal tap, and the uninterrupted one-second reveal.
## Add -- --visual to save transition frames (requires a window).

const Entry := preload("res://scripts/painting_transition.gd")
var failures := 0
var started_at := 0
var finished_at := 0
var visual := false
var visual_only := false
var captures: Array[Dictionary] = []
var requested_at := 0
var level_number := 1
var return_mode := ""


func _initialize() -> void:
	root.set_content_scale_size(Vector2i(1600, 900))
	visual = "--visual" in OS.get_cmdline_user_args()
	visual_only = "--visual-only" in OS.get_cmdline_user_args()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			level_number = clampi(argument.trim_prefix("--level=").to_int(), 1, 5)
		elif argument == "--return":
			return_mode = "pause"
		elif argument == "--complete-return":
			return_mode = "complete"
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %s" % ["OK" if ok else "FAIL", message])


func _run() -> void:
	var manager := root.get_node("LevelManager")
	var profile := root.get_node("PlayerProfile")
	profile.set("_data", profile.call("_default_profile"))
	var data: Dictionary = profile.get("_data")
	data["levels_unlocked"] = ["level_%d" % level_number]
	profile.call("record_brush_acquired")
	manager.transition_started.connect(_started)
	manager.transition_finished.connect(_finished)
	await create_timer(0.2).timeout
	change_scene_to_file("res://levels/hub/hub.tscn")
	await scene_changed
	var hub := current_scene as Node2D
	var painting := hub.get_node("Painting%d" % level_number) as Node2D
	var apo := hub.get_node("Apo") as Node2D
	apo.set_physics_process(false)
	var hall_x := painting.position.x + 37.0
	if not visual_only:
		apo.position.x = painting.position.x - 140.0
		await create_timer(0.5).timeout
		_check(is_zero_approx(float(painting.get("_nudge_height"))), "outside the horizontal tolerance the painting rests")
		apo.position.x = painting.position.x - 80.0
		await create_timer(0.10).timeout
		_check(float(painting.get("_nudge_height")) > 3.0, "walking inline lifts the painting even below it on the floor")
		await create_timer(0.5).timeout
		_check(is_zero_approx(float(painting.get("_nudge_height"))) and painting.get("_nudge_scale") == 1.0,
			"the tap settles at its original position and size")
		await create_timer(0.5).timeout
		_check(is_zero_approx(float(painting.get("_nudge_height"))), "standing inline does not repeat the tap")
		apo.position.x = painting.position.x - 140.0
		await process_frame
		await process_frame
		apo.position.x = painting.position.x + 37.0
		await create_timer(0.10).timeout
		_check(float(painting.get("_nudge_height")) > 3.0, "leaving and returning rearms the tap")
		await create_timer(0.5).timeout
	else:
		apo.position.x = hall_x
		await create_timer(0.5).timeout
	if visual:
		await _shot("00_hall")

	if not visual_only:
		# Assert the curve's actual velocity, endpoints and monotonicity, including its 40/60 split.
		var previous := 0.0
		var monotonic := true
		var peak_at := 0.0
		var peak_speed := 0.0
		for index in range(1, 1001):
			var at := index / 1000.0
			var value := Entry.entry_ease(at)
			monotonic = monotonic and value >= previous and value <= 1.0
			if value - previous > peak_speed:
				peak_speed = value - previous
				peak_at = at
			previous = value
		_check(monotonic and is_equal_approx(previous, 1.0), "the ease reaches exactly 1 without reversing or overshooting")
		_check(absf(peak_at - 0.4) < 0.005, "maximum speed occurs at 40 percent, followed by 60 percent settling")

	requested_at = Time.get_ticks_msec()
	_press(KEY_E)
	await process_frame
	_check(bool(manager.call("is_transitioning")), "the player's E key starts painting entry")
	_check(not bool(manager.call("open_level", "level_2", painting)), "a second request cannot replace a reserved destination")
	var entry := manager.get_node("PaintingEntry")
	var seen := 0
	var screenshot_index := 0
	var targets := [0.15, 0.30, 0.44, 0.58, 0.72, 0.88]
	var timeout := Time.get_ticks_msec() + 15000
	while bool(manager.call("is_transitioning")) and Time.get_ticks_msec() < timeout:
		await process_frame
		var p := float(entry.get("progress"))
		if started_at > 0 and p > 0.05 and p < 0.95:
			seen += 1
			_check_player_held()
		if visual and screenshot_index < targets.size() and p >= targets[screenshot_index]:
			await _shot("%02d_transition" % (screenshot_index + 1))
			screenshot_index += 1
	_check(seen > 5, "the transition renders intermediate frames")
	print("  preparation before the visual: %d ms" % (started_at - requested_at))
	_check(finished_at > started_at and absf((finished_at - started_at) / 1000.0 - 1.0) < 0.08,
		"the visual lasts 1 second (measured %.3f s)" % ((finished_at - started_at) / 1000.0))
	var expected: String = manager.call("get_level", "level_%d" % level_number).get("scene_path", "")
	_check(current_scene != null and current_scene.scene_file_path == expected,
		"the enlarged painting reveals the selected playable level")
	_check(not entry.visible and not bool(manager.call("is_transitioning")), "the overlay clears and input unlocks")
	if visual:
		await _shot("07_level")
		await create_timer(0.14).timeout
		await _shot("08_ui_fading")
		await create_timer(0.20).timeout
		await _shot("09_ui_visible")
		for capture in captures:
			(capture["image"] as Image).save_png("/tmp/obra_painting_%s.png" % capture["label"])
		captures.clear()
	for player in get_nodes_in_group(&"player_character"):
		_check(player.is_physics_processing(), "the incoming player regains movement")
	if not return_mode.is_empty():
		await _return_to_hall(manager, profile, hall_x)

	if not visual_only:
		# Reduced motion keeps the same duration, a calm dissolve, and no enlargement or blur.
		profile.call("set_setting", "reduce_motion", true)
		entry.prepare({"art": painting_art(), "art_size": Vector2(128, 72), "moulding": 8.0,
			"light": 1.0, "transform": Transform2D.IDENTITY}, null)
		entry.apply_progress(0.44)
		var effect := entry.get("_effect") as ShaderMaterial
		_check(not bool(entry.get("_composite").visible) and is_zero_approx(float(effect.get_shader_parameter("blur_pixels")))
			and is_zero_approx(float(effect.get_shader_parameter("exposure_stops"))), "reduced motion removes zoom, blur and exposure flash")
		entry.clear()
	current_scene.queue_free()
	await process_frame
	await process_frame
	print("OBRA_PAINTING_ENTRY_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(0 if failures == 0 else 1)


func _return_to_hall(manager: Node, profile: Node, hall_x: float) -> void:
	profile.call("load_profile")
	_check(is_equal_approx(float(profile.call("hall_position_x", -1.0)), hall_x),
		"the exact hall position survives reloading the saved profile")
	await create_timer(0.35).timeout
	if return_mode == "complete":
		current_scene.call("_complete_level")
		await create_timer(1.3, true).timeout
		current_scene.get_node("LevelCompleteOverlay/Root/Center/Panel/VBox/Buttons/ContinueButton").pressed.emit()
	else:
		current_scene.get_node("PauseMenu").call("open_pause")
		await create_timer(0.3, true).timeout
		current_scene.get_node("PauseMenu/PauseRoot/Panel/VBox/LevelSelectButton").pressed.emit()
	started_at = 0
	finished_at = 0
	var entry := manager.get_node("PaintingEntry")
	var targets := [0.15, 0.44, 0.72, 0.92]
	var index := 0
	var deadline := Time.get_ticks_msec() + 10000
	while bool(manager.call("is_transitioning")) and Time.get_ticks_msec() < deadline:
		await process_frame
		if visual and started_at > 0 and index < targets.size() \
				and float(entry.get("progress")) >= targets[index]:
			await _shot("%02d_return" % (11 + index))
			index += 1
	_check(finished_at > started_at and absf((finished_at - started_at) / 1000.0 - 1.0) < 0.08,
		"the reverse animation lasts 1 second (%.3f s)" % ((finished_at - started_at) / 1000.0))
	_check(current_scene != null and current_scene.scene_file_path == "res://levels/hub/hub.tscn",
		"the level returns into the hall")
	if current_scene == null or not current_scene.has_node("Apo"):
		quit(1)
		return
	_check(is_equal_approx((current_scene.get_node("Apo") as Node2D).position.x, hall_x),
		"the player returns to the exact saved position, rather than the first painting")
	if visual:
		await _shot("15_returned_hall")
		await create_timer(0.35, true).timeout
		await _shot("16_hall_ui")
		for capture in captures:
			(capture["image"] as Image).save_png("/tmp/obra_painting_%s.png" % capture["label"])
		captures.clear()


func painting_art() -> Texture2D:
	return load("res://assets/hub/paintings/level_1.png") as Texture2D


func _check_player_held() -> void:
	for player in get_nodes_in_group(&"player_character"):
		if player.is_physics_processing():
			_check(false, "incoming player moved before the reveal finished")


func _press(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = false
	Input.parse_input_event(event)


func _started(_destination: String) -> void:
	started_at = Time.get_ticks_msec()


func _finished(_destination: String) -> void:
	finished_at = Time.get_ticks_msec()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	# Compression is intentionally deferred: saving a retina PNG stalls the main thread
	# and would make the act of photographing the transition destroy its timing.
	captures.append({"label": label, "image": root.get_texture().get_image()})
