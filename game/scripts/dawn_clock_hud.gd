class_name DawnClockHud
extends Control
## How far off the morning is, in the last clearing: a soft horizon strip, and no numbers.
##
## The night is a dark band; the part of it already lived through warms toward the dawn's gold from
## the left, and a small sun sits at the edge of it, rising a little as it goes. A player reads
## "most of the way" at a glance without counting anything -- the finale is a thing to last, not a
## timer to watch -- and nothing on it is red, because nothing on it is a loss.
##
## Round-cornered like every panel in the game. Shown only while the night is running.

const SIZE := Vector2(380.0, 16.0)
const RADIUS := 8.0
const NIGHT := Color(0.06, 0.07, 0.14, 0.86)
const DUSK := Color(0.22, 0.2, 0.36, 0.92)
const DAWN := UISkin.GOLD
const EDGE := UISkin.RING_MID
const SUN := UISkin.GOLD_PALE
## How high the sun sits over the strip's middle at the start and at the end.
const SUN_LOW := 0.0
const SUN_HIGH := 7.0
const FADE_SECONDS := 0.4

var _progress := 0.0
var _fade: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE + Vector2(0.0, SUN_HIGH + 8.0)
	size = custom_minimum_size
	modulate.a = 0.0
	visible = false


func set_progress(share: float) -> void:
	_progress = clampf(share, 0.0, 1.0)
	queue_redraw()


func progress() -> float:
	return _progress


func show_night() -> void:
	_fade_to(1.0)


func hide_night() -> void:
	_fade_to(0.0)


func _fade_to(alpha: float) -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if alpha > 0.0:
		visible = true
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", alpha, FADE_SECONDS)
	if alpha <= 0.0:
		_fade.tween_callback(func() -> void: visible = false)


func _draw() -> void:
	var top := SUN_HIGH + 4.0
	var strip := Rect2(Vector2(0.0, top), SIZE)
	_round(strip, NIGHT, EDGE, 1.5)
	if _progress > 0.0:
		var lived := Rect2(strip.position, Vector2(maxf(SIZE.x * _progress, SIZE.y), SIZE.y))
		_round(lived, DUSK.lerp(DAWN, _progress * _progress), Color(0, 0, 0, 0), 0.0)
	var sun_x := clampf(SIZE.x * _progress, SIZE.y * 0.5, SIZE.x - SIZE.y * 0.5)
	var sun_y := top + SIZE.y * 0.5 - lerpf(SUN_LOW, SUN_HIGH, _progress)
	draw_circle(Vector2(sun_x, sun_y), 7.0, Color(SUN, 0.28))
	draw_circle(Vector2(sun_x, sun_y), 4.5, SUN)


func _round(rect: Rect2, fill: Color, edge: Color, width: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(int(RADIUS))
	box.anti_aliasing = true
	if width > 0.0:
		box.border_color = edge
		box.set_border_width_all(int(width))
	draw_style_box(box, rect)
