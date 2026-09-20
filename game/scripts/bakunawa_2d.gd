class_name Bakunawa2D
extends Node2D
## DAGAT'S ONE ENCOUNTER. Blind, frantic, and going over the same stretch of water again and
## again because it has lost something.
##
## ⚠ IT IS AN AUTHORED ENCOUNTER, NOT ONE OF THE FIFTY. The player never draws it and the
## recogniser never sees it -- the same framing the aswang gets in Dilim. It is also not a
## mythology mechanic: the game never explains it, never names what its eyes remind Lolo of,
## and never mentions the moon, which is the association a reader brings.
##
## THREE RESOLUTIONS, ONE CREATURE. Helping it see, it finds what it lost. Avoiding it, it
## keeps searching. Fighting it, you win against something that was never attacking you on
## purpose -- so it is **subdued or exhausted, never killed**, and the cost of that route is
## that nothing was healed.
##
## WHAT IT OWES THE REST OF THE GAME:
##   * `apply_tool_hit` -- the same contract Destructible2D publishes, which is what makes
##     every drawn weapon work on it without this file knowing what a sword is. The five
##     `strike` classes already differ in reach (swing 96px, boomerang 320, cannon 640) and
##     now differ in bite as well, which is the design's "more than damage".
##   * `sees()` -- the stealth rule as a real query rather than a lighting effect. Its cones
##     are drawn because they ARE the rule.
##   * `Coils`, a body across the channel, which is what "it moves aside" means mechanically.
##
## CODE-DRAWN, AND THAT IS A CONTRACT AND NOT THE ART. Nothing on Dagat's asset list exists.
## The states below are the ones the design's own asset list asks for, so the sprite work can
## replace `_draw()` without touching anything else.

enum State { SEARCHING, FOLLOWING, CALM, FIGHTING, SUBDUED }

## It has noticed something it should not have. The level resets the player.
signal saw_the_player
## It has found what it was looking for, and is holding it out.
signal gift_offered
## Worn out. Still blind, still searching, swimming off.
signal went_quiet(how: String)

## Long and low: this is a body the player swims the length of, not a sprite they stand next
## to. The arena is 900 wide, so it fills most of it and leaving is a real exit.
const BODY_LENGTH := 700.0
const BODY_DEPTH := 130.0
const SEGMENTS := 14

const CONE_LENGTH := 460.0
const CONE_HALF_ANGLE := 0.42
## How fast the sweep travels, and how far either side of straight ahead it goes. Slow enough
## that a player can read it and time a run, which is the whole of the stealth resolution.
const SWEEP_SPEED := 0.55
const SWEEP_LIMIT := 1.05

## Three good hits. The design asks that the fight be survivable without combat skill: this is
## a story game and a player who picks Protector for character reasons should not be walled by
## execution.
const HITS_TO_SUBDUE := 3
## What each drawn weapon is worth against it. Present so the five differ in more than reach,
## which the design asks for outright -- "or drawing anything becomes drawing the best one".
const BITE := {
	"cannon": 1.0, "anvil": 1.0, "axe": 0.8, "sword": 0.8, "boomerang": 0.6,
}

@export var treasure_offset := Vector2(-260.0, 220.0)

var _state: int = State.SEARCHING
var _sweep := 0.0
var _sweep_direction := 1.0
var _thrash := 0.0
var _hits := 0.0
var _follow_target := Vector2.ZERO
var _coils: StaticBody2D
var _hurtbox: Area2D


func _ready() -> void:
	z_index = 4
	_build_bodies()
	set_process(true)


func _build_bodies() -> void:
	# THE CHANNEL. "It moves aside and you can continue" is this body being switched off.
	_coils = StaticBody2D.new()
	_coils.name = "Coils"
	var block := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	# Tall enough to seal the whole column. At 1100 it left a gap at the waterline and the
	# channel could be swum over the top of, which is a barrier that is not one.
	box.size = Vector2(160.0, 1200.0)
	block.shape = box
	block.position = Vector2(BODY_LENGTH * 0.5 - 40.0, 0.0)
	_coils.add_child(block)
	add_child(_coils)

	# ⚠ collision_layer 1, AND AN AREA. UtilityObject._reachable_targets runs a shape query
	# with collide_with_areas and mask 1, then walks up the parent chain looking for something
	# with apply_tool_hit. On any other layer every drawn weapon swings straight through it.
	_hurtbox = Area2D.new()
	_hurtbox.name = "Hurtbox"
	_hurtbox.collision_layer = 1
	_hurtbox.collision_mask = 0
	_hurtbox.monitoring = false
	var hit := CollisionShape2D.new()
	var capsule := RectangleShape2D.new()
	capsule.size = Vector2(BODY_LENGTH, BODY_DEPTH * 1.4)
	hit.shape = capsule
	_hurtbox.add_child(hit)
	add_child(_hurtbox)


# --- What the level tells it -----------------------------------------------------------

## ⚠ ONE CREATURE, TWO STAGINGS, and the design calls this the most expensive single item in
## the level. From the boat it is mostly surface and silhouette; from underwater the player is
## inside its space. Same encounter, same three resolutions, same sweep -- what differs is
## where in the water column it is, and therefore what the player is looking at.
##
## Moved rather than duplicated. A second creature at the surface would be a second set of
## states to keep in step with this one, and they would drift.
func stage_at(depth_y: float) -> void:
	global_position.y = depth_y
	queue_redraw()


func begin_search() -> void:
	_state = State.SEARCHING
	_set_channel_open(false)
	queue_redraw()


## The Pragmatist resolution. It is still searching and still dangerous -- what changes is
## that there is now a way past, if the player stays out of the sweep.
func open_a_gap() -> void:
	_state = State.SEARCHING
	_set_channel_open(true)
	queue_redraw()


## The Artist resolution. Something is throwing light and it goes to it.
func follow_the_light(point: Vector2) -> void:
	if _state == State.SUBDUED or _state == State.CALM:
		return
	_state = State.FOLLOWING
	_follow_target = point
	queue_redraw()


func enter_fight() -> void:
	if _state == State.SUBDUED:
		return
	_state = State.FIGHTING
	_hits = 0.0
	_set_channel_open(false)
	queue_redraw()


func state() -> int:
	return _state


func hits_taken() -> float:
	return _hits


func treasure_point() -> Vector2:
	return global_position + treasure_offset


func _set_channel_open(open: bool) -> void:
	if _coils != null:
		_coils.process_mode = Node.PROCESS_MODE_DISABLED if open else Node.PROCESS_MODE_INHERIT
		for child in _coils.get_children():
			if child is CollisionShape2D:
				(child as CollisionShape2D).set_deferred(&"disabled", open)


# --- The stealth rule, as a query rather than a light ------------------------------------

## Is that point in the sweep? `lit` is the design's own nice interaction: a player who drew a
## flashlight and then chose to sneak has made the encounter harder for themselves, and the
## design says to allow that rather than prevent it.
func sees(point: Vector2, lit: bool = false) -> bool:
	if _state == State.SUBDUED or _state == State.CALM:
		return false
	var offset := point - global_position
	if lit and offset.length() < CONE_LENGTH * 1.6:
		return true
	if offset.length() > CONE_LENGTH:
		return false
	for facing in [_sweep, _sweep + PI]:
		var heading := Vector2(cos(facing), sin(facing))
		# ⚠ absf. Vector2.angle_to is SIGNED, so an unsigned test is true for every point on
		# one side of the heading and for the whole of the aft cone -- which made the sweep
		# see everything, everywhere, including straight down where the design says the way
		# past is. A stealth rule that is always true reads in a report as a stealth rule
		# that works.
		if absf(heading.angle_to(offset.normalized())) < CONE_HALF_ANGLE:
			return true
	return false


# --- The fight ----------------------------------------------------------------------------

## The Destructible2D contract, so every drawn weapon works without this file knowing what a
## sword is. It bites ONLY while fighting: hitting a creature that is searching for something
## it lost, before the player has said they mean to, is not a route -- it is an accident the
## game should not let them have.
func apply_tool_hit(tool: String, _impulse: float, _actor: Node2D) -> bool:
	if _state != State.FIGHTING or not BITE.has(tool):
		return false
	_hits += float(BITE[tool])
	_thrash = 0.5
	queue_redraw()
	if _hits >= float(HITS_TO_SUBDUE):
		_subdue()
	return true


func accepts_tool(tool: String) -> bool:
	return _state == State.FIGHTING and BITE.has(tool)


func _subdue() -> void:
	# ⚠ SUBDUED, NEVER KILLED. It swims off still blind and still searching, and that is the
	# cost of this route: the player won, and nothing was healed. Killing it would have hidden
	# exactly that.
	_state = State.SUBDUED
	_set_channel_open(true)
	queue_redraw()
	went_quiet.emit("FOUGHT")


## The Artist ending. It found what it lost and is holding it out.
func give_it_up() -> void:
	_state = State.CALM
	_set_channel_open(true)
	queue_redraw()
	gift_offered.emit()


# --- Per frame -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_thrash = maxf(0.0, _thrash - delta)
	match _state:
		State.SEARCHING, State.FIGHTING:
			_sweep += SWEEP_SPEED * _sweep_direction * delta
			if absf(_sweep) > SWEEP_LIMIT:
				_sweep = clampf(_sweep, -SWEEP_LIMIT, SWEEP_LIMIT)
				_sweep_direction = -_sweep_direction
		State.FOLLOWING:
			var to_light := _follow_target - global_position
			_sweep = lerp_angle(_sweep, to_light.angle(), minf(1.0, delta * 2.0))
			if to_light.length() > 24.0:
				global_position += to_light.normalized() * 120.0 * delta
			else:
				# It got there. Announcing this itself keeps the level from having to poll a
				# distance every frame to find out whether a creature has arrived.
				give_it_up()
		State.CALM, State.SUBDUED:
			_sweep = lerp_angle(_sweep, 0.0, minf(1.0, delta * 1.2))
	queue_redraw()


func _draw() -> void:
	var tone := Color(0.16, 0.24, 0.32, 1.0)
	var belly := Color(0.34, 0.46, 0.44, 1.0)
	match _state:
		State.CALM:
			tone = Color(0.22, 0.34, 0.40, 1.0)
		State.SUBDUED:
			tone = Color(0.14, 0.18, 0.22, 1.0)
		State.FIGHTING:
			tone = Color(0.24, 0.18, 0.20, 1.0)
	if _thrash > 0.0:
		tone = tone.lightened(0.35)

	# THE SWEEP FIRST, UNDER THE BODY. It is drawn because it is the rule -- a stealth section
	# whose boundary is invisible is a boundary the player learns by being reset.
	if _state == State.SEARCHING or _state == State.FIGHTING:
		for facing in [_sweep, _sweep + PI]:
			var points := PackedVector2Array([Vector2.ZERO])
			for step in range(9):
				var angle: float = facing - CONE_HALF_ANGLE \
					+ CONE_HALF_ANGLE * 2.0 * (float(step) / 8.0)
				points.append(Vector2(cos(angle), sin(angle)) * CONE_LENGTH)
			draw_colored_polygon(points, Color(0.85, 0.92, 0.70, 0.16))

	# A long body, thrown into a travelling wave. Frantic while it is searching, slack once
	# it is not.
	var amplitude := 44.0 if _state == State.SEARCHING or _state == State.FIGHTING else 14.0
	var phase := float(Time.get_ticks_msec()) * 0.0022
	var spine := PackedVector2Array()
	for index in range(SEGMENTS + 1):
		var along := float(index) / float(SEGMENTS)
		var x := lerpf(-BODY_LENGTH * 0.5, BODY_LENGTH * 0.5, along)
		var y := sin(phase + along * 5.2) * amplitude * (0.35 + along * 0.65)
		spine.append(Vector2(x, y))
	for index in range(SEGMENTS):
		var here := spine[index]
		var next := spine[index + 1]
		var thickness := BODY_DEPTH * (0.35 + 0.65 * sin(PI * float(index) / float(SEGMENTS)))
		draw_line(here, next, tone, thickness)
		draw_line(here + Vector2(0.0, thickness * 0.22),
			next + Vector2(0.0, thickness * 0.22), belly, thickness * 0.28)
	# The eyes, which are the point of the whole encounter and are never explained.
	var head := spine[SEGMENTS]
	var eye := Color(0.88, 0.84, 0.52, 0.85) if _state != State.SUBDUED \
		else Color(0.5, 0.5, 0.48, 0.5)
	draw_circle(head + Vector2(-18.0, -16.0), 11.0, eye)
	draw_circle(head + Vector2(-18.0, 14.0), 11.0, eye)
