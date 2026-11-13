extends RefCounted
## DOING A CARD AT PAYYO'S DOOR, for a probe. Every card there is strict: it goes only on what it
## shows (TutorialSpotlight._does_what_it_shows), so a probe that pressed one key for every card
## would stand at the second card forever. This sends a card the press it is waiting for.


## Press and let go of the input `card` waits for: its first action, else its first mouse input,
## else Enter, which is what a card about something to look at goes on.
static func press_for(card: Dictionary, window: Window) -> void:
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
	# In window pixels, as input arrives. The middle of the screen is between the two places a
	# card stands, so it is never on a card's SKIP.
	var at := window.get_final_transform() * (window.get_visible_rect().size * 0.5)
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = button
		click.pressed = down
		click.shift_pressed = shift
		click.position = at
		click.global_position = at
		Input.parse_input_event(click)


## Press and let go of an action.
static func press(action: StringName) -> void:
	for down in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = down
		Input.parse_input_event(event)
