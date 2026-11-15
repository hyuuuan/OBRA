class_name CannonShot2D
extends RigidBody2D
## A drawn cannon's shot, made to be followed with the eye in every level, Dilim's dark included.
##
## Kent, 2026-11-13: "lets fix how shots are fired in using cannon since its not that visible and it
## seems to not work", then "make this shots for all like in all levels especially when cannon is
## used". It was an 11 px ball of near-black ink: on Dilim's ground under a 0.9 dark it could not be
## seen leaving the muzzle, and where it landed a creature only flashed, so a shot that hit read the
## same as one that missed. Now it is a pale ball with an ink keyline and a short trail of smoke, with
## a flash at the muzzle and a burst where it lands -- a bigger, gilt one on something it hurt.
##
## ⚠ SEEN, NOT LIGHT. In a dark level the shot and each burst cut a small hole in the dark through
## DarknessLayer.REVEAL_GROUP, which LightField never counts: a shot shows where it goes without
## sending a sigbin off or holding a creature back the way a lantern does.
##
## Its physics are the old ball's exactly -- mass, gravity, radius, continuous collision -- so where
## a shot goes and what it lands on are unchanged. UtilityObject._fire_cannon aims it and hears it land.

const RADIUS := 11.0
## The ball, light on any ground; the keyline is what keeps it a ball on a pale sky.
const CORE := UISkin.CREAM_TEXT
const KEYLINE := UISkin.INK
const SHINE := UISkin.GILT_HI
const SMOKE := UISkin.MUTED
## Puffs behind it, one laid every PUFF_EVERY physics frames: the pixel idiom's 15 fps at 60.
const TRAIL := 6
const PUFF_EVERY := 4
## How much of the dark it parts around itself, px, and how far.
const REVEAL_RADIUS := 64.0
const REVEAL_STRENGTH := 0.85

var _trail: Array[Vector2] = []
var _ticks := 0


func _init() -> void:
	mass = 4.0
	gravity_scale = 0.85
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	contact_monitor = true
	max_contacts_reported = 4
	# Drawn in the world's frame below, so a spin picked up off a glancing contact cannot swing the
	# trail round the ball.
	lock_rotation = true
	var ball := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	ball.shape = circle
	add_child(ball)
	add_to_group(DarknessLayer.REVEAL_GROUP)


func _physics_process(_delta: float) -> void:
	_ticks += 1
	if _ticks % PUFF_EVERY != 0:
		return
	_trail.append(global_position.round())
	if _trail.size() > TRAIL:
		_trail.pop_front()
	queue_redraw()


## Where the shot has been, oldest first, in world px -- for a probe.
func trail() -> Array[Vector2]:
	return _trail.duplicate()


func dark_reveal() -> Dictionary:
	return {"position": global_position, "radius": REVEAL_RADIUS, "strength": REVEAL_STRENGTH}


func _draw() -> void:
	# The trail first, under the ball, in world px: older puffs smaller and fainter, alpha in eighths.
	draw_set_transform_matrix(global_transform.affine_inverse())
	var count := _trail.size()
	for i in range(count):
		var age := float(count - i) / float(TRAIL + 1)
		var alpha := floorf((1.0 - age) * 0.75 * 8.0) / 8.0
		if alpha <= 0.0:
			continue
		draw_circle(_trail[i], roundf(RADIUS * (1.0 - age * 0.6)), Color(SMOKE, alpha))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_circle(Vector2.ZERO, RADIUS, KEYLINE)
	draw_circle(Vector2.ZERO, RADIUS - 2.0, CORE)
	draw_circle(Vector2(-4.0, -4.0), 3.0, SHINE)


## A flash where a shot leaves the muzzle, or a burst where it lands: `struck` is a landing on
## something it hurt, and is bigger and gilt. Put in `world` at `at`, and gone in a third of a second.
static func burst(world: Node, at: Vector2, kind: StringName) -> Node2D:
	if world == null or not is_instance_valid(world):
		return null
	var flash := Burst.new()
	flash.kind = kind
	flash.position = (world as Node2D).to_local(at) if world is Node2D else at
	# Deferred: a landing is heard inside a physics callback.
	world.add_child.call_deferred(flash)
	return flash


## The flash and the burst. Stepped at the pixel idiom's 15 fps; under Reduce motion, one still
## frame for the same time and nothing that grows.
class Burst:
	extends Node2D

	const MUZZLE := &"muzzle"
	const LANDED := &"landed"
	const STRUCK := &"struck"
	const SECONDS := 0.33
	const SPARKS := 8

	var kind: StringName = LANDED
	var _age := 0.0
	var _frame := 0

	func _ready() -> void:
		add_to_group(DarknessLayer.REVEAL_GROUP)
		add_to_group(&"cannon_bursts")
		z_index = 5

	func _process(delta: float) -> void:
		_age += delta
		if _age >= SECONDS:
			queue_free()
			return
		var frame := 0 if Motion.reduced() else int(_age * Motion.PIXEL_FPS)
		if frame != _frame:
			_frame = frame
			queue_redraw()

	func reach() -> float:
		match kind:
			MUZZLE:
				return 20.0
			STRUCK:
				return 44.0
			_:
				return 28.0

	func dark_reveal() -> Dictionary:
		return {"position": global_position, "radius": reach() * 2.6, "strength": 1.0}

	## ⚠ SOLID, NOT SEE-THROUGH. A translucent disc under the ring read as a soap bubble drifting
	## off her (Kent's first look, in Dilim): a flash is a hot core that shrinks inside a ring that
	## grows, and a landing throws sparks.
	func _draw() -> void:
		var steps := maxf(1.0, floorf(SECONDS * Motion.PIXEL_FPS))
		var t := float(_frame) / steps
		var hot: Color = UISkin.GILT_HI if kind == STRUCK else UISkin.CREAM_TEXT
		var alpha := floorf((1.0 - t * 0.75) * 8.0) / 8.0
		var core := roundf(reach() * 0.6 * (1.0 - t))
		if core >= 2.0:
			draw_circle(Vector2.ZERO, core, Color(UISkin.CREAM_TEXT if kind == STRUCK else hot, alpha))
		draw_arc(Vector2.ZERO, roundf(reach() * (0.5 + 0.6 * t)), 0.0, TAU, 28, Color(hot, alpha), 4.0)
		if kind == MUZZLE:
			return
		for i in range(SPARKS):
			var way := Vector2.RIGHT.rotated(TAU * (float(i) + 0.5) / float(SPARKS))
			var tip := (way * reach() * (0.6 + 0.9 * t)).round()
			draw_rect(Rect2(tip - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), Color(hot, alpha))
