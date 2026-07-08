@tool
class_name PlaceholderProp2D
extends Node2D
## Lightweight editable stand-ins for future painted or sprite assets.

@export_enum("sky", "mountain", "hill", "tree", "bush", "grass", "rock", "ground_strip", "frame")
var prop_type: String = "rock"
@export var size: Vector2 = Vector2(120.0, 120.0)
@export var color: Color = Color(0.35, 0.45, 0.4, 1.0)
@export var accent_color: Color = Color(0.2, 0.28, 0.24, 1.0)
@export_range(1, 32) var segments: int = 8


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	match prop_type:
		"sky":
			_draw_sky()
		"mountain":
			_draw_mountain()
		"hill":
			_draw_hill()
		"tree":
			_draw_tree()
		"bush":
			_draw_bush()
		"grass":
			_draw_grass()
		"ground_strip":
			_draw_ground_strip()
		"frame":
			_draw_frame()
		_:
			_draw_rock()


func _draw_sky() -> void:
	var strip_count := maxi(8, segments)
	for i in range(strip_count):
		var t0 := float(i) / float(strip_count)
		var t1 := float(i + 1) / float(strip_count)
		var eased := t0 * t0 * (3.0 - 2.0 * t0)
		var y := lerpf(-size.y, 0.0, t0)
		var height := maxf(2.0, size.y * (t1 - t0) + 1.0)
		draw_rect(
			Rect2(Vector2(-size.x * 0.5, y), Vector2(size.x, height)),
			color.lerp(accent_color, eased)
		)
	var horizon_height := maxf(20.0, size.y * 0.09)
	draw_rect(
		Rect2(Vector2(-size.x * 0.5, -horizon_height), Vector2(size.x, horizon_height)),
		accent_color.lerp(Color.WHITE, 0.12)
	)
	draw_line(Vector2(-size.x * 0.5, -horizon_height), Vector2(size.x * 0.5, -horizon_height), accent_color, 2.0)


func _draw_mountain() -> void:
	var half_width := size.x * 0.5
	var points := PackedVector2Array([
		Vector2(-half_width, 0.0),
		Vector2(-size.x * 0.23, -size.y * 0.78),
		Vector2(-size.x * 0.06, -size.y * 0.42),
		Vector2(size.x * 0.18, -size.y),
		Vector2(half_width, 0.0)
	])
	draw_colored_polygon(points, color)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-size.x * 0.23, -size.y * 0.78),
			Vector2(-size.x * 0.06, -size.y * 0.42),
			Vector2(size.x * 0.08, -size.y * 0.48)
		]),
		color.lerp(accent_color, 0.35)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(size.x * 0.18, -size.y),
			Vector2(size.x * 0.08, -size.y * 0.48),
			Vector2(size.x * 0.3, -size.y * 0.22)
		]),
		color.lerp(Color.WHITE, 0.12)
	)
	_draw_closed_polyline(points, accent_color, 2.0)


func _draw_hill() -> void:
	var half_width := size.x * 0.5
	var points := PackedVector2Array()
	points.append(Vector2(-half_width, 0.0))
	var count := maxi(2, segments)
	for i in range(count + 1):
		var t := float(i) / float(count)
		var x := lerpf(-half_width, half_width, t)
		var y := -sin(t * PI) * size.y
		points.append(Vector2(x, y))
	points.append(Vector2(half_width, 0.0))
	draw_colored_polygon(points, color)
	draw_polyline(points, accent_color, 2.0, true)
	for line_index in range(1, 4):
		var t := float(line_index) / 4.0
		var y := -size.y * t * 0.38
		draw_arc(Vector2(0.0, 0.0), half_width * (1.0 - t * 0.1), PI + 0.18, TAU - 0.18, 28, color.lerp(accent_color, 0.38), 1.2)
		draw_line(Vector2(-half_width * 0.82, y), Vector2(half_width * 0.82, y + size.y * 0.03), color.lerp(accent_color, 0.18), 1.0)


func _draw_tree() -> void:
	var trunk_width := maxf(10.0, size.x * 0.16)
	var trunk_height := size.y * 0.55
	draw_rect(
		Rect2(Vector2(-trunk_width * 0.5, -trunk_height), Vector2(trunk_width, trunk_height)),
		accent_color
	)
	draw_line(Vector2(-trunk_width * 0.15, -trunk_height * 0.9), Vector2(-trunk_width * 0.2, -trunk_height * 0.12), accent_color.lerp(Color.WHITE, 0.18), 2.0)
	var canopy_radius := maxf(size.x, size.y) * 0.23
	var canopy_shadow := color.lerp(accent_color, 0.28)
	draw_circle(Vector2(0.0, -trunk_height - canopy_radius * 0.25), canopy_radius * 1.06, canopy_shadow)
	draw_circle(Vector2(-canopy_radius * 0.7, -trunk_height), canopy_radius * 0.84, canopy_shadow)
	draw_circle(Vector2(canopy_radius * 0.72, -trunk_height * 0.95), canopy_radius * 0.78, canopy_shadow)
	draw_circle(Vector2(0.0, -trunk_height - canopy_radius * 0.25), canopy_radius, color)
	draw_circle(Vector2(-canopy_radius * 0.7, -trunk_height), canopy_radius * 0.78, color)
	draw_circle(Vector2(canopy_radius * 0.72, -trunk_height * 0.95), canopy_radius * 0.72, color.lerp(Color.WHITE, 0.06))
	draw_line(Vector2(-canopy_radius * 0.45, -trunk_height - canopy_radius * 0.58), Vector2(canopy_radius * 0.32, -trunk_height - canopy_radius * 0.72), color.lerp(Color.WHITE, 0.18), 2.0)


func _draw_bush() -> void:
	var radius := maxf(12.0, size.y * 0.32)
	draw_circle(Vector2(-size.x * 0.22, -radius * 0.45), radius, color)
	draw_circle(Vector2(size.x * 0.05, -radius * 0.82), radius * 1.1, color)
	draw_circle(Vector2(size.x * 0.3, -radius * 0.38), radius * 0.82, color)
	draw_rect(Rect2(Vector2(-size.x * 0.5, -radius * 0.52), Vector2(size.x, radius * 0.55)), color)
	draw_arc(Vector2(-size.x * 0.18, -radius * 0.55), radius * 0.7, PI * 1.1, TAU * 0.92, 14, color.lerp(Color.WHITE, 0.14), 2.0)
	draw_arc(Vector2(size.x * 0.2, -radius * 0.5), radius * 0.5, PI * 1.08, TAU * 0.9, 12, accent_color, 1.6)


func _draw_grass() -> void:
	var blade_count := maxi(1, segments)
	var half_width := size.x * 0.5
	for i in range(blade_count):
		var t := 0.5
		if blade_count > 1:
			t = float(i) / float(blade_count - 1)
		var x := lerpf(-half_width, half_width, t)
		var blade_height := size.y * lerpf(0.45, 1.0, fmod(float(i) * 0.37, 1.0))
		var blade_color := color.lerp(accent_color, fmod(float(i) * 0.23, 1.0) * 0.35)
		draw_line(Vector2(x, 0.0), Vector2(x + sin(float(i)) * 7.0, -blade_height), blade_color, 3.0)
	draw_line(Vector2(-half_width, 0.0), Vector2(half_width, 0.0), accent_color, 2.0)


func _draw_rock() -> void:
	var half_width := size.x * 0.5
	var points := PackedVector2Array([
		Vector2(-half_width, 0.0),
		Vector2(-size.x * 0.35, -size.y * 0.42),
		Vector2(-size.x * 0.05, -size.y * 0.62),
		Vector2(size.x * 0.34, -size.y * 0.48),
		Vector2(half_width, -size.y * 0.12),
		Vector2(size.x * 0.28, 0.0)
	])
	draw_colored_polygon(points, color)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-size.x * 0.35, -size.y * 0.42),
			Vector2(-size.x * 0.05, -size.y * 0.62),
			Vector2(size.x * 0.1, -size.y * 0.28),
			Vector2(-size.x * 0.18, -size.y * 0.18)
		]),
		color.lerp(Color.WHITE, 0.16)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(size.x * 0.1, -size.y * 0.28),
			Vector2(size.x * 0.34, -size.y * 0.48),
			Vector2(half_width, -size.y * 0.12),
			Vector2(size.x * 0.28, 0.0)
		]),
		color.lerp(accent_color, 0.25)
	)
	_draw_closed_polyline(points, accent_color, 2.0)


func _draw_ground_strip() -> void:
	draw_rect(Rect2(Vector2(-size.x * 0.5, -size.y), size), color)
	var cap_height := minf(14.0, size.y * 0.45)
	draw_rect(Rect2(Vector2(-size.x * 0.5, -size.y), Vector2(size.x, cap_height)), color.lerp(Color.WHITE, 0.1))
	draw_rect(Rect2(Vector2(-size.x * 0.5, -size.y + cap_height), Vector2(size.x, maxf(1.0, cap_height * 0.55))), accent_color.lerp(color, 0.25))
	draw_line(Vector2(-size.x * 0.5, -size.y), Vector2(size.x * 0.5, -size.y), accent_color, 4.0)
	var pebble_count := maxi(10, segments * 4)
	for i in range(pebble_count):
		var t := float(i) / float(pebble_count)
		var x := lerpf(-size.x * 0.48, size.x * 0.48, t)
		var y := -size.y + cap_height * 1.8 + fmod(float(i) * 11.0, maxf(8.0, size.y - cap_height * 2.0))
		var radius := 1.2 + fmod(float(i) * 1.7, 2.8)
		draw_circle(Vector2(x, y), radius, color.lerp(accent_color, 0.22))


func _draw_frame() -> void:
	var trunk_width := maxf(20.0, size.x * 0.2)
	draw_rect(Rect2(Vector2(-trunk_width * 0.5, -size.y), Vector2(trunk_width, size.y)), accent_color)
	draw_circle(Vector2(0.0, -size.y), size.x * 0.5, color)
	draw_line(Vector2(0.0, -size.y * 0.72), Vector2(size.x * 0.28, -size.y * 0.88), accent_color, 5.0)
	draw_line(Vector2(0.0, -size.y * 0.58), Vector2(-size.x * 0.25, -size.y * 0.78), accent_color, 4.0)
	draw_line(Vector2(-trunk_width * 0.15, -size.y * 0.95), Vector2(-trunk_width * 0.18, -size.y * 0.08), accent_color.lerp(Color.WHITE, 0.16), 2.0)


func _draw_closed_polyline(points: PackedVector2Array, line_color: Color, width: float) -> void:
	var closed := points.duplicate()
	if closed.size() > 0:
		closed.append(closed[0])
	draw_polyline(closed, line_color, width, true)
