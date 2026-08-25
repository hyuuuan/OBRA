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
	_draw_bays()
	_draw_windows()
	_draw_wainscot()
	_draw_floor()
	_draw_furniture()
	_draw_chandeliers()


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


## The tall panelled bays the pictures hang between. One bay per gap between paintings,
## plus one at each end, so a painting always has wall either side of it rather than
## landing on a joint.
func _draw_bays() -> void:
	var stile := 16.0
	var x := 0.0
	while x < room_width:
		var width := painting_gap * 0.5
		# The stile: the raised upright between two panels, lit down its left edge.
		var top := cornice_y()
		draw_rect(Rect2(x, top, stile, floor_y - top), WALL_LIT)
		draw_rect(Rect2(x, top, PIXEL, floor_y - top), WALL_EDGE)
		draw_rect(Rect2(x + stile - PIXEL, top, PIXEL, floor_y - top), WALL_EDGE)
		# The panel between stiles, sunk a shade darker.
		var panel := Rect2(x + stile, top + 10.0, maxf(0.0, width - stile),
			floor_y - top - 10.0)
		if panel.size.x > 0.0:
			draw_rect(panel, WALL_DARK)
			draw_rect(Rect2(panel.position, Vector2(panel.size.x, PIXEL)), WALL_EDGE)
			draw_rect(Rect2(panel.position, Vector2(PIXEL, panel.size.y)), WALL_EDGE)
		x += width


## The dado running the length of the room: a rail, then shorter panels beneath it.
func _draw_wainscot() -> void:
	var top := floor_y - wainscot_height
	draw_rect(Rect2(0.0, top, room_width, wainscot_height), WALL)
	# The rail, proud of the wall above it.
	draw_rect(Rect2(0.0, top, room_width, 10.0), WALL_LIT)
	draw_rect(Rect2(0.0, top, room_width, PIXEL), WALL_EDGE)
	draw_rect(Rect2(0.0, top + 10.0, room_width, PIXEL), WALL_EDGE)
	# Panels under it, one every half-gap so they march with the bays above.
	var pitch := painting_gap * 0.5
	var x := 8.0
	while x < room_width - 8.0:
		var panel := Rect2(x + 8.0, top + 20.0, pitch - 24.0, wainscot_height - 36.0)
		draw_rect(panel, WALL_DARK)
		draw_rect(Rect2(panel.position, Vector2(panel.size.x, PIXEL)), WALL_EDGE)
		draw_rect(Rect2(Vector2(panel.position.x, panel.end.y - PIXEL),
			Vector2(panel.size.x, PIXEL)), WALL_LIT)
		x += pitch
	# The skirting the floor meets.
	draw_rect(Rect2(0.0, floor_y - 12.0, room_width, 12.0), WALL_LIT)
	draw_rect(Rect2(0.0, floor_y - 12.0, room_width, PIXEL), WALL_EDGE)


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
	# It darkens into the skirting, because that is where no light reaches at all.
	draw_rect(Rect2(0.0, floor_y, room_width, 3.0), Color(0.0, 0.0, 0.0, 0.34))
	draw_rect(Rect2(0.0, floor_y + 3.0, room_width, 3.0), Color(0.0, 0.0, 0.0, 0.20))
	draw_rect(Rect2(0.0, floor_y + 6.0, room_width, 4.0), Color(0.0, 0.0, 0.0, 0.10))


## Capiz shutters: the sliding window panels of a bahay na bato, glazed with translucent
## shell instead of glass.
##
## They go in the gaps the paintings do not use, and they are the only bright thing on this
## wall -- the room is all one brown otherwise, and a wall of pictures with no light source
## in it looks like a corridor. The panes are drawn as a grid with a thin muntin between,
## because that grid IS the thing anybody recognises capiz by.
func _draw_windows() -> void:
	for slot: int in [1, 3]:
		var centre := first_painting_x + painting_gap * (float(slot) + 0.5)
		_draw_window(Vector2(centre, painting_y))


func _draw_window(at: Vector2) -> void:
	var panes := Vector2i(3, 2)
	var pane := Vector2(20.0, 24.0)
	var glazing := Vector2(float(panes.x) * pane.x, float(panes.y) * pane.y)
	var frame := 8.0
	var outer := Rect2(at - glazing * 0.5 - Vector2.ONE * frame, glazing + Vector2.ONE * frame * 2.0)
	# The sash, in the same wood as the wall so the window is part of the joinery.
	draw_rect(outer, WALL_LIT)
	draw_rect(outer, WALL_EDGE, false, PIXEL)
	draw_rect(Rect2(at - glazing * 0.5, glazing), CAPIZ_SHADE)
	for row in range(panes.y):
		for col in range(panes.x):
			var cell := Rect2(at - glazing * 0.5 + Vector2(float(col) * pane.x, float(row) * pane.y),
				pane - Vector2.ONE * PIXEL)
			# Daylight falls off down the window, so the top row is the brightest.
			draw_rect(cell, CAPIZ.lerp(CAPIZ_SHADE, float(row) / float(panes.y)))
			draw_rect(Rect2(cell.position, Vector2(cell.size.x, PIXEL)), Color(1, 1, 1, 0.35))


## The furniture along the wall, from the reference photograph: a caned settee under the
## middle of the room, a low side table with a jar on it, and a baul.
##
## It is scenery and carries no collision. The apo walks in front of all of it -- a room you
## have to jump over to cross would be a platforming level, and this one is a house.
func _draw_furniture() -> void:
	_draw_settee(Vector2(first_painting_x + painting_gap * 0.5, floor_y))
	_draw_side_table(Vector2(first_painting_x + painting_gap * 2.5, floor_y))
	_draw_baul(Vector2(first_painting_x + painting_gap * 3.5, floor_y))


## A caned settee: dark frame, pale woven back and seat, turned legs.
##
## A metre fifty-five long and eighty-five centimetres to the top of the back, which is a
## settee. It used to be two and a half metres long and a metre and a half tall, which is
## a settee for someone the size of the room it was in.
func _draw_settee(at: Vector2) -> void:
	var width := 112.0
	var seat := 30.0
	var back := 31.0
	var cane := Color(0.729, 0.647, 0.478, 1.0)
	var cane_dark := Color(0.573, 0.498, 0.353, 1.0)
	# Legs first so the frame sits over them.
	for side: float in [-1.0, 1.0]:
		draw_rect(Rect2(at.x + side * (width * 0.5 - 10.0) - 3.0, at.y - seat, 6.0, seat),
			WALL_EDGE)
	var back_rect := Rect2(at.x - width * 0.5, at.y - seat - back, width, back)
	draw_rect(back_rect, cane_dark)
	# The caning: a lattice, which at this size is two sets of ruled lines.
	var step := 8.0
	var line := back_rect.position.x + step
	while line < back_rect.end.x:
		draw_rect(Rect2(line, back_rect.position.y + PIXEL, PIXEL, back_rect.size.y - PIXEL * 2.0),
			cane)
		line += step
	var rung := back_rect.position.y + step
	while rung < back_rect.end.y:
		draw_rect(Rect2(back_rect.position.x, rung, back_rect.size.x, PIXEL), cane)
		rung += step
	draw_rect(back_rect, WALL_EDGE, false, PIXEL)
	# The seat, proud of the back.
	var seat_rect := Rect2(at.x - width * 0.5 - 5.0, at.y - seat, width + 10.0, seat * 0.5)
	draw_rect(seat_rect, WALL)
	draw_rect(Rect2(seat_rect.position, Vector2(seat_rect.size.x, PIXEL)), WALL_LIT)
	draw_rect(seat_rect, WALL_EDGE, false, PIXEL)


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
	# The corona: two rings, the lower one wider.
	var body := hang + drop
	draw_rect(Rect2(x - 9.0, body - 11.0, 18.0, 9.0), brass_lit)
	draw_rect(Rect2(x - 30.0, body, 60.0, 8.0), brass_lit)
	draw_rect(Rect2(x - 30.0, body + 8.0, 60.0, 2.0), brass)
	# Candles standing on the ring, with a flame apiece.
	for offset: float in [-23.0, -8.0, 8.0, 23.0]:
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
