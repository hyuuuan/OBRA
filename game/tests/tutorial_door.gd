extends RefCounted
## DOING A CARD AT PAYYO'S DOOR, for a probe. Every card there is strict: it goes only on what it
## shows (TutorialSpotlight._does_what_it_shows), so a probe that pressed one key for every card
## would stand at the second card forever. This sends a card the press it is waiting for.


## Press and let go of the input `card` waits for: its first action, else its first mouse input,
## else Enter, which is what a card about something to look at goes on. A click lands at `at`, in
## canvas pixels, when given -- a `click_on_it` card counts it only on what it lights.
static func press_for(card: Dictionary, window: Window, at := Vector2.INF) -> void:
	var actions: Array = card.get("actions", [])
	var mouse: Array = card.get("mouse", [])
	if not actions.is_empty():
		press(StringName(String(actions[0])))
		return
	if mouse.is_empty():
		press(&"ui_accept")
		return
	var button := MOUSE_BUTTON_LEFT
	var shift := false
	match String(mouse[0]):
		"right":
			button = MOUSE_BUTTON_RIGHT
		"wheel":
			button = MOUSE_BUTTON_WHEEL_UP
		"shift_wheel":
			button = MOUSE_BUTTON_WHEEL_UP
			shift = true
	# The middle of the screen is between the two places a card stands, so never on its SKIP.
	click(button, window, window.get_visible_rect().size * 0.5 if at == Vector2.INF else at, shift)


## A click at `at`, in canvas pixels, sent in window pixels as input arrives.
static func click(button: MouseButton, window: Window, at: Vector2, shift := false) -> void:
	var in_window := window.get_final_transform() * at
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = down
		event.shift_pressed = shift
		event.position = in_window
		event.global_position = in_window
		Input.parse_input_event(event)


## Do the card up, as a player would: its own press, a click on what it lights. Returns the id
## of the card it did, or "" if none was up and settled.
static func do_the_card(spot: TutorialSpotlight, window: Window) -> String:
	if not spot.is_showing() or float(spot.get("_age")) <= TutorialSpotlight.STRICT_MIN_SEC + 0.05:
		return ""
	var card: Dictionary = spot.get("_lesson")
	press_for(card, window, spot.hole_rect().get_center() if bool(card.get("click_on_it", false))
		else Vector2.INF)
	return spot.lesson_id()


## Put away a bag a door card opened, once its card is done: a player reads it and closes it, and
## the door's next card waits for that.
static func close_the_bag(level: Node, spot: TutorialSpotlight) -> bool:
	var bag := level.get("inventory_screen") as InventoryScreen
	if bag == null or not bag.is_open() or spot.is_busy():
		return false
	bag.close()
	return true


## Press and let go of an action.
static func press(action: StringName) -> void:
	for down in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = down
		Input.parse_input_event(event)
