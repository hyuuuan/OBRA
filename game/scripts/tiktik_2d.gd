class_name Tiktik2D
extends FlyingEnemy2D
## The tik-tik: the finale's last wave, a flier she cannot see (Kent's design: "invisible unless
## ashed (abo); approaches at 110, circles at 300, strikes at 56; its call is louder when it is
## far; under 220 px the lantern leans and gutters; bawang wards it").
##
## IT IS NOT DRAWN AND CANNOT BE HIT until ash shows it: it is in AboDust2D.REVEALS, and a handful
## thrown with it close shows it for the dust's seconds and blinds it for a moment -- the window a
## weapon has. What she has before that is what the folklore gives her: its call, which is
## LOUDER THE FURTHER OFF IT IS (`called`, strength by `call_strength`, the level's to put on the
## screen's edge), and her lantern, which leans and gutters once it is close (`pulls_at`).
##
## It circles her at CIRCLE_RADIUS for CIRCLE_SECONDS, then comes straight in at APPROACH_SPEED and
## strikes from STRIKE_RANGE. While she stands in a garlic ward it will not come in: it keeps
## circling, outside the ward's reach.

signal called(at: Vector2, strength: float)

const CIRCLE_RADIUS := 300.0
const CIRCLE_SECONDS := 4.0
## Round her, radians a second.
const CIRCLE_TURN := 0.9
const APPROACH_SPEED := 110.0
const STRIKE_RANGE := 56.0
## Its call, every this many seconds: silent this close, loudest this much further off.
const CALL_EVERY := 2.5
const CALL_NEAR := 180.0
const CALL_SPAN := 920.0
## Inside this of her light, the lantern leans and gutters.
const PULLS_WITHIN := 220.0
## What ash does to it besides showing it.
const BLINDED_SECONDS := 1.5
## Outside a ward's reach by this much while it waits.
const WARD_CLEARANCE := 40.0

## PLACEHOLDER BODY until there is art (ART_PLACEHOLDERS): a small dark bird, long-beaked, and the
## grey of the ash still on it.
const FEATHER := Color(0.34, 0.30, 0.40)
const BEAK := Color(0.62, 0.55, 0.42)
const ASH := Color(0.62, 0.6, 0.63)

var _revealed := 0.0
var _circling := CIRCLE_SECONDS
var _angle := 0.0
var _call_clock := 0.0
var _clock := 0.0


func _init() -> void:
	kind = "tiktik"
	hunts_by_smell = false


func _ready() -> void:
	super._ready()
	add_to_group(AboDust2D.REVEALS)
	modulate.a = 0.0


## How loud its call is from `distance` away, 0 to 1: quiet when it is near.
static func call_strength(distance: float) -> float:
	return clampf((distance - CALL_NEAR) / CALL_SPAN, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	_clock += delta
	_revealed = maxf(0.0, _revealed - delta)
	if state != State.DEAD:
		# Fading out once it is dead is the base's; until then, seen only while ashed.
		modulate.a = 1.0 if _revealed > 0.0 else 0.0
		_call_clock += delta
		if _call_clock >= CALL_EVERY and _prey != null:
			_call_clock = 0.0
			called.emit(global_position, call_strength(global_position.distance_to(_prey.global_position)))
	var was := state
	super(delta)
	if was == State.RECOVER and state == State.CHASE:
		_circling = CIRCLE_SECONDS
	queue_redraw()


## Ash on it: seen, and blinded for a moment.
func reveal(seconds: float) -> void:
	if state == State.DEAD:
		return
	_revealed = maxf(_revealed, seconds)
	modulate.a = 1.0
	stun(BLINDED_SECONDS)


func is_revealed() -> bool:
	return _revealed > 0.0


## Unseen, a blow goes through where it might be.
func apply_tool_hit(tool: String, impulse: float, actor: Node2D) -> bool:
	if _revealed <= 0.0:
		return false
	return super(tool, impulse, actor)


## Whether it is close enough to her light to pull at it.
func pulls_at(point: Vector2) -> bool:
	return state != State.DEAD and global_position.distance_to(point) < PULLS_WITHIN


## Whether she stands in a garlic ward, and how far it has to stay out if she does.
func _ward_reach() -> float:
	if _prey == null:
		return 0.0
	var reach := 0.0
	for node in get_tree().get_nodes_in_group(WARDS):
		var ward := node as Node2D
		if ward != null and ward.has_method("reach") \
				and ward.global_position.distance_to(_prey.global_position) < float(ward.call("reach")):
			reach = maxf(reach, float(ward.call("reach")))
	return reach


func _in_striking_range(to_prey: Vector2) -> bool:
	return _circling <= 0.0 and _ward_reach() <= 0.0 and to_prey.length() <= STRIKE_RANGE


func _move(delta: float, to_prey: Vector2) -> void:
	if state != State.CHASE:
		super(delta, to_prey)
		return
	var warded := _ward_reach()
	_circling -= delta
	if _circling > 0.0 or warded > 0.0:
		# Round her, above her, at its distance or outside the ward's.
		_angle = fmod(_angle + CIRCLE_TURN * delta, TAU)
		var radius := maxf(CIRCLE_RADIUS, warded + WARD_CLEARANCE)
		var spot := _prey.global_position + Vector2(cos(_angle), -absf(sin(_angle)) * 0.6 - 0.2) * radius
		var to_spot := spot - global_position
		var want := to_spot.normalized() * speed if to_spot.length() > HOLD else Vector2.ZERO
		velocity = velocity.move_toward(want, ACCEL * delta)
		return
	velocity = velocity.move_toward(to_prey.normalized() * APPROACH_SPEED, ACCEL * delta)


func reset_for_restore() -> void:
	_revealed = 0.0
	_circling = CIRCLE_SECONDS
	_call_clock = 0.0
	modulate.a = 0.0
	super()


func _draw() -> void:
	if art != null and art.has_art():
		return
	var flap := sin(_clock * 12.0) * 6.0
	for side: float in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(side * 4.0, -2.0),
			Vector2(side * 22.0, -10.0 + flap), Vector2(side * 18.0, 4.0 + flap * 0.5)]), FEATHER)
	draw_circle(Vector2.ZERO, 8.0, FEATHER)
	draw_line(Vector2(_facing * 6.0, -1.0), Vector2(_facing * 20.0, 2.0), BEAK, 2.0)
	if _revealed > 0.0:
		for speck in range(5):
			draw_circle(Vector2(-6.0 + speck * 3.0, -6.0 + float(speck % 2) * 4.0), 1.6, ASH)
