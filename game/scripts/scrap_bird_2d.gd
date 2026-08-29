class_name ScrapBird2D
extends Node2D
## One of the five in Alley 1, each carrying one piece of the painting.
##
## THE DESIGN'S PROMISE IS PER-BIRD, NOT PASS/FAIL. Down three of five and you walk into
## Alley 2 with two waiting, tangled in the bandaritas. Nothing is ever lost, only deferred
## -- which is what keeps a timed route from feeling punitive, because the timer running out
## costs a walk rather than a scrap.
##
## So each bird is INDIVIDUALLY ADDRESSABLE and owns exactly one scrap. The five do not need
## to look different; they need to be five things, not a number.
##
## THREE ROUTES REACH THEM AND THEY ARE THREE DIFFERENT VERBS:
##   * calmed  -- it comes down, eats, and gives up its scrap where the player can reach it.
##   * startled -- it leaves for Alley 2 carrying the scrap. Deferred, not lost.
##   * struck  -- it is knocked down and drops the scrap where it fell.
## A bird that has already answered one of them answers none of the others: the routes are
## alternatives, and a bird that could be fed AND downed would let one player take a scrap
## twice while the ledger counted it once.

signal scrap_dropped(scrap_id: String, at: Vector2)
signal flew_off(scrap_id: String)
signal settled(scrap_id: String)

enum State { CIRCLING, CALMED, DOWNED, GONE }

## Which piece of the painting this one has. Set by the alley when it spawns the five.
@export var scrap_id: String = ""
## The circle it flies, in world units, around wherever it was placed.
@export var orbit := Vector2(120.0, 46.0)
@export var orbit_seconds := 4.0
## How high it rides as the timer runs down. The design asks for the pressure to be
## READABLE IN THE FICTION -- the birds circling higher, the light changing -- rather than
## shown as a bare countdown, so climbing is the clock.
@export var climb_when_pressed := 90.0

var _state: int = State.CIRCLING
var _home := Vector2.ZERO
var _phase := 0.0
var _pressure := 0.0


func _ready() -> void:
	_home = position
	# Spread them out so five birds are a flock rather than a stack.
	_phase = randf() * TAU


func state() -> int:
	return _state


func is_answered() -> bool:
	return _state != State.CIRCLING


func _physics_process(delta: float) -> void:
	if _state != State.CIRCLING:
		return
	_phase += delta * TAU / maxf(0.001, orbit_seconds)
	position = _home \
		+ Vector2(cos(_phase) * orbit.x, sin(_phase) * orbit.y) \
		- Vector2(0.0, _pressure * climb_when_pressed)


## 0 at the start of the timed route, 1 as it runs out. Nothing else reads the clock: the
## bird's height IS the readout.
func set_pressure(ratio: float) -> void:
	_pressure = clampf(ratio, 0.0, 1.0)


# --- The three verbs -----------------------------------------------------------------

## Fed. It comes down willingly and leaves the scrap behind it.
func calm() -> bool:
	if is_answered():
		return false
	_state = State.CALMED
	set_physics_process(false)
	scrap_dropped.emit(scrap_id, global_position)
	settled.emit(scrap_id)
	return true


## Startled. It goes on ahead to Alley 2 and takes the scrap with it -- which is a DEFERRAL
## and the ledger is told so, not a loss.
func startle() -> bool:
	if is_answered():
		return false
	_state = State.GONE
	set_physics_process(false)
	visible = false
	flew_off.emit(scrap_id)
	return true


## Hit. The design's own wording is "downed", and what it drops is recoverable where it
## lands rather than on the bird.
func strike_down() -> bool:
	if is_answered():
		return false
	_state = State.DOWNED
	set_physics_process(false)
	scrap_dropped.emit(scrap_id, global_position)
	return true


## THE HIT PROTOCOL THIS PROJECT ALREADY HAS. Destructible2D answers the same call, so the
## boomerang and the cannon reach these without either of them learning what a bird is.
## Returns whether the hit did anything, which is what the tool reports to the player.
func apply_tool_hit(_tool: String, _impulse: float, _actor: Node2D) -> bool:
	return strike_down()


## When the timer expires, everything still up there leaves. One call so the alley does not
## have to know which of the five are still circling.
func timer_expired() -> bool:
	if _state != State.CIRCLING:
		return false
	return startle()
