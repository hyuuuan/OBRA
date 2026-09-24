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

## Like Payyo's terraces, the detailed edge keeps its native proportions and a separate
## repeating fill carries the ground below it. Never stretch the retaining tile to fill the
## camera: that makes every stone look vertically warped.
const PAVING_DEPTH := 34.0
const WALL_DEPTH := 96.0
const FILL_DEPTH := 64.0
const STONE_FILL := preload("res://assets/Level2/plaza/stone_fill.png")
const STONE_REPEAT := 320.0
## The fallback is deliberate. A missing or stale Godot texture import must leave an obvious
## solid floor rather than exposing SkyFill below the player's feet again.
const PAVING_FALLBACK := Color(0.86, 0.69, 0.39, 1.0)
const WALL_FALLBACK := Color(0.16, 0.12, 0.08, 1.0)
const FILL_FALLBACK := Color(0.13, 0.09, 0.055, 1.0)
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
	var paving_rect := Rect2(left, ground, width, PAVING_DEPTH)
	var wall_rect := Rect2(left, ground + PAVING_DEPTH, width, WALL_DEPTH)
	var fill_band := Rect2(left, wall_rect.end.y, width, FILL_DEPTH)
	# Draw the guaranteed floor first, then let the tiles replace it wherever they load.
	draw_rect(paving_rect, PAVING_FALLBACK)
	draw_rect(wall_rect, WALL_FALLBACK)
	draw_rect(fill_band, FILL_FALLBACK)
	PiyestaTiles.fill_varied(self, paving_rect, ["paving_a", "paving_b", "paving_c"])
	# One continuous stone material beneath the decorative edge, at a fixed square scale.
	var fill_rect := Rect2(left, wall_rect.position.y + 48.0, width,
		WALL_DEPTH + FILL_DEPTH - 48.0)
	var points := PackedVector2Array([fill_rect.position,
		Vector2(fill_rect.end.x, fill_rect.position.y), fill_rect.end,
		Vector2(fill_rect.position.x, fill_rect.end.y)])
	var uv := PackedVector2Array()
	for point in points:
		uv.append(point / STONE_REPEAT)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	draw_polygon(points, PackedColorArray([Color.WHITE]), uv, STONE_FILL)
	_draw_retaining_edge(wall_rect)
	# ⚠ AND THEN THE TOWN, BECAUSE THE CAMERA INSISTS. The vertical follow keeps the player
	# near the middle of the frame, so about four hundred units below their feet is always on
	# screen -- and four hundred units of retaining wall is a blank band across the bottom
	# third of every shot. The plaza stands on high ground in a city; what is under it is the
	# rest of the city, receding and hazing out.
	var roofs := PiyestaTiles.size_of("rooftops_a")
	var below := ground + PAVING_DEPTH + WALL_DEPTH + FILL_DEPTH
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


func _draw_retaining_edge(rect: Rect2) -> void:
	var tile := PiyestaTiles.get_tile("retaining")
	if tile == null:
		return
	var pixels := tile.get_image()
	# Follow the existing mortar near the last stone course. A stepped two-pixel edge
	# lets the new stone field meet the old course without a straight bottom border.
	for column in range(0, int(rect.size.x), 2):
		var source_x := column % tile.get_width()
		var cut := 78
		var best := INF
		for row in range(66, 92):
			var tone := pixels.get_pixel(source_x, row)
			var score := tone.r + tone.g + tone.b + absf(float(row - 80)) * 0.004
			if score < best:
				best = score
				cut = row
		var slice_width := minf(2.0, rect.size.x - column)
		draw_texture_rect_region(tile,
			Rect2(rect.position + Vector2(column, 0), Vector2(slice_width, cut)),
			Rect2(source_x, 0, slice_width, cut))
