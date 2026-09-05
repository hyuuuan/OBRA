class_name PiyestaTiles
extends RefCounted
## The tileset the artist shipped, loaded once and handed to whatever is drawing.
##
## Piyesta's four insides were drawn with `draw_rect`: flat bands of one colour with a few
## lines on them. Next to the delivered plaza -- dense pixel art with mortar, moss, chips and
## a light coming from the left -- they read as grey boxes, and they were right to.
##
## They should never have been hand-drawn. `TextureMap_Piyesta.png` is a labelled sheet with
## three nine-slice wall sets, a stone plaza floor, church stucco, terracotta roof, plank and
## thatch, a stair set, and a shelf of props. `tools/build_tiles.py` cuts it; this loads it.
## A room built out of these is the same material as the plaza because it is the same pixels.
##
## ⚠ TILES ARE NOT ALL THE SAME SIZE. They are cut to their own alpha rather than to a grid,
## so nothing carries a transparent margin that would show as a seam. Ask for `size_of` rather
## than assuming.

## TWO SHEETS, ONE NAME SPACE. `tiles/` is the artist's own plaza tileset, cut by
## `tools/build_tiles.py`; `interiors/` is the 8-bit material authored for the insides by
## `tools/build_interiors.py`. They are kept apart on disk and together here because a room
## legitimately uses both -- a clay jar from the plaza standing on a floor that is not the
## plaza's -- and the names do not collide.
##
## ⚠ AND THE INTERIORS ARE NOT THE PLAZA'S TILES. That sheet is the OUTSIDE of a town: mossy
## rubble with grass on top, packed earth underfoot. Tiling it into a nave puts moss and dirt
## inside a building that has neither, which is exactly what this replaced.
##
## ⚠ ONE NAMESPACE MEANS THE NAMES MUST NOT COLLIDE, AND FOR A WHILE THEY DID. `banner` was
## declared in both the delivered tileset and the authored plaza sheet, and because `SHEETS`
## is walked in order the plaza's silently overwrote the other. Nothing said so -- not a
## warning, not a probe, not a frame -- because the tile that won happened to be the one the
## church wanted. That is the worst kind of correct: the room was drawing the right banner by
## LOAD ORDER rather than by name, and reordering `SHEETS` would have changed what a nave is
## dressed with. `_load` refuses to overwrite now and names both sheets in the error, and
## `run_level2_scene_probe` asserts the three manifests are disjoint.
const SHEETS := [
	{"manifest": "res://assets/Level2/tiles/tiles.json", "dir": "res://assets/Level2/tiles/"},
	{"manifest": "res://assets/Level2/interiors/interiors.json",
		"dir": "res://assets/Level2/interiors/"},
	{"manifest": "res://assets/Level2/plaza/plaza.json", "dir": "res://assets/Level2/plaza/"},
]

## The nine cells of a wall set, in the sheet's own order.
const FILL := "fill"
const TOP := "top"

static var _textures: Dictionary = {}
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	for entry: Variant in SHEETS:
		var sheet: Dictionary = entry
		var file := FileAccess.open(String(sheet["manifest"]), FileAccess.READ)
		if file == null:
			push_error("PiyestaTiles: %s is missing -- run the tool that writes it"
				% sheet["manifest"])
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("PiyestaTiles: %s does not parse" % sheet["manifest"])
			continue
		for name: Variant in (parsed as Dictionary).get("tiles", {}).keys():
			var key := String(name)
			if _textures.has(key):
				# FIRST WINS AND THE SECOND IS AN ERROR, rather than last-wins in silence. A room
				# drawing the wrong material is the one fault in this level no headless suite can
				# see, so making it loud is the whole point.
				push_error(("PiyestaTiles: '%s' is declared twice -- %s would overwrite whatever "
					+ "loaded it first. Rename one; the sheets share a namespace.")
					% [key, sheet["manifest"]])
				continue
			var texture := load(String(sheet["dir"]) + key + ".png") as Texture2D
			if texture != null:
				_textures[key] = texture


## A tile by name, or null. Null rather than a fallback on purpose: a room quietly drawing
## the wrong material is worse than one that draws nothing and is noticed.
static func get_tile(name: String) -> Texture2D:
	_load()
	return _textures.get(name) as Texture2D


static func has_tile(name: String) -> bool:
	_load()
	return _textures.has(name)


static func size_of(name: String) -> Vector2:
	var texture := get_tile(name)
	return Vector2(texture.get_size()) if texture != null else Vector2.ZERO


static func count() -> int:
	_load()
	return _textures.size()


## Fill a rect by repeating a tile. Godot's own `tile` flag on `draw_texture_rect` needs the
## canvas item's repeat mode on, which every caller here sets -- but it also stretches the
## LAST repeat rather than clipping it, so a wall whose height is not a whole number of tiles
## ends in a squashed course. Drawn by hand and clipped, which costs a few more draw calls and
## looks like masonry rather than like masonry with the bottom row sat on.
static func fill(canvas: CanvasItem, rect: Rect2, name: String,
		modulate: Color = Color.WHITE) -> void:
	var texture := get_tile(name)
	if texture == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var tile := Vector2(texture.get_size())
	if tile.x <= 0.0 or tile.y <= 0.0:
		return
	var y := rect.position.y
	while y < rect.position.y + rect.size.y:
		var height := minf(tile.y, rect.position.y + rect.size.y - y)
		var x := rect.position.x
		while x < rect.position.x + rect.size.x:
			var width := minf(tile.x, rect.position.x + rect.size.x - x)
			canvas.draw_texture_rect_region(texture,
				Rect2(x, y, width, height), Rect2(Vector2.ZERO, Vector2(width, height)),
				modulate)
			x += tile.x
		y += tile.y


## Fill a rect from a SET of interchangeable tiles, chosen per cell.
##
## One tile repeated is a grid, and the grid is what the eye finds before the material. The
## choice is deterministic on the cell's own coordinates rather than random, so a wall does
## not shimmer when the camera moves and a screenshot taken twice is the same screenshot.
static func fill_varied(canvas: CanvasItem, rect: Rect2, names: Array,
		modulate: Color = Color.WHITE) -> void:
	if names.is_empty():
		return
	var texture := get_tile(String(names[0]))
	if texture == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var tile := Vector2(texture.get_size())
	if tile.x <= 0.0 or tile.y <= 0.0:
		return
	var row := 0
	var y := rect.position.y
	while y < rect.position.y + rect.size.y:
		var height := minf(tile.y, rect.position.y + rect.size.y - y)
		var column := 0
		var x := rect.position.x
		while x < rect.position.x + rect.size.x:
			var width := minf(tile.x, rect.position.x + rect.size.x - x)
			# Hashed rather than a plain sum: `row * 7 + column * 3` walks the list in step
			# with the grid, which puts the same cut down a diagonal every time.
			var mix := (column * 73856093) ^ (row * 19349663)
			var pick := String(names[posmod(mix / 8, names.size())])
			var chosen := get_tile(pick)
			if chosen != null:
				canvas.draw_texture_rect_region(chosen, Rect2(x, y, width, height),
					Rect2(Vector2.ZERO, Vector2(width, height)), modulate)
			x += tile.x
			column += 1
		y += tile.y
		row += 1


## A run of one tile along a line, used for the capped top edge of a wall.
static func run(canvas: CanvasItem, from: Vector2, width: float, name: String,
		modulate: Color = Color.WHITE) -> void:
	var texture := get_tile(name)
	if texture == null or width <= 0.0:
		return
	var tile := Vector2(texture.get_size())
	var x := from.x
	while x < from.x + width:
		var slice := minf(tile.x, from.x + width - x)
		canvas.draw_texture_rect_region(texture, Rect2(x, from.y, slice, tile.y),
			Rect2(Vector2.ZERO, Vector2(slice, tile.y)), modulate)
		x += tile.x


## One tile, standing on `at` with its own size, optionally scaled. Props are placed by their
## FEET because that is what the level knows -- a jar sits on the floor, a lantern hangs from
## the ceiling and is placed by its top instead.
static func stand(canvas: CanvasItem, name: String, at: Vector2, scale: float = 1.0,
		modulate: Color = Color.WHITE) -> void:
	var texture := get_tile(name)
	if texture == null:
		return
	var size := Vector2(texture.get_size()) * scale
	canvas.draw_texture_rect(texture,
		Rect2(at - Vector2(size.x * 0.5, size.y), size), false, modulate)


static func hang(canvas: CanvasItem, name: String, at: Vector2, scale: float = 1.0,
		modulate: Color = Color.WHITE) -> void:
	var texture := get_tile(name)
	if texture == null:
		return
	var size := Vector2(texture.get_size()) * scale
	canvas.draw_texture_rect(texture, Rect2(at - Vector2(size.x * 0.5, 0.0), size),
		false, modulate)


## A slice out of a tile, for taking one jar off a shelf of four or one plant off a row.
static func stand_part(canvas: CanvasItem, name: String, part: Rect2, at: Vector2,
		scale: float = 1.0, modulate: Color = Color.WHITE) -> void:
	var texture := get_tile(name)
	if texture == null:
		return
	var size := part.size * scale
	canvas.draw_texture_rect_region(texture,
		Rect2(at - Vector2(size.x * 0.5, size.y), size), part, modulate)
