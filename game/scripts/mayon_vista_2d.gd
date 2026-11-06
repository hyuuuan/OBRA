extends Node2D
## The sunset and foothills repeat at their own speeds. The single cone and the
## ribbons stay framed as the camera climbs, while the ruin and near trees stand on the path.
const SKY := preload("res://assets/Level5/revamp/sky.png")
const VOLCANO := preload("res://assets/Level5/revamp/volcano.png")
const FOREST_RIDGE := preload("res://assets/Level5/revamp/canopy.png")
const ASH_RIDGE := preload("res://assets/Level5/revamp/ash_ridge.png")
@export var depth := 9.0
@export var sky_scroll := 0.02
@export var volcano_scroll := 0.065
@export var ridge_scroll := 0.12
@export var forest_scroll := 0.28
var _eye := Vector2.ZERO
var _origin_x := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	get_viewport().size_changed.connect(queue_redraw)

func set_camera_origin(at: Vector2) -> void:
	_origin_x = at.x
	update_for_camera(at)

func update_for_camera(at: Vector2) -> void:
	_eye = at
	global_position = at
	queue_redraw()

func _draw() -> void:
	var camera := get_viewport().get_camera_2d()
	var zoom := camera.zoom if camera != null else Vector2.ONE
	var view := get_viewport_rect().size / zoom
	var travel := _eye.x - _origin_x
	var rise := smoothstep(2700.0, 5350.0, _eye.x)
	var sky_tint := Color.WHITE.lerp(Color(0.75, 0.68, 0.72), rise)
	_paint_ribbon(SKY, view, travel * sky_scroll, 1.04, 1.02, sky_tint)
	var size := VOLCANO.get_size() * (view.y / VOLCANO.get_height())
	var peak := Vector2(-size.x * 0.5 - travel * volcano_scroll,
		view.y * (-0.5 + rise * 0.12))
	draw_texture_rect(VOLCANO, Rect2(peak, size), false, Color(1, 1, 1, 1.0 - rise * 0.92))
	if rise > 0.0:
		_paint_ribbon(ASH_RIDGE, view, travel * ridge_scroll, 0.92, 1.0,
			Color(1, 1, 1, rise))
	if rise < 1.0:
		_paint_ribbon(FOREST_RIDGE, view, travel * forest_scroll, 1.08, 1.04 + rise * 0.15,
			Color(1, 1, 1, 1.0 - rise))


func _paint_ribbon(texture: Texture2D, view: Vector2, travel: float,
		height_ratio: float, bottom_ratio: float, shade: Color) -> void:
	var height := view.y * height_ratio
	var width := texture.get_width() * height / texture.get_height()
	var left := -view.x * 0.5
	var phase := travel + width * 0.5
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
	draw_set_transform(Vector2.ZERO)
