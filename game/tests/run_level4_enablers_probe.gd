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
