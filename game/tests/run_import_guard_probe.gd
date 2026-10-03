extends SceneTree
## A stale import cache is noticed, and a current one is left alone.
##
##   godot --headless --path game --script res://tests/run_import_guard_probe.gd
##
## Kent: "the game cache when ran into a different device is a bit buggy like it stacks". Every
## machine builds its own `game/.godot`, and a game run on one built for an older checkout fails
## to load new art and fails to compile scripts that name new classes, every frame. ImportGuard
## checks for that before anything else loads and re-imports. This holds what it calls stale --
## on a small project built here, where each way of going stale can be made on purpose -- and
## that the real project, freshly imported, is not called stale at all, because a guard that
## misfires imports and restarts the game on every launch.

const Guard = preload("res://scripts/import_guard.gd")
const UserData = preload("res://scripts/user_data.gd")
const HASH := "0123456789abcdef0123456789abcdef"

var failures := 0
var results: Array[String] = []
var project := ""


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	results.append("  %s  %-54s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	print("\n===== THE IMPORT CACHE =====")
	_this_project_is_current()
	await _a_small_project_goes_stale()
	_the_relaunch_finds_the_project()
	await _the_game_opens_on_a_scene_that_always_loads()
	for line in results:
		print(line)
	print("OBRA_IMPORT_GUARD_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)


## The checkout this runs in has just been imported, so nothing in it is stale -- and asking
## must be cheap, because every launch asks.
func _this_project_is_current() -> void:
	var started := Time.get_ticks_usec()
	var reasons := Guard.stale_reasons()
	var took := (Time.get_ticks_usec() - started) / 1000.0
	_check(reasons.is_empty(), "this project, freshly imported, is current",
		"nothing stale" if reasons.is_empty() else "%d: %s" % [reasons.size(), reasons[0]])
	_check(took < 1000.0, "and asking takes well under a second", "%.0f ms" % took)


func _a_small_project_goes_stale() -> void:
	project = UserData.path("import_guard/project")
	_wipe(project)
	_write("art/a.png", "A1")
	_import("art/a.png", "A1")
	_write("scripts/thing.gd", "class_name Thing\nextends Node\n")
	# Not imported, and not supposed to be: a folder Godot is told to leave alone.
	_write("source/.gdignore", "")
	_write("source/reference.png", "R")
	_write("source/reference.png.import",
		'[deps]\ndest_files=["res://.godot/imported/reference.png-%s.ctex"]\n' % HASH)
	var classes: Array[Dictionary] = [_class("Thing", "res://scripts/thing.gd")]
	var now := Guard.stale_reasons(project, classes)
	_check(now.is_empty(), "a project just imported is current",
		"nothing stale" if now.is_empty() else ", ".join(now))

	# A checkout rewrites a file whose bytes did not change. The time says stale; the hash
	# says not, and the hash is right -- the import would not redo it.
	await create_timer(1.1).timeout
	_write("art/a.png", "A1")
	now = Guard.stale_reasons(project, classes)
	_check(now.is_empty(), "a file rewritten with the same bytes is not stale",
		"nothing stale" if now.is_empty() else ", ".join(now))

	_write("art/a.png", "A2")
	now = Guard.stale_reasons(project, classes)
	_check(_says(now, "art/a.png changed after it was imported"),
		"a file changed since it was imported is stale", ", ".join(now))
	_import("art/a.png", "A2")

	_write("art/b.png", "B")
	_write("art/b.png.import",
		'[deps]\ndest_files=["res://.godot/imported/b.png-%s.ctex"]\n' % HASH.reverse())
	now = Guard.stale_reasons(project, classes)
	_check(_says(now, "art/b.png has not been imported"),
		"a new file nobody has imported is stale", ", ".join(now))
	_import("art/b.png", "B")
	now = Guard.stale_reasons(project, classes)
	_check(now.is_empty(), "and once it is imported, it is current",
		"nothing stale" if now.is_empty() else ", ".join(now))

	_write("scripts/other.gd", "extends Node\nclass_name Other\n")
	now = Guard.stale_reasons(project, classes)
	_check(_says(now, "the class table does not know Other"),
		"a new class the table does not know is stale", ", ".join(now))
	classes.append(_class("Other", "res://scripts/other.gd"))

	classes.append(_class("Gone", "res://scripts/gone.gd"))
	now = Guard.stale_reasons(project, classes)
	_check(_says(now, "the class table still lists Gone, whose script is gone"),
		"a class whose script was deleted is stale", ", ".join(now))
	classes.pop_back()
	now = Guard.stale_reasons(project, classes)
	_check(now.is_empty(), "and the folder Godot ignores is never asked about",
		"nothing stale" if now.is_empty() else ", ".join(now))


## The game starts again at the project's full path -- it changes into the project folder as it
## starts, so a relative `--path game` would point at game/game -- with what it was given, and
## marked as the second try so it cannot loop.
func _the_relaunch_finds_the_project() -> void:
	var args := Guard.relaunch_args(PackedStringArray(["--path", "game", "--fullscreen", "--", "--x"]),
		PackedStringArray(["--x"]), false)
	var expected := PackedStringArray(["--path", Guard.project_dir(), "--fullscreen", "--", "--x",
		Guard.RELAUNCHED])
	_check(args == expected, "the relaunch is the same launch, at the full path, marked",
		" ".join(args))
	# The engine keeps --headless to itself, so a headless run has to be told it was one.
	args = Guard.relaunch_args(PackedStringArray(["res://game_level.tscn"]), PackedStringArray(), true)
	expected = PackedStringArray(["--path", Guard.project_dir(), "--headless", "res://game_level.tscn",
		"--", Guard.RELAUNCHED])
	_check(args == expected, "and a headless run restarts headless", " ".join(args))
	# And none of it during a suite: the autoloads load under --script too.
	_check(not Guard.wants_checking(PackedStringArray(["--script", "res://tests/x.gd"])),
		"a test suite is never checked or restarted", "--script")
	_check(Guard.wants_checking(PackedStringArray(["res://game_level.tscn"])),
		"and a game run from source is", "res://game_level.tscn")


## A fresh clone has no cache at all, so a first scene made of imported art cannot load, and
## Godot quits before ImportGuard -- an autoload -- ever runs. The game opens on a scene that
## needs nothing imported, and that scene goes on to the title screen.
func _the_game_opens_on_a_scene_that_always_loads() -> void:
	var boot := String(ProjectSettings.get_setting("application/run/main_scene"))
	_check(boot == "res://ui/boot.tscn", "the game opens on the boot scene", boot)
	var scene := FileAccess.get_file_as_string(boot)
	var resources := RegEx.create_from_string('\\[ext_resource[^\\]]*path="([^"]+)"').search_all(scene)
	var paths := resources.map(func(m: RegExMatch) -> String: return m.get_string(1))
	var script := FileAccess.get_file_as_string("res://scripts/boot.gd")
	var declares := RegEx.create_from_string("(?m)^\\s*(class_name|const\\s+\\w+\\s*=\\s*preload)").search(script)
	_check(paths == ["res://scripts/boot.gd"] and declares == null,
		"which needs nothing imported to load", ", ".join(paths))
	change_scene_to_file(boot)
	for _frame in range(10):
		await process_frame
	var now := current_scene.scene_file_path if current_scene != null else "(none)"
	_check(now == "res://ui/main_menu.tscn", "and goes straight on to the title screen", now)


func _says(reasons: PackedStringArray, reason: String) -> bool:
	return reasons.has(reason)


func _class(name: String, path: String) -> Dictionary:
	return {"class": name, "language": "GDScript", "path": path}


## What an import leaves: the file it made, and the record of the source it made it from.
func _import(source: String, content: String) -> void:
	var file := source.get_file()
	var stem := ".godot/imported/%s-%s" % [file, HASH if file == "a.png" else HASH.reverse()]
	_write(source + ".import", '[deps]\ndest_files=["res://%s.ctex"]\n' % stem)
	_write(stem + ".ctex", "imported " + content)
	_write(stem + ".md5", 'source_md5="%s"\ndest_md5="x"\n' % content.md5_text())


func _write(relative: String, content: String) -> void:
	var path := project.path_join(relative)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _wipe(dir: String) -> void:
	var access := DirAccess.open(dir)
	if access == null:
		return
	access.include_hidden = true
	for sub in access.get_directories():
		_wipe(dir.path_join(sub))
		DirAccess.remove_absolute(dir.path_join(sub))
	for file in access.get_files():
		DirAccess.remove_absolute(dir.path_join(file))
