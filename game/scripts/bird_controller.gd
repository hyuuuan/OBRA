extends "res://scripts/playable_entity.gd"
## Bird movement: tap jump to flap upward, hold jump to glide, walk on the
## ground. States are handed to the rig, which beats the wings in the air and
## steps the feet on the ground — adapting to the drawn bird's build.

@export var horizontal_speed: float = 240.0
@export var flap_velocity: float = 360.0
@export var gravity: float = 820.0
@export var glide_fall_speed: float = 120.0

var _flap_timer: float = 0.0


func _physics_process(delta: float) -> void:
	var horizontal := Input.get_axis("move_left", "move_right")
	velocity.x = horizontal * horizontal_speed
	velocity.y += gravity * delta

	var gliding := false
	if Input.is_action_just_pressed("jump"):
		velocity.y = -flap_velocity
		_flap_timer = 0.18
	elif Input.is_action_pressed("jump") and velocity.y > glide_fall_speed:
		# Holding jump on the way down spreads the wings and slows the fall.
		velocity.y = glide_fall_speed
		gliding = true

	_flap_timer = maxf(0.0, _flap_timer - delta)

	var moving := absf(horizontal) > 0.05
	var state := "idle"
	if is_on_floor():
		state = "walk" if moving else "idle"
	elif gliding:
		state = "glide"
	elif _flap_timer > 0.0:
		state = "flap" # accented downstroke right after a tap
	else:
		state = "fly" # powered flight — wings beat continuously

	set_rig_state(
		state,
		{
			"direction": horizontal,
			"moving": moving,
			"vertical_speed": velocity.y
		}
	)
	move_and_slide()
