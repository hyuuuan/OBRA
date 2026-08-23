class_name InventoryHUD
extends HBoxContainer

signal slot_pressed(slot: int)

var _manager: InventoryManager
var _buttons: Array[Button] = []
## Which slot the player is currently acting on, or -1. Without this the HUD gave no
## sign of what was selected -- pressing a slot started a placement and the six
## buttons carried on looking identical, so the only way to know what you were
## holding was the transient line in the status label.
var _selected: int = -1


func _ready() -> void:
	for index in range(6):
		var button := Button.new()
		button.theme_type_variation = &"InventorySlot"
		button.custom_minimum_size = Vector2(118.0, 52.0)
		button.focus_mode = Control.FOCUS_NONE
		button.text = "%d  Empty" % (index + 1)
		button.pressed.connect(_on_slot_pressed.bind(index))
		add_child(button)
		_buttons.append(button)


func set_manager(manager: InventoryManager) -> void:
	_manager = manager
	if not manager.inventory_changed.is_connected(_refresh):
		manager.inventory_changed.connect(_refresh)
	_refresh(manager.items())


## Mark a slot as the one in hand. -1 clears it.
func set_selected(slot: int) -> void:
	_selected = slot
	if _manager != null:
		_refresh(_manager.items())


func selected_slot() -> int:
	return _selected


## Stand out of the way of the mouse while something is being placed.
##
## The bar is 756x52 across the bottom-centre of the screen, and a placement is confirmed
## from PlacementController._unhandled_input -- which never runs for a click the GUI has
## already consumed. Setting a drawn step down near the ground means clicking low, so the
## click landed on a slot button, which does nothing during a placement, and vanished with
## nothing on screen to say why. That is Beat 0: the player draws the step and then cannot
## put it anywhere.
##
## Every button is set individually. A Control is hit-tested on its own filter, not its
## parent's, so making the container ignore the mouse would leave six live buttons sitting
## in the hole.
func set_click_through(click_through: bool) -> void:
	var filter := Control.MOUSE_FILTER_IGNORE if click_through else Control.MOUSE_FILTER_STOP
	mouse_filter = filter
	for button in _buttons:
		button.mouse_filter = filter


func _refresh(items: Array) -> void:
	for index in range(_buttons.size()):
		var item := items[index] as DrawnItemData if index < items.size() else null
		var occupied := item != null
		var chosen := index == _selected and occupied
		_buttons[index].text = "%d  %s" % [index + 1, item.display_name if occupied else "Empty"]
		_buttons[index].tooltip_text = "Place %s" % item.display_name if occupied else "Empty utility slot"
		# Selection reads as brightness and a lift rather than as a colour alone, so it
		# survives the drawing behind it and does not rely on one hue being noticed.
		_buttons[index].modulate = Color(1.25, 1.25, 1.05) if chosen else (
			Color.WHITE if occupied else Color(0.72, 0.75, 0.7))
		_buttons[index].position.y = -6.0 if chosen else 0.0


func _on_slot_pressed(slot: int) -> void:
	slot_pressed.emit(slot)

