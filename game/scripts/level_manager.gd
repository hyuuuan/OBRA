extends Node
## Persistent catalog and scene transition coordinator.
##
## THE TRANSITION IS A STROKE OF INK (Kent, 2026-10-23, asked: "an ink brush wipe ... fits a game
## about drawing"). One brush stroke sweeps across until the screen is ink, the scene changes under
## it, and its tail sweeps on past to show the next one (shaders/ink_wipe.gdshader). It replaced a
## diagonal pixel-step of blocks. With Reduce motion on it is a short fade through ink instead.

signal transition_started(destination: String)
signal level_changed(level_id: String)
signal transition_finished(destination: String)

const CATALOG_PATH := "res://config/levels.json"
const SELECTOR_SCENE := "res://ui/main_menu.tscn"
## Where levels are chosen: Lolo and Lola's house, with the paintings on the wall. This is
## what PLAY opens and what leaving a level returns to -- the menu's card grid is no longer
## the way in.
const HOUSE_SCENE := "res://levels/hub/hub.tscn"
const ENDING_SCENE := "res://ui/ending_screen.tscn"
## The stroke's seconds each way: across to cover, and on past to show.
const WIPE_SECONDS := 0.5
const WIPE_SHADER := preload("res://shaders/ink_wipe.gdshader")

var current_level_id := ""
## A level the run has just opened, for the house to open in front of the player. Set as a
## level ends and taken once by the house. Not saved: a quit in between skips only the moment.
var pending_reveal := ""
## 0 skips the wipe: the scene changes with no stroke (the journey probe walks the whole game
## and has no use for one). Anything above plays it at WIPE_SECONDS.
var transition_step_seconds := 0.012

var _levels: Array[Dictionary] = []
var _transitioning := false
var _selector_requested := false
var _transition_layer: CanvasLayer
var _transition_root: Control
var _wipe: ColorRect
var _wipe_material: ShaderMaterial


func _ready() -> void:
	_load_catalog()
	_build_transition_overlay()


func get_levels() -> Array[Dictionary]:
	return _levels.duplicate(true)


func get_level(level_id: String) -> Dictionary:
	for entry in _levels:
		if String(entry.get("id", "")) == level_id:
			return entry.duplicate(true)
	return {}


func is_unlocked(level_id: String) -> bool:
	var entry := get_level(level_id)
	if entry.is_empty():
		return false
	if bool(entry.get("unlocked", false)):
		return true
	# Progression unlocks earned in play persist in the player profile across sessions.
	var profile := get_node_or_null(^"/root/PlayerProfile")
	return profile != null and profile.is_level_unlocked(level_id)


func is_transitioning() -> bool:
	return _transitioning


func open_level(level_id: String) -> bool:
	if _transitioning or not is_unlocked(level_id) or not has_brush():
		return false
	var entry := get_level(level_id)
	var scene_path := String(entry.get("scene_path", ""))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return false
	current_level_id = level_id
	_transition_to.call_deferred(scene_path, level_id)
	return true


## Show the run's ending. Reached from the level marked "ends_run" in the catalog, so
## that when levels 2-5 exist only the last one carries the flag and no code changes.
func show_ending() -> bool:
	if _transitioning or not ResourceLoader.exists(ENDING_SCENE):
		return false
	get_tree().paused = false
	_transition_to.call_deferred(ENDING_SCENE, "")
	return true


## Whether the apo is carrying Lola's brush, which is the third question a level asks and
## the only one with a single answer for all five of them.
##
## THE GAME IS DRAWING. Every verb in a level goes through the canvas, so a player who
## walked past the stand in the house would arrive in Payyo with no way to do anything at
## all -- which is not a hard level, it is a broken one. The brush is taken once, off the
## stand at the end of the hall, and it is then true forever.
##
## Checked HERE rather than only in the house, because the house is not the only door: the
## menu's card grid calls open_level directly, and a gate that lives in one caller is a
## gate the other caller walks around. restart_level deliberately does not ask -- a level
## you are standing in is one you already got into, and refusing to reload it on a rule
## about the hub would strand the player inside it.
func has_brush() -> bool:
	var profile := get_node_or_null(^"/root/PlayerProfile")
	return profile != null and bool(profile.call("has_brush"))


## The level after this one, or "" if this is the last card in the catalog.
##
## READ OFF `number`, NOT OFF THE ID. PlayerProfile derives the next id by adding one to the
## digits on the end, which is fine for unlocking -- it only has to name a key -- and wrong
## for a door: the door has to lead to a level that EXISTS, in the order the catalog is
## sorted in, and a hub whose fifth painting is called something other than `level_5` would
## send the player nowhere with no error.
func next_level_id(level_id: String) -> String:
	var here := int(get_level(level_id).get("number", 0))
	if here <= 0:
		return ""
	# _levels is sorted by number at load, so the first one past this is the next one.
	for entry in _levels:
		if int(entry.get("number", 0)) > here:
			return String(entry.get("id", ""))
	return ""


## Whether a level has content behind it. Deliberately separate from is_unlocked,
## which means PROGRESSION: finishing level 1 unlocks level 2 in the profile, and the
## menu would then enable a card whose scene_path is empty -- an enabled button that
## silently does nothing when clicked.
func take_pending_reveal() -> String:
	var out := pending_reveal
	pending_reveal = ""
	return out


func is_playable(level_id: String) -> bool:
	var scene_path := String(get_level(level_id).get("scene_path", ""))
	return not scene_path.is_empty() and ResourceLoader.exists(scene_path)


## Reload the level currently being played.
##
## Deliberately not open_level(current_level_id): that refuses when the level is
## locked, and a level you are standing in is by definition reachable -- refusing to
## restart it because of a progression rule would strand the player in it.
func restart_level() -> bool:
	if _transitioning or current_level_id.is_empty():
		return false
	var scene_path := String(get_level(current_level_id).get("scene_path", ""))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return false
	get_tree().paused = false
	# ⚠ FROM THE BEGINNING, WHATEVER WAS SAVED. Leaving a level keeps its last checkpoint for the
	# next visit (LevelBase._resume_saved_checkpoint), and restarting used to reload straight into
	# it. Kent: "if i click reset the level then the level should start from the beginning of that
	# level regardless if i am returning to it or not." A restart forgets it first.
	var saved := preload("res://scripts/user_data.gd").path("checkpoints/%s.save" % current_level_id)
	if FileAccess.file_exists(saved):
		DirAccess.remove_absolute(saved)
	_transition_to.call_deferred(scene_path, current_level_id)
	return true


## Into the house, from the menu.
func open_house() -> bool:
	if _transitioning or not ResourceLoader.exists(HOUSE_SCENE):
		return false
	_transition_to.call_deferred(HOUSE_SCENE, "")
	return true


## Out of a level and back to the wall of paintings. Named for where it goes rather than
## for the selector it used to open: levels are chosen in a room now, not off a grid.
func return_to_house() -> bool:
	if _transitioning or not ResourceLoader.exists(HOUSE_SCENE):
		return false
	# THE TREE IS PAUSED WHEN THIS IS PRESSED. It is on the pause menu and on the out-of-ink
	# screen, both of which stop the world to show themselves, and a scene change that leaves
	# the flag set hands the house to the player frozen.
	get_tree().paused = false
	current_level_id = ""
	# NOT _transitioning = true HERE. _transition_to opens with `if _transitioning: return`,
	# so setting it first meant the deferred call arrived, saw its own guard already tripped,
	# and returned -- the button reported success and nothing on screen moved. Every other
	# route out of a level leaves the flag to _transition_to; this one was copied from
	# return_to_selector and gained a line that one does not have.
	_transition_to.call_deferred(HOUSE_SCENE, "")
	return true


func return_to_selector() -> bool:
	if _transitioning or not ResourceLoader.exists(SELECTOR_SCENE):
		return false
	get_tree().paused = false
	_selector_requested = true
	_transition_to.call_deferred(SELECTOR_SCENE, "")
	return true


## Back to the title screen itself -- NEW GAME / CONTINUE -- rather than the card grid that
## return_to_selector opens. What the house's MAIN MENU button and Escape do.
func open_main_menu() -> bool:
	if _transitioning or not ResourceLoader.exists(SELECTOR_SCENE):
		return false
	get_tree().paused = false
	_selector_requested = false
	_transition_to.call_deferred(SELECTOR_SCENE, "")
	return true


func consume_selector_request() -> bool:
	var requested := _selector_requested
	_selector_requested = false
	return requested


func _load_catalog() -> void:
	_levels.clear()
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_error("Level catalog could not be opened: %s" % CATALOG_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Array:
		push_error("Level catalog must contain an array")
		return
	for value: Variant in parsed:
		if value is Dictionary:
			_levels.append((value as Dictionary).duplicate(true))
	_levels.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("number", 0)) < int(b.get("number", 0))
	)


func _build_transition_overlay() -> void:
	_transition_layer = CanvasLayer.new()
	_transition_layer.name = "InkTransitionLayer"
	_transition_layer.layer = 1000
	add_child(_transition_layer)

	_transition_root = Control.new()
	_transition_root.name = "InkTransition"
	_transition_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_root.visible = false
	_transition_layer.add_child(_transition_root)

	_wipe_material = ShaderMaterial.new()
	_wipe_material.shader = WIPE_SHADER
	_wipe = ColorRect.new()
	_wipe.name = "Stroke"
	_wipe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe.material = _wipe_material
	_transition_root.add_child(_wipe)


## How far the stroke has gone: 0 none of the screen, 1 all of it ink, 2 gone on past.
func wipe_progress() -> float:
	return float(_wipe_material.get_shader_parameter(&"progress"))


func _transition_to(scene_path: String, level_id: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	transition_started.emit(scene_path)
	_transition_root.visible = true
	_transition_root.mouse_filter = Control.MOUSE_FILTER_STOP
	await _animate_wipe(true)

	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Could not change scene to %s (error %d)" % [scene_path, error])
		await _animate_wipe(false)
		_finish_transition(scene_path)
		return
	if not level_id.is_empty():
		level_changed.emit(level_id)
	await get_tree().process_frame
	await get_tree().process_frame
	await _animate_wipe(false)
	_finish_transition(scene_path)


func _animate_wipe(covering: bool) -> void:
	var to := 1.0 if covering else 2.0
	if transition_step_seconds <= 0.0:
		_wipe_material.set_shader_parameter(&"progress", to)
		return
	if Motion.reduced():
		# No sweep: the screen fades to ink and back.
		_wipe_material.set_shader_parameter(&"progress", 1.0)
		_wipe.modulate.a = 0.0 if covering else 1.0
		var fade := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		fade.tween_property(_wipe, "modulate:a", 1.0 if covering else 0.0, Motion.QUICK_FADE * 2.0)
		await fade.finished
		if not covering:
			_wipe_material.set_shader_parameter(&"progress", 2.0)
			_wipe.modulate.a = 1.0
		return
	_wipe.modulate.a = 1.0
	_wipe_material.set_shader_parameter(&"progress", 0.0 if covering else 1.0)
	var sweep := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	sweep.tween_property(_wipe_material, "shader_parameter/progress", to, WIPE_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN if covering else Tween.EASE_OUT)
	await sweep.finished


func _finish_transition(destination: String) -> void:
	_transition_root.visible = false
	_transition_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transitioning = false
	transition_finished.emit(destination)
