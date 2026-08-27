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


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Behind everything that stands in the gorge -- the bridge posts, the route ledges, the
	# cave mouth and the flower -- and in front of the parallax it exists to hide.
	z_index = -6
	queue_redraw()


func _draw() -> void:
	_draw_shaft()
	if face_width <= 0.0:
		return
	_draw_face(true)
	_draw_face(false)


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
