extends Node
## THE DRAWING RECOGNISER STARTS WITH THE GAME, NOT WITH THE FIRST LEVEL.
##
## Kent's friend pulled the game on Windows and "had to wait minutes for a drawing to be
## recognized". Each level started the Python server as it loaded, so a cold start -- slowest
## of all on a Windows machine's first run, where Windows Defender reads every file numpy and
## onnxruntime are made of -- began at exactly the moment she wanted to draw. Started here,
## with the title screen, it comes up while she is reading the menu and walking through the
## house, and a level's own supervisor finds it already running (they share one process; see
## BackendSupervisor).
##
## Not during a test suite (`--script`), which starts its own servers on its own ports when
## it wants one, and not while ImportGuard is about to restart the game -- a server started
## by the process that is about to quit is one the restarted game cannot stop.

const Supervisor = preload("res://scripts/backend_supervisor.gd")

var supervisor: Node


func _ready() -> void:
	var args := OS.get_cmdline_args()
	if "--script" in args or "-s" in args:
		return
	var guard := get_node_or_null(^"/root/ImportGuard")
	if guard != null and guard.has_method("is_importing") and bool(guard.call("is_importing")):
		return
	supervisor = Supervisor.new()
	supervisor.name = "Supervisor"
	add_child(supervisor)
	supervisor.call("ensure_backend")
