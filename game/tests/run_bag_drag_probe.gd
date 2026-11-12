extends SceneTree
## A drawing in the bag is dragged out into the world, in every level that keeps a bag.
##
##   godot --headless --path game --script res://tests/run_bag_drag_probe.gd
##
## Kent: "make the inventory draggable so that the users wont have to draw the exact same thing".
## A drawing in the bar came out with its key or a click, and a player who dragged it to where it
## should go got nothing -- the press never landed as a click -- and drew it again.
##
## Godot's own drag needs a real pointer, which no headless run has (run_click_ui drags one with a
## real mouse). So the drag here is begun and ended through the functions Godot calls on the bar
## -- the slot's forwarded `_drag_from_slot`, the world's `_can_drop` / `_drop`, the bar's
## NOTIFICATION_DRAG_END -- and the drop lands wherever the ghost is, which is what a pointer moves.
##
## In every level, against the same drawing taken out with its KEY: a drag must cost what the key
## costs and be refused where the key is refused. Mayon's every-drawing-costs-ink, Dilim's wear and
## the paid-once placeable are all the slot's rules, and a drag goes through the slot.

## Three on the bar itself, then eight in each level.
const CHECKS := 3 + 8 * 5
const LEVELS := [
	"res://game_level.tscn", "res://level_2.tscn", "res://level_3.tscn",
	"res://level_4.tscn", "res://level_5.tscn",
]
const PLACEABLE := "ladder"
const TOOL := "rake"

var level: Node
var results: Array[String] = []
var failures := 0
var checked := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	results.append("  %s  %-58s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	print("\n===== OUT OF THE BAG, DRAGGED =====")
	# `-- game_level` runs one level's worth, for a mutation run; the full count is the suite's.
	var levels: Array = LEVELS
	var expected := CHECKS
	var only := OS.get_cmdline_user_args()
	if not only.is_empty():
		levels = LEVELS.filter(func(path: String) -> bool:
			return path.get_file().get_basename() in only)
		expected = 3 + 8 * levels.size()
	var first := true
	for path: String in levels:
		await _open(path)
		if level == null:
			_check(false, "%s opens" % path, "it did not")
			continue
		if first:
			await _the_bar_looks_grabbable()
			first = false
		await _a_drag_sets_it_down(path)
		await _a_bad_spot_sends_it_back(path)
		await _over_the_bag_it_goes_back(path)
		await _right_click_mid_drag_puts_it_back(path)
		await _a_tool_dragged_out_is_held(path)
		level.queue_free()
		level = null
		await process_frame
		await process_frame
	for line in results:
		print(line)
	if checked != expected:
		print("OBRA_BAG_DRAG_FAILED: %d checks ran, %d expected" % [checked, expected])
		quit(1)
	elif failures == 0:
		print("OBRA_BAG_DRAG_OK")
		quit(0)
	else:
		print("OBRA_BAG_DRAG_FAILED=%d" % failures)
		quit(1)


func _open(path: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		level = null
		return
	level = packed.instantiate()
	var supervisor := level.get_node_or_null("BackendSupervisor")
	if supervisor != null:
		supervisor.set("auto_start_backend", false)
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	# On the clock, not on frames: a level is ready when it has a player and a bag.
	var waited := 0.0
	while waited < 8.0:
		await _wait(0.1)
		waited += 0.1
		var body := level.get("player") as Node2D
		if body != null and is_instance_valid(body) and level.get("inventory_hud") != null:
			break
	if level.has_method("_end_the_opening"):
		level.call("_end_the_opening", true)
	await _unpause()
	await _wait(0.3)
	await _unpause()


# --- The bar itself -----------------------------------------------------------------------

## A slot holding something says it can be picked up; an empty one does not offer a drag.
func _the_bar_looks_grabbable() -> void:
	var hud := level.get("inventory_hud") as InventoryHUD
	var bag := level.get("inventory_manager") as InventoryManager
	_empty(bag)
	bag.add_item(_item(PLACEABLE), 0)
	var buttons: Array = hud.get("_buttons")
	var full := buttons[0] as Button
	var empty := buttons[1] as Button
	var lit := full.get_theme_stylebox(&"hover") as StyleBoxFlat
	var rest := full.get_theme_stylebox(&"normal") as StyleBoxFlat
	_check(lit != null and rest != null and lit.border_color != rest.border_color
			and full.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
		"a full slot lights under the pointer, with a hand",
		"ring %s over %s" % [lit.border_color.to_html(false) if lit != null else "-",
			rest.border_color.to_html(false) if rest != null else "-"])
	var nothing: Variant = hud.call("_drag_from_slot", Vector2.ZERO, 1)
	_check(nothing == null and empty.mouse_default_cursor_shape != Control.CURSOR_POINTING_HAND,
		"an empty slot offers nothing to drag", "data %s" % str(nothing))
	# Pulled off its slot: the line over the bar says what letting go does, at the readable floor.
	var data: Variant = hud.call("_drag_from_slot", Vector2.ZERO, 0)
	var caption := level.get_node_or_null("CanvasLayer/BagCaption") as Label
	if caption == null:
		for node in level.find_children("BagCaption", "Label", true, false):
			caption = node as Label
	var size := caption.get_theme_font_size(&"font_size") if caption != null else 0
	_check(data != null and caption != null and caption.visible
			and caption.text == InventoryHUD.DRAG_HINT and size >= UISkin.FONT_CAPTION,
		"what the bar says during a drag is readable",
		"\"%s\" at %d px (the floor is %d)" % [caption.text if caption != null else "-", size,
			UISkin.FONT_CAPTION])
	hud.notification(Control.NOTIFICATION_DRAG_END)
	await _unpause()
	_empty(bag)


# --- One level -------------------------------------------------------------------------------

## Out with the key, set down; the same again by dragging. Both land, and cost the same.
func _a_drag_sets_it_down(path: String) -> void:
	var tag := path.get_file().get_basename()
	var bag := level.get("inventory_manager") as InventoryManager
	var hud := level.get("inventory_hud") as InventoryHUD
	var placement := level.get("placement_controller") as PlacementController
	var ink = level.get("ink_manager")
	var spot: Variant = await _open_ground()
	_empty(bag)
	if spot == null:
		_check(false, "there is open ground beside her (%s)" % tag, "no spot found to set a ladder")
		for _skip in range(2):
			_check(false, "(skipped, %s)" % tag, "no open ground")
		return
	# THE KEY, the way the number does it.
	_refill(ink)
	bag.add_item(_item(PLACEABLE), 0)
	var before := float(ink.call("remaining"))
	level.call("_on_inventory_slot_pressed", 0)
	placement.update_target(spot)
	var keyed := placement.confirm_placement()
	await _unpause()
	var key_cost := before - float(ink.call("remaining"))
	var by_key := level.get("_last_placed") as Node2D
	# Taken away again, so the same spot is open ground for the drag.
	_clear_placed()
	for _frame in range(3):
		await physics_frame
	# THE DRAG.
	_refill(ink)
	bag.add_item(_item(PLACEABLE), 0)
	before = float(ink.call("remaining"))
	var data: Variant = hud.call("_drag_from_slot", Vector2.ZERO, 0)
	var following := placement.is_placing() and placement.source_slot() == 0
	_check(data != null and following and bag.count(0) == 0,
		"a drawing pulled off its slot puts its ghost on the pointer (%s)" % tag,
		"placing %s, the slot holds %d" % [placement.is_placing(), bag.count(0)])
	placement.update_target(spot)
	var catcher := hud.call("drop_target") as Control
	var world := _screen_of(spot)
	var may := bool(hud.call("_can_drop_on_world", world, data)) if data != null else false
	if may:
		hud.call("_drop_on_world", world, data)
	else:
		# Refused: Godot ends the drag, unsuccessful, and the bar hears it.
		hud.notification(Control.NOTIFICATION_DRAG_END)
	await _unpause()
	var dragged_cost := before - float(ink.call("remaining"))
	# Read as a Variant first: what was last set down may be the key's ladder, freed above.
	var last: Variant = level.get("_last_placed")
	var placed: Node2D = last as Node2D if last != null and is_instance_valid(last) else null
	_check(keyed and may and not placement.is_placing() and placed != null and placed != by_key
			and is_instance_valid(placed) and bag.count(0) == 0 and catcher != null,
		"let go on open ground, it is set down there (%s)" % tag,
		"accepted %s, set at %s" % [may, placed.global_position.round() if placed != null else "-"])
	_check(is_equal_approx(dragged_cost, key_cost),
		"and it costs what its key costs (%s)" % tag,
		"%.2f by dragging, %.2f by the key" % [dragged_cost, key_cost])
	_clear_placed()


## Let go where the ghost will not stand -- deep in solid ground, past what it may climb out of --
## refused, and it goes back where it came from. Found by asking the placement itself, round her.
func _a_bad_spot_sends_it_back(path: String) -> void:
	var tag := path.get_file().get_basename()
	var bag := level.get("inventory_manager") as InventoryManager
	var hud := level.get("inventory_hud") as InventoryHUD
	var placement := level.get("placement_controller") as PlacementController
	var ink = level.get("ink_manager")
	_empty(bag)
	_refill(ink)
	bag.add_item(_item(PLACEABLE), 0)
	var before := float(ink.call("remaining"))
	var data: Variant = hud.call("_drag_from_slot", Vector2.ZERO, 0)
	var bad: Variant = _refused_spot() if data != null else null
	var may := data != null and bad != null \
		and bool(hud.call("_can_drop_on_world", _screen_of(bad), data))
	# Refused: Godot ends the drag unsuccessfully, and the bar hears it.
	hud.notification(Control.NOTIFICATION_DRAG_END)
	await _unpause()
	var status := String((level.get("status_label") as Label).text)
	_check(data != null and bad != null and not may,
		"let go where it cannot stand, it is refused (%s)" % tag,
		"no refused spot found round her" if bad == null
			else "the drop is %s at %s" % ["ACCEPTED" if may else "refused", (bad as Vector2).round()])
	_check(not placement.is_placing() and bag.count(0) == 1
			and is_equal_approx(before, float(ink.call("remaining"))) and status.contains("No room"),
		"and goes back into its slot, saying why (%s)" % tag,
		"slot holds %d, \"%s\"" % [bag.count(0), status])


## A spot within her reach the ghost refuses, while one is out: the first, ring by ring, outward.
func _refused_spot() -> Variant:
	var placement := level.get("placement_controller") as PlacementController
	var origin := _anchor()
	for radius: float in [60.0, 160.0, 260.0, 350.0]:
		for step in range(12):
			var at := origin + Vector2.DOWN.rotated(TAU * float(step) / 12.0) * radius
			placement.update_target(at)
			if placement.is_placing() and not placement.is_valid():
				return at
	return null


## Back over the bar, letting go puts it back. Nothing set down, nothing spent.
func _over_the_bag_it_goes_back(path: String) -> void:
	var tag := path.get_file().get_basename()
	var bag := level.get("inventory_manager") as InventoryManager
	var hud := level.get("inventory_hud") as InventoryHUD
	var placement := level.get("placement_controller") as PlacementController
	var ink = level.get("ink_manager")
	_empty(bag)
	_refill(ink)
	bag.add_item(_item(PLACEABLE), 0)
	var before := float(ink.call("remaining"))
	var data: Variant = hud.call("_drag_from_slot", Vector2.ZERO, 0)
	var over := hud.get_global_rect().get_center()
	var may := data != null and bool(hud.call("_can_drop_on_world", over, data))
	if may:
		hud.call("_drop_on_world", over, data)
	await _unpause()
	_check(may and not placement.is_placing() and bag.count(0) == 1
			and is_equal_approx(before, float(ink.call("remaining"))),
		"let go back over the bag, it goes back in (%s)" % tag,
		"accepted %s, slot holds %d" % [may, bag.count(0)])


## Right-click mid-drag: the same put-back right-click gives a placement, and the drag ends.
func _right_click_mid_drag_puts_it_back(path: String) -> void:
	var tag := path.get_file().get_basename()
	var bag := level.get("inventory_manager") as InventoryManager
	var hud := level.get("inventory_hud") as InventoryHUD
	var placement := level.get("placement_controller") as PlacementController
	_empty(bag)
	_refill(level.get("ink_manager"))
	bag.add_item(_item(PLACEABLE), 0)
	var data: Variant = hud.call("_drag_from_slot", Vector2.ZERO, 0)
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	hud.call("_on_catcher_input", right)
	await _unpause()
	_check(data != null and not placement.is_placing() and bag.count(0) == 1
			and not bool(hud.call("is_dragging")),
		"right-click mid-drag puts it back (%s)" % tag,
		"slot holds %d, still dragging %s" % [bag.count(0), hud.call("is_dragging")])


## A tool is not set down: dragged out, it goes into her hand, as its key puts it there.
func _a_tool_dragged_out_is_held(path: String) -> void:
	var tag := path.get_file().get_basename()
	var bag := level.get("inventory_manager") as InventoryManager
	var hud := level.get("inventory_hud") as InventoryHUD
	var placement := level.get("placement_controller") as PlacementController
	_empty(bag)
	level.call("_stow_equipped")
	var tool := _item(TOOL)
	tool.ink_committed = true
	bag.add_item(tool, 2)
	var data: Variant = hud.call("_drag_from_slot", Vector2.ZERO, 2)
	var away := hud.get_global_rect().get_center() + Vector2(600.0, -400.0)
	var may := data != null and bool(hud.call("_can_drop_on_world", away, data))
	if may:
		hud.call("_drop_on_world", away, data)
	await _unpause()
	var held = level.get("_equipped_utility")
	var holding := held != null and is_instance_valid(held) \
		and String(held.get("utility_behavior")) == TOOL
	_check(may and holding and not placement.is_placing() and bag.count(2) == 1,
		"a tool dragged out goes into her hand (%s)" % tag,
		"in hand: %s; still in the bag: %d" % [
			String(held.get("utility_behavior")) if held != null and is_instance_valid(held) else "nothing",
			bag.count(2)])
	level.call("_stow_equipped")
	_empty(bag)


# --- Helpers ---------------------------------------------------------------------------------

## A spot beside her where a ladder stands, found by asking the placement itself.
func _open_ground() -> Variant:
	var placement := level.get("placement_controller") as PlacementController
	var item := _item(PLACEABLE)
	var origin := _anchor()
	if not placement.begin_placement(item, level.get("player") as Node2D, -1):
		return null
	var found: Variant = null
	for offset: Vector2 in [Vector2(160, -40), Vector2(-160, -40), Vector2(220, -120),
			Vector2(-220, -120), Vector2(120, -200), Vector2(-120, -200), Vector2(260, 0),
			Vector2(-260, 0), Vector2(0, -260)]:
		placement.update_target(origin + offset)
		if placement.is_valid():
			found = origin + offset
			break
	# Put back the way any placement is put back; the level files it in the bag, and the caller
	# empties the bag after.
	placement.cancel_placement()
	await process_frame
	return found


func _anchor() -> Vector2:
	var body := level.get("player") as Node2D
	if body != null and body.has_method("get_physics_anchor"):
		var anchor := body.call("get_physics_anchor") as Node2D
		if anchor != null:
			return anchor.global_position
	return body.global_position if body != null else Vector2.ZERO


func _screen_of(world: Vector2) -> Vector2:
	return (level as Node2D).get_viewport().get_canvas_transform() * world


func _clear_placed() -> void:
	var placed: Variant = level.get("_last_placed")
	if placed != null and is_instance_valid(placed):
		(placed as Node).queue_free()


func _empty(bag: InventoryManager) -> void:
	for slot in range(bag.capacity):
		while bag.take_item(slot) != null:
			pass


func _refill(ink) -> void:
	if ink != null:
		ink.set("committed", 0.0)
		ink.call("release_attempt")


func _item(entity_id: String) -> DrawnItemData:
	var item := DrawnItemData.new()
	item.entity_id = entity_id
	item.display_name = entity_id.capitalize()
	# As a drawing arrives in the bag: paid for when it was drawn, never yet set down.
	item.ink_committed = true
	return item


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _unpause() -> void:
	for _attempt in range(20):
		for node in get_nodes_in_group(&"modal_overlays"):
			if node is AcquiredOverlay:
				continue
			if node.has_method("is_open") and node.has_method("close") and bool(node.call("is_open")):
				node.call("close")
		call_group(DialogueBox.GROUP, &"hide_line")
		paused = false
		await physics_frame
		if not paused:
			return
