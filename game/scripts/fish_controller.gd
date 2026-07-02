extends "res://scripts/playable_entity.gd"
## Fish movement: smooth 8-direction swimming with no gravity.

@export var swim_speed: float = 260.0
@export var acceleration: float = 1100.0
@export var turn_speed: float = 8.0


func _physics_process(delta: float) -> void:
	var input_vector := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()

	velocity = velocity.move_toward(input_vector * swim_speed, acceleration * delta)
	if velocity.length() > 5.0:
		rotation = lerp_angle(rotation, velocity.angle(), turn_speed * delta)
	move_and_slide()

