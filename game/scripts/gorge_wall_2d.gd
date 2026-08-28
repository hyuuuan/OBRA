class_name GorgeWall2D
extends Node2D
## The inside of Ang Tulay's gorge: two rock faces and the dark between them.
##
## THERE WAS NOTHING HERE, AND THAT IS WHAT "THE BRIDGE LOOKS ODDLY BROKEN" WAS. The gorge is
## a 560-pixel hole in the terrain with the level's deepest drop under it, and it was drawn
## by not drawing anything -- so what the player saw between the two bridge posts was the
## PARALLAX BACKGROUND: mountains, sky, and a painted terrace with a stone staircase on it,
## at almost the same brightness as the ground they were standing on. A gorge you can see
## blue sky and green hills through is not a gorge. It reads as a place where the level ran
## out, and the ruined bridge standing over it reads as broken art rather than as a broken
## bridge.
##
## So the hole gets an inside: the near lip's rock face going down on each side, strata
## across them, and the shaft between darkening with depth. It carries NO collision -- the
## gorge is still a gorge and the routes across it are still the only way over.
##
## Drawn in code rather than tiled, for the reason ART_PLACEHOLDERS gives about this atlas:
## its regions are terrace SLICES rather than materials, so a wall filled with one comes out
## wearing a band of soil and a fringe of grass halfway down a cliff.

## The hole: x from the near lip to the far one, y from the terrace top to the valley floor.
@export var opening := Rect2(0.0, 0.0, 560.0, 440.0)
## How far into the opening each rock face reaches. The two do not meet -- what is between
## them is the drop, and the drop is the point. ZERO draws the back and no faces, which is
## what a paddy wants: a pit cut into a terrace has a wall behind it and no chasm.
@export var face_width := 96.0
## The back, top and bottom. Exported because the two things in this level that are holes in
## the ground are holes of different kinds -- the gorge is rock going down a long way, and a
## paddy is wet earth a metre and a half behind the water. Both were see-through.
@export var shaft_top := Color(0.212, 0.196, 0.169, 1.0)
@export var shaft_bottom := Color(0.106, 0.098, 0.090, 1.0)
## WHETHER THIS HOLE HAS A BOTTOM YOU STAND ON. The gorge does -- the cave, the flower and
## the sign are all down there and the player walks to them -- and a paddy does not: what is
## under a paddy is water, and drawing a rubble floor behind it would put a beach in it.
##
## Without this the gorge floor was the shaft colour running off the bottom of the screen.
## The player and Lolo stood on an undifferentiated dark slab with a signboard and two tufts
## of grass on it, which is what "it seems like I'm walking to something" is describing:
## there was no floor, so there was no room, so there was nothing to have arrived at.
@export var has_a_floor := false
## Where the cave mouth is cut into the far wall, in this node's space, and how big. Zero
## width draws none. The gate and the flower stand in front of it -- before this the "cave"
## the gate talks about did not exist as anything you could see.
@export var cave_at := Vector2.ZERO
@export var cave_size := Vector2.ZERO

const EDGE := Color(0.106, 0.086, 0.067, 1.0)       # 1B1611
const ROCK_DARK := Color(0.208, 0.180, 0.145, 1.0)  # 352E25
const ROCK := Color(0.310, 0.267, 0.208, 1.0)       # 4F4435
const ROCK_LIT := Color(0.412, 0.353, 0.271, 1.0)   # 695A45
const MOSS := Color(0.243, 0.318, 0.180, 1.0)       # 3E512E
## The shaft. Not black: a hole painted black on a bright terrace is a sticker. This is the
## colour rock is when the only light reaching it has come a long way down.
## The far wall's own courses, drawn across the shaft. Without them the drop is a flat dark
## rectangle -- which reads as a hole cut in the picture rather than as rock a long way back.
const STRATA := Color(0.267, 0.243, 0.208, 1.0)
## The floor of the gorge: rubble that has come off the walls, packed by the water that runs
## through here after rain.
const RUBBLE := Color(0.286, 0.259, 0.216, 1.0)
const RUBBLE_LIT := Color(0.376, 0.341, 0.282, 1.0)
const RUBBLE_DARK := Color(0.180, 0.161, 0.133, 1.0)
const SILT := Color(0.227, 0.208, 0.169, 1.0)
## Inside the cave, which is darker than the shaft because nothing reaches into it.
const CAVE_DARK := Color(0.043, 0.039, 0.035, 1.0)
const CAVE_LIP := Color(0.153, 0.137, 0.114, 1.0)
## Daylight coming down the gorge's own mouth. One soft column, so the bottom is not lit
## evenly and the eye knows which way is out.
const DAYLIGHT := Color(0.788, 0.827, 0.729, 1.0)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Behind everything that stands in the gorge -- the bridge posts, the route ledges, the
	# cave mouth and the flower -- and in front of the parallax it exists to hide.
	z_index = -6
	queue_redraw()


func _draw() -> void:
	_draw_shaft()
	if cave_size.x > 0.0:
		_draw_cave()
	if has_a_floor:
		_draw_floor()
	if face_width <= 0.0:
		return
	_draw_face(true)
	_draw_face(false)


## The hollow the gate is standing in front of. Cut into the far wall rather than drawn on
## top of it: a lip of rock over the opening, the dark inside, and a scatter of the same
## rubble spilling out of it onto the floor.
func _draw_cave() -> void:
	# ⚠ ROW BY ROW, NOT AN ARCH DRAWN OVER A RECTANGLE. The first cut stepped the top corners
	# in and then filled the inside with one rect, which painted straight back over the steps
	# -- so the "cave" came out as a plain black box cut into the wall, which reads as a
	# missing texture rather than as a hole in a cliff. The arch has to BE the shape.
	var mouth := Rect2(cave_at - Vector2(cave_size.x * 0.5, cave_size.y), cave_size)
	var middle := cave_at.x
	var rows := int(cave_size.y)
	for row in range(rows):
		var t := float(row) / float(maxi(1, rows - 1))
		# Round for the top third, straight sides below it, which is what a hollow worn into
		# rock by water actually looks like.
		var arch := 1.0
		if t < 0.42:
			var a := t / 0.42
			arch = sqrt(maxf(0.0, 1.0 - (1.0 - a) * (1.0 - a)))
		var half := floorf(cave_size.x * 0.5 * arch)
		if half < 1.0:
			continue
		var y := floorf(mouth.position.y + float(row))
		draw_rect(Rect2(middle - half, y, half * 2.0, 1.0), CAVE_DARK)
		# The cut edge, so the hole has a thickness and is not a sticker.
		draw_rect(Rect2(middle - half - 2.0, y, 2.0, 1.0), CAVE_LIP)
		draw_rect(Rect2(middle + half, y, 2.0, 1.0), CAVE_LIP)
	# The threshold: a cave has a lip you step over, and it is what tells the eye the floor
	# carries on INTO it rather than stopping at a painted line.
	draw_rect(Rect2(middle - cave_size.x * 0.5, mouth.end.y - 3.0, cave_size.x, 3.0), CAVE_LIP)


## The bottom of the gorge, and the reason it is worth walking down to.
func _draw_floor() -> void:
	var floor_top := opening.end.y - 34.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260829
	# Silt first -- the flat the water leaves -- then rubble on top of it.
	draw_rect(Rect2(opening.position.x, floor_top, opening.size.x, 34.0), SILT)
	draw_rect(Rect2(opening.position.x, floor_top, opening.size.x, 2.0), RUBBLE_LIT)
	for index in range(74):
		var at := Vector2(
			opening.position.x + rng.randf_range(4.0, opening.size.x - 4.0),
			floor_top + rng.randf_range(2.0, 28.0))
		var size := rng.randf_range(3.0, 9.0)
		var tone := RUBBLE if rng.randf() < 0.7 else RUBBLE_DARK
		draw_rect(Rect2(at.floor(), Vector2(size, size * 0.7).floor()), tone)
		# A catch of light on the up-facing edge of the bigger stones, so the floor has a
		# direction the light comes from like everything else in this level.
		if size > 6.0:
			draw_rect(Rect2(at.floor(), Vector2(size * 0.6, 1.0).floor()), RUBBLE_LIT)

	# THE WAY OUT, SAID IN LIGHT. Daylight down the gorge's own mouth, widening as it falls,
	# so the bottom of the hole is not lit evenly and the eye knows where the sky is.
	var mouth_x := opening.position.x + opening.size.x * 0.5
	var bands := 16
	for index in range(bands):
		var t := float(index) / float(bands - 1)
		var half := lerpf(28.0, 96.0, t * t)
		var y := opening.position.y + opening.size.y * (0.28 + 0.72 * t)
		draw_rect(Rect2(mouth_x - half, y, half * 2.0, opening.size.y * 0.72 / float(bands) + 1.0),
			Color(DAYLIGHT, 0.05 * (1.0 - t)))


## The drop, in bands that darken toward the bottom. Whole-pixel steps rather than a
## gradient, which is the rule everything else in this game is drawn by.
func _draw_shaft() -> void:
	var bands := 14
	for index in range(bands):
		var t := float(index) / float(bands - 1)
		var top := opening.position.y + opening.size.y * (float(index) / float(bands))
		var height := opening.size.y / float(bands) + 1.0
		draw_rect(Rect2(opening.position.x, top, opening.size.x, height),
			shaft_top.lerp(shaft_bottom, t * t))
		# A course line every other band, inset a little from each side and jittered, so the
		# far wall has a surface. Fixed offsets rather than randf, like everything else here.
		if index % 2 == 1:
			var inset := 26.0 + float((index * 37) % 40)
			draw_rect(Rect2(opening.position.x + inset, top,
				opening.size.x - inset * 2.0, 1.0),
				Color(STRATA, 0.55 - t * 0.35))


## One rock face, going down from a lip. `near` is the left-hand one, whose lit side faces
## into the gorge; the far one is in its own shadow, which is what gives the hole a
## direction to be lit from.
func _draw_face(near: bool) -> void:
	var lip_x := opening.position.x if near else opening.end.x
	var into := 1.0 if near else -1.0
	var rng := RandomNumberGenerator.new()
	# Seeded, so the rock is the same rock every run and a screenshot can be compared with
	# the last one. Same rule the pickup flourish and the checkpoint sparks follow.
	rng.seed = 20260828 if near else 20260829

	var rows := int(opening.size.y / 8.0)
	for row in range(rows):
		var y := opening.position.y + float(row) * 8.0
		var t := float(row) / float(maxi(1, rows - 1))
		# The face steps back as it goes down, so the gorge is wider at the bottom than at
		# the lip -- which is what erosion does and what makes the drop read as deep.
		var reach := face_width * (1.0 - t * 0.45) + rng.randf_range(-5.0, 5.0)
		reach = maxf(10.0, reach)
		var x := lip_x if near else lip_x - reach
		var band := Rect2(x if near else x, y, reach, 8.0)
		# Darker with depth, so the two faces and the shaft agree about where the light is.
		var shade := ROCK.lerp(ROCK_DARK, t * 0.85)
		if not near:
			shade = shade.darkened(0.22)
		draw_rect(band, shade)
		# The strata: a lit line along the top of every third course, on the side that faces
		# the light. Without them the face is a flat brown slab.
		if row % 3 == 0:
			var lit := ROCK_LIT.lerp(ROCK_DARK, t * 0.8)
			if not near:
				lit = lit.darkened(0.3)
			draw_rect(Rect2(band.position, Vector2(band.size.x, 1.0)), lit)
		# The inner edge, which is what separates rock from drop.
		draw_rect(Rect2((band.end.x - 1.0) if near else band.position.x, y, 1.0, 8.0), EDGE)

	# Moss over the lip, where the rain runs off the terrace above. Only on the first few
	# courses: it is the join between the ground you walk on and the hole beside it.
	for row in range(4):
		var y := opening.position.y + float(row) * 8.0
		var reach := (face_width * 0.7) * (1.0 - float(row) * 0.22)
		var x := lip_x if near else lip_x - reach
		draw_rect(Rect2(x, y, reach, 2.0), Color(MOSS, 0.75 - float(row) * 0.16))
	draw_rect(Rect2(lip_x - (0.0 if near else 2.0), opening.position.y,
		2.0, opening.size.y), EDGE)
