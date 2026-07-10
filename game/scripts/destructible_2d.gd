class_name Destructible2D
extends Node2D
## Reusable target contract for later level scenes; this pass adds no targets.

signal damaged(remaining_health: float, impulse: float)
signal destroyed

@export var health: float = 100.0
@export var axe_damage_scale: float = 0.25
var is_destroyed: bool = false


func apply_tool_hit(tool: String, impulse: float, _actor: Node2D) -> bool:
	if is_destroyed or tool != "axe":
		return false
	health = maxf(0.0, health - maxf(0.0, impulse) * axe_damage_scale)
	damaged.emit(health, impulse)
	if health <= 0.0:
		is_destroyed = true
		destroyed.emit()
	return true

