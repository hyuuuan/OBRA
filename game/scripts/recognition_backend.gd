extends Node
## THE DRAWING RECOGNISER STARTS WITH THE GAME, NOT WITH THE FIRST LEVEL -- AND SETS ITSELF UP.
##
## Kent's friend pulled the game on Windows and "had to wait minutes for a drawing to be
## recognized". Each level started the Python server as it loaded, so a cold start -- slowest
## of all on a Windows machine's first run, where Windows Defender reads every file numpy and
## onnxruntime are made of -- began at exactly the moment she wanted to draw. Started here,
## with the title screen, it comes up while she is reading the menu and walking through the
## house, and a level's own supervisor finds it already running (they share one process; see
## BackendSupervisor).
##
## And then Kent: "i want it to be automatic". On a computer that has never run the game there
## is no .venv, and only the launchers made one. Now serve.py makes it and fills it on that first
## start (minutes, once), and this says so on screen while it does -- a note in the corner, in
## words, so a first start reads as the game getting ready rather than as the game not working.
## Nothing is shown when the recogniser is up within a moment, which is every start after that.
##
## Not during a test suite (`--script`), which starts its own servers on its own ports when
## it wants one, and not while ImportGuard is about to restart the game -- a server started
## by the process that is about to quit is one the restarted game cannot stop.

const Supervisor = preload("res://scripts/backend_supervisor.gd")
const NoteSkin = preload("res://scripts/ui_skin.gd")

## How long a start may take before the note appears: long enough that a warm start never
## flashes it, short enough that a first start is explained from its first seconds.
const SHOW_AFTER_SEC := 1.5
const READY_NOTE_SEC := 3.0

var supervisor: Node
var _layer: CanvasLayer
var _panel: PanelContainer
var _label: Label
var _pending := ""
var _hide_at_msec := 0
var _show_at_msec := 0


func _ready() -> void:
	var args := OS.get_cmdline_args()
	if "--script" in args or "-s" in args:
		return
	var guard := get_node_or_null(^"/root/ImportGuard")
	if guard != null and guard.has_method("is_importing") and bool(guard.call("is_importing")):
		return
	begin()


## Start the recogniser and the note that follows it. Public so a probe -- which runs under
## --script, where _ready stands aside -- can start one on its own port with its own Python.
func begin(python := "", port := 8000) -> void:
	_build_note()
	supervisor = Supervisor.new()
	supervisor.name = "Supervisor"
	supervisor.set("python_executable", python)
	supervisor.set("backend_port", port)
	add_child(supervisor)
	supervisor.connect("backend_starting", _on_starting)
	supervisor.connect("backend_failed", _on_failed)
	supervisor.connect("backend_ready", _on_ready)
	_show_at_msec = Time.get_ticks_msec() + int(SHOW_AFTER_SEC * 1000.0)
	_pending = "Getting the drawing recogniser ready..."
	supervisor.call("ensure_backend")


func _process(_delta: float) -> void:
	if _panel == null:
		return
	var now := Time.get_ticks_msec()
	if not _pending.is_empty() and _show_at_msec > 0 and now >= _show_at_msec:
		_say(_pending)
		_pending = ""
		_show_at_msec = 0
	if _hide_at_msec > 0 and now >= _hide_at_msec:
		_hide_at_msec = 0
		_panel.visible = false


func is_note_showing() -> bool:
	return _panel != null and _panel.visible


func note_text() -> String:
	return _label.text if _label != null else ""


func _on_starting(message: String) -> void:
	if _show_at_msec > 0:
		_pending = message
	else:
		_say(message)


func _on_failed(message: String) -> void:
	_show_at_msec = 0
	_pending = ""
	_say(message)


func _on_ready() -> void:
	_pending = ""
	_show_at_msec = 0
	if _panel != null and _panel.visible:
		_say("The drawing recogniser is ready.")
		_hide_at_msec = Time.get_ticks_msec() + int(READY_NOTE_SEC * 1000.0)


func _say(text: String) -> void:
	_hide_at_msec = 0
	_label.text = text
	_panel.visible = true
	_panel.reset_size()
	var view := _panel.get_viewport_rect().size
	_panel.position = Vector2(floorf((view.x - _panel.size.x) * 0.5), 104.0)


## Top centre, under where a level's objective line sits, and above every level's own HUD --
## it is about the whole game, not about one screen of it.
func _build_note() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child(_layer)
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(holder)
	_panel = PanelContainer.new()
	_panel.name = "RecogniserNote"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override(&"panel", NoteSkin.chip(12.0, 6.0))
	_panel.visible = false
	holder.add_child(_panel)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(560.0, 0.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override(&"font_size", NoteSkin.FONT_CAPTION)
	_label.add_theme_color_override(&"font_color", NoteSkin.CREAM_TEXT)
	_panel.add_child(_label)
