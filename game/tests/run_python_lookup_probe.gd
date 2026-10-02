extends SceneTree
## The game finds the backend's Python on Windows as well as on a Mac.
##
##   godot --headless --path game --script res://tests/run_python_lookup_probe.gd
##
## Kent's teammates on Windows: "the game is not playable in their end". The game starts the
## sketch backend itself, with the venv's interpreter -- and it only ever looked for
## `.venv/bin/python`, which a Windows venv does not have (`Scripts\python.exe`). It fell
## through to `python3`, the Microsoft Store's stand-in on most Windows machines, and the
## backend never came up. Asked here of a venv laid out each way, on whatever machine runs it.

const UserData := preload("res://scripts/user_data.gd")

var results: Array[String] = []
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	results.append("  %s  %-52s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	print("\n===== WHICH PYTHON =====")
	var root_dir := ProjectSettings.globalize_path(UserData.path("python_lookup"))
	var windows_venv := root_dir.path_join("windows/.venv")
	var unix_venv := root_dir.path_join("unix/.venv")
	var empty_venv := root_dir.path_join("empty/.venv")
	_touch(windows_venv.path_join("Scripts/python.exe"))
	_touch(unix_venv.path_join("bin/python"))
	DirAccess.make_dir_recursive_absolute(empty_venv)

	var found := BackendSupervisor.python_in(windows_venv, true)
	_check(found == windows_venv.path_join("Scripts/python.exe"),
		"a Windows venv: Scripts\\python.exe", found)
	found = BackendSupervisor.python_in(unix_venv, false)
	_check(found == unix_venv.path_join("bin/python"), "a Mac or Linux venv: bin/python", found)
	found = BackendSupervisor.python_in(empty_venv, true)
	_check(found == "python", "no venv on Windows: python, not the Store's python3", found)
	found = BackendSupervisor.python_in(empty_venv, false)
	_check(found == "python3", "no venv elsewhere: python3", found)

	# And this checkout, on this machine, the way the game asks.
	var supervisor := BackendSupervisor.new()
	var here := String(supervisor.call("_resolve_python_executable"))
	supervisor.free()
	var expected := BackendSupervisor.python_in(
		ProjectSettings.globalize_path("res://").path_join("../.venv").simplify_path(),
		OS.has_feature("windows"))
	_check(here == expected and (here.ends_with("python.exe") or here.ends_with("python")
			or here.ends_with("python3")), "this checkout resolves the same way", here)

	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_PYTHON_LOOKUP_OK")
		quit(0)
	else:
		print("OBRA_PYTHON_LOOKUP_FAILED=%d" % failures)
		quit(1)


func _touch(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("")
	file.close()
