class_name Santelmo2D
extends Node2D
## A santelmo: a floating flame at the edge of the woods that follows what runs (Kent's design,
## "Running makes it faster. Walking makes it lose interest.").
##
## Not a fight and not a puzzle -- a rule to work out under pressure. While she RUNS anywhere it
## can see her, it wants her, and comes at a little more than her own pace, so running away from
## it never works. While she walks, or stands, it loses interest at INTEREST_DECAY a second and
## only drifts after her; at none it goes home. Touching her takes the lantern down a stage, and
## it is spent: it goes out, and forms again at home after REFORM_SECONDS.
##
## It reads her pace off how far her hurtbox moved, not off any one body's velocity, so it works
## the same whoever she is -- the apo, or a drawn creature. No hurtbox (a level that does not
## fight): it floats where it is.
##
## It is a light like every other, so the dark is cut around it -- the one thing in the woods she
## can see coming.

const GROUP := &"dilim_encounters"
## Faster than this, horizontally, and she is running: her walk is 110, her run 260.
const RUNNING_PACE := 187.0
## Faster than this between two ticks is not running, it is being put somewhere -- a restore, a
## knockout, a Continue: the reading starts over rather than calling it a sprint. Seen in a window:
## put down near it, she was taken for a runner at seventy thousand px/s, and it burned her.
const PUT_DOWN_PACE := 1200.0
## How much faster than her it comes while she runs.
const CHASE_SHARE := 1.15
## How far it can see a runner.
const SIGHT := 640.0
## Interest lost per second while she does not run, from 1.
const INTEREST_DECAY := 0.35
## How fast it follows while it still wants her but she is walking, and how fast it goes home.
const DRIFT := 60.0
const HOMING := 90.0
## Closer than this to her middle and it has touched her.
const CONTACT := 34.0
const REFORM_SECONDS := 6.0
## Its own light, world px.
const LIGHT_RADIUS := 110.0
## How far above its rest point it bobs, and how fast.
const BOB := 6.0
const BOB_HZ := 0.8
## The little shove a touch gives: a flame, not a blow.
const KNOCK := Vector2(160.0, -120.0)

signal touched_her

var interest := 0.0
var _home := Vector2.ZERO
var _out_left := 0.0
var _last_middle := Vector2.INF
var _clock := 0.0
var _chasing := false


## Its strips (tools/build_dilim_creatures.py, or drawn art under the same names); the code-drawn
## body below stands in only while there are none.
var art: PixelStripAnimator


func _make_art(kind: String, anims: Array, centre: bool, at: Vector2) -> void:
	art = PixelStripAnimator.new()
	art.name = "Art"
	art.centre = centre
	art.position = at
	add_child(art)
	art.load_kind(Enemy2D.ART, kind, anims)
	art.play("idle")


func _ready() -> void:
	_make_art("santelmo", ["idle", "hot"], true, Vector2.ZERO)
	add_to_group(GROUP)
	add_to_group(LightField.GROUP)
	_home = global_position
	z_index = 6


func _physics_process(delta: float) -> void:
	_clock += delta
	if _out_left > 0.0:
		_out_left -= delta
		if _out_left <= 0.0:
			_reform()
		return
	var hurtbox := _her_hurtbox()
	if hurtbox == null:
		_last_middle = Vector2.INF
		return
	var middle := hurtbox.middle()
	var pace := 0.0
	if _last_middle != Vector2.INF and delta > 0.0:
		pace = absf(middle.x - _last_middle.x) / delta
	if pace > PUT_DOWN_PACE:
		pace = 0.0
	_last_middle = middle
	var running := pace > RUNNING_PACE
	var to_her := middle - global_position
	if running and to_her.length() <= SIGHT:
		interest = 1.0
	else:
		interest = maxf(0.0, interest - INTEREST_DECAY * delta)
	_chasing = interest > 0.0
	var step := 0.0
	var target := _home
	if _chasing:
		target = middle
		step = (pace * CHASE_SHARE if running else DRIFT) * delta
	else:
		step = HOMING * delta
	global_position = global_position.move_toward(target, step)
	if _chasing and global_position.distance_to(middle) <= CONTACT:
		if hurtbox.receive_hit(global_position, KNOCK):
			touched_her.emit()
			_go_out()
	queue_redraw()


## Whether it is out after touching her, and forming again at home.
func is_out() -> bool:
	return _out_left > 0.0


func is_chasing() -> bool:
	return _chasing and not is_out()


func home() -> Vector2:
	return _home


func light_hole() -> Dictionary:
	if is_out():
		return {}
	return {"position": global_position, "radius": LIGHT_RADIUS, "strength": 1.0}


## Back where it floats, wanting nothing -- the checkpoint the level restored is from before.
func reset_for_restore() -> void:
	_reform()


func _go_out() -> void:
	_out_left = REFORM_SECONDS
	interest = 0.0
	_chasing = false
	visible = false


func _reform() -> void:
	_out_left = 0.0
	interest = 0.0
	_chasing = false
	global_position = _home
	_last_middle = Vector2.INF
	visible = true


func _her_hurtbox() -> PlayerHurtbox2D:
	for node in get_tree().get_nodes_in_group(PlayerHurtbox2D.GROUP):
		var hurtbox := node as PlayerHurtbox2D
		if hurtbox != null and hurtbox.is_inside_tree():
			return hurtbox
	return null


## PLACEHOLDER until it has art: a flame of three soft rounds, brighter while it wants her.
func _draw() -> void:
	var lift := Vector2(0.0, sin(_clock * TAU * BOB_HZ) * BOB)
	var heat := 1.0 if _chasing else 0.7
	draw_circle(lift, 22.0, Color(1.0, 0.45, 0.12, 0.22 * heat))
	if art != null and art.has_art():
		art.position = lift
		art.play("hot" if _chasing else "idle")
		art.advance(get_process_delta_time() if is_processing() else get_physics_process_delta_time())
		return
	draw_circle(lift + Vector2(0.0, 2.0), 13.0, Color(1.0, 0.62, 0.2, 0.55 * heat))
	draw_circle(lift + Vector2(0.0, 4.0), 6.0, Color(1.0, 0.92, 0.6, 0.95))
