extends RefCounted
## One native-pixel outline for every moonlit floating shelf, solid or one-way.


static func draw_on(canvas: CanvasItem, texture: Texture2D, rect: Rect2) -> void:
	var width := rect.size.x
	var height := float(texture.get_height())
	var corner := minf(8.0, minf(width * 0.25, height * 0.5))
	var step := corner * 0.5
	var contour := PackedVector2Array([
		Vector2(corner, 0), Vector2(width - corner, 0),
		Vector2(width - corner, step), Vector2(width - step, step),
		Vector2(width - step, corner), Vector2(width, corner),
		Vector2(width, height), Vector2(0, height), Vector2(0, corner),
		Vector2(step, corner), Vector2(step, step), Vector2(corner, step)])
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	for point in contour:
		points.append(rect.position - Vector2(0, 8) + point)
		uv.append(point / texture.get_size())
	canvas.draw_polygon(points, PackedColorArray([Color.WHITE]), uv, texture)
