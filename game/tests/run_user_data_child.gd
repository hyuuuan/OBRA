extends SceneTree
## A second test run, started by run_test_runs_probe while it is still going: it takes its own
## folder (which empties and sweeps), leaves a file in it, and ends. See user_data.gd.

const UserData := preload("res://scripts/user_data.gd")

func _initialize() -> void:
	var file := FileAccess.open(UserData.path("child.txt"), FileAccess.WRITE)
	if file != null:
		file.store_string(str(OS.get_process_id()))
		file.close()
	quit(0)
