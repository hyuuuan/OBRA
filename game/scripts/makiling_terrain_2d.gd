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
## Optional native-size shelf art. Only changes appearance; the one-way branch stays 18 px.
@export var branch_texture: Texture2D
## Which texture fills a platform's body.
@export_enum("mud", "stone", "path") var body: String = "mud"
## The night, on the ground too -- lighter than the backdrop's, so what she stands on still reads
## as the nearest thing in the picture. The tileset is painted by day.
@export var tint := Color(0.62, 0.64, 0.78, 1.0)

var _body_texture: Texture2D
var _leaf: Texture2D
var _bark: Texture2D
## Worn by a CliffDressing2D: the platforms are drawn there, and only the branches here.
var _dressed := false


func _ready() -> void:
	add_to_group(&"makiling_ground")
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


## What a CliffDressing2D needs: which kit this ground wears, and its platforms in world space.
## Branches are not handed over -- they are logs, and stay drawn here.
func ground_kind() -> String:
	return body


func ground_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for rect in platforms:
		out.append(Rect2(global_transform * rect.position, rect.size))
	return out


## Dilim's `CliffDressing*` draw the platforms in Mayon's construction, in Makiling's own mud and
## stone; the flat fill and the thin leaf strip here stand down. Moonlit edges belong to the
## artwork itself, without a separate dotted overlay above the darkness.
func dressed_ground() -> Array[Rect2]:
	_dressed = true
	queue_redraw()
	return ground_rects()


func _solid(rect: Rect2, one_way: bool) -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	shape.one_way_collision = one_way
	add_child(shape)


func _draw() -> void:
	for rect in platforms if not _dressed else []:
		if _body_texture != null:
			draw_texture_rect(_body_texture, rect, true)
		if _leaf != null:
			draw_texture_rect(_leaf, Rect2(rect.position - Vector2(0.0, LIP),
				Vector2(rect.size.x, COVER + LIP)), true)
	for rect in branches:
		if branch_texture != null:
			_draw_branch_shelf(rect)
			continue
		if _bark != null:
			draw_texture_rect(_bark, Rect2(rect.position, Vector2(rect.size.x, BRANCH_THICKNESS)),
				true, Color(0.62, 0.48, 0.36))
		if _leaf != null:
			draw_texture_rect(_leaf, Rect2(rect.position - Vector2(0.0, LIP), Vector2(rect.size.x,
				LIP + 6.0)), true)


## Small pixel steps round the upper corners while keeping the texture at native size.
func _draw_branch_shelf(rect: Rect2) -> void:
	var width := rect.size.x
	var height := float(branch_texture.get_height())
	var corner := minf(8.0, minf(width * 0.25, height * 0.5))
	var step := corner * 0.5
	var contour := PackedVector2Array([
		Vector2(corner, 0), Vector2(width - corner, 0),
		Vector2(width - corner, step), Vector2(width - step, step),
		Vector2(width - step, corner), Vector2(width, corner),
		Vector2(width, height), Vector2(0, height), Vector2(0, corner),
		Vector2(step, corner), Vector2(step, step), Vector2(corner, step)])
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	for point in contour:
		points.append(rect.position - Vector2(0, 8) + point)
		uv.append(point / branch_texture.get_size())
	draw_polygon(points, PackedColorArray([Color.WHITE]), uv, branch_texture)
