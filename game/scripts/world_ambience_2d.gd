class_name WorldAmbience2D
extends Node2D
## The air. Motes, seed-fluff and leaves going past on the wind, everywhere, always.
##
## PAYYO WAS A PHOTOGRAPH. Every single thing on screen held perfectly still unless the
## player was touching it: the terraces, the trees, the water, the sky. A side-scroller made
## of static art reads as a picture you are walking across rather than a place you are in,
## and the fix for that is not more art -- it is one thing that never stops moving.
##
## THE CAMERA CARRIES IT. Particles authored into the level would be a fixed number of them
## in a fixed place, which at 5120 wide means either thousands of nodes or a level with
## weather in one corner. This follows the view and recycles: every mote that leaves the
## frame is re-seeded on the upwind side, so the density on screen is constant wherever the
## player is and the cost is a fixed sixty-odd rectangles.
##
## DRAWN, NOT SIMULATED. No physics, no GPUParticles, no textures -- three sine terms per
## mote and a whole-pixel position, which is the same idiom the ants, the sparks and the
## flame are drawn with and the only one that keeps the pixel grid.

## How many of each. Kept low: this is meant to be noticed the way you notice air, and a
## screenful of confetti is weather, which Payyo does not have.
const MOTES := 46
const LEAVES := 12
## How far outside the view they are seeded and recycled, so nothing pops in at the edge.
const MARGIN := 140.0
## The wind. Mostly east, because the level is walked east and dust going the other way reads
## as the player being pushed back.
const WIND := Vector2(26.0, 7.0)

## Tuned by LOOKING at it. At 0.5 the motes were only legible against the sky and vanished
## over the terraces, which is where the player actually is -- air you can only see in the
## top third of the screen is not air.
const MOTE := Color(1.0, 0.98, 0.878, 0.72)      # FFFAE0  sunlit dust
const MOTE_WARM := Color(1.0, 0.902, 0.647, 0.66)
const LEAF := Color(0.478, 0.639, 0.278, 0.95)   # 7AA347
const LEAF_DRY := Color(0.749, 0.573, 0.243, 0.95)

## [position, phase, speed, size]. Kept as plain arrays rather than nodes -- sixty Node2Ds
## that do nothing but hold two floats is sixty things for the scene tree to walk every frame.
var _motes: Array[Dictionary] = []
var _leaves: Array[Dictionary] = []
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _view := Vector2(1600.0, 900.0)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# In front of the terraces and behind the player, so dust passes over the ground and
	# never over the apo's face.
	z_index = 7
	# Seeded, so the air is the same air every run and a screenshot of it can be compared
	# with the last one. Same rule the pickup sparks and the gorge's rock follow.
	_rng.seed = 20260828
	_view = _view_size()
	for index in range(MOTES):
		_motes.append(_seed_mote(true))
	for index in range(LEAVES):
		_leaves.append(_seed_leaf(true))
	set_process(true)


func _seed_mote(anywhere: bool) -> Dictionary:
	return {
		"at": Vector2(_rng.randf_range(-MARGIN, _view.x + MARGIN) if anywhere else -MARGIN,
			_rng.randf_range(-MARGIN, _view.y + MARGIN)),
		"phase": _rng.randf_range(0.0, TAU),
		"speed": _rng.randf_range(0.55, 1.5),
		"size": 1.0 if _rng.randf() < 0.62 else 2.0,
		"warm": _rng.randf() < 0.4,
	}


func _seed_leaf(anywhere: bool) -> Dictionary:
	return {
		"at": Vector2(_rng.randf_range(-MARGIN, _view.x + MARGIN) if anywhere else -MARGIN,
			_rng.randf_range(-MARGIN, _view.y * 0.7)),
		"phase": _rng.randf_range(0.0, TAU),
		"speed": _rng.randf_range(0.7, 1.25),
		"spin": _rng.randf_range(1.4, 3.2),
		"dry": _rng.randf() < 0.45,
	}


func _process(delta: float) -> void:
	_time += delta
	_view = _view_size()
	for mote in _motes:
		# Two sines across the drift, so nothing travels in a straight line -- a mote on a
		# ruler is a bug flying, and a mote that wanders is air moving.
		var wander := Vector2(
			sin(_time * 0.7 + mote["phase"]) * 9.0,
			sin(_time * 1.3 + mote["phase"] * 1.7) * 13.0)
		mote["at"] += (WIND * float(mote["speed"]) + wander * 0.06) * delta
		if not _inside(mote["at"]):
			var fresh := _seed_mote(false)
			mote["at"] = fresh["at"]
	for leaf in _leaves:
		# A leaf falls and swings; it does not drift like dust.
		leaf["at"] += Vector2(
			WIND.x * float(leaf["speed"]) + sin(_time * float(leaf["spin"]) + leaf["phase"]) * 22.0,
			30.0 * float(leaf["speed"])) * delta
		if not _inside(leaf["at"]):
			var fresh := _seed_leaf(false)
			leaf["at"] = fresh["at"]
	queue_redraw()


## HOW MUCH WORLD THE CAMERA CAN SEE, which is not the size of the window.
##
## This node hangs off the Camera2D so that "where a mote is on screen" and "where it is in
## this node's space" are the same question -- but the camera zooms: 1 out on the terraces,
## 2 inside the heap, 3 inside the house. Measuring in window pixels would put the air three
## times too wide in Ang Bale and recycle every mote the instant it was seeded.
func _view_size() -> Vector2:
	var camera := get_parent() as Camera2D
	var zoom := camera.zoom if camera != null else Vector2.ONE
	return get_viewport_rect().size / Vector2(maxf(0.01, zoom.x), maxf(0.01, zoom.y))


func _inside(at: Vector2) -> bool:
	return at.x > -MARGIN * 1.5 and at.x < _view.x + MARGIN * 1.5 \
		and at.y > -MARGIN * 1.5 and at.y < _view.y + MARGIN * 1.5


## Everything here is in VIEW space -- the node is parked on the camera, so a mote's position
## is where it is on screen and the world scrolling past underneath is what makes it drift.
func _draw() -> void:
	# The camera's own origin is the MIDDLE of what it can see, and everything above is
	# measured from the top-left corner of it.
	draw_set_transform(-_view * 0.5, 0.0, Vector2.ONE)
	for mote in _motes:
		var at: Vector2 = Vector2(mote["at"]).floor()
		# A shadow pixel under the bright one, so a mote stays legible over pale straw and
		# bright grass as well as against the sky.
		var size := float(mote["size"])
		# Breathing alpha, so the specks read as catching the light rather than as dead pixels.
		var glint := 0.55 + 0.45 * sin(_time * 2.1 + float(mote["phase"]))
		var tone: Color = MOTE_WARM if bool(mote["warm"]) else MOTE
		draw_rect(Rect2(at + Vector2(1.0, 1.0), Vector2(size, size)),
			Color(0.13, 0.12, 0.09, 0.28 * glint))
		draw_rect(Rect2(at, Vector2(size, size)), Color(tone, tone.a * glint))
	for leaf in _leaves:
		var at: Vector2 = Vector2(leaf["at"]).floor()
		# The swing turns the leaf edge-on and back, which at this size is a width change
		# from three pixels to one. Cheaper than a rotation and it reads better.
		var wide := 1.0 + roundf(absf(sin(_time * float(leaf["spin"]) + float(leaf["phase"]))) * 2.0)
		var tone: Color = LEAF_DRY if bool(leaf["dry"]) else LEAF
		draw_rect(Rect2(at + Vector2(1.0, 1.0), Vector2(wide, 2.0)),
			Color(0.13, 0.12, 0.09, 0.3))
		draw_rect(Rect2(at, Vector2(wide, 2.0)), tone)
		draw_rect(Rect2(at + Vector2(0.0, 2.0), Vector2(maxf(1.0, wide - 1.0), 1.0)),
			Color(tone, tone.a * 0.6))
