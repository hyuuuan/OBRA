extends CanvasLayer
## THE LOADING SCREEN: the title card with its bar, while the next scene loads behind it.
##
## The scene is loaded on a thread and the bar follows how far it has got, but never faster than
## MIN_SECONDS fills it: the menu loads in a blink, and a bar that flashes full and vanishes reads
## as a glitch rather than as the game getting ready. When both are done the scene changes under
## the card, and the card fades -- onto the home screen, which stands on the same picture, so
## what changes is the bar giving way to the buttons.
##
## No class_name, like the card it shows: boot.gd builds this with load(), and boot must load
## with nothing imported.

const CARD := preload("res://scripts/title_card.gd")
const MIN_SECONDS := 1.4
const HOLD_SECONDS := 0.15
const FADE_SECONDS := 0.35

var _target := ""
var _card: Control
var _elapsed := 0.0
var _shown := 0.0
var _done := false


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_card = CARD.new()
	_card.name = "TitleCard"
	_card.set("mode", 1)  # LOADING
	add_child(_card)


## Load `scene_path` behind the card, then go to it.
func begin(scene_path: String) -> void:
	_target = scene_path
	ResourceLoader.load_threaded_request(scene_path, "", true)


func shown_progress() -> float:
	return _shown


func _process(delta: float) -> void:
	if _done or _target.is_empty():
		return
	_elapsed += delta
	var loaded: Array = []
	var status := ResourceLoader.load_threaded_get_status(_target, loaded)
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		push_error("Loading screen: could not load %s" % _target)
		_done = true
		get_tree().change_scene_to_file(_target)
		queue_free()
		return
	var actual := 1.0 if status == ResourceLoader.THREAD_LOAD_LOADED \
		else float(loaded[0]) if not loaded.is_empty() else 0.0
	# Never ahead of the load, never faster than MIN_SECONDS -- and never backwards.
	var allowed := minf(actual, _elapsed / MIN_SECONDS)
	_shown = maxf(_shown, move_toward(_shown, allowed, delta * 2.5))
	_card.set("progress", _shown)
	if status == ResourceLoader.THREAD_LOAD_LOADED and _shown >= 0.999:
		_done = true
		_arrive.call_deferred()


func _arrive() -> void:
	await get_tree().create_timer(HOLD_SECONDS, true).timeout
	var scene := ResourceLoader.load_threaded_get(_target) as PackedScene
	get_tree().change_scene_to_packed(scene)
	var fade := create_tween()
	fade.tween_property(_card, "modulate:a", 0.0, FADE_SECONDS)
	fade.tween_callback(queue_free)
