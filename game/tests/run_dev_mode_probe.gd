extends SceneTree
## The flag opens the normal hub paintings, without changing the game's navigation.

const CHECKS := 26
var checked := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	checked += 1
	if not ok:
		failures += 1
	print("  %s  %s" % ["OK" if ok else "FAIL", what])


func _run() -> void:
	var profile := root.get_node("PlayerProfile")
	var manager := root.get_node("LevelManager")
	var dev_mode := root.get_node("DevMode")
	_check(bool(ProjectSettings.get_setting("debug/dev_mode/enabled", false)),
		"the shared project defaults to dev mode for normal launches")
	profile.set("_data", profile.call("_default_profile"))
	manager.set("transition_step_seconds", 0.0)
	_check(not bool(dev_mode.get("enabled")), "probes start with normal progression")
	_check(not bool(manager.call("is_unlocked", "level_5")), "Mayon is normally locked")
	var normal_title := root.title
	dev_mode.set("enabled", true)
	var indicator := dev_mode.get("_indicator") as Label
	_check(indicator != null and indicator.visible and indicator.text == "DEV MODE"
		and indicator.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the flag has a small, click-through indicator")
	_check(root.title == normal_title + " [DEV MODE]", "the window title identifies dev mode")
	for number in range(1, 6):
		_check(bool(manager.call("is_unlocked", "level_%d" % number)), "level %d is unlocked by the flag" % number)
	_check(not bool(manager.call("is_unlocked", "missing_level"))
		and not bool(manager.call("open_level", "missing_level")), "unknown levels are still refused")
	_check(not bool(profile.call("has_brush")) and not bool(manager.call("open_level", "level_5")),
		"the normal brush pickup still comes first")
	var data: Dictionary = profile.get("_data")
	_check((data["levels_unlocked"] as Array).is_empty() and (data["levels_completed"] as Array).is_empty(),
		"enabling the flag does not write progress")
	change_scene_to_file("res://ui/main_menu.tscn")
	await create_timer(0.8).timeout
	_check(not bool(current_scene.call("is_selector_open"))
		and (current_scene.get("play_button") as Button).text == "NEW GAME", "the normal title screen stays in use")
	await _capture("title")
	(current_scene.get("play_button") as Button).pressed.emit()
	await _arrive(manager, "res://levels/hub/hub.tscn")
	var hub := current_scene
	var paintings := get_nodes_in_group(&"paintings")
	_check(paintings.size() == 5, "Play opens the normal house with five paintings")
	var mayon: Node2D
	for painting in paintings:
		_check(not bool(painting.call("is_locked")), "the house shows its paintings unlocked")
		if String(painting.get("level_id")) == "level_5":
			mayon = painting as Node2D
	var apo := hub.get("_player") as Node2D
	var stand := hub.get("_stand") as Node2D
	apo.global_position.x = stand.global_position.x
	await create_timer(0.1).timeout
	_press(&"interact")
	await create_timer(0.1, true, false, true).timeout
	var acquired := hub.get_node("AcquiredOverlay")
	var deadline := Time.get_ticks_msec() + 8000
	while bool(acquired.call("is_busy")) and Time.get_ticks_msec() < deadline:
		await create_timer(0.05, true, false, true).timeout
	_check(not bool(acquired.call("is_busy")), "the brush acquisition card has finished before entering a painting")
	_check(bool(profile.call("has_brush")), "E at the stand takes the brush normally")
	_check(mayon != null, "Mayon's painting is present")
	if mayon != null:
		apo.global_position.x = mayon.global_position.x
		await create_timer(0.1).timeout
		await _capture("hub")
		_press(&"interact")
		await _arrive(manager, "res://level_5.tscn")
		_check(String(manager.get("current_level_id")) == "level_5", "E at Mayon's painting enters Mayon")
		await _capture("level")
		call_group(&"dialogue_box", &"hide_line")
		manager.call("return_to_house")
		await _arrive(manager, "res://levels/hub/hub.tscn")
	dev_mode.set("enabled", false)
	_check(not indicator.visible and root.title == normal_title
		and not bool(manager.call("is_unlocked", "level_5")),
		"disabling the flag restores the normal title, indicator and earned locks")
	profile.call("mark_level_completed", "level_4")
	_check(bool(manager.call("is_unlocked", "level_5")), "earned unlocks still work with the flag off")
	if checked != CHECKS:
		failures += 1
		push_error("Dev mode probe ran %d of %d checks" % [checked, CHECKS])
	print("OBRA_DEV_MODE_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(0 if failures == 0 else 1)


func _arrive(manager: Node, path: String) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		if current_scene != null and current_scene.scene_file_path == path \
				and not bool(manager.call("is_transitioning")):
			return
		await create_timer(0.05, true, false, true).timeout
	_check(false, "scene transition timed out: " + path)


func _press(action: StringName) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event.duplicate() as InputEventKey
			key.pressed = true
			Input.parse_input_event(key)
			key = key.duplicate() as InputEventKey
			key.pressed = false
			Input.parse_input_event(key)
			return


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/obra_dev_%s.png" % label)
