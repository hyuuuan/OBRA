extends "res://scripts/playable_entity.gd"
## Spider movement: walk on the floor and climb while touching walls.

@export var walk_speed: float = 180.0
@export var climb_speed: float = 150.0
@export var jump_velocity: float = 320.0
@export var gravity: float = 1000.0


func _physics_process(delta: float) -> void:
	var horizontal := Input.get_axis("move_left", "move_right")
	var vertical := Input.get_axis("move_up", "move_down")
	var state := "idle"

	velocity.x = horizontal * walk_speed
	if is_on_wall() and absf(vertical) > 0.0:
		velocity.y = vertical * climb_speed
		state = "climb"
	elif not is_on_floor():
		velocity.y += gravity * delta
		state = "jump" if velocity.y < 0.0 else "fall"
	elif Input.is_action_just_pressed("jump"):
		velocity.y = -jump_velocity
		state = "jump"
	else:
		velocity.y = 0.0
		if absf(horizontal) > 0.05:
			state = "walk"

	set_rig_state(
		state,
		{
			"direction": horizontal,
			"moving": absf(horizontal) > 0.05 or absf(vertical) > 0.05,
			"speed_ratio": clampf(absf(horizontal), 0.0, 1.0)
		}
	)
	move_and_slide()
