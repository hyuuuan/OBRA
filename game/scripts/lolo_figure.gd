extends Node2D
## Lolo, drawn in code from a handful of primitives.
##
## DELIBERATELY A PLACEHOLDER, exactly like wanderer_figure.gd: no design exists yet,
## so this is built to be thrown away whole. Replacing Lolo's look means replacing this
## file and nothing else -- lolo.gd owns where he is and what he says, not how he looks.
##
## He is a floating blob rather than a walker on purpose: a companion who hovers does
## not need a gait, cannot look wrong next to the player's own drawn animal, and keeps
## reading as "not a creature you drew".

const INK := Color(0.09, 0.11, 0.13, 1.0)
const HALO := Color(1.0, 1.0, 1.0, 0.8)
const SHELL := Color(0.99, 0.86, 0.42, 1.0)
const WIDTH := 5.0

const BODY_RADIUS := 19.0
const EYE_OFFSET := 6.5
const EYE_RADIUS := 3.1

## Advanced by lolo.gd; drives the bob and the leaf sway so the two stay in step.
@export var bob: float = 0.0
## -1 or 1. Lolo turns to face the way he is going, like the player does.
@export var facing: float = 1.0
## Set while he is talking, so the idle bob lifts a little and reads as animated.
@export var talking: bool = false


func _draw() -> void:
	var lift := sin(TAU * bob) * 3.0
	var squash := 1.0 + sin(TAU * bob) * 0.04
	var centre := Vector2(0.0, lift)

	# A soft shadow on the ground so he reads as floating rather than pasted on.
	draw_circle(Vector2(0.0, BODY_RADIUS + 16.0), BODY_RADIUS * 0.62, Color(0.0, 0.0, 0.0, 0.16))

	draw_circle(centre, BODY_RADIUS * squash + 2.0, HALO)
	draw_circle(centre, BODY_RADIUS * squash, SHELL)
	draw_arc(centre, BODY_RADIUS * squash, 0.0, TAU, 24, INK, WIDTH * 0.6, true)

	# A leaf, so the silhouette is not a plain ball at a glance.
	var stem_top := centre + Vector2(-2.0 * facing, -BODY_RADIUS - 9.0)
	draw_line(centre + Vector2(-2.0 * facing, -BODY_RADIUS + 2.0), stem_top, INK, WIDTH * 0.6, true)
	var sway := sin(TAU * bob + 0.6) * 0.22
	var leaf_tip := stem_top + Vector2(sin(sway + 0.9) * 15.0 * facing, -cos(sway + 0.9) * 9.0)
	draw_line(stem_top, leaf_tip, INK, WIDTH * 0.5, true)
	draw_circle((stem_top + leaf_tip) * 0.5 + Vector2(0.0, -3.0), 5.0, Color(0.45, 0.76, 0.36))

	var eyes := centre + Vector2(2.0 * facing, -2.0)
	for side in [-1.0, 1.0]:
		draw_circle(eyes + Vector2(side * EYE_OFFSET, 0.0), EYE_RADIUS, INK)
	# The mouth is the whole of his expression: a small o while talking, a line at rest.
	if talking:
		draw_arc(eyes + Vector2(0.0, 8.0), 3.6, 0.0, TAU, 12, INK, WIDTH * 0.5, true)
	else:
		draw_line(eyes + Vector2(-4.0, 8.0), eyes + Vector2(4.0, 8.0), INK, WIDTH * 0.5, true)
