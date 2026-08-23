class_name TerraceSegment2D
extends StaticBody2D
## Solid terrace block whose visuals are tiled from the Level 1 texture atlas.

## PATH is the surface the player actually walks on. The others are what the terrace is
## made of; this one is where the feet go, and it exists because the level was unreadable
## without it: the gameplay plane was built from the same rice and grass tiles as the
## painted background behind it, so the ground you can stand on and the scenery you cannot
## were the same colour at the same brightness. Packed earth against green reads instantly,
## and a worn path along a terrace is what is actually there in Banaue.
enum SurfaceStyle { RICE, GRASS, STONE, PATH }

const TEXTURE_MAP := preload("res://assets/Level1/texturemap.png")
const RICE_TOP := Rect2(828, 80, 84, 84)
const GRASS_TOP := Rect2(828, 209, 84, 84)
const STONE_TOP := Rect2(828, 343, 84, 86)
## The packed-earth row of the atlas's edge set, unused until now.
const PATH_TOP := Rect2(828, 473, 84, 90)
const MUD_WALL := Rect2(217, 228, 146, 129)
const STONE_WALL := Rect2(217, 401, 146, 125)

@export var segment_size := Vector2(360.0, 216.0)
@export var surface_style := SurfaceStyle.GRASS
@export var use_stone_wall := true


func _ready() -> void:
	add_to_group("terrace_ground")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_collision()
	_build_visuals()


func _build_collision() -> void:
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.position = segment_size * 0.5
	var rectangle := RectangleShape2D.new()
	rectangle.size = segment_size
	collision.shape = rectangle
	add_child(collision)


func _build_visuals() -> void:
	var wall := TextureRect.new()
	wall.name = "RetainingWall"
	wall.position = Vector2(0.0, 44.0)
	wall.size = Vector2(segment_size.x, maxf(1.0, segment_size.y - 44.0))
	wall.texture = _atlas(STONE_WALL if use_stone_wall else MUD_WALL)
	wall.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	wall.stretch_mode = TextureRect.STRETCH_TILE
	wall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wall.show_behind_parent = true
	add_child(wall)

	var top := TextureRect.new()
	top.name = "TerraceTop"
	top.position = Vector2.ZERO
	top.size = Vector2(segment_size.x, 60.0)
	match surface_style:
		SurfaceStyle.RICE:
			top.texture = _atlas(RICE_TOP)
		SurfaceStyle.STONE:
			top.texture = _atlas(STONE_TOP)
		SurfaceStyle.PATH:
			top.texture = _atlas(PATH_TOP)
		_:
			top.texture = _atlas(GRASS_TOP)
	top.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	top.stretch_mode = TextureRect.STRETCH_TILE
	top.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)


func _atlas(region: Rect2) -> AtlasTexture:
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = TEXTURE_MAP
	atlas_texture.region = region
	return atlas_texture
