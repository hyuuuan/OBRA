class_name UIIcons
extends RefCounted
## Pictures of the things the game hands you, for the screens that have to show one.
##
## Most of what the player acquires already has art -- a drawing has the player's own strokes,
## the canvas is `hub/paintings/level_2.png`, the brush is `hud/brush_full.png`, the hidden
## flower has its own sprite. The brass key off the nail in the heap does not: it is drawn in
## code inside StrawRoom2D, as part of that room, and there is no file anywhere to hang on a
## card or put in an inventory slot.
##
## So it is written here the way UIGlyph writes the droplet and the flag: rows of characters,
## one per pixel, turned into an ImageTexture at native size and blown up with NEAREST. It
## costs nothing, it cannot be imported with the wrong filter, and it does not add a binary
## nobody can diff. The generated textures are cached, because a screen that rebuilds one
## every time it opens is doing per-pixel work for a picture that never changes.
##
## ⚠ An ImageTexture must never be saved into a .tres -- it keeps its header and loses its
## pixels, and the control comes up invisible with nothing to say why. These live in memory.

## Rows top to bottom. '.' is nothing; the other characters index into the palette below.
const BRASS_KEY := [
	"..ddd.......",
	".dbbbd......",
	".db.bd......",
	".dbbbd......",
	"..dbbdddd...",
	"...bbbbbbdd.",
	"...dbbbbbbbd",
	"....dddb.b.d",
	".......d.d.d",
]

const PALETTES := {
	"brass": {
		"b": Color(0.804, 0.616, 0.216, 1.0),  # CD9E37  the metal
		"d": Color(0.427, 0.310, 0.098, 1.0),  # 6D4F19  its edge
		"l": Color(0.949, 0.855, 0.529, 1.0),  # F2DA87  the catch of light
	},
}

static var _cache: Dictionary = {}


## The brass key from the nail in the straw heap.
static func key() -> Texture2D:
	return bitmap(BRASS_KEY, "brass", "key")


## Any character-row bitmap as a texture, cached under `id`.
static func bitmap(rows: Array, palette_id: String, id: String) -> Texture2D:
	var cached: Texture2D = _cache.get(id)
	if cached != null:
		return cached
	var palette: Dictionary = PALETTES.get(palette_id, {})
	var height := rows.size()
	if height == 0:
		return null
	var width := String(rows[0]).length()
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in range(height):
		var row := String(rows[y])
		for x in range(mini(width, row.length())):
			var key_char := row[x]
			if not palette.has(key_char):
				continue
			image.set_pixel(x, y, palette[key_char] as Color)
	var texture := ImageTexture.create_from_image(image)
	_cache[id] = texture
	return texture
