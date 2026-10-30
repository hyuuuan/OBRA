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
## Which texture fills a platform's body.
@export_enum("mud", "stone", "path") var body: String = "mud"
## The night, on the ground too -- lighter than the backdrop's, so what she stands on still reads
## as the nearest thing in the picture. The tileset is painted by day.
@export var tint := Color(0.62, 0.64, 0.78, 1.0)

var _body_texture: Texture2D
var _leaf: Texture2D
var _bark: Texture2D
var _rims: Node2D


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
		out.append([global_transform * (rect.position - Vector2(0.0, LIP)),
			global_transform * (Vector2(rect.end.x, rect.position.y) - Vector2(0.0, LIP))])
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
