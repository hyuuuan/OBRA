extends SceneTree
## What the playtest records beyond the recognition itself (thesis §4.10.3, Table 14):
##   * a once-a-second performance sample -- frame rate and memory -- for the whole session;
##   * every recognition record carries the obstacle it was made at, the tags asked for, the
##     hint tier, the frame rate across its own recognition window and the recogniser's
##     timing split;
##   * once the third hint has NAMED a class, that class is the record's intended label --
##     the only point at which the game knows what the player meant -- and the attempt that
##     solves the obstacle keeps it.
##
##   godot --headless --path game --script res://tests/run_playtest_telemetry_probe.gd

## Every check this probe makes. A script error that skips them must not pass as quiet.
const CHECKS := 5

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

	if checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_PLAYTEST_TELEMETRY_OK")
		quit(0)
	else:
		print("OBRA_PLAYTEST_TELEMETRY_FAILED=%d" % failures)
		quit(1)


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
