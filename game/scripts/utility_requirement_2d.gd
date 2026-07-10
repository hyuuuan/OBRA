class_name UtilityRequirement2D
extends Node
## Minimal objective hook for later level scripts.

signal satisfied(required_utility: String, item_instance_id: int)

@export var required_utility: String = ""
var is_satisfied: bool = false


func _ready() -> void:
	add_to_group("utility_requirements")


func report_utility_used(utility_id: String, item: DrawnItemData) -> bool:
	if is_satisfied or utility_id != required_utility or item == null:
		return false
	is_satisfied = true
	satisfied.emit(required_utility, item.instance_id)
	return true
