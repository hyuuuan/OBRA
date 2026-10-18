class_name BawangWard2D
extends Node2D
## Bawang crushed where she stands: for a while, nothing that hunts by smell will cross into it.
##
## Kent's design: "Defensive, not damaging. Best use is buying room to draw." It hurts nothing; an
## aswang that hunts by smell (Enemy2D.hunts_by_smell) is held at its edge instead -- see
## Enemy2D._keep_out_of_wards. Shown as a faint ring on the ground and a few motes, fading in its
## last seconds, then gone.

const FADE_SECONDS := 1.5
const RING := Color(0.86, 0.8, 0.95, 0.35)

@export var radius := 150.0
@export var seconds := 10.0

var _left := 0.0
var _clock := 0.0


func _ready() -> void:
	add_to_group(Enemy2D.WARDS)
	_left = seconds
	z_index = 3


func _process(delta: float) -> void:
	_clock += delta
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	queue_redraw()


## How far it holds them off. Nothing once it is spent.
func reach() -> float:
	return radius if _left > 0.0 else 0.0


func seconds_left() -> float:
	return maxf(0.0, _left)


## PLACEHOLDER until it has art: a pale ring on the ground and a few motes rising from it.
func _draw() -> void:
	var fade := clampf(_left / FADE_SECONDS, 0.0, 1.0)
	var colour := Color(RING, RING.a * fade)
	draw_arc(Vector2.ZERO, radius, PI, TAU, 48, colour, 2.0, true)
	for index in range(6):
		var x := (float(index) / 5.0 - 0.5) * radius * 1.4
		var y := -fmod(_clock * 18.0 + index * 23.0, 60.0)
		draw_circle(Vector2(x, y), 2.0, Color(colour, colour.a * (1.0 + y / 60.0)))
