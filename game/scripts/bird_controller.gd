extends "res://scripts/playable_entity.gd"
## Bird movement: flap to gain height, hold jump to glide.

@export var horizontal_speed: float = 260.0
@export var flap_velocity: float = 380.0
@export var gravity: float = 850.0
@export var glide_fall_speed: float = 130.0


func _physics_process(delta: float) -> void:
	velocity.x = Input.get_axis("move_left", "move_right") * horizontal_speed
	velocity.y += gravity * delta

	if Input.is_action_just_pressed("jump"):
		velocity.y = -flap_velocity
	elif Input.is_action_pressed("jump") and velocity.y > glide_fall_speed:
		velocity.y = glide_fall_speed

	move_and_slide()

