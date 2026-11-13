extends SceneTree
## A drawing had again from the bag, not drawn: it costs what drawing it costs, and is refused where
## drawing is refused.
##
##   godot --headless --path game --script res://tests/run_draw_again_probe.gd
##
## Kent: "implement the draggable inventory wherein the users wont have to draw something if drawn
## already but it should cost ink just like the same". A card the player has drawn is dragged out of
## the bag (or its USE IT AGAIN pressed) and the level makes it from the page the class was last
## drawn on, down the door a fresh drawing comes through (LevelBase._draw_again).
##
## ⚠ EVERY COST HERE IS A COMPARISON, NOT A NUMBER. Each case draws the thing fresh, puts the
## world back as it was, has it again from the bag, and asks that the gauge moved the same. The
## prices are FR-7's and the levels' own (a creature free in Payyo and a unit in Mayon, a tool once,
## a placeable when it is set down) and they may change; what must not is the two agreeing.

const DRAWN := preload("res://tests/drawn_like_people_fixtures.gd")
const CHECKS := 13

var level: Node
var failures := 0
var checked := 0
var _results: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _open("res://game_level.tscn")
	var profile := root.get_node("PlayerProfile")
	(profile.get("_data")["classes_drawn_accepted"] as Array).clear()
	(profile.get("_data")["acquired_objects"] as Array).clear()
	await _a_recognised_drawing_keeps_its_page()
	await _the_bag_offers_a_drawn_card_again()
	await _a_creature_had_again_costs_what_drawing_it_costs()
	await _a_tool_had_again_costs_what_drawing_it_costs()
	await _a_thing_to_set_down_had_again_waits_to_be_paid_for()
	await _close_level()
	await _open("res://level_5.tscn")
	await _in_mayon_a_creature_had_again_costs_a_unit_too()
	await _where_the_brush_refuses_the_bag_makes_nothing()
	await _close_level()
	for line in _results:
		print(line)
	if checked != CHECKS:
		print("OBRA_DRAW_AGAIN_FAILED: %d checks ran, %d expected" % [checked, CHECKS])
		quit(1)
	elif failures == 0:
		print("OBRA_DRAW_AGAIN_OK")
		quit(0)
	else:
		print("OBRA_DRAW_AGAIN_FAILED=%d" % failures)
		quit(1)


# --- Payyo ----------------------------------------------------------------------------------

## The page is kept as it was drawn: every stroke, every point, and how sure the recogniser was.
func _a_recognised_drawing_keeps_its_page() -> void:
	var profile := root.get_node("PlayerProfile")
	var strokes := _strokes_for("frog")
	await _draw("frog", strokes)
	await _settle()
	var page: Dictionary = profile.call("class_page", "frog")
	var kept: Array = page.get("strokes", [])
	var same := kept.size() == strokes.size()
	for i in range(mini(kept.size(), strokes.size())):
		var a := PackedVector2Array((kept[i] as Dictionary)["points"])
		var b := PackedVector2Array((strokes[i] as Dictionary)["points"])
		same = same and a.size() == b.size() and a[0].is_equal_approx(b[0]) \
			and a[a.size() - 1].is_equal_approx(b[b.size() - 1])
	_check(bool(profile.call("has_class_page", "frog")) and same
			and is_equal_approx(float(page.get("confidence", 0.0)), 0.91)
			and page.get("image") is Image,
		"a recognised drawing keeps its whole page", "%d of %d strokes, confidence %.2f" % [
			kept.size(), strokes.size(), float(page.get("confidence", 0.0))])


## A drawn card offers itself again, by drag and by its button; one whose page was never kept says
## to draw it once more and offers nothing to drag.
func _the_bag_offers_a_drawn_card_again() -> void:
	var screen := level.get("inventory_screen") as InventoryScreen
	var drawn: Array = root.get_node("PlayerProfile").get("_data")["classes_drawn_accepted"]
	if not drawn.has("bird"):
		drawn.append("bird")
	screen.open()
	await _wait(0.3)
	screen.call("_choose_drawn", "frog")
	await _wait(0.1)
	var button := screen.get("_use_button") as Button
	var carried: Variant = screen.call("_drag_from_roster", Vector2.ZERO, "frog")
	_check(button.visible and not button.disabled and button.text == "USE IT AGAIN"
			and carried is Dictionary and String((carried as Dictionary).get("drawn_class", "")) == "frog",
		"a drawn card can be dragged out, or used again", "button \"%s\"%s, carries %s" % [
			button.text, " (off)" if button.disabled else "", str(carried)])
	screen.call("_choose_drawn", "bird")
	await _wait(0.1)
	var nothing: Variant = screen.call("_drag_from_roster", Vector2.ZERO, "bird")
	_check(button.visible and button.disabled and button.text == "REDRAW FIRST" and nothing == null,
		"one with no page kept says to redraw it first", "button \"%s\"%s, carries %s" % [
			button.text, " (off)" if button.disabled else "", str(nothing)])
	drawn.erase("bird")
	screen.close()
	await _settle()


## In Payyo a creature is free to become, drawn or had again; had again it is her, the bag shuts,
## and it is logged as a reuse -- not as a recognition, not as a submission.
func _a_creature_had_again_costs_what_drawing_it_costs() -> void:
	var ink = level.get("ink_manager")
	level.call("_revert_to_base_form")
	await _settle()
	_refill(ink)
	var before := float(ink.call("remaining"))
	await _draw("frog", _strokes_for("frog"))
	var drawn_cost := before - float(ink.call("remaining"))
	level.call("_revert_to_base_form")
	await _settle()
	_refill(ink)
	var screen := level.get("inventory_screen") as InventoryScreen
	screen.open()
	await _wait(0.3)
	var log_before := _telemetry_lines().size()
	var submissions := _submissions()
	before = float(ink.call("remaining"))
	screen.call("_drop_outside", Vector2.ZERO, {"drawn_class": "frog"})
	var again_cost := before - float(ink.call("remaining"))
	await _settle()
	_check(not screen.is_open() and String(level.get("_current_form_id")) == "frog",
		"dragged out of the bag, the frog is her", "form \"%s\", bag %s" % [
			level.get("_current_form_id"), "open" if screen.is_open() else "shut"])
	_check(is_equal_approx(drawn_cost, again_cost), "and it costs what drawing it costs",
		"drawn %.2f, had again %.2f" % [drawn_cost, again_cost])
	var types := _events_since(log_before)
	_check(types.has("drawing_reused") and not types.has("recognition") and _submissions() == submissions,
		"and is logged as a reuse, not a drawing", "events %s, submissions %d -> %d" % [
			str(types), submissions, _submissions()])
	level.call("_revert_to_base_form")
	await _settle()


## A tool is paid for the first time it is had, then is free (FR-7) -- drawn or had again.
func _a_tool_had_again_costs_what_drawing_it_costs() -> void:
	var ink = level.get("ink_manager")
	var axe := _strokes_for("axe")
	var drawn_costs: Array[float] = []
	_start_without("axe")
	for _time in range(2):
		var before := float(ink.call("remaining"))
		await _draw("axe", axe)
		drawn_costs.append(before - float(ink.call("remaining")))
		await _settle()
	_start_without("axe")
	var again_costs: Array[float] = []
	for _time in range(2):
		var before := float(ink.call("remaining"))
		level.call("_draw_again", "axe")
		again_costs.append(before - float(ink.call("remaining")))
		await _settle()
	var held = level.get("_equipped_utility")
	_check(is_equal_approx(drawn_costs[0], again_costs[0]) and is_equal_approx(drawn_costs[1], again_costs[1]),
		"a tool had again costs what drawing it costs, first time and after",
		"drawn %.2f then %.2f, had again %.2f then %.2f" % [drawn_costs[0], drawn_costs[1],
			again_costs[0], again_costs[1]])
	_check(held != null and is_instance_valid(held) and held.item_data != null
			and held.item_data.entity_id == "axe",
		"and it comes out into her hand", "holding %s" % (
			held.item_data.entity_id if held != null and is_instance_valid(held) else "nothing"))
	_start_without("axe")


## A thing to set down is paid for when it is set down. Had again it is on the pointer straight
## away and still owes its unit, as a fresh one taken from its pocket does; with no ink, both are
## refused the pointer alike.
func _a_thing_to_set_down_had_again_waits_to_be_paid_for() -> void:
	var ink = level.get("ink_manager")
	var placement := level.get("placement_controller") as PlacementController
	var bag := level.get("inventory_manager") as InventoryManager
	var ladder := _strokes_for("ladder")
	_start_without("ladder")
	var before := float(ink.call("remaining"))
	await _draw("ladder", ladder)
	var drawn_cost := before - float(ink.call("remaining"))
	var fresh := bag.peek_item(level.call("_slot_holding", "ladder"))
	var fresh_owes := fresh != null and not fresh.placement_paid
	_start_without("ladder")
	before = float(ink.call("remaining"))
	level.call("_draw_again", "ladder")
	var again_cost := before - float(ink.call("remaining"))
	var on_pointer: DrawnItemData = placement.get("_item")
	_check(placement.is_placing() and on_pointer != null and on_pointer.entity_id == "ladder",
		"a ladder had again is on the pointer", "placing %s" % (
			on_pointer.entity_id if on_pointer != null else "nothing"))
	_check(is_equal_approx(drawn_cost, again_cost) and fresh_owes and on_pointer != null
			and not on_pointer.placement_paid,
		"and owes its unit, as a fresh one does", "drawn %.2f, had again %.2f, owes %s / %s" % [
			drawn_cost, again_cost, fresh_owes, on_pointer != null and not on_pointer.placement_paid])
	placement.cancel_placement()
	await _settle()
	# Empty: the fresh one cannot come out of its pocket, and the one had again cannot either.
	_start_without("ladder")
	await _draw("ladder", ladder)
	ink.set("committed", float(ink.get("capacity")))
	ink.call("release_attempt")
	level.call("_on_inventory_slot_pressed", int(level.call("_slot_holding", "ladder")))
	var fresh_says := String((level.get("status_label") as Label).text)
	var fresh_placing := placement.is_placing()
	_empty(bag)
	level.call("_draw_again", "ladder")
	var again_says := String((level.get("status_label") as Label).text)
	_check(not fresh_placing and not placement.is_placing() and fresh_says == again_says
			and again_says.contains("none left"),
		"with no ink, both are refused alike", "fresh \"%s\", had again \"%s\"" % [fresh_says, again_says])
	if placement.is_placing():
		placement.cancel_placement()
	_start_without("ladder")


# --- Mayon ----------------------------------------------------------------------------------

## Mayon charges every drawing, a creature too: had again, the same unit.
func _in_mayon_a_creature_had_again_costs_a_unit_too() -> void:
	var ink = level.get("ink_manager")
	_refill(ink)
	var before := float(ink.call("remaining"))
	await _draw("frog", _strokes_for("frog"))
	var drawn_cost := before - float(ink.call("remaining"))
	level.call("_revert_to_base_form")
	await _settle()
	_refill(ink)
	before = float(ink.call("remaining"))
	level.call("_draw_again", "frog")
	var again_cost := before - float(ink.call("remaining"))
	_check(String(level.get("_current_form_id")) == "frog" and drawn_cost > 0.5
			and is_equal_approx(drawn_cost, again_cost),
		"in Mayon a frog had again costs its unit, as drawn", "drawn %.2f, had again %.2f, form \"%s\"" % [
			drawn_cost, again_cost, level.get("_current_form_id")])
	level.call("_revert_to_base_form")
	await _settle()


## Where the brush makes nothing -- Mayon, as she tries to draw him -- the bag makes nothing either.
func _where_the_brush_refuses_the_bag_makes_nothing() -> void:
	var ink = level.get("ink_manager")
	_refill(ink)
	var was := String(level.get("_lolo_moment"))
	level.set("_lolo_moment", "waiting")
	var log_before := _telemetry_lines().size()
	var before := float(ink.call("remaining"))
	var form_before := String(level.get("_current_form_id"))
	level.call("_draw_again", "frog")
	var types := _events_since(log_before)
	_check(String(level.get("_current_form_id")) == form_before
			and is_equal_approx(before, float(ink.call("remaining"))) and not types.has("drawing_reused"),
		"where the brush refuses, nothing comes out of the bag", "form \"%s\", spent %.2f, events %s" % [
			level.get("_current_form_id"), before - float(ink.call("remaining")), str(types)])
	level.set("_lolo_moment", was)


# --- Helpers --------------------------------------------------------------------------------

## A fresh drawing of `id`: the page opens, and the recogniser answers with it.
func _draw(id: String, strokes: Array) -> void:
	var panel := level.get("draw_panel") as DrawPanel
	level.call("_open_the_page", false)
	await process_frame
	var entry: Dictionary = (level.get("registry") as Node).call("get_entity", id)
	panel.set("_pending_strokes", strokes)
	panel.set("_submit_started_usec", Time.get_ticks_usec())
	panel.client.entity_prediction_received.emit(id, String(entry.get("display_name", id)), 0.91,
		_page(), {"confidence": 0.91})


func _page() -> Image:
	var page := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	page.fill(Color(0.96, 0.94, 0.88))
	return page


func _strokes_for(id: String) -> Array:
	for fixture: Dictionary in DRAWN.all():
		if String(fixture.get("entity_id", "")) == id:
			return (fixture["strokes"] as Array).duplicate(true)
	# Not a creature: two rails and three rungs serve an axe and a ladder alike.
	var out: Array = []
	for line: Array in [[Vector2(200, 120), Vector2(200, 400)], [Vector2(300, 120), Vector2(300, 400)],
			[Vector2(200, 180), Vector2(300, 180)], [Vector2(200, 260), Vector2(300, 260)],
			[Vector2(200, 340), Vector2(300, 340)]]:
		out.append({"points": DRAWN.dense(PackedVector2Array(line)), "width": 6.0, "color": Color.BLACK})
	return out


## The world as a case starts it: the class not yet acquired, nothing in the bag or the hand, the
## gauge full, nothing on the pointer.
func _start_without(id: String) -> void:
	(root.get_node("PlayerProfile").get("_data")["acquired_objects"] as Array).erase(id)
	var placement := level.get("placement_controller") as PlacementController
	if placement.is_placing():
		placement.cancel_placement()
	level.call("_stow_equipped")
	_empty(level.get("inventory_manager") as InventoryManager)
	_refill(level.get("ink_manager"))


func _empty(bag: InventoryManager) -> void:
	for slot in range(bag.capacity):
		while bag.take_item(slot) != null:
			pass


func _refill(ink) -> void:
	ink.set("committed", 0.0)
	ink.call("release_attempt")


func _submissions() -> int:
	return int((root.get_node("PlayerProfile").get("_data")["counts"] as Dictionary).get("submissions", 0))


func _telemetry_lines() -> Array:
	var telemetry := root.get_node_or_null("Telemetry")
	var file: Variant = telemetry.get("_file") if telemetry != null else null
	if not (file is FileAccess):
		return []
	(file as FileAccess).flush()
	var text := FileAccess.get_file_as_string((file as FileAccess).get_path_absolute())
	return Array(text.split("\n", false))


func _events_since(index: int) -> Array[String]:
	var types: Array[String] = []
	for line: Variant in _telemetry_lines().slice(index):
		var event: Variant = JSON.parse_string(String(line))
		if event is Dictionary:
			types.append(String((event as Dictionary).get("type", "")))
	return types


func _open(path: String) -> void:
	level = (load(path) as PackedScene).instantiate()
	level.get_node("BackendSupervisor").set("auto_start_backend", false)
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
	await _settle()


func _close_level() -> void:
	level.queue_free()
	level = null
	await process_frame
	await process_frame


func _settle() -> void:
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
			break
	await _wait(0.1)


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if not ok:
		failures += 1
	_results.append("  %s  %-58s %s" % ["OK  " if ok else "FAIL", what, detail])
