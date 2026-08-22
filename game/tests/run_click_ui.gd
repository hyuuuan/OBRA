extends SceneTree
## Clicks the buttons a player clicks, with a real mouse event, at the pixel each button
## actually occupies.
##
##	 godot --headless --path game --script res://tests/run_click_ui.gd
##
## WHY THIS EXISTS. Every other suite presses buttons with emit_signal("pressed"). That
## calls the handler directly and so cannot fail the way a click fails: it skips hit
## testing, skips whatever Control is lying on top of the button, skips `disabled`, and
## skips the tree's pause state. Everything reported as "the buttons do not work" was
## invisible to the entire test suite for exactly that reason -- every button in the game
## is correctly wired, and several of them could not be pressed.

var passes := 0
var failures := 0
var results: Array[String] = []

var level: Node
var player: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://game_level.tscn") as PackedScene
	level = packed.instantiate()
	# No backend: this is about input reaching a button, not about what the button then
	# asks the recogniser.
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	await _wait(1.0)
	player = level.get("player") as Node2D

	if not await _mouse_reaches_the_gui():
		print("OBRA_CLICK_UI_NEEDS_VIEWPORT  (run without --headless)")
		quit(2)
		return

	await _draw_button_opens_the_panel()
	await _panel_buttons_answer_a_click()
	await _inventory_slot_answers_a_click()
	await _placing_click_reaches_the_world()
	await _dialogue_choices_answer_a_click()

	print("\n===== UI CLICK AUDIT =====")
	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_CLICK_UI_OK")
		quit(0)
	else:
		print("OBRA_CLICK_UI_FAILED=%d" % failures)
		quit(1)


## Does a mouse event reach a Control at all? Everything else here is meaningless if not,
## and the answer is no under --headless.
func _mouse_reaches_the_gui() -> bool:
	var hud := level.get("inventory_hud") as Node
	var slot := _first_button(hud) if hud != null else null
	if slot == null:
		return false
	var landed := [false]
	var probe := func() -> void: landed[0] = true
	slot.pressed.connect(probe)
	await _click(slot)
	slot.pressed.disconnect(probe)
	return landed[0]


## The button in the corner of the HUD. A player who never learns that R opens the panel
## has this and nothing else, so if it does not open the panel there is no game.
##
## Checked AFTER a backend failure on purpose. The button is enabled only by
## `backend_ready`, and a machine with a backend already listening passes this without
## ever exercising the case that matters -- the one where the Python side is slow, absent,
## or wedged, which is every first launch.
func _draw_button_opens_the_panel() -> void:
	var button := level.get_node_or_null("CanvasLayer/DrawButton") as Button
	var panel := level.get_node_or_null("DrawPanel")
	if button == null or panel == null:
		_fail("draw button", "the level has no DrawButton or no DrawPanel")
		return
	var supervisor := level.get_node_or_null("BackendSupervisor")
	if supervisor != null:
		supervisor.emit_signal("backend_failed", "pretend the backend is not there")
		await _wait(0.3)
	_check(not button.disabled, "the Draw button survives a dead backend",
		"still pressable" if not button.disabled
		else "DISABLED for the rest of the session -- nothing ever re-enables it")
	await _click(button)
	_check(bool(panel.call("is_open")), "clicking Draw opens the panel",
		"the panel is %s" % ("open" if bool(panel.call("is_open")) else "still shut"))
	if bool(panel.call("is_open")):
		return
	# Open it the other way so the rest of the run has something to click.
	panel.call("open_panel")
	await _wait(0.4)


## Transform and Clear, which is what a player presses after drawing.
func _panel_buttons_answer_a_click() -> void:
	var panel := level.get_node_or_null("DrawPanel")
	if panel == null:
		return
	if not bool(panel.call("is_open")):
		panel.call("open_panel")
		await _wait(0.4)

	var clear := panel.get_node_or_null("PanelRoot/ClearButton") as Button
	var transform := panel.get_node_or_null("PanelRoot/TransformButton") as Button
	if clear == null or transform == null:
		_fail("panel buttons", "the panel has no Clear or Transform button")
		return

	var cleared := [false]
	clear.pressed.connect(func() -> void: cleared[0] = true)
	await _click(clear)
	_check(cleared[0], "Clear answers a click", "the handler ran")

	var transformed := [false]
	transform.pressed.connect(func() -> void: transformed[0] = true)
	await _click(transform)
	_check(transformed[0], "Transform answers a click", "the handler ran")

	panel.call("close_panel")
	await _wait(0.3)


func _inventory_slot_answers_a_click() -> void:
	var hud := level.get("inventory_hud") as Node
	if hud == null:
		_fail("inventory", "the level has no inventory HUD")
		return
	var slot := _first_button(hud)
	if slot == null:
		_fail("inventory", "the HUD built no slot buttons")
		return
	var pressed := [false]
	(hud as Node).connect(&"slot_pressed", func(_index: int) -> void: pressed[0] = true)
	await _click(slot)
	_check(pressed[0], "an inventory slot answers a click", "slot_pressed fired")


## THE ONE THAT MATTERS AT BEAT 0. The inventory bar is 756x56 across the bottom-centre
## of the screen, and placement is confirmed from _unhandled_input -- which never runs for
## a click the GUI consumed. Setting a drawn step down near the ground means clicking low,
## and the click was landing on a slot button instead and vanishing.
func _placing_click_reaches_the_world() -> void:
	var hud := level.get("inventory_hud") as Node
	var placement := level.get("placement_controller") as Node2D
	var inventory := level.get("inventory_manager") as Node
	if hud == null or placement == null or inventory == null or player == null:
		_fail("placing over the inventory bar", "level did not build placement or inventory")
		return

	var item := DrawnItemData.new()
	item.entity_id = "square"
	item.display_name = "Square"
	var slot_index: int = inventory.call("add_item", item)
	await process_frame
	level.call("_on_inventory_slot_pressed", slot_index)
	await _wait(0.3)
	if not bool(placement.call("is_placing")):
		_fail("placing over the inventory bar", "the placement never started")
		return

	var slot := _first_button(hud)
	var eaten := [false]
	(hud as Node).connect(&"slot_pressed", func(_index: int) -> void: eaten[0] = true)
	await _click(slot)
	_check(not eaten[0], "a placing click is not eaten by the inventory bar",
		"the click went past the HUD to the world" if not eaten[0]
		else "the slot button swallowed it -- this is why a step cannot be set down")
	if bool(placement.call("is_placing")):
		placement.call("cancel_placement")
	await process_frame


func _dialogue_choices_answer_a_click() -> void:
	var overlay := level.get_node_or_null("DialogueChoiceOverlay")
	if overlay == null:
		_fail("dialogue choices", "the level has no DialogueChoiceOverlay")
		return
	var picked := [""]
	overlay.connect(&"route_picked", func(route: String) -> void: picked[0] = route)
	overlay.call("present", "Lolo", "Which?", {
		"artist": "Let us put it back.",
		"pragmatist": "There is another way.",
		"protector": "I will make a way.",
	})
	await _wait(0.5)
	var choices := overlay.get_node_or_null("Root/Center/Panel/VBox/Choices")
	var first := _first_button(choices) if choices != null else null
	if first == null:
		_fail("dialogue choices", "the overlay rendered no buttons")
		return
	await _click(first)
	_check(picked[0] == "artist", "a dialogue choice answers a click",
		"picked '%s'" % picked[0] if not picked[0].is_empty()
		else "nothing was picked -- the question cannot be answered with the mouse")
	if bool(overlay.call("is_open")):
		overlay.call("close")
	await process_frame


## A real click: move there, press, release. Buttons fire on RELEASE by default, so a
## press alone proves nothing, and the motion first is what a mouse actually does.
func _click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	for event in [_motion(at), _button(at, true), _button(at, false)]:
		Input.parse_input_event(event)
		await process_frame
	await process_frame


func _motion(at: Vector2) -> InputEventMouseMotion:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	return motion


func _button(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	return event


func _first_button(node: Node) -> Button:
	for child in node.get_children():
		if child is Button:
			return child as Button
		var found := _first_button(child)
		if found != null:
			return found
	return null


func _check(ok: bool, what: String, detail: String) -> void:
	if ok:
		passes += 1
		results.append("  OK	%s	%s" % [what, detail])
	else:
		_fail(what, detail)


func _fail(what: String, detail: String) -> void:
	failures += 1
	results.append("  FAIL	%s	%s" % [what, detail])


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout
