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
const WALL_DEPTH := 210.0


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
	for step in range(5):
		var t := float(step) / 4.0
		draw_rect(Rect2(left, ground + PAVING_DEPTH + 30.0 + t * 44.0, width, WALL_DEPTH),
			Color(0.055, 0.047, 0.043, 0.13 + 0.09 * t))
	# ⚠ AND THEN THE TOWN, BECAUSE THE CAMERA INSISTS. The vertical follow keeps the player
	# near the middle of the frame, so about four hundred units below their feet is always on
	# screen -- and four hundred units of retaining wall is a blank band across the bottom
	# third of every shot. The plaza stands on high ground in a city; what is under it is the
	# rest of the city, receding and hazing out.
	var roofs := PiyestaTiles.size_of("rooftops_a")
	var below := ground + PAVING_DEPTH + WALL_DEPTH
	if roofs.y > 0.0:
		var cuts: Array = ["rooftops_a", "rooftops_b", "rooftops_c"]
		# ⚠ HAZED HARD, and much further toward the sky than looks right on paper. Drawn at
		# anything like full strength this band is a row of red roofs across the bottom third
		# of every shot, and the eye goes to it instead of to the plaza. It is DISTANCE, and
		# distance is pale.
		for row in range(3):
			var t := float(row) / 2.0
			var haze := Color(
				lerpf(0.72, 0.86, t), lerpf(0.80, 0.90, t), lerpf(0.88, 0.96, t),
				lerpf(0.85, 0.45, t))
			PiyestaTiles.fill_varied(self, Rect2(left + float(row) * 47.0,
				below + float(row) * roofs.y * 0.72, width, roofs.y),
				[cuts[row % 3], cuts[(row + 1) % 3], cuts[(row + 2) % 3]], haze)
		draw_rect(Rect2(left, below + roofs.y * 2.2, width, 900.0),
			Color(0.686, 0.796, 0.878, 1.0))
