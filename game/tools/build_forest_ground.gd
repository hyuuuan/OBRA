extends SceneTree
## Cut the reference-matched Dilim kit. Generated originals and exact prompts live beside it.
## godot --headless --path game --script res://tools/build_forest_ground.gd
const SOURCE := "res://../LEVEL4_Mt.Makiling/authored/forest_ground_v2/"
const DEST := "res://assets/Level4/ground_forest/"
const OVERLAP := 24
const WIDTH := 384
const PIXEL := 3
const PALETTE := [Color("#15251c"), Color("#4b3927"), Color("#896642"),
	Color("#285333"), Color("#537b3c")]


func _initialize() -> void:
	var ground := Image.load_from_file(ProjectSettings.globalize_path(SOURCE + "ground_simple.png"))
	var foliage := Image.load_from_file(ProjectSettings.globalize_path(SOURCE + "foliage_simple.png"))
	if ground == null or foliage == null or foliage.get_size() != Vector2i(1536, 1024):
		push_error("Forest kit: missing ground or expected 1536 x 1024 foliage sheet")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	ground.convert(Image.FORMAT_RGBA8)
	ground.resize((WIDTH + OVERLAP) / PIXEL, 86, Image.INTERPOLATE_NEAREST)
	# The simplified source devotes 22 logical rows to moss; fit it back to the
	# level's 33 px lip, keeping the rest of the block earth rather than a deep hedge.
	var moss := ground.get_region(Rect2i(0, 0, ground.get_width(), 22))
	var earth := ground.get_region(Rect2i(0, 22, ground.get_width(), 64))
	moss.resize(ground.get_width(), 11, Image.INTERPOLATE_NEAREST)
	earth.resize(ground.get_width(), 75, Image.INTERPOLATE_NEAREST)
	ground.blit_rect(moss, Rect2i(Vector2i.ZERO, moss.get_size()), Vector2i.ZERO)
	ground.blit_rect(earth, Rect2i(Vector2i.ZERO, earth.get_size()), Vector2i(0, 11))
	_limit_palette(ground)
	var face := _wrap_horizontal(ground)
	face.resize(WIDTH, 258, Image.INTERPOLATE_NEAREST)
	face = face.get_region(Rect2i(0, 0, WIDTH, 256))
	face.save_png(DEST + "face.png")
	# The regular TileSet has six top tiles and three underground rows; the runtime draws
	# the entire strip in world phase so neighbours never restart the moss or stone pattern.
	var atlas_text := "[gd_resource type=\"TileSet\" load_steps=3 format=3]\n\n"
	atlas_text += "[ext_resource type=\"Texture2D\" path=\"res://assets/Level4/ground_forest/face.png\" id=\"1\"]\n\n"
	atlas_text += "[sub_resource type=\"TileSetAtlasSource\" id=\"Atlas\"]\ntexture = ExtResource(\"1\")\ntexture_region_size = Vector2i(64, 64)\n"
	for y in range(4):
		for x in range(6):
			atlas_text += "%d:%d/0 = 0\n" % [x, y]
	atlas_text += "\n[resource]\ntile_size = Vector2i(64, 64)\nsources/0 = SubResource(\"Atlas\")\n"
	var atlas_file := FileAccess.open(DEST + "ground_tileset.tres", FileAccess.WRITE)
	atlas_file.store_string(atlas_text)
	atlas_file.close()
	var plants: Array[Image] = []
	var vines: Array[Image] = []
	for index in range(6):
		var cell := foliage.get_region(Rect2i((index % 3) * 512, (index / 3) * 512, 512, 512))
		# Generated transparent sheets can have a faint translucent halo. Keep solid sprite
		# pixels and their RGB, and clear only the matte; never key out dark green outlines.
		for y in range(512):
			for x in range(512):
				var pixel := cell.get_pixel(x, y)
				pixel.a = 1.0 if pixel.a >= 0.75 else 0.0
				cell.set_pixel(x, y, pixel if pixel.a > 0.0 else Color.TRANSPARENT)
		var bounds := cell.get_used_rect()
		if not bounds.has_area():
			push_error("Forest kit: empty foliage cell %d" % index)
			quit(1)
			return
		cell = cell.get_region(bounds)
		var widths := [114, 96, 114, 78, 66, 72]
		var width: int = widths[index]
		var logical_width := width / PIXEL
		var logical_height := maxi(1, roundi(float(cell.get_height()) * logical_width / cell.get_width()))
		cell.resize(logical_width, logical_height, Image.INTERPOLATE_NEAREST)
		_limit_palette(cell)
		cell.resize(logical_width * PIXEL, logical_height * PIXEL, Image.INTERPOLATE_NEAREST)
		# Slot 0 is reserved for corners by CliffDressing2D; slots 1-3 dress the walk.
		var slot: int = [1, 2, 3, 0, 0, 1][index]
		var filename := "plant_%d.png" % slot if index < 4 else "vine_%d.png" % slot
		cell.save_png(DEST + filename)
		if index < 4:
			plants.append(cell)
		else:
			vines.append(cell)
		print("Forest kit %s: %s" % [filename, cell.get_size()])
	var config := {"lip": 6, "band": 33, "skip": 48, "deep": "#15251c",
		"overhang": 3, "edge": false, "plants": 4, "vines": 2}
	var file := FileAccess.open(DEST + "kit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(config, "  ") + "\n")
	file.close()
	var palette_file := FileAccess.open(DEST + "palette.json", FileAccess.WRITE)
	palette_file.store_string(JSON.stringify({"pixel_size": PIXEL,
		"colors": ["#15251c", "#4b3927", "#896642", "#285333", "#537b3c"]}, "  ") + "\n")
	palette_file.close()
	_preview(face, plants, vines)
	print("OBRA_FOREST_GROUND_BUILT: 384 x 256 repeat, four plants, two short vines, five colors, 3 px grid")
	quit(0)


## Minimum-error quilting: cut through matching pixels rather than cross-fading stones.
## The output's outer edges are adjacent columns of the original, making the wrap continuous.
func _wrap_horizontal(source: Image) -> Image:
	var overlap := OVERLAP / PIXEL
	var width := WIDTH / PIXEL
	var costs: Array[PackedFloat32Array] = []
	var previous: Array[PackedInt32Array] = []
	for y in range(source.get_height()):
		var row := PackedFloat32Array()
		var parent := PackedInt32Array()
		for x in range(overlap):
			var a := source.get_pixel(x, y)
			var b := source.get_pixel(width + x, y)
			var error := Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length_squared()
			var best := x
			if y > 0:
				for candidate in range(maxi(0, x - 1), mini(overlap, x + 2)):
					if costs[y - 1][candidate] < costs[y - 1][best]:
						best = candidate
				error += costs[y - 1][best]
			row.append(error)
			parent.append(best)
		costs.append(row)
		previous.append(parent)
	var cut := 0
	for x in range(overlap):
		if costs[-1][x] < costs[-1][cut]:
			cut = x
	var result := source.get_region(Rect2i(0, 0, width, source.get_height()))
	for y in range(source.get_height() - 1, -1, -1):
		for x in range(cut):
			result.set_pixel(x, y, source.get_pixel(width + x, y))
		cut = previous[y][cut]
	return result


## Enforce the shared five-color palette, with no dithering or extra smoothing shades.
func _limit_palette(image: Image) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if pixel.a < 0.5:
				image.set_pixel(x, y, Color.TRANSPARENT)
				continue
			var best := PALETTE[0]
			var distance := INF
			for color: Color in PALETTE:
				var delta := Vector3(pixel.r - color.r, pixel.g - color.g, pixel.b - color.b)
				if delta.length_squared() < distance:
					distance = delta.length_squared()
					best = color
			image.set_pixel(x, y, best)


func _preview(face: Image, plants: Array[Image], vines: Array[Image]) -> void:
	var preview := Image.create(WIDTH * 3, 420, false, Image.FORMAT_RGBA8)
	preview.fill(Color("#101d1b"))
	for repeat in range(3):
		preview.blit_rect(face, Rect2i(Vector2i.ZERO, face.get_size()), Vector2i(repeat * WIDTH, 150))
	for index in range(plants.size()):
		var plant := plants[index]
		preview.blend_rect(plant, Rect2i(Vector2i.ZERO, plant.get_size()),
			Vector2i(85 + index * 280, 153 - plant.get_height()))
	for index in range(4):
		var vine := vines[index % vines.size()]
		preview.blend_rect(vine, Rect2i(Vector2i.ZERO, vine.get_size()),
			Vector2i(200 + index * 250, 168))
	preview.save_png(ProjectSettings.globalize_path(SOURCE + "repeat_preview.png"))
