class_name Tiyanak2D
extends GroundEnemy2D
## The tiyanak: an infant's shape, crying in the undergrowth to bring travellers off the path.
##
## Kent's design: "The threat is the lure, not the creature. The cry pulls the player toward a
## drop or a nest, and the danger is the terrain it leads to." So it sits at the near rim of a
## drop its undergrowth hides -- the bushes run on over nothing -- and cries every CRY_EVERY
## seconds. The cry is SHOWN as well as heard (the design: "a directional pull or a disturbance in
## the undergrowth where the sound comes from"): the undergrowth stirs, and `cried` is the level's
## cue to put an amber ripple where it comes from.
##
## IT CANNOT REACH A PLAYER WHO DOES NOT COME TO IT. It goes for her only while she is in its LURE
## -- down on the ground by it, not up on the path over it -- and never further than LEASH from
## where it sits. A close ground-level approach plays the supplied transformation, then a leap
## out of the bush. Shown a light it shows what it is and flees. Struck down it is gone, and leaves
## nothing (`drops` off: "allowing this and not rewarding it"). Which of those answered the
## encounter is the level's to judge.

signal cried(at: Vector2)

const CRY_EVERY := 4.0
## How far it goes from where it sits, chasing her.
const LEASH := 160.0
## Its lure: from this far west of it to the far edge of its undergrowth, and no higher above the
## ground it sits on than this -- the path over the drop is out of it. Short of the path's first
## log (at its mark, 250 west), so she can step up onto the path from outside the lure.
const LURE_WEST := 180.0
const LURE_HEIGHT := 70.0
## The undergrowth it hides the drop with, from just behind it out over the drop.
const UNDERGROWTH := Rect2(-44.0, -58.0, 480.0, 58.0)
const STIR_SECONDS := 0.8
## Seen for what it is this long before it is off.
const TRUE_FORM_SECONDS := 0.6
const FLEE_SECONDS := 1.2
const FLEE_SHARE := 1.4
## Close enough to investigate the baby, on the ground in the lure, never on the high path.
const AMBUSH_REACH := 120.0
const TRANSFORM_SECONDS := 0.75
const LEAP_SECONDS := 0.7
const LEAP_SPEED := 220.0
const LEAP_UP := 300.0

## PLACEHOLDER BODY until there is art (ART_PLACEHOLDERS): a swaddled bundle, and what is in it.
const CLOTH := Color(0.86, 0.82, 0.74)
const CLOTH_SHADE := Color(0.62, 0.58, 0.52)
const SKIN := Color(0.88, 0.72, 0.62)
const TRUE_SKIN := Color(0.36, 0.42, 0.32)
const TRUE_EYE := Color(0.95, 0.2, 0.15)
const FANG := Color(0.96, 0.95, 0.9)
const LEAF := Color(0.13, 0.22, 0.14)
const LEAF_LIT := Color(0.22, 0.34, 0.2)

## The bushes it hides the drop with. Their own node, beside it: they stay where they are when it
## flees and when it is struck down, and only thin once a light has shown what was under them.
var undergrowth: Undergrowth

var _cry_clock := 0.0
var _stir := 0.0
var _true_form := 0.0
var _fleeing := 0.0
var _gone := false
var _revealed := false
var _transformed := false
var _transforming := 0.0
var _leaping := 0.0
var _leap_direction := 1.0
var _flee_after_transform := false


func _init() -> void:
	kind = "tiyanak"
	drops = false


func _ready() -> void:
	super._ready()
	# The baby must be visible to lure her; the old bush covered almost all of its body.
	z_index = 7
	undergrowth = Undergrowth.new()
	undergrowth.name = "%sUndergrowth" % name
	undergrowth.tiyanak = self
	undergrowth.position = position + Vector2(0.0, body_size.y * 0.5)
	get_parent().add_child.call_deferred(undergrowth)


## How hard the undergrowth is stirring, 0 to 1.
func stir() -> float:
	return _stir / STIR_SECONDS


func _physics_process(delta: float) -> void:
	_pick_art()
	_stir = maxf(0.0, _stir - delta)
	if _gone:
		return
	if state == State.DEAD:
		super(delta)
		return
	_find_prey()
	if _fleeing > 0.0:
		art.advance(delta)
		_flee_on(delta)
		return
	if _true_form > 0.0:
		art.advance(delta)
		_true_form -= delta
		velocity = Vector2.ZERO
		queue_redraw()
		if _true_form <= 0.0:
			_fleeing = FLEE_SECONDS
			_set_colliding(false)
		return
	if _transforming > 0.0:
		_burn(delta)
		if state == State.DEAD:
			return
		_transforming = maxf(0.0, _transforming - delta)
		velocity = Vector2.ZERO
		_pick_art()
		if _transforming <= 0.0:
			_transformed = true
			if _flee_after_transform:
				_true_form = TRUE_FORM_SECONDS
			else:
				_leaping = LEAP_SECONDS
				_leap_direction = signf(_prey.global_position.x - global_position.x) if _prey != null else -1.0
				if is_zero_approx(_leap_direction):
					_leap_direction = _facing
				_face(_leap_direction * 10.0)
				velocity = Vector2(_leap_direction * LEAP_SPEED, -LEAP_UP)
			_pick_art()
		queue_redraw()
		return
	if _leaping > 0.0:
		_burn(delta)
		if state == State.DEAD:
			return
		art.advance(delta)
		_leaping = maxf(0.0, _leaping - delta)
		velocity.y = minf(velocity.y + _gravity * delta, MAX_FALL)
		_limit_to_home(delta)
		# Jump out of the bush, not off the bank into the hidden drop beside it.
		if not is_zero_approx(velocity.x) and not _safe_to_walk(signf(velocity.x), Vector2.ZERO):
			velocity.x = 0.0
		move_and_slide()
		_keep_out_of_wards()
		if _leaping <= 0.0 or (is_on_floor() and _leaping < LEAP_SECONDS - 0.18):
			_leaping = 0.0
			_enter(State.CHASE)
		return
	if not _transformed:
		_burn(delta)
		if state == State.DEAD:
			return
		if _prey != null:
			_face(_prey.global_position.x - global_position.x)
		_cry_clock += delta
		if _cry_clock >= CRY_EVERY:
			_cry_clock = 0.0
			_stir = STIR_SECONDS
			cried.emit(global_position)
		# Stay a harmless crying bundle until she investigates the bush. The transformation is
		# the warning; its first jump is a startle, and damaging strikes still use the windup.
		if _prey != null and in_lure(_prey.global_position) \
				and absf(_prey.global_position.x - _home.x) <= AMBUSH_REACH:
			_begin_transformation(false)
		else:
			velocity.x = 0.0
			if not is_on_floor():
				velocity.y = minf(velocity.y + _gravity * delta, MAX_FALL)
			move_and_slide()
		art.advance(delta)
		return
	super(delta)
	# Out of its lure it stops pursuing her, but does not turn back into a harmless baby.
	if _prey != null and (state == State.CHASE or state == State.WINDUP) and not in_lure(_prey.global_position):
		_enter(State.IDLE)
	if _stir > 0.0:
		queue_redraw()


## Whether `point` -- her middle -- is down in its lure.
func in_lure(point: Vector2) -> bool:
	var ground := _home.y + body_size.y * 0.5
	return point.x >= _home.x - LURE_WEST and point.x <= _home.x + UNDERGROWTH.end.x \
		and point.y >= ground - LURE_HEIGHT and point.y <= ground + 40.0


## Lit by a light she drew: it shows what it is, and is off.
func reveal_and_flee() -> void:
	if is_gone():
		return
	if not _transformed:
		if _transforming <= 0.0:
			_begin_transformation(true)
		else:
			_flee_after_transform = true
		return
	_revealed = true
	_leaping = 0.0
	_flee_after_transform = true
	_true_form = TRUE_FORM_SECONDS
	telegraph.stop()
	if undergrowth != null:
		undergrowth.show_through()
	_enter(State.IDLE)
	queue_redraw()


func _begin_transformation(flee_after: bool) -> void:
	_revealed = true
	_flee_after_transform = flee_after
	_transforming = TRANSFORM_SECONDS
	_stir = STIR_SECONDS
	velocity = Vector2.ZERO
	telegraph.stop()
	_enter(State.IDLE)
	if undergrowth != null:
		undergrowth.show_through()
	queue_redraw()


func apply_tool_hit(tool: String, impulse: float, actor: Node2D) -> bool:
	if not _revealed and not is_dead() and WeaponTable.is_weapon(tool):
		_begin_transformation(false)
	return super(tool, impulse, actor)


## A light or a fight removes it; unmasking for its ambush does not solve the encounter.
func is_gone() -> bool:
	return _gone or _fleeing > 0.0 or _true_form > 0.0 \
		or (_transforming > 0.0 and _flee_after_transform) or state == State.DEAD


func is_revealed() -> bool:
	return _revealed


func reset_for_restore() -> void:
	_cry_clock = 0.0
	_stir = 0.0
	_true_form = 0.0
	_fleeing = 0.0
	_gone = false
	_revealed = false
	_transformed = false
	_transforming = 0.0
	_leaping = 0.0
	_flee_after_transform = false
	super()
	if undergrowth != null:
		undergrowth.queue_redraw()


## Chasing, it keeps to its leash.
func _move(delta: float, to_prey: Vector2) -> void:
	super(delta, to_prey)
	_limit_to_home(delta)


func _limit_to_home(delta: float) -> void:
	var next_x := global_position.x + velocity.x * delta
	if absf(next_x - _home.x) > LEASH and signf(next_x - _home.x) == signf(velocity.x):
		velocity.x = 0.0


func _in_striking_range(to_prey: Vector2) -> bool:
	return super(to_prey) and in_lure(global_position + to_prey)


func _flee_on(delta: float) -> void:
	_fleeing -= delta
	var away := signf(global_position.x - _prey.global_position.x) if _prey != null else 1.0
	global_position.x += (away if away != 0.0 else 1.0) * speed * FLEE_SHARE * delta
	modulate.a = clampf(_fleeing / FLEE_SECONDS, 0.0, 1.0)
	queue_redraw()
	if _fleeing <= 0.0:
		_gone = true
		visible = false


func _art_extras() -> Array:
	return ["true", "transform", "leap"]


func _enter(next: State) -> void:
	super(next)
	_pick_art()


## Select once, advance once: normal combat advances in Enemy2D, custom phases advance above.
func _pick_art() -> void:
	if art == null or not art.has_art():
		return
	if state == State.DEAD:
		art.play("death")
	elif _transforming > 0.0:
		art.play("transform")
		art.frame = mini(int((1.0 - _transforming / TRANSFORM_SECONDS) * art.hframes), art.hframes - 1)
	elif _leaping > 0.0:
		art.play("leap")
	elif _fleeing > 0.0:
		art.play("run")
	elif _true_form > 0.0 or (_transformed and state in [State.IDLE, State.RECOVER]):
		art.play("true")
	elif _transformed:
		art.play(ANIM_FOR[state])
	else:
		art.play("idle")


func _draw() -> void:
	if art != null and art.has_art():
		return
	var feet := body_size.y * 0.5
	if _revealed:
		# What it is: small, hunched, green-grey, red-eyed and fanged.
		draw_rect(Rect2(Vector2(-15.0, feet - 24.0), Vector2(30.0, 24.0)), TRUE_SKIN)
		draw_circle(Vector2(0.0, feet - 28.0), 11.0, TRUE_SKIN)
		for side: float in [-1.0, 1.0]:
			draw_circle(Vector2(side * 4.5, feet - 30.0), 2.2, TRUE_EYE)
			draw_rect(Rect2(Vector2(side * 3.0 - 1.0, feet - 22.0), Vector2(2.0, 4.0)), FANG)
		return
	# The bundle: cloth wrapped round, a face at the top, its mouth open while it cries.
	draw_rect(Rect2(Vector2(-14.0, feet - 20.0), Vector2(28.0, 20.0)), CLOTH)
	draw_rect(Rect2(Vector2(-14.0, feet - 6.0), Vector2(28.0, 6.0)), CLOTH_SHADE)
	draw_circle(Vector2(0.0, feet - 24.0), 9.0, CLOTH)
	draw_circle(Vector2(0.0, feet - 23.0), 6.0, SKIN)
	var crying := _stir > 0.0
	draw_rect(Rect2(Vector2(-2.0, feet - 21.0), Vector2(4.0, 3.0 if crying else 1.0)), CLOTH_SHADE)


## The bushes over the drop, standing on the ground it sits on and hanging down into the drop. They
## stir while it cries; once it has shown what it is, they part, and the drop shows
## through.
class Undergrowth extends Node2D:
	## Their picture (tools/dilim_small.py undergrowth): the bushes that span UNDERGROWTH, ART_MARGIN
	## px clear at the sides and top, and under them, over the drop, a thicket ART_BELOW px down past
	## the ground's rim -- in her light the drop is more bushes, not a hole. The discs below stand in
	## only while there is no picture.
	const ART := "tiyanak_undergrowth_idle.png"
	const ART_MARGIN := 4.0
	const ART_BELOW := 200.0
	var tiyanak: Tiyanak2D
	var _art: Texture2D

	func _ready() -> void:
		z_index = 6
		if ResourceLoader.exists(Enemy2D.ART + ART):
			_art = load(Enemy2D.ART + ART) as Texture2D

	func has_art() -> bool:
		return _art != null

	func _process(_delta: float) -> void:
		if tiyanak != null and is_instance_valid(tiyanak) and tiyanak.stir() > 0.0:
			queue_redraw()

	func _draw() -> void:
		var lit := tiyanak != null and is_instance_valid(tiyanak) and tiyanak.is_revealed()
		var shake := 0.0
		if tiyanak != null and is_instance_valid(tiyanak):
			shake = sin(tiyanak.stir() * 30.0) * 3.0 * tiyanak.stir()
		var thin := 0.35 if lit else 1.0
		if _art != null:
			draw_texture(_art, Vector2(UNDERGROWTH.position.x - ART_MARGIN + shake, -_art.get_height() + ART_BELOW),
				Color(1.0, 1.0, 1.0, thin))
			return
		var x := UNDERGROWTH.position.x
		var step := 0
		while x < UNDERGROWTH.end.x:
			var height := 34.0 + float((step * 37) % 24)
			var sway := shake * (1.0 if step % 2 == 0 else -1.0)
			var colour := LEAF_LIT if step % 3 == 0 else LEAF
			draw_circle(Vector2(x + sway, -height * 0.5), height * 0.55, Color(colour, thin))
			x += 26.0
			step += 1

	## Thinned when it was shown: redrawn once, then still.
	func show_through() -> void:
		queue_redraw()
