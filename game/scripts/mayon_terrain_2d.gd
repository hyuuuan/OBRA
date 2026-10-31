class_name MayonTerrain2D
extends StaticBody2D
## Mayon's measured collision rectangles, dressed with broad authored cliff faces.
## Meadow, basalt and ash have distinct materials; texture phase belongs to world space.
## The cliff's broken silhouette is decoration; the continuous grass/crust is the walk line.

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
## Detached memory ledges can be jumped through from below.
@export var one_way := false

const CLIFFS := {
	"meadow": preload("res://assets/Level5/terrain/meadow.png"),
	"basalt": preload("res://assets/Level5/terrain/basalt.png"),
	"ash": preload("res://assets/Level5/terrain/ash.png"),
}

## Painted end caps share the three surface materials. Their left edge faces open air;
## mirroring puts the same registered corner on a right-facing gap edge.
const EDGES := {
	"meadow": preload("res://assets/Level5/terrain/edge_meadow.png"),
	"basalt": preload("res://assets/Level5/terrain/edge_basalt.png"),
	"ash": preload("res://assets/Level5/terrain/edge_ash.png"),
}

var _body_texture: Texture2D
var _grass: Texture2D
var _edge_layer: Node2D
var _joins: Array[Dictionary] = []
var _ends: Array[Dictionary] = []


func _ready() -> void:
	# The world layer, where every body stands and every tool looks.
	collision_layer = 1
	collision_mask = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	z_index = -6
	modulate = tint
	_body_texture = load(TILES + body + ".png") as Texture2D
	_grass = load(TILES + "grass.png") as Texture2D if grassed else null
	for rect in platforms:
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.get_center()
		shape.one_way_collision = one_way
		add_child(shape)
	queue_redraw()
	if not one_way:
		call_deferred("_build_edge_joins")


func _draw() -> void:
	for rect in platforms:
		var zone := _zone(rect)
		if one_way:
			_draw_loose_rock(rect, CLIFFS[zone])
			continue
		var deep := Color(.19, .15, .12)
		var face := rect
		draw_rect(face, deep)
		var cliff: Texture2D = CLIFFS[zone]
		var lip := _lip(zone)
		var height := minf(face.size.y + lip, cliff.get_height())
		var left := face.position.x
		while left < face.end.x:
			# Texture phase belongs to the mountain, so adjacent steps do not restart a tile.
			var phase := fposmod(left + global_position.x, cliff.get_width())
			var width := minf(face.end.x - left, cliff.get_width() - phase)
			draw_texture_rect_region(cliff, Rect2(left, face.position.y-lip, width, height),
				Rect2(phase, 0, width, height))
			left += width


func _zone(rect: Rect2) -> String:
	if rect.position.x + global_position.x >= 8800.0:
		return "ash"
	return "meadow" if grassed and rect.position.x + global_position.x < 2800.0 else "basalt"


func _lip(zone: String) -> float:
	return 20.0 if zone == "meadow" else (5.0 if zone == "ash" else 7.0)


func _build_edge_joins() -> void:
	# Discover real contacts, including Slopes -> Cone. Never dress the gap as a contact,
	# and leave the detached one-way rocks' silhouettes alone.
	var ground: Array[Rect2] = []
	for sibling in get_parent().get_children():
		if sibling.get_script() != get_script() or bool(sibling.get("one_way")):
			continue
		for rect: Rect2 in sibling.get("platforms"):
			ground.append(Rect2(to_local(sibling.to_global(rect.position)), rect.size))
	for rect in platforms:
		var has_left := false
		var has_right := false
		for other in ground:
			if is_equal_approx(other.end.x, rect.position.x):
				has_left = true
				if rect.position.y <= other.position.y:
					_joins.append({"left": other, "right": rect,
						"right_zone": _zone(rect)})
			if is_equal_approx(other.position.x, rect.end.x):
				has_right = true
		if not has_left:
			_ends.append({"rect": rect, "zone": _zone(rect), "side": -1})
		if not has_right:
			_ends.append({"rect": rect, "zone": _zone(rect), "side": 1})
	_edge_layer = Node2D.new()
	_edge_layer.name = "CliffJoins"
	_edge_layer.z_index = 1
	# The summit's Drainable must also take these edges to paper.
	_edge_layer.use_parent_material = true
	_edge_layer.draw.connect(_draw_edge_joins)
	add_child(_edge_layer)


func _draw_edge_joins() -> void:
	for end: Dictionary in _ends:
		_draw_edge_cap(end.rect, end.zone, int(end.side), 0.0)
	for join: Dictionary in _joins:
		var low: Rect2 = join.left
		var high: Rect2 = join.right
		var rise := low.position.y - high.position.y
		if rise > 0.0:
			_draw_edge_cap(high, join.right_zone, -1, rise)


func _draw_edge_cap(rect: Rect2, zone: String, side: int, rise: float) -> void:
	var edge_art: Texture2D = EDGES[zone]
	var edge := rect.position.x if side < 0 else rect.end.x
	# Natural size on ordinary steps; a uniform enlargement covers the 220px wall.
	# Neither axis is independently stretched and the top lip keeps its registration.
	var fit := maxf(1.0, (rise + 100.0) / edge_art.get_height())
	var size := edge_art.get_size() * fit
	var top := rect.position.y - _lip(zone)
	_edge_layer.draw_set_transform(Vector2(edge + side * 10.0, top), 0.0,
		Vector2(float(-side), 1.0))
	_edge_layer.draw_texture_rect(edge_art, Rect2(Vector2.ZERO, size), false)
	_edge_layer.draw_set_transform(Vector2.ZERO)


func _draw_loose_rock(rect: Rect2, cliff: Texture2D) -> void:
	# Keep the detached rocks' broken underside instead of rectangular strips of crust.
	var width := rect.size.x
	var outline := PackedVector2Array([Vector2(0, 0), Vector2(width, 0),
		Vector2(width-12, 24), Vector2(width-42, 39), Vector2(width*.56, 49),
		Vector2(width*.36, 40), Vector2(26, 35), Vector2(8, 23)])
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	var phase := fposmod(rect.position.x, cliff.get_width())
	for point in outline:
		points.append(rect.position + point)
		uv.append(Vector2((phase + point.x) / cliff.get_width(), point.y / cliff.get_height()))
	draw_polygon(points, PackedColorArray([Color.WHITE]), uv, cliff)
