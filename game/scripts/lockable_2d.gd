class_name Lockable2D
extends Node2D
## Reusable lock contract for later level scenes; this pass adds no locks.

signal unlocked(item_instance_id: int)

@export var accepted_key_tag: String = "drawn_key"
@export var consume_key: bool = false
var is_locked: bool = true


func try_unlock(key_tag: String, item: DrawnItemData) -> Dictionary:
	if not is_locked or key_tag != accepted_key_tag or item == null:
		return {"unlocked": false, "consumed": false}
	is_locked = false
	unlocked.emit(item.instance_id)
	return {"unlocked": true, "consumed": consume_key}

