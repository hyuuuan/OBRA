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

## ⚠ THE STONE IS NOT A CONSTANT ANY MORE. It is sampled off the painting AT THIS DOOR'S
## OWN X, and handed in by the scene.
##
## Three versions of this failed the same way. First a grey plank slab with iron straps: four
## filing cabinets standing in a finished painting. Then one fixed limestone ramp taken off
## `TextureMap_Piyesta` -- better, but the plaza is a PAINTING, and it is not one colour: the
## two dark doors stand in deep shade under the kiosko stair (#4E3A09, #574129) while the lit
## house and the church front are in full sun (#BC8659, #96661F). One pale ramp for all four
## put two chalky arches in a shadow, which is exactly as wrong as the filing cabinets and
## harder to see because each door looked fine on its own.
##
## The mapping is 1:1 -- the painting is placed so that world x IS plate x -- so any door's
## tone is a median of the plate under it. `tools/build_plaza.py` prints nothing for this on
## purpose; it is four numbers in the scene, beside the four marks they belong to.
@export var wall_tone: Color = Color(0.612, 0.482, 0.302, 1.0)   # 9C7B4D, behind the dancers
## The leaf is timber, and timber is timber wherever it is standing -- it does not take the
## wall's colour, it takes the wall's LIGHT, which is what `_tone` is for.
## The leaf: the stall's dark timber, which is the only wood in this picture.
const LEAF_DARK := Color(0.098, 0.078, 0.039, 1.0)    # 19140A
const LEAF := Color(0.270, 0.212, 0.112, 1.0)         # 44351C
const LEAF_LIT := Color(0.408, 0.302, 0.173, 1.0)     # 684D2C
## What is behind an open one. Not black -- a doorway that is black reads as a hole.
const INSIDE := Color(0.075, 0.067, 0.063, 1.0)       # 131110
## Lamplight from inside, in the seam and the keyhole. The tell.
const LAMP := Color(0.988, 0.812, 0.451, 1.0)         # FCCF73
const LAMP_SOFT := Color(0.988, 0.812, 0.451, 0.30)
## Light coming through the joints between the boards -- dimmer than the seam under the door,
## because it is squeezing through a crack rather than pouring under a gap.
const LAMP_WARM := Color(0.976, 0.729, 0.322, 0.72)
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


## THE WALL BUILDS THE DOORWAY; THIS DRAWS THE HOLE.
##
## ⚠ DO NOT PUT THE MASONRY BACK. An earlier version drew the full architecture -- a
## five-inch reveal, seven voussoirs over the head, a lit jamb and a sill -- in pale church
## limestone. Each door looked like a door and the four together looked like four doors
## PASTED ON, because the painting already has the wall and does not need a second one drawn
## over it in a different colour. The eye read the surround first and the opening second,
## which is backwards for a level whose one piece of misdirection is "which of these has a
## light on".
##
## So the surround is the wall's own tone, barely modelled: a jamb face a shade under it, a
## reveal well under it, three pixels of light down the left edge because the light in this
## picture comes from the left, and a sill. Nothing here is lighter than the wall it is cut
## into. What the eye finds is the dark hole, and then -- on exactly one of them -- the lamp.
func _draw() -> void:
	var leaf := Rect2(-SIZE.x * 0.5, -SIZE.y, SIZE.x, SIZE.y)
	var jamb := 9.0
	var rise := 22.0
	# The jamb face, then the reveal. Both out of the wall's own colour, so the doorway is a
	# hole in this wall rather than a frame standing in front of it.
	_draw_arched(leaf.grow(jamb), rise + 5.0, _tone(0.78))
	_draw_arched(leaf.grow(jamb - 4.0), rise + 3.0, _tone(0.52))
	_draw_arched(leaf.grow(2.0), rise, _tone(0.24))
	# One light, from the left, everywhere in this picture.
	draw_rect(Rect2(leaf.position.x - jamb, leaf.position.y - 2.0, 3.0, leaf.size.y + 2.0),
		_tone(1.18))
	# The sill it opens onto: a lit top face and the shadow it casts, and nothing else.
	draw_rect(Rect2(leaf.position.x - jamb - 4.0, -6.0, leaf.size.x + jamb * 2.0 + 8.0, 7.0),
		_tone(1.10))
	draw_rect(Rect2(leaf.position.x - jamb - 4.0, 1.0, leaf.size.x + jamb * 2.0 + 8.0, 4.0),
		_tone(0.46))

	if open:
		# Swung inward: the leaf against the reveal on one side, and dark beyond it.
		draw_rect(leaf, LEAF_DARK)
		draw_rect(Rect2(leaf.position, Vector2(15.0, leaf.size.y)), LEAF)
		if lit:
			draw_rect(Rect2(leaf.position.x + 15.0, leaf.position.y,
				leaf.size.x - 15.0, leaf.size.y), LAMP_SOFT)
			draw_rect(Rect2(leaf.position.x - 10.0, 0.0, leaf.size.x + 20.0, 16.0), LAMP_SOFT)
		return

	# Shut: vertical boards, a plank ledge across them, and a ring handle. Small and dark,
	# because the masonry is what the eye should read first.
	draw_rect(leaf, LEAF)
	var boards := 4
	for index in range(boards):
		var width := leaf.size.x / float(boards)
		var x := leaf.position.x + float(index) * width
		draw_rect(Rect2(x, leaf.position.y, width - 2.0, leaf.size.y),
			LEAF_LIT if index % 2 == 0 else LEAF)
		draw_rect(Rect2(x + width - 2.0, leaf.position.y, 2.0, leaf.size.y), LEAF_DARK)
	for height: float in [0.26, 0.74]:
		draw_rect(Rect2(leaf.position.x, leaf.position.y + leaf.size.y * height,
			leaf.size.x, 6.0), LEAF_DARK)
	draw_arc(Vector2(leaf.position.x + leaf.size.x - 17.0,
		leaf.position.y + leaf.size.y * 0.54), 7.0, 0.0, TAU, 12, IRON, 3.0)
	if not lit:
		return
	# THE TELL, AND IT HAS TO CARRY ACROSS THE PLAZA. The player is told to look for a house
	# with its lights on; a seam of warm pixels among four identical doorways is not something
	# anybody finds. So: the seam under the leaf, the keyhole, light through the joints between
	# the boards, and a wash of it thrown out onto the sill and up the reveal.
	for index in range(1, 4):
		var joint := leaf.position.x + leaf.size.x / 4.0 * float(index)
		draw_rect(Rect2(joint - 2.0, leaf.position.y + 6.0, 3.0, leaf.size.y - 12.0), LAMP_WARM)
	draw_rect(Rect2(leaf.position.x + 2.0, -10.0, leaf.size.x - 4.0, 10.0), LAMP)
	draw_rect(Rect2(leaf.position.x + leaf.size.x - 21.0,
		leaf.position.y + leaf.size.y * 0.54 - 5.0, 8.0, 14.0), LAMP)
	# On the sill and washing up the stone either side, which is what a lit window does to
	# the wall around it and is the part that reads from a distance.
	draw_rect(Rect2(leaf.position.x - 26.0, -6.0, leaf.size.x + 52.0, 22.0), LAMP_SOFT)
	draw_rect(Rect2(leaf.position.x - 34.0, 2.0, leaf.size.x + 68.0, 12.0), LAMP_SOFT)
	for side: float in [-1.0, 1.0]:
		draw_rect(Rect2(leaf.position.x + (0.0 if side < 0.0 else leaf.size.x) - 9.0,
			leaf.position.y, 9.0, leaf.size.y), LAMP_SOFT)


## THE WALL'S OWN COLOUR, taken up into the light or down into the shade.
##
## Below one it multiplies, which is what shadow does to a surface -- a shaded ochre stays
## ochre. Above one it goes toward white and NOT toward a fixed highlight colour, because a
## fixed highlight is how the pale-limestone version ended up chalky in the shadow under the
## kiosko stair.
func _tone(scale: float) -> Color:
	if scale <= 1.0:
		return Color(wall_tone.r * scale, wall_tone.g * scale, wall_tone.b * scale, 1.0)
	return wall_tone.lerp(Color(1.0, 1.0, 1.0, 1.0), minf(scale - 1.0, 1.0) * 0.55)


## An arched-headed rectangle: the rectangle, plus the segment over its top.
func _draw_arched(rect: Rect2, rise: float, colour: Color) -> void:
	draw_rect(rect, colour)
	var points := PackedVector2Array()
	var steps := 16
	for index in range(steps + 1):
		var t := float(index) / float(steps)
		points.append(Vector2(rect.position.x + t * rect.size.x,
			rect.position.y - sin(t * PI) * rise))
	points.append(Vector2(rect.position.x + rect.size.x, rect.position.y))
	points.append(rect.position)
	draw_colored_polygon(points, colour)
