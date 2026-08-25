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
@export var room_width: float = 2560.0
@export var floor_y: float = 620.0
## How far up the wall the wainscot panelling reaches.
@export var wainscot_height: float = 190.0
## Where the paintings hang, measured to their middle.
@export var painting_y: float = 300.0
## The first painting's centre, and the gap to the next.
@export var first_painting_x: float = 480.0
@export var painting_gap: float = 420.0

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
	_draw_wainscot()
	_draw_floor()


func _draw_wall() -> void:
	draw_rect(Rect2(0.0, -400.0, room_width, floor_y + 400.0), WALL)
	# A ceiling line, so the wall has a top rather than running off into nothing.
	draw_rect(Rect2(0.0, -400.0, room_width, 24.0), WALL_EDGE)
	draw_rect(Rect2(0.0, -376.0, room_width, 8.0), WALL_LIT)


## The tall panelled bays the pictures hang between. One bay per gap between paintings,
## plus one at each end, so a painting always has wall either side of it rather than
## landing on a joint.
func _draw_bays() -> void:
	var stile := 28.0
	var x := 0.0
	while x < room_width:
		var width := painting_gap * 0.5
		# The stile: the raised upright between two panels, lit down its left edge.
		draw_rect(Rect2(x, -368.0, stile, floor_y + 368.0), WALL_LIT)
		draw_rect(Rect2(x, -368.0, PIXEL, floor_y + 368.0), WALL_EDGE)
		draw_rect(Rect2(x + stile - PIXEL, -368.0, PIXEL, floor_y + 368.0), WALL_EDGE)
		# The panel between stiles, sunk a shade darker.
		var panel := Rect2(x + stile, -344.0, maxf(0.0, width - stile), floor_y + 320.0)
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
	draw_rect(Rect2(0.0, floor_y, room_width, 400.0), FLOOR)
	var y := floor_y + 12.0
	var band := 0
	while y < floor_y + 400.0:
		draw_rect(Rect2(0.0, y, room_width, PIXEL), FLOOR_LIT if band % 2 == 0 else WALL_EDGE)
		y += 28.0
		band += 1
	# The board ends. Only one per board row and offset by a different amount on each, so
	# the floor reads as planks laid in courses -- an even grid of them reads as tiling, which
	# is what a first pass at this looked like.
	var y2 := floor_y + 12.0
	var course := 0
	while y2 < floor_y + 400.0:
		var x := float((course * 97) % 240)
		while x < room_width:
			draw_rect(Rect2(x, y2, PIXEL, 28.0), WALL_EDGE)
			x += 380.0
		y2 += 28.0
		course += 1
