class_name Satchel
extends RefCounted
## Dilim's satchel: Lola's things, in stacks with a visible count, four of them on quick slots.
##
## Not the bag. The bag holds drawings, which are the apo's and went through the recogniser; these
## are Lola's, are never drawn, and are counted rather than kept one by one (config/satchel.json).
##
## THE QUICK SLOTS FILL THEMSELVES, in the order things are first picked up -- a fight has no time
## for a menu. A slot keeps its thing while she has any; once it is spent the slot goes to the next
## new kind she picks up, and until then it stays put, empty, so nothing moves under her fingers.
##
## Plain data in and out (to_data / from_data): a checkpoint's run state drops any dictionary that
## holds an object, so the satchel is saved as counts and slot ids, never as itself.

signal changed

const CONFIG := "res://config/satchel.json"
const SLOTS := 4

var _rows: Dictionary = {}
var _counts: Dictionary = {}
var _slots: Array[String] = []


func _init(config_path: String = CONFIG) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	var items: Variant = (parsed as Dictionary).get("items", {}) if parsed is Dictionary else {}
	if items is Dictionary:
		_rows = (items as Dictionary).duplicate(true)
	_slots.resize(SLOTS)
	_slots.fill("")


## Every kind the satchel knows, in the file's order.
func ids() -> Array[String]:
	var out: Array[String] = []
	for id: Variant in _rows.keys():
		out.append(String(id))
	return out


func row(id: String) -> Dictionary:
	return _rows.get(id, {}) as Dictionary


func count(id: String) -> int:
	return int(_counts.get(id, 0))


func cap(id: String) -> int:
	return int(row(id).get("cap", 0))


## Puts up to `amount` of a kind in, never past its cap. Returns how many went in -- none for a kind
## the satchel does not know, or one already full.
func add(id: String, amount: int = 1) -> int:
	if not _rows.has(id) or amount <= 0:
		return 0
	var room := maxi(0, cap(id) - count(id))
	var taken := mini(room, amount)
	if taken <= 0:
		return 0
	_counts[id] = count(id) + taken
	_give_a_slot(id)
	changed.emit()
	return taken


## Uses one. False when she has none.
func take(id: String) -> bool:
	if count(id) <= 0:
		return false
	_counts[id] = count(id) - 1
	changed.emit()
	return true


## The kind on a quick slot, "" for an empty one.
func slot_item(index: int) -> String:
	return _slots[index] if index >= 0 and index < _slots.size() else ""


func slots() -> Array[String]:
	return _slots.duplicate()


func to_data() -> Dictionary:
	return {"counts": _counts.duplicate(), "slots": Array(_slots)}


func from_data(data: Dictionary) -> void:
	_counts.clear()
	for id: Variant in (data.get("counts", {}) as Dictionary).keys():
		if _rows.has(String(id)):
			_counts[String(id)] = clampi(int(data["counts"][id]), 0, cap(String(id)))
	_slots.fill("")
	var saved: Array = data.get("slots", [])
	for index in range(mini(saved.size(), SLOTS)):
		var id := String(saved[index])
		_slots[index] = id if _rows.has(id) else ""
	changed.emit()


## A kind already on a slot keeps it. A new one takes the first empty slot, or failing that the
## first whose kind is spent.
func _give_a_slot(id: String) -> void:
	if _slots.has(id):
		return
	for index in range(SLOTS):
		if _slots[index].is_empty():
			_slots[index] = id
			return
	for index in range(SLOTS):
		if count(_slots[index]) <= 0:
			_slots[index] = id
			return
