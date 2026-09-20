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

## WHICH BAND. Each is a separate delivery and a separate place in the level.
@export_enum("shore", "storm", "deep") var band: String = "shore"
## The world x range this band covers. Layers tile across it and stop at its edges, so the
## shore does not go on being drawn a thousand pixels out to sea.
@export var span := Vector2(0.0, 1100.0)
## World y of the plate's TOP edge. See the header -- derived, not chosen.
@export var plate_top: float = -230.0
## Stretch the plate vertically. The deep band fills a water column that is not 941 tall.
@export var plate_scale: float = 1.0

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
		layer.position = layer.home + Vector2(travelled.x * (1.0 - layer.rate), 0.0)


## One tiled, optionally animated plate.
##
## ⚠ A Sprite2D WITH A REPEATING REGION, NOT A CUSTOM _draw. The first version of this drew
## with draw_texture_rect(..., tile = true) and produced nothing at all for four of the seven
## layers -- _draw ran, with the right texture, the right rect and the right position, and the
## screen stayed empty where they should have been. Sprite2D with region_enabled and
## TEXTURE_REPEAT_ENABLED is the path level_2.tscn already uses for its backdrop, and it
## repeats across a span wider than the texture without any of that.
class _Layer extends Sprite2D:
	var frames: Array[Texture2D] = []
	var span := Vector2.ZERO
	var plate_scale := 1.0
	var rate := 1.0
	var fps := 0.0
	var home := Vector2.ZERO
	var _frame := 0
	var _clock := 0.0

	func _ready() -> void:
		# Pixel art, and the project draws it NEAREST everywhere else.
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		# Top-left anchored, because every layer in a band is pinned by the SAME top edge.
		centered = false
		texture = frames[0]
		region_enabled = true
		region_rect = Rect2(0.0, 0.0, maxf(1.0, span.y - span.x), texture.get_height())
		scale = Vector2(1.0, plate_scale)
		position = home
		set_process(fps > 0.0 and frames.size() > 1)

	func _process(delta: float) -> void:
		_clock += delta
		var step := 1.0 / maxf(0.01, fps)
		if _clock < step:
			return
		_clock -= step
		_frame = (_frame + 1) % frames.size()
		texture = frames[_frame]
		# The region is cleared by a texture swap when the new frame is a different size,
		# so it is restated rather than assumed.
		region_rect = Rect2(0.0, 0.0, maxf(1.0, span.y - span.x), texture.get_height())
