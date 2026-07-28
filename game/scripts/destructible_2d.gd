class_name Destructible2D
extends Node2D
## Reusable target contract for later level scenes; this pass adds no targets.

signal damaged(remaining_health: float, impulse: float)
signal destroyed

@export var health: float = 100.0
@export var axe_damage_scale: float = 0.25
## Which drawn tools bite, and how hard relative to the axe. The design table gives
## four classes a "cut or break it" function, not one, so accepting only "axe" here
## made sword, scissors, cannon and anvil unable to affect anything by construction.
@export var tool_effectiveness: Dictionary = {
	"axe": 1.0,
	"sword": 0.85,
	"scissors": 0.45,
	"cannon": 1.6,
	"anvil": 1.4,
}
var is_destroyed: bool = false


func accepts_tool(tool: String) -> bool:
	return not is_destroyed and tool_effectiveness.has(tool)


func apply_tool_hit(tool: String, impulse: float, _actor: Node2D) -> bool:
	if not accepts_tool(tool):
		return false
	var effectiveness := float(tool_effectiveness.get(tool, 0.0))
	health = maxf(0.0, health - maxf(0.0, impulse) * axe_damage_scale * effectiveness)
	damaged.emit(health, impulse)
	if health <= 0.0:
		is_destroyed = true
		destroyed.emit()
	return true

