class_name RuinedBridge2D
extends Node2D
## What is left of the hanging bridge Lola painted (Game Design, Level 1): two anchor
## posts and the frayed rope still tied to them. Scenery with no collision — the point
## of it is that it does NOT hold anyone up.
##
## It reads left-to-right as a sentence: a post, rope going out, rope stopping in
## mid-air. That is the question the dialogue node then asks out loud.

@export var span: float = 560.0
@export var post_height: float = 96.0
## How far the surviving rope reaches out over the drop before it gives out.
@export var frayed_reach: float = 0.22

const ROPE := Color(0.55, 0.42, 0.26)
const WOOD := Color(0.34, 0.25, 0.17)
const DARK := Color(0.14, 0.1, 0.07)


func _draw() -> void:
	for side: float in [0.0, 1.0]:
		var lean: float = 0.16 if side == 0.0 else -0.2
		_draw_post(Vector2(span * side, 0.0), lean)
	# Rope from each post, sagging out over the gorge and simply ending.
	_draw_frayed_rope(Vector2(6.0, -post_height + 14.0), span * frayed_reach, 1.0)
	_draw_frayed_rope(Vector2(span - 6.0, -post_height + 8.0), span * frayed_reach * 0.72, -1.0)
	# A couple of surviving planks still hanging off the near rope.
	for offset: float in [0.34, 0.62]:
		var at := Vector2(span * frayed_reach * offset + 6.0,
			-post_height + 14.0 + 46.0 * offset * offset)
		draw_line(at, at + Vector2(0.0, 16.0), ROPE, 2.5)
		draw_rect(Rect2(at + Vector2(-13.0, 16.0), Vector2(26.0, 7.0)), WOOD)


func _draw_post(base: Vector2, lean: float) -> void:
	var top := base + Vector2(sin(lean) * post_height, -cos(lean) * post_height)
	draw_line(base, top, WOOD, 13.0, true)
	draw_line(base, top, DARK, 3.0, true)
	# A brace, because a post standing on nothing looks like a mistake.
	draw_line(base + Vector2(-26.0, -4.0), top + Vector2(-4.0, 26.0), WOOD, 7.0, true)
	draw_line(top + Vector2(-9.0, 6.0), top + Vector2(9.0, 6.0), ROPE, 4.0, true)


func _draw_frayed_rope(from: Vector2, reach: float, direction: float) -> void:
	var points := PackedVector2Array()
	var steps := 14
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		# A catenary that never gets anywhere: it sags away and stops.
		points.append(from + Vector2(direction * reach * t, 74.0 * t * t))
	draw_polyline(points, ROPE, 4.0, true)
	# Frayed ends, three loose threads going nowhere.
	var tip: Vector2 = points[points.size() - 1]
	for spread: float in [-0.5, 0.05, 0.6]:
		draw_line(tip, tip + Vector2(direction * 13.0, 12.0).rotated(spread), ROPE, 2.0, true)
