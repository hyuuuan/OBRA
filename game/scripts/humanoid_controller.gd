extends "res://scripts/playable_entity.gd"
## Humanoid movement: standard platform walk and jump.

@export var walk_speed: float = 240.0
@export var acceleration: float = 1600.0
@export var jump_velocity: float = 430.0
@export var gravity: float = 1200.0


func _physics_process(delta: float) -> void:
	var target_speed := Input.get_axis("move_left", "move_right") * walk_speed
	velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)

	if not is_on_floor():
		velocity.y += gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = -jump_velocity

	move_and_slide()

