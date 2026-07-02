extends "res://scripts/playable_entity.gd"
## Bird movement: flap to gain height, hold jump to glide.

@export var horizontal_speed: float = 260.0
@export var flap_velocity: float = 380.0
@export var gravity: float = 850.0
@export var glide_fall_speed: float = 130.0

var _flap_timer: float = 0.0


func _physics_process(delta: float) -> void:
	var horizontal := Input.get_axis("move_left", "move_right")
	velocity.x = horizontal * horizontal_speed
	velocity.y += gravity * delta

	if Input.is_action_just_pressed("jump"):
		velocity.y = -flap_velocity
		_flap_timer = 0.16
	elif Input.is_action_pressed("jump") and velocity.y > glide_fall_speed:
		velocity.y = glide_fall_speed

	_flap_timer = maxf(0.0, _flap_timer - delta)
	var state := "fall"
	if _flap_timer > 0.0:
		state = "flap"
	elif Input.is_action_pressed("jump") and velocity.y >= glide_fall_speed:
		state = "glide"
	elif is_on_floor():
		state = "walk" if absf(horizontal) > 0.05 else "idle"
	elif absf(horizontal) > 0.05:
		state = "fly"

	set_rig_state(
		state,
		{
			"direction": horizontal,
			"moving": absf(horizontal) > 0.05,
			"vertical_speed": velocity.y
		}
	)
	move_and_slide()
