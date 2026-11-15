extends Sprite2D
## A landscape reaching the ground, with the exact saved polylines signed into it.
var ink: Array = []
## The sprite's world scale, set before it is shown. The signature is sized on screen, and it
## cannot read `scale` here: Motion.fade_in resets scale to one before the level restores it.
var world_scale := 1.0

## ⚠ HER LINES ARE A SIGNATURE, NOT THE PICTURE. Fitted to 45% of a 1000px landscape they
## became a giant chevron of hairlines across the whole place, which read as a rendering fault.
const SIGNATURE := 140.0
const INK_WIDTH := 4.0
const INK := Color(0.24, 0.16, 0.12, 0.9)
## A paper halo under the ink, so it reads on the night forest as well as the bright fiesta.
const HALO := Color(0.96, 0.94, 0.89, 0.6)
const HALO_EXTRA := 4.0
## Where the signature sits: the lower right of the place, inside its body, from the centre.
const CORNER := Vector2(0.3, 0.22)
## Above every restored place (they overlap, the earliest saved in front) and below the pair:
## drawn at its own place's depth, a signature fell under its neighbours and vanished.
const SIGNATURE_Z := -3

var _signature: Node2D


func _ready() -> void:
	_signature = Node2D.new()
	_signature.name = "Signature"
	_signature.z_as_relative = false
	_signature.z_index = SIGNATURE_Z
	_signature.draw.connect(_draw_signature)
	add_child(_signature)


## The signature's box in this sprite's own space: longest side SIGNATURE on screen.
func signature_rect() -> Rect2:
	var bounds := _bounds()
	if bounds.size == Vector2.ZERO or texture == null:
		return Rect2()
	var fit := _fit(bounds)
	var size := bounds.size * fit
	return Rect2(texture.get_size() * CORNER - size * 0.5, size)


func _draw_signature() -> void:
	var bounds := _bounds()
	if bounds.size == Vector2.ZERO or texture == null:
		return
	var fit := _fit(bounds)
	# Transform the whole polyline; never round, reorder, smooth, or invent its points.
	_signature.draw_set_transform(texture.get_size() * CORNER - bounds.get_center() * fit, 0.0, Vector2.ONE * fit)
	for layer: Array in [[HALO, INK_WIDTH + HALO_EXTRA], [INK, INK_WIDTH]]:
		var colour: Color = layer[0]
		var width: float = float(layer[1]) / (world_scale * fit)
		for flat: Array in ink:
			var line := PackedVector2Array()
			for i in range(0, flat.size(), 2):
				line.append(Vector2(float(flat[i]), float(flat[i + 1])))
			if line.size() < 2:
				continue
			_signature.draw_polyline(line, colour, width)
			# Round every joint and end, or a thick stroke shows notches at its turns.
			for point in line:
				_signature.draw_circle(point, width * 0.5, colour)


func _bounds() -> Rect2:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for flat: Array in ink:
		for i in range(0, flat.size() - 1, 2):
			var point := Vector2(float(flat[i]), float(flat[i + 1]))
			low = low.min(point)
			high = high.max(point)
	if low.x > high.x:
		return Rect2()
	return Rect2(low, (high - low).max(Vector2.ONE))


func _fit(bounds: Rect2) -> float:
	return SIGNATURE / maxf(world_scale, 0.001) / maxf(bounds.size.x, bounds.size.y)
