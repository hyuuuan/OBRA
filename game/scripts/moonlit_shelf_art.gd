extends RefCounted
## One native-pixel outline for every moonlit floating shelf, solid or one-way.

const EdgeArt = preload("res://scripts/terrain_edge_art.gd")


static func draw_on(canvas: CanvasItem, texture: Texture2D, rect: Rect2) -> void:
	var width := rect.size.x
	var height := float(texture.get_height())
	var corner := EdgeArt.radius(rect, height * 0.5)
	var contour := EdgeArt.top_edge(width, corner)
	# A narrow tuck at the foot gives the shelf a rounded underside too.
	var foot := minf(10.0, width / 3.0)
	contour.append_array(PackedVector2Array([
		Vector2(width, height * 0.8125), Vector2(width - foot * 0.4, height * 0.9375),
		Vector2(width - foot, height), Vector2(foot, height),
		Vector2(foot * 0.4, height * 0.9375), Vector2(0.0, height * 0.8125)]))
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	for point in contour:
		points.append(rect.position - Vector2(0, 8) + point)
		uv.append(point / texture.get_size())
	canvas.draw_polygon(points, PackedColorArray([Color.WHITE]), uv, texture)
