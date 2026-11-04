extends SceneTree
## Preserve the supplied moonlit artwork: native crops, pixel-cut seams, nearest scaling.
## godot --headless --path game --script res://tools/build_moonlit_ground.gd
const SOURCE := "res://../LEVEL4_Mt.Makiling/authored/moonlit_ground/"
const DEST := "res://assets/Level4/ground_moonlit/"
const FOLIAGE := "res://assets/Level4/foliage_moonlit/"
const WALL := Rect2i(0, 220, 338, 448)
const STRIPS := [0, 510, 968, 1442]
const OVERLAP := 34
const SPRITES := [
	{"name": "plant_1", "rect": Rect2i(136, 52, 228, 156)},
	{"name": "plant_2", "rect": Rect2i(624, 50, 212, 158)},
	{"name": "plant_3", "rect": Rect2i(1124, 80, 248, 128)},
	{"name": "plant_0", "rect": Rect2i(1624, 112, 188, 96)},
	{"name": "vine_0", "rect": Rect2i(348, 228, 120, 128)},
	{"name": "vine_1", "rect": Rect2i(796, 228, 120, 132)},
]


func _initialize() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE + "reference.png"))
	if source == null or source.get_size() != Vector2i(2172, 724):
		push_error("Moonlit kit: expected the supplied 2172 x 724 reference")
		quit(1)
		return
	source.convert(Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLIAGE))
	var face := source.get_region(WALL)
	for index in range(1, STRIPS.size()):
		var strip := source.get_region(Rect2i(STRIPS[index], WALL.position.y, WALL.size.x, WALL.size.y))
		face = _join(face, strip, OVERLAP)
	face = _wrap(face, OVERLAP)
	# Native size: preserve the reference's actual pixels, color ramps and cluster sizes.
	if face.save_png(DEST + "face.png") != OK:
		push_error("Moonlit kit: could not save ground")
		quit(1)
		return
	# Shallow floating shelves: keep native pixel size, using a shorter moss lip and one
	# stone course from the same ground. Do not squeeze the whole cliff into a thin block.
	var shelf := Image.create(face.get_width(), 32, false, Image.FORMAT_RGBA8)
	shelf.blit_rect(face, Rect2i(0, 0, face.get_width(), 16), Vector2i.ZERO)
	shelf.blit_rect(face, Rect2i(0, 80, face.get_width(), 16), Vector2i(0, 16))
	if shelf.save_png(DEST + "platform.png") != OK:
		push_error("Moonlit kit: could not save platform")
		quit(1)
		return
	var plants: Array[Image] = []
	var vines: Array[Image] = []
	for entry: Dictionary in SPRITES:
		# Sprite boxes were measured in the 2048 px preview; crop at native resolution.
		var measured: Rect2i = entry.rect
		var factor := source.get_width() / 2048.0
		var native := Rect2i(floori(measured.position.x * factor), floori(measured.position.y * factor),
			ceili(measured.size.x * factor), ceili(measured.size.y * factor))
		var is_vine := String(entry.name).begins_with("vine")
		# Stop above the horizontal grass strip: it belongs to the ground, not the bush.
		if not is_vine:
			native.size.y = mini(native.end.y, 218) - native.position.y
		var sprite := source.get_region(native)
		_clear_background(sprite, is_vine)
		var bounds := sprite.get_used_rect()
		if not bounds.has_area():
			push_error("Moonlit kit: empty sprite %s" % entry.name)
			quit(1)
			return
		var crop := sprite.get_region(bounds)
		if crop.save_png(FOLIAGE + String(entry.name) + ".png") != OK:
			push_error("Moonlit kit: could not save %s" % entry.name)
			quit(1)
			return
		if String(entry.name).begins_with("plant"):
			plants.append(crop)
		else:
			vines.append(crop)
		print("Moonlit %s: %s" % [entry.name, crop.get_size()])
		# Retire the old mixed export; a ground rebuild must never plant a bush itself.
		for suffix in [".png", ".png.import"]:
			var old_path: String = DEST + String(entry.name) + suffix
			if FileAccess.file_exists(old_path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(old_path))
	var config := {"lip": 8, "band": 64, "skip": 80, "deep": "#001b1e",
		"overhang": 6, "edge": false, "plants": 0, "vines": 0}
	_write(DEST + "kit.json", JSON.stringify(config, "  ") + "\n")
	_write(FOLIAGE + "foliage.json", JSON.stringify({"plants": 4, "vines": 2,
		"plant_gap": [420, 860], "plant_margin": 140, "vine_offset": 22}, "  ") + "\n")
	_tileset(face.get_size())
	_preview(face, plants, vines)
	_write(SOURCE + "cuts.json", JSON.stringify({"wall_y": WALL.position.y,
		"wall_height": WALL.size.y, "strip_width": WALL.size.x, "strip_x": STRIPS,
		"overlap": OVERLAP, "scale": 1.0, "sprite_box_preview_width": 2048, "sprites": SPRITES}, "  ") + "\n")
	print("OBRA_MOONLIT_GROUND_BUILT: %s, original artwork, four plants, two vines" % face.get_size())
	quit(0)


## Color only seeds the silhouette. Closing narrow shadow cuts and filling its enclosed holes
## preserves the navy shading INSIDE leaves that the old global color key punched out.
## Retained/recovered plant pixels use the original source RGB, never a white/blurred fill.
func _clear_background(sprite: Image, foliage_only: bool) -> void:
	var size := sprite.get_size()
	var mask := PackedByteArray()
	mask.resize(size.x * size.y)
	for y in range(sprite.get_height()):
		for x in range(sprite.get_width()):
			var color := sprite.get_pixel(x, y)
			var navy := color.r < 0.065 and color.b >= color.g * 0.95
			var rock := foliage_only and color.g <= color.r * 1.08
			mask[y * size.x + x] = int(color.a >= 0.5 and not navy and not rock)
	# Work padded so the sprite's tips are not eroded against the crop boundary.
	var padding := 12
	var padded_size := size + Vector2i.ONE * padding * 2
	var padded := PackedByteArray()
	padded.resize(padded_size.x * padded_size.y)
	for y in range(size.y):
		for x in range(size.x):
			padded[(y + padding) * padded_size.x + x + padding] = mask[y * size.x + x]
	padded = _morph(_morph(padded, padded_size, 7, true), padded_size, 7, false)
	padded = _fill_holes(padded, padded_size)
	for y in range(size.y):
		for x in range(size.x):
			var color := sprite.get_pixel(x, y)
			var keep := padded[(y + padding) * padded_size.x + x + padding] != 0
			if not keep:
				sprite.set_pixel(x, y, Color.TRANSPARENT)
			else:
				# Vines were painted over brown rocks; recovered shadow cuts must be leaf
				# shadow, not pieces of that wall. Existing visible leaf colors stay exact.
				if foliage_only and color.g <= color.r * 1.08:
					color = Color("#002d23")
				color.a = 1.0
				sprite.set_pixel(x, y, color)


## Square max/min filter using a summed-area table: crisp alpha, no RGB interpolation.
func _morph(mask: PackedByteArray, size: Vector2i, radius: int, dilate: bool) -> PackedByteArray:
	var stride := size.x + 1
	var sums := PackedInt32Array()
	sums.resize(stride * (size.y + 1))
	for y in range(size.y):
		var total := 0
		for x in range(size.x):
			total += mask[y * size.x + x]
			sums[(y + 1) * stride + x + 1] = total + sums[y * stride + x + 1]
	var result := PackedByteArray()
	result.resize(mask.size())
	for y in range(size.y):
		for x in range(size.x):
			var left := maxi(0, x - radius)
			var right := mini(size.x, x + radius + 1)
			var top := maxi(0, y - radius)
			var bottom := mini(size.y, y + radius + 1)
			var count := sums[bottom * stride + right] - sums[top * stride + right] \
				- sums[bottom * stride + left] + sums[top * stride + left]
			result[y * size.x + x] = int(count > 0 if dilate else count == (right - left) * (bottom - top))
	return result


func _fill_holes(mask: PackedByteArray, size: Vector2i) -> PackedByteArray:
	var outside := PackedByteArray()
	outside.resize(mask.size())
	var queue := PackedInt32Array([0])
	outside[0] = 1
	var cursor := 0
	while cursor < queue.size():
		var index := queue[cursor]
		cursor += 1
		var point := Vector2i(index % size.x, index / size.x)
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var near := point + offset
			if near.x < 0 or near.y < 0 or near.x >= size.x or near.y >= size.y:
				continue
			var next := near.y * size.x + near.x
			if mask[next] == 0 and outside[next] == 0:
				outside[next] = 1
				queue.append(next)
	var result := mask.duplicate()
	for index in range(mask.size()):
		if outside[index] == 0:
			result[index] = 1
	return result


## A single minimum-error vertical pixel cut keeps crisp edges, never blended/ghosted rocks.
func _seam(left: Image, right: Image, overlap: int) -> PackedInt32Array:
	var width := left.get_width()
	var costs: Array[PackedFloat32Array] = []
	var previous: Array[PackedInt32Array] = []
	for y in range(left.get_height()):
		var row := PackedFloat32Array()
		var parents := PackedInt32Array()
		for x in range(overlap):
			var a := left.get_pixel(width - overlap + x, y)
			var b := right.get_pixel(x, y)
			var cost := Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length_squared()
			var best := x
			if y > 0:
				for candidate in range(maxi(0, x - 1), mini(overlap, x + 2)):
					if costs[y - 1][candidate] < costs[y - 1][best]:
						best = candidate
				cost += costs[y - 1][best]
			row.append(cost)
			parents.append(best)
		costs.append(row)
		previous.append(parents)
	var cut := 0
	for x in range(overlap):
		if costs[-1][x] < costs[-1][cut]:
			cut = x
	var path := PackedInt32Array()
	path.resize(left.get_height())
	for y in range(left.get_height() - 1, -1, -1):
		path[y] = cut
		cut = previous[y][cut]
	return path


func _join(left: Image, right: Image, overlap: int) -> Image:
	var offset := left.get_width() - overlap
	var result := Image.create(offset + right.get_width(), left.get_height(), false, Image.FORMAT_RGBA8)
	result.blit_rect(left, Rect2i(Vector2i.ZERO, left.get_size()), Vector2i.ZERO)
	result.blit_rect(right, Rect2i(Vector2i.ZERO, right.get_size()), Vector2i(offset, 0))
	var seam := _seam(left, right, overlap)
	for y in range(left.get_height()):
		for x in range(seam[y]):
			result.set_pixel(offset + x, y, left.get_pixel(offset + x, y))
	return result


func _wrap(source: Image, overlap: int) -> Image:
	var width := source.get_width() - overlap
	var seam := _seam(source, source, overlap)
	var result := source.get_region(Rect2i(0, 0, width, source.get_height()))
	for y in range(source.get_height()):
		for x in range(seam[y]):
			result.set_pixel(x, y, source.get_pixel(width + x, y))
	return result


func _tileset(size: Vector2i) -> void:
	var text := "[gd_resource type=\"TileSet\" load_steps=3 format=3]\n\n"
	text += "[ext_resource type=\"Texture2D\" path=\"res://assets/Level4/ground_moonlit/face.png\" id=\"1\"]\n\n"
	text += "[sub_resource type=\"TileSetAtlasSource\" id=\"Atlas\"]\ntexture = ExtResource(\"1\")\ntexture_region_size = Vector2i(64, 64)\n"
	for y in range(size.y / 64):
		for x in range(size.x / 64):
			text += "%d:%d/0 = 0\n" % [x, y]
	text += "\n[resource]\ntile_size = Vector2i(64, 64)\nsources/0 = SubResource(\"Atlas\")\n"
	_write(DEST + "ground_tileset.tres", text)


func _preview(face: Image, plants: Array[Image], vines: Array[Image]) -> void:
	var preview := Image.create(face.get_width() * 2, 720, false, Image.FORMAT_RGBA8)
	preview.fill(Color("#001b1e"))
	for repeat in range(2):
		preview.blit_rect(face, Rect2i(Vector2i.ZERO, face.get_size()),
			Vector2i(repeat * face.get_width(), 240))
	for index in range(plants.size()):
		var plant := plants[index]
		preview.blend_rect(plant, Rect2i(Vector2i.ZERO, plant.get_size()),
			Vector2i(140 + index * 560, 240 - plant.get_height()))
	for index in range(4):
		var vine := vines[index % vines.size()]
		preview.blend_rect(vine, Rect2i(Vector2i.ZERO, vine.get_size()),
			Vector2i(380 + index * 560, 262))
	preview.save_png(ProjectSettings.globalize_path(SOURCE + "repeat_preview.png"))


func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()
