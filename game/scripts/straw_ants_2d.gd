class_name StrawAnts2D
extends Node2D
## The tenants of the straw room, walking about on the floor of it.
##
## THEY ARE THE ONLY THING IN THIS GAME THAT MOVES ON ITS OWN and is not a creature the
## player drew, and that is deliberate: the room is a place somebody has not been for a long
## time, and the one thing that says so without a line of dialogue is that something else
## lives there. They carry no collision, nothing reads their position, and drawing an ant on
## the canvas does not make one appear here.
##
## THEY GET THEIR OWN NODE so the room does not repaint to animate them. The walls are a
## thousand-odd units of tiled art and the floor is another thousand; redrawing all of that
## sixty times a second to move six legs would be sixty times the work for the smallest
## thing on screen.
##
## Drawn rather than cut, from the reference in level-1-assets. That file is a watermarked
## stock image, so it is a drawing to work from and not an asset to ship -- the shape, the
## three-segment body and the two oranges are its, the walk is not.

## Where they may wander, in this node's own space: they turn round at the ends rather than
## walking out of the room.
@export var patrol := Vector2(-560.0, 560.0)
@export var count: int = 5
## How fast an ant walks. Slow: it is scenery, and something crossing the floor at speed
## reads as a threat.
@export var speed := 26.0

## The two oranges off the reference, plus a dark for the outline and the eye.
const SHELL := Color(0.820, 0.404, 0.106, 1.0)  # D1671B
const SHELL_DARK := Color(0.741, 0.294, 0.184, 1.0)  # BD4B2F
const OUTLINE := Color(0.243, 0.098, 0.043, 1.0)  # 3E190B
const GLINT := Color(1.0, 0.878, 0.694, 1.0)

var _ants: Array[Dictionary] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rng := RandomNumberGenerator.new()
	# Seeded, so they are in the same places every time the room is walked into rather than
	# scattering afresh on every entry.
	rng.seed = int(absf(position.x) * 7919.0 + absf(position.y) * 104729.0) | 1
	for index in range(count):
		_ants.append({
			"x": rng.randf_range(patrol.x, patrol.y),
			"y": rng.randf_range(-6.0, 6.0),
			"dir": 1.0 if rng.randf() < 0.5 else -1.0,
			"pace": rng.randf_range(0.7, 1.3),
			"phase": rng.randf_range(0.0, TAU),
		})
	set_process(true)


func _process(delta: float) -> void:
	for ant in _ants:
		var pace: float = ant["pace"]
		ant["x"] = float(ant["x"]) + float(ant["dir"]) * speed * pace * delta
		# Turn round at the ends. An ant that walks off the edge of the floor and comes back
		# on the other side is a bug in the most literal way.
		if float(ant["x"]) < patrol.x:
			ant["x"] = patrol.x
			ant["dir"] = 1.0
		elif float(ant["x"]) > patrol.y:
			ant["x"] = patrol.y
			ant["dir"] = -1.0
		ant["phase"] = fmod(float(ant["phase"]) + delta * 11.0 * pace, TAU)
	queue_redraw()


func _draw() -> void:
	for ant in _ants:
		_draw_ant(Vector2(ant["x"], ant["y"]), float(ant["dir"]), float(ant["phase"]))


## One ant, in whole pixels: abdomen, thorax, head, six legs and two antennae.
##
## THE LEGS ARE THE WALK. The body barely moves -- it bobs a pixel -- and everything that
## says "walking" is the tripod gait: front and back leg on one side swing with the middle
## leg on the other, which is what an insect actually does and what stops six legs paddling
## in unison like a rowing eight.
func _draw_ant(at: Vector2, facing: float, phase: float) -> void:
	var bob := 1.0 if sin(phase * 2.0) > 0.0 else 0.0
	var body := at + Vector2(0.0, -bob)

	# Legs first, so the body sits over the top of them.
	for index in range(3):
		var hip := body + Vector2(facing * (-5.0 + float(index) * 5.0), -4.0)
		# Tripod: 0 and 2 on one beat, 1 on the other.
		var swing := sin(phase + (0.0 if index == 1 else PI))
		var reach := facing * (2.0 + swing * 3.0)
		_leg(hip, reach)

	# Abdomen, thorax, head -- back to front, each a little block with a lit top.
	_segment(body + Vector2(facing * -10.0, -7.0), Vector2(7.0, 6.0))
	_segment(body + Vector2(facing * -4.0, -6.0), Vector2(5.0, 5.0))
	_segment(body + Vector2(facing * 1.0, -8.0), Vector2(6.0, 6.0))
	# The eye, and the catch of light on it.
	var eye := body + Vector2(facing * 4.0, -7.0)
	draw_rect(Rect2(eye - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), OUTLINE)
	draw_rect(Rect2(eye, Vector2(1.0, 1.0)), GLINT)
	# Antennae, sweeping with the walk.
	for side: float in [-1.0, 1.0]:
		var root := body + Vector2(facing * 4.0, -11.0)
		var tip := root + Vector2(facing * (4.0 + sin(phase) * 1.5),
			-4.0 + side * 2.0)
		draw_line(root, tip, OUTLINE, 1.0, false)


## A block of shell: the body colour with a lighter top edge and a dark underside, which is
## the same way round as every other thing in this game that catches the light.
func _segment(centre: Vector2, size: Vector2) -> void:
	var box := Rect2(centre - size * 0.5, size)
	draw_rect(box.grow(1.0), OUTLINE)
	draw_rect(box, SHELL_DARK)
	draw_rect(Rect2(box.position, Vector2(box.size.x, maxf(1.0, box.size.y - 2.0))), SHELL)
	draw_rect(Rect2(box.position, Vector2(box.size.x, 1.0)), SHELL.lightened(0.25))


## A leg: down from the hip, then out to the foot. Two strokes, both on whole pixels.
func _leg(hip: Vector2, reach: float) -> void:
	var knee := hip + Vector2(reach * 0.5, 3.0)
	draw_line(hip, knee, OUTLINE, 1.0, false)
	draw_line(knee, Vector2(hip.x + reach, hip.y + 5.0), OUTLINE, 1.0, false)
