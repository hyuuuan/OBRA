extends SceneTree
## What the playtest records beyond the recognition itself (thesis §4.10.3, Table 14):
##   * a once-a-second performance sample -- frame rate and memory -- for the whole session;
##   * every recognition record carries the obstacle it was made at, the tags asked for, the
##     hint tier, the frame rate across its own recognition window and the recogniser's
##     timing split;
##   * once the third hint has NAMED a class, that class is the record's intended label --
##     the only point at which the game knows what the player meant -- and the attempt that
##     solves the obstacle keeps it.
##   * a bird transformation with a weapon equipped keeps recording in the same session.
##
##   godot --headless --path game --script res://tests/run_playtest_telemetry_probe.gd

## Every check this probe makes. A script error that skips them must not pass as quiet.
const CHECKS := 11
const DRAWN_FIXTURES := preload("res://tests/drawn_like_people_fixtures.gd")

var failures := 0
var checked := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := (load("res://game_level.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(40):
		await physics_frame

	await create_timer(1.5).timeout
	var perf := _events("perf")
	_check(not perf.is_empty() and perf[-1].has("fps") and perf[-1].has("static_mb"),
		"the session samples frame rate and memory every second", "%d samples" % perf.size())

	var director := level.get("director") as LevelDirector
	var panel := level.get("draw_panel") as DrawPanel
	var obstacle := String(director.obstacle_ids()[0])
	director.enter_obstacle(obstacle)
	(director.get("_tier") as Dictionary)[obstacle] = 1
	level.call("_update_telemetry_context")
	var low: Dictionary = panel.telemetry_context.duplicate()
	(director.get("_tier") as Dictionary)[obstacle] = 3
	level.call("_update_telemetry_context")
	var named := director.clue_class(obstacle)
	var high: Dictionary = panel.telemetry_context
	_check(String(low.get("obstacle_id", "")) == obstacle and not low.has("intended_class"),
		"below the third hint, a record names the obstacle and no intended class", str(low))
	_check(not named.is_empty() and String(high.get("intended_class", "")) == named
		and int(high.get("hint_tier", 0)) == 3 and not (high.get("required_tags", []) as Array).is_empty(),
		"once the third hint names a class, that class is the intended label", str(high))

	panel.set("_submit_started_usec", Time.get_ticks_usec() - 200_000)
	panel.set("_submit_started_frame", Engine.get_frames_drawn() - 12)
	var record: Dictionary = panel.call("_with_context", {"timing": {"infer_ms": 3.0}},
		{"outcome": "accept", "entity": named})
	_check(String(record.get("intended_class", "")) == named and record.has("fps_during_submit")
		and float(record["fps_during_submit"]) > 0.0 and record.has("backend_timing"),
		"a recognition record carries the context, its own frame rate and the recogniser's timing",
		"fps %.1f" % float(record.get("fps_during_submit", -1.0)))

	var verdict := director.note_submission(named)
	_check(bool(verdict.get("solves", false)) and String(verdict.get("named_class", "")) == named,
		"the drawing that solves the obstacle keeps the class the hint named",
		"solves %s, named '%s'" % [verdict.get("solves"), verdict.get("named_class", "")])

	level.queue_free()
	await process_frame
	await _bird_while_holding_a_sword()

	if checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_PLAYTEST_TELEMETRY_OK")
		quit(0)
	else:
		print("OBRA_PLAYTEST_TELEMETRY_FAILED=%d" % failures)
		quit(1)


func _bird_while_holding_a_sword() -> void:
	root.get_node("LevelManager").set("current_level_id", "level_4")
	var level := (load("res://level_4.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(40):
		await physics_frame

	var panel := level.get("draw_panel") as DrawPanel
	var drawing := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	await _press_key(KEY_R)
	panel.client.entity_prediction_received.emit("sword", "Sword", 0.99, drawing, {})
	var held := level.get("_equipped_utility") as UtilityObject
	_check(held != null, "Dilim equips a drawn sword", "required to exercise the held-item swap")
	if held == null:
		return
	var item := held.item_data
	await _press_key(KEY_F)
	var wear := int(item.runtime_state.get("uses_left", 0))
	var world_items := level.get("world_item_root") as Node2D
	var telemetry := root.get_node("Telemetry")
	var session := String(telemetry.get("_session_path"))

	await _press_key(KEY_R)
	_check(panel.is_open() and paused, "R opens the drawing panel with a sword in hand", "before the bird reply")
	# Headless has no canvas capture. Deliver a deterministic reply at the client's signal.
	panel.set("_pending_strokes", DRAWN_FIXTURES.all()[0]["strokes"])
	panel.set("_submit_started_usec", Time.get_ticks_usec())
	panel.client.entity_prediction_received.emit("bird", "Bird", 0.99, drawing, {})
	await physics_frame
	_check(not panel.is_open() and not paused and level.get("player") is ActiveRagdollMorph
		and level.get("_current_form_id") == "bird", "the bird replaces the player and gameplay resumes",
		"form '%s', paused %s" % [level.get("_current_form_id"), paused])
	var sword_put_away: bool = level.get("_equipped_utility") == null \
		and (not is_instance_valid(held) or held.is_queued_for_deletion())

	# A loose tool has no inventory entry, so changing back must keep it in the world.
	var registry := level.get("registry") as EntityRegistry
	var loose := registry.instantiate_entity("axe") as UtilityObject
	world_items.add_child(loose)
	loose.apply_item_data(DrawnItemData.from_prediction("axe", "Axe", drawing, [], 0.0, registry.get_entity("axe")))
	level.call("_connect_utility", loose)
	loose.equip_to(level.get("player"))
	await _press_key(KEY_Q)
	_check(is_instance_valid(loose) and loose.get_parent() == world_items and not loose.freeze
		and level.get("_equipped_utility") == null
		and loose.get("_world_bounds") == level.get("environment").get("world_bounds"),
		"Q leaves a loose tool in the world with Dilim's bounds", "after changing back from bird")

	await _press_key(KEY_1)
	var reequipped := level.get("_equipped_utility") as UtilityObject
	_check(sword_put_away and level.get("player") is Wanderer and reequipped != null and reequipped.item_data == item
		and wear > 0 and wear < int(item.runtime_state.get("uses_total", 0))
		and int(item.runtime_state.get("uses_left", 0)) == wear,
		"Q and the slot key recover the same worn sword without a second copy", "%d swings left" % wear)

	var recognitions := _events("recognition")
	var spawns := _events("spawn")
	var reverts := _events("morph_reverted")
	_check(not session.is_empty() and String(telemetry.get("_session_path")) == session
		and not recognitions.is_empty() and recognitions[-1].get("entity") == "bird"
		and not spawns.is_empty() and spawns[-1].get("entity") == "bird"
		and not reverts.is_empty() and reverts[-1].get("from_entity") == "bird",
		"bird recognition, spawn and reversion share one telemetry session", "Level 4")


func _press_key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = keycode
		key.pressed = pressed
		Input.parse_input_event(key)
		await process_frame


func _events(kind: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var file := root.get_node("Telemetry").get("_file") as FileAccess
	if file == null:
		return found
	for line in FileAccess.get_file_as_string(file.get_path_absolute()).split("\n"):
		var event: Variant = JSON.parse_string(line) if not line.is_empty() else null
		if event is Dictionary and String(event.get("type", "")) == kind:
			found.append(event)
	return found


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
