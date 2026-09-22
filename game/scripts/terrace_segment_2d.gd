class_name TerraceSegment2D
extends StaticBody2D
## Solid terrace: one grass cap over a continuous, world-aligned stone material.
## PATH keeps its serialized enum value, but now shares the bright grass ledge treatment.
## MUD is the floor of a flooded paddy, and it is the one style drawn in code rather than cut
## from the atlas: the atlas has no ground you cannot walk on, and a paddy floored with the
## terrace kit read as the terrace. See PaddyBasin2D.
enum SurfaceStyle { RICE, GRASS, STONE, PATH, MUD }

const TEXTURE_MAP := preload("res://assets/Level1/texturemap.png")
const StoneFill = preload("res://scripts/terrace_material.gd")
const AtlasTile = preload("res://scripts/atlas_tile.gd")
const EDGE_REFERENCE := preload("res://assets/Level1/terrace_reference.png")
const CAP_HEIGHT := 30.0
const CORNER_RADIUS := 8.0

@export var segment_size := Vector2(360.0, 216.0)
@export var surface_style := SurfaceStyle.GRASS
@export var use_stone_wall := true


func _ready() -> void:
	add_to_group("terrace_ground")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_collision()
	_build_visuals()
	call_deferred("_round_exposed_corners")


func _build_collision() -> void:
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.position = segment_size * 0.5
	var rectangle := RectangleShape2D.new()
	rectangle.size = segment_size
	collision.shape = rectangle
	add_child(collision)


func _build_visuals() -> void:
	var wall := Polygon2D.new()
	wall.name = "RetainingWall"
	wall.polygon = PackedVector2Array([Vector2.ZERO, Vector2(segment_size.x, 0),
		segment_size, Vector2(0, segment_size.y)])
	wall.texture = StoneFill.TEXTURE
	wall.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	wall.uv = StoneFill.world_uv(wall.polygon, global_position)
	var upper := StoneFill.shade(global_position.y)
	var lower := StoneFill.shade(global_position.y + segment_size.y)
	wall.vertex_colors = PackedColorArray([upper, upper, lower, lower])
	if not use_stone_wall:
		wall.modulate = Color(0.8, 0.73, 0.6)
	wall.show_behind_parent = true
	add_child(wall)

	if surface_style == SurfaceStyle.MUD:
		queue_redraw()
		return
	var top := Polygon2D.new()
	top.name = "TerraceTop"
	top.polygon = _outline(minf(CAP_HEIGHT, segment_size.y), false, false)
	match surface_style:
		SurfaceStyle.RICE:
			top.texture = AtlasTile.cut(TEXTURE_MAP, Rect2(830, 81, 80, 22))
		SurfaceStyle.STONE:
			top.texture = AtlasTile.cut(TEXTURE_MAP, Rect2(830, 345, 80, 22))
		_:
			# The user's reference supplies the actual grass and squared earth lip.
			top.texture = AtlasTile.cut(EDGE_REFERENCE, Rect2(920, 122, 800, 90))
	top.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	top.uv = _cap_uv(top.polygon, top.texture.get_height())
	add_child(top)


func _cap_uv(points: PackedVector2Array, texture_height: float) -> PackedVector2Array:
	var uv := PackedVector2Array()
	for point in points:
		uv.append(Vector2((point.x + global_position.x) * 3.0,
			point.y * texture_height / CAP_HEIGHT))
	return uv


func _round_exposed_corners() -> void:
	if surface_style == SurfaceStyle.MUD:
		return
	var left := true
	var right := true
	for neighbor in get_tree().get_nodes_in_group("terrace_ground"):
		if neighbor == self or not neighbor is TerraceSegment2D:
			continue
		var bounds := Rect2(neighbor.global_position, neighbor.segment_size)
		if bounds.has_point(global_position + Vector2(-1, 1)):
			left = false
		if bounds.has_point(global_position + Vector2(segment_size.x + 1, 1)):
			right = false
	var wall := get_node("RetainingWall") as Polygon2D
	wall.polygon = _outline(segment_size.y, left, right)
	wall.uv = StoneFill.world_uv(wall.polygon, global_position)
	var tones := PackedColorArray()
	for point in wall.polygon:
		tones.append(StoneFill.shade(global_position.y + point.y))
	wall.vertex_colors = tones
	var top := get_node("TerraceTop") as Polygon2D
	top.polygon = _outline(minf(CAP_HEIGHT, segment_size.y), left, right)
	top.uv = _cap_uv(top.polygon, top.texture.get_height())


func _outline(height: float, left: bool, right: bool) -> PackedVector2Array:
	var w := segment_size.x
	var r := minf(CORNER_RADIUS, minf(w * 0.5, height))
	# Stepped quarter-rounds preserve the pixel grid; only eight pixels of visual trim.
	var points := PackedVector2Array()
	if left:
		points.append_array(PackedVector2Array([Vector2(0, r), Vector2(2, r * 0.5),
			Vector2(r * 0.5, 2), Vector2(r, 0)]))
	else:
		points.append(Vector2.ZERO)
	if right:
		points.append_array(PackedVector2Array([Vector2(w - r, 0), Vector2(w - r * 0.5, 2),
			Vector2(w - 2, r * 0.5), Vector2(w, r)]))
	else:
		points.append(Vector2(w, 0))
	points.append_array(PackedVector2Array([Vector2(w, height), Vector2(0, height)]))
	return points


## The silt bed of a paddy: wet and dark on top, lumpy, stubble of last season's rice in it,
## and the retaining wall carrying on below as it does under any terrace.
func _draw() -> void:
	if surface_style != SurfaceStyle.MUD:
		return
	var band := minf(44.0, segment_size.y)
	draw_rect(Rect2(0.0, 0.0, segment_size.x, band), Color(0.235, 0.176, 0.110, 1.0))
	draw_rect(Rect2(0.0, 0.0, segment_size.x, 4.0), Color(0.290, 0.239, 0.157, 1.0))
	draw_rect(Rect2(0.0, 0.0, segment_size.x, 1.0), Color(0.384, 0.325, 0.224, 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x) * 13 + 5
	for index in range(int(segment_size.x / 7.0)):
		var at := Vector2(floorf(rng.randf() * (segment_size.x - 8.0)),
			floorf(6.0 + rng.randf() * (band - 12.0)))
		draw_rect(Rect2(at, Vector2(5.0 + floorf(rng.randf() * 5.0), 3.0)),
			Color(0.165, 0.122, 0.075, 1.0))
	for index in range(int(segment_size.x / 30.0)):
		var at := Vector2(floorf(rng.randf() * (segment_size.x - 4.0)),
			floorf(8.0 + rng.randf() * (band - 14.0)))
		draw_rect(Rect2(at, Vector2(3.0, 2.0)), Color(0.451, 0.420, 0.365, 1.0))
	draw_rect(Rect2(0.0, band - 3.0, segment_size.x, 3.0), Color(0.149, 0.110, 0.071, 1.0))
