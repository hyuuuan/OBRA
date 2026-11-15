class_name BawangWard2D
extends Node2D
## Bawang crushed where she stands: for a while, nothing that hunts by smell will cross into it.
##
## Kent's design: "Defensive, not damaging. Best use is buying room to draw." It hurts nothing; an
## aswang that hunts by smell (Enemy2D.hunts_by_smell) is held at its edge instead -- see
## Enemy2D._keep_out_of_wards. Shown as a ring round where it was crushed and a few motes, fading in
## its last seconds, then gone.
##
## ⚠ THE RING IS OVER THE DARK, AND IT IS THE CLOCK. Lit only by her lamp, a faint arc at 150 px fell
## outside the light as soon as the lamp was low, which is when she crushes it: she could not see
## where it held, or that it was about to stop. It stands on its own layer now, closing as the ward
## runs out, so where it is and how long it has left are the same mark.

const FADE_SECONDS := 1.5
const RING := Color(0.86, 0.8, 0.95, 0.35)
const RING_OVER := Color(UISkin.CLIMB_LIT, 0.85)
const RING_WIDTH := 3.0

@export var radius := 150.0
@export var seconds := 10.0

var _left := 0.0
var _clock := 0.0
var _ring: Node2D


func _ready() -> void:
	add_to_group(Enemy2D.WARDS)
	_left = seconds
	z_index = 3
	var layer := CanvasLayer.new()
	layer.layer = DarknessLayer.LAYER + 1
	layer.follow_viewport_enabled = true
	add_child(layer)
	_ring = Node2D.new()
	layer.add_child(_ring)
	_ring.draw.connect(_draw_ring)


func _process(delta: float) -> void:
	_clock += delta
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	queue_redraw()
	_ring.position = global_position.round()
	_ring.queue_redraw()


## How far it holds them off. Nothing once it is spent.
func reach() -> float:
	return radius if _left > 0.0 else 0.0


func seconds_left() -> float:
	return maxf(0.0, _left)


## How much of the ring still stands, 1 when crushed and closing to nothing as it runs out.
func ring_share() -> float:
	return clampf(_left / seconds, 0.0, 1.0)


## The layer the ring is on, for a probe: over the dark, or she cannot see it when she needs it.
func ring_layer() -> int:
	return (_ring.get_parent() as CanvasLayer).layer


func _draw_ring() -> void:
	var fade := clampf(_left / FADE_SECONDS, 0.0, 1.0)
	_ring.draw_arc(Vector2.ZERO, radius, PI, PI + PI * ring_share(), 48,
		Color(RING_OVER, RING_OVER.a * fade), RING_WIDTH, false)


## PLACEHOLDER until it has art: a few motes rising from it.
func _draw() -> void:
	var fade := clampf(_left / FADE_SECONDS, 0.0, 1.0)
	var colour := Color(RING, RING.a * fade)
	for index in range(6):
		var x := (float(index) / 5.0 - 0.5) * radius * 1.4
		var y := -fmod(_clock * 18.0 + index * 23.0, 60.0)
		draw_circle(Vector2(x, y), 2.0, Color(colour, colour.a * (1.0 + y / 60.0)))
