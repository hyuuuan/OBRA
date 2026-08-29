class_name PiyestaDoor2D
extends Node2D
## A door in the plaza wall, and the only way into anywhere in this level.
##
## FOUR OF THEM AND ONLY TWO GO ANYWHERE, which is the design asking for it in so many
## words: *"put the lit house past two or three dark doors so the search reads as a search"*.
## A door that opens onto nothing is not a failure of this class -- it is the level's one
## piece of misdirection, and the dark ones have to look exactly like the lit one except for
## the light.
##
## SO THE LIGHT IS THE WHOLE TELL. `lit` puts a warm seam under the door and a glow in the
## keyhole, and nothing else about a lit door differs from a dark one. A player who has been
## told to look for a house with lights inside has one thing to look for and it is legible
## from across the plaza, which is what makes walking past two dark ones feel like searching
## rather than like being made to wait.
##
## ⚠ IT IS NOT A LOCK. Level 1's padlock judges the STROKES of a drawn key -- that mechanic
## is `WardLock2D` and the design says to reuse it, not to rebuild it. This class holds the
## door's state and says whether the player is standing in front of it. What opens it is the
## level's business.
##
## PLACEHOLDER ART. The design lists a house door set -- closed, lit from inside, keyhole,
## open -- under what does not exist yet. Drawn to `ART_PLACEHOLDERS.md` rules: real size,
## real trigger, and nothing implying an affordance it does not have.

## The apo is standing in front of this door, or has stepped away from it.
signal at_door(standing: bool)

## What the level calls this one. The level matches on it rather than on node names.
@export var door_id: String = ""
## Light showing under it. The one difference between the house that matters and the two
## that do not.
@export var lit := false
## Whether it can be walked through yet. A shut door still shows what it is -- it is not a
## blank wall -- so a player can see where they will be going before they can go.
@export var open := false
## Said when the player stands at a door that is shut. A door that does nothing and explains
## nothing is a door the player concludes is broken.
@export var shut_note: String = ""
## Said when the player stands at a door that is open. Carries its own key cap.
@export var open_note: String = ""

## A town door: a metre wide and a little over two tall. Measured at the apo's
## seventy-two-pixels-to-the-metre, same ruler the rooms use.
const SIZE := Vector2(78.0, 156.0)
## How far either side of the door counts as standing at it. Wide enough that the player
## does not have to be pixel-perfect, narrow enough that two doors cannot both claim them --
## the plaza's dark pair are 200 apart.
const REACH := Vector2(120.0, 170.0)

const FRAME_DEEP := Color(0.114, 0.086, 0.063, 1.0)   # 1D1610
const FRAME := Color(0.310, 0.239, 0.176, 1.0)        # 4F3D2D
const FRAME_LIT := Color(0.443, 0.353, 0.259, 1.0)    # 715A42
## The leaf itself: painted board, sun-bleached, the way a door on a plaza is.
const LEAF_DARK := Color(0.239, 0.212, 0.196, 1.0)    # 3D3632
const LEAF := Color(0.373, 0.325, 0.286, 1.0)         # 5F5349
const LEAF_LIT := Color(0.478, 0.427, 0.373, 1.0)     # 7A6D5F
## What is behind an open one. Not black -- a doorway that is black reads as a hole.
const INSIDE := Color(0.075, 0.067, 0.063, 1.0)       # 131110
## Lamplight from inside, in the seam and the keyhole. The tell.
const LAMP := Color(0.988, 0.812, 0.451, 1.0)         # FCCF73
const LAMP_SOFT := Color(0.988, 0.812, 0.451, 0.30)
const IRON := Color(0.184, 0.176, 0.169, 1.0)         # 2F2D2B

var _standing := false
var _area: Area2D


func _ready() -> void:
	add_to_group(&"piyesta_doors")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_reach()
	queue_redraw()


## The volume that notices somebody standing in front of it. An Area2D and nothing else:
## the door is not solid, because a door you bump into is a door you cannot stand in.
func _build_reach() -> void:
	_area = Area2D.new()
	_area.name = "Reach"
	_area.position = Vector2(0.0, -REACH.y * 0.5)
	add_child(_area)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = REACH
	shape.shape = box
	_area.add_child(shape)
	_area.body_entered.connect(_on_body.bind(true))
	_area.body_exited.connect(_on_body.bind(false))


func _on_body(body: Node, coming_in: bool) -> void:
	if not body.is_in_group(&"player_character"):
		return
	# A rig has more than one body in it and they cross the edge one at a time, so an exit
	# from one foot while another is still inside would take the prompt down mid-approach.
	# Same guard the straw mouth carries.
	if not coming_in and _bodies_inside() > 0:
		return
	if _standing == coming_in:
		return
	_standing = coming_in
	at_door.emit(coming_in)


func _bodies_inside() -> int:
	var count := 0
	for body in _area.get_overlapping_bodies():
		if body.is_in_group(&"player_character"):
			count += 1
	return count


func standing_here() -> bool:
	return _standing


## Where the player is put back down when they come out of here. Beside the door rather than
## in it, or walking out counts as walking back in and the room is a trap. Level 1 learned
## this at the straw mouth.
func step_out_point() -> Vector2:
	return global_position + Vector2(-REACH.x * 0.9, 0.0)


func set_open(value: bool) -> void:
	if open == value:
		return
	open = value
	queue_redraw()


func set_lit(value: bool) -> void:
	if lit == value:
		return
	lit = value
	queue_redraw()


## What the level puts on the hint bar while the player stands here. Kept on the door so a
## door's two states cannot be described in two different voices by two call sites.
func prompt() -> String:
	if open:
		return open_note if not open_note.is_empty() else ""
	return shut_note


func _draw() -> void:
	var leaf := Rect2(-SIZE.x * 0.5, -SIZE.y, SIZE.x, SIZE.y)
	# The surround, and the step under it. A door drawn straight onto a wall has no depth
	# and reads as a poster.
	draw_rect(leaf.grow(12.0), FRAME_DEEP)
	draw_rect(Rect2(leaf.position - Vector2(8.0, 8.0), Vector2(leaf.size.x + 16.0, 10.0)),
		FRAME_LIT)
	draw_rect(Rect2(-SIZE.x * 0.5 - 16.0, -10.0, SIZE.x + 32.0, 12.0), FRAME)
	if open:
		draw_rect(leaf, INSIDE)
		# The leaf swung back against the inside of the jamb, so an open door is a door and
		# not an absence.
		draw_rect(Rect2(leaf.position, Vector2(14.0, leaf.size.y)), LEAF_DARK)
		if lit:
			draw_rect(leaf, LAMP_SOFT)
		return
	draw_rect(leaf, LEAF)
	# Vertical boards with a shadowed joint, which is what makes a rectangle a door.
	var boards := 4
	for index in range(boards):
		var width := leaf.size.x / float(boards)
		var x := leaf.position.x + float(index) * width
		draw_rect(Rect2(x, leaf.position.y, width - 2.0, leaf.size.y),
			LEAF_LIT if index % 2 == 0 else LEAF)
		draw_rect(Rect2(x + width - 2.0, leaf.position.y, 2.0, leaf.size.y), LEAF_DARK)
	# Two straps and a handle: the ironwork is what gives it a scale.
	for height: float in [0.24, 0.76]:
		draw_rect(Rect2(leaf.position.x, leaf.position.y + leaf.size.y * height,
			leaf.size.x, 8.0), IRON)
	draw_rect(Rect2(leaf.position.x + leaf.size.x - 20.0,
		leaf.position.y + leaf.size.y * 0.52, 10.0, 16.0), IRON)
	if not lit:
		return
	# THE TELL, and it is only these two marks. Light under the door and light in the
	# keyhole -- the same door otherwise, so what the player is looking for is a light and
	# not a different house.
	draw_rect(Rect2(leaf.position.x + 3.0, -6.0, leaf.size.x - 6.0, 6.0), LAMP)
	draw_rect(Rect2(leaf.position.x + leaf.size.x - 19.0,
		leaf.position.y + leaf.size.y * 0.52 + 2.0, 8.0, 12.0), LAMP)
	# And a little of it spilling onto the step, so it reads from across the plaza.
	draw_rect(Rect2(leaf.position.x - 10.0, 0.0, leaf.size.x + 20.0, 14.0), LAMP_SOFT)
