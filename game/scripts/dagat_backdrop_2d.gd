class_name DagatBackdrop2D
extends Node2D
## Dagat's painted parallax, in three bands: the shore by day, the sea under a storm, and
## the deep. One node per band, each building its own stack of layers from the manifest
## tools/build_dagat.py writes.
##
## WHY A NODE AND NOT TWENTY SPRITES IN THE SCENE. The delivered art is 1672px wide and the
## level is 5400, so every layer has to repeat; each layer scrolls at its own rate; and four
## of them are animations. Authored by hand that is sixty-odd scene nodes whose z-order,
## parallax factor and frame timing all have to agree with each other, and the first one
## somebody nudges in the editor is the one that breaks registration. Here the stack is a
## table with a reason beside each row.
##
## ⚠ THE LAYERS ARE REGISTERED TO EACH OTHER BY THEIR MARGINS, so every one of them is drawn
## on the same 1672x941 plate and pinned by the SAME top edge. `plate_top` is where that edge
## sits in the world, and it is derived from the art rather than chosen: the shore's sand
## surface is at plate-y 790 and the apo stands at y 560, so the plate's top is at -230.
## Moving one layer's y independently is how a horizon leaves its own waterline.
##
## Parallax comes for free: EnvironmentBaseplate drives anything with set_camera_origin and
## update_for_camera, which is the same hook DepthLayer2D uses.

const MANIFEST := "res://assets/Level3/dagat.json"

## ⚠ EnvironmentBaseplate SORTS ITS LAYERS BY THIS. It collects anything with
## set_camera_origin/update_for_camera -- which is how a backdrop gets parallax for free --
## and then sorts them with float(child.get("depth")). A layer without the property hands it
## null and throws "Nonexistent 'float' constructor" once per sort, forever. DepthLayer2D has
## carried it since Level 1; this is the same contract, not a new one.
@export var depth: float = 0.0

## WHICH BAND. Each is a separate delivery and a separate place in the level.
@export_enum("shore", "storm", "deep") var band: String = "shore"
## The world x range this band covers. Layers tile across it and stop at its edges, so the
## shore does not go on being drawn a thousand pixels out to sea.
@export var span := Vector2(0.0, 1100.0)
## World y of the plate's TOP edge. See the header -- derived, not chosen.
@export var plate_top: float = -230.0
## Stretch the plate vertically. The deep band fills a water column that is not 941 tall.
@export var plate_scale: float = 1.0
## ⚠ WHERE THE LAND IS. A layer marked `ground` -- the sand -- is laid only across these x
## ranges instead of the whole band, because sand is not sky: tiled across the band it ran
## straight out over the sea. ZERO means "no land here". The home beach is the first; the
## island the crossing arrives at is the second, and it faces the other way.
@export var home_ground := Vector2.ZERO
@export var island_ground := Vector2.ZERO
## Where the camera stands when each of the storm's two landmarks is centred on screen. They
## are halves of one plate -- a headland with a jetty at its left, an island with the ink buoy
## at its right -- and each is shown ONCE, where it belongs in the crossing.
@export var headland_x := 0.0
@export var far_island_x := 0.0
## ⚠ WHERE THE BAND FADES UP, IN WORLD X. Dagat crosses from a bright shore into a storm, and
## the design asks for exactly that: "the field has to get darker and emptier as the player
## nears the bakunawa, or the encounter arrives without buildup." Two bands butted against
## each other cut from noon to night at one pixel; a band that fades in over a thousand
## pixels is the buildup. Zero means "always at full", which is what the other two want.
@export var fade_span := Vector2.ZERO

## ⚠ THE STACK, FURTHEST FIRST. `rate` is the parallax factor: 0 is painted on the far wall
## and never moves, 1 travels with the world. `fps` turns a layer into an animation.
##
## ⚠ `z` IS ABSOLUTE ACROSS ALL THREE BANDS, NOT A PLACE WITHIN ONE. The bands share a
## screen -- the storm fades in over the shore's sky, the deep sits under both -- and when each
## band numbered its own stack from -200 the three interleaved: the deep's ruins drew over the
## storm's underside, the storm's waves tied with the deep's terraces and fell back on tree
## order, and the frame read as three pictures shuffled together. So the whole level is one
## ordering, back to front:
##
##   shore far layers  -250..-235   the daylight sky and sea, behind everything
##   deep              -230..-215   the water column and its floor
##   storm             -212..-193   sky, clouds, islands, the underside, the waves, the shores
##   shore ground      -165..-160   sand and palms: nearer than any sea, behind the player
##   storm rain          60         in front of everything
const BANDS := {
	"shore": [
		{"key": "shore/sky", "rate": 0.15, "z": -250},
		{"key": "shore/mountains", "rate": 0.35, "z": -245},
		{"key": "shore/ocean", "rate": 0.55, "z": -240},
		# The surf is foam over a still sea, so it moves a little faster than the water it
		# sits on and slower than the sand -- which is what makes the beach read as nearer.
		{"key": "shore/surf", "rate": 0.70, "z": -235, "fps": 3.0},
		{"key": "shore/sand", "rate": 1.00, "z": -165, "ground": true},
		# ⚠ PIECES, NOT TILES. Each palm plate is one clump drawn at one edge of a 1672 canvas:
		# a palm and rocks at the far left, or a sand spit ending in rocks and a palm at the
		# right. Tiled and mirrored, a clump of palms stood every screen along the beach and
		# out across the open sea. So each is cut to the clump and set down once, at an end of
		# the land -- and at the island, which faces the other way, mirrored.
		{"key": "shore/palms_left", "rate": 1.00, "z": -160, "pieces": [
			{"crop": Vector2(0, 478), "at": "home_ground.x", "align": "left"},
			{"crop": Vector2(0, 478), "at": "island_ground.y", "align": "right",
				"flip": true},
		]},
		{"key": "shore/palms_right", "rate": 1.00, "z": -160, "pieces": [
			{"crop": Vector2(690, 1672), "at": "home_ground.y", "align": "right"},
			{"crop": Vector2(690, 1672), "at": "island_ground.x", "align": "left",
				"flip": true},
		]},
	],
	"deep": [
		{"key": "deep/water", "rate": 0.15, "z": -230},
		{"key": "deep/ridges", "rate": 0.35, "z": -225},
		{"key": "deep/ruins", "rate": 0.55, "z": -220},
		{"key": "deep/terraces", "rate": 0.80, "z": -215},
	],
	"storm": [
		{"key": "storm/clouds", "rate": 0.15, "z": -210},
		{"key": "storm/islands", "rate": 0.35, "z": -205},
		{"key": "storm/undersea", "rate": 0.50, "z": -198},
		{"key": "storm/waves", "rate": 0.80, "z": -195, "fps": 4.0},
		# In FRONT of the waves and at their rate: the jetty's posts stand in the water, and a
		# headland behind the sea it stands in reads as a picture of a headland pasted on.
		{"key": "storm/shores", "rate": 0.80, "z": -193, "pieces": [
			{"crop": Vector2(0, 536), "at": "headland_x", "align": "center"},
			{"crop": Vector2(1306, 1672), "at": "far_island_x", "align": "center"},
		]},
		# Rain falls in front of everything, fast, and never repeats the sea's rhythm.
		{"key": "storm/rain", "rate": 1.00, "z": 60, "fps": 10.0},
	],
}

var _layers: Array[Node2D] = []


func _ready() -> void:
	var manifest := _manifest()
	for row_value: Variant in BANDS.get(band, []):
		var row: Dictionary = row_value
		var frames := _frames(manifest, String(row["key"]))
		if frames.is_empty():
			push_warning("DagatBackdrop2D: nothing in the manifest for %s" % row["key"])
			continue
		if row.has("pieces"):
			var pieces: Array = row["pieces"]
			for index in range(pieces.size()):
				var piece: Dictionary = pieces[index]
				var at := _landmark(String(piece["at"]))
				if is_nan(at):
					continue
				var layer := _new_layer(row, frames, manifest)
				layer.name = "%s_%d" % [layer.name, index]
				layer.crop = piece["crop"]
				layer.flipped = bool(piece.get("flip", false))
				layer.place_piece(at, String(piece.get("align", "center")))
				add_child(layer)
				_layers.append(layer)
		elif bool(row.get("ground", false)):
			for ground: Vector2 in [home_ground, island_ground]:
				if ground == Vector2.ZERO:
					continue
				var layer := _new_layer(row, frames, manifest)
				layer.name = "%s_%d" % [layer.name, int(ground.x)]
				layer.span = ground
				layer.grounded = true
				add_child(layer)
				_layers.append(layer)
		else:
			var layer := _new_layer(row, frames, manifest)
			add_child(layer)
			_layers.append(layer)


func _new_layer(row: Dictionary, frames: Array[Texture2D], manifest: Dictionary) -> _Layer:
	var layer := _Layer.new()
	layer.name = String(row["key"]).replace("/", "_")
	layer.frames = frames
	layer.origin = _origin_of(manifest, String(row["key"]))
	layer.canvas_width = float(manifest.get("plate_size", [1672, 941])[0])
	layer.span = span
	layer.plate_scale = plate_scale
	layer.rate = float(row["rate"])
	layer.z_index = int(row["z"])
	layer.fps = float(row.get("fps", 0.0))
	layer.plate_top = plate_top
	return layer


## A landmark by name: an export, or one end of a ground ("home_ground.y"). NAN when the band
## does not have that piece of land, which is how the island's palms stay out of a band that
## has no island.
func _landmark(name_path: String) -> float:
	var parts := name_path.split(".")
	var value: Variant = get(parts[0])
	if value is Vector2:
		var ground := value as Vector2
		if ground == Vector2.ZERO:
			return NAN
		return ground.x if parts.size() < 2 or parts[1] == "x" else ground.y
	if value is float and not is_zero_approx(float(value)):
		return float(value)
	return NAN


## ⚠ WHERE AN ANIMATION'S FRAMES SIT ON THE PLATE THEY WERE CUT FROM. A group is trimmed to
## the union of its frames, so frame 0 of the storm's waves is 867 tall and starts 48 rows
## down the 941 plate everything else is registered to. Drawn at the plate's top edge, the
## waves rode 48 pixels above the sea they belong to, the surf 21 above the sand, and the rain
## 18 to the left of its own sky. A single plate has no origin, which is (0, 0).
func _origin_of(manifest: Dictionary, key: String) -> Vector2:
	var groups: Dictionary = manifest.get("groups", {})
	if not groups.has(key):
		return Vector2.ZERO
	var origin: Array = (groups[key] as Dictionary).get("origin", [0, 0])
	return Vector2(float(origin[0]), float(origin[1]))


func _manifest() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return parsed as Dictionary if parsed is Dictionary else {}


## A key is either a single plate or an animation group. Both come back as a frame list, so
## the layer below does not have to care which it was handed.
func _frames(manifest: Dictionary, key: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var plates: Dictionary = manifest.get("plates", {})
	var groups: Dictionary = manifest.get("groups", {})
	var paths: Array = []
	if plates.has(key):
		paths = [String((plates[key] as Dictionary).get("file", ""))]
	elif groups.has(key):
		paths = (groups[key] as Dictionary).get("frames", [])
	for path_value: Variant in paths:
		var texture := load(String(path_value)) as Texture2D
		if texture != null:
			out.append(texture)
	return out


## ⚠ THE CAMERA'S ORIGIN IS NOT KEPT, deliberately. EnvironmentBaseplate hands every layer a
## fresh origin whenever the player's body changes -- set_target resyncs them -- and parallax
## measured from "wherever the camera was at the last transformation" snaps every far layer
## back to its starting place the moment the player draws something mid-crossing. The whole
## sky jumped sideways. Parallax here is measured from a fixed point in the world instead, so
## the backdrop is a function of where the camera IS, never of how it got there.
func set_camera_origin(camera_position: Vector2) -> void:
	update_for_camera(camera_position)


func update_for_camera(camera_position: Vector2) -> void:
	if fade_span != Vector2.ZERO:
		# x < y fades the band UP across that stretch; x > y fades it DOWN. The shore and the
		# storm are the same crossing seen twice, so one has to leave as the other arrives --
		# otherwise a low-rate layer from the daylight band drifts far enough right to hang a
		# palm tree over the storm.
		# ⚠ THE RAMP ALWAYS RUNS LEFT TO RIGHT ACROSS THE WORLD; only its SENSE is reversed.
		# Reading it from fade_span.x meant a fade-out started where it should have finished,
		# so the daylight band stayed at full alpha across the whole crossing and hung a palm
		# tree over the storm.
		var lo := minf(fade_span.x, fade_span.y)
		var hi := maxf(fade_span.x, fade_span.y)
		var ramp := clampf((camera_position.x - lo) / maxf(1.0, hi - lo), 0.0, 1.0)
		modulate.a = ramp if fade_span.y > fade_span.x else 1.0 - ramp
	for layer in _layers:
		# ⚠ HORIZONTAL ONLY. Parallax on Y unmoors the composition from the thing it is
		# registered to: this level is a thousand pixels tall, so let the far layers lag on Y
		# and the sky, the horizon and the surf all slide up out of frame the moment the
		# player goes under. That is exactly what it did, and it looked like four layers
		# failing to render.
		#
		# A rate of 1 sits still relative to the world; anything less lags behind the camera,
		# which is what reads as distance. At the reference point every layer is where it was
		# authored; everywhere else it has drifted by (1 - rate) of the distance from there.
		layer.position = Vector2(
			layer.base_x + (camera_position.x - layer.reference_x) * (1.0 - layer.rate),
			layer.plate_top)


## One tiled, optionally animated plate.
##
## ⚠ SPRITES, NOT A CUSTOM _draw. The first version of this drew
## with draw_texture_rect(..., tile = true) and produced nothing at all for four of the seven
## layers -- _draw ran, with the right texture, the right rect and the right position, and the
## screen stayed empty where they should have been. Sprite2D with region_enabled and
## TEXTURE_REPEAT_ENABLED is the path level_2.tscn already uses for its backdrop, and it
## repeats across a span wider than the texture without any of that.
class _Layer extends Node2D:
	## The far edge of the camera's travel past either end of a band, in world pixels: half a
	## screen at the widest zoom this level uses, with room to spare.
	const HALF_VIEW := 1200.0

	var frames: Array[Texture2D] = []
	var span := Vector2.ZERO
	var plate_scale := 1.0
	var plate_top := 0.0
	var rate := 1.0
	var fps := 0.0
	## Where frame 0 sits on the plate it was cut from. Zero for a plate.
	var origin := Vector2.ZERO
	## The width every layer repeats at: the PLATE's, not the trimmed frame's, or a trimmed
	## animation tiles at a different period from the sea it is painted on.
	var canvas_width := 1672.0
	## The world x the camera is at when this layer is exactly where it was authored.
	var reference_x := 0.0
	## Where the layer's left edge sits at that moment.
	var base_x := 0.0
	## A piece is one cut of a plate (`crop` is its x range on the canvas) set down once.
	var crop := Vector2.ZERO
	var flipped := false
	## Laid across `span` at world rate and cut off at its ends, rather than widened for drift.
	var grounded := false
	var _frame := 0
	var _clock := 0.0

	var _tiles: Array[Sprite2D] = []

	## Set a piece down so it sits where it belongs when the camera is looking at it. For a
	## layer at world rate that is simply where it is; for a slower one, it is where it is when
	## the camera stands at `at`, and it drifts from there like everything else at its depth.
	func place_piece(at: float, align: String) -> void:
		var width := crop.y - crop.x
		match align:
			"left":
				base_x = at
			"right":
				base_x = at - width
			_:
				base_x = at - width * 0.5
		reference_x = base_x + width * 0.5

	func _ready() -> void:
		if crop != Vector2.ZERO:
			_build_piece()
		elif grounded:
			_build_ground()
		else:
			_build_tiles()
		position = Vector2(base_x, plate_top)
		set_process(fps > 0.0 and frames.size() > 1)

	func _add_tile(x: float, flip: bool, region: Rect2) -> Sprite2D:
		var tile := Sprite2D.new()
		tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Top-left anchored, because every layer in a band is pinned by the SAME top edge.
		tile.centered = false
		tile.texture = frames[0]
		tile.flip_h = flip
		if region.size != Vector2.ZERO:
			tile.region_enabled = true
			tile.region_rect = region
		tile.position = Vector2(x, origin.y * plate_scale)
		tile.scale = Vector2(1.0, plate_scale)
		add_child(tile)
		_tiles.append(tile)
		return tile

	func _build_piece() -> void:
		var height := float(frames[0].get_height())
		_add_tile(0.0, flipped, Rect2(crop.x - origin.x, 0.0, crop.y - crop.x, height))

	## ⚠ A CUT MIRRORED TILE SHOWS THE FAR END OF THE TEXTURE, not the near one. Mirrored
	## copies meet edge to matching edge: an upright tile ends on the texture's last column, so
	## the flipped one after it has to START on that column -- and when it is cut short, what
	## is kept is the texture's right-hand part, reversed.
	func _build_ground() -> void:
		base_x = span.x
		reference_x = span.x
		var height := float(frames[0].get_height())
		var texture_width := float(frames[0].get_width())
		var x := 0.0
		var index := 0
		while x < span.y - span.x - 0.5:
			var width := minf(texture_width, span.y - span.x - x)
			var flip := index % 2 == 1
			var region := Rect2(0.0, 0.0, width, height)
			if flip:
				region.position.x = texture_width - width
			_add_tile(x, flip, region)
			x += texture_width
			index += 1

	func _build_tiles() -> void:
		# ⚠ MIRRORED TILES, NOT A REPEATING REGION. Every plate is a self-contained painting
		# 1672 wide and the bands are two to four times that, so it has to repeat -- and a
		# straight repeat puts a hard vertical cut through the ruins every 1672 pixels, which
		# the eye finds immediately. Flipping every second copy turns the cut into a mirror
		# line, which reads as more of the same place rather than as the same place again.
		#
		# ⚠ A SLOW LAYER HAS TO COVER MORE GROUND THAN THE BAND IS WIDE. At rate 0.15 the sky
		# lags the camera by 85% of everything it travels, so it slides sideways by nearly as
		# much as the band is wide. It is referenced from the band's middle, so it drifts by
		# (1 - rate) of half the band plus half a screen at most in either direction, and the
		# tiles are laid out to cover exactly that.
		reference_x = (span.x + span.y) * 0.5
		var drift := ((span.y - span.x) * 0.5 + HALF_VIEW) * (1.0 - rate)
		base_x = span.x - drift
		var count := int(ceil((span.y - span.x + drift * 2.0) / canvas_width))
		for index in range(count):
			var flip := index % 2 == 1
			# ⚠ flip_h mirrors the texture INSIDE the sprite's own rect; it does not move the
			# rect. A trimmed frame mirrored on its canvas lands the same distance from the
			# canvas's OTHER edge, which is the only thing that has to be worked out here.
			var inset := origin.x
			if flip:
				inset = canvas_width - origin.x - float(frames[0].get_width())
			_add_tile(canvas_width * float(index) + inset, flip, Rect2())

	func _process(delta: float) -> void:
		_clock += delta
		var step := 1.0 / maxf(0.01, fps)
		if _clock < step:
			return
		_clock -= step
		_frame = (_frame + 1) % frames.size()
		for tile in _tiles:
			tile.texture = frames[_frame]
