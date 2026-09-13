class_name PaddyBasin2D
extends Node2D
## THE INSIDE OF A FLOODED PADDY: wet clay banks, a silt floor, rice in it.
##
## Both of Payyo's paddies were built from the terrace kit. The floor under the water was a
## terrace segment in the STONE style -- a grass-topped cobble slab -- and the pit behind the
## water was the gorge's rock shaft in a browner colour. So what the player saw at the first
## gate in the game was a blue rectangle sitting on a strip of exactly the ground they walk
## on everywhere else, and a paddy read as a platform with some water drawn over it. Kent:
## "it has the same one as the platform itself, which is very confusing."
##
## A paddy is MUD. Nothing in here uses a tile from the terrace atlas: the banks slope, the
## clay is dark and wet under the waterline, the floor is silt with rice standing in it, and
## a lip of the same mud spills over the edge of the path at both ends -- so the eye reads
## "you would sink in that" before it reads anything else.
##
## Drawn behind the water and the player. `WaterArea2D` with `paddy` on draws the surface.

## The hole this fills, in local space: the paddy's width and its depth from the rim.
@export var opening := Rect2(0.0, 0.0, 300.0, 104.0)

## Wet clay, darkest where it is deepest.
const CLAY_WET := Color(0.227, 0.169, 0.106, 1.0)     # 3A2B1B
const CLAY_DEEP := Color(0.149, 0.110, 0.071, 1.0)    # 261C12
const CLAY := Color(0.306, 0.231, 0.149, 1.0)         # 4E3B26
const CLAY_LIT := Color(0.420, 0.329, 0.220, 1.0)     # 6B5438
## Silt the water leaves on the floor, a shade paler than the banks.
const SILT := Color(0.290, 0.239, 0.157, 1.0)         # 4A3D28
const SILT_LIT := Color(0.384, 0.325, 0.224, 1.0)     # 625339
## Rice. Young, planted in rows, and the only green inside the paddy.
const RICE := Color(0.525, 0.706, 0.263, 1.0)         # 86B443
const RICE_DARK := Color(0.290, 0.408, 0.153, 1.0)    # 4A6827
const PEBBLE := Color(0.451, 0.420, 0.365, 1.0)       # 736B5D
## How far each bank leans in from the rim to the floor.
const SLOPE := 26.0

var _lip: Node2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Behind the water, the player and the terrace blocks either side, the way the gorge's own
	# shaft is: the blocks' faces are the top of the banks, and this is everything below.
	z_index = -6
	# ⚠ THE LIP HAS TO BE IN FRONT OF THE TERRACE, and the basin cannot be. A child with an
	# absolute z carries the clay over the edge of the path, which is what breaks the straight
	# vertical cut where a cobble block used to meet blue water.
	_lip = Node2D.new()
	_lip.name = "Lip"
	_lip.z_as_relative = false
	_lip.z_index = 2
	_lip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_lip.draw.connect(_draw_lip)
	add_child(_lip)
	queue_redraw()


func _draw() -> void:
	var box := opening
	# The far bank: wet clay banded darker toward the bottom, in whole steps, because a smooth
	# gradient is a wash over the picture rather than light in a hole.
	var bands := 6
	for band in range(bands):
		var t := float(band) / float(bands - 1)
		var colour := CLAY.lerp(CLAY_DEEP, t)
		var y := box.position.y + box.size.y * float(band) / float(bands)
		draw_rect(Rect2(box.position.x, floorf(y), box.size.x,
			ceilf(box.size.y / float(bands)) + 1.0), colour)
	# Root-matted streaks down the far bank, so it has a surface and not only a colour.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x) * 31 + 7
	for index in range(int(box.size.x / 9.0)):
		var x := floorf(box.position.x + rng.randf() * box.size.x)
		var top := box.position.y + 6.0 + rng.randf() * box.size.y * 0.5
		draw_rect(Rect2(x, top, 2.0, 6.0 + rng.randf() * 14.0), CLAY_WET)

	# The two near banks, leaning in from the rim to the floor.
	var floor_y := box.end.y
	for side: float in [-1.0, 1.0]:
		var rim_x := box.position.x if side < 0.0 else box.end.x
		var foot_x := rim_x - side * SLOPE
		draw_colored_polygon(PackedVector2Array([
			Vector2(rim_x, box.position.y), Vector2(rim_x, floor_y),
			Vector2(foot_x, floor_y)]), CLAY_WET)
		# The lit edge of the bank, where the slope faces the sky.
		for step in range(int(box.size.y / 4.0)):
			var t := float(step) / (box.size.y / 4.0)
			var x := rim_x - side * SLOPE * t
			draw_rect(Rect2(x - (2.0 if side > 0.0 else 0.0), box.position.y + float(step) * 4.0,
				2.0, 4.0), CLAY if side < 0.0 else CLAY_DEEP)

	# The floor: silt, pebbles, and rice standing in rows.
	draw_rect(Rect2(box.position.x, floor_y - 10.0, box.size.x, 10.0), SILT)
	draw_rect(Rect2(box.position.x, floor_y - 10.0, box.size.x, 2.0), SILT_LIT)
	for index in range(int(box.size.x / 22.0)):
		var at := Vector2(floorf(box.position.x + 8.0 + rng.randf() * (box.size.x - 16.0)),
			floor_y - 6.0 + floorf(rng.randf() * 4.0))
		draw_rect(Rect2(at, Vector2(3.0, 2.0)), PEBBLE)
	var row := box.position.x + SLOPE + 10.0
	while row < box.end.x - SLOPE - 6.0:
		_draw_clump(Vector2(row, floor_y - 9.0), 16.0 + fmod(row, 3.0) * 3.0)
		row += 28.0


## A clump of rice planted in the floor, three blades from one base.
func _draw_clump(base: Vector2, height: float) -> void:
	draw_rect(Rect2(base.x - 2.0, base.y - 3.0, 5.0, 3.0), RICE_DARK)
	draw_rect(Rect2(base.x, base.y - height, 1.0, height), RICE_DARK)
	draw_line(base, base + Vector2(-5.0, -height * 0.8), RICE, 1.0)
	draw_line(base, base + Vector2(5.0, -height * 0.85), RICE, 1.0)


## Mud over the edge of the path at both ends: lumps of clay and a dark wet line where the
## grass gives out, so the paddy starts before the water does.
func _draw_lip() -> void:
	var box := opening
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x) * 17 + 3
	for side: float in [-1.0, 1.0]:
		var rim_x := box.position.x if side < 0.0 else box.end.x
		# Spilling back onto the path, biggest at the edge and smaller away from it.
		for lump in range(5):
			var width := 16.0 - float(lump) * 2.0 + floorf(rng.randf() * 4.0)
			var x := rim_x + side * (4.0 + float(lump) * 12.0) - width * 0.5
			var height := 9.0 - float(lump) * 1.2 + floorf(rng.randf() * 2.0)
			_lip.draw_rect(Rect2(x, box.position.y - height + 3.0, width, height), CLAY_WET)
			_lip.draw_rect(Rect2(x + 2.0, box.position.y - height + 3.0, width - 4.0, 2.0), CLAY_LIT)
			_lip.draw_rect(Rect2(x, box.position.y + 1.0, width, 2.0), CLAY_DEEP)
		# The wet line down the bank's face where water has soaked into the terrace edge.
		var edge := rim_x - (4.0 if side > 0.0 else 0.0)
		_lip.draw_rect(Rect2(edge, box.position.y, 4.0, minf(28.0, box.size.y)), CLAY_WET)
