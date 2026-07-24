extends Node
## Persistent catalog and pixel-step scene transition coordinator.

signal transition_started(destination: String)
signal level_changed(level_id: String)
signal transition_finished(destination: String)

const CATALOG_PATH := "res://config/levels.json"
const SELECTOR_SCENE := "res://ui/main_menu.tscn"
const GRID_COLUMNS := 20
const GRID_ROWS := 12

var current_level_id := ""
var transition_step_seconds := 0.012

var _levels: Array[Dictionary] = []
var _transitioning := false
var _selector_requested := false
var _transition_layer: CanvasLayer
var _transition_root: Control
var _blocks: Array[ColorRect] = []


func _ready() -> void:
	_load_catalog()
	_build_transition_overlay()
	get_viewport().size_changed.connect(_layout_transition_blocks)


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
	if _transitioning or not is_unlocked(level_id):
		return false
	var entry := get_level(level_id)
	var scene_path := String(entry.get("scene_path", ""))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return false
	current_level_id = level_id
	_transition_to.call_deferred(scene_path, level_id)
	return true


func return_to_selector() -> bool:
	if _transitioning or not ResourceLoader.exists(SELECTOR_SCENE):
		return false
	get_tree().paused = false
	_selector_requested = true
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
	_transition_layer.name = "PixelTransitionLayer"
	_transition_layer.layer = 1000
	add_child(_transition_layer)

	_transition_root = Control.new()
	_transition_root.name = "PixelTransition"
	_transition_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_root.visible = false
	_transition_layer.add_child(_transition_root)

	for row in range(GRID_ROWS):
		for column in range(GRID_COLUMNS):
			var block := ColorRect.new()
			block.name = "Block_%02d_%02d" % [column, row]
			var shade := 0.055 + float((column + row) % 3) * 0.012
			block.color = Color(shade, 0.105 + shade, 0.075, 1.0)
			block.mouse_filter = Control.MOUSE_FILTER_IGNORE
			block.visible = false
			_transition_root.add_child(block)
			_blocks.append(block)
	_layout_transition_blocks()


func _layout_transition_blocks() -> void:
	if _transition_root == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1600.0, 900.0)
	var block_size := Vector2(
		ceilf(viewport_size.x / float(GRID_COLUMNS)),
		ceilf(viewport_size.y / float(GRID_ROWS))
	)
	for row in range(GRID_ROWS):
		for column in range(GRID_COLUMNS):
			var block := _blocks[row * GRID_COLUMNS + column]
			block.position = Vector2(column, row) * block_size
			block.size = block_size + Vector2.ONE


func _transition_to(scene_path: String, level_id: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	transition_started.emit(scene_path)
	_transition_root.visible = true
	_transition_root.mouse_filter = Control.MOUSE_FILTER_STOP
	await _animate_blocks(true)

	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Could not change scene to %s (error %d)" % [scene_path, error])
		await _animate_blocks(false)
		_finish_transition(scene_path)
		return
	if not level_id.is_empty():
		level_changed.emit(level_id)
	await get_tree().process_frame
	await get_tree().process_frame
	await _animate_blocks(false)
	_finish_transition(scene_path)


func _animate_blocks(covering: bool) -> void:
	var last_band := GRID_COLUMNS + GRID_ROWS - 2
	var bands: Array[int] = []
	for band in range(last_band + 1):
		bands.append(band)
	if not covering:
		bands.reverse()
	for band in bands:
		for row in range(GRID_ROWS):
			var column := band - row
			if column >= 0 and column < GRID_COLUMNS:
				_blocks[row * GRID_COLUMNS + column].visible = covering
		if transition_step_seconds > 0.0:
			await get_tree().create_timer(transition_step_seconds, true, false, true).timeout


func _finish_transition(destination: String) -> void:
	_transition_root.visible = false
	_transition_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transitioning = false
	transition_finished.emit(destination)
