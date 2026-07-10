class_name InventoryHUD
extends HBoxContainer

signal slot_pressed(slot: int)

var _manager: InventoryManager
var _buttons: Array[Button] = []


func _ready() -> void:
	for index in range(6):
		var button := Button.new()
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


func _refresh(items: Array) -> void:
	for index in range(_buttons.size()):
		var item := items[index] as DrawnItemData if index < items.size() else null
		_buttons[index].text = "%d  %s" % [index + 1, item.display_name if item != null else "Empty"]
		_buttons[index].tooltip_text = "Place %s" % item.display_name if item != null else "Empty utility slot"


func _on_slot_pressed(slot: int) -> void:
	slot_pressed.emit(slot)

