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
	offset = Vector2(-float(texture.get_width()) * 0.5, -native)
	set_process(_frames.size() > 1 and fps > 0.0)


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
