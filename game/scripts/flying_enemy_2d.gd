class_name FlyingEnemy2D
extends Enemy2D
## A flier -- the wakwak, and the manananggal's upper half. Closes to above her, hangs there
## through its windup, then dives along the line it chose at the end of it.
##
## THE DIVE DOES NOT FOLLOW HER. The direction is fixed when the windup ends, so a step aside
## during the glint is a dodge; a dive that homed would make the telegraph a lie. And it flies by
## move_and_slide against the world like everything else, so a canopy is a ceiling to it too.

const ACCEL := 900.0
const STUN_DRAG := 600.0
## Where it hangs while closing: this far above her middle.
const HOVER_ABOVE := 140.0
## Inside this of its hover point it stops pushing and holds.
const HOLD := 16.0

var _dive := Vector2.ZERO


func _in_striking_range(to_prey: Vector2) -> bool:
	return to_prey.length() <= attack_range


func _begin_attack(to_prey: Vector2) -> void:
	_face(to_prey.x)
	_dive = to_prey.normalized() * lunge
	velocity = _dive


## The line the current dive was locked to, for a probe.
func dive_direction() -> Vector2:
	return _dive.normalized()


func _move(delta: float, to_prey: Vector2) -> void:
	match state:
		State.CHASE:
			var goal := to_prey + Vector2(0.0, -HOVER_ABOVE)
			var want := goal.normalized() * speed if goal.length() > HOLD else Vector2.ZERO
			velocity = velocity.move_toward(want, ACCEL * delta)
		State.ATTACK:
			velocity = _dive
			# Into the ground or a wall, the dive is over.
			if get_slide_collision_count() > 0:
				_state_left = 0.0
		State.RECOVER:
			velocity = velocity.move_toward(Vector2(0.0, -speed * 0.6), ACCEL * delta)
		State.STUN:
			velocity = velocity.move_toward(Vector2.ZERO, STUN_DRAG * delta)
		_:
			velocity = velocity.move_toward(Vector2.ZERO, ACCEL * delta)
