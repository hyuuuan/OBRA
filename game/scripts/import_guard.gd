extends Node
## A STALE IMPORT CACHE FIXES ITSELF.
##
## Kent, of the game on his teammates' machines: "the game cache when ran into a different device
## is a bit buggy like it stacks". Godot keeps what it has imported -- textures, fonts, the table
## of every script's class_name -- in `game/.godot`, which is not in git, so every machine builds
## its own. Pull a change and run the game without importing first, and that cache describes an
## older checkout: new art fails to load, scripts that name a new class fail to compile, and the
## errors repeat every frame. Built at a September commit and run at the October one, Level 1
## printed two thousand lines in five seconds, three hundred of them the same line.
##
## `play_windows.bat` imports before every launch. Anything else -- `godot --path game`, a
## shortcut, a Mac -- went straight into the stale cache. So the game checks for itself, before
## anything else loads: is every imported file there, is every source file still the one that
## was imported, and does the class table name every class the scripts declare? If not, it runs
## the same import the launcher runs, waits for it, and starts itself again.
##
## ⚠ NO class_name, AND NOTHING THAT NEEDS ONE. This has to work on exactly the cache that is
## broken, and a script that leans on the class table cannot load when the table is wrong. It is
## the first autoload for the same reason: it runs before the ones that do lean on it.
##
## Only a game run from the project's source does this. An exported build has no import cache
## to go stale. A `--script` run -- every test suite -- does load the autoloads, and stands this
## one aside: a suite restarted under itself halfway through would report nothing useful.

## Handed to the relaunched game, so a cache the import could not bring up to date is reported
## once rather than imported again on every start.
const RELAUNCHED := "--obra-reimported"

## An imported file's name up to its hash, which is also the name of the record of what it was
## imported from: `x.png-<md5>.ctex` beside `x.png-<md5>.md5`.
const _STAMP := "^(.*-[0-9a-f]{32})\\."
const _CLASS_NAME := "(?m)^class_name\\s+(\\w+)"


## The import, running beside the game so the window can say what is happening. A first
## import on a slow laptop takes minutes, and a frozen splash for minutes reads as a crash.
var _import: Thread
var _note: Label


func _ready() -> void:
	if not wants_checking():
		return
	var reasons := stale_reasons()
	if OS.get_cmdline_user_args().has(RELAUNCHED):
		if not reasons.is_empty():
			push_warning("ImportGuard: still out of date after importing (%s). Open the project "
				% reasons[0] + "in the Godot editor once and let it finish importing.")
		return
	if reasons.is_empty():
		return
	print("O.B.R.A.: this computer's copy of the game's imported files is out of date (%d: %s). "
		% [reasons.size(), reasons[0]] + "Importing, then starting again -- once per update.")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_say("Getting O.B.R.A. ready for this computer.\n\nThe game was updated, so its files are "
		+ "being prepared again. This happens once,\nand the game starts again by itself.")
	_import = Thread.new()
	_import.start(_run_the_import)


func _process(_delta: float) -> void:
	if _import == null:
		set_process(false)
		return
	# ⚠ THE SCENE THAT WAS LOADING GOES AT ONCE. It was built against the cache being replaced,
	# and left running it errors every frame for as long as the import takes -- the stacking.
	var scene := get_tree().current_scene
	if scene != null:
		scene.queue_free()
	if _import.is_alive():
		return
	var code := int(_import.wait_to_finish())
	_import = null
	if code != 0:
		# Stopped rather than looped: a restart would find the same cache and do this again.
		push_error("ImportGuard: the import exited %d." % code)
		_say("O.B.R.A. could not prepare its files (the import stopped with code %d).\n\n" % code
			+ "Close this window, then run play_windows.bat -- or open the project\nin the Godot "
			+ "editor once and let it finish importing.")
		return
	OS.set_restart_on_exit(true, relaunch_args())
	get_tree().quit()


func _run_the_import() -> int:
	var output: Array = []
	return OS.execute(OS.get_executable_path(),
		["--headless", "--path", project_dir(), "--import"], output, true)


## Over everything, in the engine's own font: the project's theme and its pixel font are
## among the files being imported, and may be the very ones that are missing.
func _say(text: String) -> void:
	if _note == null:
		var layer := CanvasLayer.new()
		layer.layer = 128
		add_child(layer)
		var shade := ColorRect.new()
		shade.color = Color(0.051, 0.067, 0.055)
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(shade)
		_note = Label.new()
		_note.set_anchors_preset(Control.PRESET_FULL_RECT)
		_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_note.add_theme_font_size_override(&"font_size", 22)
		_note.add_theme_color_override(&"font_color", Color(0.93, 0.91, 0.84))
		layer.add_child(_note)
	_note.text = text


## Whether this launch is importing and about to restart. RecognitionBackend asks, so it does
## not start a server the restarted game would not know it owns.
func is_importing() -> bool:
	return _import != null


## A game run from source -- not an export, which carries `project.binary` instead of this file
## and has the `template` feature -- and not a `--script` run.
static func wants_checking(args: PackedStringArray = OS.get_cmdline_args()) -> bool:
	if "--script" in args or "-s" in args:
		return false
	return FileAccess.file_exists("res://project.godot") and not OS.has_feature("template")


static func project_dir() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/")


## The same launch, pointed at the project by its full path -- Godot changes into the project
## folder when it starts, so a relative `--path game` would point somewhere else -- and marked
## as the second try.
##
## ⚠ HEADLESS IS ASKED FOR, NOT READ BACK. The engine keeps the options it acts on to itself, so
## `--headless` is not in `get_cmdline_args()`, and a headless run restarted as a game with a
## window.
static func relaunch_args(args: PackedStringArray = OS.get_cmdline_args(),
		user: PackedStringArray = OS.get_cmdline_user_args(),
		headless: bool = DisplayServer.get_name() == "headless") -> PackedStringArray:
	var out := PackedStringArray(["--path", project_dir()])
	if headless:
		out.append("--headless")
	var skip := false
	for arg in args:
		if skip:
			skip = false
			continue
		if arg == "--path":
			skip = true
			continue
		if arg in ["--", "++", "--headless"] or arg in user:
			continue
		out.append(arg)
	out.append("--")
	out.append_array(user)
	out.append(RELAUNCHED)
	return out


## Every way the cache under `root` is out of date, as a sentence each; empty when it is current.
##
## `classes` is the class table the engine loaded at start -- ProjectSettings' copy of the cache
## -- and is a parameter so a probe can hand in one it built.
static func stale_reasons(root := "res://",
		classes: Array[Dictionary] = ProjectSettings.get_global_class_list()) -> PackedStringArray:
	var reasons := PackedStringArray()
	var declared: Dictionary = {}
	var patterns: Array[RegEx] = [RegEx.create_from_string(_STAMP),
		RegEx.create_from_string(_CLASS_NAME)]
	_walk(root, root, reasons, declared, patterns)
	var cached: Dictionary = {}
	for entry in classes:
		if String(entry.get("language", "")) == "GDScript":
			cached[String(entry.get("class", ""))] = String(entry.get("path", ""))
	for name: String in declared:
		if cached.get(name, "") != declared[name]:
			reasons.append("the class table does not know %s" % name)
	for name: String in cached:
		var path: String = cached[name]
		if path.begins_with("res://") and not FileAccess.file_exists(_local(path, root)):
			reasons.append("the class table still lists %s, whose script is gone" % name)
	return reasons


static func _walk(dir: String, root: String, reasons: PackedStringArray, declared: Dictionary,
		patterns: Array[RegEx]) -> void:
	var access := DirAccess.open(dir)
	if access == null or access.file_exists(".gdignore"):
		return
	for sub in access.get_directories():
		if not sub.begins_with("."):
			_walk(dir.path_join(sub), root, reasons, declared, patterns)
	for file in access.get_files():
		var path := dir.path_join(file)
		if file.ends_with(".import"):
			var reason := _import_reason(path, root, patterns[0])
			if not reason.is_empty():
				reasons.append(reason)
		elif file.ends_with(".gd"):
			var found := patterns[1].search(FileAccess.get_file_as_string(path))
			if found != null:
				declared[found.get_string(1)] = _res(path, root)


## Why one imported asset is out of date, or "" when it is not.
##
## ⚠ NOT BY MODIFIED TIME ALONE. A checkout rewrites every file it touches, including ones whose
## bytes did not change, and the import leaves those alone -- so a time check says "stale" for a
## file the import will never redo, and the game would import and restart on every launch. The
## time is only the cheap first question; a newer source is then hashed against the hash Godot
## recorded when it imported it.
static func _import_reason(import_path: String, root: String, stamp: RegEx) -> String:
	var config := ConfigFile.new()
	if config.load(import_path) != OK:
		return ""
	var dests: Array = config.get_value("deps", "dest_files", [])
	var source := import_path.trim_suffix(".import")
	var label := _res(source, root).trim_prefix("res://")
	if dests.is_empty() or not FileAccess.file_exists(source):
		return ""
	for dest in dests:
		if not FileAccess.file_exists(_local(String(dest), root)):
			return "%s has not been imported" % label
	var found := stamp.search(String(dests[0]))
	if found == null:
		return ""
	var record := _local(found.get_string(1) + ".md5", root)
	if not FileAccess.file_exists(record):
		return "%s has not been imported" % label
	if FileAccess.get_modified_time(source) <= FileAccess.get_modified_time(record):
		return ""
	var hashes := ConfigFile.new()
	if hashes.load(record) == OK and String(hashes.get_value("", "source_md5", "")) \
			== FileAccess.get_md5(source):
		return ""
	return "%s changed after it was imported" % label


## A `res://` path inside `root`, which is `res://` itself except in a probe.
static func _local(path: String, root: String) -> String:
	return root.path_join(path.trim_prefix("res://")) if path.begins_with("res://") else path


static func _res(path: String, root: String) -> String:
	return "res://" + path.trim_prefix(root).trim_prefix("/")
