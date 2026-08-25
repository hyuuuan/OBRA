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

## How long the wall is and where the floor sits under it.
##
## THE ROOM IS A ROOM, NOT A HALL. The first cut put the ceiling four hundred pixels above
## the pictures and gave the floor four hundred below them, so two thirds of the screen was
## empty wall and bare boards and the apo crossed it like an ant. Everything here is now
## sized to what a camera at 1.25 shows at once: ceiling at the top of frame, pictures at
## eye height, and the floor a strip along the bottom -- the same proportion of ground to
## air the levels have.
@export var room_width: float = 2700.0
@export var ceiling_y: float = -60.0
@export var floor_y: float = 560.0
## How deep the floorboards run before the frame ends.
@export var floor_depth: float = 150.0
## How far up the wall the wainscot panelling reaches.
@export var wainscot_height: float = 150.0
## Where the paintings hang, measured to their middle.
@export var painting_y: float = 190.0
## The first painting's centre, and the gap to the next.
@export var first_painting_x: float = 420.0
## Wide enough that a shutter fits between two pictures. At 400 the gap between frames was
## 120px and the window was 164 -- it hung across the corner of the Dagat painting, which is
## the sort of thing that only shows up when you look at the room.
@export var painting_gap: float = 470.0

## Hardwood, in four tones. Narra darkens with age and these are all one hue apart on
## purpose -- a wall of contrasting browns reads as a woodpile rather than as joinery.
const WALL_DARK := Color(0.208, 0.118, 0.063, 1.0)    # 351E10  the shadowed bay
const WALL := Color(0.310, 0.180, 0.094, 1.0)         # 4F2E18  the field
const WALL_LIT := Color(0.396, 0.239, 0.129, 1.0)     # 653D21  the lit stile
const WALL_EDGE := Color(0.129, 0.071, 0.039, 1.0)    # 21120A  the shadow line
## The floor, a shade cooler than the wall so the two do not merge at the skirting.
const FLOOR := Color(0.278, 0.157, 0.082, 1.0)        # 472815
const FLOOR_LIT := Color(0.345, 0.204, 0.110, 1.0)    # 58341C
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


func _draw_wall() -> void:
	draw_rect(Rect2(0.0, ceiling_y, room_width, floor_y - ceiling_y), WALL)
	# The pressed-tin ceiling of the reference photo: a pale band above the picture rail,
	# ruled into panels. It is what makes the room read as a storey rather than as a
	# backdrop, and it is what the chandeliers hang from.
	draw_rect(Rect2(0.0, ceiling_y, room_width, 40.0), Color(0.435, 0.455, 0.400, 1.0))
	var rib := 0.0
	while rib < room_width:
		draw_rect(Rect2(rib, ceiling_y, PIXEL, 40.0), Color(0.318, 0.337, 0.290, 1.0))
		rib += 56.0
	draw_rect(Rect2(0.0, ceiling_y + 40.0, room_width, 12.0), WALL_LIT)
	draw_rect(Rect2(0.0, ceiling_y + 52.0, room_width, PIXEL), WALL_EDGE)


## The tall panelled bays the pictures hang between. One bay per gap between paintings,
## plus one at each end, so a painting always has wall either side of it rather than
## landing on a joint.
func _draw_bays() -> void:
	var stile := 28.0
	var x := 0.0
	while x < room_width:
		var width := painting_gap * 0.5
		# The stile: the raised upright between two panels, lit down its left edge.
		var top := ceiling_y + 56.0
		draw_rect(Rect2(x, top, stile, floor_y - top), WALL_LIT)
		draw_rect(Rect2(x, top, PIXEL, floor_y - top), WALL_EDGE)
		draw_rect(Rect2(x + stile - PIXEL, top, PIXEL, floor_y - top), WALL_EDGE)
		# The panel between stiles, sunk a shade darker.
		var panel := Rect2(x + stile, top + 16.0, maxf(0.0, width - stile),
			floor_y - top - 16.0)
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
	draw_rect(Rect2(0.0, top, room_width, 20.0), WALL_LIT)
	draw_rect(Rect2(0.0, top, room_width, PIXEL), WALL_EDGE)
	draw_rect(Rect2(0.0, top + 20.0, room_width, PIXEL), WALL_EDGE)
	# Panels under it, one every half-gap so they march with the bays above.
	var pitch := painting_gap * 0.5
	var x := 16.0
	while x < room_width - 16.0:
		var panel := Rect2(x + 12.0, top + 44.0, pitch - 40.0, wainscot_height - 76.0)
		draw_rect(panel, WALL_DARK)
		draw_rect(Rect2(panel.position, Vector2(panel.size.x, PIXEL)), WALL_EDGE)
		draw_rect(Rect2(Vector2(panel.position.x, panel.end.y - PIXEL),
			Vector2(panel.size.x, PIXEL)), WALL_LIT)
		x += pitch
	# The skirting the floor meets.
	draw_rect(Rect2(0.0, floor_y - 24.0, room_width, 24.0), WALL_LIT)
	draw_rect(Rect2(0.0, floor_y - 24.0, room_width, PIXEL), WALL_EDGE)


## Plank floor, running away from the wall. The boards are drawn as bands rather than in
## perspective: this is a side-on game and a receding floor would fight the flatness of
## everything else in it.
func _draw_floor() -> void:
	draw_rect(Rect2(0.0, floor_y, room_width, floor_depth), FLOOR)
	var y := floor_y + 12.0
	var band := 0
	while y < floor_y + floor_depth:
		draw_rect(Rect2(0.0, y, room_width, PIXEL), FLOOR_LIT if band % 2 == 0 else WALL_EDGE)
		y += 28.0
		band += 1
	# The board ends. Only one per board row and offset by a different amount on each, so
	# the floor reads as planks laid in courses -- an even grid of them reads as tiling, which
	# is what a first pass at this looked like.
	var y2 := floor_y + 12.0
	var course := 0
	while y2 < floor_y + floor_depth:
		var x := float((course * 97) % 240)
		while x < room_width:
			draw_rect(Rect2(x, y2, PIXEL, 28.0), WALL_EDGE)
			x += 380.0
		y2 += 28.0
		course += 1


## Capiz shutters: the sliding window panels of a bahay na bato, glazed with translucent
## shell instead of glass.
##
## They go in the gaps the paintings do not use, and they are the only bright thing on this
## wall -- the room is all one brown otherwise, and a wall of pictures with no light source
## in it looks like a corridor. The panes are drawn as a grid with a thin muntin between,
## because that grid IS the thing anybody recognises capiz by.
func _draw_windows() -> void:
	for slot: int in [1, 4]:
		var centre := first_painting_x + painting_gap * (float(slot) + 0.5)
		_draw_window(Vector2(centre, painting_y + 6.0))


func _draw_window(at: Vector2) -> void:
	var panes := Vector2i(3, 2)
	var pane := Vector2(30.0, 36.0)
	var glazing := Vector2(float(panes.x) * pane.x, float(panes.y) * pane.y)
	var frame := 14.0
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
func _draw_settee(at: Vector2) -> void:
	var width := 176.0
	var seat := 46.0
	var back := 64.0
	var cane := Color(0.729, 0.647, 0.478, 1.0)
	var cane_dark := Color(0.573, 0.498, 0.353, 1.0)
	# Legs first so the frame sits over them.
	for side: float in [-1.0, 1.0]:
		draw_rect(Rect2(at.x + side * (width * 0.5 - 14.0) - 5.0, at.y - seat, 10.0, seat),
			WALL_EDGE)
	var back_rect := Rect2(at.x - width * 0.5, at.y - seat - back, width, back)
	draw_rect(back_rect, cane_dark)
	# The caning: a lattice, which at this size is two sets of ruled lines.
	var step := 12.0
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
	var seat_rect := Rect2(at.x - width * 0.5 - 8.0, at.y - seat, width + 16.0, seat * 0.5)
	draw_rect(seat_rect, WALL)
	draw_rect(Rect2(seat_rect.position, Vector2(seat_rect.size.x, PIXEL)), WALL_LIT)
	draw_rect(seat_rect, WALL_EDGE, false, PIXEL)


## A low table with a lidded jar on it -- the palayok in the corner of every old house.
func _draw_side_table(at: Vector2) -> void:
	var top := Rect2(at.x - 52.0, at.y - 62.0, 104.0, 12.0)
	for side: float in [-1.0, 1.0]:
		draw_rect(Rect2(at.x + side * 40.0 - 5.0, at.y - 50.0, 10.0, 50.0), WALL_EDGE)
	draw_rect(top, WALL_LIT)
	draw_rect(top, WALL_EDGE, false, PIXEL)
	# The jar: a belly, a shoulder and a lid, in fired clay.
	var clay := Color(0.518, 0.310, 0.192, 1.0)
	var clay_lit := Color(0.639, 0.412, 0.259, 1.0)
	draw_rect(Rect2(at.x - 22.0, at.y - 104.0, 44.0, 42.0), clay)
	draw_rect(Rect2(at.x - 18.0, at.y - 104.0, 12.0, 42.0), clay_lit)
	draw_rect(Rect2(at.x - 16.0, at.y - 114.0, 32.0, 12.0), clay)
	draw_rect(Rect2(at.x - 20.0, at.y - 120.0, 40.0, 8.0), clay_lit)
	draw_rect(Rect2(at.x - 22.0, at.y - 104.0, 44.0, 42.0), WALL_EDGE, false, PIXEL)


## The baul: the carved chest at the foot of the wall, the same object Node 2 of Payyo hides
## the sketchbook page in.
func _draw_baul(at: Vector2) -> void:
	var body := Rect2(at.x - 66.0, at.y - 58.0, 132.0, 58.0)
	draw_rect(body, WALL)
	draw_rect(Rect2(body.position, Vector2(body.size.x, 14.0)), WALL_LIT)
	draw_rect(Rect2(body.position.x, body.position.y + 14.0, body.size.x, PIXEL), WALL_EDGE)
	# Iron banding and a lock plate.
	for band: float in [0.25, 0.75]:
		draw_rect(Rect2(body.position.x + body.size.x * band - 5.0, body.position.y,
			10.0, body.size.y), Color(0.239, 0.227, 0.212, 1.0))
	draw_rect(Rect2(at.x - 9.0, body.position.y + 18.0, 18.0, 16.0), UISkin.GILT_DARK)
	draw_rect(body, WALL_EDGE, false, PIXEL)


## Two chandeliers on the ceiling, over the gaps rather than over the pictures.
##
## The reference photo has one enormous cut-glass fixture and it is the first thing the eye
## goes to; at this scale a faithful copy would be a grey smear, so this is the SILHOUETTE of
## one -- a chain, a brass corona, candles, and a skirt of drops that catches the light.
func _draw_chandeliers() -> void:
	for slot: int in [0, 3]:
		_draw_chandelier(first_painting_x + painting_gap * (float(slot) + 0.5))


func _draw_chandelier(x: float) -> void:
	var hang := ceiling_y + 52.0
	var drop := 96.0
	var brass := UISkin.GILT_DARK
	var brass_lit := UISkin.GILT
	var crystal := Color(0.827, 0.882, 0.878, 0.85)
	# The chain.
	var link := hang
	while link < hang + drop - 16.0:
		draw_rect(Rect2(x - 3.0, link, 6.0, 8.0), brass)
		link += 14.0
	# The corona: two rings, the lower one wider.
	var body := hang + drop
	draw_rect(Rect2(x - 14.0, body - 18.0, 28.0, 14.0), brass_lit)
	draw_rect(Rect2(x - 46.0, body, 92.0, 12.0), brass_lit)
	draw_rect(Rect2(x - 46.0, body + 12.0, 92.0, PIXEL), brass)
	# Candles standing on the ring, with a flame apiece.
	for offset: float in [-36.0, -12.0, 12.0, 36.0]:
		draw_rect(Rect2(x + offset - 4.0, body - 22.0, 8.0, 22.0), Color(0.914, 0.886, 0.800, 1.0))
		draw_rect(Rect2(x + offset - 3.0, body - 30.0, 6.0, 8.0), Color(1.0, 0.839, 0.400, 1.0))
		draw_rect(Rect2(x + offset - 2.0, body - 34.0, 4.0, 5.0), Color(1.0, 0.949, 0.729, 1.0))
	# The skirt of drops. Longest in the middle, so the fixture reads as a bell.
	for index in range(9):
		var offset := (float(index) - 4.0) * 11.0
		var length := 26.0 - absf(float(index) - 4.0) * 3.5
		draw_rect(Rect2(x + offset - 3.0, body + 14.0, 6.0, length), crystal)
		draw_rect(Rect2(x + offset - 3.0, body + 14.0, PIXEL, length), Color(1, 1, 1, 0.55))
