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
## WHERE THE GROUND IS, IN THE DARK. Past her lamp the woods were black right up to the lip of a
## drop and the underside of a log (Kent, of Dilim: "where to go in the dark"). Every top edge she
## can stand on catches a thread of moonlight, drawn over the dark, and a ledge's ends turn down so
## a drop reads as an edge. A line, not light: nothing is lit by it and LightField never hears of it.
const RIM_LAYER := DarknessLayer.LAYER + 1
const RIM := Color(0.72, 0.78, 0.95, 0.42)
## Glints, not a line: a 2 px fleck every RIM_STEP px along the edge, each as bright as a fixed hash
## of where it is says -- moonlight on leaf tips. A line read as a rule drawn across the screen.
const RIM_STEP := 6.0
const RIM_PIXEL := 2.0
const RIM_TURN := 14.0

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
var _rims: Node2D
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
	var layer := CanvasLayer.new()
	layer.name = "Rims"
	layer.layer = RIM_LAYER
	layer.follow_viewport_enabled = true
	add_child(layer)
	_rims = Node2D.new()
	layer.add_child(_rims)
	_rims.draw.connect(_draw_rims)
	queue_redraw()


## Every thread of moonlight, as [from, to] in world px: each top edge where the leaves are, and a
## platform's two ends turned down.
func rim_segments() -> Array:
	var out: Array = []
	for rect in platforms:
		var left := global_transform * (rect.position - Vector2(0.0, LIP))
		var right := global_transform * (Vector2(rect.end.x, rect.position.y) - Vector2(0.0, LIP))
		out.append([left, right])
		out.append([left, left + Vector2(0.0, RIM_TURN)])
		out.append([right, right + Vector2(0.0, RIM_TURN)])
	for rect in branches:
		var corner := 8.0 if branch_texture != null else 0.0
		out.append([global_transform * (rect.position + Vector2(corner, -LIP)),
			global_transform * (Vector2(rect.end.x - corner, rect.position.y) - Vector2(0.0, LIP))])
	return out


func _draw_rims() -> void:
	for segment: Array in rim_segments():
		var from: Vector2 = segment[0]
		var to: Vector2 = segment[1]
		var steps := maxi(1, int(from.distance_to(to) / RIM_STEP))
		for index in range(steps + 1):
			var at := from.lerp(to, float(index) / float(steps)).round()
			var glint := fposmod(sin(at.x * 12.9898 + at.y * 78.233) * 43758.5453, 1.0)
			if glint < 0.25:
				continue
			_rims.draw_rect(Rect2(at - Vector2.ONE * RIM_PIXEL * 0.5, Vector2.ONE * RIM_PIXEL),
				Color(RIM, RIM.a * glint))


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
## stone; the flat fill and the thin leaf strip here stand down. The rims stay: they are where
## the ground is in the dark, whoever draws it.
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
