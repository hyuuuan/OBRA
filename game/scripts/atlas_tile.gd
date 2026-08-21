extends RefCounted
## Cuts one region out of a texture atlas into a standalone tiling texture.
##
## WHY THIS EXISTS. A Polygon2D with an AtlasTexture does NOT sample the atlas region --
## it samples the whole atlas page, using the polygon's own vertex coordinates as UVs.
## The props built out of Polygon2D therefore drew whatever art happened to sit near the
## region, which for this atlas is mostly dark, and the result reads on screen as nothing
## at all: the baul's body, the bale's posts, deck and thatch, and every straw pile were
## all invisible in play while the audit reported them present, positioned and correct.
## Setting `uv` does not fix it either -- wrapping the coordinates into the region's size
## still samples the page. Measured four ways in one frame before this was written.
##
## The terrain does not have the problem because TerraceSegment2D and StairTread2D fill
## with a TextureRect in STRETCH_TILE, which honours the region. A TextureRect cannot be
## cut to a mound or a roof slope, so shaped props need a real texture instead: this cuts
## the region out once and hands back an ImageTexture that tiles correctly under
## `texture_repeat = TEXTURE_REPEAT_ENABLED`, negative coordinates and all.
##
## Cached because three straw piles, four posts and a roof asking for the same 84x84 patch
## should decode the atlas once, not nine times.

static var _cache: Dictionary = {}


static func cut(atlas: Texture2D, region: Rect2) -> ImageTexture:
	if atlas == null:
		return null
	var key := "%s|%s" % [atlas.resource_path, region]
	var cached: ImageTexture = _cache.get(key)
	if cached != null:
		return cached
	var image := atlas.get_image()
	if image == null:
		return null
	# Clamped, because a region running off the edge of the page returns an empty image
	# and the prop would go invisible again -- the exact failure this file exists to end.
	var page := Rect2i(Vector2i.ZERO, image.get_size())
	var wanted := Rect2i(region.position.round(), region.size.round()).intersection(page)
	if wanted.size.x <= 0 or wanted.size.y <= 0:
		push_error("AtlasTile: region %s falls outside %s" % [region, page])
		return null
	var texture := ImageTexture.create_from_image(image.get_region(wanted))
	_cache[key] = texture
	return texture
