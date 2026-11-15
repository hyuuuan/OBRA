extends RefCounted
## WHERE THE PLAYER'S THINGS ARE KEPT, AND WHERE A TEST'S ARE.
##
## Source runs use Godot's user data folder. Each export keeps its save and telemetry in
## its own package's gamesession folder, starting fresh on the first launch.
##
## Test runs used to share the player's user data folder. A suite plays a level with the
## real autoloads, and the real autoloads wrote to
## the real folder: by September it held 3,839 telemetry sessions, nearly all of them bots, and
## the profile on the development machine was whatever the last suite had left in it. Two
## suites DELETE it on purpose, to start clean. A playtest after a test run began from a save
## nobody had played, and the telemetry the thesis aggregates could not tell a participant
## from a probe.
##
## A run started with `--script` is a suite, a probe or a tool -- never a player. Nothing a
## player launches passes it: not the editor's Play button, not an exported build. Those runs
## keep their things under user://test_runs instead, emptied when the run starts, so every
## suite begins from the same nothing whatever ran before it.
##
## ⚠ EACH RUN IN ITS OWN FOLDER, user://test_runs/<its process id>. They all used to share
## test_runs itself, and every run emptied it when it started -- and the user folder is keyed by
## the project's NAME, so every git worktree of the project shares it. A probe started in one
## worktree wiped the profile out from under a suite running in another, and that suite failed on
## data that had vanished mid-run. A run empties its own folder now, and sweeps away only what
## runs that have ended left behind.

const TEST_ROOT := "user://test_runs"

static var _run_root := ""
static var _export_root := ""


static func is_test_run() -> bool:
	var args := OS.get_cmdline_args()
	return args.has("--script") or args.has("-s")


static func is_exported_build() -> bool:
	return OS.has_feature("template") and not is_test_run()


static func path(relative: String) -> String:
	if is_test_run():
		return run_root().path_join(relative)
	if OS.has_feature("template"):
		if _export_root.is_empty():
			_export_root = export_package_root().path_join("gamesession")
			if DirAccess.make_dir_recursive_absolute(_export_root) != OK:
				push_error("Could not create the game session folder: %s" % _export_root)
		return _export_root.path_join(relative)
	return "user://" + relative


## Packages put the binary in game/ and the recogniser and session data one level up.
## For a standalone export, keep the session folder beside the executable or app bundle.
static func export_package_root(executable: String = OS.get_executable_path()) -> String:
	var folder := executable.simplify_path().get_base_dir()
	if folder.ends_with(".app/Contents/MacOS"):
		folder = folder.get_base_dir().get_base_dir().get_base_dir()
	return folder.get_base_dir() if folder.get_file() == "game" else folder


## This test run's own folder, empty the first time it is asked for.
static func run_root() -> String:
	if _run_root.is_empty():
		_run_root = TEST_ROOT.path_join(str(OS.get_process_id()))
		DirAccess.make_dir_recursive_absolute(TEST_ROOT)
		sweep_ended_runs()
		_empty(_run_root)
		DirAccess.make_dir_recursive_absolute(_run_root)
	return _run_root


## Take away what ended runs left: a folder named for a process no longer running, and anything
## at the top from before runs had folders of their own. Never the folder of a run still going.
static func sweep_ended_runs() -> void:
	var dir := DirAccess.open(TEST_ROOT)
	if dir == null:
		return
	var mine := OS.get_process_id()
	for sub in dir.get_directories():
		if sub.is_valid_int() and (int(sub) == mine or is_running(int(sub))):
			continue
		_empty(TEST_ROOT.path_join(sub))
		DirAccess.remove_absolute(TEST_ROOT.path_join(sub))
	for file in dir.get_files():
		DirAccess.remove_absolute(TEST_ROOT.path_join(file))


## Whether a process is still going -- any process, asked of the system.
##
## ⚠ NOT OS.is_process_running. That answers only for processes this one started itself; asked
## about a run started from another terminal it says "ended", and the sweep took a live run's folder
## -- the very thing these folders exist to stop.
static func is_running(pid: int) -> bool:
	if pid == OS.get_process_id():
		return true
	if OS.has_feature("windows"):
		var listing := []
		OS.execute("tasklist", ["/FI", "PID eq %d" % pid, "/NH"], listing)
		return not listing.is_empty() and String(listing[0]).contains(" %d " % pid)
	return OS.execute("kill", ["-0", str(pid)]) == 0


static func _empty(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_empty(dir_path.path_join(sub))
		DirAccess.remove_absolute(dir_path.path_join(sub))
	for file in dir.get_files():
		DirAccess.remove_absolute(dir_path.path_join(file))
