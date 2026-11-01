extends Node2D
## A few passing painted gusts. Camera-relative like the ash;
## the ordinary gameplay clock holds them during dialogue and drawing.
const ART := preload("res://assets/Level5/weather/wind_streaks.png")
const COLUMNS := 3
const FRAMES := 4
const CYCLE := 7.2
const LIFETIME := 3.8
const PLACES := [Vector2(0.79, 0.29), Vector2(0.48, 0.46),
	Vector2(0.73, 0.62), Vector2(0.55, 0.37)]

@export var enabled := true:
	set(value):
		if enabled == value:
			return
		enabled = value
		queue_redraw()

var _time := 0.0
var _frame := -1
var _reduced := false


func _ready() -> void:
	# Behind the characters, over the scenery, with the ash's own wind direction.
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	var reduced := Motion.reduced()
	if _reduced != reduced:
		_reduced = reduced
		queue_redraw()
	if not enabled or reduced:
		return
	_time += delta
	var frame := floori(_time * Motion.PIXEL_FPS)
	if frame != _frame:
		_frame = frame
		queue_redraw()


func _draw() -> void:
	if not enabled or Motion.reduced():
		return
	var camera := get_parent() as Camera2D
	var zoom := camera.zoom if camera != null else Vector2.ONE
	var view := get_viewport_rect().size / zoom
	var clock := float(maxi(0, _frame)) / Motion.PIXEL_FPS
	var cell := ART.get_size() / Vector2(COLUMNS, FRAMES)
	for index in range(PLACES.size()):
		var elapsed := clock + index * CYCLE / PLACES.size()
		var age := fposmod(elapsed, CYCLE)
		if age >= LIFETIME:
			continue
		var progress := age / LIFETIME
		var fade := smoothstep(0.0, 0.18, progress) * (1.0 - smoothstep(0.72, 1.0, progress))
		var pass_index := floori(elapsed / CYCLE)
		var start: Vector2 = PLACES[index] * view - view * 0.5
		start += Vector2(sin(pass_index * 2.3 + index) * 70.0,
			sin(pass_index * 1.7 + index) * 24.0)
		var at := start + Vector2(-240.0 * progress, sin(progress * PI) * 15.0)
		var variant := posmod(index + pass_index, COLUMNS)
		var frame := mini(FRAMES - 1, int(progress * FRAMES))
		var source := Rect2(Vector2(variant, frame) * cell, cell)
		# Preserve the atlas cell's aspect and registration as its four frames unfurl.
		# A small passing accent, roughly 170-195px of visible ink.
		var size := cell * ((180.0 + variant * 15.0) / cell.x)
		draw_texture_rect_region(ART, Rect2((at - size * 0.5).round(), size),
			source, Color(1.0, 1.0, 1.0, fade * 0.46))
