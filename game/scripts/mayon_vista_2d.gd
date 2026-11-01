extends Node2D
## Keep the registered painting intact; independent ridges add depth in front of it.
## All layers share camera-relative vertical framing, so the climb cannot split the vista.
const FOOT := preload("res://assets/Level5/backdrop/foot_vista.png")
const UPPER := preload("res://assets/Level5/backdrop/upper_vista.png")
const FAR_RIDGE := preload("res://assets/Level5/backdrop/far_ridge.png")
const FOREST_RIDGE := preload("res://assets/Level5/backdrop/forest_ridge.png")
@export var depth := 9.0
## Screen travel per world pixel: the ridge drifts slowly, the nearer forest twice as fast.
@export var ridge_scroll := 0.12
@export var forest_scroll := 0.28
var _eye := Vector2.ZERO

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func set_camera_origin(at: Vector2) -> void:
	update_for_camera(at)

func update_for_camera(at: Vector2) -> void:
	_eye = at
	global_position = at
	queue_redraw()

func _draw() -> void:
	var camera := get_viewport().get_camera_2d()
	var zoom := camera.zoom if camera != null else Vector2.ONE
	var view := get_viewport_rect().size / zoom
	var rise := smoothstep(2700.0, 5350.0, _eye.x)
	_paint_cover(FOOT, view, Color.WHITE)
	_paint_cover(UPPER, view, Color(1,1,1,rise))
	var treeline := 1.0 - smoothstep(3100.0, 5100.0, _eye.x)
	# The forest falls below the path at the treeline. Distant ridges persist through
	# the memory areas, then give way to the summit's white rather than new vegetation.
	var distant := 1.0 - smoothstep(9800.0, 11800.0, _eye.x)
	_paint_ribbon(FAR_RIDGE, view, ridge_scroll, 0.42, 0.77,
		Color(1, 1, 1, distant * lerpf(0.75, 0.38, rise)))
	if treeline > 0.0:
		_paint_ribbon(FOREST_RIDGE, view, forest_scroll, 0.74, 1.02,
			Color(0.83, 0.86, 0.77, treeline))
	# The last memories stand in ash, rather than against the same sunset as the meadow.
	var paper := smoothstep(7300.0, 11100.0, _eye.x) * 0.22
	draw_rect(Rect2(-view*.5,view),Color(0.86,0.83,0.80,paper))

func _paint_cover(texture: Texture2D, view: Vector2, shade: Color) -> void:
	# Overscan leaves room for a slow pan without exposing any plate edge. One Mayon,
	# never repeated, and the whole painting moves together in both axes.
	var fit := maxf(view.x/texture.get_width(),view.y/texture.get_height()) * 1.1
	var size := texture.get_size()*fit
	var travel := clampf((_eye.x - 260.0) / 11000.0, 0.0, 1.0)
	var drift := Vector2(lerpf(36.0, -36.0, travel), clampf(-_eye.y * 0.025, -18.0, 18.0))
	var margin := (size - view) * 0.5
	drift = drift.clamp(-margin, margin)
	draw_texture_rect(texture,Rect2(-size*.5 + drift,size),false,shade)


func _paint_ribbon(texture: Texture2D, view: Vector2, scroll: float,
		height_ratio: float, bottom_ratio: float, shade: Color) -> void:
	var height := view.y * height_ratio
	var width := texture.get_width() * height / texture.get_height()
	var left := -view.x * 0.5
	var phase := _eye.x * scroll
	var first := floori((left + phase) / width)
	var last := ceili((view.x * 0.5 + phase) / width)
	var top := view.y * (bottom_ratio - 0.5) - height
	for index in range(first, last + 1):
		var start := index * width - phase
		# Mirror about the repeat's own edge; this also works for negative indices.
		var mirrored := posmod(index, 2) == 1
		draw_set_transform(Vector2(start + (width if mirrored else 0.0), top), 0.0,
			Vector2(-1.0 if mirrored else 1.0, 1.0))
		draw_texture_rect(texture, Rect2(0.0, 0.0, width + 1.0, height), false, shade)
		# Continue with full chunks of woodland/rock, mirrored at each join. Stretching
		# a single bottom row made vertical colour streaks visible through the span.
		var tail_height := height * 0.25
		var y := top + height
		var tail := 0
		while y < view.y * 0.5:
			var flip_y := tail % 2 == 0
			draw_set_transform(Vector2(start + (width if mirrored else 0.0),
				y + (tail_height if flip_y else 0.0)), 0.0,
				Vector2(-1.0 if mirrored else 1.0, -1.0 if flip_y else 1.0))
			draw_texture_rect_region(texture, Rect2(0.0, 0.0, width + 1.0, tail_height + 1.0),
				Rect2(0.0, texture.get_height() * 0.75, texture.get_width(), texture.get_height() * 0.25), shade)
			y += tail_height
			tail += 1
		draw_set_transform(Vector2.ZERO)
