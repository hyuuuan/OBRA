class_name UIGlyph
extends Control
## The two pictograms the HUD needs, drawn as pixels rather than shipped as files.
##
## A droplet beside INK and a flag beside GOAL. They are eight rows of a bitmap each, so
## they cost nothing, they scale to whatever the row they sit in turns out to be, and they
## cannot be imported with the wrong texture filter or land in the repo as a binary nobody
## can diff. They are also the only two marks in the interface that are not type or a
## rectangle, which is the whole reason they read at a glance.

enum Kind { DROPLET, FLAG }

## Rows read top to bottom, one character per pixel, '#' set.
const SHAPES := {
	Kind.DROPLET: [
		"..##..",
		"..##..",
		".####.",
		".####.",
		"######",
		"######",
		"######",
		".####.",
	],
	Kind.FLAG: [
		"#......",
		"#####..",
		"######.",
		"#####..",
		"###....",
		"#......",
		"#......",
		"#......",
	],
}

@export var kind: Kind = Kind.DROPLET:
	set(value):
		kind = value
		queue_redraw()

@export var color: Color = UISkin.GOLD:
	set(value):
		color = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(12.0, 16.0)


func _draw() -> void:
	var rows: Array = SHAPES[kind]
	var height := rows.size()
	var width := String(rows[0]).length()
	# Snapped to whole pixels, or a bitmap drawn at a fractional scale grows seams between
	# its own cells and stops reading as one shape.
	var cell := maxf(1.0, floorf(minf(size.x / float(width), size.y / float(height))))
	var origin := ((size - Vector2(width, height) * cell) * 0.5).floor()
	for y in range(height):
		var row := String(rows[y])
		for x in range(width):
			if row[x] == "#":
				draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), color)
