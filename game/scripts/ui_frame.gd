class_name UIFrame
extends Control
## A pixelated picture frame, drawn rather than shipped.
##
## THE LORE IS THE REASON. OBRA is a game about a grandmother's paintings -- the hub is her
## studio, the levels are her canvases, and the player is holding her brush. So when the
## game speaks, it speaks from inside a frame: every line of story is presented the way a
## painting is presented. A dialogue box that looks like a UI panel says "this is software";
## a dialogue box that looks like a frame says "this is one of hers".
##
## Three things make a frame read as a frame rather than as a thick border, and all three
## have to be here or it just looks like a panel someone made chunky:
##
##   1. DEPTH. Bands of different widths, not one ring. A real moulding steps.
##   2. LIGHT. The top and left edges catch it, the bottom and right fall away. This is
##      what makes it look carved instead of printed.
##   3. CORNERS. Real frames are joined at the corners and the joint is decorated. The
##      corner bosses are the single strongest cue and the cheapest to draw.
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

## The crest and the pins. Worth turning off for a small frame, where a crest is a bigger
## fraction of the rail than of the object and the pins land on top of each other.
@export var ornament: bool = true:
	set(value):
		ornament = value
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
## The bands, outermost first: width in units, and what colour that width is painted.
## Read as a table because that is what it is -- change a width or a colour here and the
## whole frame follows, including the padding the dialogue box lays its text out against.
const BANDS := [
	[1.0, "EDGE"],
	[3.0, "DEEP"],
	[1.0, "MID"],
	[1.0, "PALE"],
	[1.0, "LIT"],
	[2.0, "RABBET"],
]

## How far each corner is cut back, in steps of one unit. Three reads as a chamfer at a
## glance and as a staircase up close, which is the whole idea.
const CORNER_STEPS := 3

## The crest at the top and bottom centre: how far it stands proud of the rail, and how
## much of the frame's width it spans.
const CREST_U := 5.0
const CREST_SPAN := 0.20

## How much of the rect the frame itself eats, in units. What is left is canvas.
const TOTAL_U := 9.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The padding a caller has to leave so its content lands on the canvas and not under the
## moulding. Static so a layout can ask before the frame exists.
static func inset_for(unit_size: float) -> float:
	return maxf(1.0, floorf(unit_size)) * TOTAL_U


## Frame an existing PanelContainer in place: the panel stops drawing its own background,
## takes enough padding to keep its content off the moulding, and gets a frame behind
## everything it holds.
static func wrap(panel: PanelContainer, unit_size: float = 4.0,
		with_ornament: bool = true) -> UIFrame:
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
	frame.ornament = with_ornament
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

	# Snapped to the unit grid so the crest's two halves are the same width. An odd number
	# of units either side of centre puts one more step on the left than the right, and at
	# this scale that is visible.
	var crest_w := floorf(rect.size.x * CREST_SPAN / (u * 2.0)) * u * 2.0 if ornament else 0.0

	# Each band is drawn as a SOLID silhouette and then covered by the next one in, rather
	# than as a ring. A ring with stepped corners and a crest on it is four awkward shapes;
	# a solid one is a stack of rows, and the stack is the same code for every band.
	var inset := 0.0
	for band: Array in BANDS:
		_silhouette(rect.grow(-inset), u, crest_w - inset,
			u * CREST_U - inset, _band_color(String(band[1])))
		inset += float(band[0]) * u

	if ornament:
		_pins(rect, u)
	_silhouette(rect.grow(-inset), u, 0.0, 0.0, canvas_color)


func _band_color(name: String) -> Color:
	match name:
		"EDGE":
			return UISkin.GILT_EDGE
		"DEEP":
			return UISkin.GILT_DEEP
		"MID":
			return UISkin.GILT_MID
		"PALE":
			return UISkin.GILT_PALE
		"LIT":
			return UISkin.GILT_LIT
		_:
			return UISkin.GILT_RABBET


## One solid band: a rectangle whose four corners are cut back in steps, with a crest
## standing proud of the top and bottom rails.
func _silhouette(rect: Rect2, u: float, crest_w: float, crest_h: float,
		color: Color) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	if crest_w > u * 4.0 and crest_h >= u:
		var cx := rect.position.x + floorf(rect.size.x * 0.5)
		for edge in [-1.0, 1.0]:
			var top := rect.position.y - crest_h if edge < 0.0 else rect.position.y + rect.size.y
			# The crest's own outer corners are cut by one step, so it reads as part of
			# the same moulding rather than as a tab stuck onto it.
			var lip := top if edge < 0.0 else top + crest_h - u
			draw_rect(Rect2(Vector2(cx - crest_w * 0.5 + u, lip),
				Vector2(crest_w - u * 2.0, u)), color)
			var rest := top + u if edge < 0.0 else top
			draw_rect(Rect2(Vector2(cx - crest_w * 0.5, rest),
				Vector2(crest_w, crest_h - u)), color)

	var steps := CORNER_STEPS
	var cut := float(steps) * u
	if rect.size.y <= cut * 2.0 or rect.size.x <= cut * 2.0:
		draw_rect(rect, color)
		return
	for i in range(steps):
		var side := float(steps - i) * u
		var width := rect.size.x - side * 2.0
		draw_rect(Rect2(Vector2(rect.position.x + side,
			rect.position.y + float(i) * u), Vector2(width, u)), color)
		draw_rect(Rect2(Vector2(rect.position.x + side,
			rect.position.y + rect.size.y - float(i + 1) * u), Vector2(width, u)), color)
	draw_rect(Rect2(Vector2(rect.position.x, rect.position.y + cut),
		Vector2(rect.size.x, rect.size.y - cut * 2.0)), color)


## The four pins, set into the gold band just inside each cut corner. They are the
## brightest thing on the frame, which is what makes them read as hardware rather than as
## more decoration -- and they are the detail that says "this object was made and joined"
## more cheaply than any amount of carving.
func _pins(rect: Rect2, u: float) -> void:
	var depth := (float(BANDS[0][0]) + float(BANDS[1][0]) + float(BANDS[2][0])) * u
	var band := rect.grow(-depth)
	var step := float(CORNER_STEPS) * u
	var size_px := Vector2(u, u) * 2.0
	for corner in [
		band.position + Vector2(step, step),
		band.position + Vector2(band.size.x - step - size_px.x, step),
		band.position + Vector2(step, band.size.y - step - size_px.y),
		band.position + band.size - Vector2(step, step) - size_px,
	]:
		draw_rect(Rect2(corner.floor(), size_px), UISkin.GILT_PIN)
