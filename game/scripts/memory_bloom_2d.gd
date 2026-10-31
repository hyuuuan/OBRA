extends Sprite2D
## A landscape reaching the ground, with the exact saved polylines carried into it.
var ink: Array = []


func _draw() -> void:
	if ink.is_empty() or texture == null:
		return
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for flat: Array in ink:
		for i in range(0, flat.size(), 2):
			var point := Vector2(float(flat[i]), float(flat[i + 1]))
			low = low.min(point)
			high = high.max(point)
	var room := texture.get_size() * 0.45
	var fit := minf(room.x / maxf(1, high.x - low.x), room.y / maxf(1, high.y - low.y))
	# Transform the whole polyline; never round, reorder, smooth, or invent its points.
	draw_set_transform(-(low + high) * 0.5 * fit, 0.0, Vector2.ONE * fit)
	for flat: Array in ink:
		var line := PackedVector2Array()
		for i in range(0, flat.size(), 2):
			line.append(Vector2(float(flat[i]), float(flat[i + 1])))
		if line.size() >= 2:
			draw_polyline(line, Color(0.12, 0.1, 0.09, 0.7), 2.0 / fit)
