class_name InventoryManager
extends Node
## Six exact, non-stacking item slots. World objects are removed only after an
## add operation succeeds, so a full inventory can never delete an item.

signal inventory_changed(items: Array)
signal item_added(slot: int, item: DrawnItemData)
signal item_removed(slot: int, item: DrawnItemData)

@export_range(1, 12) var capacity: int = 6

var _items: Array = []


func _ready() -> void:
	_reset_slots()


func begin_level() -> void:
	_reset_slots()
	_emit_changed()


func is_full() -> bool:
	return first_empty_slot() == -1


func first_empty_slot() -> int:
	for index in range(_items.size()):
		if _items[index] == null:
			return index
	return -1


func add_item(item: DrawnItemData, preferred_slot: int = -1) -> int:
	if item == null:
		return -1
	var slot := preferred_slot
	if slot < 0 or slot >= _items.size() or _items[slot] != null:
		slot = first_empty_slot()
	if slot == -1:
		return -1
	_items[slot] = item
	item_added.emit(slot, item)
	_emit_changed()
	return slot


func take_item(slot: int) -> DrawnItemData:
	if slot < 0 or slot >= _items.size():
		return null
	var item := _items[slot] as DrawnItemData
	if item == null:
		return null
	_items[slot] = null
	item_removed.emit(slot, item)
	_emit_changed()
	return item


func peek_item(slot: int) -> DrawnItemData:
	if slot < 0 or slot >= _items.size():
		return null
	return _items[slot] as DrawnItemData


func items() -> Array:
	return _items.duplicate()


func _reset_slots() -> void:
	_items.resize(capacity)
	_items.fill(null)


func _emit_changed() -> void:
	inventory_changed.emit(items())

