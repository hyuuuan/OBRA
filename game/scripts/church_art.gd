extends RefCounted
## Registration for tools/build_church.py's supplied plates. One world pixel per pixel.
## The aisle is row 790 in the originals; the import starts at row 70.
const NAVE := preload("res://assets/Level2/church/nave.png")
const RACK := preload("res://assets/Level2/church/rack.png")
const CANDLE := preload("res://assets/Level2/church/candle.png")
const RECT := Rect2(-1036.0, -720.0, 2072.0, 820.0)
const RACK_FOOT := Vector2(-86.0, -10.0)
const CANDLE_FOOT := Vector2(-156.0, -116.0)
const PRIEST_X := 364.0


static func draw_nave(canvas: CanvasItem, back: Rect2, onward: Rect2, open: bool) -> void:
	canvas.draw_texture(NAVE, RECT.position)
	_draw_open_door(canvas, back, true)
	_draw_open_door(canvas, onward, open)


## Open the painted panels inside their own stone frame. The cross above stays untouched.
static func _draw_open_door(canvas: CanvasItem, reach: Rect2, open: bool) -> void:
	if not open:
		return
	var panel := Rect2(reach.get_center().x - 44.0, -159.0, 88.0, 143.0)
	canvas.draw_rect(panel, Color("211b13"))
	# The same wall and paving, receding into shadow beyond the stone reveal.
	canvas.draw_texture_rect_region(NAVE, panel.grow(-6.0), Rect2(1690.0, 550.0, 80.0, 190.0),
		Color(0.48, 0.45, 0.40, 1.0))
	canvas.draw_rect(Rect2(panel.position, Vector2(8.0, panel.size.y)), Color("30200f"))
