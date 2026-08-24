class_name UIFrame
extends Control
## A picture frame, drawn rather than shipped.
##
## THE LORE IS THE REASON. OBRA is a game about a grandmother's paintings -- the hub is her
## studio, the levels are her canvases, and the player is holding her brush. So when the
## game speaks, it speaks from inside a frame: every line of story is presented the way a
## painting is presented. A dialogue box that looks like a UI panel says "this is software";
## a dialogue box that looks like a frame says "this is one of hers".
##
## Dark wood with a gold liner, and restrained. An earlier cut of this was vermillion and
## gold with a crest on the top rail, stepped corners and pins at every joint -- a
## fairground frame. It drew more attention than the words inside it, which is the one
## thing a frame must never do.
##
## What makes it read as a frame rather than as a thick brown border is not ornament:
##
##   1. DEPTH. Bands of different widths, not one ring. A real moulding steps.
##   2. LIGHT. Two bevels leaning OPPOSITE ways -- the outer edge catches the light, the
##      inner edge falls away from it. That opposition is what makes the flat band between
##      them read as the top of something raised rather than as a stripe.
##   3. THE LINER. One pixel of gold between the wood and the picture. It is the whole
##      difference between a brown rectangle and a frame, and it costs a single band.
##
## Sized to whatever rect it is given, so the same frame serves a two-line hint and a
## six-line memory without a second asset.

## The size of one drawn pixel. Everything is a multiple of this, so the whole frame stays
## on a single grid and scales by changing one number. Floored, never fractional -- a
## bitmap drawn at a fractional scale grows seams between its own cells.
@export var unit: float = 4.0:
	set(value):
		unit = value
		queue_redraw()

## How far past its own rect the frame draws, on every side.
##
## This exists so a frame can be a plain child of the PanelContainer it decorates. A
## container lays its children out INSIDE the padding that keeps the text off the moulding,
## which is precisely where the frame must not be -- so it is laid out with everything else
## and then draws back outward over the padding. Godot does not clip a Control's drawing to
## its rect unless asked, so this costs nothing and needs no layout special case.
@export var overdraw: float = 0.0:
	set(value):
		overdraw = value
		queue_redraw()

## What the frame is holding. The mat around it does not change.
@export var canvas_color: Color = UISkin.PANEL:
	set(value):
		canvas_color = value
		queue_redraw()

## Widths in units, outermost first. Named rather than inlined because the dialogue box
## measures its own text against them.
## The bands, outermost first: width in units, and how that width is painted. A band is
## either FLAT (one colour) or a BEVEL (lit on the top and left, shaded on the bottom and
## right, or the reverse). Read as a table because that is what it is -- change a width or
## a colour here and the whole frame follows, including the padding the dialogue box lays
## its text out against.
const BANDS := [
	[1.0, "flat", "EDGE"],
	[1.0, "bevel", "WOOD_LIT"],   # the outer arris, catching the light
	[3.0, "flat", "WOOD"],        # the face of the moulding
	[1.0, "bevel", "WOOD_DARK"],  # stepping down into the picture, so it turns away
	[1.0, "bevel", "FILLET"],     # the gold liner
	[1.0, "flat", "EDGE"],        # the rabbet: the shadow the glass would sit in
	[2.0, "flat", "MAT"],
]

## How much of the rect the frame itself eats, in units. What is left is canvas.
const TOTAL_U := 10.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The padding a caller has to leave so its content lands on the canvas and not under the
## moulding. Static so a layout can ask before the frame exists.
static func inset_for(unit_size: float) -> float:
	return maxf(1.0, floorf(unit_size)) * TOTAL_U


## Frame an existing PanelContainer in place: the panel stops drawing its own background,
## takes enough padding to keep its content off the moulding, and gets a frame behind
## everything it holds.
static func wrap(panel: PanelContainer, unit_size: float = 4.0) -> UIFrame:
	var pad := inset_for(unit_size) + 14.0
	var hollow := StyleBoxEmpty.new()
	hollow.content_margin_left = pad
	hollow.content_margin_right = pad
	hollow.content_margin_top = pad
	hollow.content_margin_bottom = pad
	panel.add_theme_stylebox_override(&"panel", hollow)

	var frame := UIFrame.new()
	frame.name = "Frame"
	frame.unit = unit_size
	frame.overdraw = pad
	panel.add_child(frame)
	# First child, so it is drawn before -- and therefore behind -- the content.
	panel.move_child(frame, 0)
	return frame


func _draw() -> void:
	var u := maxf(1.0, floorf(unit))
	var out := floorf(overdraw)
	var rect := Rect2(Vector2(-out, -out), (size + Vector2(out, out) * 2.0).floor())
	if rect.size.x < u * TOTAL_U * 2.0 or rect.size.y < u * TOTAL_U * 2.0:
		return

	for band: Array in BANDS:
		var w := float(band[0]) * u
		if String(band[1]) == "bevel":
			rect = _bevel(rect, w, String(band[2]))
		else:
			rect = _ring(rect, w, _band_color(String(band[2])))
	draw_rect(rect, canvas_color)


func _band_color(name: String) -> Color:
	match name:
		"EDGE":
			return UISkin.WOOD_EDGE
		"WOOD":
			return UISkin.WOOD
		"WOOD_LIT":
			return UISkin.WOOD_LIT
		"WOOD_DARK":
			return UISkin.WOOD_DARK
		"FILLET":
			return UISkin.FILLET
		_:
			return UISkin.MAT


## Paint a ring `w` thick inside `rect` and hand back what is left. Four rects rather than
## an unfilled draw_rect, because an unfilled one strokes centred on the boundary and
## leaves the ring half outside the rect it was supposed to fit in.
func _ring(rect: Rect2, w: float, color: Color) -> Rect2:
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, w)), color)
	draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - w),
		Vector2(rect.size.x, w)), color)
	draw_rect(Rect2(rect.position + Vector2(0.0, w), Vector2(w, rect.size.y - w * 2.0)), color)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - w, w),
		Vector2(w, rect.size.y - w * 2.0)), color)
	return Rect2(rect.position + Vector2(w, w), rect.size - Vector2(w, w) * 2.0)


## A ring whose top and left take the lit tone and whose bottom and right take the shaded
## one. Mitred at the corners, so the two meet on the diagonal the way a moulding is
## actually cut rather than one overrunning the other and putting a bright notch in a dark
## edge.
##
## WOOD_DARK is named as the lit tone for the inner arris on purpose: there the surface
## turns AWAY from the light, so the pair swaps and the wood below it becomes the highlight.
func _bevel(rect: Rect2, w: float, name: String) -> Rect2:
	var lit := _band_color(name)
	var dark := UISkin.WOOD_DARK if name != "WOOD_DARK" else UISkin.WOOD_LIT
	if name == "FILLET":
		lit = UISkin.FILLET_LIT
		dark = UISkin.FILLET
	draw_colored_polygon(PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + Vector2(rect.size.x - w, w),
		rect.position + Vector2(w, w),
	]), lit)
	draw_colored_polygon(PackedVector2Array([
		rect.position,
		rect.position + Vector2(w, w),
		rect.position + Vector2(w, rect.size.y - w),
		rect.position + Vector2(0.0, rect.size.y),
	]), lit)
	draw_colored_polygon(PackedVector2Array([
		rect.position + Vector2(0.0, rect.size.y),
		rect.position + Vector2(w, rect.size.y - w),
		rect.position + Vector2(rect.size.x - w, rect.size.y - w),
		rect.position + rect.size,
	]), dark)
	draw_colored_polygon(PackedVector2Array([
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + rect.size,
		rect.position + Vector2(rect.size.x - w, rect.size.y - w),
		rect.position + Vector2(rect.size.x - w, w),
	]), dark)
	return Rect2(rect.position + Vector2(w, w), rect.size - Vector2(w, w) * 2.0)
