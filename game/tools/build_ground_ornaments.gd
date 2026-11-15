extends SceneTree
## Slice generated Dilim ornaments onto the game's coarse 3 px grid, preserving the base tile.
## godot --headless --path game --script res://tools/build_ground_ornaments.gd

const SOURCE := "res://../LEVEL4_Mt.Makiling/authored/ground_ornaments.png"
const DEST := "res://assets/Level4/ground_mossy/"
const WIDTHS := [72, 75, 66, 72, 54, 60]

func _initialize() -> void:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	if sheet == null or sheet.get_size() != Vector2i(1024, 1536):
		push_error("Ground ornaments: expected a 1024 x 1536 RGBA atlas")
		quit(1)
		return
	for index in range(WIDTHS.size()):
		var tile := sheet.get_region(Rect2i((index % 2) * 512, (index / 2) * 512, 512, 512))
		# Remove the generated translucent matte; actual sprite pixels become fully opaque.
		for y in range(tile.get_height()):
			for x in range(tile.get_width()):
				var pixel := tile.get_pixel(x, y)
				pixel.a = 1.0 if pixel.a >= 0.5 else 0.0
				tile.set_pixel(x, y, pixel)
		var bounds := tile.get_used_rect()
		if not bounds.has_area():
			push_error("Ground ornaments: empty sprite %d" % index)
			quit(1)
			return
		tile = tile.get_region(bounds)
		var width := int(WIDTHS[index]) / 3
		var height := maxi(1, roundi(float(tile.get_height()) * width / tile.get_width()))
		tile.resize(width, height, Image.INTERPOLATE_NEAREST)
		tile.resize(width * 3, height * 3, Image.INTERPOLATE_NEAREST)
		var name := "plant_%d.png" % index if index < 4 else "vine_%d.png" % (index - 4)
		if tile.save_png(DEST.path_join(name)) != OK:
			push_error("Ground ornaments: could not save %s" % name)
			quit(1)
			return
		print("Ground ornament %s: %s" % [name, tile.get_size()])
	quit(0)
