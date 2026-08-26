class_name PickupFlourish2D
extends Node2D
## The half-second that says the thing you were looking at is yours now.
##
## TAKING SOMETHING USED TO BE A SPRITE THAT STOPPED BEING DRAWN. The brass on the nail
## inside the heap and the canvas leaning against the wall of the house are the two objects
## Level 1 is actually about, and both of them were collected by walking into a trigger that
## set a bool and called queue_redraw. One frame it was there, the next it was not. A player
## who was looking at their own feet at the time got no signal at all that the level had just
## handed them the thing the last ten minutes were for.
##
## So both pickups play THIS, and it is one node rather than two copies because a reward
## should not look different according to which room it was in. A ring going out, sparks
## thrown off it, and a glint rising -- the vocabulary the checkpoint flag already uses when
## it turns gold, in the same metal, so "yours now" reads the same way everywhere.
##
## It runs while the tree is PAUSED, deliberately. Picking something up is usually followed
## immediately by a line of story, and a story line stops the world -- so a flourish bound to
## the tree's pause state would freeze one frame in and finish after the player had turned
## the page.

## How long the whole thing takes. Short: it is punctuation, not a cutscene.
const LIFE := 0.8
const SPARKS := 14
const RING_FROM := 6.0
const RING_TO := 46.0

## What metal it is thrown in. Gold by default -- the interface's own "yours now" colour.
var tint: Color = UISkin.GOLD

var _age := 0.0
var _angles: PackedFloat32Array = PackedFloat32Array()
var _speeds: PackedFloat32Array = PackedFloat32Array()


## Throw one at a spot in `parent`'s own space. Returns the node so a caller can park it
## somewhere else in the tree if it wants; nothing has to be freed, it frees itself.
static func burst(parent: Node2D, at: Vector2, colour: Color = UISkin.GOLD) -> PickupFlourish2D:
	if parent == null or not is_instance_valid(parent):
		return null
	var flourish := PickupFlourish2D.new()
	flourish.name = "PickupFlourish"
	flourish.position = at
	flourish.tint = colour
	# Over the room it is drawn in. The interiors draw themselves at a negative z so the
	# player stands in front of the picture; a flourish behind the wall is no flourish.
	flourish.z_index = 40
	parent.add_child(flourish)
	return flourish


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	process_mode = Node.PROCESS_MODE_ALWAYS
	# DETERMINISTIC, like everything else these rooms draw. The same pickup throws the same
	# sparks every time, so a screenshot has something to be compared against and a bug here
	# is reproducible rather than a thing that happened once.
	for index in range(SPARKS):
		_angles.append(TAU * float(index) / float(SPARKS) + float((index * 37) % 11) * 0.03)
		_speeds.append(58.0 + float((index * 53) % 7) * 9.0)
	set_process(true)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_age / LIFE, 0.0, 1.0)
	var fade := 1.0 - t

	# The ring: one pulse outward, thinning as it widens.
	var radius := lerpf(RING_FROM, RING_TO, ease(t, 0.35))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40,
		Color(tint, 0.55 * fade), maxf(1.0, 4.0 * fade), true)

	# The sparks, falling as they fly -- they are struck off the thing, not fired from it.
	for index in range(_angles.size()):
		var at := Vector2.from_angle(_angles[index]) * (_speeds[index] * t) \
			+ Vector2(0.0, 42.0 * t * t)
		draw_rect(Rect2(at - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), Color(tint, fade))

	# And the glint going up, which is the part that reads at a glance: something left the
	# floor and went where the player keeps things.
	var lift := -34.0 * ease(t, 0.4)
	var pale := Color(UISkin.GOLD_PALE, 0.75 * fade)
	draw_rect(Rect2(-1.5, lift - 10.0, 3.0, 20.0), pale)
	draw_rect(Rect2(-9.0, lift - 1.5, 18.0, 3.0), pale)
