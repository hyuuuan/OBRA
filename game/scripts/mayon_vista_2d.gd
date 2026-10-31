extends Node2D
## One registered landscape. Separate vertical parallax tore the original painting apart.
const FOOT := preload("res://assets/Level5/backdrop/foot_vista.png")
const UPPER := preload("res://assets/Level5/backdrop/upper_vista.png")
@export var depth := 9.0
var _eye := Vector2.ZERO

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
	# The last memories stand in ash, rather than against the same sunset as the meadow.
	var paper := smoothstep(7300.0, 11100.0, _eye.x) * 0.22
	draw_rect(Rect2(-view*.5,view),Color(0.86,0.83,0.80,paper))

func _paint_cover(texture: Texture2D, view: Vector2, shade: Color) -> void:
	var fit := maxf(view.x/texture.get_width(),view.y/texture.get_height())
	var size := texture.get_size()*fit
	draw_texture_rect(texture,Rect2(-size*.5,size),false,shade)
