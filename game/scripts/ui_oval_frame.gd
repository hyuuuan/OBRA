class_name UIOvalFrame
extends Control
## The gilt oval the player draws inside: the O of OBRA, at the size of a canvas.
##
## THE WORDMARK IS THE BRIEF. The O is not a letter with a hole in it, it is an ornate
## mirror -- a bevelled gold ring, a palmette at the top and the bottom, scrollwork at the
## corners, and a little landscape inside where the glass would be. The canvas is the same
## object with the landscape left out, because the player is the one who puts something in
## it. That is the whole conceit of the game in one shape, and it was sitting unused in the
## logo while the canvas was a cream square with four lime brackets on it.
##
## DRAWN, NOT SCALED. The O in the mark is 48 x 75 of pixel art and the canvas is square and
## ten times the size; stretching one into the other would smear every bevel it has. So this
## is built from the same palette and the same light direction and fitted to whatever
## rectangle it is given -- see UISkin.GILT_* and GILT_LIGHT.
##
## WHAT IT COVERS IS DELIBERATE. The opening is an ellipse inscribed in the canvas, so the
## matting hides the paper's four corners. Ink is clipped to the same ellipse by
## DrawingCanvas, because a canvas that accepts a stroke you cannot see is worse than one
## that refuses it: the stroke still costs ink and still goes to the recogniser.
##
## The recogniser does not care about the shape. preprocess.py crops to the ink and centres
## it in 28x28, so what reaches the model is the drawing, never the paper it was drawn on.

## How thick the moulding is, as a share of the smaller half-axis.
@export var moulding: float = 0.13
## How far the ornaments stand out past the moulding, in the same units.
##
## They are drawn OUTSIDE this control's own rectangle, deliberately. Godot does not clip a
## Control's drawing to its bounds, and the alternative -- insetting the opening far enough
## to hold them -- would have cost the canvas a fifth of its width to make room for
## decoration. The frame is exactly the size of the paper; the scrollwork hangs over the
## panel margin around it, which is what scrollwork on a real frame does.
@export var ornament_reach: float = 0.16
## Segments around the ring. Enough that the bevel turns smoothly at canvas size.
@export var segments: int = 96
## The plate that hides the corners of the paper behind the opening.
@export var matting: Color = UISkin.PANEL


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(queue_redraw)


## The opening, in this control's own space. DrawingCanvas asks for it so that the ink and
## the hole cannot drift apart -- there is one ellipse and both of them read it.
func opening() -> Rect2:
	var pad := _moulding_px()
	return Rect2(Vector2(pad, pad), size - Vector2(pad, pad) * 2.0)


func _moulding_px() -> float:
	return minf(size.x, size.y) * 0.5 * moulding


func _ornament_px() -> float:
	return minf(size.x, size.y) * 0.5 * ornament_reach


func _draw() -> void:
	var hole := opening()
	var centre := hole.position + hole.size * 0.5
	var radii := hole.size * 0.5
	_draw_matting(centre, radii)
	_draw_moulding(centre, radii)
	# Ornaments last: they sit proud of the moulding and overlap it.
	var reach := _ornament_px()
	_draw_finial(centre + Vector2(0.0, -radii.y), -1.0, reach)
	_draw_finial(centre + Vector2(0.0, radii.y), 1.0, reach)
	for corner: Vector2 in [Vector2(-0.7071, -0.7071), Vector2(0.7071, -0.7071),
			Vector2(-0.7071, 0.7071), Vector2(0.7071, 0.7071)]:
		_draw_scroll(centre + corner * radii, corner, reach * 0.72)


## Everything outside the opening but still on the paper, filled flat.
##
## Godot cannot draw a rectangle with an elliptical hole in it, so the plate is built as a
## fan of quads: for each step around the ellipse, one quad from the edge out to the edge of
## THIS CONTROL. Out to a fixed large radius instead -- which is what the first version did
## -- and the plate is a disc the size of the screen, painting over the panel, the HUD and
## the level behind them.
func _draw_matting(centre: Vector2, radii: Vector2) -> void:
	for index in range(segments):
		var a := TAU * float(index) / float(segments)
		var b := TAU * float(index + 1) / float(segments)
		draw_colored_polygon(PackedVector2Array([
			centre + Vector2(cos(a) * radii.x, sin(a) * radii.y),
			centre + Vector2(cos(b) * radii.x, sin(b) * radii.y),
			_edge_of_rect(centre, b),
			_edge_of_rect(centre, a),
		]), matting)


## Where a ray leaving the centre crosses this control's own rectangle. A shade past it, so
## two adjacent quads cannot leave a hairline of paper showing between them.
func _edge_of_rect(centre: Vector2, angle: float) -> Vector2:
	var direction := Vector2(cos(angle), sin(angle))
	var span := INF
	if absf(direction.x) > 0.0001:
		span = minf(span, ((size.x if direction.x > 0.0 else 0.0) - centre.x) / direction.x)
	if absf(direction.y) > 0.0001:
		span = minf(span, ((size.y if direction.y > 0.0 else 0.0) - centre.y) / direction.y)
	return centre + direction * (span + 2.0)


## The ring itself, one band at a time from the opening outward.
##
## Each band is a ring of quads rather than an arc, because the colour has to change AROUND
## the ring as well as across it: a moulding is lit where it faces the light and shadowed
## where it turns away, and an arc drawn in one colour is a flat washer.
func _draw_moulding(centre: Vector2, radii: Vector2) -> void:
	var thickness := _moulding_px()
	var bands := 5
	for band in range(bands):
		var inner := radii + Vector2.ONE * (thickness * float(band) / float(bands))
		var outer := radii + Vector2.ONE * (thickness * float(band + 1) / float(bands))
		# Where the band sits across the moulding: 0 at the opening, 1 at the outside. The
		# crown of a moulding is its middle, so that is where the light is strongest.
		var crown := 1.0 - absf(float(band) / float(bands - 1) * 2.0 - 1.0)
		for index in range(segments):
			var a := TAU * float(index) / float(segments)
			var b := TAU * float(index + 1) / float(segments)
			var normal := Vector2(cos((a + b) * 0.5), sin((a + b) * 0.5))
			draw_colored_polygon(PackedVector2Array([
				centre + Vector2(cos(a) * inner.x, sin(a) * inner.y),
				centre + Vector2(cos(b) * inner.x, sin(b) * inner.y),
				centre + Vector2(cos(b) * outer.x, sin(b) * outer.y),
				centre + Vector2(cos(a) * outer.x, sin(a) * outer.y),
			]), _tone(normal, crown))
	# A keyline on both edges, so the frame holds its shape against bright level art behind
	# it and against the paper in front of it.
	_draw_ellipse_line(centre, radii, UISkin.GILT_EDGE, 2.0)
	_draw_ellipse_line(centre, radii + Vector2.ONE * thickness, UISkin.GILT_EDGE, 2.0)


## Which gold a point on the moulding takes: how much it faces the light, and how near it is
## to the crown. Both matter -- the crown of a moulding on the shadowed side is still
## brighter than the hollow beside it.
func _tone(normal: Vector2, crown: float) -> Color:
	var lit := (normal.dot(UISkin.GILT_LIGHT) + 1.0) * 0.5
	var ramp: Array[Color] = [UISkin.GILT_EDGE, UISkin.GILT_DARK, UISkin.GILT_MID,
		UISkin.GILT, UISkin.GILT_LIT, UISkin.GILT_HI]
	var step := int(round(clampf(lit * 0.72 + crown * 0.42, 0.0, 1.0) * float(ramp.size() - 1)))
	return ramp[step]


func _draw_ellipse_line(centre: Vector2, radii: Vector2, colour: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in range(segments + 1):
		var a := TAU * float(index) / float(segments)
		points.append(centre + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_polyline(points, colour, width, true)


## The palmette at the top and the bottom of the frame. `facing` is -1 above the ring and
## +1 below it, so the same shape serves both ends without a second set of numbers.
##
## Five lobes fanning off a collar, not three on stalks. The first cut drew each lobe as a
## small disc on a thin line and the result was a pair of antennae -- at this size a thin
## line is one or two pixels and reads as wire, while what an ornament has to do is read as
## CARVED, which means mass. Everything here is a filled lobe with a keyline round it, and
## the lobes overlap so the cluster has one silhouette instead of five.
func _draw_finial(at: Vector2, facing: float, reach: float) -> void:
	var up := Vector2(0.0, facing)
	var lobes: Array[Vector2] = []
	for lobe: float in [-2.0, -1.0, 0.0, 1.0, 2.0]:
		# The outer lobes sit lower and smaller, so the cluster comes to a point.
		var fall := 1.0 - absf(lobe) * 0.30
		lobes.append(Vector2(lobe * reach * 0.46, 0.0) + up * reach * (0.30 + 0.78 * fall))
	# Keylines for the whole cluster first, then the fills, or each lobe's outline cuts a
	# groove across the one before it.
	for index in range(lobes.size()):
		var fall := 1.0 - absf(float(index) - 2.0) * 0.30
		draw_circle(at + lobes[index], reach * (0.20 + 0.26 * fall) + 2.0, UISkin.GILT_EDGE)
	for index in range(lobes.size()):
		var fall := 1.0 - absf(float(index) - 2.0) * 0.30
		var body := reach * (0.20 + 0.26 * fall)
		draw_circle(at + lobes[index], body, _tone(up * -1.0, 0.55 + 0.35 * fall))
		draw_circle(at + lobes[index] + UISkin.GILT_LIGHT * body * 0.34, body * 0.40,
			UISkin.GILT_HI if fall > 0.8 else UISkin.GILT_LIT)
	# The collar the fan springs from, sunk into the moulding so the two are one piece.
	draw_circle(at + up * reach * 0.10, reach * 0.40 + 2.0, UISkin.GILT_EDGE)
	draw_circle(at + up * reach * 0.10, reach * 0.40, _tone(up, 0.9))


## The scrollwork at the four diagonals: a trefoil of leaves curling off the moulding.
##
## Was a disc with a smaller disc bitten out of it, which is a bolt head. Three overlapping
## lobes with a keyline round the group read as foliage instead, which is what is carved
## into the corners of the O.
func _draw_scroll(at: Vector2, outward: Vector2, reach: float) -> void:
	var across := Vector2(-outward.y, outward.x)
	var seat := at + outward * reach * 0.42
	var leaves: Array[Vector2] = [
		seat + outward * reach * 0.52,
		seat + across * reach * 0.62 - outward * reach * 0.18,
		seat - across * reach * 0.62 - outward * reach * 0.18,
	]
	for leaf: Vector2 in leaves:
		draw_circle(leaf, reach * 0.60 + 2.0, UISkin.GILT_EDGE)
	draw_circle(seat, reach * 0.52 + 2.0, UISkin.GILT_EDGE)
	for leaf: Vector2 in leaves:
		draw_circle(leaf, reach * 0.60, _tone((leaf - seat).normalized(), 0.62))
		draw_circle(leaf + UISkin.GILT_LIGHT * reach * 0.22, reach * 0.22, UISkin.GILT_LIT)
	draw_circle(seat, reach * 0.52, _tone(outward, 0.95))
	draw_circle(seat + UISkin.GILT_LIGHT * reach * 0.18, reach * 0.20, UISkin.GILT_HI)
