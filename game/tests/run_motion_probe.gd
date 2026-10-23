extends SceneTree
## The game's motion (motion.gd) and the overlays that use it, headless:
##
##   godot --headless --path game --script res://tests/run_motion_probe.gd
##
## Each check gives the motion its own time to play out (the design's seconds, with room), so a
## change to a curve shows up as a check failing rather than as a hang.

var failures := 0
## Every check that ran, so one skipped by a script error is a failure rather than a silence.
var checked := 0
const CHECKS := 19
## Room past each motion's own length before it is looked at again.
const SETTLE := 0.25


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(120.0, true).timeout.connect(func() -> void:
		print("OBRA_MOTION_FAILED=watchdog")
		quit(2))
	await process_frame
	_reduce(false)
	await _a_pop_overshoots_and_settles()
	await _going_ends_hidden_and_put_back()
	await _it_moves_while_the_game_is_paused()
	await _reduced_motion_keeps_it_still()
	await _an_overlay_comes_and_goes()
	await _closed_and_reopened_at_once_it_stays_open()
	await _settings_keeps_the_choice()
	await _an_ink_jar_lifts_as_it_is_taken()
	await _a_scene_change_is_a_stroke_of_ink()
	await _with_motion_reduced_the_stroke_only_fades()
	_reduce(false)
	paused = false
	if checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_MOTION_OK")
		quit(0)
	else:
		print("OBRA_MOTION_FAILED=%d" % failures)
		quit(1)


func _a_pop_overshoots_and_settles() -> void:
	var box := _box()
	Motion.pop_in(box)
	var start := box.scale.x
	var most := 0.0
	var start_ms := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms < int((Motion.POP_SECONDS + SETTLE) * 1000.0):
		await process_frame
		most = maxf(most, box.scale.x)
	_check(start < 0.95 and box.modulate.a > 0.99 and is_equal_approx(box.scale.x, 1.0),
		"a pop comes in from smaller and settles whole", "from %.2f to %.2f, alpha %.2f" % [start, box.scale.x, box.modulate.a])
	_check(most > 1.0, "and overshoots on the way, the canvas's own pop", "largest %.3f" % most)
	box.queue_free()


func _going_ends_hidden_and_put_back() -> void:
	var box := _box()
	var gone := [false]
	Motion.leave(box, func() -> void:
		gone[0] = true
		box.visible = false)
	await _seconds(Motion.EXIT_SECONDS * 0.5)
	var mid := box.modulate.a
	await _seconds(Motion.EXIT_SECONDS * 0.5 + SETTLE)
	_check(mid < 0.95 and gone[0] and not box.visible, "going fades it and then it is gone", "alpha mid-way %.2f, done %s" % [mid, gone[0]])
	_check(is_equal_approx(box.modulate.a, 1.0) and is_equal_approx(box.scale.x, 1.0),
		"and put back whole, so the next entrance starts clean", "alpha %.2f scale %.2f" % [box.modulate.a, box.scale.x])
	box.queue_free()


func _it_moves_while_the_game_is_paused() -> void:
	var box := _box()
	paused = true
	Motion.pop_in(box)
	await _seconds(Motion.POP_SECONDS + SETTLE)
	_check(is_equal_approx(box.scale.x, 1.0) and box.modulate.a > 0.99,
		"a menu that pauses the game still animates", "scale %.2f alpha %.2f" % [box.scale.x, box.modulate.a])
	paused = false
	box.queue_free()


func _reduced_motion_keeps_it_still() -> void:
	_reduce(true)
	var box := _box()
	Motion.pop_in(box)
	var largest := 0.0
	var smallest := 9.0
	var start_ms := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms < int((Motion.QUICK_FADE + SETTLE) * 1000.0):
		await process_frame
		largest = maxf(largest, box.scale.x)
		smallest = minf(smallest, box.scale.x)
	_check(is_equal_approx(smallest, 1.0) and is_equal_approx(largest, 1.0) and box.modulate.a > 0.99,
		"with motion reduced it arrives by a fade, never scaling", "scale %.2f..%.2f alpha %.2f" % [smallest, largest, box.modulate.a])
	var before := box.position
	Motion.shake(box)
	Motion.pulse(box)
	await _seconds(Motion.SHAKE_SECONDS + SETTLE)
	_check(box.position == before and is_equal_approx(box.scale.x, 1.0),
		"and a shake or a pulse keeps still", "moved %s, scale %.2f" % [box.position - before, box.scale.x])
	_reduce(false)
	box.queue_free()


func _an_overlay_comes_and_goes() -> void:
	var overlay := _settings()
	var panel := overlay.call(&"_motion_panel") as Control
	var scrim := overlay.call(&"_motion_scrim") as ColorRect
	overlay.open()
	_check(overlay.is_open() and panel != null and scrim != null and panel.scale.x < 0.95 and scrim.modulate.a < 0.5,
		"an overlay opens at once, its panel popping and its scrim fading in",
		"open %s, panel %s, scrim %s" % [overlay.is_open(), panel.scale if panel else null, scrim.modulate.a if scrim else null])
	await _seconds(0.34 + SETTLE)
	_check(is_equal_approx(panel.scale.x, 1.0) and panel.modulate.a > 0.99 and scrim.modulate.a > 0.99,
		"and settles whole", "panel %.2f/%.2f scrim %.2f" % [panel.scale.x, panel.modulate.a, scrim.modulate.a])
	overlay.close()
	_check(not overlay.is_open() and not paused and overlay.visible,
		"closed, it is shut and the game unpaused at once, while it is still going",
		"open %s paused %s shown %s" % [overlay.is_open(), paused, overlay.visible])
	await _seconds(Motion.EXIT_SECONDS + SETTLE)
	_check(not overlay.visible, "and then it is gone", "shown %s" % overlay.visible)
	overlay.queue_free()


func _closed_and_reopened_at_once_it_stays_open() -> void:
	var overlay := _settings()
	overlay.open()
	await _seconds(0.34 + SETTLE)
	overlay.close()
	await process_frame
	overlay.open()
	await _seconds(0.34 + SETTLE)
	var panel := overlay.call(&"_motion_panel") as Control
	_check(overlay.is_open() and overlay.visible and panel.modulate.a > 0.99 and is_equal_approx(panel.scale.x, 1.0),
		"closed and opened again at once, it stays open and whole -- the old exit does not hide it",
		"open %s shown %s alpha %.2f" % [overlay.is_open(), overlay.visible, panel.modulate.a])
	# Shut before it goes, or the game is left paused under an overlay nobody can see.
	overlay.close()
	overlay.queue_free()


func _settings_keeps_the_choice() -> void:
	var overlay := _settings()
	overlay.open()
	var toggle := overlay.get_node_or_null(^"Root/Center/Panel/VBox/ReduceMotionToggle") as CheckButton
	_check(toggle != null and toggle.text == "Reduce motion", "Settings has a Reduce motion switch", "found %s" % toggle)
	if toggle != null:
		toggle.button_pressed = true
	_check(Motion.reduced(), "and switching it on is kept, and every motion asks it", "reduced %s" % Motion.reduced())
	overlay.close()
	overlay.queue_free()
	_reduce(false)


## LevelManager's transition: one stroke across until the screen is ink, the scene swapped under
## it, and the stroke on past. Watched frame by frame, to the main menu.
func _a_scene_change_is_a_stroke_of_ink() -> void:
	var manager := root.get_node(^"LevelManager")
	manager.set("transition_step_seconds", 0.012)
	var before := current_scene
	var seen := await _watch_a_transition(manager)
	_check(seen["rose"] and seen["swapped_at"] >= 0.999 and seen["end"] >= 1.999 and not seen["transitioning"],
		"a scene change sweeps a stroke of ink across, swaps the scene under it and sweeps on",
		"rose %s, swapped at %.2f, ended at %.2f, still going %s" % [seen["rose"], seen["swapped_at"], seen["end"], seen["transitioning"]])
	_check(seen["blocked"], "and nothing can be clicked while it crosses", "blocked %s" % seen["blocked"])
	_check(current_scene != before and seen["seconds"] >= 2.0 * 0.5 - 0.1,
		"and it takes its time each way", "%.2f s" % seen["seconds"])


func _with_motion_reduced_the_stroke_only_fades() -> void:
	_reduce(true)
	var manager := root.get_node(^"LevelManager")
	var seen := await _watch_a_transition(manager)
	_check(seen["most_mid_sweep"] == 0 and seen["faded"] and not seen["transitioning"],
		"with motion reduced, the stroke never sweeps -- the screen fades through ink",
		"frames mid-sweep %d, faded %s" % [seen["most_mid_sweep"], seen["faded"]])
	_reduce(false)


func _watch_a_transition(manager: Node) -> Dictionary:
	var seen := {"rose": false, "swapped_at": -1.0, "end": 0.0, "transitioning": true, "blocked": true,
		"seconds": 0.0, "most_mid_sweep": 0, "faded": false}
	var scene_before := current_scene
	var stroke := manager.get_node(^"InkTransitionLayer/InkTransition/Stroke") as ColorRect
	var cover := manager.get_node(^"InkTransitionLayer/InkTransition") as Control
	var start_ms := Time.get_ticks_msec()
	manager.call(&"_transition_to", "res://ui/main_menu.tscn", "")
	var last := 0.0
	while Time.get_ticks_msec() - start_ms < 6000:
		await process_frame
		var progress := float(manager.call(&"wipe_progress"))
		if progress > 0.05 and progress < 0.95:
			seen["rose"] = true
			seen["most_mid_sweep"] = int(seen["most_mid_sweep"]) + 1
		if stroke.modulate.a < 0.95 and stroke.modulate.a > 0.05:
			seen["faded"] = true
		if bool(manager.call(&"is_transitioning")) and cover.mouse_filter != Control.MOUSE_FILTER_STOP:
			seen["blocked"] = false
		if current_scene != scene_before and float(seen["swapped_at"]) < 0.0:
			seen["swapped_at"] = last
		last = progress
		if not bool(manager.call(&"is_transitioning")):
			break
	seen["seconds"] = (Time.get_ticks_msec() - start_ms) / 1000.0
	seen["end"] = float(manager.call(&"wipe_progress"))
	seen["transitioning"] = bool(manager.call(&"is_transitioning"))
	return seen


func _an_ink_jar_lifts_as_it_is_taken() -> void:
	paused = false
	var jar := InkJar2D.new()
	jar.position = Vector2(300.0, 300.0)
	root.add_child(jar)
	await process_frame
	jar.take()
	var highest := jar.position.y
	var largest := 1.0
	var start_ms := Time.get_ticks_msec()
	while is_instance_valid(jar) and Time.get_ticks_msec() - start_ms < 500:
		highest = minf(highest, jar.position.y)
		largest = maxf(largest, jar.scale.x)
		await process_frame
	_check(highest < 300.0 - 12.0 and largest > 1.1, "an ink jar lifts and swells as it is taken",
		"rose %.0f px, swelled to %.2f" % [300.0 - highest, largest])


func _settings() -> ModalOverlay:
	var overlay := (load("res://ui/settings_overlay.tscn") as PackedScene).instantiate() as ModalOverlay
	root.add_child(overlay)
	return overlay


func _box() -> Control:
	var box := ColorRect.new()
	box.size = Vector2(120.0, 60.0)
	box.position = Vector2(200.0, 200.0)
	root.add_child(box)
	return box


func _reduce(on: bool) -> void:
	var profile := root.get_node_or_null(^"PlayerProfile")
	if profile != null:
		profile.call(&"set_setting", "reduce_motion", on)


func _seconds(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
