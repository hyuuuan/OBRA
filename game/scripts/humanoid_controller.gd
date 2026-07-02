extends "res://scripts/playable_entity.gd"
## Humanoid movement: standard platform walk and jump.

@export var walk_speed: float = 240.0
@export var acceleration: float = 1600.0
@export var jump_velocity: float = 430.0
@export var gravity: float = 1200.0


func _physics_process(delta: float) -> void:
	var was_on_floor := is_on_floor()
	var target_speed := Input.get_axis("move_left", "move_right") * walk_speed
	velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)

	if not is_on_floor():
		velocity.y += gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = -jump_velocity

	move_and_slide()
	_update_rig_state(was_on_floor, target_speed)


func _update_rig_state(was_on_floor: bool, target_speed: float) -> void:
	var grounded := is_on_floor()
	var direction := 0.0
	if absf(target_speed) > 0.05:
		direction = 1.0 if target_speed > 0.0 else -1.0
	var moving := absf(target_speed) > 0.05
	var params := {
		"direction": direction,
		"moving": moving,
		"speed_ratio": clampf(absf(target_speed) / walk_speed, 0.0, 1.0)
	}

	if grounded and not was_on_floor:
		set_rig_state("landed", params)
	elif grounded and moving:
		set_rig_state("walk", params)
	elif grounded:
		set_rig_state("idle", params)
	elif velocity.y < 0.0:
		set_rig_state("jump", params)
	else:
		set_rig_state("fall", params)
