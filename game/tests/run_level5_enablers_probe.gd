extends SceneTree
## What Mayon needs from the shared code, each off by default: a hidden ink reserve only the
## level's gates may draw on, silent saves, an ink gauge that never steps aside, a level that ends
## with its own scene (the run's ending still logged), Lolo fading and gone in one frame, the
## route the run leaned toward, and the fifth flower.
##
##   godot --headless --path game --script res://tests/run_level5_enablers_probe.gd

## Every check this probe makes. A script error that skips them must not pass as quiet.
const CHECKS := 11

var failures := 0
var checked := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_the_reserve_pays_only_who_may_ask()
	await _a_level_may_pay_its_gates_from_the_reserve()
	await _a_silent_level_saves_without_a_word()
	await _the_gauge_never_steps_aside_where_ink_is_the_story()
	await _a_level_can_end_with_its_own_scene()
	await _lolo_fades_and_goes_in_one_frame()
	_the_run_leans_toward_its_most_taken_route()
	_the_fifth_flower_counts()
	if checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_LEVEL5_ENABLERS_OK")
		quit(0)
	else:
		print("OBRA_LEVEL5_ENABLERS_FAILED=%d" % failures)
		quit(1)


func _the_reserve_pays_only_who_may_ask() -> void:
	var ink := InkManager.new()
	root.add_child(ink)
	ink.committed = ink.capacity
	ink.hidden_reserve = 1.0
	var plain := ink.spend_unit()
	var asked := ink.spend_unit(true)
	var again := ink.spend_unit(true)
	_check(not plain and asked and not again and is_zero_approx(ink.remaining())
		and is_zero_approx(ink.hidden_reserve),
		"the hidden reserve pays only a caller who asks, never shows, and runs out",
		"plain %s, asked %s, asked again %s, gauge %.1f, reserve %.1f" % [plain, asked, again,
			ink.remaining(), ink.hidden_reserve])
	ink.queue_free()


func _a_level_may_pay_its_gates_from_the_reserve() -> void:
	# A tool drawn with the gauge empty: refused where the level does not allow the reserve,
	# taken where it does, and the reserve is what paid. Two different tools -- a refused one is
	# still the player's class for later, and would come free the second time.
	var results: Array[bool] = []
	var restored := -1.0
	for allowed in [false, true]:
		var level := await _open_level(_level_saying("_may_use_hidden_ink") if allowed else null)
		var ink := level.get("ink_manager") as InkManager
		ink.committed = ink.capacity
		ink.hidden_reserve = 1.0
		if allowed:
			level.call("_write_checkpoint", "probe")
		var tool := "axe" if allowed else "sword"
		_draw(level, tool)
		await _frames(4)
		results.append(int(level.call("_slot_holding", tool)) >= 0)
		if allowed:
			results.append(is_zero_approx(ink.hidden_reserve))
			# A fall back to the checkpoint gives the reserve back, like the rest of the ink.
			level.call("_restore_checkpoint")
			await _frames(2)
			restored = ink.hidden_reserve
		level.queue_free()
		await _frames(3)
	_check(results == [false, true, true],
		"a level that allows it pays its drawing from the reserve when the gauge is empty",
		"kept without leave %s, with leave %s, reserve spent %s" % [results[0], results[1], results[2]])
	_check(is_equal_approx(restored, 1.0), "a fall back to the checkpoint gives the reserve back",
		"reserve after the restore %.1f" % restored)


func _a_silent_level_saves_without_a_word() -> void:
	var said: Array[String] = []
	var saved: Array[int] = []
	var chip: Array[bool] = []
	for silent in [false, true]:
		var level := await _open_level(_level_saying("_saves_silently") if silent else null)
		var director := level.get("director") as LevelDirector
		var first: Variant = (director.level_data().get("checkpoints", []) as Array)[0]
		var id := String((first as Dictionary).get("id", "")) if first is Dictionary else String(first)
		var checkpoints: Object = level.get("checkpoints")
		var before: int = checkpoints.call("count")
		(level.get("status_label") as Label).text = ""
		level.call("_on_checkpoint_area_reached", id)
		await _frames(2)
		said.append((level.get("status_label") as Label).text)
		saved.append(int(checkpoints.call("count")) - before)
		chip.append((level.get("checkpoint_label") as Label).visible)
		level.queue_free()
		await _frames(3)
	_check(said[0] == "Checkpoint" and said[1] == "" and saved == [1, 1] and chip == [true, false],
		"a silent level writes its checkpoint and says and counts nothing",
		"said '%s' / '%s', written %s, count shown %s" % [said[0], said[1], saved, chip])


func _the_gauge_never_steps_aside_where_ink_is_the_story() -> void:
	var alphas: Array[float] = []
	for always in [false, true]:
		var level := await _open_level(_level_saying("_ink_always_visible") if always else null)
		level.set("_curtain_closed", 1.0)
		level.call("_apply_hud_alpha")
		alphas.append((level.get("hud_panel") as CanvasItem).modulate.a)
		level.queue_free()
		await _frames(3)
	_check(is_zero_approx(alphas[0]) and is_equal_approx(alphas[1], 1.0),
		"with the bars closed the ink plate steps aside, except where ink is the story",
		"ordinary %.2f, always shown %.2f" % [alphas[0], alphas[1]])


func _a_level_can_end_with_its_own_scene() -> void:
	var script := GDScript.new()
	script.source_code = "extends \"res://scripts/game_level.gd\"\nvar played := false\n" \
		+ "func _ends_with_its_own_scene() -> bool:\n\treturn true\n" \
		+ "func _play_own_ending() -> void:\n\tplayed = true\n"
	script.reload()
	var level := await _open_level(script)
	var manager := root.get_node("LevelManager")
	var was: String = manager.get("current_level_id")
	# The level the run ends on, so the ending is logged.
	var last := ""
	for entry: Dictionary in manager.call("get_levels"):
		if bool(entry.get("ends_run", false)):
			last = String(entry["id"])
	manager.set("current_level_id", last)
	level.call("_complete_level")
	await create_timer(1.6).timeout
	var overlay := level.get("complete_overlay") as CanvasLayer
	var profile := root.get_node("PlayerProfile")
	var finished: bool = profile.call("is_level_completed", last)
	var telemetry := root.get_node("Telemetry")
	var path := String(telemetry.get("_session_path"))
	var log_text := FileAccess.get_file_as_string(path) if not path.is_empty() else ""
	_check(bool(level.get("played")) and not overlay.visible and finished,
		"a level that ends with its own scene plays it, and no completion card comes",
		"played %s, card shown %s, %s recorded finished %s" % [level.get("played"), overlay.visible,
			last, finished])
	_check(log_text.contains("\"type\":\"ending\"") and log_text.contains("\"ending\":"),
		"the run's ending is still worked out and logged for the thesis",
		"ending event in the session log: %s" % log_text.contains("\"type\":\"ending\""))
	manager.set("current_level_id", was)
	level.queue_free()
	await _frames(3)


func _lolo_fades_and_goes_in_one_frame() -> void:
	var lolo := (load("res://creatures/lolo.tscn") as PackedScene).instantiate() as Lolo
	root.add_child(lolo)
	await process_frame
	lolo.set_thinness(0.6)
	var figure := lolo.get_node("Figure") as CanvasItem
	var material := figure.material as ShaderMaterial
	var parts := true
	for item in figure.find_children("*", "CanvasItem", true, false):
		parts = parts and (item as CanvasItem).use_parent_material
	_check(material != null and is_equal_approx(lolo.thinness(), 0.6) and parts,
		"lolo thins: his whole figure wears the fade",
		"thinness %.2f, parts share it %s" % [lolo.thinness(), parts])
	lolo.vanish()
	var gone_now := not lolo.visible and lolo.is_gone()
	_check(gone_now and lolo.modulate.a == 1.0,
		"he is gone in the same frame, with no fade",
		"hidden at once %s, faded %s" % [gone_now, lolo.modulate.a < 1.0])
	lolo.queue_free()


func _the_run_leans_toward_its_most_taken_route() -> void:
	var profile := root.get_node("PlayerProfile")
	profile.call("reset_progress")
	var none: String = profile.call("dominant_route")
	for route in ["artist", "protector", "artist", "protector"]:
		profile.call("record_route", "level_1", route)
	var tied: String = profile.call("dominant_route")
	profile.call("record_route", "level_2", "pragmatist")
	var tied_then_other: String = profile.call("dominant_route")
	profile.call("record_route", "level_3", "artist")
	var ahead: String = profile.call("dominant_route")
	_check(none == "" and tied == "protector" and tied_then_other == "protector" and ahead == "artist",
		"the run leans toward its most taken route, and a tie toward the one taken last",
		"none '%s', tied '%s', tied then another '%s', one ahead '%s'" % [none, tied,
			tied_then_other, ahead])
	profile.call("reset_progress")


func _the_fifth_flower_counts() -> void:
	var profile := root.get_node("PlayerProfile")
	var found := false
	for entry: Dictionary in InventoryScreen.FOUND:
		found = found or (entry["id"] == "L5_HF" and entry["stack"] == "hidden_flower")
	for id: String in PlayerProfile.FLOWER_IDS:
		profile.call("record_collectible", id)
	var count: int = profile.call("flower_count")
	_check(found and count == 5, "Mayon's flower is the fifth, and five can be found",
		"in the satchel's list %s, counted %d" % [found, count])
	profile.call("reset_progress")


func _draw(level: Node, entity: String) -> void:
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	level.call("_on_drawing_ready", entity, entity.capitalize(), sheet, {"confidence": 0.9},
		[{"points": PackedVector2Array([Vector2(0, 0), Vector2(0, 80)]), "width": 6.0,
			"color": Color.BLACK}], 1.0)


## Payyo, told one hook says yes.
func _level_saying(hook: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = "extends \"res://scripts/game_level.gd\"\nfunc %s(_a = null) -> bool:\n\treturn true\n" % hook
	script.reload()
	return script


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
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
