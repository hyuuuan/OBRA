class_name Bungisngis2D
extends GroundEnemy2D
## The bungisngis: a one-eyed giant, always laughing, standing in the crossing (Kent's design:
## "Strong, slow, and easily distracted. Blocks a crossing. A wall rather than a hunter").
##
## It stands on the ravine's floor -- the way across, down one side and up the other -- and its
## body is a WALL there: she cannot walk through it, which is what blocking the crossing means. It
## goes for her only as far as its own floor reaches, slowly, and its strike is a SLAM, all round
## it at once after a long windup, that throws her a long way. Answered three ways, each the level's
## to judge: something absurd brought to it sets it laughing itself helpless (`laugh`), and after it
## sits aside, out of the way, for good; beaten, it is driven off; or she goes over or round it and
## it never comes into it.

## How far round it the slam lands -- her middle within this of its middle.
const SLAM_RADIUS := 150.0
const LAUGH_SECONDS := 10.0
## Where it sits once it has laughed itself out: this far back along its floor, out of the way.
const ASIDE_SHIFT := 92.0
const DRIVEN_OFF_SECONDS := 1.0
## The wall its body makes in the crossing.
const WALL := Vector2(70.0, 180.0)

## PLACEHOLDER BODY until there is art (ART_PLACEHOLDERS): lighter than the dark round it, so it
## reads in her light; one eye, and the grin it never loses.
const HIDE := Color(0.42, 0.36, 0.32)
const HIDE_SHADE := Color(0.30, 0.26, 0.23)
const EYE_WHITE := Color(0.95, 0.92, 0.82)
const EYE_DOT := Color(0.12, 0.08, 0.06)
const GRIN := Color(0.14, 0.06, 0.05)
const TEETH := Color(0.93, 0.9, 0.8)
const CLUB := Color(0.36, 0.24, 0.14)

var wall: StaticBody2D

var _laughing := 0.0
var _aside := false
var _clock := 0.0


func _init() -> void:
	kind = "bungisngis"
	hunts_by_smell = false


func _ready() -> void:
	super._ready()
	wall = StaticBody2D.new()
	wall.name = "Wall"
	wall.collision_layer = PhysicsLayers.WORLD
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = WALL
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	add_collision_exception_with(wall)


func _physics_process(delta: float) -> void:
	_clock += delta
	if _laughing > 0.0:
		art.play("laugh")
		art.advance(delta)
		_laughing -= delta
		velocity = Vector2(0.0, velocity.y + 980.0 * delta)
		move_and_slide()
		queue_redraw()
		if _laughing <= 0.0:
			_sit_aside()
		return
	if _aside:
		art.play("aside")
		art.advance(delta)
		return
	super(delta)
	queue_redraw()


## Something absurd in front of it: it laughs itself helpless, the crossing open while it does,
## and then sits out of the way.
func laugh() -> void:
	if not is_in_the_way():
		return
	_laughing = LAUGH_SECONDS
	telegraph.stop()
	_enter(State.IDLE)
	velocity.x = 0.0
	_block(false)


## Whether it still stands in the crossing.
func is_in_the_way() -> bool:
	return state != State.DEAD and _laughing <= 0.0 and not _aside


func is_laughing() -> bool:
	return _laughing > 0.0


func is_aside() -> bool:
	return _aside


## Only while it stands there: laughing or sat aside, a blow is nothing to it, and changes nothing.
func apply_tool_hit(tool: String, impulse: float, actor: Node2D) -> bool:
	if not is_in_the_way():
		return false
	return super(tool, impulse, actor)


func reset_for_restore() -> void:
	_laughing = 0.0
	_aside = false
	super()
	_block(true)


## Its slam: no lunge, it stays where it stands and brings the club down.
func _begin_attack(to_prey: Vector2) -> void:
	_face(to_prey.x)
	velocity.x = 0.0


func _in_striking_range(to_prey: Vector2) -> bool:
	return to_prey.length() <= attack_range


## The slam lands on her if her middle is inside its reach -- all round it, not just ahead.
func _try_to_land() -> void:
	if _landed or _prey == null:
		return
	if _prey.global_position.distance_to(global_position) <= SLAM_RADIUS:
		_landed = true
		if _prey.receive_hit(global_position, knock):
			struck_player.emit(self)


## Beaten, it goes -- and so does its wall.
func _set_colliding(on: bool) -> void:
	super(on)
	_block(on and _laughing <= 0.0 and not _aside)


func _block(on: bool) -> void:
	if wall == null:
		return
	wall.set_deferred(&"collision_layer", PhysicsLayers.WORLD if on else 0)


func _sit_aside() -> void:
	_aside = true
	var back := create_tween()
	back.tween_property(self, "global_position:x", _home.x - ASIDE_SHIFT, 0.6)
	queue_redraw()


func _art_extras() -> Array:
	return ["laugh", "aside"]


func _draw() -> void:
	if art != null and art.has_art():
		return
	var feet := body_size.y * 0.5
	var shake := sin(_clock * 40.0) * 2.0 if _laughing > 0.0 else 0.0
	# Sat aside it is half as tall: squatting, still grinning.
	var tall := body_size.y * (0.55 if _aside else 1.0)
	var top := feet - tall
	draw_rect(Rect2(Vector2(-body_size.x * 0.5 + shake, top + 30.0), Vector2(body_size.x, tall - 30.0)), HIDE)
	draw_rect(Rect2(Vector2(-body_size.x * 0.5 + shake, feet - 18.0), Vector2(body_size.x, 18.0)), HIDE_SHADE)
	var head := Vector2(shake, top + 26.0)
	draw_circle(head, 30.0, HIDE)
	var eye := head + Vector2(_facing * 4.0, -6.0)
	if _laughing > 0.0 or _aside:
		# Laughing its eye shut: a crease.
		draw_rect(Rect2(eye + Vector2(-9.0, -1.0), Vector2(18.0, 3.0)), EYE_DOT)
	else:
		draw_circle(eye, 9.0, EYE_WHITE)
		draw_circle(eye + Vector2(_facing * 2.0, 0.0), 4.0, EYE_DOT)
	var mouth_open := 12.0 if _laughing > 0.0 else 6.0
	draw_rect(Rect2(head + Vector2(-16.0, 8.0), Vector2(32.0, mouth_open)), GRIN)
	draw_rect(Rect2(head + Vector2(-14.0, 8.0), Vector2(28.0, 3.0)), TEETH)
	if not _aside:
		# The club, raised in its windup and down in its slam.
		var raised := state == State.WINDUP
		var grip := Vector2(_facing * (body_size.x * 0.5 + 8.0), top + 70.0)
		var club_end := grip + (Vector2(0.0, -70.0) if raised else Vector2(_facing * 40.0, 50.0))
		draw_line(grip, club_end, CLUB, 12.0)
