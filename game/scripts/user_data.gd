extends RefCounted
## WHERE THE PLAYER'S THINGS ARE KEPT, AND WHERE A TEST'S ARE.
##
## The profile and the telemetry log live in the player's user data folder, and so did every
## test run's. A suite plays a level with the real autoloads, and the real autoloads wrote to
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

const TEST_ROOT := "user://test_runs"

static var _emptied := false


static func is_test_run() -> bool:
	var args := OS.get_cmdline_args()
	return args.has("--script") or args.has("-s")


## Where `relative` lives for this run: the player's folder, or the test run's own.
static func path(relative: String) -> String:
	if not is_test_run():
		return "user://" + relative
	if not _emptied:
		_emptied = true
		_empty(TEST_ROOT)
		DirAccess.make_dir_recursive_absolute(TEST_ROOT)
	return TEST_ROOT.path_join(relative)


static func _empty(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_empty(dir_path.path_join(sub))
		DirAccess.remove_absolute(dir_path.path_join(sub))
	for file in dir.get_files():
		DirAccess.remove_absolute(dir_path.path_join(file))
