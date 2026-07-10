class_name WaterArea2D
extends Area2D
## Future levels can add this area without changing fish or sailboat code.

@export var buoyancy: float = 1.0
@export var linear_drag: float = 2.8
@export var angular_drag: float = 1.8


func _ready() -> void:
	add_to_group("water_medium")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	var count := int(body.get_meta("water_overlap_count", 0))
	body.set_meta("water_overlap_count", count + 1)
	body.set_meta("water_area", self)


func _on_body_exited(body: Node2D) -> void:
	var count := maxi(0, int(body.get_meta("water_overlap_count", 0)) - 1)
	body.set_meta("water_overlap_count", count)
	if count == 0:
		body.remove_meta("water_area")

