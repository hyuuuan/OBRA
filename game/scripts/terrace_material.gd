extends RefCounted
## Shared, world-anchored stone: neighboring blocks sample the same continuous wall.
const TEXTURE := preload("res://assets/Level1/terrace_stone_fill.png")
const TILE_SIZE := 256.0


static func shade(world_y: float) -> Color:
	return Color.WHITE.darkened(clampf((world_y - 80.0) / 850.0, 0.0, 0.72))


static func world_uv(points: PackedVector2Array, origin: Vector2) -> PackedVector2Array:
	var uv := PackedVector2Array()
	for point in points:
		uv.append((point + origin) * TEXTURE.get_size() / TILE_SIZE)
	return uv
