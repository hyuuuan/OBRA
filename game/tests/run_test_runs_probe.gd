extends SceneTree
## Test runs that overlap cannot disturb each other: each keeps its things in its own folder.
##
##   godot --headless --path game --script res://tests/run_test_runs_probe.gd
##
## The fault this guards: every --script run used to share user://test_runs and empty it when it
## started, and every git worktree shares that folder -- a probe in one worktree wiped the profile
## of a suite running in another. Proved here the way it happened: a second Godot run is started
## while this one holds a file, and the file must still be there when it has finished.


const UserData := preload("res://scripts/user_data.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var mine := UserData.path("mine.txt")
	_check(mine.begins_with("user://test_runs/%d/" % OS.get_process_id()),
		"a test run keeps its things in a folder of its own", mine)
	var file := FileAccess.open(mine, FileAccess.WRITE)
	file.store_string("still here")
	file.close()
	await _a_second_run_leaves_this_ones_things_alone(mine)
	await _only_ended_runs_are_swept()
	if failures == 0:
		print("OBRA_TEST_RUNS_OK")
		quit(0)
	else:
		print("OBRA_TEST_RUNS_FAILED=%d" % failures)
		quit(1)


func _a_second_run_leaves_this_ones_things_alone(mine: String) -> void:
	var child := OS.create_process(OS.get_executable_path(), ["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--script", "res://tests/run_user_data_child.gd"])
	var waited := 0.0
	while child > 0 and OS.is_process_running(child) and waited < 30.0:
		await create_timer(0.2).timeout
		waited += 0.2
	var child_file := "user://test_runs/%d/child.txt" % child
	var theirs_written := FileAccess.file_exists(child_file)
	_check(child > 0 and not OS.is_process_running(child) and FileAccess.file_exists(mine)
			and FileAccess.get_file_as_string(mine) == "still here",
		"a second run starting and ending beside this one leaves this one's things alone",
		"child %d ran %.1f s; mine.txt %s" % [child, waited,
			"intact" if FileAccess.file_exists(mine) else "GONE"])
	_check(theirs_written, "and it kept its own things in its own folder", child_file)


## A folder named for a process still running is kept; one for a process that has ended goes.
func _only_ended_runs_are_swept() -> void:
	var sleeper := OS.create_process("/bin/sleep", ["20"])
	var ended := OS.create_process("/usr/bin/true", [])
	var waited := 0.0
	while OS.is_process_running(ended) and waited < 5.0:
		await create_timer(0.1).timeout
		waited += 0.1
	for pid in [sleeper, ended]:
		DirAccess.make_dir_recursive_absolute("user://test_runs/%d" % pid)
		var marker := FileAccess.open("user://test_runs/%d/marker" % pid, FileAccess.WRITE)
		marker.store_string("x")
		marker.close()
	UserData.sweep_ended_runs()
	var live_kept := FileAccess.file_exists("user://test_runs/%d/marker" % sleeper)
	var dead_gone := not DirAccess.dir_exists_absolute("user://test_runs/%d" % ended)
	OS.kill(sleeper)
	_check(live_kept and dead_gone, "the sweep takes an ended run's folder, never a live one's",
		"live %s, ended %s" % ["kept" if live_kept else "SWEPT", "gone" if dead_gone else "LEFT"])


func _check(ok: bool, what: String, detail: String) -> void:
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
