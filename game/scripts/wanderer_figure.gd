extends Node2D
## The wanderer's body, drawn from primitives.
##
## Deliberately crude, and deliberately drawn in the same ink the player's own drawings
## are rendered in -- dark line, pale halo -- so the character reads as belonging to
## the same world as the creature it turns into rather than as a sprite standing next
## to one. Replacing this with real art means replacing this one file.

const INK := Color(0.08, 0.09, 0.07, 1.0)
const HALO := Color(1.0, 1.0, 1.0, 0.75)
const WIDTH := 5.0

## How far the limbs swing at full stride. Held here rather than read off Wanderer so
## this file compiles on its own: a script that names a class_name not yet registered
## resolves to null when loaded, and set_script(null) writes a scene with no script at
## all -- silently, and visible only as a figure that never draws.
const STRIDE := 0.7

const HEAD_RADIUS := 9.0
const HEAD_Y := -48.0
const HIP_Y := -20.0
const SHOULDER_Y := -34.0
const LEG := 20.0
const ARM := 15.0
## Resting spread, so the limbs are distinguishable when standing still.
const ARM_SPLAY := 0.30
const LEG_SPLAY := 0.20

@export var stride: float = 0.0


func _draw() -> void:
	var swing: float = sin(TAU * stride) * STRIDE
	# Halo first, then ink over it, so the figure stays readable against the terraces.
	for pass_index in range(2):
		var colour := HALO if pass_index == 0 else INK
		var width := WIDTH + 4.0 if pass_index == 0 else WIDTH
		draw_arc(Vector2(0.0, HEAD_Y), HEAD_RADIUS, 0.0, TAU, 20, colour, width, true)
		draw_line(Vector2(0.0, HEAD_Y + HEAD_RADIUS), Vector2(0.0, HIP_Y), colour, width, true)
		# Arms and legs counter-swing, which is what makes it read as a walk. Each pair
		# also carries a fixed splay so the four limbs never all collapse onto the torso
		# line at rest -- without it the figure reads as a lollipop rather than a body.
		_limb(Vector2(0.0, SHOULDER_Y), ARM, swing + ARM_SPLAY, colour, width)
		_limb(Vector2(0.0, SHOULDER_Y), ARM, -swing - ARM_SPLAY, colour, width)
		_limb(Vector2(0.0, HIP_Y), LEG, -swing - LEG_SPLAY, colour, width)
		_limb(Vector2(0.0, HIP_Y), LEG, swing + LEG_SPLAY, colour, width)


## One straight limb hanging from `origin`, rotated `angle` off vertical.
func _limb(origin: Vector2, length: float, angle: float, colour: Color, width: float) -> void:
	var tip := origin + Vector2(sin(angle), cos(angle)) * length
	draw_line(origin, tip, colour, width, true)
