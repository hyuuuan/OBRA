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
	_update_skin_flip()

	var speed_ratio := clampf(velocity.length() / swim_speed, 0.0, 1.0)
	set_rig_state(
		"swim" if speed_ratio > 0.05 else "idle",
		{
			"speed_ratio": speed_ratio,
			"moving": speed_ratio > 0.05,
			"direction": input_vector.x
		}
	)
	move_and_slide()


## Mirror the drawing vertically when facing left so the fish is never
## rendered upside down while the body rotates toward its heading.
func _update_skin_flip() -> void:
	var skin := _get_skin() as Node2D
	if skin == null:
		return
	skin.scale.y = -1.0 if absf(wrapf(rotation, -PI, PI)) > PI * 0.5 else 1.0
