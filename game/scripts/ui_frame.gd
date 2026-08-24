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

## Carved ticks along the moulding. Worth turning off for a small frame, where the ticks
## land closer together than they are wide and read as a dotted line.
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
const KEYLINE_U := 1.0
## The lit step at the outer edge and the shaded one at the inner edge. One unit each --
## a bevel is a catch of light, not a band, and widening it turns the moulding into two
## flat colours instead of one piece of wood with an edge.
const BEVEL_U := 1.0
const MOULDING_U := 3.0
const RABBET_U := 1.0
const MAT_U := 2.0

## How much of the rect the frame itself eats, in units. What is left is canvas.
const TOTAL_U := KEYLINE_U + BEVEL_U * 2.0 + MOULDING_U + RABBET_U + MAT_U


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

	rect = _ring(rect, u * KEYLINE_U, UISkin.INK)
	# Kept, because the joint blocks are drawn over the whole moulding at the end and need
	# to know where its outer edge was.
	var moulding := rect
	var moulding_w := u * (BEVEL_U * 2.0 + MOULDING_U)

	# Light from the top left, and the two bevels lean opposite ways: the outer edge
	# catches it and the inner edge falls into shadow. That opposition is the whole trick
	# -- it is what makes the flat band between them read as the top of something raised
	# rather than as a stripe.
	rect = _bevel(rect, u * BEVEL_U, UISkin.LIME, UISkin.RING_OUTER)
	var body := rect
	rect = _ring(rect, u * MOULDING_U, UISkin.RING_MID)
	if ornament:
		_notches(body, u * MOULDING_U, u)
	rect = _bevel(rect, u * BEVEL_U, UISkin.RING_OUTER, UISkin.LIME)

	_joints(moulding, moulding_w, u)
	rect = _ring(rect, u * RABBET_U, UISkin.INK)
	rect = _ring(rect, u * MAT_U, UISkin.PANEL_LIT)
	draw_rect(rect, canvas_color)


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


## A ring whose top and left take one colour and whose bottom and right take another.
## Mitred at the corners, so the two colours meet on the diagonal the way a real moulding
## is cut, rather than one overrunning the other and putting a bright notch in a dark edge.
func _bevel(rect: Rect2, w: float, lit: Color, dark: Color) -> Rect2:
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


## Carving. Notches cut INTO the moulding, so they are darker than it rather than brighter:
## a recess catches less light, not more. The first version drew them in lime at a tight
## pitch, which made the whole top rail read as one bright dashed line instead of as wood
## with marks in it.
func _notches(rect: Rect2, thickness: float, u: float) -> void:
	var pitch := u * 6.0
	var depth := thickness - u * 2.0
	if depth <= 0.0:
		return
	var inset := u

	var span_x := rect.size.x - thickness * 2.0
	var count_x := int(span_x / pitch)
	# Centred on the run rather than started from one end, or the pattern is symmetrical
	# on one side of the frame and cut off on the other.
	var start_x := rect.position.x + thickness + (span_x - float(count_x) * pitch) * 0.5
	for i in range(count_x):
		var x := floorf(start_x + float(i) * pitch)
		draw_rect(Rect2(Vector2(x, rect.position.y + inset), Vector2(u, depth)),
			UISkin.RING_OUTER)
		draw_rect(Rect2(Vector2(x, rect.position.y + rect.size.y - thickness + inset),
			Vector2(u, depth)), UISkin.RING_OUTER)

	var span_y := rect.size.y - thickness * 2.0
	var count_y := int(span_y / pitch)
	var start_y := rect.position.y + thickness + (span_y - float(count_y) * pitch) * 0.5
	for i in range(count_y):
		var y := floorf(start_y + float(i) * pitch)
		draw_rect(Rect2(Vector2(rect.position.x + inset, y), Vector2(depth, u)),
			UISkin.RING_OUTER)
		draw_rect(Rect2(Vector2(rect.position.x + rect.size.x - thickness + inset, y),
			Vector2(depth, u)), UISkin.RING_OUTER)


## The four corners, where the mitres meet, capped with a joint block.
##
## This is the strongest single cue that the thing is a frame and not a border, because it
## is the one piece of a frame that has no equivalent in a UI panel. Drawn last, over the
## bevels and the carving, which is exactly what a real corner block does.
func _joints(rect: Rect2, thickness: float, u: float) -> void:
	var block := Vector2(thickness, thickness)
	for corner in [
		rect.position,
		rect.position + Vector2(rect.size.x - thickness, 0.0),
		rect.position + Vector2(0.0, rect.size.y - thickness),
		rect.position + rect.size - block,
	]:
		draw_rect(Rect2(corner, block), UISkin.RING_MID)
		draw_rect(Rect2(corner, block), UISkin.LIME, false, u)
		# A pin in the middle of the block. Two units across, so it survives being drawn
		# at unit 3 for a small frame.
		draw_rect(Rect2(corner + block * 0.5 - Vector2(u, u), Vector2(u, u) * 2.0),
			UISkin.LIME)
