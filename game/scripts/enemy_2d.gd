class_name Enemy2D
extends CharacterBody2D
## Something in the dark that fights back: the base every walker and flier in a fight extends.
##
## IT ALWAYS SAYS WHAT IT IS ABOUT TO DO. Nothing strikes without a windup first -- it stops and an
## amber glint grows on it (Telegraph2D) -- so a hit is something she could have seen coming, and a
## blow landed in the windup knocks it out of the strike. That is the whole of what makes a fight
## fair rather than a dice roll, and it is why config/enemies.json never lets a windup go under 0.4.
##
## How it touches the world:
## - Its body is on ENEMY_BODY and stands on the world (mask WORLD), but never on her: it keeps a
##   collision exception for every body of whoever the player is, so the two overlap the way they
##   do in Terraria, and only a strike hurts.
## - Its hurtbox is on WORLD as well as ENEMY_HURTBOX, so every weapon's existing world-layer query
##   finds it, and apply_tool_hit lives here, which the weapons' parent walk reaches.
## - Its strike is an area that looks for the level's PlayerHurtbox2D, and lands once per strike.
##
## What it hunts is the level's PlayerHurtbox2D, which follows whoever the player is -- so it keeps
## hunting her through every change of body. No hurtbox (a level that does not fight): it sleeps.

signal died(enemy: Enemy2D)
signal struck_player(enemy: Enemy2D)

enum State { IDLE, CHASE, WINDUP, ATTACK, RECOVER, STUN, DEAD }

## Every encounter a checkpoint restore must put back the way it was.
const GROUP := &"dilim_encounters"
## Anything it will not cross while it hunts by smell. Each answers `reach()`, a radius.
const WARDS := &"scent_wards"
const CONFIG := "res://config/enemies.json"
## A blow takes it out of whatever it was doing for this long, windup included.
const STUN_SECONDS := 0.3
## Its shove from a blow, px/s, plus this much per point of damage: an axe throws it further.
const KNOCK_BASE := 220.0
const KNOCK_PER_DAMAGE := 80.0
const DEATH_FADE := 0.4
## PLACEHOLDER BODY until there is art for it: a shape darker than the dark, and its eyes.
const SHADE := Color(0.055, 0.047, 0.067)
const EYE := Color(1.0, 0.62, 0.22)
## Its strips, if it has any (tools/build_dilim_creatures.py, or drawn art under the same names).
const ART := "res://assets/Level4/creatures/"
const ANIM_FOR := {
	State.IDLE: "idle", State.CHASE: "run", State.WINDUP: "windup", State.ATTACK: "attack",
	State.RECOVER: "idle", State.STUN: "hurt", State.DEAD: "death",
}

@export var kind := "aswang_dog"
## Whether it hunts by smell -- and so will not cross a ward of bawang (Kent's design: "anything
## that hunts by smell will not cross it"). Every aswang does.
@export var hunts_by_smell := true
## Beyond this distance from her it does nothing at all: no thinking, no moving.
@export var sleep_beyond := 1400.0

var max_hp := 4
var speed := 200.0
var windup := 0.45
var attack_range := 96.0
var attack_time := 0.3
var lunge := 400.0
var recover := 0.5
var sight := 700.0
var body_size := Vector2(44.0, 28.0)
var knock := Vector2(300.0, -220.0)

var hp := 4
var state := State.IDLE
var hurtbox: Area2D
var hitbox: Area2D
var telegraph: Telegraph2D
var art: PixelStripAnimator

var _state_left := 0.0
var _home := Vector2.ZERO
var _facing := 1.0
var _landed := false
var _prey: PlayerHurtbox2D = null
var _excepted: Array[PhysicsBody2D] = []
var _excepted_for: Node = null
var _fade: Tween
## A burn still to land: ticks left, and the time to the next.
var _burn_ticks := 0
var _burn_every := 0.0
var _burn_clock := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	_read_config()
	hp = max_hp
	_home = global_position
	collision_layer = PhysicsLayers.ENEMY_BODY
	collision_mask = PhysicsLayers.WORLD
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = body_size
	shape.shape = box
	add_child(shape)
	hurtbox = _area("Hurtbox", PhysicsLayers.WORLD | PhysicsLayers.ENEMY_HURTBOX, 0, body_size)
	hurtbox.monitoring = false
	hitbox = _area("Hitbox", 0, PhysicsLayers.PLAYER_HURTBOX, body_size + Vector2(20.0, 8.0))
	hitbox.monitorable = false
	art = PixelStripAnimator.new()
	art.name = "Art"
	art.position = Vector2(0.0, body_size.y * 0.5)
	add_child(art)
	art.load_kind(ART, kind, ANIM_FOR.values())
	art.play("idle")
	telegraph = Telegraph2D.new()
	telegraph.position = Vector2(body_size.x * 0.25, -body_size.y * 0.5)
	add_child(telegraph)


func _physics_process(delta: float) -> void:
	art.advance(delta)
	if state == State.DEAD:
		return
	_burn(delta)
	if state == State.DEAD:
		return
	_find_prey()
	if _prey == null or global_position.distance_to(_prey.global_position) > sleep_beyond:
		velocity = Vector2.ZERO
		if state != State.STUN:
			_enter(State.IDLE)
		return
	_state_left -= delta
	var to_prey := _prey.global_position - global_position
	match state:
		State.IDLE:
			if to_prey.length() <= sight:
				_enter(State.CHASE)
		State.CHASE:
			_face(to_prey.x)
			if _in_striking_range(to_prey):
				_enter(State.WINDUP)
		State.WINDUP:
			if _state_left <= 0.0:
				_enter(State.ATTACK)
		State.ATTACK:
			_try_to_land()
			if _state_left <= 0.0:
				_enter(State.RECOVER)
		State.RECOVER:
			if _state_left <= 0.0:
				_enter(State.CHASE)
		State.STUN:
			if _state_left <= 0.0:
				_enter(State.CHASE)
	_move(delta, to_prey)
	move_and_slide()
	_keep_out_of_wards()


## A weapon's blow. Damage is the weapon's row for this level; anything that is not a weapon
## does nothing. Returns whether it landed.
func apply_tool_hit(tool: String, _impulse: float, actor: Node2D) -> bool:
	if state == State.DEAD or not WeaponTable.is_weapon(tool):
		return false
	var damage := maxi(1, WeaponTable.damage(tool))
	hp -= damage
	var from := actor.global_position.x if actor != null and is_instance_valid(actor) \
		else global_position.x - _facing
	var away := signf(global_position.x - from)
	if away == 0.0:
		away = -_facing
	velocity = Vector2(away * (KNOCK_BASE + KNOCK_PER_DAMAGE * damage), -140.0)
	_flash()
	if hp <= 0:
		_die()
	else:
		_enter(State.STUN)
		_state_left = STUN_SECONDS
	return true


## Back out to the edge of any ward it has come into, across, never up: a walker stays on its
## ground. Whatever it was doing toward the ward's middle stops there.
func _keep_out_of_wards() -> void:
	if not hunts_by_smell:
		return
	for node in get_tree().get_nodes_in_group(WARDS):
		var ward := node as Node2D
		if ward == null or not ward.has_method("reach"):
			continue
		var reach := float(ward.call("reach"))
		var away := global_position - ward.global_position
		if away.length() >= reach or absf(away.y) >= reach:
			continue
		var side := signf(away.x) if away.x != 0.0 else -_facing
		global_position.x = ward.global_position.x + side * sqrt(reach * reach - away.y * away.y)
		if signf(velocity.x) == -side:
			velocity.x = 0.0


## BLINDED FOR A MOMENT -- ash in its eyes (abo): out of whatever it was doing, a windup
## included, and standing still until it can see again. No harm and no shove.
func stun(seconds: float) -> void:
	if state == State.DEAD or seconds <= 0.0:
		return
	_enter(State.STUN)
	_state_left = seconds
	velocity.x = 0.0


## SALT ON ITS FLESH (Kent's design: "Burns aswang flesh over time"). `ticks` of one, spread over
## `seconds`, each a flash and no shove -- it is not a blow -- and the last can kill it. A second
## burn while one is under way starts over rather than stacking.
func apply_burn(ticks: int, seconds: float) -> void:
	if state == State.DEAD or ticks <= 0:
		return
	_burn_ticks = ticks
	_burn_every = seconds / float(ticks)
	_burn_clock = _burn_every


func is_burning() -> bool:
	return _burn_ticks > 0


func _burn(delta: float) -> void:
	if _burn_ticks <= 0:
		return
	_burn_clock -= delta
	if _burn_clock > 0.0:
		return
	_burn_ticks -= 1
	_burn_clock = _burn_every
	hp -= 1
	_flash()
	if hp <= 0:
		_burn_ticks = 0
		_die()


## Put back the way it was before the fight -- the checkpoint the level restored is from then.
func reset_for_restore() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	hp = max_hp
	_burn_ticks = 0
	global_position = _home
	velocity = Vector2.ZERO
	modulate = Color.WHITE
	visible = true
	_set_colliding(true)
	_enter(State.IDLE)


## Where a restore puts it back: where it is now. A level placing it after adding it calls this.
func reset_home() -> void:
	_home = global_position


func is_dead() -> bool:
	return state == State.DEAD


func state_name() -> String:
	return String(State.keys()[state])


# --- what a walker or a flier fills in -----------------------------------------------------

## How it moves this frame, given the state it is in and where she is.
func _move(_delta: float, _to_prey: Vector2) -> void:
	pass


## Whether she is close enough, and placed right, for it to start a windup.
func _in_striking_range(to_prey: Vector2) -> bool:
	return to_prey.length() <= attack_range


## The strike begins: the direction is decided now and does not follow her after.
func _begin_attack(_to_prey: Vector2) -> void:
	pass


# --- the shared machinery ------------------------------------------------------------------

func _enter(next: State) -> void:
	var was := state
	state = next
	art.play(ANIM_FOR[next])
	match next:
		State.WINDUP:
			_state_left = windup
			velocity.x = 0.0
			telegraph.show_for(windup)
		State.ATTACK:
			_state_left = attack_time
			_landed = false
			telegraph.stop()
			if _prey != null:
				_begin_attack(_prey.global_position - global_position)
		State.RECOVER:
			_state_left = recover
		_:
			if was == State.WINDUP:
				telegraph.stop()


func _try_to_land() -> void:
	if _landed or _prey == null:
		return
	for area in hitbox.get_overlapping_areas():
		if area == _prey:
			_landed = true
			if _prey.receive_hit(global_position, knock):
				struck_player.emit(self)
			return


func _find_prey() -> void:
	if _prey == null or not is_instance_valid(_prey):
		_prey = get_tree().get_first_node_in_group(PlayerHurtbox2D.GROUP) as PlayerHurtbox2D
	if _prey != null and _prey.player != _excepted_for:
		_except_player(_prey.player)


## Never stands on her or blocks her: an exception for every body of whoever the player is now.
func _except_player(player: Node) -> void:
	for body in _excepted:
		if is_instance_valid(body):
			remove_collision_exception_with(body)
	_excepted.clear()
	_excepted_for = player
	if player == null or not is_instance_valid(player):
		return
	var bodies: Array[Node] = player.find_children("*", "PhysicsBody2D", true, false)
	if player is PhysicsBody2D:
		bodies.append(player)
	for body in bodies:
		add_collision_exception_with(body)
		_excepted.append(body as PhysicsBody2D)


func _face(dx: float) -> void:
	if absf(dx) > 2.0 and signf(dx) != _facing:
		_facing = signf(dx)
		telegraph.position.x = absf(telegraph.position.x) * _facing
		art.face(_facing)
		queue_redraw()


func _draw() -> void:
	if art != null and art.has_art():
		return
	var half := body_size * 0.5
	draw_rect(Rect2(-half, body_size), SHADE)
	var eye := Vector2(_facing * half.x * 0.55, -half.y * 0.35)
	draw_circle(eye, 2.5, EYE)
	draw_circle(eye + Vector2(-_facing * 7.0, 0.0), 2.5, EYE)


func _die() -> void:
	_enter(State.DEAD)
	telegraph.stop()
	velocity = Vector2.ZERO
	_set_colliding(false)
	died.emit(self)
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 0.0, DEATH_FADE)
	_fade.tween_callback(func() -> void: visible = false)


## Deferred, all of it: the killing blow can arrive from inside a physics callback (a cannon shot
## landing, a boomerang's sweep), where changing what collides is refused.
func _set_colliding(on: bool) -> void:
	set_deferred(&"collision_layer", PhysicsLayers.ENEMY_BODY if on else 0)
	hurtbox.set_deferred(&"monitorable", on)
	hurtbox.set_deferred(&"collision_layer",
		(PhysicsLayers.WORLD | PhysicsLayers.ENEMY_HURTBOX) if on else 0)
	hitbox.set_deferred(&"monitoring", on)


func _flash() -> void:
	modulate = Color(1.6, 0.55, 0.45)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.18)


func _area(area_name: String, layer: int, mask: int, size: Vector2) -> Area2D:
	var area := Area2D.new()
	area.name = area_name
	area.collision_layer = layer
	area.collision_mask = mask
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	add_child(area)
	return area


func _read_config() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	if not (parsed is Dictionary):
		push_warning("Enemy2D: %s did not parse; %s keeps its defaults" % [CONFIG, kind])
		return
	var row: Dictionary = (parsed as Dictionary).get(kind, {})
	if row.is_empty():
		push_warning("Enemy2D: no row for '%s' in %s" % [kind, CONFIG])
		return
	max_hp = int(row.get("hp", max_hp))
	speed = float(row.get("speed", speed))
	windup = maxf(0.4, float(row.get("windup", windup)))
	attack_range = float(row.get("attack_range", attack_range))
	attack_time = float(row.get("attack_time", attack_time))
	lunge = float(row.get("lunge", lunge))
	recover = float(row.get("recover", recover))
	sight = float(row.get("sight", sight))
	var size: Array = row.get("size", [body_size.x, body_size.y])
	body_size = Vector2(float(size[0]), float(size[1]))
	var shove: Array = row.get("knock", [knock.x, knock.y])
	knock = Vector2(float(shove[0]), float(shove[1]))
