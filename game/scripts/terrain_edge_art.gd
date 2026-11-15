extends RefCounted
## Pixel-stepped shoulders for exposed terrain. Physics keeps the authored walk line.

const RADIUS := 24.0
const PIXEL_STEP := 3.0


static func neighbour_top(rect: Rect2, side: int, neighbours: Array[Rect2]) -> float:
	var top := INF
	var edge := rect.position.x if side < 0 else rect.end.x
	for other in neighbours:
		if other.end.y <= rect.position.y:
			continue
		var meets := other.position.x < edge and other.end.x >= edge if side < 0 \
			else other.position.x <= edge and other.end.x > edge
		if meets:
			top = minf(top, other.position.y)
	return top


static func radius(rect: Rect2, limit: float = RADIUS) -> float:
	return minf(limit, minf(rect.size.x / 3.0, rect.size.y))


static func _inset(r: float, depth: float) -> float:
	var dy := maxf(r - depth, 0.0)
	return roundf(r - sqrt(maxf(0.0, r * r - dy * dy)))


## Horizontal slices preserve the original texture phase through the cut.
static func rows(bounds: Rect2, corners: Vector2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var depth := 0.0
	var rounded := maxf(corners.x, corners.y)
	while depth < rounded:
		var next := minf(depth + PIXEL_STEP, rounded)
		var left := _inset(corners.x, depth)
		var right := _inset(corners.y, depth)
		result.append(Rect2(bounds.position + Vector2(left, depth),
			Vector2(bounds.size.x - left - right, next - depth)))
		depth = next
	if depth < bounds.size.y:
		result.append(Rect2(bounds.position + Vector2(0.0, depth),
			Vector2(bounds.size.x, bounds.size.y - depth)))
	return result


## From left shoulder to right shoulder, for shelves with a separate underside contour.
static func top_edge(width: float, r: float) -> PackedVector2Array:
	var left := PackedVector2Array([Vector2(0.0, r)])
	var depth := ceilf(r / PIXEL_STEP) * PIXEL_STEP - PIXEL_STEP
	while depth >= 0.0:
		var x := _inset(r, depth)
		if x != left[-1].x:
			var y := minf(r, depth + PIXEL_STEP)
			if y != left[-1].y:
				left.append(Vector2(left[-1].x, y))
			left.append(Vector2(x, y))
		depth -= PIXEL_STEP
	left.append(Vector2(left[-1].x, 0.0))
	var result := left.duplicate()
	for index in range(left.size() - 1, -1, -1):
		result.append(Vector2(width - left[index].x, left[index].y))
	return result
