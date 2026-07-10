class_name BackendSupervisor
extends Node
## Ensures the local FastAPI sketch backend is reachable when the game starts.

signal backend_ready
signal backend_starting(message: String)
signal backend_failed(message: String)

@export var auto_start_backend: bool = true
@export var backend_host: String = "127.0.0.1"
@export var backend_port: int = 8000
@export var health_path: String = "/"
@export var python_executable: String = ""
@export var startup_timeout_sec: float = 10.0
@export var poll_interval_sec: float = 0.35
@export var debug_logs: bool = false

var _http: HTTPRequest
var _retry_timer: Timer
var _started_process := false
var _ensuring := false
var _deadline_msec := 0
var _backend_pid := -1


func _ready() -> void:
	_http = HTTPRequest.new()
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
	_backend_pid = -1
	_deadline_msec = Time.get_ticks_msec() + int(startup_timeout_sec * 1000.0)
	_request_health()


func backend_url(path: String = "") -> String:
	var suffix := path if not path.is_empty() else health_path
	if not suffix.begins_with("/"):
		suffix = "/" + suffix
	return "http://%s:%d%s" % [backend_host, backend_port, suffix]


func _request_health() -> void:
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
			if debug_logs:
				print("BackendSupervisor ready at %s" % backend_url())
			backend_ready.emit()
			return

	_handle_health_failure("backend health check did not return ok")


func _handle_health_failure(reason: String) -> void:
	if not _started_process:
		if auto_start_backend:
			_start_backend()
		else:
			_fail("Backend is not running.")
			return

	if Time.get_ticks_msec() >= _deadline_msec:
		_fail("Backend did not become ready. Start it manually from backend/.")
		return

	if debug_logs:
		print("BackendSupervisor retrying: %s" % reason)
	_retry_timer.start(poll_interval_sec)


func _start_backend() -> void:
	_started_process = true
	backend_starting.emit("Starting backend...")

	var python := _resolve_python_executable()
	var backend_dir := _repo_root().path_join("backend")
	var args := PackedStringArray([
		"-m",
		"uvicorn",
		"--app-dir",
		backend_dir,
		"main:app",
		"--host",
		backend_host,
		"--port",
		str(backend_port)
	])
	_backend_pid = OS.create_process(python, args)
	if debug_logs:
		print("BackendSupervisor launched pid %d with %s %s" % [_backend_pid, python, " ".join(args)])
	if _backend_pid <= 0:
		_fail("Could not launch backend process. Check .venv and backend requirements.")


func _fail(message: String) -> void:
	_ensuring = false
	backend_failed.emit(message)


func _resolve_python_executable() -> String:
	var configured := python_executable.strip_edges()
	if not configured.is_empty():
		return configured

	var venv_python := _repo_root().path_join(".venv/bin/python")
	if FileAccess.file_exists(venv_python):
		return venv_python

	return "python3"


func _repo_root() -> String:
	var game_dir := ProjectSettings.globalize_path("res://").simplify_path()
	return game_dir.path_join("..").simplify_path()
