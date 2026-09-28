extends RefCounted
## THE SHADOW A THING CASTS ON THE GROUND IT STANDS ON -- the one mark that says it is standing
## there at all.
##
## Without it every prop in Dagat was pasted onto the picture: a jar, a clam, a lantern and a
## pillar each ended on the sand in a clean line with nothing under it, and a thing that makes no
## mark on what it stands on reads as a cut-out laid over the background rather than as an object
## in the place. Light in this game comes from above -- through the surface, under the water -- so
## the shadow is directly under the foot, a little wider than the thing, darkest in its middle.
##
## ⚠ WHOLE-PIXEL ROWS, NOT A RADIAL GRADIENT. The lantern's glow learned this first: a soft
## falloff is the one thing in the picture that is not pixel art, and it reads as a rendering
## fault. Two stepped ellipses, the inner over the outer, so the middle is darker than the rim.
##
## Drawn in whatever units the caller is drawing in -- the lantern's art pixels, or world pixels
## for a scaled sprite -- centred on the caller's origin, which for everything here is its foot.

const TONE := Color(0.016, 0.027, 0.075, 1.0)


static func draw(item: CanvasItem, half_width: float, half_height: float, alpha: float) -> void:
	for layer in range(2):
		var shrink := 1.0 - 0.4 * float(layer)
		var reach := half_width * shrink
		var rows := maxf(1.0, roundf(half_height * shrink))
		var tone := Color(TONE, alpha * (0.5 if layer == 0 else 0.62))
		for row in range(int(-rows), int(rows) + 1):
			var t := float(row) / (rows + 0.5)
			var half := roundf(reach * sqrt(maxf(0.0, 1.0 - t * t)))
			if half < 1.0:
				continue
			item.draw_rect(Rect2(-half, float(row), half * 2.0, 1.0), tone)
