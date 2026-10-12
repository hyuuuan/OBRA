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

## SOFT CORNERS, LIKE EVERY OTHER BOX. Kent: "there are still boxes in the game like the brush
## container or like the dialogue or hints, i told you to make them use the soft edged curve".
## Each band is a rounded rect inset from the one outside it, and its corner is the outer
## corner less how far in it is -- so the moulding turns the corner as one piece, not as rings
## of different curves. In units, like the bands.
const CORNER_U := 6.0
## However deep in the frame, a corner never closes tighter than this.
const MIN_CORNER := 4.0

var _boxes := {}


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

	var corner := CORNER_U * u
	var inset := 0.0
	for band: Array in BANDS:
		var w := float(band[0]) * u
		var radius := maxf(corner - inset, MIN_CORNER)
		if String(band[1]) == "bevel":
			_bevel(rect, w, String(band[2]), radius)
		else:
			_fill(rect, _band_color(String(band[2])), radius)
		# The next band is painted over everything inside this one, leaving this one a ring.
		rect = rect.grow(-w)
		inset += w
	_fill(rect, canvas_color, maxf(corner - inset, MIN_CORNER))


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


## A filled rounded rect. Recolouring a shared box is safe: a StyleBox is read when it is drawn.
func _fill(rect: Rect2, color: Color, radius: float) -> void:
	var key := int(round(radius))
	var box := _boxes.get(key) as StyleBoxFlat
	if box == null:
		box = StyleBoxFlat.new()
		box.set_corner_radius_all(key)
		box.corner_detail = 12
		box.anti_aliasing = true
		_boxes[key] = box
	box.bg_color = color
	draw_style_box(box, rect)


## A band whose top and left take the lit tone and whose bottom and right take the shaded one:
## the whole band in shade, then the lit tone over it from the top-left corner, stopping a band
## short of the bottom and right. The next band in covers the middle.
##
## WOOD_DARK is named as the lit tone for the inner arris on purpose: there the surface
## turns AWAY from the light, so the pair swaps and the wood below it becomes the highlight.
func _bevel(rect: Rect2, w: float, name: String, radius: float) -> void:
	var lit := _band_color(name)
	var dark := UISkin.WOOD_DARK if name != "WOOD_DARK" else UISkin.WOOD_LIT
	if name == "FILLET":
		lit = UISkin.FILLET_LIT
		dark = UISkin.FILLET
	_fill(rect, dark, radius)
	_fill(Rect2(rect.position, rect.size - Vector2(w, w)), lit, radius)
