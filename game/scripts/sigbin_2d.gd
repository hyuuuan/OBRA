class_name Sigbin2D
extends GroundEnemy2D
## The sigbin: goat-like, walks backwards, hides in shadow, strikes from behind (Kent's design --
## "The only creature that directly punishes the level's darkness").
##
## It goes for the place BEHIND her, BEHIND_BY px on the side she is not facing, and starts a strike
## only from there: turn to face it and it has to come round again. It shows only as much as the
## light on it (LightField), so in the dark it is a glint and nothing else -- the 0.6 s glint before
## it lunges, which is the tell. Answered three ways, all the level's to judge: shown a light it
## flees; with her back to a surface it cannot get behind her and gives up; struck down it is
## driven off. `flee()` is how it leaves, either way it goes.

const BEHIND_BY := 110.0
## How lit it has to be to be seen at all, and to be seen whole.
const SEEN_FROM := 0.12
const SEEN_WHOLE := 0.6
const FLEE_SECONDS := 1.2
const FLEE_SHARE := 1.6

var _fleeing := 0.0
var _gone := false


func _init() -> void:
	kind = "sigbin"


func _physics_process(delta: float) -> void:
	if _gone:
		return
	if _fleeing > 0.0:
		_fleeing -= delta
		var away := signf(global_position.x - _her_x()) if _prey != null else _facing
		velocity = Vector2((away if away != 0.0 else 1.0) * speed * FLEE_SHARE, velocity.y + 980.0 * delta)
		move_and_slide()
		modulate.a = clampf(_fleeing / FLEE_SECONDS, 0.0, 1.0)
		if _fleeing <= 0.0:
			_gone = true
			visible = false
		return
	super(delta)
	var lit := LightField.light_from(LightField.holes_in(get_tree()), global_position)
	self_modulate.a = smoothstep(SEEN_FROM, SEEN_WHOLE, lit)
	if art != null:
		art.modulate.a = self_modulate.a


## It goes: off away from her, fading, and is not there after. Nothing it does after counts.
func flee() -> void:
	if _gone or _fleeing > 0.0 or state == State.DEAD:
		return
	_fleeing = FLEE_SECONDS
	telegraph.stop()
	_set_colliding(false)


func is_gone() -> bool:
	return _gone or _fleeing > 0.0


func reset_for_restore() -> void:
	_fleeing = 0.0
	_gone = false
	super()


## For the chase it aims at the place behind her; everything else is about her herself.
func _move(delta: float, to_prey: Vector2) -> void:
	if state == State.CHASE:
		super(delta, to_prey + Vector2(-_her_facing() * BEHIND_BY, 0.0))
	else:
		super(delta, to_prey)


## Only from behind: on the side she is not facing, and close.
func _in_striking_range(to_prey: Vector2) -> bool:
	return super(to_prey) and to_prey.x * _her_facing() > 0.0


func _her_facing() -> float:
	var body: Node = _prey.player if _prey != null else null
	var facing: Variant = body.get(&"_facing") if body != null and is_instance_valid(body) else null
	return signf(float(facing)) if facing != null and float(facing) != 0.0 else 1.0


func _her_x() -> float:
	return _prey.global_position.x if _prey != null else global_position.x
