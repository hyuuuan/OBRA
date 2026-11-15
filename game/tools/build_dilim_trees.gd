extends SceneTree
## Fit the two supplied trees to Dilim's existing origins; preserve source RGB and pixel edges.
## godot --headless --path game --script res://tools/build_dilim_trees.gd [-- --check]
const SOURCE := "res://../LEVEL4_Mt.Makiling/authored/trees/"
const OUT := "res://assets/Level4/trees/"
var failed := false


func _initialize() -> void:
	var kapre := _source("kapre_reference.png")
	var forest := _source("forest_reference.png")
	if kapre == null or forest == null:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# The supplied branch at source (364, 339) meets ART_AT (-64, -173).
	# This is a cropped trunk: continue its own upper bark to the existing canopy.
	var standing := _blank(260, 500)
	var body := kapre.get_region(Rect2i(86, 12, 1089, 1290))
	body.resize(196, 232, Image.INTERPOLATE_NEAREST)
	var upper := kapre.get_region(Rect2i(600, 12, 260, 80))
	upper.resize(47, 260, Image.INTERPOLATE_NEAREST)
	standing.blit_rect(upper, Rect2i(Vector2i.ZERO, upper.get_size()), Vector2i(108, 8))
	standing.blit_rect(body, Rect2i(Vector2i.ZERO, body.get_size()), Vector2i(16, 268))
	_save("kapre_tree_idle", standing)
	_save("kapre_tree_felled", _log(kapre, Rect2i(600, 12, 260, 1290), 300, 64, 380, 96))
	var bare := forest.get_region(Rect2i(54, 91, 943, 1378))
	var dead := bare.duplicate() as Image
	dead.resize(229, 334, Image.INTERPOLATE_NEAREST)
	standing = _blank(260, 336)
	standing.blit_rect(dead, Rect2i(Vector2i.ZERO, dead.get_size()), Vector2i(22, 2))
	_save("dead_tree_idle", standing)
	_save("dead_tree_felled", _log(forest, Rect2i(350, 560, 280, 900), 280, 64, 380, 140))
	# Replace the old repeating vine-tree frame, retaining its plate registration and scroll.
	var plate := _blank(1672, 941)
	for entry in [[280, 740, false], [1120, 660, true]]:
		var tree := bare.duplicate() as Image
		var height: int = entry[1]
		tree.resize(roundi(bare.get_width() * height / float(bare.get_height())), height, Image.INTERPOLATE_NEAREST)
		if entry[2]:
			tree.flip_x()
		var trunk := roundi(tree.get_width() * (0.53 if entry[2] else 0.47))
		plate.blit_rect(tree, Rect2i(Vector2i.ZERO, tree.get_size()), Vector2i(entry[0] - trunk, 760 - height))
	_save("forest_plate", plate)
	print("OBRA_DILIM_TREES_%s" % ("FAILED" if failed else "OK"))
	quit(1 if failed else 0)


func _source(filename: String) -> Image:
	var picture := Image.load_from_file(ProjectSettings.globalize_path(SOURCE + filename))
	if picture == null:
		push_error("Missing supplied tree: " + filename)
		return null
	picture.convert(Image.FORMAT_RGBA8)
	# Remove only almost-transparent export dust. Never key the dark bark or hollow.
	for y in range(picture.get_height()):
		for x in range(picture.get_width()):
			if picture.get_pixel(x, y).a < 24.0 / 255.0:
				picture.set_pixel(x, y, Color.TRANSPARENT)
	return picture


func _blank(width: int, height: int) -> Image:
	var picture := Image.create(width, height, false, Image.FORMAT_RGBA8)
	picture.fill(Color.TRANSPARENT)
	return picture


func _log(source: Image, crop: Rect2i, length: int, thickness: int, width: int, height: int) -> Image:
	var wood := source.get_region(crop)
	wood.resize(thickness, length, Image.INTERPOLATE_NEAREST)
	# Image.rotate_90 requires a square; copy the exact quarter-turn for this rectangle.
	var picture := _blank(width, height)
	for y in range(length):
		for x in range(thickness):
			picture.set_pixel((width - length) / 2 + length - 1 - y, height - thickness + x, wood.get_pixel(x, y))
	return picture


func _save(filename: String, picture: Image) -> void:
	var path := OUT + filename + ".png"
	if "--check" in OS.get_cmdline_user_args():
		var saved := Image.load_from_file(ProjectSettings.globalize_path(path))
		if saved != null:
			saved.convert(Image.FORMAT_RGBA8)
		if saved == null or saved.get_size() != picture.get_size() or saved.get_data() != picture.get_data():
			push_error("Stale tree export: " + path)
			failed = true
	elif picture.save_png(path) != OK:
		push_error("Could not save tree export: " + path)
		failed = true
