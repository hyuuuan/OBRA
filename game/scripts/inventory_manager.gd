class_name InventoryManager
extends Node
## Six slots, and a slot holds a STACK. World objects are removed only after an add operation
## succeeds, so a full inventory can never delete an item.
##
## ⚠ IT WAS SIX EXACT, NON-STACKING SLOTS. Two ladders drawn were two slots with the same
## picture in them, and a bag of three ladders and two squares was five of its six pockets.
## Kent: "storing the same object in the inventory places them separately like the flower so
## instead of that how about we use the counter like x1 x2". So every drawing of one class
## goes into the one slot that already holds that class, the slot shows how many, and its key
## takes one out at a time. Each drawing is still its own item -- its own picture, its own
## size, whether it has been paid for -- the stack only says where they are kept.
##
## What a slot SHOWS and what its key takes out is the same drawing: see _top. Everything
## that asks the bag by kind -- which slot holds a ladder, is there anything to throw --
## reads `items()`, the one drawing each slot shows. Anything that has to see every drawing
## reads `all_items()`.

signal inventory_changed(items: Array)
signal item_added(slot: int, item: DrawnItemData)
signal item_removed(slot: int, item: DrawnItemData)
## Something moved from one slot to another, swapping with whatever was there. Nothing left
## the bag and nothing came into it, which is why neither of the two above fires for it.
signal item_moved(from_slot: int, to_slot: int)

@export_range(1, 12) var capacity: int = 6

## One Array per slot: empty, or every drawing of one class, oldest first.
var _stacks: Array = []


func _ready() -> void:
	_reset_slots()


func begin_level() -> void:
	_reset_slots()
	_emit_changed()


## No empty slot left. A drawing of a class the bag already holds still fits -- see has_room_for.
func is_full() -> bool:
	return first_empty_slot() == -1


func first_empty_slot() -> int:
	for index in range(_stacks.size()):
		if (_stacks[index] as Array).is_empty():
			return index
	return -1


## Whether `item` would go in: onto the stack of its own class, or into an empty slot.
func has_room_for(item: DrawnItemData) -> bool:
	return first_empty_slot() != -1 or (item != null and _slot_of_kind(item.entity_id) != -1)


## Onto the stack of its own class wherever that is, or into `preferred_slot` if that is empty
## (where it came out of, when a placement is called off), or into the first empty slot.
func add_item(item: DrawnItemData, preferred_slot: int = -1) -> int:
	if item == null:
		return -1
	var slot := _slot_of_kind(item.entity_id)
	if slot == -1 and preferred_slot >= 0 and preferred_slot < _stacks.size() \
			and (_stacks[preferred_slot] as Array).is_empty():
		slot = preferred_slot
	if slot == -1:
		slot = first_empty_slot()
	if slot == -1:
		return -1
	(_stacks[slot] as Array).append(item)
	item_added.emit(slot, item)
	_emit_changed()
	return slot


## The drawing the slot shows, out of the bag. The rest of its stack stays.
func take_item(slot: int) -> DrawnItemData:
	if slot < 0 or slot >= _stacks.size():
		return null
	var stack: Array = _stacks[slot]
	if stack.is_empty():
		return null
	var item := stack.pop_at(_top(stack)) as DrawnItemData
	item_removed.emit(slot, item)
	_emit_changed()
	return item


## This drawing, wherever it is in its stack -- for a caller that knows WHICH one it means
## (the one in the hand, the one that could not be paid for). The slot it left, or -1.
func remove_item(item: DrawnItemData) -> int:
	for slot in range(_stacks.size()):
		var stack: Array = _stacks[slot]
		var at := stack.find(item)
		if at == -1:
			continue
		stack.remove_at(at)
		item_removed.emit(slot, item)
		_emit_changed()
		return slot
	return -1


## Whether this very drawing is in the bag. A tool in the hand never left it.
func holds(item: DrawnItemData) -> bool:
	if item == null:
		return false
	for stack: Array in _stacks:
		if stack.has(item):
			return true
	return false


## How many drawings the slot holds.
func count(slot: int) -> int:
	if slot < 0 or slot >= _stacks.size():
		return 0
	return (_stacks[slot] as Array).size()


## Move what is in `from_slot` to `to_slot`, and whatever was there to `from_slot`: the bag
## screen's drag. The slot is the number key that reaches it, so this is how a player puts the
## ladder on 1. A whole stack moves together.
func move_item(from_slot: int, to_slot: int) -> bool:
	if from_slot == to_slot or from_slot < 0 or to_slot < 0 \
			or from_slot >= _stacks.size() or to_slot >= _stacks.size():
		return false
	if (_stacks[from_slot] as Array).is_empty():
		return false
	var moving: Variant = _stacks[from_slot]
	_stacks[from_slot] = _stacks[to_slot]
	_stacks[to_slot] = moving
	item_moved.emit(from_slot, to_slot)
	_emit_changed()
	return true


## The drawing the slot shows, which is the one its key would take out.
func peek_item(slot: int) -> DrawnItemData:
	if slot < 0 or slot >= _stacks.size():
		return null
	var stack: Array = _stacks[slot]
	return null if stack.is_empty() else stack[_top(stack)] as DrawnItemData


## One entry per slot: the drawing it shows, or null.
func items() -> Array:
	var out: Array = []
	for slot in range(_stacks.size()):
		out.append(peek_item(slot))
	return out


## Every drawing in the bag, every stack.
func all_items() -> Array:
	var out: Array = []
	for stack: Array in _stacks:
		out.append_array(stack)
	return out


## ⚠ THE ONE ALREADY PAID FOR COMES OUT FIRST. A placeable costs its unit the first time it
## is set down, and one taken back into the bag goes down again free -- so with a paid ladder
## and a new one in the same slot, handing out the new one would charge for a ladder the
## player already owns outright. Otherwise the newest.
static func _top(stack: Array) -> int:
	for at in range(stack.size() - 1, -1, -1):
		var item := stack[at] as DrawnItemData
		if item != null and item.placement_paid:
			return at
	return stack.size() - 1


## The slot holding drawings of this class, or -1. A drawing with no class stacks with nothing.
func _slot_of_kind(entity_id: String) -> int:
	if entity_id.is_empty():
		return -1
	for slot in range(_stacks.size()):
		var stack: Array = _stacks[slot]
		if not stack.is_empty() and (stack[0] as DrawnItemData).entity_id == entity_id:
			return slot
	return -1


func _reset_slots() -> void:
	_stacks.clear()
	for _slot in range(capacity):
		_stacks.append([])


func _emit_changed() -> void:
	inventory_changed.emit(items())
