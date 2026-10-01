class_name StoneThrow2D
extends Node2D
## The alleys' Protector route: something to throw, an aim you can see, and a flight that goes
## where the aim said.
##
## Kent: "throw a rock (this includes a projectile trajectory in the game)", and the design's own
## words for the route are "aim to the birds (angry birds style)". So while the player holds
## something to throw, a dotted arc runs from their hand toward the pointer -- the same arc the
## throw will fly, worked out by the same step, so what is shown is what happens. Further from
## the hand is a harder throw. A click or the use key lets go.
##
## WHAT IS THROWN IS DRAWN. There is no stone class; a round shape is recognised as a circle,
## and in an alley on this route a circle is a stone. A drawn boomerang or cannon throws the same
## way. (Stones lying in the alley were considered and rejected: with the dance at Problem 1 they
## would let Piyesta be finished without drawing anything, which is the one thing T1 forbids.)
##
## A MISS COSTS NOTHING BUT THE WALK. A thrown stone lands and lies where it landed; walking over
## it picks it up again. A boomerang comes back to the hand. A cannon keeps its shot. Nothing
## flies off for good, so nothing here can strand the player without a throw.
##
## ONE THROWER PER ALLEY, and it does not decide what is in the player's hand -- the level does,
## every frame, through `hold`. It owns the stone, the flights and the aim.

signal thrown(kind: int)
signal hit(bird: Node2D)

enum Kind { NONE, STONE, BOOMERANG, CANNON }

## What each drawing that can be thrown is thrown AS. The route's answers are exactly these --
## `strike`, less the blades and the anvil, which swing or drop rather than leave the hand --
## and `run_level2_audit` holds the level data to this table, so a class the route accepts and
## this cannot throw fails there rather than in somebody's hands.
const THROWN := {"circle": Kind.STONE, "boomerang": Kind.BOOMERANG, "cannon": Kind.CANNON}

const GRAVITY := 900.0
## The weakest and the strongest throw, in px/s.
const MIN_SPEED := 320.0
const MAX_SPEED := 800.0
## How far the pointer has to be from the hand for a full-strength throw.
const FULL_DRAW := 380.0
## How far ahead the arc is drawn, and how often a dot is placed on it.
const PREVIEW_SECONDS := 1.25
const STEP := 1.0 / 60.0
const DOT_EVERY := 3
const STONE_RADIUS := 7.0
## Walking this close to a stone on the floor picks it back up.
const PICKUP_REACH := 44.0
## How long a boomerang takes to come back to the hand once its flight is over.
const RETURN_SECONDS := 0.6
## How fast a stone rolls back in off a doorway.
const ROLL_SPEED := 360.0
## Where the apo holds a thing, above their feet: `wanderer.gd` puts its grip 48px up.
const HAND_HEIGHT := 48.0

const ROCK := Color(0.494, 0.478, 0.451, 1.0)      # 7E7A73
const ROCK_LIT := Color(0.678, 0.663, 0.627, 1.0)  # ADA9A0
const ROCK_DARK := Color(0.286, 0.275, 0.259, 1.0) # 494642
const WOOD := Color(0.573, 0.392, 0.212, 1.0)      # 926436
const WOOD_DARK := Color(0.365, 0.231, 0.110, 1.0) # 5D3B1C
const IRON := Color(0.169, 0.169, 0.184, 1.0)      # 2B2B2F
const IRON_LIT := Color(0.380, 0.380, 0.408, 1.0)  # 616168
const AIM := Color(1.0, 0.973, 0.878, 0.95)
const AIM_EDGE := Color(0.106, 0.086, 0.075, 0.55)

## What the next throw is. Set by the level every frame through `hold`.
var kind: int = Kind.NONE
## The throwing hand, asked every frame: a Callable returning a global point, INF if none.
var hand := Callable()
## What can be hit: a Callable returning an Array of nodes answering `hit_test(point, radius)`
## and `strike_down()` -- the flock of this alley.
var targets := Callable()
## The floor (global y) a thrown thing lands on, and the walls (global x) it stops at.
var floor_y := 0.0
var walls := Vector2(-INF, INF)
## Where a stone may come to REST (global x): the floor between the alley's doorways. One that
## lands outside it rolls back in. ⚠ NEVER IN A DOORWAY -- walking in to pick it up would walk
## the apo out of the alley, and the stone is the only thing they have to throw.
var rest_span := Vector2(-INF, INF)
## Whether the aim follows the pointer. A test turns it off and aims with `aim_at`, because a
## headless pointer sits wherever the window left it.
var follow_mouse := true

## One stone per alley, and where it is: in the hand, in the air, or on the floor.
var _has_stone := false
var _stone_in_hand := false
var _resting := Vector2.INF
var _flights: Array[Dictionary] = []
## The world point being aimed at. INF until something has aimed.
var _pointer := Vector2.INF


## How high the hardest throw goes above the floor the thrower stands on: the hand, and then
## v^2 / 2g straight up. Static so an audit can ask without a level.
static func reach() -> float:
	return HAND_HEIGHT + MAX_SPEED * MAX_SPEED / (2.0 * GRAVITY)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# OVER THE APO, not under: the stone is held in front of the figure and the arc starts at
	# the hand. At the room's own depth (-10, under the figure's 10) both would be drawn behind
	# the body that throws them.
	z_as_relative = false
	z_index = 20


## A stone has been drawn: it is in the hand. There is only ever one -- a second drawing
## replaces the first rather than putting two in play.
func give_stone() -> void:
	_has_stone = true
	_stone_in_hand = true
	_resting = Vector2.INF
	var kept: Array[Dictionary] = []
	for flight in _flights:
		if int(flight["kind"]) != Kind.STONE:
			kept.append(flight)
	_flights = kept
	queue_redraw()


func has_stone() -> bool:
	return _has_stone


## What is in the hand to throw now. A stone is only held if one was drawn.
func hold(new_kind: int) -> void:
	if new_kind == Kind.STONE and not _has_stone:
		new_kind = Kind.NONE
	kind = new_kind


## Nothing to throw any more: the flock is down, or a restore has put the alley back.
func clear() -> void:
	kind = Kind.NONE
	_has_stone = false
	_stone_in_hand = false
	_resting = Vector2.INF
	_flights.clear()
	queue_redraw()


func ready_to_throw() -> bool:
	if not _hand_point().is_finite():
		return false
	match kind:
		Kind.STONE:
			return _stone_in_hand
		Kind.BOOMERANG, Kind.CANNON:
			return not in_flight(kind)
	return false


func stone_in_hand() -> bool:
	return _has_stone and _stone_in_hand


## Whether a stone is lying on the floor to be picked up, and where.
func stone_on_the_floor() -> bool:
	return _has_stone and _resting.is_finite()


func resting_stone() -> Vector2:
	return _resting


## Whether something of `of_kind` is in the air -- anything at all, for NONE.
func in_flight(of_kind: int = Kind.NONE) -> bool:
	for flight in _flights:
		if of_kind == Kind.NONE or int(flight["kind"]) == of_kind:
			return true
	return false


## Aim at a point in the world: the direction from the hand, and the strength from how far.
func aim_at(point: Vector2) -> void:
	_pointer = point
	queue_redraw()


func aimed_at() -> Vector2:
	return _pointer


## The velocity a throw toward `point` leaves the hand with.
func velocity_for(point: Vector2) -> Vector2:
	var from := _hand_point()
	if not from.is_finite() or not point.is_finite():
		return Vector2.ZERO
	var toward := point - from
	if toward.length() < 1.0:
		toward = Vector2(1.0, -1.0)
	var strength := clampf(toward.length() / FULL_DRAW, 0.0, 1.0)
	return toward.normalized() * lerpf(MIN_SPEED, MAX_SPEED, strength)


## The velocity the next throw would leave with. Up and forward when nothing has aimed yet.
func current_velocity() -> Vector2:
	if _pointer.is_finite():
		return velocity_for(_pointer)
	var from := _hand_point()
	return velocity_for(from + Vector2(200.0, -200.0)) if from.is_finite() else Vector2.ZERO


## Where a throw at `velocity` goes, step by step, until it lands or hits a wall. The arc on
## screen and the flight in the air both come from this, so they cannot disagree.
func trajectory(velocity: Vector2, seconds: float = PREVIEW_SECONDS) -> PackedVector2Array:
	var out := PackedVector2Array()
	var at := _hand_point()
	if not at.is_finite():
		return out
	var moving := velocity
	var t := 0.0
	while t < seconds:
		out.append(at)
		moving.y += GRAVITY * STEP
		at += moving * STEP
		t += STEP
		if at.y >= floor_y - STONE_RADIUS or at.x <= walls.x or at.x >= walls.y:
			out.append(at)
			break
	return out


## Let go, along the current aim. False when there is nothing to throw.
func throw() -> bool:
	if not ready_to_throw():
		return false
	_flights.append({"at": _hand_point(), "v": current_velocity(), "kind": kind, "t": 0.0,
		"live": true, "back": false})
	if kind == Kind.STONE:
		_stone_in_hand = false
	thrown.emit(kind)
	queue_redraw()
	return true


func _hand_point() -> Vector2:
	if not hand.is_valid():
		return Vector2.INF
	var at: Variant = hand.call()
	return at as Vector2 if at is Vector2 else Vector2.INF


func _process(_delta: float) -> void:
	if follow_mouse and kind != Kind.NONE:
		_pointer = get_global_mouse_position()
	queue_redraw()


## THE FLIGHTS ARE STEPPED WITH THE STEP THE ARC IS DRAWN WITH, so the dots and the flight are
## one calculation. At the project's sixty ticks that is the physics step anyway; if the tick
## rate is ever changed, the throw still goes where the dots said.
func _physics_process(_delta: float) -> void:
	if not _flights.is_empty():
		var still: Array[Dictionary] = []
		for flight in _flights:
			_fly(flight, STEP)
			if not flight.has("done"):
				still.append(flight)
		_flights = still
	# Rolling back in off a doorway, if it came to rest in one.
	if _resting.is_finite():
		_resting.x = move_toward(_resting.x, clampf(_resting.x, rest_span.x, rest_span.y),
			ROLL_SPEED * STEP)
	# Walking over a stone on the floor picks it back up, whatever is in the hand just then.
	if _has_stone and not _stone_in_hand and _resting.is_finite():
		var from := _hand_point()
		if from.is_finite() and absf(from.x - _resting.x) <= PICKUP_REACH \
				and absf(from.y - _resting.y) <= HAND_HEIGHT + 60.0:
			_resting = Vector2.INF
			_stone_in_hand = true


func _fly(flight: Dictionary, delta: float) -> void:
	flight["t"] = float(flight["t"]) + delta
	if bool(flight["back"]):
		# A boomerang on its way home. Straight to the hand, fast, and then it is in it.
		var home := _hand_point()
		var here: Vector2 = flight["at"]
		if not home.is_finite() or here.distance_to(home) < 16.0:
			flight["done"] = true
			return
		flight["at"] = here.move_toward(home,
			here.distance_to(home) * delta / RETURN_SECONDS + 400.0 * delta)
		return
	var velocity: Vector2 = flight["v"]
	velocity.y += GRAVITY * delta
	var at: Vector2 = flight["at"] + velocity * delta
	flight["v"] = velocity
	flight["at"] = at
	if bool(flight["live"]) and targets.is_valid():
		for target: Variant in targets.call():
			var bird := target as Node2D
			if bird == null or not is_instance_valid(bird):
				continue
			if bool(bird.call("hit_test", at, STONE_RADIUS)):
				bird.call("strike_down")
				hit.emit(bird)
				# One bird per throw. It drops away off the bird rather than carrying on.
				flight["live"] = false
				flight["v"] = Vector2(velocity.x * 0.2, 60.0)
				if int(flight["kind"]) == Kind.BOOMERANG:
					flight["back"] = true
				return
	var landed := at.y >= floor_y - STONE_RADIUS
	var walled := at.x <= walls.x or at.x >= walls.y
	if not landed and not walled:
		return
	match int(flight["kind"]):
		Kind.STONE:
			if walled and not landed:
				# Off the wall and straight down.
				flight["v"] = Vector2(0.0, maxf(velocity.y, 0.0))
				flight["at"] = Vector2(clampf(at.x, walls.x + 8.0, walls.y - 8.0), at.y)
				flight["live"] = false
				return
			_resting = Vector2(clampf(at.x, walls.x + 8.0, walls.y - 8.0),
				floor_y - STONE_RADIUS)
			flight["done"] = true
		Kind.BOOMERANG:
			flight["back"] = true
			flight["live"] = false
		_:
			flight["done"] = true


func _draw() -> void:
	if ready_to_throw():
		_draw_the_aim()
	if kind == Kind.STONE and stone_in_hand():
		_draw_rock(to_local(_hand_point()), 0.0)
	if stone_on_the_floor():
		_draw_rock(to_local(_resting), 0.0)
	for flight in _flights:
		var at := to_local(flight["at"] as Vector2)
		var spin := float(flight["t"]) * 14.0
		match int(flight["kind"]):
			Kind.STONE:
				_draw_rock(at, spin)
			Kind.BOOMERANG:
				_draw_boomerang(at, spin)
			_:
				draw_circle(at, 6.0, IRON)
				draw_circle(at + Vector2(-2.0, -2.0), 2.0, IRON_LIT)


## The dotted arc. Dots rather than a line, larger near the hand and smaller as they go, the
## way this kind of aim is always drawn -- a line reads as a laser, dots read as a throw.
func _draw_the_aim() -> void:
	var path := trajectory(current_velocity())
	for index in range(0, path.size(), DOT_EVERY):
		var along := float(index) / float(maxi(1, path.size()))
		var radius := lerpf(4.0, 2.0, along)
		var at := to_local(path[index])
		draw_circle(at, radius + 1.5, AIM_EDGE)
		draw_circle(at, radius, Color(AIM.r, AIM.g, AIM.b, AIM.a * (1.0 - along * 0.6)))


func _draw_rock(at: Vector2, spin: float) -> void:
	draw_set_transform(at, spin, Vector2.ONE)
	var rock := PackedVector2Array([Vector2(-7.0, -3.0), Vector2(-3.0, -7.0), Vector2(5.0, -6.0),
		Vector2(8.0, 0.0), Vector2(4.0, 6.0), Vector2(-5.0, 6.0)])
	var closed := rock.duplicate()
	closed.append(rock[0])
	draw_colored_polygon(rock, ROCK)
	draw_colored_polygon(PackedVector2Array([Vector2(-3.0, -6.0), Vector2(4.0, -5.0),
		Vector2(2.0, -1.0), Vector2(-4.0, -1.0)]), ROCK_LIT)
	draw_polyline(closed, ROCK_DARK, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_boomerang(at: Vector2, spin: float) -> void:
	draw_set_transform(at, spin, Vector2.ONE)
	draw_line(Vector2(-10.0, 4.0), Vector2(0.0, -4.0), WOOD_DARK, 5.0)
	draw_line(Vector2(0.0, -4.0), Vector2(10.0, 4.0), WOOD_DARK, 5.0)
	draw_line(Vector2(-10.0, 4.0), Vector2(0.0, -4.0), WOOD, 3.0)
	draw_line(Vector2(0.0, -4.0), Vector2(10.0, 4.0), WOOD, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
