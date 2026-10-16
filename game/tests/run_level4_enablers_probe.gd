extends SceneTree
## The generic pieces Dilim needs from the levels before it, each off for Levels 1-3:
## a level with no companion, a level that speaks in its own voice, a level tallied by majority,
## the three tags its encounters ask for, and its hidden flower.
##
##   godot --headless --path game --script res://tests/run_level4_enablers_probe.gd

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_a_dialogue_file_names_its_own_speaker()
	await _a_level_can_go_without_lolo()
	await _a_level_can_be_tallied_by_majority()
	_dilims_tags_are_there()
	if failures == 0:
		print("OBRA_L4_ENABLERS_OK")
		quit(0)
	else:
		print("OBRA_L4_ENABLERS_FAILED=%d" % failures)
		quit(1)


func _a_dialogue_file_names_its_own_speaker() -> void:
	var path := "user://enablers_probe_dialogue.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"level_id": "level_x", "speaker_default": "apo",
		"lines": [{"id": "a", "at": "x", "text": "I remember this."}]}))
	file.close()
	var own := DialogueScript.new()
	own.load_from(path)
	var payyo := DialogueScript.new()
	payyo.load_from("res://config/dialogue_l1.json")
	var unmarked := own.line_by_id("a")
	_check(own.speaker_of(unmarked) == "apo" and payyo.speaker_of({"text": "-"}) == "lolo",
		"a line that names no speaker is said by its file's speaker_default",
		"apo in a file that says so, lolo in Payyo's")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _a_level_can_go_without_lolo() -> void:
	var with_him := await _open_level(null)
	var visits_before := int(_profile().call("level_visits", _level_id()))
	_check(with_him.get("lolo") != null, "Payyo as it is has Lolo", "present")
	with_him.call("_say_why", "Back to the terraces.")
	var hint := with_him.get("hint_bar") as HintBar
	_check(hint != null and hint.current_speaker() == _shown(Lolo.SPEAKER),
		"and he says its notes", hint.current_speaker() if hint != null else "-")
	with_him.queue_free()
	await _frames(3)
	var alone := GDScript.new()
	alone.source_code = "extends \"res://scripts/game_level.gd\"\n" \
		+ "func _has_companion() -> bool:\n\treturn false\n" \
		+ "func _companion_speaker() -> String:\n\treturn APO_SPEAKER\n"
	alone.reload()
	# Openings are off in test runs unless asked for (see run_opening_probe); this one is the point.
	var level := await _open_level(alone, true)
	_check(level.get("lolo") == null, "a level told it goes alone has no Lolo", "absent")
	_check(int(_profile().call("level_visits", _level_id())) > visits_before,
		"and its opening still plays: the visit is recorded", "visits %d" % _profile().call("level_visits", _level_id()))
	# Her opening is said rather than skipped: lines spoken with nobody beside her to say them.
	var script_lines = level.get("script_lines")
	var spoken := 0
	for _frame in range(180):
		await physics_frame
		if root.get_tree().paused:
			call_group(DialogueBox.GROUP, &"hide_line")
			paused = false
		spoken = int(script_lines.call("lines_spoken"))
		if spoken > 0:
			break
	_check(spoken > 0, "and its opening is said, with nobody beside her to say it",
		"%d line(s) spoken" % spoken)
	level.call("_say_why", "Back to the terraces.")
	var her_hint := level.get("hint_bar") as HintBar
	_check(her_hint != null and her_hint.current_speaker() == _shown(String(level.get("APO_SPEAKER"))),
		"and its notes are in her own voice", her_hint.current_speaker() if her_hint != null else "-")
	level.queue_free()
	await _frames(3)


func _a_level_can_be_tallied_by_majority() -> void:
	var level := await _open_level(null)
	var director = level.get("director")
	var obstacles: Array = []
	for obstacle: Dictionary in (director.call("level_data") as Dictionary).get("obstacles", []):
		if (obstacle.get("routes", {}) as Dictionary).size() >= 2:
			obstacles.append(obstacle)
	var counts_before: Dictionary = (_profile().call("route_counts") as Dictionary).duplicate()
	# Payyo told it is tallied by majority, without a new level to say it.
	director.set(&"_level", (director.call("level_data") as Dictionary).merged({"tally": "majority"}, true))
	var committed: Array[String] = []
	for obstacle: Dictionary in obstacles.slice(0, 3):
		var routes: Array = (obstacle["routes"] as Dictionary).keys()
		var route := String(routes[0]) if committed.size() != 1 else String(routes[routes.size() - 1])
		director.call("commit_route", String(obstacle["id"]), route)
		committed.append(route)
	var unchanged: bool = (_profile().call("route_counts") as Dictionary) == counts_before
	var settled := String(director.call("settle_majority_route"))
	_check(obstacles.size() >= 3 and unchanged and settled == committed[0],
		"tallied by majority, a commit gives the ending nothing yet, and the most-taken route is settled",
		"committed %s, settled %s, counts unchanged %s" % [committed, settled, unchanged])
	level.call("_complete_level")
	await _frames(2)
	var after: Dictionary = (_profile().call("route_counts") as Dictionary)
	_check(int(after.get(settled, 0)) == int(counts_before.get(settled, 0)) + 1,
		"and finishing the level gives the ending exactly that one point",
		"%s: %d -> %d" % [settled, int(counts_before.get(settled, 0)), int(after.get(settled, 0))])
	level.queue_free()
	await _frames(3)
	var tie := LevelDirector.new()
	tie.set(&"_level", {"tally": "majority"})
	tie.set(&"_committed", {"a": "artist", "b": "protector"})
	_check(tie.settle_majority_route() == "protector", "a tie goes to the most recent",
		tie.settle_majority_route())
	tie.free()


func _dilims_tags_are_there() -> void:
	var tags: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://config/tags.json"))
		as Dictionary).get("tags", {})
	var hoof: Dictionary = (tags.get("hoof", {}) as Dictionary).get("classes", {})
	var beast: Dictionary = (tags.get("beast", {}) as Dictionary).get("classes", {})
	var absurd: Dictionary = (tags.get("absurd", {}) as Dictionary).get("classes", {})
	_check(hoof.has("horse") and hoof.has("pig") and beast.size() == 20
			and absurd.keys().all(func(id: String) -> bool: return id in ["fish", "shark", "octopus", "sailboat", "submarine"])
			and absurd.size() == 5 and int((tags["absurd"] as Dictionary).get("unlocked_in_level", 0)) == 4,
		"Dilim's tags: hoof, beast (every creature) and absurd (the sea, in a forest)",
		"%d / %d / %d classes" % [hoof.size(), beast.size(), absurd.size()])


func _shown(speaker: String) -> String:
	return "%s:" % speaker.to_upper()


## The autoloads, through the tree: a --script runner compiles this before any of them exists.
func _profile() -> Node:
	return root.get_node(^"PlayerProfile")


func _level_id() -> String:
	return String(root.get_node(^"LevelManager").get(&"current_level_id"))


func _open_level(script: GDScript, with_opening: bool = false) -> Node:
	var level := (load("res://game_level.tscn") as PackedScene).instantiate()
	if script != null:
		level.set_script(script)
	if with_opening:
		level.set(&"intro_enabled", true)
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
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
