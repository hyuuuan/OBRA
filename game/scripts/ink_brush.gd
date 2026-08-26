class_name InkBrush
extends Control
## The ink gauge, drawn as Lola's brush running dry.
##
## WHAT THIS REPLACES. Ink was twelve lime blocks in a trough -- a good gauge, and a gauge
## about nothing. The player is not spending twelve abstract units, they are spending the
## brush the game hands them in the house, and the brush already exists as art. So the
## gauge IS the brush: it starts loaded and gold, and it goes dark as the level is drawn.
## One object, carried from the hub into every level, that answers "how much have I got
## left" without a number and without a legend.
##
## TWO ARTWORKS, PIXEL FOR PIXEL THE SAME SHAPE. `brush_full` is the loaded brush and
## `brush_empty` is the same brush drawn dry. They were exported on the same canvas with
## the same 13,284 opaque pixels and not one pixel of either falls outside the other, which
## is the whole reason this can be drawn as one sprite lit part-way along rather than as a
## sprite plus a mask. If they are ever re-exported, that alignment is the thing to check
## first -- a one-pixel drift shows up as a fringe along the dry edge.
##
## IT EMPTIES TOWARD THE BRISTLES. The head is on the right, so the gold recedes rightward
## and the bristles are the first thing to go dry. That is the direction ink actually
## leaves a brush, and it is the more useful one to read: a dark head says "this will not
## paint" at a glance, where a dark handle butt says nothing at all.

## Where the brush sits on its 384x384 export sheet, and the size of it. Both files carry
## the same box. The art is drawn on a six-pixel grid -- 61 by 11 of its own pixels -- and
## every number below is derived from that rather than from the 366x66 it happens to
## occupy, because the grid is what has to stay whole when the gauge is scaled.
const SHEET_ORIGIN := Vector2(6.0, 156.0)
const ART := Vector2i(61, 11)
const ART_PIXEL := 6.0

const FULL: Texture2D = preload("res://assets/hud/brush_full.png")
const EMPTY: Texture2D = preload("res://assets/hud/brush_empty.png")

## THE DRY BRUSH HAS TO RECEDE, and left alone it does the opposite. `brush_empty` is not a
## silhouette -- it is line work in dark umber over an OPAQUE CREAM field, five thousand
## pixels of near-white, and near-white is brighter than the gold it stands in for wherever
## it is shown. A gauge whose empty half is louder than its full half reads backwards; at
## zero ink it lit up like something had been gained.
##
## Multiplied down to a dim olive instead, so what is left of a spent brush is the SHAPE of
## it, quietly, with the gold gone. The value is chosen against the darkest ground it has
## to sit on -- the scrim behind the drawing page, UISkin.PANEL at (13, 16, 9) -- where the
## cream resolves to roughly (71, 76, 57) and stays visible without competing. On the level
## itself it goes darker than its background rather than lighter, which is the same reading
## from the other side.
const DRY := Color(0.28, 0.30, 0.24, 1.0)

## Ink the current sketch has claimed but not yet spent. Clearing the canvas hands every
## unit of it straight back, so it is neither spent nor safe.
##
## ORANGE, NOT WARM GOLD. It was UISkin.PENDING, which is what the old block gauge used --
## and that gauge could afford a subtle warm because its full state was GOLD, so warm and
## lime were never confusable. Multiplied over gold artwork, a warm yellow is gold, and the
## band the player most needs to see -- the one their current stroke is eating -- vanished
## into the ink they still had. Pushed hard off the hue instead, and held slightly under
## full so the dry brush reads through it as something not yet committed.
const PENDING := Color(1.0, 0.66, 0.12, 0.85)

## Where the gold starts to worry, and where it gives up. Below the first the brush warms
## toward amber, below the second it goes red: the colour is a second channel saying the
## same thing the length says, so a player who is watching the drawing and not the HUD
## still catches it in the corner of their eye.
const LOW := 0.34
const CRITICAL := 0.12
const WARN := Color(1.0, 0.80, 0.42)
const DANGER := Color(1.0, 0.42, 0.34)


var remaining := 12.0
var capacity := 12.0
var reserved := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	var scale := _fit()
	if scale <= 0:
		return
	var drawn := Vector2(ART) * float(scale)
	# Centred and on whole pixels. Half a pixel of offset on nearest-neighbour art is a row
	# of doubled columns down one side of the brush.
	var origin := ((size - drawn) * 0.5).floor()

	# The dry brush underneath, whole. The lit part is painted over it, so the boundary
	# between wet and dry needs no mask -- it is simply where the gold stops.
	_band(origin, scale, 0, ART.x, EMPTY, DRY)

	var span := maxf(0.001, capacity)
	var lit := _columns(remaining / span)
	var claimed := _columns((remaining + maxf(0.0, reserved)) / span)
	_band(origin, scale, 0, lit, FULL, _health_tint(clampf(remaining / span, 0.0, 1.0)))
	_band(origin, scale, lit, claimed, FULL, PENDING)


## How many of the brush's own 61 pixels are wet at this fraction of the budget.
##
## WHOLE ART PIXELS, never a fraction of one. The gauge has to move smoothly enough to
## show a stroke eating into it, and 61 steps across twelve units is five steps per unit,
## which is plenty -- but a boundary landing mid-pixel would draw a part-lit column, and a
## part-lit column in pixel art reads as a rendering fault rather than as a quantity.
##
## Any ink at all keeps one column lit. Rounding a real but tiny reserve down to nothing
## would show a dry brush to a player who can still draw, which is the one lie a gauge
## must not tell.
func _columns(ratio: float) -> int:
	if ratio <= 0.0:
		return 0
	return clampi(maxi(1, roundi(ratio * float(ART.x))), 0, ART.x)


## Paint art pixels [from, to) of the brush from one of the two sheets.
func _band(origin: Vector2, scale: int, from: int, to: int,
		texture: Texture2D, modulate: Color) -> void:
	if to <= from:
		return
	var source := Rect2(
		SHEET_ORIGIN + Vector2(float(from) * ART_PIXEL, 0.0),
		Vector2(float(to - from) * ART_PIXEL, float(ART.y) * ART_PIXEL))
	var target := Rect2(
		origin + Vector2(float(from * scale), 0.0),
		Vector2(float((to - from) * scale), float(ART.y * scale)))
	draw_texture_rect_region(texture, target, source, modulate)


## The largest whole number of screen pixels one art pixel can take and still fit the box.
##
## Whole numbers only. This is a sprite on a six-pixel grid and the two places it is shown
## -- the level HUD and the strip over the drawing page -- are different widths; letting it
## scale to fill either one would put the brush on half pixels in at least one of them.
func _fit() -> int:
	return mini(int(size.x) / ART.x, int(size.y) / ART.y)


## Gold while there is ink to spare, amber as it runs low, red at the end. Multiplied over
## the artwork rather than replacing it, so the brush keeps its own shading throughout and
## only the light on it changes.
func _health_tint(ratio: float) -> Color:
	if ratio >= LOW:
		return Color.WHITE
	if ratio >= CRITICAL:
		return Color.WHITE.lerp(WARN, inverse_lerp(LOW, CRITICAL, ratio))
	return WARN.lerp(DANGER, inverse_lerp(CRITICAL, 0.0, ratio))


## The box a brush wants at N screen pixels to the art pixel.
##
## Asked for rather than written out, because the two places that show a brush want it at
## different sizes and neither should be carrying its own copy of 61 by 11.
static func size_at(scale: int) -> Vector2:
	return Vector2(ART) * float(maxi(1, scale))


## What the gauge is showing, for anything that wants to place a label beside it.
func remaining_ratio() -> float:
	if capacity <= 0.0:
		return 0.0
	return clampf(remaining / capacity, 0.0, 1.0)
