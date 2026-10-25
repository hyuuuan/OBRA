class_name MayonTerrain2D
extends StaticBody2D
## Mayon's ground: rectangles of volcanic soil, path or ruin stone, grassed on top below the
## treeline and bare above it -- drawn from tools/build_mayon.py's tiles and solid exactly where
## they are drawn.
##
## The collision is the rectangle; the grass overhangs its top by LIP px so feet stand IN the
## grass rather than on a line above it. Up on the cone nothing grows, and `grassed` is off.

const TILES := "res://assets/Level5/tiles/"
## How far the grass is drawn above a platform's collision top.
const LIP := 8.0

## Solid ground, world rectangles in this node's space.
@export var platforms: Array[Rect2] = []
## Which texture fills a platform's body.
@export_enum("soil", "path", "masonry") var body: String = "soil"
## Grass on top: the lower slopes have it, the bare cone does not.
@export var grassed := true
## The light on the ground. Lighter than the backdrop's, so what she stands on reads as nearest.
@export var tint := Color(1.0, 1.0, 1.0, 1.0)

var _body_texture: Texture2D
var _grass: Texture2D


func _ready() -> void:
	# The world layer, where every body stands and every tool looks.
	collision_layer = 1
	collision_mask = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	modulate = tint
	_body_texture = load(TILES + body + ".png") as Texture2D
	_grass = load(TILES + "grass.png") as Texture2D if grassed else null
	for rect in platforms:
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.get_center()
		add_child(shape)
	queue_redraw()


func _draw() -> void:
	for rect in platforms:
		if _body_texture != null:
			draw_texture_rect(_body_texture, rect, true)
		if _grass != null:
			var height := float(_grass.get_height())
			draw_texture_rect(_grass, Rect2(rect.position - Vector2(0.0, LIP),
				Vector2(rect.size.x, height)), true)
