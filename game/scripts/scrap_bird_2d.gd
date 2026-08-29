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

## What a bird looks like at this scale, which is not much: a body, two wings and the piece
## of painting in its beak. The scrap is the important half -- five identical birds are five
## birds, but five birds each carrying something the player wants is Problem 2.
const BODY := Color(0.196, 0.192, 0.204, 1.0)      # 323134
const BODY_LIT := Color(0.318, 0.310, 0.333, 1.0)  # 514F55
const WING := Color(0.259, 0.251, 0.271, 1.0)      # 424045
const BEAK := Color(0.898, 0.667, 0.263, 1.0)      # E5AA43
const EYE := Color(0.937, 0.925, 0.882, 1.0)       # EFECE1
## The scrap in the beak. Canvas, with a little of the picture on it, so it reads as a piece
## of a painting rather than as a white card.
const SCRAP := Color(0.878, 0.827, 0.729, 1.0)     # E0D3BA
const SCRAP_EDGE := Color(0.678, 0.616, 0.502, 1.0)# AD9D80
const SCRAP_INK := Color(0.404, 0.475, 0.522, 1.0) # 677985
## Where a downed one is left, and what tells the player it is worth walking to.
const DOWNED := Color(0.298, 0.290, 0.310, 1.0)    # 4C4A4F

var _state: int = State.CIRCLING
var _home := Vector2.ZERO
var _phase := 0.0
var _pressure := 0.0


func _ready() -> void:
	add_to_group(&"scrap_birds")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_home = position
	# Spread them out so five birds are a flock rather than a stack.
	_phase = randf() * TAU
	queue_redraw()


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
	queue_redraw()


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
	queue_redraw()
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
	queue_redraw()
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


## ⚠ THESE HAD NO `_draw` AT ALL, and nothing anywhere said so. Five birds carrying five of
## the seven pieces of the painting, orbiting on a real physics process, invisible -- and
## every headless check passed, because the ledger, the ids, the three verbs and the reach
## are all true of an object nobody can see. Caught by looking at a frame, which is the
## fourth time in this project that has been the only way.
func _draw() -> void:
	if _state == State.GONE:
		return
	if _state == State.CALMED or _state == State.DOWNED:
		_draw_settled()
		return
	# The wingbeat is driven by the orbit rather than by its own clock, so a bird at the top
	# of its circle is on the same beat it was the last time round.
	var flap := sin(_phase * 3.0) * 9.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8.0, -2.0), Vector2(-26.0, -2.0 - flap), Vector2(-9.0, 6.0)]), WING)
	draw_colored_polygon(PackedVector2Array([
		Vector2(8.0, -2.0), Vector2(26.0, -2.0 + flap), Vector2(9.0, 6.0)]), WING)
	# Body, and a tail so it has a direction.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11.0, -6.0), Vector2(9.0, -7.0), Vector2(13.0, 0.0),
		Vector2(7.0, 7.0), Vector2(-11.0, 6.0), Vector2(-19.0, 2.0)]), BODY)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4.0, -6.0), Vector2(9.0, -7.0), Vector2(11.0, -2.0),
		Vector2(-4.0, -1.0)]), BODY_LIT)
	draw_circle(Vector2(8.0, -3.0), 2.0, EYE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(12.0, -2.0), Vector2(21.0, 1.0), Vector2(12.0, 3.0)]), BEAK)
	_draw_scrap(Vector2(20.0, 6.0))


## Set down where it landed, with the scrap beside it rather than in its beak -- the piece
## is what the player walks over, so it has to be the thing on the ground.
func _draw_settled() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14.0, 0.0), Vector2(10.0, -4.0), Vector2(14.0, 2.0),
		Vector2(-12.0, 4.0)]), DOWNED)
	_draw_scrap(Vector2(22.0, -2.0))


func _draw_scrap(at: Vector2) -> void:
	var rect := Rect2(at + Vector2(-13.0, -8.0), Vector2(26.0, 30.0))
	draw_rect(rect.grow(1.5), SCRAP_EDGE)
	draw_rect(rect, SCRAP)
	draw_rect(Rect2(rect.position + Vector2(3.0, 15.0), Vector2(20.0, 7.0)), SCRAP_INK)
	draw_rect(Rect2(rect.position + Vector2(3.0, 5.0), Vector2(9.0, 6.0)), SCRAP_INK)
