class_name BackendSupervisor
extends Node
## Ensures the local FastAPI sketch backend is reachable when the game starts.
##
## ⚠ ONE SERVER FOR THE WHOLE GAME, and it is started when the GAME starts. Kent's friend
## pulled the game on Windows and "had to wait minutes for a drawing to be recognized". The
## server was started only once a level had loaded, so its cold start -- Python importing
## numpy and onnxruntime and FastAPI, which on a Windows machine's first run is Windows
## Defender reading every one of those files -- began at the moment she wanted to draw. After
## 45 seconds the game said it had given up; a drawing sent before then failed outright. Now
## RecognitionBackend (an autoload) starts it with the title screen, every supervisor shares
## the one process (the pid, the port and what went wrong are static), and while that process
## is alive the game waits for it however long it takes -- saying so -- rather than giving up.

const _UserData = preload("res://scripts/user_data.gd")

signal backend_ready
signal backend_starting(message: String)
signal backend_failed(message: String)

@export var auto_start_backend: bool = true
@export var backend_host: String = "127.0.0.1"
## The port asked for first. Used unless something that is not the game's server holds it --
## see `_choose_port`.
@export var backend_port: int = 8000
@export var health_path: String = "/"
@export var python_executable: String = ""
## How long to wait for a server the game did NOT start, before saying it is not answering.
## A server the game did start is waited for for as long as it is running.
@export var startup_timeout_sec: float = 45.0
@export var poll_interval_sec: float = 0.35
## How often to look again after the budget has run out. Slower, because by then this is
## waiting on a person rather than on a process.
@export var recovery_poll_sec: float = 2.0
@export var debug_logs: bool = false

## After this long starting, the player is told why it is slow.
const SLOW_START_SEC := 8.0
## And after this long, that something may be wrong -- while still waiting.
const STUCK_SEC := 300.0
## Where to look when the asked-for port is taken: something else on the machine, or a range
## Windows has reserved for Hyper-V or WSL, where binding fails with WinError 10013.
const SPARE_PORTS := [8765, 8766, 8767, 8768, 8769, 8770, 8771, 8772, 8773, 8774]

var _http: HTTPRequest
var _retry_timer: Timer
var _started_process := false
var _ensuring := false
var _deadline_msec := 0
## Whether the failure has already been announced. It is said once; the watching carries
## on silently after that.
var _gave_up := false
var _said_slow := false
var _said_stuck := false

## STATIC, because this node does not live as long as the server. Each level has its own
## supervisor and it dies on every level change; the server deliberately does not. Held on
## the node, the pid of the server Payyo started was gone by Piyesta, whose supervisor found
## a healthy server, launched nothing, and so had nothing to stop -- and the title screen and
## the house have no supervisor of their own, so quitting from either stopped nothing either.
static var _backend_pid := -1
## The port the game's server is on. 0 until one is chosen.
static var _port := 0
static var _launched_msec := 0
## Whether the server the game started has answered yet.
static var _answered := false
## The last thing that went wrong, in words a player can act on. Empty when nothing has.
static var _reason := ""


## Anything that is about to quit the game calls this group, so the Python child does not
## outlive the process that started it.
const GROUP := &"backend_supervisors"


func _ready() -> void:
	add_to_group(GROUP)
	_http = HTTPRequest.new()
	_http.timeout = 5.0
	add_child(_http)
	_http.request_completed.connect(_on_health_completed)

	_retry_timer = Timer.new()
	_retry_timer.one_shot = true
	add_child(_retry_timer)
	_retry_timer.timeout.connect(_request_health)


func ensure_backend() -> void:
	if _ensuring:
		return
	_ensuring = true
	_started_process = false
	_gave_up = false
	_said_slow = false
	_said_stuck = false
	# A server another supervisor started, still coming up or already up, is the one to ask.
	# Otherwise this one's own port.
	if not owned_backend_running():
		_port = backend_port
	_deadline_msec = Time.get_ticks_msec() + int(startup_timeout_sec * 1000.0)
	_request_health()


## Where the game's server is, for anything that talks to it.
static func url(path: String = "/") -> String:
	if not path.begins_with("/"):
		path = "/" + path
	return "http://127.0.0.1:%d%s" % [_port if _port > 0 else 8000, path]


## The server the game started is running and has not answered yet: give it time.
static func is_waking() -> bool:
	return owned_backend_running() and not _answered


static func owned_backend_running() -> bool:
	return _backend_pid > 0 and OS.is_process_running(_backend_pid)


## What went wrong last, in words; empty if nothing has.
static func failure_reason() -> String:
	return _reason


## Kill the backend the game started, if it started one.
##
## Only ever ours: `_start_backend` runs solely when nothing answered the health check, so
## a server the player launched by hand is never touched. Left alone, the child outlives
## the game, keeps its port, and the next launch uses it whatever code it is running.
##
## STATIC so a screen with no supervisor in it can call it: the title screen and the house.
## NOT called from _exit_tree -- a supervisor dies on every level change, and killing the
## backend between levels would buy a fresh cold start each time.
static func stop_owned_backend() -> void:
	if _backend_pid > 0:
		OS.kill(_backend_pid)
		_backend_pid = -1
	_answered = false


## The group call anything about to quit makes. Same as stop_owned_backend.
func stop_backend() -> void:
	stop_owned_backend()
	_started_process = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_CRASH:
		stop_backend()


func backend_url(path: String = "") -> String:
	return url(path if not path.is_empty() else health_path)


func _request_health() -> void:
	if not is_inside_tree():
		return
	var error := _http.request(backend_url(), [], HTTPClient.METHOD_GET)
	if error != OK:
		_handle_health_failure("could not start backend health check")


func _on_health_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary and String(parsed.get("status", "")) == "ok":
			_ensuring = false
			_gave_up = false
			_answered = true
			_reason = ""
			if debug_logs:
				print("BackendSupervisor ready at %s" % backend_url())
			backend_ready.emit()
			return

	_handle_health_failure("backend health check did not return ok")


func _handle_health_failure(reason: String) -> void:
	if debug_logs:
		print("BackendSupervisor retrying: %s" % reason)
	# OURS AND STILL STARTING: wait, however long it takes, and say why once it is slow.
	if owned_backend_running():
		var waited := (Time.get_ticks_msec() - _launched_msec) / 1000.0
		if waited >= SLOW_START_SEC and not _said_slow:
			_said_slow = true
			backend_starting.emit("Waking the drawing recogniser up -- the first start on a "
				+ "computer can take a minute or two")
		if waited >= STUCK_SEC and not _said_stuck:
			_said_stuck = true
			_reason = "The drawing recogniser has been starting for five minutes. Close the " \
				+ "game and run %s again." % _launcher_name()
			backend_failed.emit(_reason)
		_retry_timer.start(poll_interval_sec)
		return
	# OURS, AND IT HAS STOPPED. It wrote down why (backend/serve.py); say that.
	if _backend_pid > 0:
		_backend_pid = -1
		_answered = false
		_reason = _reason_from_log()
		_fail(_reason)
		return
	if not _started_process and auto_start_backend:
		_start_backend()
		if _backend_pid > 0:
			_retry_timer.start(poll_interval_sec)
		return

	if Time.get_ticks_msec() >= _deadline_msec:
		if _reason.is_empty():
			_reason = "The drawing recogniser is not answering. Close the game and run %s." \
				% _launcher_name()
		_fail(_reason)
		return
	_retry_timer.start(poll_interval_sec)


func _start_backend() -> void:
	_started_process = true
	_answered = false
	_reason = ""
	_port = _choose_port()
	if _port <= 0:
		_port = backend_port
		_reason = "No free port for the drawing recogniser (tried %d and 8765-8774)." % backend_port
		_fail(_reason)
		return
	backend_starting.emit("Starting the drawing recogniser...")

	var python := _resolve_python_executable()
	# WHO STARTED IT. The server watches this process and exits when it is gone
	# (backend/lifecycle.py), which covers what stop_backend cannot: a crash, a force-quit, a
	# run stopped from the editor. The child inherits the environment it is launched with.
	OS.set_environment("OBRA_GAME_PID", str(OS.get_process_id()))
	var args := PackedStringArray([
		_repo_root().path_join("backend").path_join("serve.py"),
		"--host", backend_host,
		"--port", str(_port),
		"--log", log_path(),
	])
	_backend_pid = OS.create_process(python, args)
	_launched_msec = Time.get_ticks_msec()
	if debug_logs:
		print("BackendSupervisor launched pid %d with %s %s" % [_backend_pid, python, " ".join(args)])
	if _backend_pid <= 0:
		_reason = "Python could not be started (%s). Run %s once -- it sets Python up for " \
			% [python, _launcher_name()] + "the game."
		_fail(_reason)


## The asked-for port if it can be listened on, else the first spare that can. Asked by
## actually listening, because that is the only answer Windows' reserved ranges give.
func _choose_port() -> int:
	for port: int in [backend_port] + SPARE_PORTS:
		if port_is_free(port):
			return port
	return -1


static func port_is_free(port: int) -> bool:
	var server := TCPServer.new()
	var ok := server.listen(port, "127.0.0.1") == OK
	server.stop()
	return ok


## Where serve.py writes everything, and where its last words are read back from.
static func log_path() -> String:
	return ProjectSettings.globalize_path(_UserData.path("backend.log"))


## The reason serve.py gave, or the last thing it said, or -- when it said nothing at all,
## which is a Python that never ran our code -- what that usually means.
func _reason_from_log() -> String:
	var text := FileAccess.get_file_as_string(log_path())
	var last := ""
	for line in text.split("\n", false):
		var said := line.strip_edges()
		if said.begins_with("OBRA_BACKEND_FAILED:"):
			return "The drawing recogniser could not start: " + said.trim_prefix(
				"OBRA_BACKEND_FAILED:").strip_edges()
		if not said.is_empty():
			last = said
	if not last.is_empty():
		return "The drawing recogniser stopped: %s" % last
	return "The drawing recogniser stopped before it could start -- Python may be missing. " \
		+ "Run %s once." % _launcher_name()


## Say so once, and then KEEP LOOKING.
##
## This used to stop dead: `_ensuring` went false, the retry timer was never restarted,
## and nothing checked again for the life of the scene. A backend that came up two seconds
## after the budget expired -- which is most first launches -- was never noticed, and the
## game stayed in its failed state until the player quit. Every situation that reaches
## here is one a person can resolve while the game is running.
func _fail(message: String) -> void:
	if not _gave_up:
		_gave_up = true
		backend_failed.emit(message)
	_retry_timer.start(recovery_poll_sec)


static func _launcher_name() -> String:
	return "play_windows.bat" if OS.has_feature("windows") else "./play.sh"


func _resolve_python_executable() -> String:
	var configured := python_executable.strip_edges()
	if not configured.is_empty():
		return configured
	return python_in(_repo_root().path_join(".venv"), OS.has_feature("windows"))


## The venv's interpreter, wherever this platform keeps it, or else what this platform calls
## Python.
##
## ⚠ IT ONLY EVER LOOKED FOR `.venv/bin/python`, and a Windows venv has no `bin`: its
## interpreter is `Scripts\python.exe`. Every Windows checkout fell through to `python3` --
## which on Windows is usually not Python at all but the Microsoft Store's stand-in for it --
## so the server never came up and every drawing went unrecognised. Kent's teammates on
## Windows: "the game is not playable in their end". Static, and told the platform, so a test
## on any machine can ask it about both.
static func python_in(venv_dir: String, windows: bool) -> String:
	var inside := ["Scripts/python.exe", "bin/python", "bin/python3"] if windows \
		else ["bin/python", "bin/python3"]
	for relative: String in inside:
		var candidate := venv_dir.path_join(relative)
		if FileAccess.file_exists(candidate):
			return candidate
	return "python" if windows else "python3"


func _repo_root() -> String:
	var game_dir := ProjectSettings.globalize_path("res://").simplify_path()
	return game_dir.path_join("..").simplify_path()
