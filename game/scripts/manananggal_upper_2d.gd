class_name ManananggalUpper2D
extends FlyingEnemy2D
## The manananggal's upper half: torso and wings, hunting her from above (Kent's design: "the
## upper half flies, so ground weapons mostly miss. This is a search under pressure rather than a
## fight").
##
## It hunts only over its own ground -- ARENA_WEST to ARENA_EAST either side of where it rose --
## and goes back there when she is off it, so it is not a thing that follows her out of the
## encounter. At no hp it is DRIVEN OFF, up and away, not killed: "It can be driven off but not
## killed while the lower half stands" -- the night it comes back is the finale's. Salted below, or
## caught where she cannot rejoin in the light, it leaves the same way (`leave`); which of those
## answered the encounter is the level's to judge.

const ARENA_WEST := 700.0
const ARENA_EAST := 600.0
const RISE_SECONDS := 1.0
const RISE := 260.0

## PLACEHOLDER BODY until there is art (ART_PLACEHOLDERS): a pale torso and long dark hair on
## wide wings -- lighter than the dark round it, so it reads in her light -- and its eyes.
const SKIN := Color(0.70, 0.64, 0.72)
const HAIR := Color(0.10, 0.08, 0.12)
const WING := Color(0.28, 0.22, 0.32)
const EYES := Color(1.0, 0.3, 0.25)

var _clock := 0.0
var _leaving := false
var _away: Tween


func _init() -> void:
	kind = "manananggal_upper"


func _physics_process(delta: float) -> void:
	_clock += delta
	if _leaving:
		art.advance(delta)
		return
	super(delta)
	queue_redraw()


## Whether she is over its ground.
func hunts_at(point: Vector2) -> bool:
	return point.x >= _home.x - ARENA_WEST and point.x <= _home.x + ARENA_EAST


func _in_striking_range(to_prey: Vector2) -> bool:
	return super(to_prey) and hunts_at(global_position + to_prey)


## Off its ground, she is not its to hunt: back over where it rose, and hold there.
func _move(delta: float, to_prey: Vector2) -> void:
	if state == State.CHASE and not hunts_at(global_position + to_prey):
		var to_home := _home - global_position
		var want := to_home.normalized() * speed if to_home.length() > HOLD else Vector2.ZERO
		velocity = velocity.move_toward(want, ACCEL * delta)
		return
	super(delta, to_prey)


## Up and away, and not there after -- driven off, salted below, or caught by the light.
func leave() -> void:
	if _leaving:
		return
	_leaving = true
	telegraph.stop()
	_set_colliding(false)
	_away = create_tween().set_parallel(true)
	_away.tween_property(self, "global_position:y", global_position.y - RISE, RISE_SECONDS)
	_away.tween_property(self, "modulate:a", 0.0, RISE_SECONDS)
	_away.chain().tween_callback(func() -> void: visible = false)


func is_gone() -> bool:
	return _leaving or state == State.DEAD


## Its last blow does not kill it: it is driven off, which is `leave` -- after `died`, which is
## how the level hears it.
func _die() -> void:
	_enter(State.DEAD)
	died.emit(self)
	leave()


func reset_for_restore() -> void:
	if _away != null and _away.is_valid():
		_away.kill()
	_leaving = false
	super()


func _draw() -> void:
	if art != null and art.has_art():
		return
	var flap := sin(_clock * 9.0) * 8.0
	for side: float in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(side * 8.0, -6.0),
			Vector2(side * 46.0, -20.0 + flap), Vector2(side * 40.0, 6.0 + flap * 0.5)]), WING)
	draw_rect(Rect2(Vector2(-9.0, -8.0), Vector2(18.0, 20.0)), SKIN)
	draw_circle(Vector2(0.0, -16.0), 9.0, SKIN)
	draw_rect(Rect2(Vector2(-11.0, -24.0), Vector2(22.0, 26.0)), HAIR)
	draw_rect(Rect2(Vector2(-6.0, -20.0), Vector2(12.0, 10.0)), SKIN)
	for side: float in [-1.0, 1.0]:
		draw_circle(Vector2(side * 3.0, -16.0), 1.8, EYES)
	# What it left behind trails from where it parted.
	draw_line(Vector2(0.0, 12.0), Vector2(sin(_clock * 3.0) * 4.0, 26.0), HAIR, 3.0)
