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
## ⚠ WHERE THE BAND FADES UP, IN WORLD X. Dagat crosses from a bright shore into a storm, and
## the design asks for exactly that: "the field has to get darker and emptier as the player
## nears the bakunawa, or the encounter arrives without buildup." Two bands butted against
## each other cut from noon to night at one pixel; a band that fades in over a thousand
## pixels is the buildup. Zero means "always at full", which is what the other two want.
@export var fade_span := Vector2.ZERO

## ⚠ THE STACK, FURTHEST FIRST. `rate` is the parallax factor: 0 is painted on the far wall
## and never moves, 1 travels with the world. `fps` turns a layer into an animation.
const BANDS := {
	"shore": [
		{"key": "shore/sky", "rate": 0.15, "z": -200},
		{"key": "shore/mountains", "rate": 0.35, "z": -190},
		{"key": "shore/ocean", "rate": 0.55, "z": -180},
		# The surf is foam over a still sea, so it moves a little faster than the water it
		# sits on and slower than the sand -- which is what makes the beach read as nearer.
		{"key": "shore/surf", "rate": 0.70, "z": -170, "fps": 3.0},
		{"key": "shore/sand", "rate": 1.00, "z": -160},
		# The palms are IN FRONT of the player, at slightly more than world rate, which is
		# what a foreground gets you: the beach opens out as you walk along it.
		{"key": "shore/palms_left", "rate": 1.08, "z": 40},
		{"key": "shore/palms_right", "rate": 1.08, "z": 40},
	],
	"storm": [
		{"key": "storm/clouds", "rate": 0.15, "z": -200},
		{"key": "storm/islands", "rate": 0.35, "z": -190},
		{"key": "storm/shore_left", "rate": 0.50, "z": -186},
		{"key": "storm/shore_right", "rate": 0.50, "z": -185},
		{"key": "storm/waves", "rate": 0.80, "z": -170, "fps": 4.0},
		# Rain falls in front of everything, fast, and never repeats the sea's rhythm.
		{"key": "storm/rain", "rate": 1.00, "z": 60, "fps": 10.0},
	],
	"deep": [
		{"key": "deep/water", "rate": 0.15, "z": -200},
		{"key": "deep/ridges", "rate": 0.35, "z": -190},
		{"key": "deep/ruins", "rate": 0.55, "z": -180},
		{"key": "deep/terraces", "rate": 0.80, "z": -170},
	],
}

var _layers: Array[Node2D] = []
var _origin := Vector2.ZERO


func _ready() -> void:
	var manifest := _manifest()
	for row_value: Variant in BANDS.get(band, []):
		var row: Dictionary = row_value
		var frames := _frames(manifest, String(row["key"]))
		if frames.is_empty():
			push_warning("DagatBackdrop2D: nothing in the manifest for %s" % row["key"])
			continue
		var layer := _Layer.new()
		layer.name = String(row["key"]).replace("/", "_")
		layer.frames = frames
		layer.span = span
		layer.plate_scale = plate_scale
		layer.rate = float(row["rate"])
		layer.z_index = int(row["z"])
		layer.fps = float(row.get("fps", 0.0))
		layer.home = Vector2(span.x, plate_top)
		add_child(layer)
		_layers.append(layer)


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


func set_camera_origin(camera_position: Vector2) -> void:
	_origin = camera_position
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
	var travelled := camera_position - _origin
	for layer in _layers:
		# ⚠ HORIZONTAL ONLY, AND home + offset RATHER THAN THE OFFSET ALONE.
		#
		# Two separate bugs live here and both of them empty the screen. Writing the parallax
		# straight into `position` throws away the plate_top every layer is pinned by, so the
		# band jumps to the world origin and the beach draws a screen below the apo.
		#
		# And parallax on Y unmoors the composition from the thing it is registered to. This
		# level is a thousand pixels tall, so the camera travels vertically as much as it
		# does horizontally: let the far layers lag on Y and the sky, the horizon and the
		# surf all slide up out of frame the moment the player goes under, leaving the sand
		# and the palms -- which run at rate 1 -- as the only things still drawn. That is
		# exactly what it did, and it looked like four layers failing to render.
		#
		# A rate of 1 sits still relative to the world; anything less lags behind the camera
		# across the level, which is what reads as distance.
		layer.position = layer.home + Vector2(
			travelled.x * (1.0 - layer.rate) - layer.spread, 0.0)


## One tiled, optionally animated plate.
##
## ⚠ SPRITES, NOT A CUSTOM _draw. The first version of this drew
## with draw_texture_rect(..., tile = true) and produced nothing at all for four of the seven
## layers -- _draw ran, with the right texture, the right rect and the right position, and the
## screen stayed empty where they should have been. Sprite2D with region_enabled and
## TEXTURE_REPEAT_ENABLED is the path level_2.tscn already uses for its backdrop, and it
## repeats across a span wider than the texture without any of that.
class _Layer extends Node2D:
	var frames: Array[Texture2D] = []
	var span := Vector2.ZERO
	var plate_scale := 1.0
	var rate := 1.0
	var fps := 0.0
	var home := Vector2.ZERO
	var _frame := 0
	var _clock := 0.0

	var _tiles: Array[Sprite2D] = []
	## How far left of the band the tiles start, so the widened run is centred on it.
	var spread := 0.0

	func _ready() -> void:
		# ⚠ MIRRORED TILES, NOT A REPEATING REGION. Every plate is a self-contained painting
		# 1672 wide and the bands are two to four times that, so it has to repeat -- and a
		# straight repeat puts a hard vertical cut through the ruins every 1672 pixels, which
		# the eye finds immediately. Flipping every second copy turns the cut into a mirror
		# line, which reads as more of the same place rather than as the same place again.
		var width := maxf(1.0, span.y - span.x)
		var texture_width := maxf(1.0, float(frames[0].get_width()))
		# ⚠ A SLOW LAYER HAS TO COVER MORE GROUND THAN THE BAND IS WIDE. At rate 0.15 the sky
		# lags the camera by 85% of everything it travels, so across a three-thousand-pixel
		# band it slides nearly three thousand pixels sideways -- off one end of its own tiles
		# and into open space at the other. Widening by 1/rate covers the drift in both
		# directions; the extra tiles are centred so neither edge runs out first.
		var reach := width / maxf(0.25, rate)
		var count := int(ceil(reach / texture_width))
		spread = (float(count) * texture_width - width) * 0.5
		for index in range(count):
			var tile := Sprite2D.new()
			tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			# Top-left anchored, because every layer in a band is pinned by the SAME top edge.
			tile.centered = false
			tile.texture = frames[0]
			tile.flip_h = index % 2 == 1
			# ⚠ THE SAME PLACE WHETHER IT IS FLIPPED OR NOT. flip_h mirrors the texture
			# INSIDE the sprite's own rect; it does not move the rect. Offsetting flipped
			# tiles by a tile-width on the assumption that they draw leftward left a
			# texture-wide hole in the middle of every band.
			tile.position = Vector2(texture_width * float(index), 0.0)
			tile.scale = Vector2(1.0, plate_scale)
			add_child(tile)
			_tiles.append(tile)
		position = home - Vector2(spread, 0.0)
		set_process(fps > 0.0 and frames.size() > 1)

	func _process(delta: float) -> void:
		_clock += delta
		var step := 1.0 / maxf(0.01, fps)
		if _clock < step:
			return
		_clock -= step
		_frame = (_frame + 1) % frames.size()
		for tile in _tiles:
			tile.texture = frames[_frame]
