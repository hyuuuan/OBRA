class_name HubRoom
extends Node2D
## Lolo and Lola's house: where the game starts, and where you choose a level by walking up
## to the painting of it.
##
## THE REFERENCE IS A BAHAY NA BATO INTERIOR -- hardwood walls in tall panelled bays, a
## wainscot running the length of them, capiz shutters, a plank floor, and pictures hung at
## eye height between the bays. It is drawn here rather than tiled from art because the room
## is one long wall and a repeating tile is exactly what a hand-built wall is not: the bays
## have to line up with the paintings, and the paintings are spaced by how far apart five
## levels want to be, not by a tile size.
##
## Everything is drawn on a four-pixel grid and nothing is anti-aliased, so it belongs with
## the rest of the 8-bit interface rather than looking like a vector illustration of a room.

## The art grid. Every rectangle in this room snaps to it.
const PIXEL := 4.0

## THE ROOM IS MEASURED IN THE PERSON STANDING IN IT.
##
## Every number below was guessed twice before it was worked out, and both guesses were
## wrong the same way: the house was sized like a level, so it came out enormous and the
## apo crossed it like an ant. Sizing it to the camera instead only moved the problem --
## the frame filled up, with a wall two metres of dado and a picture three and a half
## metres across, and the child was still the smallest thing in his grandparents' house.
##
## So the ruler is the apo. He is 96 pixels tall and he is a child of about one metre
## thirty, which puts a METRE AT SEVENTY-TWO PIXELS, and every dimension here is a real
## measurement of a real room divided by that. A four-metre ceiling because a bahay na bato
## salon has one. A dado at ninety-five centimetres because that is where a chair rail
## goes. Pictures with their middles at eye height for an adult, which is above his.
##
## The virtue of a ruler is that it answers the next question too. If the settee looks
## wrong, it is because 1.55 m is the wrong length for a settee, and that is arguable in a
## way that "112" is not.
const METRE := 72.0

## How long the wall is and where the floor sits under it. The floor line is what the apo
## stands on; everything else is measured off it.
@export var room_width: float = 1800.0
@export var floor_y: float = 360.0
## Floor to cornice: four metres, which is a storey in a house with these ceilings.
@export var wall_height: float = 288.0
## The pressed-tin ceiling above the cornice, seen from underneath.
@export var ceiling_depth: float = 72.0
## How deep the floorboards run toward the viewer before the frame ends.
@export var floor_depth: float = 108.0
## How far up the wall the wainscot panelling reaches. A chair rail, at chest height on the
## apo and at the waist on the adult who fitted it.
@export var wainscot_height: float = 68.0
## Where the paintings hang, measured to their middle.
##
## Two and a half metres, which is higher than a gallery hangs and is right for a house:
## these are over the furniture, and at two metres the bottom of the frame came down level
## with the top of the apo's head. He is a metre thirty and the frame reached a metre
## thirty-nine, so it was correct and it still looked like he was about to walk into it.
@export var painting_y: float = 180.0
## The first painting's centre, and the gap to the next.
##
## Four metres and a bit apart, which is what leaves a PIER between two pictures wide
## enough for the door that goes in it -- see _draw_doors. The five pictures and the six
## doors alternate, so this one number sets the whole rhythm of the wall and the room is as
## long as five of them plus a pier at each end.
@export var first_painting_x: float = 300.0
@export var painting_gap: float = 300.0

## Hardwood, in four tones. Narra darkens with age and these are all one hue apart on
## purpose -- a wall of contrasting browns reads as a woodpile rather than as joinery.
const WALL_DARK := Color(0.208, 0.118, 0.063, 1.0)    # 351E10  the shadowed bay
const WALL := Color(0.310, 0.180, 0.094, 1.0)         # 4F2E18  the field
const WALL_LIT := Color(0.396, 0.239, 0.129, 1.0)     # 653D21  the lit stile
const WALL_EDGE := Color(0.129, 0.071, 0.039, 1.0)    # 21120A  the shadow line
const WALL_HI := Color(0.494, 0.318, 0.184, 1.0)      # 7E512F  the catch on a stile
## The floor, a shade cooler than the wall so the two do not merge at the skirting -- and
## LIGHTER than the wall, which took a screenshot to see. Narra darkens with age but a
## floor is walked on and waxed, so it is the one surface in a house that catches the light
## rather than absorbing it; drawn darker than the panelling it read as a hole in the
## bottom third of the frame.
const FLOOR := Color(0.365, 0.208, 0.106, 1.0)        # 5D351B
const FLOOR_LIT := Color(0.451, 0.278, 0.153, 1.0)    # 734727
## Capiz: shell panes, milk-white and faintly warm, in a grid of thin muntins.
const CAPIZ := Color(0.902, 0.878, 0.784, 1.0)        # E6E0C8
const CAPIZ_SHADE := Color(0.780, 0.749, 0.647, 1.0)  # C7BFA5


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -10
	queue_redraw()


## Where the apo stands. The room owns it so the scene does not have to repeat the number.
func ground_y() -> float:
	return floor_y


## The top of everything this room draws, and the line the wall meets it on. Derived rather
## than stored: the ceiling is above the wall, and the wall is a height off the floor, so
## there is one number here and it is the floor.
func ceiling_y() -> float:
	return floor_y - wall_height - ceiling_depth


func cornice_y() -> float:
	return floor_y - wall_height


## How tall the room draws in total, which is what the camera has to be able to fill.
func drawn_height() -> float:
	return ceiling_depth + wall_height + floor_depth


## The middle of the nth painting, counting from zero.
func painting_anchor(index: int) -> Vector2:
	return Vector2(first_painting_x + painting_gap * float(index), painting_y)


func _draw() -> void:
	_draw_wall()
	_draw_piers()
	_draw_doors()
	_draw_floor()
	_draw_furniture()
	_draw_chandeliers()


## Where the nth door stands, counting from zero. One between every pair of pictures and
## one at each end of the wall, so what you walk past is picture, door, picture, door.
##
## That rhythm is the reference photograph's and it is why the pictures are spaced the way
## they are: a bahay na bato salon is not a corridor with things hung along it, it is a run
## of piers with a doorway in every gap, and the pictures go on the piers.
func door_anchor(index: int) -> float:
	return first_painting_x + painting_gap * (float(index) - 0.5)


func door_count() -> int:
	return 6


## How wide a doorway is, and how much pier it leaves either side of it.
const DOOR_WIDTH := 116.0
## How tall: two metres sixty, which is a door in a room with four-metre ceilings.
const DOOR_HEIGHT := 187.0
## The pierced fretwork panel above it. Calado is what a house with this much heat and no
## glass does instead of a fanlight -- air moves between the rooms with the doors shut.
const TRANSOM_HEIGHT := 69.0

## The wood grain. Narra is a striped timber and the stripe is the whole reason a wall of
## it does not read as cardboard, but it has to be UNDER the joinery rather than on top of
## it: a stripe that crosses a stile is a scratch.
const GRAIN_PITCH := 7


## A deterministic scatter, so the grain does not crawl from one redraw to the next.
func _hash(value: int) -> int:
	var x := (value * 374761393 + 668265263) & 0x7FFFFFFF
	x = (x ^ (x >> 13)) * 1274126177
	return x & 0x7FFFFFFF


## Vertical grain over a rectangle, in the two tones either side of `base`.
func _grain(area: Rect2, light: Color, dark: Color) -> void:
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	var x := ceilf(area.position.x)
	while x < area.end.x:
		var roll := _hash(int(x))
		var step := GRAIN_PITCH + roll % 5
		# Not every stripe, and not every stripe the same length: an even comb of lines is
		# corduroy, and this is supposed to be timber.
		if roll % 3 != 0:
			var top := area.position.y + float((roll >> 5) % 11)
			var height := area.size.y - float((roll >> 9) % 17) - (top - area.position.y)
			if height > 6.0:
				draw_rect(Rect2(x, top, 1.0, height),
					light if (roll >> 3) % 2 == 0 else dark)
		x += float(step)


func _draw_wall() -> void:
	var top := ceiling_y()
	var cornice := cornice_y()
	draw_rect(Rect2(0.0, top, room_width, floor_y - top), WALL)
	_draw_ceiling(top, cornice)
	# The cornice: the moulded band the ceiling sits on, stepped out from the wall in three
	# courses so it catches light the way a run of moulding does.
	draw_rect(Rect2(0.0, cornice - 18.0, room_width, 6.0), WALL_LIT)
	draw_rect(Rect2(0.0, cornice - 12.0, room_width, 2.0), WALL_EDGE)
	draw_rect(Rect2(0.0, cornice - 10.0, room_width, 8.0), WALL)
	draw_rect(Rect2(0.0, cornice - 2.0, room_width, 2.0), WALL_EDGE)


## The pressed-tin ceiling of the reference photograph, seen from underneath.
##
## It was a strip with vertical ribs down it, which is a corrugated roof, not a ceiling. A
## stamped tin ceiling is a GRID OF PANELS with a motif punched into each -- that is the
## whole of what makes one recognisable -- and seen from below at this angle the grid is
## foreshortened into two shallow courses rather than squares.
func _draw_ceiling(top: float, cornice: float) -> void:
	var depth := cornice - 18.0 - top
	var tin := Color(0.435, 0.455, 0.400, 1.0)
	var tin_dark := Color(0.318, 0.337, 0.290, 1.0)
	var tin_lit := Color(0.529, 0.549, 0.486, 1.0)
	draw_rect(Rect2(0.0, top, room_width, depth), tin)
	var courses := 2
	var course_h := depth / float(courses)
	for course in range(courses):
		var y := top + course_h * float(course)
		draw_rect(Rect2(0.0, y, room_width, 2.0), tin_dark)
		var x := 0.0
		while x < room_width:
			# The panel: a sunk field with a raised bead round it.
			var panel := Rect2(x + 4.0, y + 5.0, 64.0, course_h - 12.0)
			draw_rect(panel, tin_dark)
			draw_rect(Rect2(panel.position, Vector2(panel.size.x, 1.0)), tin_lit)
			draw_rect(Rect2(panel.position.x, panel.end.y - 1.0, panel.size.x, 1.0), tin_lit)
			# The stamped motif in the middle of it: a small four-pointed star, which at
			# this size is a cross with its corners knocked off.
			var mid := panel.get_center()
			draw_rect(Rect2(mid.x - 6.0, mid.y - 1.0, 12.0, 2.0), tin_lit)
			draw_rect(Rect2(mid.x - 1.0, mid.y - 6.0, 2.0, 12.0), tin_lit)
			draw_rect(Rect2(mid.x - 3.0, mid.y - 3.0, 6.0, 6.0), tin)
			draw_rect(Rect2(x + 70.0, y + 2.0, 2.0, course_h - 4.0), tin_dark)
			x += 72.0


## The piers: the panelled stretches of wall the pictures hang on, between one doorway and
## the next. Each is a pair of stiles with a tall raised panel between them, a dado across
## the bottom, and grain under all of it.
func _draw_piers() -> void:
	var edges: Array[float] = [0.0]
	for index in range(door_count()):
		edges.append(door_anchor(index) - DOOR_WIDTH * 0.5 - 10.0)
		edges.append(door_anchor(index) + DOOR_WIDTH * 0.5 + 10.0)
	edges.append(room_width)
	var pair := 0
	while pair + 1 < edges.size():
		_draw_pier(edges[pair], edges[pair + 1])
		pair += 2


func _draw_pier(left: float, right: float) -> void:
	var width := right - left
	if width <= 0.0:
		return
	var top := cornice_y()
	var stile := minf(14.0, width * 0.5)
	draw_rect(Rect2(left, top, width, floor_y - top), WALL)
	_grain(Rect2(left, top, width, floor_y - top), WALL_LIT, WALL_DARK)

	# The two uprights, lit down the left edge because the light in this room comes from
	# the left, the same way it does round the gilt on a frame.
	for edge: float in [left, right - stile]:
		draw_rect(Rect2(edge, top, stile, floor_y - top), WALL_LIT)
		draw_rect(Rect2(edge, top, 2.0, floor_y - top), WALL_HI)
		draw_rect(Rect2(edge + stile - 2.0, top, 2.0, floor_y - top), WALL_EDGE)

	# The raised panel between them, above the dado.
	var dado := floor_y - wainscot_height
	var field := Rect2(left + stile, top + 12.0, maxf(0.0, width - stile * 2.0),
		dado - top - 24.0)
	_draw_raised_panel(field)
	_draw_dado(left, right, dado)


## One sunk panel with a bevel round it: dark at the top and left where the moulding turns
## away from the light, light at the bottom and right where it turns into it, which is the
## opposite of a raised surface and is the only thing that says "sunk" at this size.
func _draw_raised_panel(field: Rect2) -> void:
	if field.size.x <= 8.0 or field.size.y <= 8.0:
		return
	draw_rect(field, WALL_DARK)
	_grain(field.grow(-4.0), WALL, WALL_EDGE)
	draw_rect(Rect2(field.position, Vector2(field.size.x, 3.0)), WALL_EDGE)
	draw_rect(Rect2(field.position, Vector2(3.0, field.size.y)), WALL_EDGE)
	draw_rect(Rect2(field.position.x, field.end.y - 3.0, field.size.x, 3.0), WALL_LIT)
	draw_rect(Rect2(field.end.x - 3.0, field.position.y, 3.0, field.size.y), WALL_LIT)


## The dado: a chair rail with shorter panels under it, running across a pier and stopping
## at the door jamb rather than ploughing through it.
func _draw_dado(left: float, right: float, top: float) -> void:
	var width := right - left
	draw_rect(Rect2(left, top, width, wainscot_height), WALL)
	_grain(Rect2(left, top + 12.0, width, wainscot_height - 24.0), WALL_LIT, WALL_DARK)
	# The rail, proud of the wall above it.
	draw_rect(Rect2(left, top, width, 4.0), WALL_LIT)
	draw_rect(Rect2(left, top + 4.0, width, 2.0), WALL_EDGE)
	draw_rect(Rect2(left, top + 6.0, width, 4.0), WALL)
	# One panel under it, inset from the stiles so it lines up with the field above.
	var panel := Rect2(left + 18.0, top + 16.0, maxf(0.0, width - 36.0),
		wainscot_height - 30.0)
	if panel.size.x > 8.0:
		draw_rect(panel, WALL_DARK)
		draw_rect(Rect2(panel.position, Vector2(panel.size.x, 2.0)), WALL_EDGE)
		draw_rect(Rect2(panel.position, Vector2(2.0, panel.size.y)), WALL_EDGE)
		draw_rect(Rect2(panel.position.x, panel.end.y - 2.0, panel.size.x, 2.0), WALL_LIT)
	# The skirting the floor meets.
	draw_rect(Rect2(left, floor_y - 12.0, width, 12.0), WALL_LIT)
	draw_rect(Rect2(left, floor_y - 12.0, width, 2.0), WALL_EDGE)
	draw_rect(Rect2(left, floor_y - 3.0, width, 3.0), WALL_EDGE)


## The doorways, glazed with capiz and topped with calado.
##
## THEY ARE THE ONLY LIGHT IN THE ROOM. Everything else here is one brown, and a wall of
## pictures with no light source in it looks like a corridor rather than a room in a house.
## What used to be here was a single small shuttered window floating in the middle of a
## panel with no sill and nothing holding it up, which looked like a mistake; a doorway
## reaches the floor, and the eye reads it without being told.
func _draw_doors() -> void:
	for index in range(door_count()):
		_draw_door(door_anchor(index))


func _draw_door(centre: float) -> void:
	var half := DOOR_WIDTH * 0.5
	var head := floor_y - DOOR_HEIGHT
	var jamb := 10.0

	# The architrave: the moulded surround, running from the floor up round the transom.
	var surround := Rect2(centre - half - jamb, head - TRANSOM_HEIGHT - jamb * 2.0,
		DOOR_WIDTH + jamb * 2.0, DOOR_HEIGHT + TRANSOM_HEIGHT + jamb * 2.0)
	draw_rect(surround, WALL_LIT)
	draw_rect(surround, WALL_EDGE, false, 2.0)

	_draw_calado(Rect2(centre - half, head - TRANSOM_HEIGHT - jamb, DOOR_WIDTH,
		TRANSOM_HEIGHT))
	# The lintel between the transom and the door.
	draw_rect(Rect2(centre - half - jamb, head - jamb, DOOR_WIDTH + jamb * 2.0, jamb),
		WALL)
	draw_rect(Rect2(centre - half - jamb, head - 2.0, DOOR_WIDTH + jamb * 2.0, 2.0),
		WALL_EDGE)

	# THE LEAF ITSELF, in three courses: shell above, a lock rail level with the dado on
	# the piers either side, and a solid panel below. Lining the rail up with the chair
	# rail is what a joiner does and what stops the wall reading as two unrelated things
	# meeting at a door.
	var rail := floor_y - wainscot_height
	var leaf := Rect2(centre - half, head, DOOR_WIDTH, DOOR_HEIGHT)
	draw_rect(leaf, WALL)
	_draw_capiz(Rect2(leaf.position.x + 6.0, leaf.position.y + 6.0,
		leaf.size.x - 12.0, rail - leaf.position.y - 12.0))
	draw_rect(Rect2(leaf.position.x, rail - 6.0, leaf.size.x, 12.0), WALL_LIT)
	draw_rect(Rect2(leaf.position.x, rail + 6.0, leaf.size.x, 2.0), WALL_EDGE)
	var lower := Rect2(leaf.position.x + 6.0, rail + 14.0, leaf.size.x - 12.0,
		floor_y - rail - 26.0)
	if lower.size.y > 8.0:
		draw_rect(lower, WALL_DARK)
		_grain(lower.grow(-3.0), WALL, WALL_EDGE)
		draw_rect(Rect2(lower.position, Vector2(lower.size.x, 2.0)), WALL_EDGE)
		draw_rect(Rect2(lower.position.x, lower.end.y - 2.0, lower.size.x, 2.0), WALL_LIT)
	# The threshold.
	draw_rect(Rect2(leaf.position.x, floor_y - 10.0, leaf.size.x, 10.0), WALL_LIT)
	draw_rect(Rect2(leaf.position.x, floor_y - 10.0, leaf.size.x, 2.0), WALL_EDGE)
	draw_rect(leaf, WALL_EDGE, false, 2.0)


## Capiz: the shell panes a bahay na bato is glazed with instead of glass, in a grid of
## thin muntins. The grid IS the thing anybody recognises capiz by, so it is drawn as a
## grid before it is drawn as anything else.
func _draw_capiz(area: Rect2) -> void:
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	draw_rect(area, WALL_EDGE)
	var cols := 4
	var rows := int(maxf(1.0, roundf(area.size.y / 22.0)))
	var cell := Vector2(area.size.x / float(cols), area.size.y / float(rows))
	for row in range(rows):
		for col in range(cols):
			var pane := Rect2(
				area.position + Vector2(float(col) * cell.x, float(row) * cell.y)
					+ Vector2.ONE * 2.0,
				cell - Vector2.ONE * 4.0)
			# Daylight falls off down the opening, so the top row is the brightest. Each
			# shell is a slightly different milk, which is what shell does.
			var fade := float(row) / float(maxi(rows, 1))
			var tint := CAPIZ.lerp(CAPIZ_SHADE, fade)
			if _hash(col * 31 + row * 7 + int(area.position.x)) % 3 == 0:
				tint = tint.darkened(0.06)
			draw_rect(pane, tint)
			draw_rect(Rect2(pane.position, Vector2(pane.size.x, 2.0)),
				Color(1.0, 1.0, 1.0, 0.35))
			draw_rect(Rect2(pane.position.x, pane.end.y - 2.0, pane.size.x, 2.0),
				Color(0.0, 0.0, 0.0, 0.12))


## Calado: the pierced fretwork panel over a doorway, which is how air crosses a house
## with the doors shut.
##
## DRAWN AS THE WOOD, WITH HOLES IN IT. The first cut drew it the other way round -- a lit
## field with spindles standing in front of it -- and a row of pale uprights with a swelling
## at the middle is not fretwork, it is a row of candles. Six of them along the wall, under
## a chandelier that is also a row of candles, and the eye could not tell which was the
## light fitting.
##
## So the panel is a solid board and the daylight comes through a row of diamonds cut out
## of it. That is both the right way round physically and the thing that makes it legible:
## the wood is the majority, so the transom sits back on the wall instead of glaring off
## it, and the chandelier hanging in front has something dark to be seen against.
func _draw_calado(area: Rect2) -> void:
	if area.size.x <= 8.0 or area.size.y <= 8.0:
		return
	draw_rect(area, WALL)
	_grain(area.grow(-3.0), WALL_LIT, WALL_DARK)
	# The light in the next room, which is what you actually see through a calado.
	# Dim, and dimmer than the capiz below it: this is borrowed light from the next room
	# through a hole the size of a hand, not the daylight coming through a whole doorway.
	# Drawn at the brightness of the shell it came out looking like a row of lamps.
	var glow := Color(0.510, 0.463, 0.361, 1.0)
	var pitch := 22.0
	var half := Vector2(8.0, area.size.y * 0.5 - 12.0)
	var x := area.position.x + pitch * 0.5
	while x < area.end.x - 4.0:
		var centre := Vector2(x, area.get_center().y)
		_diamond(centre, half + Vector2.ONE * 2.0, WALL_EDGE)
		_diamond(centre, half, glow)
		# A catch of light down the left cheek of the cut, so the board has a thickness.
		_diamond(centre - Vector2(1.0, 0.0), half - Vector2(3.0, 3.0),
			glow.lightened(0.18))
		_diamond(centre, half - Vector2(4.0, 4.0), glow)
		x += pitch
	# The rails top and bottom, which is what the diamonds are cut between.
	draw_rect(Rect2(area.position, Vector2(area.size.x, 5.0)), WALL_LIT)
	draw_rect(Rect2(area.position.x, area.position.y + 5.0, area.size.x, 2.0), WALL_EDGE)
	draw_rect(Rect2(area.position.x, area.end.y - 5.0, area.size.x, 5.0), WALL_LIT)
	draw_rect(Rect2(area.position.x, area.end.y - 7.0, area.size.x, 2.0), WALL_EDGE)
	draw_rect(area, WALL_EDGE, false, 2.0)


## A filled diamond, a row of pixels at a time. There is no primitive for one and a
## polygon would be the only anti-aliased thing in the room.
func _diamond(centre: Vector2, half: Vector2, colour: Color) -> void:
	if half.x <= 0.0 or half.y <= 0.0:
		return
	var rows := int(half.y * 2.0)
	for row in range(rows):
		var taper := absf(float(row) - half.y) / half.y
		var width := roundf(half.x * (1.0 - taper))
		if width <= 0.0:
			continue
		draw_rect(Rect2(centre.x - width, centre.y - half.y + float(row),
			width * 2.0, 1.0), colour)


## Plank floor, running away from the wall. The boards are drawn as bands rather than in
## perspective: this is a side-on game and a receding floor would fight the flatness of
## everything else in it.
##
## IT USED TO READ AS BRICKWORK. Board ends the full height of a course, spaced evenly and
## offset course by course, is exactly the drawing of a stretcher bond -- so the floor of
## this house was a brick wall lying down. What separates a floor from a wall is that the
## joints between boards are HAIRLINE and the boards are long, so the ends are rare and the
## eye follows the length instead of the courses.
func _draw_floor() -> void:
	draw_rect(Rect2(0.0, floor_y, room_width, floor_depth), FLOOR)
	var y := floor_y
	var course := 0
	while y < floor_y + floor_depth:
		var height := 20.0
		# Each course a slightly different timber, because a floor is boards and not a
		# painted surface.
		var shade := FLOOR.lerp(FLOOR_LIT, float(_hash(course) % 100) / 240.0)
		draw_rect(Rect2(0.0, y, room_width, height), shade)
		_grain(Rect2(0.0, y + 3.0, room_width, height - 6.0),
			shade.lightened(0.06), shade.darkened(0.14))
		# The joint between this course and the last: one hairline, not a gap.
		draw_rect(Rect2(0.0, y, room_width, 1.0), WALL_EDGE)
		draw_rect(Rect2(0.0, y + 1.0, room_width, 1.0), shade.lightened(0.10))
		# Board ends, far apart and never twice in the same place.
		var x := float(_hash(course * 3 + 1) % 400)
		while x < room_width:
			draw_rect(Rect2(x, y + 2.0, 1.0, height - 3.0), WALL_EDGE)
			x += 300.0 + float(_hash(course * 7 + int(x)) % 220)
		y += height
		course += 1
	# LIGHT FALLS OUT OF THE DOORWAYS ONTO IT. Six lit openings along a wall and none of
	# them reaching the floor is the sort of thing nobody names and everybody feels: it is
	# what makes the capiz read as a source rather than as a pale panel, and it is the only
	# thing tying the boards to the wall above them.
	for index in range(door_count()):
		var centre := door_anchor(index)
		var spill := 0
		while spill < int(floor_depth):
			# Widening and fading as it goes, the way a pool of light out of a doorway does.
			var reach := float(spill) / floor_depth
			var half := DOOR_WIDTH * (0.5 + reach * 0.26)
			draw_rect(Rect2(centre - half, floor_y + float(spill), half * 2.0, 4.0),
				Color(0.929, 0.867, 0.694, 0.13 * (1.0 - reach)))
			spill += 4
	# And it darkens into the skirting, because that is where no light reaches at all.
	draw_rect(Rect2(0.0, floor_y, room_width, 3.0), Color(0.0, 0.0, 0.0, 0.34))
	draw_rect(Rect2(0.0, floor_y + 3.0, room_width, 3.0), Color(0.0, 0.0, 0.0, 0.20))
	draw_rect(Rect2(0.0, floor_y + 6.0, room_width, 4.0), Color(0.0, 0.0, 0.0, 0.10))


## The furniture along the wall, from the reference photograph: a caned settee under the
## middle of the room, a low side table with a jar on it, and a baul.
##
## It is scenery and carries no collision. The apo walks in front of all of it -- a room you
## have to jump over to cross would be a platforming level, and this one is a house.
## ON THE PIERS, NOT IN THE DOORWAYS. All three used to stand at the half-gaps between
## pictures, which is exactly where the doors went in -- a settee across a doorway and a
## chest in another. Under a picture is where a settee goes anyway, and it is what the
## reference photograph does.
func _draw_furniture() -> void:
	_draw_settee(Vector2(painting_anchor(1).x, floor_y))
	_draw_side_table(Vector2(painting_anchor(3).x + 56.0, floor_y))
	_draw_baul(Vector2(painting_anchor(4).x - 44.0, floor_y))


## A caned settee: dark frame, pale woven back and seat, turned legs.
##
## A metre fifty-five long and eighty-five centimetres to the top of the back, which is a
## settee. It used to be two and a half metres long and a metre and a half tall, which is
## a settee for someone the size of the room it was in.
func _draw_settee(at: Vector2) -> void:
	var width := 112.0
	var seat := 30.0
	var back := 31.0
	var half := width * 0.5

	# Legs, turned: a square block at the top, a waist, and a foot. Four of them, but the
	# back pair is only a hint -- they are behind the front pair and mostly hidden by the
	# stretcher, and drawing them in full puts a picket fence under the seat.
	for side: float in [-1.0, 1.0]:
		var leg := at.x + side * (half - 9.0)
		draw_rect(Rect2(leg - 8.0, at.y - seat, 5.0, seat), WALL_DARK)
		draw_rect(Rect2(leg - 3.0, at.y - seat, 6.0, 6.0), WALL_LIT)
		draw_rect(Rect2(leg - 2.0, at.y - seat + 6.0, 4.0, seat - 11.0), WALL)
		draw_rect(Rect2(leg - 3.0, at.y - 5.0, 6.0, 5.0), WALL_LIT)
	# The stretcher between them, low down where one goes.
	draw_rect(Rect2(at.x - half + 12.0, at.y - 9.0, width - 24.0, 3.0), WALL_DARK)

	# The seat: a caned panel in a frame, with the front rail proud of it.
	var seat_top := at.y - seat - 4.0
	_cane(Rect2(at.x - half + 4.0, seat_top, width - 8.0, 10.0))
	draw_rect(Rect2(at.x - half - 4.0, seat_top + 8.0, width + 8.0, 7.0), WALL_LIT)
	draw_rect(Rect2(at.x - half - 4.0, seat_top + 15.0, width + 8.0, 2.0), WALL_EDGE)
	draw_rect(Rect2(at.x - half - 4.0, seat_top, width + 8.0, 2.0), WALL_LIT)

	# Arms: a post at each end and a rail along the top of it.
	for side: float in [-1.0, 1.0]:
		var post := at.x + side * half
		draw_rect(Rect2(post - 4.0, seat_top - 14.0, 8.0, 16.0), WALL)
		draw_rect(Rect2(post - 4.0, seat_top - 14.0, 3.0, 16.0), WALL_LIT)
		draw_rect(Rect2(post - 6.0, seat_top - 18.0, 12.0, 5.0), WALL_LIT)
		draw_rect(Rect2(post - 6.0, seat_top - 13.0, 12.0, 2.0), WALL_EDGE)

	# The back: caning in a frame, with a crest rail over it.
	var frame := Rect2(at.x - half + 8.0, seat_top - back, width - 16.0, back - 4.0)
	draw_rect(frame, WALL)
	_cane(frame.grow(-4.0))
	draw_rect(frame, WALL_EDGE, false, 2.0)
	draw_rect(Rect2(frame.position.x - 4.0, frame.position.y - 6.0, frame.size.x + 8.0, 7.0),
		WALL_LIT)
	draw_rect(Rect2(frame.position.x - 4.0, frame.position.y + 1.0, frame.size.x + 8.0, 2.0),
		WALL_EDGE)


## Rattan caning: a woven panel, drawn as the STRANDS with the gaps dark between them.
##
## It used to be drawn the other way about -- pale lines ruled over a dark ground -- and at
## this size that fills in as a solid pale rectangle with a few dark specks, which is a
## cushion. What makes caning read is the holes.
func _cane(area: Rect2) -> void:
	if area.size.x <= 4.0 or area.size.y <= 4.0:
		return
	var straw := Color(0.729, 0.647, 0.478, 1.0)
	var straw_dark := Color(0.573, 0.498, 0.353, 1.0)
	draw_rect(area, straw)
	# ONE STRAND EVERY FOUR PIXELS, and only every second gap dark. At five with both lines
	# dark it came out half holes by area, which at this size is a typewriter keyboard: the
	# weave has to be finer than the eye can count for it to read as weave at all.
	var x := area.position.x + 2.0
	var column := 0
	while x < area.end.x:
		draw_rect(Rect2(x, area.position.y, 1.0, area.size.y),
			WALL_EDGE if column % 2 == 0 else straw_dark)
		x += 4.0
		column += 1
	var y := area.position.y + 2.0
	var row := 0
	while y < area.end.y:
		draw_rect(Rect2(area.position.x, y, area.size.x, 1.0),
			WALL_EDGE if row % 2 == 0 else straw_dark)
		y += 4.0
		row += 1


## A low table with a lidded jar on it -- the palayok in the corner of every old house.
## Seventy-five centimetres to the top, which is a table; the jar on it stands a foot high.
func _draw_side_table(at: Vector2) -> void:
	var top := Rect2(at.x - 30.0, at.y - 54.0, 60.0, 7.0)
	for side: float in [-1.0, 1.0]:
		draw_rect(Rect2(at.x + side * 23.0 - 3.0, at.y - 47.0, 6.0, 47.0), WALL_EDGE)
	draw_rect(top, WALL_LIT)
	draw_rect(top, WALL_EDGE, false, 2.0)
	# The jar: a belly, a shoulder and a lid, in fired clay.
	var clay := Color(0.518, 0.310, 0.192, 1.0)
	var clay_lit := Color(0.639, 0.412, 0.259, 1.0)
	draw_rect(Rect2(at.x - 13.0, at.y - 78.0, 26.0, 24.0), clay)
	draw_rect(Rect2(at.x - 11.0, at.y - 78.0, 7.0, 24.0), clay_lit)
	draw_rect(Rect2(at.x - 9.0, at.y - 84.0, 18.0, 7.0), clay)
	draw_rect(Rect2(at.x - 12.0, at.y - 88.0, 24.0, 5.0), clay_lit)
	draw_rect(Rect2(at.x - 13.0, at.y - 78.0, 26.0, 24.0), WALL_EDGE, false, 2.0)


## The baul: the carved chest at the foot of the wall, the same object Node 2 of Payyo hides
## the sketchbook page in.
func _draw_baul(at: Vector2) -> void:
	var body := Rect2(at.x - 38.0, at.y - 40.0, 76.0, 40.0)
	draw_rect(body, WALL)
	draw_rect(Rect2(body.position, Vector2(body.size.x, 9.0)), WALL_LIT)
	draw_rect(Rect2(body.position.x, body.position.y + 9.0, body.size.x, 2.0), WALL_EDGE)
	# Iron banding and a lock plate.
	for band: float in [0.25, 0.75]:
		draw_rect(Rect2(body.position.x + body.size.x * band - 3.0, body.position.y,
			6.0, body.size.y), Color(0.239, 0.227, 0.212, 1.0))
	draw_rect(Rect2(at.x - 5.0, body.position.y + 12.0, 10.0, 9.0), UISkin.GILT_DARK)
	draw_rect(body, WALL_EDGE, false, 2.0)


## Two chandeliers on the ceiling, over the gaps rather than over the pictures.
##
## The reference photo has one enormous cut-glass fixture and it is the first thing the eye
## goes to; at this scale a faithful copy would be a grey smear, so this is the SILHOUETTE of
## one -- a chain, a brass corona, candles, and a skirt of drops that catches the light.
func _draw_chandeliers() -> void:
	for slot: int in [0, 2]:
		_draw_chandelier(first_painting_x + painting_gap * (float(slot) + 0.5))


func _draw_chandelier(x: float) -> void:
	var hang := cornice_y() - 12.0
	var drop := 66.0
	var brass := UISkin.GILT_DARK
	var brass_lit := UISkin.GILT
	var crystal := Color(0.827, 0.882, 0.878, 0.85)
	# The chain.
	var link := hang
	while link < hang + drop - 10.0:
		draw_rect(Rect2(x - 2.0, link, 4.0, 5.0), brass)
		link += 9.0
	# The corona: two rings, the lower one wider, with a dark underside.
	#
	# IT HANGS IN FRONT OF A CALADO PANEL, which is the one place on this wall with light
	# behind it, so every pale part of the fixture needs something dark of its own to be
	# seen against or the two dissolve into each other -- a chandelier of white candles in
	# front of a row of lit cut-outs read as neither.
	var body := hang + drop
	draw_rect(Rect2(x - 9.0, body - 11.0, 18.0, 9.0), brass_lit)
	draw_rect(Rect2(x - 32.0, body - 2.0, 64.0, 2.0), Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(Rect2(x - 30.0, body, 60.0, 8.0), brass_lit)
	draw_rect(Rect2(x - 30.0, body + 8.0, 60.0, 3.0), brass)
	draw_rect(Rect2(x - 30.0, body + 11.0, 60.0, 2.0), Color(0.0, 0.0, 0.0, 0.40))
	# Candles standing on the ring, with a flame apiece.
	for offset: float in [-23.0, -8.0, 8.0, 23.0]:
		draw_rect(Rect2(x + offset - 4.0, body - 15.0, 7.0, 15.0),
			Color(0.0, 0.0, 0.0, 0.45))
		draw_rect(Rect2(x + offset - 3.0, body - 14.0, 5.0, 14.0),
			Color(0.914, 0.886, 0.800, 1.0))
		draw_rect(Rect2(x + offset - 2.0, body - 19.0, 4.0, 5.0),
			Color(1.0, 0.839, 0.400, 1.0))
		draw_rect(Rect2(x + offset - 1.0, body - 22.0, 2.0, 4.0),
			Color(1.0, 0.949, 0.729, 1.0))
	# The skirt of drops. Longest in the middle, so the fixture reads as a bell.
	for index in range(9):
		var offset := (float(index) - 4.0) * 7.0
		var length := 17.0 - absf(float(index) - 4.0) * 2.3
		draw_rect(Rect2(x + offset - 2.0, body + 10.0, 4.0, length), crystal)
		draw_rect(Rect2(x + offset - 2.0, body + 10.0, 2.0, length), Color(1, 1, 1, 0.55))
