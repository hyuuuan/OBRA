class_name GroundEnemy2D
extends Enemy2D
## A walker -- the aswang as a dog or a pig. Runs at her, hops what it can, and lunges.
##
## It is not a thing that falls off the world chasing her: it hops a step it can clear, stops at
## a wall it cannot, and will not walk off a drop deeper than SAFE_DROP -- unless she is down
## there, in which case following her is the point.

## The tallest step it hops onto without breaking stride; anything taller stops it.
const STEP_UP := 48.0
## The deepest drop it walks off, unless she is below it.
const SAFE_DROP := 180.0
const ACCEL := 1400.0
const STUN_DRAG := 600.0
const MAX_FALL := 900.0
## The little hop its lunge carries, so a strike reads as a leap and clears a kerb.
const LUNGE_HOP := -170.0

var _gravity := 980.0


func _ready() -> void:
	super._ready()
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	floor_snap_length = 8.0


func _in_striking_range(to_prey: Vector2) -> bool:
	return absf(to_prey.x) <= attack_range and absf(to_prey.y) <= body_size.y + 50.0


func _begin_attack(to_prey: Vector2) -> void:
	var dir := signf(to_prey.x)
	if dir == 0.0:
		dir = _facing
	_face(dir)
	velocity = Vector2(dir * lunge, LUNGE_HOP)


func _move(delta: float, to_prey: Vector2) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + _gravity * delta, MAX_FALL)
	match state:
		State.CHASE:
			var dir := signf(to_prey.x) if absf(to_prey.x) > 4.0 else 0.0
			if dir != 0.0 and is_on_floor() and not _safe_to_walk(dir, to_prey):
				dir = 0.0
			velocity.x = move_toward(velocity.x, dir * speed, ACCEL * delta)
			if dir != 0.0 and is_on_floor() and _blocked_ahead(dir) and _step_clears(dir):
				velocity.y = -sqrt(2.0 * _gravity * (STEP_UP + 10.0))
		State.ATTACK:
			pass
		State.STUN:
			velocity.x = move_toward(velocity.x, 0.0, STUN_DRAG * delta)
		_:
			velocity.x = move_toward(velocity.x, 0.0, ACCEL * delta)


## Something in the way at its own height, a little ahead.
func _blocked_ahead(dir: float) -> bool:
	return test_move(global_transform.translated(Vector2(0.0, -2.0)), Vector2(dir * 6.0, 0.0))


## And nothing in the way STEP_UP higher: a step it can hop, not a wall.
func _step_clears(dir: float) -> bool:
	return not test_move(global_transform.translated(Vector2(0.0, -(STEP_UP + 2.0))),
		Vector2(dir * 10.0, 0.0))


## Ground under the leading foot within SAFE_DROP -- or she is below, and down is the way to her.
func _safe_to_walk(dir: float, to_prey: Vector2) -> bool:
	if to_prey.y > body_size.y:
		return true
	var foot := global_position + Vector2(dir * (body_size.x * 0.5 + 4.0), body_size.y * 0.5)
	var ray := PhysicsRayQueryParameters2D.create(foot, foot + Vector2(0.0, SAFE_DROP),
		PhysicsLayers.WORLD)
	var skip: Array[RID] = [get_rid()]
	for body in _excepted:
		if is_instance_valid(body):
			skip.append(body.get_rid())
	ray.exclude = skip
	return not get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
