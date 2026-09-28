class_name DagatProp2D
extends Sprite2D
## One piece of Dagat's scenery: a coral, a frond of kelp, a column of bubbles, a school of
## fish, or the ink jar on the seabed. Each is a short loop, and the loop is the whole point --
## a still underwater level reads as a photograph of one.
##
## ⚠ FRAMES ARE FOUND BY PREFIX, NOT LISTED. The delivered sets are numbered from zero by
## tools/build_dagat.py and the authored jar by tools/build_dagat_props.py, so
## "res://assets/Level3/props/kelp_long" and "res://assets/Level3/props/ink_jar" resolve the
## same way and a set that grows a fourth frame needs no scene edit.
##
## SIZED BY HEIGHT, because that is what a designer measures against a seabed: the delivered
## props are around 1200px on their long side and want to be around a hundred in the world.

@export var prefix: String = ""
@export var fps: float = 2.0
@export var target_height: float = 130.0
## Every frond in a bed moving in lockstep is a bed nobody believes. Set per instance.
@export var phase: int = 0
## Kelp leans, coral does not. A little horizontal variety without needing more art.
@export var mirrored: bool = false
## Half the width of the shadow it casts on the ground under its foot, in world pixels. ZERO
## casts none: a school of fish or a column of bubbles is not standing on anything. See
## ground_shadow.gd -- without one, everything on the seabed read as pasted onto the picture.
##
## ⚠ AND A THING WITH A SHADOW STANDS ON ITS FOOT, NOT ON ITS PICTURE'S BOTTOM EDGE. The
## delivered corals carry a faint halo under their stems -- 15 to 20 per cent of the picture's
## height with nothing solid in it -- so anchored by the picture's edge, every coral on the bed
## stood fifteen to twenty-two pixels above the sand, on nothing. It did not show while the
## seabed was a lumpy painted band; on a flat floor with a shadow under each piece it was the
## first thing you saw. See _foot_margin.
@export var shadow_width: float = 0.0

## Rows of picture under each texture's lowest solid row, by path. Measured once per texture
## per run, not per prop.
static var _feet := {}

var _frames: Array[Texture2D] = []
var _frame := 0
var _clock := 0.0


func _ready() -> void:
	# ⚠ OFF FIRST. A script that defines _process has processing ENABLED by default, so the
	# early return below left it running against an empty frame list -- one "modulo by zero"
	# per frame, per prop, for the life of the level.
	set_process(false)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Anchored at the FOOT: scenery stands on a seabed, and centring it buries half of each
	# piece or floats it, depending on how tall the piece happens to be.
	centered = false
	_frames = _load_frames()
	if _frames.is_empty():
		push_warning("DagatProp2D: no frames for '%s'" % prefix)
		return
	_frame = phase % _frames.size()
	texture = _frames[_frame]
	flip_h = mirrored
	var native := maxf(1.0, float(texture.get_height()))
	var factor := target_height / native
	scale = Vector2.ONE * factor
	var margin := 0.0
	if shadow_width > 0.0:
		for frame in _frames:
			margin = maxf(margin, _foot_margin(frame))
	offset = Vector2(-float(texture.get_width()) * 0.5, -native + margin)
	if shadow_width > 0.0:
		var shadow := _FootShadow.new()
		shadow.name = "Shadow"
		shadow.half_width = shadow_width
		# Behind the sprite, at its foot, and in world pixels rather than the sprite's own.
		shadow.show_behind_parent = true
		shadow.scale = Vector2.ONE / factor
		add_child(shadow)
	set_process(_frames.size() > 1 and fps > 0.0)


## How far above the picture's bottom edge its lowest SOLID row is. Read off a copy shrunk
## eight times with nearest sampling, which keeps any stem wider than eight texels and costs a
## few thousand reads instead of a million; a frond or a coral stem is fifty wide.
static func _foot_margin(texture: Texture2D) -> float:
	var key := texture.resource_path
	if _feet.has(key):
		return float(_feet[key])
	var margin := 0.0
	var image := texture.get_image()
	if image != null:
		if image.is_compressed():
			image.decompress()
		const STEP := 8
		var small := Image.create_from_data(image.get_width(), image.get_height(), false,
			image.get_format(), image.get_data())
		small.resize(maxi(1, image.get_width() / STEP), maxi(1, image.get_height() / STEP),
			Image.INTERPOLATE_NEAREST)
		var rows := small.get_height()
		for y in range(rows - 1, -1, -1):
			var solid := false
			for x in range(small.get_width()):
				if small.get_pixel(x, y).a > 0.5:
					solid = true
					break
			if solid:
				margin = float(rows - 1 - y) * float(image.get_height()) / float(rows)
				break
	_feet[key] = margin
	return margin


func _load_frames() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for index in range(32):
		var path := "%s_%d.png" % [prefix, index]
		if not ResourceLoader.exists(path):
			break
		var texture := load(path) as Texture2D
		if texture != null:
			out.append(texture)
	return out


func _process(delta: float) -> void:
	_clock += delta
	var step := 1.0 / maxf(0.01, fps)
	if _clock < step:
		return
	_clock -= step
	_frame = (_frame + 1) % _frames.size()
	texture = _frames[_frame]


class _FootShadow extends Node2D:
	const GroundShadow = preload("res://scripts/ground_shadow.gd")
	var half_width := 20.0

	func _draw() -> void:
		GroundShadow.draw(self, half_width, maxf(2.0, roundf(half_width * 0.14)), 0.5)
