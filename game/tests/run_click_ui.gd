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
	# The level opens on a line of dialogue, and a conversation stops the tree until the
	# player turns the page. Nobody is here to press a key, so dismiss it the way a skip
	# button would, and keep dismissing them -- otherwise the first obstacle the
	# walker reaches stops the world and it reports the level as a wall.
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	# WAIT ON THE THING, NOT ON A CLOCK. This was `await _wait(1.0)`, and one second is
	# plenty on an idle machine and not always enough on a busy one -- which is exactly the
	# state this suite runs in, because it is usually started the moment another Godot is
	# still shutting down. When it was not enough the HUD had not built its slot buttons
	# yet, so the canary found nothing to click, reported NEEDS_VIEWPORT, and blamed the
	# display server for a race in its own setup.
	if not await _ready_to_click():
		print("OBRA_CLICK_UI_NEEDS_VIEWPORT  (the level never finished building)")
		quit(2)
		return
	player = level.get("player") as Node2D
	_stock_the_bag()
	await process_frame

	if not await _mouse_reaches_the_gui():
		print("OBRA_CLICK_UI_NEEDS_VIEWPORT  (run without --headless)")
		quit(2)
		return

	await _draw_button_opens_the_panel()
	await _panel_buttons_answer_a_click()
	await _inventory_slot_answers_a_click()
	await _dialogue_can_be_advanced()
	await _placing_click_reaches_the_world()
	await _a_click_places_it_and_right_click_takes_it_back()
	await _dialogue_choices_answer_a_click()
	await _escape_during_a_question_is_not_a_pause_menu()

	print("\n===== UI CLICK AUDIT =====")
	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_CLICK_UI_OK")
		quit(0)
	else:
		print("OBRA_CLICK_UI_FAILED=%d" % failures)
		quit(1)


## Everything the run is about to click, actually on screen and laid out.
##
## The window is checked for FOCUS too. Events go straight into the viewport now rather
## than through the window manager, so focus is not needed to deliver them -- but an
## unfocused window on this platform is one that has not finished being mapped, and a
## Control laid out during that has not necessarily settled where it will end up.
## AN EMPTY BAG DRAWS NOTHING, so a suite that clicks a slot has to put something in it
## first. That is also the honest test: a player clicks a slot to place the drawing that is
## in it, and there is no reason to click one that is empty. Without this the canary finds
## no slot to click and blames the display server for a bag with nothing in it.
func _stock_the_bag() -> void:
	var inventory := level.get("inventory_manager") as Node
	if inventory == null:
		return
	var item := DrawnItemData.new()
	item.entity_id = "square"
	item.display_name = "Square"
	inventory.call("add_item", item)


func _ready_to_click() -> bool:
	for _attempt in range(240):
		await process_frame
		var hud := level.get("inventory_hud") as Node
		var draw_button := level.get_node_or_null("CanvasLayer/DrawButton") as Button
		if hud == null or draw_button == null or level.get("player") == null:
			continue
		if _first_button(hud) == null:
			continue
		if draw_button.get_global_rect().get_center().x <= 0.0:
			continue
		if not DisplayServer.window_is_focused():
			continue
		# Settled, then two more frames for the layout pass that follows the last one.
		await process_frame
		await process_frame
		return true
	return false


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


## Press past Lolo's explanation of the canvas, the way a player does. Safe to call when
## there is no briefing -- a level that authored none opens straight to the paper.
func _dismiss_canvas_briefing(panel: Node) -> void:
	var briefing := panel.get_node_or_null("CanvasBriefing")
	if briefing == null:
		return
	var guard := 0
	while bool(briefing.call("is_speaking")) and guard < 10:
		var event := InputEventAction.new()
		event.action = &"ui_accept"
		event.pressed = true
		briefing.call("_input", event)
		guard += 1
		await _wait(0.1)
	await _wait(0.4)


## Transform and Clear, which is what a player presses after drawing.
func _panel_buttons_answer_a_click() -> void:
	var panel := level.get_node_or_null("DrawPanel")
	if panel == null:
		return
	if not bool(panel.call("is_open")):
		panel.call("open_panel")
		await _wait(0.4)
	# ⚠ LOLO EXPLAINS THE CANVAS THE FIRST TIME IT OPENS, and he stands in front of the
	# buttons while he does -- deliberately, so a player does not start drawing through the
	# briefing and lose the strokes when it closes. A player presses past him; so does this.
	await _dismiss_canvas_briefing(panel)

	var clear := panel.get_node_or_null("PanelRoot/ClearButton") as Button
	var transform := panel.get_node_or_null("PanelRoot/TransformButton") as Button
	if clear == null or transform == null:
		_fail("panel buttons", "the panel has no Clear or Transform button")
		return

	var cleared := [false]
	clear.pressed.connect(func() -> void: cleared[0] = true)
	await _click(clear)
	_check(cleared[0], "Clear answers a click", "the handler ran")

	_check(transform.disabled, "Transform is not offered for an empty canvas",
		"nothing drawn, nothing to transform" if transform.disabled
		else "OFFERED -- pressing it posts a blank image and is answered with a 422")

	# Put something on the canvas, the way the panel's own pointer handler would.
	var canvas := panel.get_node_or_null(
		"PanelRoot/SubViewportContainer/SubViewport/Canvas")
	if canvas != null:
		canvas.call("_start_stroke", Vector2(180.0, 120.0))
		for step in range(1, 25):
			canvas.call("_append_point", Vector2(180.0, 120.0).lerp(Vector2(330.0, 380.0),
				float(step) / 24.0))
		canvas.call("_append_point", Vector2(330.0, 380.0), true)
		canvas.set("_current_line", null)
		await _wait(0.3)

	var transformed := [false]
	transform.pressed.connect(func() -> void: transformed[0] = true)
	await _click(transform)
	_check(transformed[0], "Transform answers a click once there is ink",
		"the handler ran")

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


## THE WHOLE LOOP, WITH A MOUSE. Everything above proves a click is not swallowed; this
## proves the click does the thing. A placement is confirmed from _unhandled_input and a
## take-back is a right-click in the same place, so both are exactly the kind of thing
## emit_signal cannot test -- calling the handler skips the routing that decides whether a
## modal, an overlay or the HUD gets the event first, which IS the step under test.
##
## The AIM is set directly and _process is frozen, deliberately. The controller follows
## get_global_mouse_position(), and this project stretches canvas_items -- so the viewport
## is 1600x900 whatever the window is, Input.warp_mouse takes WINDOW pixels, and a warp
## computed from the canvas transform lands somewhere else entirely. Where the preview is
## pointing is not what this suite is for; whether the button press reaches the world and
## confirms it is.
func _a_click_places_it_and_right_click_takes_it_back() -> void:
	var placement := level.get("placement_controller") as Node2D
	var inventory := level.get("inventory_manager") as Node
	var world_items := level.get_node_or_null(
		"EnvironmentBaseplate/GameplayPlane/WorldItemRoot") as Node2D
	if placement == null or inventory == null or world_items == null or player == null:
		_fail("placing with the mouse", "the level did not build what this needs")
		return
	var panel := level.get_node_or_null("DrawPanel")
	if panel != null and bool(panel.call("is_open")):
		panel.call("close_panel")
		await _wait(0.3)
	# Counted, not looked for: an earlier case in this file confirms a placement of its own
	# as a side effect of proving the click gets past the HUD, so "is there a square" is
	# already true before this one starts.
	var before := _squares_in(world_items)

	var item := DrawnItemData.new()
	item.entity_id = "square"
	item.display_name = "Square"
	var slot_index: int = inventory.call("add_item", item)
	await process_frame
	level.call("_on_inventory_slot_pressed", slot_index)
	await _wait(0.3)
	if not bool(placement.call("is_placing")):
		_fail("placing with the mouse", "the placement never started")
		return

	# ⚠ EAST OF THE BODY, AND THE OLD REASON FOR GOING WEST WAS STALE. The comment here said
	# the water is to the east and a square dropped in it drifts -- but LowerPaddy sits at
	# x 600..900 and the spawn is at 150, so east is four hundred pixels of dry terrace.
	# West is the level's own boundary: LeftWall spans x -24..24, and a 72-wide square
	# centred at 54 overlaps it by six pixels. The game was refusing correctly -- red
	# preview, "Can't build that into solid ground" on the status line -- and this test
	# called that a broken click for as long as it has been failing.
	var spot := player.global_position + Vector2(96.0, -40.0)
	placement.set_process(false)
	placement.call("update_target", spot)
	await _wait(0.2)
	# THE PREMISE, CHECKED BEFORE THE CLICK. A spot that is already invalid makes the
	# assertion below test the level's geometry rather than the mouse, and reports it as a
	# failure of the click -- which is exactly how six pixels of wall read as "the click
	# never confirmed".
	if not bool(placement.get("_valid")):
		_fail("placing with the mouse",
			"harness fault: %s is not a placeable spot, so the click has nothing to prove"
			% spot.round())
		placement.call("cancel_placement")
		placement.set_process(true)
		return
	# ⚠ AND A REFUSAL HAS TO SAY SO, which nothing tested until this went looking. The whole
	# reason the stale aim above read as a broken click is that a click into solid ground is
	# SUPPOSED to do nothing -- so the thing that makes it acceptable is the game saying why.
	# Checked first, on the spot that is genuinely blocked, before the good one is used.
	var status := level.get("status_label") as Label
	var wall := player.global_position + Vector2(-96.0, -40.0)
	placement.call("update_target", wall)
	await _wait(0.2)
	if status != null and not bool(placement.get("_valid")):
		status.text = ""
		await _click_at(_screen_of(wall), MOUSE_BUTTON_LEFT)
		await _wait(0.3)
		_check(not status.text.is_empty(),
			"a click into solid ground says why it did nothing",
			"'%s'" % status.text if not status.text.is_empty()
			else "SILENT -- indistinguishable from a broken button")
	placement.call("update_target", spot)
	await _wait(0.2)

	await _click_at(_screen_of(spot), MOUSE_BUTTON_LEFT)
	await _wait(0.4)
	_check(not bool(placement.call("is_placing")), "a left click sets the drawing down",
		"the placement closed" if not bool(placement.call("is_placing"))
		else "STILL PLACING -- the click never confirmed")
	var placed := _last_square(world_items)
	_check(_squares_in(world_items) == before + 1, "and the square is in the world",
		"at %s" % (placed.global_position.round() if placed != null else "nowhere"))
	if placed == null:
		if bool(placement.call("is_placing")):
			placement.call("cancel_placement")
		placement.set_process(true)
		return

	await _click_at(_screen_of(placed.global_position), MOUSE_BUTTON_RIGHT)
	await _wait(0.4)
	_check(_squares_in(world_items) == before, "a right click takes it back out",
		"gone" if _squares_in(world_items) == before
		else "STILL THERE -- the undo the keybind row promises does not answer a mouse")
	var back := -1
	var items: Array = inventory.call("items")
	for index in range(items.size()):
		var bagged := items[index] as DrawnItemData
		if bagged != null and bagged.entity_id == "square":
			back = index
	_check(back >= 0, "and it is back in the bag", "slot %d" % (back + 1) if back >= 0
		else "LOST -- the drawing and the ink that made it are both gone")
	if back >= 0:
		inventory.call("take_item", back)
	placement.set_process(true)
	await process_frame


func _squares_in(world_items: Node2D) -> int:
	var count := 0
	for child in world_items.get_children():
		if _is_placed_square(child):
			count += 1
	return count


func _last_square(world_items: Node2D) -> PhysicsShapeObject:
	var found: PhysicsShapeObject = null
	for child in world_items.get_children():
		if _is_placed_square(child):
			found = child as PhysicsShapeObject
	return found


func _is_placed_square(child: Node) -> bool:
	var prop := child as PhysicsShapeObject
	return prop != null and is_instance_valid(prop) and not prop.is_queued_for_deletion() \
		and not prop.is_preview and prop.item_data != null \
		and prop.item_data.entity_id == "square"


func _screen_of(world_position: Vector2) -> Vector2:
	return level.get_viewport().get_canvas_transform() * world_position


## A press and release at a point on the screen, with no Control under it. The take-back
## reads the position off the event, which is what makes this testable at all.
## THE ONE THE PLAYER ACTUALLY HIT. A beat is a queue of lines and there was no way to
## reach the second one: the level wrote every line of a beat into the same label in the
## same frame, so four of every five lines in Level 1 were never on screen long enough to
## read. Nothing failed -- the labels said the right words, briefly.
##
## Driven with a real key event, for the same reason the button tests use a real mouse:
## calling _advance() directly cannot fail the way a keypress can.
func _dialogue_can_be_advanced() -> void:
	var box = level.get("dialogue_box")
	if box == null:
		_fail("dialogue", "the level built no dialogue box")
		return
	# The draw-panel checks above leave the panel up, and it pauses too -- so the world
	# would still be stopped at the end of this and the assertion would be measuring the
	# wrong overlay.
	level.get_node("DrawPanel").call("close_panel")
	# This runner dismisses beats on sight so the rest of it can drive a live world. Turn
	# that off for the one check whose whole subject is reading a beat.
	box.call("set_auto_dismiss", false)
	await _wait(0.2)
	box.call("skip_all")
	await _wait(0.3)
	box.call("speak", [
		{"text": "First line.", "speaker": "Lolo"},
		{"text": "Second line.", "speaker": "Lolo"},
	])
	await _wait(0.2)
	_check(bool(paused), "a conversation stops the world",
		"paused while a beat is being read")

	# First press catches up the typing, second turns the page.
	await _press_accept()
	await _press_accept()
	var second: String = String(box.call("current_line"))
	_check(second.begins_with("Second"),
		"the advance key reaches the next line", "showing '%s'" % second)

	# The bust stands ON the box's top rail: face at the top of the screen, words at the
	# bottom, and the middle -- where the reader's eye travels between them -- left clear.
	# Asserted as "the head is entirely above the box", which is the part that breaks if
	# the portrait ever slides down into the text.
	var box_rect: Rect2 = box.call("frame_rect")
	var bust: Rect2 = box.call("portrait_rect")
	var head_bottom := bust.position.y + bust.size.y * 0.5
	_check(bust.size.y > 0.0 and head_bottom < box_rect.position.y,
		"the speaker's face sits above the box",
		"head ends at %d, box starts at %d" % [head_bottom, box_rect.position.y])

	# Pressed until the beat is done rather than a fixed number of times. The level is
	# live while this runs and can queue a beat of its own -- the declined recognition
	# above does exactly that when there is no backend -- and the property worth asserting
	# is not "two presses" but "the player can always read their way out".
	var presses := 0
	while box.call("is_open") and presses < 24:
		await _press_accept()
		presses += 1
	_check(not box.call("is_open"), "a beat can always be read to the end",
		"finished after %d presses" % presses)
	await _wait(0.3)
	var holding: Array[String] = []
	for node in get_nodes_in_group(ModalOverlay.GROUP):
		if node.has_method(&"is_open") and bool(node.call(&"is_open")):
			holding.append(String(node.name))
	_check(not bool(paused), "reading the last line gives the world back",
		"unpaused once the beat is over" if not paused
		else "still paused, held by %s" % str(holding))
	box.call("set_auto_dismiss", true)


func _press_accept() -> void:
	var event := InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := InputEventAction.new()
	release.action = &"ui_accept"
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
	await process_frame


func _click_at(at: Vector2, button: int) -> void:
	_inject(_motion(at))
	await process_frame
	for pressed in [true, false]:
		_inject(_button(at, pressed, button))
		await process_frame
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


## Escape while Lolo is asking his question.
##
## The router walks an authored chain and the first willing handler wins. Both decision
## overlays were missing from it, so every entry declined and the PAUSE MENU opened -- at
## layer 50, underneath their layer-68 scrim, where it stole focus and could not be
## clicked. A ghost menu bleeding through the dim, over a question that still needs
## answering.
func _escape_during_a_question_is_not_a_pause_menu() -> void:
	var overlay := level.get_node_or_null("DialogueChoiceOverlay")
	var pause := level.get_node_or_null("PauseMenu")
	if overlay == null or pause == null:
		_fail("escape during a question", "the level has no dialogue overlay or no pause menu")
		return
	overlay.call("present", "Lolo", "Which?", {"artist": "Let us put it back."})
	await _wait(0.4)

	# Through the InputMap, as a key: the router listens in _shortcut_input, which sees
	# InputEventKey and never a synthetic action.
	for event in [_key(true), _key(false)]:
		_inject(event)
		await process_frame
	await _wait(0.3)

	_check(not bool(pause.call("is_open")), "escape during a question opens no pause menu",
		"the question keeps the key" if not bool(pause.call("is_open"))
		else "a pause menu opened under the scrim, unclickable")
	_check(bool(overlay.call("is_open")), "the question is still on screen",
		"a decision point is not dismissable")
	if bool(pause.call("is_open")):
		pause.call("close")
	if bool(overlay.call("is_open")):
		overlay.call("close")
	await process_frame


func _key(pressed: bool) -> InputEventKey:
	for event in InputMap.action_get_events(&"pause"):
		var key := event as InputEventKey
		if key != null:
			var copy := key.duplicate() as InputEventKey
			copy.pressed = pressed
			return copy
	return InputEventKey.new()


## A real click: move there, press, release. Buttons fire on RELEASE by default, so a
## press alone proves nothing, and the motion first is what a mouse actually does.
func _click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	# Move first, then WAIT FOR THE HOVER TO ARRIVE. Input.warp_mouse asks the display
	# server to move the pointer and that is not answered within the frame -- so a press
	# sent on the next frame can still be picked against where the mouse used to be, which
	# left about one run in eight failing after the warp went in. Waiting on the hover is
	# waiting on the thing itself.
	_inject(_motion(at))
	for _frame in range(20):
		await process_frame
		var hovered := root.gui_get_hovered_control()
		if hovered != null and (hovered == control or control.is_ancestor_of(hovered)):
			break
	for event in [_button(at, true), _button(at, false)]:
		_inject(event)
		await process_frame
	await process_frame


## INTO THE VIEWPORT, NOT THROUGH THE INPUT SINGLETON.
##
## THIS IS WHAT MADE THE SUITE FLAKY. Input.parse_input_event hands the event to the
## DisplayServer's focused window, and a Godot started while another one is still closing
## does not have focus for the first second or so -- so the events went nowhere. What that
## produced was not an honest failure but a random one: no focus at all and the canary
## tripped and reported NEEDS_VIEWPORT on a machine that has a perfectly good viewport;
## focus arriving midway and the canary passed while the first click after it did not,
## which is how "clicking Draw opens the panel" came and went between runs on unchanged
## code. Two hours were spent looking at the Draw button.
##
## push_input skips the window manager and hands the event to the viewport directly. It is
## NOT the shortcut that would defeat the point of this file: the viewport still does GUI
## hit testing, still honours `disabled`, still respects whatever Control is lying on top,
## still consults the pause state, and still falls through to _input and _unhandled_input
## in that order. The only thing it does not need is the mouse pointer to be over the
## window, which is not something a player's click depends on either.
##
## Actions stay on Input.parse_input_event -- those exist to move the Input singleton's own
## state, which is what the code under test reads them back out of.
func _inject(event: InputEvent) -> void:
	# THE REAL POINTER HAS TO BE THERE TOO, and this is the whole of the flakiness.
	#
	# Godot picks the Control under the mouse from the DisplayServer's actual pointer, not
	# from the position on a pushed event -- so with the physical mouse parked outside the
	# window, gui_get_hovered_control() is null and a pushed button event lands on nothing.
	# Whether a run passed therefore depended on where somebody had last left their mouse,
	# which is why "clicking Draw opens the panel" came and went on code nobody had touched
	# and why chasing it through the button, the badge and the injection API found nothing.
	# Diagnosed by printing root.get_mouse_position() on a failing run: (-558, -286).
	#
	# warp_mouse takes WINDOW pixels while these events are in the 1600x900 content the game
	# is laid out in, so the position is scaled by whatever the window is doing.
	if event is InputEventMouse:
		var at := (event as InputEventMouse).position
		var window := Vector2(DisplayServer.window_get_size())
		var content := root.get_visible_rect().size
		if content.x > 0.0 and content.y > 0.0:
			Input.warp_mouse(at * (window / content))
	root.push_input(event, true)


func _motion(at: Vector2) -> InputEventMouseMotion:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	return motion


func _button(at: Vector2, pressed: bool, button: int = MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
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
