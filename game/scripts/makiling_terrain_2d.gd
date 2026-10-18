class_name MakilingTerrain2D
extends StaticBody2D
## Dilim's ground: rectangles of earth with leaf cover on top, and branches you can jump up
## through -- drawn from the Makiling tileset's seamless textures (tools/build_dilim.py) and solid
## where they are drawn.
##
## The collision is the rectangle, exactly; the leaf lip overhangs it by LIP px on top, so feet
## stand IN the leaves rather than on a line above them. A branch is one-way: up from below it lets
## her through, down onto it it holds.

const TILES := "res://assets/Level4/tiles/"
## How far the leaf cover is drawn above a platform's collision top, and how deep it runs into it.
const LIP := 6.0
const COVER := 22.0
## A branch's height, drawn and solid.
const BRANCH_THICKNESS := 18.0

## Solid ground, world rectangles in this node's space.
@export var platforms: Array[Rect2] = []
## One-way branches, the same: only the top edge counts, from above.
@export var branches: Array[Rect2] = []
## Which texture fills a platform's body.
@export_enum("mud", "stone", "path") var body: String = "mud"
## The night, on the ground too -- lighter than the backdrop's, so what she stands on still reads
## as the nearest thing in the picture. The tileset is painted by day.
@export var tint := Color(0.62, 0.64, 0.78, 1.0)

var _body_texture: Texture2D
var _leaf: Texture2D
var _bark: Texture2D


func _ready() -> void:
	# The world layer, where every body stands and every tool looks.
	collision_layer = 1
	collision_mask = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	modulate = tint
	_body_texture = load(TILES + body + ".png") as Texture2D
	_leaf = load(TILES + "leaf.png") as Texture2D
	_bark = load(TILES + "path.png") as Texture2D
	for rect in platforms:
		_solid(rect, false)
	for rect in branches:
		_solid(Rect2(rect.position, Vector2(rect.size.x, BRANCH_THICKNESS)), true)
	queue_redraw()


func _solid(rect: Rect2, one_way: bool) -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	shape.one_way_collision = one_way
	add_child(shape)


func _draw() -> void:
	for rect in platforms:
		if _body_texture != null:
			draw_texture_rect(_body_texture, rect, true)
		if _leaf != null:
			draw_texture_rect(_leaf, Rect2(rect.position - Vector2(0.0, LIP),
				Vector2(rect.size.x, COVER + LIP)), true)
	for rect in branches:
		if _bark != null:
			draw_texture_rect(_bark, Rect2(rect.position, Vector2(rect.size.x, BRANCH_THICKNESS)),
				true, Color(0.62, 0.48, 0.36))
		if _leaf != null:
			draw_texture_rect(_leaf, Rect2(rect.position - Vector2(0.0, LIP), Vector2(rect.size.x,
				LIP + 6.0)), true)
