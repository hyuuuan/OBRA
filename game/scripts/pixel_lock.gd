extends Control
## Font-independent lock mark built from hard-edged pixel rectangles.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var unit := maxf(3.0, floorf(minf(size.x, size.y) / 12.0))
	var center := size * 0.5
	var body := Rect2(center.x - unit * 4.0, center.y - unit, unit * 8.0, unit * 6.0)
	draw_rect(body, Color(0.68, 0.67, 0.52, 1.0))
	draw_rect(Rect2(center.x - unit * 2.5, center.y - unit * 5.0, unit * 5.0, unit), Color(0.68, 0.67, 0.52, 1.0))
	draw_rect(Rect2(center.x - unit * 3.5, center.y - unit * 4.0, unit, unit * 4.0), Color(0.68, 0.67, 0.52, 1.0))
	draw_rect(Rect2(center.x + unit * 2.5, center.y - unit * 4.0, unit, unit * 4.0), Color(0.68, 0.67, 0.52, 1.0))
	draw_rect(Rect2(center.x - unit * 0.5, center.y + unit, unit, unit * 2.5), Color(0.16, 0.18, 0.13, 1.0))
