class_name PiyestaPlaza2D
extends Node2D
## The ground the plaza stands on. Everything above it is the delivered painting.
##
## ⚠ THE PAINTING IS THE PLAZA AGAIN, AND THIS TIME IT IS CUT.
##
## This went round three times. First the plate was pasted whole with collision fitted under
## it, and it read as two platforms -- because the painting is a VISTA with a low wall behind
## the dancers AND a grass verge over a retaining wall in front of them, about sixty pixels of
## cobble between, and the apo is ninety-six tall. He spans the strip, with a wall above his
## knees and another below them. Both walls are IN THE PICTURE, so no collision change could
## fix it.
##
## Then the whole plaza was authored from scratch to get around that, and it was never as good
## as the plate.
##
## So: the plate, CUT AT THE PAINTED DANCERS' FEET (`tools/build_plaza.py`). The near verge and
## its wall are gone with the crop. What is left -- sky, clouds, hills, the church, the kiosko,
## the arch, the palms, the dancers -- all stands ON the cut, and this draws the ground below
## it. One ground line, and it is the line the artist stood four dancers on.
##
## ⚠ NOTHING DRAWS IN FRONT OF THE PLAYER. There is no kerb and no second plate. The thing
## that used to occlude his feet was the half of the painting that had to go, and adding an
## authored one back is how the doubling returns.

## Where the player's feet go, in this node's own space. The backdrop's bottom edge is here.
@export var ground := 0.0
## How far the plaza runs. The walls stand just outside these.
@export var from_x := 80.0
@export var to_x := 1790.0

## How deep the paving strip is: the top face of the plaza, seen at a glancing angle. Shallow,
## because it is a surface the player stands ON, not a slab they stand in front of.
const PAVING_DEPTH := 34.0
## And how far the retaining wall runs before the town below it takes over.
##
## ⚠ TUNED AGAINST THE CAMERA, not against how a wall looks on its own. The camera's
## `world_bottom_y` stops it at 722, which leaves about a hundred and sixty units under the
## walk line at rest and roughly twice that at the top of a jump.
##
## IT WAS 170 AND THAT IS EXACTLY THE VISIBLE BAND, so the wall filled every pixel under the
## plaza and the town below it -- three courses of hazed rooftops, generated, imported and
## drawn -- was never once on screen. What the player actually saw was the wall's own shadow
## ramp: a flat dark bar across the bottom eighth of every shot, under a painting that is the
## brightest thing in the game. Ninety-six puts the roofs back inside the frame, so the band
## is DISTANCE rather than a black edge, and a jump shows more of the town rather than more
## of the dark.
const WALL_DEPTH := 96.0
## The colour distance goes toward here: the plaza's own sky, a little greyer. Everything
## below the terrace is lifted toward it rather than multiplied by it -- see _draw.
const HAZE := Color(0.757, 0.816, 0.851, 1.0)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -90
	queue_redraw()


func _draw() -> void:
	var left := from_x - 900.0
	var width := (to_x - from_x) + 1800.0
	# The paving, in three cuts so it does not repeat every metre.
	PiyestaTiles.fill_varied(self, Rect2(left, ground, width, PAVING_DEPTH),
		["paving_a", "paving_b", "paving_c"])
	draw_rect(Rect2(left, ground, width, 3.0), Color(1.0, 0.94, 0.82, 0.20))
	# The wall that retains it, going into shadow as it drops.
	PiyestaTiles.fill(self, Rect2(left, ground + PAVING_DEPTH, width, WALL_DEPTH),
		"retaining")
	draw_rect(Rect2(left, ground + PAVING_DEPTH, width, 4.0), Color(0.0, 0.0, 0.0, 0.45))
	# It falls into shadow as it drops, so the eye stays on the plaza rather than on the wall.
	# ⚠ FIVE STACKED RECTS OF IT WAS TOO MUCH BY HALF. Each one reached WALL_DEPTH below its
	# own start, so the last four overhung the wall entirely and piled up on the town under
	# it -- the bottom of the frame ended up at about 0.55 alpha of near-black, which is the
	# flat bar this band used to be. Three, shallower, and stopping where the wall does.
	for step in range(2):
		var t := float(step)
		var top := ground + PAVING_DEPTH + 34.0 + t * 30.0
		draw_rect(Rect2(left, top, width, ground + PAVING_DEPTH + WALL_DEPTH - top),
			Color(0.055, 0.047, 0.043, 0.08 + 0.05 * t))
	# ⚠ AND THEN THE TOWN, BECAUSE THE CAMERA INSISTS. The vertical follow keeps the player
	# near the middle of the frame, so about four hundred units below their feet is always on
	# screen -- and four hundred units of retaining wall is a blank band across the bottom
	# third of every shot. The plaza stands on high ground in a city; what is under it is the
	# rest of the city, receding and hazing out.
	var roofs := PiyestaTiles.size_of("rooftops_a")
	var below := ground + PAVING_DEPTH + WALL_DEPTH
	if roofs.y > 0.0:
		var cuts: Array = ["rooftops_a", "rooftops_b", "rooftops_c"]
		# ⚠ A MODULATE CANNOT MAKE ANYTHING PALER, AND THAT IS WHY THIS BAND WAS BLACK.
		#
		# The intent was right and is worth keeping: this is DISTANCE, and distance is pale --
		# drawn at full strength a row of red roofs across the bottom of every shot pulls the
		# eye off the plaza. But it was done by passing a pale blue-grey as the `modulate`,
		# and a modulate MULTIPLIES: the roof ramp starts at #241412, so multiplying it by
		# 0.72/0.80/0.88 and blending at 0.85 alpha gave #2B1C19. Sampled down the frame, the
		# bottom eighth of Piyesta was reading #282013 -- a black bar under the brightest
		# painting in the game, which is exactly what the haze was supposed to prevent.
		#
		# So the roofs are drawn as they are, and the haze is a LAYER OVER them in the sky's
		# own colour, deepening as it recedes. Adding light is the only way to make something
		# paler, and a rect on top is how you add light.
		for row in range(3):
			PiyestaTiles.fill_varied(self, Rect2(left + float(row) * 47.0,
				below + float(row) * roofs.y * 0.72, width, roofs.y),
				[cuts[row % 3], cuts[(row + 1) % 3], cuts[(row + 2) % 3]])
		for step in range(6):
			var t := float(step) / 5.0
			draw_rect(Rect2(left, below + t * roofs.y * 1.8, width, roofs.y * 1.8),
				Color(HAZE.r, HAZE.g, HAZE.b, 0.30 + 0.10 * t))
		draw_rect(Rect2(left, below + roofs.y * 2.2, width, 900.0), HAZE)
