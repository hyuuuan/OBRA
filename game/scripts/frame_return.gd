class_name FrameReturn
extends CanvasLayer
## The ordinary room, with registered seated performances over a painted background.
const LAYER := 7
const ROOM := preload("res://assets/Level5/frame/room.png")
const FOLDER := "res://assets/Level5/people/"
## Retain textures through RenderingServer's draw. A load() local freed at return paints white.
const ACTORS := {
	"lola_seated": preload("res://assets/Level5/people/lola_seated.png"),
	"lola_seated_flowers": preload("res://assets/Level5/people/lola_seated_flowers.png"),
	"seated": preload("res://assets/Level5/people/apo_seated.png"),
	"seated_paint": preload("res://assets/Level5/people/apo_seated_paint.png"),
	"pickup": preload("res://assets/Level5/people/apo_pickup.png"),
}
const BLACK_HOLD := 3.0
var _black: ColorRect
var _room: Control
var _phase := "listening"
var _ordinary_brush := false
var has_flowers := false
var _memory: Texture2D


func _ready() -> void:
	layer = LAYER
	_room = Control.new()
	_room.name = "Room"
	_room.set_anchors_preset(Control.PRESET_FULL_RECT)
	_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_room.draw.connect(_draw_room)
	add_child(_room)
	_black = ColorRect.new()
	_black.name = "Black"
	_black.color = Color(0, 0, 0, 0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	Motion.fade_in(_room, 1.0)


func show_memory(texture: Texture2D) -> void:
	_memory = texture
	_room.queue_redraw()


func pick_up_brush() -> void:
	_phase = "pickup"
	_room.queue_redraw()
	await get_tree().create_timer(0.9, true).timeout
	_ordinary_brush = true
	_phase = "painting"
	_room.queue_redraw()
	await get_tree().create_timer(1.3, true).timeout


func holds_ordinary_brush() -> bool:
	return _ordinary_brush


func cut_to_black() -> void:
	_black.color.a = 1.0
	await get_tree().create_timer(BLACK_HOLD, true).timeout


func is_black() -> bool:
	return _black.color.a >= 1.0


func _draw_room() -> void:
	# Room, bench and actors share the original 1600x900 composition on every screen.
	# Stretching only the backdrop displaced the seated poses on taller windows.
	var size := Vector2(1600, 900)
	var cover := maxf(_room.size.x / size.x, _room.size.y / size.y)
	_room.draw_set_transform((_room.size - size * cover) * .5, 0.0, Vector2.ONE * cover)
	_room.draw_texture_rect(ROOM, Rect2(Vector2.ZERO, size), false)
	var seated_y := size.y * 0.715
	var lola: Texture2D = ACTORS["lola_seated_flowers" if has_flowers else "lola_seated"]
	var apo_pose := "pickup" if _phase == "pickup" else ("seated_paint" if _phase == "painting" else "seated")
	var apo: Texture2D = ACTORS[apo_pose]
	var scale := 2.2
	var ls := lola.get_size() * scale
	var aps := apo.get_size() * scale
	_room.draw_texture_rect(lola, Rect2(Vector2(size.x * .47 - ls.x * .5, seated_y - ls.y), ls), false)
	var apo_y := size.y * .86 if _phase == "pickup" else seated_y
	_room.draw_texture_rect(apo, Rect2(Vector2(size.x * .62 - aps.x * .5, apo_y - aps.y), aps), false)
	if _memory != null:
		var frame := Rect2(size.x * .779, size.y * .327, size.x * .115, size.y * .23)
		var fit := minf(frame.size.x/_memory.get_width(),frame.size.y/_memory.get_height())
		var painting := _memory.get_size()*fit
		_room.draw_texture_rect(_memory,Rect2(frame.get_center()-painting*.5,painting),false)
	_room.draw_set_transform(Vector2.ZERO)
