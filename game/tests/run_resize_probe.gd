extends SceneTree
## A drawing can be made bigger or smaller while it is placed -- and stays its own size if not.
##
##   godot --headless --path game --script res://tests/run_resize_probe.gd
##
## Kent: "add a feature wherein the player can resize their drawings in cases that its placeable
## since there are parts where it needs a bridge right but the default scale of the drawing is
## not big enough or not too small enough, keep the default size/scale if the user decides not
## to resize". Driven the way a player drives it: a bridge drawn and taken out of the bag, then
## Shift+scroll, held keys and a pinch as input events. And then the case he named: a bridge too
## short for the lake before the gorge, made long enough, and walked across.

var level: Node
var placement: PlacementController
var failures := 0
var results: Array[String] = []

const BRIDGE := [Vector2(0, 0), Vector2(400, 0), Vector2(400, 40), Vector2(0, 40), Vector2(0, 0)]


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	results.append("  %s  %-56s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	print("\n===== RESIZING A DRAWING =====")
	level = (load("res://game_level.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(40)
	await _unpause()
	placement = level.get("placement_controller") as PlacementController
	await _left_alone_it_keeps_its_size()
	await _the_player_can_resize_it()
	await _put_back_it_keeps_the_size_it_had()
	await _set_down_it_keeps_the_size_it_was_given()
	await _a_bridge_made_long_enough_crosses_the_lake()
	for line in results:
		print(line)
	print("OBRA_RESIZE_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)


var _authored_width := 0.0


func _left_alone_it_keeps_its_size() -> void:
	var apo := _stand_at(Vector2(1900.0, 270.0))
	await _frames(20)
	var item := _draw_a_bridge()
	_take_out(item)
	await _frames(2)
	_check(placement.is_placing() and is_equal_approx(placement.size_scale(), 1.0),
		"taken out, it is the size it was drawn to", "%d%%" % roundi(placement.size_scale() * 100.0))
	var ghost := placement.get("_preview") as PhysicsShapeObject
	_authored_width = ghost.world_extent().size.x
	_check(absf(_authored_width - 340.0) < 12.0, "which for a bridge is its authored length",
		"%.0fpx against object_sizes.json's 340" % _authored_width)
	var placed := await _set_down_at(apo.global_position + Vector2(260.0, -20.0))
	_check(placed != null and is_equal_approx(placed.size_scale, 1.0)
			and is_equal_approx(item.size_scale, 1.0),
		"set down without resizing, it keeps that size",
		"%.0fpx, %d%%" % [placed.world_extent().size.x, roundi(item.size_scale * 100.0)]
			if placed != null else "not placed")
	_take_back(placed)
	await _frames(4)


func _the_player_can_resize_it() -> void:
	var item := _item_in_the_bag()
	_take_out(item)
	await _frames(2)
	placement.set_process(false)
	for _notch in range(3):
		_wheel(MOUSE_BUTTON_WHEEL_UP, true)
		await process_frame
	var three := placement.size_scale()
	_check(absf(three - pow(1.1, 3)) < 0.01, "Shift+scroll up makes it bigger, a tenth a notch",
		"%d%% after three notches" % roundi(three * 100.0))
	var ghost := placement.get("_preview") as PhysicsShapeObject
	_check(absf(ghost.world_extent().size.x - _authored_width * three) < 6.0,
		"and the drawing and its body grow with it",
		"%.0fpx, against %.0fpx at 100%%" % [ghost.world_extent().size.x, _authored_width])
	_wheel(MOUSE_BUTTON_WHEEL_RIGHT, true)
	await process_frame
	_check(absf(placement.size_scale() - pow(1.1, 2)) < 0.01,
		"Shift+scroll sideways counts too (macOS sends it so)", "%d%%" % roundi(placement.size_scale() * 100.0))
	_wheel(MOUSE_BUTTON_WHEEL_UP, false)
	await process_frame
	_check(absf(placement.size_scale() - pow(1.1, 2)) < 0.01 and not is_zero_approx(ghost.rotation),
		"scroll on its own still turns it, and leaves the size", "%d%%, turned %.0f degrees" % [
			roundi(placement.size_scale() * 100.0), rad_to_deg(ghost.rotation)])
	ghost.rotation = 0.0
	var pinch := InputEventMagnifyGesture.new()
	pinch.factor = 1.25
	Input.parse_input_event(pinch)
	await process_frame
	_check(absf(placement.size_scale() - pow(1.1, 2) * 1.25) < 0.01, "a trackpad pinch resizes it",
		"%d%%" % roundi(placement.size_scale() * 100.0))

	placement.set_process(true)
	Input.action_press(&"grow_placement")
	await _frames(240)
	Input.action_release(&"grow_placement")
	_check(is_equal_approx(placement.size_scale(), PhysicsShapeObject.SIZE_SCALE_MAX),
		"holding V grows it, and no further than double", "%d%%" % roundi(placement.size_scale() * 100.0))
	Input.action_press(&"shrink_placement")
	await _frames(300)
	Input.action_release(&"shrink_placement")
	_check(is_equal_approx(placement.size_scale(), PhysicsShapeObject.SIZE_SCALE_MIN),
		"holding C shrinks it, and no further than half", "%d%%" % roundi(placement.size_scale() * 100.0))
	placement.resize_preview(1.9)
	placement.resize_preview(1.1)
	_check(is_equal_approx(placement.size_scale(), 1.0), "and passing 100% stops there",
		"95%% then a notch up lands on %d%%" % roundi(placement.size_scale() * 100.0))


func _put_back_it_keeps_the_size_it_had() -> void:
	placement.resize_preview(1.8)
	var item := placement.get("_item") as DrawnItemData
	_click(MOUSE_BUTTON_RIGHT)
	await _frames(2)
	_check(not placement.is_placing() and is_equal_approx(item.size_scale, 1.0),
		"resized and put back, it keeps the size it had", "%d%% in the bag" % roundi(item.size_scale * 100.0))


func _set_down_it_keeps_the_size_it_was_given() -> void:
	var apo := level.get("player") as Node2D
	var item := _item_in_the_bag()
	_take_out(item)
	await _frames(2)
	placement.set_process(false)
	placement.resize_preview(1.5)
	var placed := await _set_down_at(apo.global_position + Vector2(300.0, -20.0))
	_check(placed != null and is_equal_approx(item.size_scale, 1.5)
			and absf(placed.world_extent().size.x - _authored_width * 1.5) < 6.0,
		"set down resized, it is that size in the world", "%.0fpx at %d%%" % [
			placed.world_extent().size.x if placed != null else 0.0, roundi(item.size_scale * 100.0)])
	_take_back(placed)
	await _frames(4)
	_take_out(item)
	await _frames(2)
	_check(is_equal_approx(placement.size_scale(), 1.5), "and taken out again, it comes back that size",
		"%d%%" % roundi(placement.size_scale() * 100.0))
	placement.cancel_placement()
	await _frames(2)


## The lake before the gorge is 600px of water, and a bridge is 340. Made 200% -- 680 -- it
## lies across both banks, and the apo walks over it to the shelf before the gorge.
func _a_bridge_made_long_enough_crosses_the_lake() -> void:
	var plane := "EnvironmentBaseplate/GameplayPlane/"
	var water := level.get_node(plane + "WaterAreas/CentralPaddy") as WaterArea2D
	var east := level.get_node(plane + "Terrain/CentralRight") as Node2D
	var lake := Rect2(water.global_position - water.surface_size * 0.5, water.surface_size)
	var apo := _stand_at(Vector2(lake.position.x - 30.0, lake.position.y - 10.0))
	await _frames(30)
	_check(_authored_width < lake.size.x, "a bridge at 100% is shorter than the lake",
		"%.0fpx against %.0fpx" % [_authored_width, lake.size.x])
	var item := _item_in_the_bag()
	_take_out(item)
	await _frames(2)
	placement.set_process(false)
	placement.resize_preview(2.0)
	var placed := await _set_down_at(Vector2(lake.get_center().x, lake.position.y - 30.0))
	if placed == null:
		_check(false, "made 200%, it can be laid across the lake", "refused")
		return
	await _frames(60)
	var span := placed.world_extent()
	_check(span.position.x < lake.position.x and span.end.x > lake.end.x,
		"made 200%, it lies across the lake bank to bank",
		"x %.0f..%.0f over water %.0f..%.0f" % [span.position.x, span.end.x, lake.position.x, lake.end.x])
	# A bridge twice the size is twice as thick too, and the apo does not walk up a ledge: she
	# hops onto it, the way a player does.
	Input.action_press(&"move_right")
	var reached := false
	for frame in range(360):
		if frame % 30 == 0:
			Input.action_press(&"jump")
		elif frame % 30 == 14:
			Input.action_release(&"jump")
		await physics_frame
		await _unpause_if_needed()
		if apo.global_position.x > east.global_position.x + 20.0 and bool(apo.call("is_on_floor")):
			reached = true
			break
	Input.action_release(&"move_right")
	Input.action_release(&"jump")
	_check(reached, "and the apo walks across it to the far shelf",
		"at x %.0f" % apo.global_position.x if reached
			else "stopped at %s, in water %s" % [apo.global_position.round(), apo.call("is_in_water")])


# --- Doing it ----------------------------------------------------------------------------

func _draw_a_bridge() -> DrawnItemData:
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	level.call("_on_drawing_ready", "bridge", "Bridge", sheet, {"confidence": 0.9},
		[{"points": PackedVector2Array(BRIDGE), "width": 6.0, "color": Color.BLACK}], 1.0)
	return _item_in_the_bag()


func _item_in_the_bag() -> DrawnItemData:
	var bag := level.get("inventory_manager") as InventoryManager
	for slot in range(bag.capacity):
		var item := bag.peek_item(slot)
		if item != null and item.entity_id == "bridge":
			return item
	return null


func _take_out(item: DrawnItemData) -> void:
	_refill_the_ink()
	level.call("_on_inventory_slot_pressed", int(level.call("_slot_holding", "bridge")))
	if not placement.is_placing():
		_check(false, "the bridge comes out of the bag to be placed", "it did not")


func _set_down_at(at: Vector2) -> PhysicsShapeObject:
	placement.set_process(false)
	placement.update_target(at)
	await _frames(2)
	placement.update_target(at)
	var ghost := placement.get("_preview") as PhysicsShapeObject
	var placed: bool = placement.confirm_placement()
	placement.set_process(true)
	await _unpause()
	return ghost if placed else null


func _take_back(placed: PhysicsShapeObject) -> void:
	if placed != null and is_instance_valid(placed):
		level.call("_take_back_under_cursor", placed.global_position)


func _stand_at(at: Vector2) -> Node2D:
	var apo := level.get("player") as Node2D
	apo.call("apply_morph_state", {"position": at, "velocity": Vector2.ZERO})
	return apo


func _refill_the_ink() -> void:
	var ink := level.get("ink_manager") as InkManager
	if ink != null:
		ink.committed = 0.0
		ink.reserved = 0.0


func _wheel(button: MouseButton, shift: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.shift_pressed = shift
	event.factor = 1.0
	Input.parse_input_event(event)


func _click(button: MouseButton) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)


func _frames(count: int) -> void:
	for _i in range(count):
		await physics_frame


func _unpause() -> void:
	for _attempt in range(20):
		await _unpause_if_needed()
		await physics_frame


func _unpause_if_needed() -> void:
	if not paused:
		return
	for node in get_nodes_in_group(&"modal_overlays"):
		if node.has_method("is_open") and node.has_method("close") and bool(node.call("is_open")):
			node.call("close")
	call_group(DialogueBox.GROUP, &"hide_line")
	paused = false
