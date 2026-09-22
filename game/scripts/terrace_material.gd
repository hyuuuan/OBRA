extends RefCounted
## Shared, world-anchored stone: neighboring blocks sample the same continuous wall.
const TEXTURE := preload("res://assets/Level1/terrace_stone_fill.png")
const TILE_SIZE := 256.0
## The wall should recede below the grass cap without turning the lower half of the screen
## black. The texture already contains its own stone shadows; this is only broad daylight
## falloff. At Payyo's lowest ground (y ~= 680) it now retains about 62% of its painted
## brightness, instead of the old 29%.
const DEPTH_LIGHT_RUN := 1600.0
const MAX_DEPTH_DARKEN := 0.38


static func shade(world_y: float) -> Color:
	return Color.WHITE.darkened(clampf(
		(world_y - 80.0) / DEPTH_LIGHT_RUN, 0.0, MAX_DEPTH_DARKEN))


static func world_uv(points: PackedVector2Array, origin: Vector2) -> PackedVector2Array:
	var uv := PackedVector2Array()
	for point in points:
		uv.append((point + origin) * TEXTURE.get_size() / TILE_SIZE)
	return uv
