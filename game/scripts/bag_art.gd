extends Control
## The leather bag the inventory screen is drawn on: a flap across the top with two straps
## and their buckles hanging over it, a dark lining for the pockets and cards, a stitched
## band along the bottom and two feet under it.
##
## Drawn rather than painted, so it is as wide and as tall as whatever the screen puts in it.
## Chunky and unsmoothed on purpose -- every edge is a keyline and a flat fill, which is how
## the rest of the interface reads as pixel art at any window size.

## The flap the title sits on, from the top of the bag to the seam.
const FLAP_H := 92.0
## The stitched band under the lining, which the footer is printed on.
const BOTTOM_H := 52.0
## How far the feet stand below the body.
const FEET_H := 18.0
## How far above its own rect the straps start, as they do in the bag they are copied from.
const STRAP_RISE := 8.0

const OUTLINE := Color(0.169, 0.114, 0.090)       # 2B1D17
const LEATHER := Color(0.549, 0.365, 0.271)       # 8C5D45
const LEATHER_LIT := Color(0.635, 0.435, 0.325)   # A26F53
const LEATHER_DARK := Color(0.431, 0.275, 0.204)  # 6E4634
const LINING := Color(0.290, 0.208, 0.188)        # 4A3530
const LINING_EDGE := Color(0.180, 0.125, 0.106)   # 2E201B
const STITCH := Color(0.365, 0.231, 0.173)        # 5D3B2C
const METAL := Color(0.557, 0.557, 0.557)
const METAL_LIT := Color(0.749, 0.749, 0.749)
const METAL_DARK := Color(0.290, 0.290, 0.290)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var body_bottom := h - FEET_H

	# Feet first, so the body sits on them.
	for x in [w * 0.14, w * 0.86]:
		draw_style_box(_box(LEATHER_DARK, OUTLINE, 4, 10),
			Rect2(x - 40.0, body_bottom - 24.0, 80.0, FEET_H + 24.0))

	# The body, with the light catching the top edge of the flap.
	draw_style_box(_box(LEATHER, OUTLINE, 4, 14), Rect2(0.0, 0.0, w, body_bottom))
	draw_rect(Rect2(14.0, 4.0, w - 28.0, 6.0), LEATHER_LIT)

	# The flap's stitching and the seam under it.
	draw_dashed_line(Vector2(18.0, 18.0), Vector2(w - 18.0, 18.0), STITCH, 2.0, 8.0)
	draw_dashed_line(Vector2(18.0, FLAP_H - 14.0), Vector2(w - 18.0, FLAP_H - 14.0), STITCH, 2.0, 8.0)
	draw_rect(Rect2(4.0, FLAP_H - 4.0, w - 8.0, 8.0), LEATHER_DARK)

	# The lining, where the pockets and the cards are.
	var lining := Rect2(14.0, FLAP_H + 8.0, w - 28.0, body_bottom - BOTTOM_H - FLAP_H - 8.0)
	draw_style_box(_box(LINING, LINING_EDGE, 4, 8), lining)
	draw_rect(Rect2(lining.position + Vector2(4.0, 4.0), Vector2(lining.size.x - 8.0, 6.0)),
		LINING_EDGE)

	# The bottom band's stitching.
	var band_top := body_bottom - BOTTOM_H
	draw_dashed_line(Vector2(18.0, band_top + 12.0), Vector2(w - 18.0, band_top + 12.0),
		STITCH, 2.0, 8.0)
	draw_dashed_line(Vector2(18.0, body_bottom - 12.0), Vector2(w - 18.0, body_bottom - 12.0),
		STITCH, 2.0, 8.0)

	for x in [w * 0.1, w * 0.9]:
		_draw_strap(x)


## One strap down over the flap, with its buckle and the hole the prong goes through.
func _draw_strap(x: float) -> void:
	var strap := Rect2(x - 24.0, -STRAP_RISE, 48.0, FLAP_H + STRAP_RISE + 30.0)
	var box := _box(LEATHER, OUTLINE, 4, 0)
	box.corner_radius_bottom_left = 18
	box.corner_radius_bottom_right = 18
	draw_style_box(box, strap)
	draw_dashed_line(Vector2(x - 14.0, 0.0), Vector2(x - 14.0, strap.end.y - 14.0), STITCH, 2.0, 6.0)
	draw_dashed_line(Vector2(x + 14.0, 0.0), Vector2(x + 14.0, strap.end.y - 14.0), STITCH, 2.0, 6.0)
	draw_circle(Vector2(x, strap.end.y - 18.0), 5.0, OUTLINE)

	# The buckle: a metal frame wider than the strap, and the prong across its middle.
	var buckle := Rect2(x - 32.0, 22.0, 64.0, 38.0)
	draw_style_box(_box(Color(0, 0, 0, 0), OUTLINE, 9, 4), buckle)
	draw_style_box(_box(Color(0, 0, 0, 0), METAL, 5, 3), buckle.grow(-2.0))
	draw_rect(Rect2(buckle.position + Vector2(4.0, 3.0), Vector2(buckle.size.x - 8.0, 2.0)), METAL_LIT)
	draw_rect(Rect2(x - 3.0, buckle.position.y + 2.0, 6.0, buckle.size.y - 4.0), OUTLINE)
	draw_rect(Rect2(x - 1.0, buckle.position.y + 4.0, 2.0, buckle.size.y - 8.0), METAL_DARK)


static func _box(fill: Color, edge: Color, border: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.draw_center = fill.a > 0.0
	box.border_color = edge
	box.set_border_width_all(border)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = false
	return box
