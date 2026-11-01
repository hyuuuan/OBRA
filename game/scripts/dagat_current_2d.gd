extends Node2D
## The strong water's visible leftward flow. The level asks this same footprint for its force,
## so the moving marks cannot advertise a current somewhere the player is free to drift.

var water_rect := Rect2()
var waterline_y := 560.0
var camera: Camera2D
const EDGE_FADE := 180.0
const FLOW_SPEED := 140.0
const COLUMN_GAP := 300.0
const ROW_GAP := 175.0

var _flow_time := 0.0
var _reduce_motion := false


func _ready() -> void:
	z_index = -1
	var profile := get_node_or_null(^"/root/PlayerProfile")
	if profile != null:
		_reduce_motion = bool(profile.call("get_setting", "reduce_motion"))
		profile.connect(&"settings_changed", _on_setting_changed)
	queue_redraw()


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "reduce_motion":
		_reduce_motion = bool(value)


func _process(delta: float) -> void:
	if not _reduce_motion:
		_flow_time += delta
	queue_redraw()


func strength_at(at: Vector2) -> float:
	if not water_rect.has_point(at):
		return 0.0
	var edge := minf(at.x - water_rect.position.x, water_rect.end.x - at.x)
	return smoothstep(0.0, EDGE_FADE, edge)


func _draw() -> void:
	if not water_rect.has_area():
		return
	var view := water_rect
	if is_instance_valid(camera):
		var size := camera.get_viewport_rect().size / camera.zoom
		view = water_rect.intersection(Rect2(camera.get_screen_center_position() - size * 0.5, size).grow(80.0))
	if not view.has_area():
		return
	# Short, arrow-headed streams all travel left, from the surface down through the column.
	# Their dark rim keeps the direction legible against both white surf and the deep blue ruins.
	var shift := _flow_time * FLOW_SPEED
	var first_row := maxi(0, int(floorf((view.position.y - waterline_y - 44.0) / ROW_GAP)))
	var last_row := int(ceilf((view.end.y - waterline_y - 44.0) / ROW_GAP))
	for row in range(first_row, last_row + 1):
		var y := waterline_y + 56.0 + row * ROW_GAP
		if y > water_rect.end.y - 20.0:
			continue
		var stagger := fposmod(row * 93.0, COLUMN_GAP)
		var first := int(floorf((view.position.x - water_rect.position.x + shift - stagger) / COLUMN_GAP))
		var last := int(ceilf((view.end.x - water_rect.position.x + shift - stagger) / COLUMN_GAP))
		for column in range(first, last + 1):
			var jitter := fposmod(row * 37.0 + column * 53.0, 43.0) - 21.0
			var at := Vector2(water_rect.position.x + column * COLUMN_GAP + stagger - shift, y + jitter)
			var strength := strength_at(at)
			if strength <= 0.0:
				continue
			_draw_stream(at.round(), 40.0 + fposmod(row * 17.0 + column * 11.0, 44.0),
				0.5 * strength, (row + column) % 3 != 0)
	# Denser broken foam along the top makes the boundary readable before the player dives.
	if view.position.y <= waterline_y + 40.0:
		var foam_shift := _flow_time * FLOW_SPEED
		var first := int(floorf((view.position.x - water_rect.position.x + foam_shift) / 180.0))
		var last := int(ceilf((view.end.x - water_rect.position.x + foam_shift) / 180.0))
		for column in range(first, last + 1):
			var at := Vector2(water_rect.position.x + column * 180.0 - foam_shift, waterline_y + 10.0)
			var alpha := strength_at(at) * 0.8
			if alpha <= 0.0:
				continue
			_draw_stream(at.round(), 34.0, alpha)
			draw_rect(Rect2(at.round() + Vector2(18.0, 10.0), Vector2(16.0, 3.0)), Color(0.7, 0.96, 1.0, alpha * 0.6))
			draw_rect(Rect2(at.round() + Vector2(42.0, 7.0), Vector2(4.0, 3.0)), Color(0.7, 0.96, 1.0, alpha * 0.7))


func _draw_stream(at: Vector2, length: float, alpha: float, headed := true) -> void:
	# Broken, slightly bending trails belong to the water; the short fins keep their leftward
	# direction readable even in a still frame or with Reduce Motion enabled.
	var lines := [PackedVector2Array([at + Vector2(length, 0.0),
		at + Vector2(roundf(length * 0.65), 2.0), at + Vector2(roundf(length * 0.3), -2.0), at])]
	if headed:
		lines.append(PackedVector2Array([at + Vector2(12.0, -8.0), at, at + Vector2(12.0, 8.0)]))
	for points: PackedVector2Array in lines:
		draw_polyline(points, Color(0.015, 0.14, 0.23, alpha * 0.75), 7.0)
		draw_polyline(points, Color(0.65, 0.94, 1.0, alpha), 3.0)
