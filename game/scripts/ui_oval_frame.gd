class_name UIOvalFrame
extends Control
## The gilt oval the player draws inside: the O of OBRA, at the size of a canvas.
##
## THE WORDMARK IS THE BRIEF. The O is not a letter with a hole in it, it is an ornate
## mirror -- a bevelled gold ring, a palmette top and bottom, scrollwork at the corners, and
## a little landscape inside where the glass would be. The canvas is the same object with
## the landscape left out, because the player is the one who puts something in it.
##
## THIS IS THE PANEL, NOT SOMETHING INSIDE ONE. There is no rectangle behind it any more.
## The first version drew the oval on top of the draw panel's square frame and the two read
## as two objects -- a mirror sitting in a box -- which is exactly one frame too many. What
## opens now is the frame itself, over the scrim, with the header above it and the buttons
## below.
##
## AND IT IS DRAWN AS PIXELS. Every curve here used to be a fan of ninety-six polygons,
## which is smooth, and smooth is the one thing this interface is not: the logo it comes
## from is chunky 8-bit art and so is everything around it. So the frame is rasterised into
## a small image -- one art pixel per PIXEL screen pixels -- and blown up with nearest
## filtering. The stair-stepping down the sides of the ring is the point, not an artifact.
##
## The recogniser does not care about the shape. preprocess.py crops to the ink and centres
## it in 28x28, so what reaches the model is the drawing, never the paper it was drawn on.

## Screen pixels per art pixel. Six is the chunk the wordmark is drawn at.
const PIXEL := 6.0

## How thick the moulding is, as a share of the smaller half-axis.
@export var moulding: float = 0.15
## How far the ornaments stand out past the moulding, in the same units. They fall outside
## this control's own rectangle, so the raster is grown by this much on every side.
@export var ornament_reach: float = 0.17
## Draw the paper itself -- the cream oval the ink lands on.
##
## THE FRAME IS TWO NODES, ONE EITHER SIDE OF THE CANVAS. It has to be: the paper the player
## draws on is a square viewport, and a square is exactly what must not be visible. So the
## BACK copy fills the opening with paper and sits behind the canvas, the canvas draws its
## own square of the same cream over the middle of it, and the FRONT copy draws the ring on
## top and covers the square's four corners with moulding.
##
## The first attempt did it with a dark plate over the corners instead. That works and it
## looks like exactly what it is -- an oval in a black box -- which was the whole complaint.
## Cream over cream leaves nothing to see but the oval.
@export var shows_paper: bool = false
## Draw the moulding and the ornaments. The back copy does not.
@export var shows_moulding: bool = true
## What the paper is. Not printer white: the ink is black and the drawing is the point, so
## this only comes far enough off white to stop the oval glaring.
@export var paper: Color = Color(0.965, 0.95, 0.9, 1.0)

var _texture: ImageTexture
var _bleed: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _ready() -> void:
	resized.connect(_rebuild)
	_rebuild()


## The ellipse ink is allowed inside. Pulled a whole art pixel in from the opening the
## frame draws, so a stroke can never end up under the moulding's stepped edge -- with both
## reading the same number, the quantised edge and the smooth one disagree by up to a pixel
## and ink goes missing along the rim.
func opening() -> Rect2:
	var pad := _moulding_px() + PIXEL
	return Rect2(Vector2(pad, pad), size - Vector2(pad, pad) * 2.0)


func _moulding_px() -> float:
	return minf(size.x, size.y) * 0.5 * moulding


func _ornament_px() -> float:
	return minf(size.x, size.y) * 0.5 * ornament_reach


func _draw() -> void:
	if _texture == null:
		return
	var extent := Vector2(_texture.get_width(), _texture.get_height()) * PIXEL
	draw_texture_rect(_texture, Rect2(Vector2(-_bleed, -_bleed), extent), false)


## Rasterise the whole frame once, at art resolution.
##
## Per pixel rather than per shape: everything here is a question about one point -- how far
## out of the opening is it, which way is it facing, is it under an ornament -- and asking
## it once per art pixel is both simpler than clipping polygons and the only way to get an
## edge that steps instead of feathering.
func _rebuild() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	_bleed = ceilf(_ornament_px() / PIXEL) * PIXEL
	var cols := int(ceilf((size.x + _bleed * 2.0) / PIXEL))
	var rows := int(ceilf((size.y + _bleed * 2.0) / PIXEL))
	var image := Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	var hole := opening()
	var centre := hole.position + hole.size * 0.5
	var radii := (size - Vector2.ONE * _moulding_px() * 2.0) * 0.5
	var thickness := _moulding_px()
	# The moulding's outer edge, in the same normalised units the inside is measured in.
	var outer := 1.0 + thickness / minf(radii.x, radii.y)

	for row in range(rows):
		for col in range(cols):
			# The centre of this art pixel, in the control's own coordinates.
			var at := Vector2(float(col) + 0.5, float(row) + 0.5) * PIXEL - Vector2.ONE * _bleed
			var offset := (at - centre) / radii
			var rho := offset.length()
			if rho <= 1.0:
				if shows_paper:
					image.set_pixel(col, row, paper)
				continue
			if not shows_moulding:
				continue
			if rho <= outer:
				# Across the moulding, 0 at the opening and 1 at the outside. A moulding is
				# brightest at its crown, which is the middle, not either edge.
				var across := (rho - 1.0) / maxf(0.0001, outer - 1.0)
				var crown := 1.0 - absf(across * 2.0 - 1.0)
				image.set_pixel(col, row, _tone(offset.normalized(), crown))

	if shows_moulding:
		_stamp_ornaments(image, centre, radii)
	_texture = ImageTexture.create_from_image(image)
	queue_redraw()


## The palmettes and the scrollwork, stamped into the same raster.
##
## Filled lobes with a keyline round the group, not discs on stalks. At this chunk a thin
## line is one art pixel and reads as wire; what an ornament has to do is read as CARVED,
## which means mass.
func _stamp_ornaments(image: Image, centre: Vector2, radii: Vector2) -> void:
	var reach := _ornament_px()
	var lobes: Array = []
	# Top and bottom palmettes: five lobes fanning off a collar, tallest in the middle.
	for facing: float in [-1.0, 1.0]:
		var root := centre + Vector2(0.0, facing * radii.y)
		var up := Vector2(0.0, facing)
		for lobe: float in [-2.0, -1.0, 0.0, 1.0, 2.0]:
			var fall := 1.0 - absf(lobe) * 0.30
			lobes.append([root + Vector2(lobe * reach * 0.44, 0.0) + up * reach * (0.26 + 0.70 * fall),
				reach * (0.20 + 0.24 * fall), up * -1.0, 0.55 + 0.35 * fall])
		lobes.append([root + up * reach * 0.08, reach * 0.38, up, 0.9])
	# Scrollwork at the four diagonals: a trefoil curling off the moulding.
	for corner: Vector2 in [Vector2(-0.7071, -0.7071), Vector2(0.7071, -0.7071),
			Vector2(-0.7071, 0.7071), Vector2(0.7071, 0.7071)]:
		var seat := centre + corner * radii + corner * reach * 0.34
		var across := Vector2(-corner.y, corner.x)
		for leaf: Vector2 in [corner * reach * 0.46,
				across * reach * 0.54 - corner * reach * 0.14,
				-across * reach * 0.54 - corner * reach * 0.14]:
			lobes.append([seat + leaf, reach * 0.44, leaf.normalized(), 0.62])
		lobes.append([seat, reach * 0.40, corner, 0.95])

	# Keyline pass first, then the fills, or each lobe's outline cuts a groove across the
	# one before it and the cluster comes apart into separate beads.
	for lobe: Array in lobes:
		_stamp_disc(image, lobe[0], float(lobe[1]) + PIXEL, UISkin.GILT_EDGE)
	for lobe: Array in lobes:
		_stamp_disc(image, lobe[0], float(lobe[1]), _tone(lobe[2], float(lobe[3])))
		_stamp_disc(image, Vector2(lobe[0]) + UISkin.GILT_LIGHT * float(lobe[1]) * 0.38,
			float(lobe[1]) * 0.34, UISkin.GILT_LIT)


func _stamp_disc(image: Image, at: Vector2, radius: float, colour: Color) -> void:
	var low := ((at - Vector2.ONE * radius) + Vector2.ONE * _bleed) / PIXEL
	var high := ((at + Vector2.ONE * radius) + Vector2.ONE * _bleed) / PIXEL
	for row in range(maxi(0, int(floorf(low.y))), mini(image.get_height(), int(ceilf(high.y)) + 1)):
		for col in range(maxi(0, int(floorf(low.x))), mini(image.get_width(), int(ceilf(high.x)) + 1)):
			var point := Vector2(float(col) + 0.5, float(row) + 0.5) * PIXEL - Vector2.ONE * _bleed
			if point.distance_to(at) <= radius:
				image.set_pixel(col, row, colour)


## Which gold a point on the moulding takes: how much it faces the light, and how near it is
## to the crown. Both matter -- the crown of a moulding on the shadowed side is still
## brighter than the hollow beside it.
func _tone(normal: Vector2, crown: float) -> Color:
	var lit := (normal.dot(UISkin.GILT_LIGHT) + 1.0) * 0.5
	var ramp: Array[Color] = [UISkin.GILT_EDGE, UISkin.GILT_DARK, UISkin.GILT_MID,
		UISkin.GILT, UISkin.GILT_LIT, UISkin.GILT_HI]
	var step := int(round(clampf(lit * 0.70 + crown * 0.44, 0.0, 1.0) * float(ramp.size() - 1)))
	return ramp[step]
