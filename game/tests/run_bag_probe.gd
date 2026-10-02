extends SceneTree
## A drawing going into the bag never stops the player.
##
##   godot --headless --path game --script res://tests/run_bag_probe.gd
##
## Kent: "i dont like how the animation is happening in like whats happening in the inventory,
## i cant scroll, drag, etc. from it". A new drawing came up on the acquisition card -- the
## level dimmed, the drawing held large in the middle for three and a half seconds -- and the
## card answered every mouse press by taking itself down and swallowing it, the wheel
## included. So with a card up, the scroll that turns a placement and the click that sets it
## down did nothing.
##
## Now a drawing flies into its own slot, and the card -- kept for what the game hands the
## player -- leaves the mouse alone. Both are driven the way a player drives them: the drawing
## through the level's own door for a recognised drawing, the mouse as input events.

var level: Node
var results: Array[String] = []
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	results.append("  %s  %-50s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	print("\n===== INTO THE BAG =====")
	level = (load("res://level_2.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(40)
	await _unpause()
	await _a_drawing_flies_into_its_slot()
	await _a_card_leaves_the_mouse_alone()
	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_BAG_OK")
		quit(0)
	else:
		print("OBRA_BAG_FAILED=%d" % failures)
		quit(1)


func _a_drawing_flies_into_its_slot() -> void:
	var cards := level.get("acquired_overlay") as AcquiredOverlay
	var bag := level.get("inventory_hud") as InventoryHUD
	_draw("square")
	var slot := int(level.call("_slot_holding", "square"))
	_check(slot >= 0, "a drawn square goes into the bag", "slot %d" % (slot + 1))
	_check(cards != null and not cards.is_busy(), "and no card dims the level for it",
		"no card" if cards != null and not cards.is_busy() else "the card is up")
	_check(bag.is_arriving(), "it flies to its slot instead",
		"on its way" if bag.is_arriving() else "nothing in flight")
	var art := bag.get("_art")[slot] as TextureRect
	_check(art.modulate.a < 0.01, "and the slot fills when it lands, not before",
		"alpha %.2f in flight" % art.modulate.a)
	var started := Time.get_ticks_msec()
	var waited := 0.0
	while bag.is_arriving() and waited < 2.0:
		await process_frame
		waited = (Time.get_ticks_msec() - started) / 1000.0
	_check(not bag.is_arriving() and art.modulate.a > 0.99, "and it lands",
		"in %.2f s" % waited if not bag.is_arriving() else "still flying after 2 s")
	var said := bag.caption()
	_check(said.contains("press %d" % (slot + 1)), "and the line over the bag names its key",
		"'%s'" % said)


func _a_card_leaves_the_mouse_alone() -> void:
	var cards := level.get("acquired_overlay") as AcquiredOverlay
	var placement := level.get("placement_controller") as PlacementController
	level.call("_on_inventory_slot_pressed", int(level.call("_slot_holding", "square")))
	_check(placement.is_placing(), "the square is taken out to be placed", "a ghost on the cursor")
	await _card_up(cards)
	_check(bool(cards.get("_holding")), "a card for something handed over is up", "holding")
	var ghost := placement.get("_preview") as Node2D
	var turned_from := ghost.rotation
	_wheel(MOUSE_BUTTON_WHEEL_UP)
	await process_frame
	_check(not is_equal_approx(ghost.rotation, turned_from), "the wheel still turns the placement",
		"turned %.0f degrees" % rad_to_deg(ghost.rotation - turned_from)
			if not is_equal_approx(ghost.rotation, turned_from) else "the card ate the scroll")
	_check(bool(cards.get("_holding")), "and does not take the card down",
		"still up" if bool(cards.get("_holding")) else "the scroll took it down")
	# A card up for the click in its own right, whatever the scroll did to the last one.
	await _card_up(cards)
	var heard := [false]
	var answer := func(_a = null, _b = null, _c = null) -> void: heard[0] = true
	placement.placement_confirmed.connect(answer)
	placement.placement_rejected.connect(answer)
	_click(MOUSE_BUTTON_LEFT)
	await process_frame
	_check(heard[0], "a click still reaches the placement", "set down, or refused where it stood"
		if heard[0] else "the card ate the click")
	_check(not bool(cards.get("_holding")), "and the same click takes the card down",
		"going" if not bool(cards.get("_holding")) else "still up")


## A card for something handed over, waited on until it is fully up: before that it answers
## nothing at all, by design.
func _card_up(cards: AcquiredOverlay) -> void:
	if bool(cards.get("_holding")):
		return
	level.call("announce_acquisition", "Kandila", "A candle off a stranger's table.", null)
	for _attempt in range(240):
		await process_frame
		if bool(cards.get("_holding")):
			return


func _draw(entity_id: String) -> void:
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	for x in range(10, 54):
		sheet.set_pixel(x, 10, Color.BLACK)
		sheet.set_pixel(x, 53, Color.BLACK)
	var points := PackedVector2Array([Vector2(0, 0), Vector2(90, 0), Vector2(90, 90), Vector2(0, 90),
		Vector2(0, 0)])
	level.call("_on_drawing_ready", entity_id, entity_id.capitalize(), sheet, {"confidence": 0.9},
		[{"points": points, "width": 6.0, "color": Color.BLACK}], 1.0)


func _wheel(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.factor = 1.0
	Input.parse_input_event(event)


func _click(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	var lift := InputEventMouseButton.new()
	lift.button_index = button
	lift.pressed = false
	Input.parse_input_event(lift)


func _frames(count: int) -> void:
	for _i in range(count):
		await physics_frame


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
