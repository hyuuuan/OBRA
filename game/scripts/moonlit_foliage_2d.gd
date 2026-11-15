extends Node2D
## Decorative art only. Ground belongs to CliffDressing2D; creatures own the gameplay plane.
## Bushes sit behind the ground, vines on its face, and both leave encounter volumes clear.
const ART := "res://assets/Level4/foliage_moonlit/"
const Obstacle = preload("res://scripts/level_obstacle_2d.gd")
@export_enum("Bushes", "Vines") var layer := 0

var _sprites: Array[Sprite2D] = []
var _reserved: Array[Rect2] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	call_deferred("_build")


func _build() -> void:
	var terrain := get_node_or_null(^"../Terrain")
	if terrain == null:
		push_error("Moonlit foliage must be a sibling of Terrain")
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART + "foliage.json"))
	var gap: Array = data["plant_gap"]
	var margin := float(data["plant_margin"])
	_reserved = reserved_regions()
	for body in terrain.get_children():
		if not body.has_method("ground_rects"):
			continue
		for ground: Rect2 in body.call("ground_rects"):
			if ground.size.y <= 40.0 or ground.size.x <= margin * 2.0:
				continue
			var x := ground.position.x + margin
			x += _hash(x) * float(gap[0]) * 0.5
			while x < ground.end.x - margin:
				var count := int(data["plants"] if layer == 0 else data["vines"])
				var index := int(_hash(x + 17.0) * count) % count
				var filename := ("plant_%d.png" if layer == 0 else "vine_%d.png") % index
				var texture := load(ART + filename) as Texture2D
				var at := Vector2(roundf(x) - floorf(texture.get_width() * 0.5), ground.position.y)
				at.y += 3.0 - texture.get_height() if layer == 0 else -8.0 + float(data["vine_offset"])
				var bounds := Rect2(at, texture.get_size())
				var fits := layer == 0 or bounds.end.y <= ground.end.y
				if fits and _clear(bounds):
					var sprite := Sprite2D.new()
					sprite.name = ("Bush" if layer == 0 else "Vine") + str(_sprites.size())
					sprite.centered = false
					sprite.texture = texture
					add_child(sprite)
					sprite.global_position = at
					_sprites.append(sprite)
				x += lerpf(float(gap[0]), float(gap[1]), _hash(x + 31.0))


func _hash(value: float) -> float:
	return fposmod(sin(value * 12.9898) * 43758.5453, 1.0)


func _clear(bounds: Rect2) -> bool:
	for region in _reserved:
		if bounds.intersects(region):
			return false
	return true


## Use the encounter volumes already authored by the level, including the entire finale.
## No second hand-maintained list of nuno/aswang positions.
func reserved_regions() -> Array[Rect2]:
	var regions: Array[Rect2] = []
	var obstacles := get_node_or_null(^"../Obstacles")
	if obstacles != null:
		for child in obstacles.get_children():
			if child is Obstacle:
				var extent: Vector2 = child.trigger_size
				regions.append(Rect2(child.global_position - extent * 0.5, extent).grow(64.0))
	# The santelmo and supplies are mechanics too, even between encounter volumes.
	for folder: String in ["Hazards", "Pickups", "InkJars"]:
		var parent := get_node_or_null(NodePath("../" + folder))
		if parent != null:
			for child in parent.get_children():
				if child is Node2D:
					regions.append(Rect2(child.global_position - Vector2(140, 190), Vector2(280, 260)))
	return regions


func decoration_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for sprite in _sprites:
		result.append(Rect2(sprite.global_position, sprite.texture.get_size()))
	return result
