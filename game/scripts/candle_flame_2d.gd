class_name CandleFlame2D
extends Node2D
## A kandila set down and lit: a light that costs no ink, burning down where she left it.
##
## Kent's design: "Portable light that costs no ink. Burns down over time ... the thing a player
## hoards for the final clearing." A light in LightField like every other -- the dark is cut by it,
## and anything that asks how lit a place is gets the same answer the picture gives. Its light
## shrinks a little as it burns down, and in its last seconds it gutters.

const GUTTER_SECONDS := 4.0
const SHRINK_TO := 0.75
const FLICKER_HZ := 9.0

@export var radius := 220.0
@export var seconds := 45.0

var _left := 0.0
var _clock := 0.0


func _ready() -> void:
	add_to_group(LightField.GROUP)
	_left = seconds
	z_index = 4


func _process(delta: float) -> void:
	_clock += delta
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	queue_redraw()


func seconds_left() -> float:
	return maxf(0.0, _left)


## Its light now: full when lit, three quarters by the end, guttering in its last seconds.
func light_radius() -> float:
	var burnt := 1.0 - clampf(_left / seconds, 0.0, 1.0)
	var r := radius * lerpf(1.0, SHRINK_TO, burnt)
	if _left < GUTTER_SECONDS:
		r *= 0.85 + 0.15 * absf(sin(_clock * TAU * FLICKER_HZ * 0.5))
	return r


func light_hole() -> Dictionary:
	if _left <= 0.0:
		return {}
	return {"position": global_position + Vector2(0.0, -18.0), "radius": light_radius(), "strength": 1.0}


## PLACEHOLDER until it has art: a stub of wax and its flame.
func _draw() -> void:
	var height := lerpf(16.0, 6.0, 1.0 - clampf(_left / seconds, 0.0, 1.0))
	draw_rect(Rect2(-3.0, -height, 6.0, height), Color(0.92, 0.85, 0.69))
	var sway := sin(_clock * TAU * 1.3) * 1.2
	draw_circle(Vector2(sway, -height - 5.0), 5.0, Color(1.0, 0.62, 0.2, 0.45))
	draw_circle(Vector2(sway, -height - 5.0), 2.5, Color(1.0, 0.94, 0.75))
