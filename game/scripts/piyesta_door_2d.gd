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
## SO THE LIGHT IS THE WHOLE TELL. A lit house has its wall lantern burning, amber in the capiz
## fanlight over the leaves, and lamplight in the joint between them; a dark one has cold glass,
## grey shell and a bar across the door. Nothing else about the two differs. A player who has
## been told to look for a house with a light in the window has one thing to look for, and it
## is legible from across the plaza -- which is what makes walking past two dark ones feel like
## searching rather than like being made to wait.
##
## ⚠ IT IS NOT A LOCK. Level 1's padlock judges the STROKES of a drawn key -- that mechanic
## is `WardLock2D` and the design says to reuse it, not to rebuild it. This class holds the
## door's state and says whether the player is standing in front of it. What opens it is the
## level's business.
##
## PLACEHOLDER ART, but no longer a hole with nothing round it. The design lists a house door
## set -- closed, lit from inside, keyhole, open -- that has not been delivered. Drawn to
## `ART_PLACEHOLDERS.md` rules: real size, real trigger, and nothing implying an affordance it
## does not have.

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

## Which kind of doorway. A house is a slice of a street front; the church is a stone portal
## in a facade that is already painted behind it.
enum Style { HOUSE, CHURCH }
@export var style: Style = Style.HOUSE

## A town door: a metre wide and a little over two tall. Measured at the apo's
## seventy-two-pixels-to-the-metre, same ruler the rooms use.
const SIZE := Vector2(78.0, 156.0)
## The piece of house front a door is set into. Wide enough for quoins either side and a
## lantern, and no taller than the painted ground floors behind it.
const FACADE := Vector2(156.0, 214.0)
## The church's opening, which is a double door and a head taller than any house's.
const PORTAL := Vector2(104.0, 176.0)
## How far either side of the door counts as standing at it. Wide enough that the player
## does not have to be pixel-perfect, narrow enough that two doors cannot both claim them --
## the plaza's dark pair are 200 apart.
const REACH := Vector2(120.0, 170.0)

## ⚠ WALL TONE IS A LIGHT LEVEL NOW, NOT A COLOUR.
##
## It is still sampled off the painting at this door's own x and handed in by the scene -- the
## dark pair stand in the shade under the kiosko stair and the other two in full sun -- but it
## no longer paints the stone. The first three versions of this door drew only a hole cut in
## the painted wall, in that wall's colour, and that was right for as long as there was a
## painted wall behind each door. There is not: the plaza is a painting of a plaza, and the
## marks put doors in front of a palm, a dancer and a stretch of sky. Four brown boards
## standing in the open is what the player saw, and it read as four boards.
##
## So a door brings the front it is set into -- plaster over a stone plinth, quoins at the
## corners, a tile hood -- in the palette the painted houses are already made of, and takes
## only its BRIGHTNESS from the plate, so a front standing in shade is darker than one in sun.
@export var wall_tone: Color = Color(0.612, 0.482, 0.302, 1.0)   # 9C7B4D, behind the dancers

## The painted houses' own materials: lime plaster, adobe stone, clay tile, narra.
const PLASTER := Color(0.890, 0.816, 0.678, 1.0)      # E3D0AD
const PLASTER_SHADE := Color(0.769, 0.671, 0.514, 1.0) # C4AB83
const QUOIN := Color(0.851, 0.780, 0.639, 1.0)        # D9C7A3
const QUOIN_EDGE := Color(0.561, 0.478, 0.353, 1.0)   # 8F7A5A
const PLINTH := Color(0.553, 0.486, 0.392, 1.0)       # 8D7C64
const PLINTH_DARK := Color(0.416, 0.357, 0.282, 1.0)  # 6A5B48
const STONE := Color(0.804, 0.733, 0.592, 1.0)        # CDBB97
const STONE_LIT := Color(0.910, 0.863, 0.753, 1.0)    # E8DCC0
const STONE_DARK := Color(0.616, 0.541, 0.408, 1.0)   # 9D8A68
const TILE := Color(0.725, 0.329, 0.176, 1.0)         # B9542D
const TILE_LIT := Color(0.843, 0.443, 0.247, 1.0)     # D7713F
const TILE_DARK := Color(0.494, 0.196, 0.098, 1.0)    # 7E3219
const TIMBER := Color(0.357, 0.227, 0.122, 1.0)       # 5B3A1F
const TIMBER_LIT := Color(0.490, 0.333, 0.188, 1.0)   # 7D5530
const TIMBER_DARK := Color(0.227, 0.141, 0.071, 1.0)  # 3A2412
## What is behind an open one. Not black -- a doorway that is black reads as a hole.
const INSIDE := Color(0.075, 0.067, 0.063, 1.0)       # 131110
## Capiz shell in the fanlight: grey pearl with nobody home, amber with a lamp behind it.
const CAPIZ := Color(0.294, 0.282, 0.255, 1.0)        # 4B4841
const CAPIZ_LIT := Color(1.0, 0.859, 0.557, 1.0)      # FFDB8E
## Lamplight. The tell, and it has to carry across the plaza.
const LAMP := Color(0.988, 0.812, 0.451, 1.0)         # FCCF73
const LAMP_SOFT := Color(0.988, 0.812, 0.451, 0.30)
const GLASS := Color(0.169, 0.165, 0.149, 1.0)        # 2B2A26
const IRON := Color(0.184, 0.176, 0.169, 1.0)         # 2F2D2B
const SHADOW := Color(0.0, 0.0, 0.0, 0.28)
## What the painter's shadows are made of: a warm umber, never grey.
const SHADE := Color(0.70, 0.58, 0.46, 1.0)
## The church is built of the cream coral stone the painted facade is, not the house plinths.
const CHURCH := Color(0.886, 0.816, 0.682, 1.0)       # E2D0AE
const CHURCH_LIT := Color(0.957, 0.914, 0.824, 1.0)   # F4E9D2
const CHURCH_DARK := Color(0.749, 0.651, 0.490, 1.0)  # BFA67D
const CHURCH_DEEP := Color(0.573, 0.475, 0.337, 1.0)  # 927956

var _standing := false
var _area: Area2D
var _flicker := 0.0
var _since_redraw := 0.0


func _ready() -> void:
	add_to_group(&"piyesta_doors")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_reach()
	set_process(lit)
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
	queue_redraw()
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
	set_process(lit)
	queue_redraw()


## What the level puts on the hint bar while the player stands here. Kept on the door so a
## door's two states cannot be described in two different voices by two call sites.
func prompt() -> String:
	if open:
		return open_note if not open_note.is_empty() else ""
	return shut_note


func _process(delta: float) -> void:
	_flicker += delta
	# About a dozen redraws a second is all a lamp flame needs, and it is only asked of the
	# one door with a lamp in it.
	_since_redraw += delta
	if _since_redraw >= 0.08:
		_since_redraw = 0.0
		queue_redraw()


## How strongly the plate is lit where this door stands: 0 in the deepest shade in the
## picture, 1 in full sun.
func _light() -> float:
	return clampf((wall_tone.get_luminance() - 0.18) / 0.34, 0.0, 1.0)


## A material, in the light where this door stands. ⚠ SHADE IS WARM HERE. The first pass
## multiplied toward black, and the two fronts under the kiosko stair came out a flat
## concrete grey in a picture that has no grey in it -- the painter's shadows are brown.
func _lit(colour: Color, extra: float = 1.0) -> Color:
	var shade := SHADE.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.35 + 0.65 * _light())
	var out := Color(colour.r * shade.r * extra, colour.g * shade.g * extra,
		colour.b * shade.b * extra, colour.a)
	return out.clamp()


## A lamp flame breathes; a steady glow reads as a sticker. Two sines out of step, so it does
## not pulse like a warning light.
func _flame() -> float:
	return 0.82 + 0.10 * sin(_flicker * 7.3) + 0.08 * sin(_flicker * 12.9 + 1.7)


func _draw() -> void:
	if style == Style.CHURCH:
		_draw_church()
	else:
		_draw_house()
	if _standing and open:
		# THE ONE SIGN THAT THIS IS THE DOOR THE PROMPT IS ABOUT: a line of lamp gold along the
		# sill, only while it can actually be walked through.
		var width := (PORTAL.x if style == Style.CHURCH else SIZE.x) + 14.0
		draw_rect(Rect2(-width * 0.5, -3.0, width, 3.0), Color(UISkin.GOLD, 0.85))


# --- A house front ----------------------------------------------------------------------

func _draw_house() -> void:
	var half := FACADE.x * 0.5
	var top := -FACADE.y
	var plinth := 26.0
	# The shadow the front throws on the paving, so it stands ON the plaza.
	draw_rect(Rect2(-half + 6.0, -2.0, FACADE.x + 6.0, 8.0), SHADOW)

	# Plaster over a stone plinth, lit from the left like everything in the picture.
	draw_rect(Rect2(-half, top, FACADE.x, FACADE.y - plinth), _lit(PLASTER))
	draw_rect(Rect2(half - 10.0, top, 10.0, FACADE.y - plinth), _lit(PLASTER_SHADE))
	draw_rect(Rect2(-half, -plinth, FACADE.x, plinth), _lit(PLINTH))
	draw_rect(Rect2(-half, -plinth, FACADE.x, 3.0), _lit(STONE_LIT))
	for row in range(2):
		var y := -plinth + 3.0 + float(row) * 12.0
		draw_rect(Rect2(-half, y + 10.0, FACADE.x, 2.0), _lit(PLINTH_DARK))
		var step := 30.0
		var x := -half + (15.0 if row % 2 == 1 else 0.0)
		while x < half:
			draw_rect(Rect2(x, y, 2.0, 10.0), _lit(PLINTH_DARK))
			x += step
	# Quoins at both corners: the block edge is what tells the eye this is the corner of a
	# building and not a sheet of plaster that stops.
	for side: float in [-1.0, 1.0]:
		var y := -plinth
		var index := 0
		while y > top + 6.0:
			var width := 20.0 if index % 2 == 0 else 13.0
			var x := -half if side < 0.0 else half - width
			draw_rect(Rect2(x, y - 20.0, width, 20.0), _lit(QUOIN, 1.0 if side < 0.0 else 0.9))
			draw_rect(Rect2(x, y - 2.0, width, 2.0), _lit(QUOIN_EDGE))
			y -= 20.0
			index += 1
	# The timber sill of the floor above, which is how the old stone houses here are built.
	draw_rect(Rect2(-half - 4.0, top - 4.0, FACADE.x + 8.0, 10.0), _lit(TIMBER))
	draw_rect(Rect2(-half - 4.0, top - 4.0, FACADE.x + 8.0, 2.0), _lit(TIMBER_LIT))

	var opening := Rect2(-SIZE.x * 0.5, -SIZE.y, SIZE.x, SIZE.y)
	_draw_surround(opening, 9.0, 14.0)
	_draw_hood(Rect2(-half + 8.0, opening.position.y - 44.0, FACADE.x - 16.0, 18.0))
	_draw_fanlight(Rect2(opening.position.x, opening.position.y - 14.0,
		opening.size.x, 40.0), 14.0)
	var leaves := Rect2(opening.position.x, opening.position.y + 26.0,
		opening.size.x, opening.size.y - 26.0)
	if open:
		_draw_open_leaves(leaves)
	else:
		_draw_leaves(leaves, 2)
		if not lit:
			# SHUTTERED. A bar across the leaves is the town's own way of saying nobody is
			# home, and it is the difference a player can see from across the plaza.
			draw_rect(Rect2(leaves.position.x - 8.0, leaves.position.y + leaves.size.y * 0.42,
				leaves.size.x + 16.0, 10.0), _lit(TIMBER_DARK))
			draw_rect(Rect2(leaves.position.x - 8.0, leaves.position.y + leaves.size.y * 0.42,
				leaves.size.x + 16.0, 2.0), _lit(TIMBER))
			for side: float in [-1.0, 1.0]:
				draw_rect(Rect2(side * (leaves.size.x * 0.5 + 2.0) - 3.0,
					leaves.position.y + leaves.size.y * 0.42 - 3.0, 6.0, 16.0), IRON)
	# The threshold.
	draw_rect(Rect2(opening.position.x - 12.0, -5.0, opening.size.x + 24.0, 5.0),
		_lit(STONE_LIT))
	_draw_lantern(Vector2(half - 22.0, opening.position.y + 8.0))
	if lit:
		_draw_lamplight(opening)


## Stone voussoirs up both jambs and round a shallow arch.
func _draw_surround(opening: Rect2, jamb: float, rise: float) -> void:
	var block := 18.0
	var y := opening.position.y + opening.size.y
	var index := 0
	while y > opening.position.y:
		var height := minf(block, y - opening.position.y)
		var tone := STONE if index % 2 == 0 else STONE_DARK
		draw_rect(Rect2(opening.position.x - jamb, y - height, jamb, height), _lit(tone))
		draw_rect(Rect2(opening.position.x + opening.size.x, y - height, jamb, height),
			_lit(tone, 0.88))
		y -= block
		index += 1
	# The arch, as a band of wedge blocks following the segment.
	var steps := 7
	for step in range(steps):
		var a := float(step) / float(steps)
		var b := float(step + 1) / float(steps)
		var outer_a := _arch_point(opening, rise + jamb, a, jamb)
		var outer_b := _arch_point(opening, rise + jamb, b, jamb)
		var inner_a := _arch_point(opening, rise, a, 0.0)
		var inner_b := _arch_point(opening, rise, b, 0.0)
		var tone := STONE_LIT if step == steps / 2 else (STONE if step % 2 == 0 else STONE_DARK)
		draw_colored_polygon(PackedVector2Array([outer_a, outer_b, inner_b, inner_a]),
			_lit(tone))
	# The reveal in shadow.
	draw_rect(opening, INSIDE)


func _arch_point(opening: Rect2, rise: float, t: float, grow: float) -> Vector2:
	var x := opening.position.x - grow + t * (opening.size.x + grow * 2.0)
	return Vector2(x, opening.position.y - sin(t * PI) * rise)


## Clay tile on timber brackets over the door -- the hood every house on a plaza like this
## has, and the one thing that makes a doorway read as the front of a house from a distance.
func _draw_hood(band: Rect2) -> void:
	# Braces, not spikes: a post against the wall and a strut out to the tile. Drawn as
	# tapering black triangles they read as a row of teeth over every door.
	for side: float in [0.16, 0.84]:
		var x := band.position.x + band.size.x * side
		var y := band.position.y + band.size.y
		draw_rect(Rect2(x - 2.0, y, 4.0, 14.0), _lit(TIMBER))
		draw_rect(Rect2(x - 2.0, y, 1.0, 14.0), _lit(TIMBER_LIT))
		for step in range(4):
			var toward := -1.0 if side < 0.5 else 1.0
			draw_rect(Rect2(x + toward * (3.0 + float(step) * 3.0) - 1.5, y + 10.0 - float(step) * 3.0,
				3.0, 3.0), _lit(TIMBER))
	draw_rect(Rect2(band.position + Vector2(0.0, band.size.y), Vector2(band.size.x, 4.0)),
		SHADOW)
	draw_rect(band, _lit(TILE))
	draw_rect(Rect2(band.position, Vector2(band.size.x, 3.0)), _lit(TILE_LIT))
	var x := band.position.x + 4.0
	while x < band.position.x + band.size.x - 2.0:
		draw_rect(Rect2(x, band.position.y + 3.0, 2.0, band.size.y - 3.0), _lit(TILE_DARK))
		x += 10.0
	draw_rect(Rect2(band.position.x, band.position.y + band.size.y - 3.0, band.size.x, 3.0),
		_lit(TILE_DARK))


## The capiz fanlight over the leaves. Grey pearl in an empty house, amber in the lit one.
func _draw_fanlight(area: Rect2, rise: float) -> void:
	var points := PackedVector2Array()
	for index in range(13):
		points.append(_arch_point(area, rise, float(index) / 12.0, 0.0))
	points.append(area.position + Vector2(area.size.x, area.size.y))
	points.append(area.position + Vector2(0.0, area.size.y))
	var glow := CAPIZ_LIT if lit else CAPIZ
	if lit:
		glow = glow.lerp(LAMP, 1.0 - _flame())
	draw_colored_polygon(points, glow if lit else _lit(glow))
	for column in range(1, 4):
		var x := area.position.x + area.size.x * float(column) / 4.0
		draw_rect(Rect2(x - 1.0, area.position.y - rise, 2.0, area.size.y + rise), TIMBER_DARK)
	draw_rect(Rect2(area.position.x, area.position.y + area.size.y * 0.45, area.size.x, 2.0),
		TIMBER_DARK)
	draw_rect(Rect2(area.position.x, area.position.y + area.size.y - 3.0, area.size.x, 3.0),
		_lit(TIMBER))


## Panelled double leaves, iron-studded, with a ring pull on each.
func _draw_leaves(area: Rect2, panels: int) -> void:
	var gap := 2.0
	var leaf_width := (area.size.x - gap) * 0.5
	for leaf in range(2):
		var x := area.position.x + float(leaf) * (leaf_width + gap)
		var leaf_rect := Rect2(x, area.position.y, leaf_width, area.size.y)
		draw_rect(leaf_rect, _lit(TIMBER))
		var inset := 6.0
		var panel_height := (area.size.y - inset * float(panels + 1)) / float(panels)
		for panel in range(panels):
			var panel_rect := Rect2(x + inset, area.position.y + inset
				+ float(panel) * (panel_height + inset), leaf_width - inset * 2.0, panel_height)
			draw_rect(panel_rect, _lit(TIMBER, 0.92))
			draw_rect(Rect2(panel_rect.position, Vector2(panel_rect.size.x, 2.0)), _lit(TIMBER_LIT))
			draw_rect(Rect2(panel_rect.position, Vector2(2.0, panel_rect.size.y)), _lit(TIMBER_LIT))
			draw_rect(Rect2(panel_rect.position + Vector2(0.0, panel_rect.size.y - 2.0),
				Vector2(panel_rect.size.x, 2.0)), _lit(TIMBER_DARK))
			for corner: Vector2 in [Vector2(-3.0, -3.0), Vector2(panel_rect.size.x + 1.0, -3.0),
					Vector2(-3.0, panel_rect.size.y + 1.0),
					Vector2(panel_rect.size.x + 1.0, panel_rect.size.y + 1.0)]:
				draw_rect(Rect2(panel_rect.position + corner, Vector2(2.0, 2.0)), IRON)
		var ring := Vector2(x + (leaf_width - 7.0 if leaf == 0 else 7.0),
			area.position.y + area.size.y * 0.5)
		draw_arc(ring, 4.0, 0.0, TAU, 10, IRON, 2.0)
	draw_rect(Rect2(area.position.x + leaf_width, area.position.y, gap, area.size.y),
		LAMP if lit else TIMBER_DARK)


## Swung inward: dark beyond, the leaves folded back against the reveal, and lamplight on the
## floor if there is a lamp.
func _draw_open_leaves(area: Rect2) -> void:
	draw_rect(area, INSIDE)
	if lit:
		draw_rect(area, Color(LAMP.r, LAMP.g, LAMP.b, 0.22 * _flame()))
		draw_rect(Rect2(area.position.x, area.position.y + area.size.y - 18.0,
			area.size.x, 18.0), Color(LAMP.r, LAMP.g, LAMP.b, 0.30))
	draw_rect(Rect2(area.position.x, area.position.y, 10.0, area.size.y), _lit(TIMBER_DARK))
	draw_rect(Rect2(area.position.x + area.size.x - 10.0, area.position.y, 10.0,
		area.size.y), _lit(TIMBER))


## A wall lantern on an iron arm. Cold glass on the dark houses; alight on the one with
## somebody's lamp inside.
func _draw_lantern(at: Vector2) -> void:
	draw_rect(Rect2(at.x - 14.0, at.y - 2.0, 14.0, 3.0), IRON)
	draw_rect(Rect2(at.x - 1.0, at.y, 2.0, 6.0), IRON)
	var body := Rect2(at.x - 7.0, at.y + 6.0, 14.0, 20.0)
	# ⚠ NO SOFT HALO. It is noon on this plaza; a round wash of lamplight on sunlit plaster is
	# invisible at a distance and a pale disc up close, which is what the first cut drew. What
	# a lit lamp looks like in daylight is its FLAME -- a hot core in amber glass.
	if lit:
		var flame := _flame()
		draw_rect(body.grow(3.0), Color(LAMP.r, LAMP.g, LAMP.b, 0.55 * flame))
	draw_rect(Rect2(body.position.x - 2.0, body.position.y - 3.0, body.size.x + 4.0, 4.0), IRON)
	draw_rect(body, Color(0.957, 0.608, 0.184, 1.0) if lit else GLASS)
	if lit:
		var core := 5.0 + 3.0 * _flame()
		draw_rect(Rect2(body.get_center().x - 2.0, body.get_center().y - core * 0.5 + 2.0,
			4.0, core), Color(1.0, 0.953, 0.769, 1.0))
	draw_rect(Rect2(body.position.x - 1.0, body.position.y, 2.0, body.size.y), IRON)
	draw_rect(Rect2(body.position.x + body.size.x - 1.0, body.position.y, 2.0, body.size.y), IRON)
	draw_rect(Rect2(body.position.x, body.position.y + body.size.y, body.size.x, 3.0), IRON)


## THE TELL, AND IT HAS TO CARRY ACROSS THE PLAZA. Light under the leaves, through the joint,
## and thrown out onto the paving -- which is what a lit doorway does to the ground in front
## of it and is the part that reads from a distance.
func _draw_lamplight(opening: Rect2) -> void:
	var flame := _flame()
	if not open:
		draw_rect(Rect2(opening.position.x + 2.0, -9.0, opening.size.x - 4.0, 4.0), LAMP)
	var spill := PackedVector2Array()
	for index in range(17):
		var t := float(index) / 16.0 * PI
		spill.append(Vector2(cos(t) * (opening.size.x * 0.5 + 90.0), sin(t) * 22.0))
	draw_colored_polygon(spill, Color(LAMP.r, LAMP.g, LAMP.b, 0.34 * flame))


# --- The church's portal ---------------------------------------------------------------

func _draw_church() -> void:
	var opening := Rect2(-PORTAL.x * 0.5, -PORTAL.y, PORTAL.x, PORTAL.y)
	var base := -16.0
	var pilaster := 16.0
	var arch_rise := PORTAL.x * 0.5
	var ring := 16.0
	var outer := PORTAL.x * 0.5 + ring + pilaster
	var head := base - PORTAL.y - arch_rise - ring
	draw_rect(Rect2(-outer + 6.0, -2.0, outer * 2.0 + 6.0, 8.0), SHADOW)
	# Two steps up to it, because nobody walks straight off a plaza into a church.
	draw_rect(Rect2(-outer - 14.0, -8.0, (outer + 14.0) * 2.0, 8.0), _lit(CHURCH_DARK))
	draw_rect(Rect2(-outer - 14.0, -8.0, (outer + 14.0) * 2.0, 2.0), _lit(CHURCH))
	draw_rect(Rect2(-outer - 4.0, -16.0, (outer + 4.0) * 2.0, 8.0), _lit(CHURCH))
	draw_rect(Rect2(-outer - 4.0, -16.0, (outer + 4.0) * 2.0, 2.0), _lit(CHURCH_LIT))
	opening.position.y += base
	# The wall the arch is set into, up to the cornice. Drawn first and overdrawn by the arch,
	# which is what leaves the two spandrels standing.
	draw_rect(Rect2(-outer + pilaster, head, (outer - pilaster) * 2.0,
		opening.position.y - head), _lit(CHURCH, 0.95))
	# The round arch the doors stand in: the reveal first, then the ring of wedge stones.
	var arch := PackedVector2Array()
	for index in range(25):
		var t := PI + PI * float(index) / 24.0
		arch.append(Vector2(cos(t) * PORTAL.x * 0.5, opening.position.y + sin(t) * arch_rise))
	arch.append(Vector2(PORTAL.x * 0.5, base))
	arch.append(Vector2(-PORTAL.x * 0.5, base))
	draw_colored_polygon(arch, INSIDE)
	var stones := 11
	for stone in range(stones):
		var a := PI + PI * float(stone) / float(stones)
		var b := PI + PI * float(stone + 1) / float(stones)
		var inner := PORTAL.x * 0.5
		var out := inner + ring
		var tone := CHURCH_LIT if stone == stones / 2 else (CHURCH if stone % 2 == 0 else CHURCH_DARK)
		draw_colored_polygon(PackedVector2Array([
			Vector2(cos(a) * inner, opening.position.y + sin(a) * arch_rise),
			Vector2(cos(a) * out, opening.position.y + sin(a) * (arch_rise + ring)),
			Vector2(cos(b) * out, opening.position.y + sin(b) * (arch_rise + ring)),
			Vector2(cos(b) * inner, opening.position.y + sin(b) * arch_rise)]), _lit(tone))
	# Jambs down to the step, and a pilaster either side carrying a cornice over the arch.
	for side: float in [-1.0, 1.0]:
		var jamb_x := -PORTAL.x * 0.5 - ring if side < 0.0 else PORTAL.x * 0.5
		var y := base
		var index := 0
		while y > opening.position.y:
			var height := minf(22.0, y - opening.position.y)
			draw_rect(Rect2(jamb_x, y - height, ring, height),
				_lit(CHURCH if index % 2 == 0 else CHURCH_DARK, 1.0 if side < 0.0 else 0.92))
			y -= 22.0
			index += 1
		var x := -outer if side < 0.0 else outer - pilaster
		draw_rect(Rect2(x, head, pilaster, base - head), _lit(CHURCH))
		draw_rect(Rect2(x, head, 3.0, base - head), _lit(CHURCH_LIT))
		draw_rect(Rect2(x + pilaster - 3.0, head, 3.0, base - head), _lit(CHURCH_DEEP))
		draw_rect(Rect2(x - 3.0, base - 12.0, pilaster + 6.0, 12.0), _lit(CHURCH_DARK))
	draw_rect(Rect2(-outer - 8.0, head - 12.0, (outer + 8.0) * 2.0, 12.0), _lit(CHURCH_LIT))
	draw_rect(Rect2(-outer - 8.0, head - 2.0, (outer + 8.0) * 2.0, 3.0), _lit(CHURCH_DEEP))
	# A carved rosette on the keystone, and nothing sacred: the guardrail in `level_02.json`
	# keeps every image off anything the player can use, and this is a door they walk through.
	var key := Vector2(0.0, opening.position.y - arch_rise - ring * 0.5)
	draw_circle(key, 5.0, _lit(CHURCH_DEEP))
	draw_circle(key, 2.0, _lit(CHURCH_LIT))
	var leaves := Rect2(opening.position.x + 4.0, opening.position.y - arch_rise * 0.2,
		opening.size.x - 8.0, base - opening.position.y + arch_rise * 0.2)
	if open:
		# Candle warmth from inside the nave, and the two leaves folded back.
		draw_colored_polygon(arch, Color(LAMP.r, LAMP.g, LAMP.b, 0.20))
		for index in range(7):
			draw_rect(Rect2(leaves.position.x + 18.0 + float(index) * 10.0,
				base - 34.0 - float(index % 2) * 4.0, 3.0, 5.0), LAMP)
		draw_rect(Rect2(leaves.position.x, leaves.position.y, 12.0, leaves.size.y),
			_lit(TIMBER_DARK))
		draw_rect(Rect2(leaves.position.x + leaves.size.x - 12.0, leaves.position.y, 12.0,
			leaves.size.y), _lit(TIMBER))
	else:
		_draw_leaves(leaves, 3)
