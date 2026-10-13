extends SceneTree
## EVERY SCREEN FITS EVERY SCREEN.
##   godot --headless --path game --script res://tests/run_screens_fit_probe.gd
##
## Kent: "its not properly oriented or responsive to all screens like some parts are cut off
## ... dont forget the settings screens/keybinds/etc". The game is stretched keep_height
## (project.godot): it is never shown narrower or shorter than 1600 x 900 -- a taller screen
## gets bars above and below -- and a wider one gets more width. So a screen that fits 1600 x
## 900 fits every screen, and one that stays centred on a wide one is the right way round on
## it. Two did not fit: the keybind list was 949 pixels tall, with BACK cut in half under the
## bottom of the screen, and the bag with its tabs was 1620 across -- wider still with a found
## thing chosen, because one line on its card did not wrap.
##
## So this opens every one of them -- the home screen, its settings and keybinds, and every
## overlay in both levels, the bag with its longest card up -- at 1600 x 900 and at 2100 x
## 900, and fails on anything drawn off the screen or off the middle of it.

const SIZES: Array[Vector2i] = [Vector2i(1600, 900), Vector2i(2100, 900)]
const LEVELS := ["res://game_level.tscn", "res://level_2.tscn"]
## How far off the middle a screen may sit before it is the wrong way round.
const OFF_CENTRE := 4.0
const InventoryBagArt = preload("res://scripts/bag_art.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-58s %s" % ["OK  " if ok else "FAIL", what, detail])


func _run() -> void:
	print("\n===== EVERY SCREEN FITS =====")
	for shape in SIZES:
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
		root.content_scale_size = shape
		await _frames(4)
		print("-- %d x %d" % [shape.x, shape.y])
		await _home()
		for path: String in LEVELS:
			await _level(path)
	print("OBRA_SCREENS_FIT_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)


func _home() -> void:
	var menu := (load("res://ui/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await _frames(30)
	# Its buttons and its lettering. The vista behind them bleeds past every edge on purpose.
	_judge("home", _reach(menu, true, true), false)
	for overlay_name: String in ["SettingsOverlay", "ControlsOverlay"]:
		var overlay := menu.find_child(overlay_name, true, false) as CanvasLayer
		if overlay == null:
			_check(false, "home: %s" % overlay_name, "not on the home screen")
			continue
		await _judge_overlay("home: " + overlay_name, overlay)
	menu.queue_free()
	await _frames(6)


func _level(path: String) -> void:
	var level := (load(path) as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(30)
	_fill_the_bag(level)
	for node in get_nodes_in_group(&"modal_overlays"):
		var overlay := node as CanvasLayer
		# The choice overlay is built from the choices it is handed, and none are offered here.
		if overlay == null or not level.is_ancestor_of(overlay) or overlay.name.contains("Choice") \
				or not overlay.has_method("open"):
			continue
		await _judge_overlay("%s: %s" % [path.get_file().get_basename(), overlay.name], overlay)
	# The drawing page, which is not a modal overlay but is a whole screen of its own.
	var page := level.get("draw_panel") as DrawPanel
	page.open_panel()
	await _frames(45)
	# On the screen, brush and all; and the PAGE in the middle -- the brush stands beside it.
	var what := "%s: the drawing page" % path.get_file().get_basename()
	_judge(what, _reach(page, true), false)
	var sheet := page.get_node_or_null(^"PanelRoot/CanvasFrame") as Control
	_judge(what + "'s canvas", sheet.get_global_rect() if sheet != null else Rect2(), true)
	page.close_panel()
	await _frames(8)
	level.queue_free()
	await _frames(6)


## Everything the bag can hold at once, so its pockets and its card are at their widest.
func _fill_the_bag(level: Node) -> void:
	var bag := level.get("inventory_manager") as InventoryManager
	for entity_id: String in ["ladder", "ladder", "axe", "square", "circle", "triangle", "rope"]:
		var item := DrawnItemData.new()
		item.entity_id = entity_id
		item.display_name = entity_id.capitalize()
		bag.add_item(item)
	var profile := root.get_node("PlayerProfile")
	for id: String in ["flower_1", "L2_HF", "L3_HF"]:
		profile.call("record_collectible", id)


func _judge_overlay(what: String, overlay: CanvasLayer) -> void:
	overlay.call("open")
	await _frames(45)
	if overlay is InventoryScreen:
		# Its card at its widest: something found, whose kind line is the longest it prints.
		overlay.call("_choose_found", "hidden_flower")
		await _frames(20)
	_judge(what, _reach(overlay, true), true)
	overlay.call("close")
	await _frames(8)


func _judge(what: String, reach: Rect2, centred: bool) -> void:
	var view := root.get_visible_rect()
	var inside := reach.size == Vector2.ZERO or view.grow(1.0).encloses(reach)
	_check(inside, "%s is on the screen" % what,
		"%s within %s" % [_rect(reach), view.size] if inside else "%s off %s" % [_rect(reach), view.size])
	if centred and reach.size != Vector2.ZERO:
		var off := absf(reach.get_center().x - view.get_center().x)
		_check(off <= OFF_CENTRE, "%s is in the middle" % what, "%.0f px off centre" % off)


## Where what is DRAWN reaches: every visible control that paints something, scale included.
## A scrim that fills the screen is the dimming behind a screen, not the screen.
func _reach(node: Node, skip_fills: bool, lettering_only: bool = false) -> Rect2:
	var view := root.get_visible_rect()
	var out := Rect2()
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		var control := current as Control
		if control != null:
			if not control.is_visible_in_tree():
				continue
			var rect := control.get_global_transform() * Rect2(Vector2.ZERO, control.size)
			var fills := rect.size.x >= view.size.x - 2.0 and rect.size.y >= view.size.y - 2.0
			var counts := (control is Label or control is Button) if lettering_only else _paints(control)
			if counts and not (skip_fills and fills) and rect.size.x > 2.0 and rect.size.y > 2.0:
				out = rect if out.size == Vector2.ZERO else out.merge(rect)
		stack.append_array(current.get_children())
	return out


func _paints(control: Control) -> bool:
	if control is Label or control is TextureRect or control is Button or control is NinePatchRect:
		return true
	if control.get_script() == InventoryBagArt:
		return true
	if control is PanelContainer or control is Panel:
		var box := control.get_theme_stylebox(&"panel")
		return box != null and not (box is StyleBoxEmpty)
	return false


func _rect(rect: Rect2) -> String:
	return "(%d, %d)-(%d, %d)" % [rect.position.x, rect.position.y, rect.end.x, rect.end.y]


func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame
