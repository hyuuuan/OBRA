class_name AshFall2D
extends Node2D
## Mayon's ash, falling. The thing the player watches take the world, so it is always there in
## Acts One and Two, thicker the higher she climbs, and gone at the summit.
##
## Built the way WorldAmbience2D is, and for its reasons: hung on the camera, so a flake's
## position is where it is on screen and the world scrolling underneath is what makes it drift;
## recycled at the top as it leaves the bottom, so the cost is a fixed number of rectangles
## wherever she is; seeded, so a screenshot can be compared with the last one; whole pixels,
## like everything else drawn in code. `density` says how many of the flakes are falling.
##
## `pulse()` is the eruption's visual twin (every sound has one -- Dilim's rule): the tremor
## calls it, and for a moment the ash falls harder and thicker.

## Tuned by LOOKING at it: 150 one- and two-pixel flakes the colour of dusk were invisible
## against the sunset sky -- ash nobody can see is not the thing taking the world.
const FLAKES := 240
## How far outside the view a flake is seeded and recycled, so nothing pops in at an edge.
const MARGIN := 120.0
## The fall: down, and drifting back down the mountain -- she climbs east, so the ash blows west.
const FALL := Vector2(-16.0, 46.0)
## A pulse decays at this rate per second.
const PULSE_FADE := 1.4
const ASH := Color(0.36, 0.34, 0.33, 0.85)
const ASH_PALE := Color(0.88, 0.87, 0.84, 0.85)

## How much of the ash is falling: 0 none, 1 all of it.
@export_range(0.0, 1.0) var density: float = 0.3

## [at, phase, speed, size, pale]
var _flakes: Array[Dictionary] = []
var _time := 0.0
var _pulse := 0.0
var _rng := RandomNumberGenerator.new()
var _view := Vector2(1600.0, 900.0)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Over the ground and the props, under the apo: ash passes over the world and never over her
	# face.
	z_index = 7
	_rng.seed = 20261025
	_view = _view_size()
	for index in range(FLAKES):
		_flakes.append(_seed(true))


## How many flakes are falling now.
func falling() -> int:
	var share := clampf(density + _pulse * 0.35, 0.0, 1.0)
	return int(roundf(FLAKES * share))


## The eruption: harder and thicker for a moment.
func pulse(strength: float = 1.0) -> void:
	_pulse = maxf(_pulse, clampf(strength, 0.0, 1.0))


func pulse_left() -> float:
	return _pulse


## Where every falling flake is, in view space (for a probe).
func flake_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for index in range(falling()):
		out.append(Vector2(_flakes[index]["at"]))
	return out


func view_size() -> Vector2:
	return _view


func _seed(anywhere: bool) -> Dictionary:
	return {
		"at": Vector2(_rng.randf_range(-MARGIN, _view.x + MARGIN),
			_rng.randf_range(-MARGIN, _view.y + MARGIN) if anywhere else -MARGIN),
		"phase": _rng.randf_range(0.0, TAU),
		"speed": _rng.randf_range(0.6, 1.4),
		"size": 2.0 if _rng.randf() < 0.6 else 3.0,
		"pale": _rng.randf() < 0.45,
	}


func _process(delta: float) -> void:
	_time += delta
	_view = _view_size()
	_pulse = maxf(0.0, _pulse - PULSE_FADE * delta)
	var hurry := 1.0 + _pulse * 1.6
	for index in range(falling()):
		var flake: Dictionary = _flakes[index]
		# A flake flutters across its fall; one on a ruler reads as rain.
		var flutter := Vector2(sin(_time * 1.7 + float(flake["phase"])) * 10.0, 0.0)
		flake["at"] += (FALL * float(flake["speed"]) * hurry + flutter) * delta
		if not _inside(flake["at"]):
			var fresh := _seed(false)
			flake["at"] = fresh["at"]
	queue_redraw()


## HOW MUCH WORLD THE CAMERA CAN SEE, not the size of the window -- see WorldAmbience2D.
func _view_size() -> Vector2:
	var camera := get_parent() as Camera2D
	var zoom := camera.zoom if camera != null else Vector2.ONE
	return get_viewport_rect().size / Vector2(maxf(0.01, zoom.x), maxf(0.01, zoom.y))


func _inside(at: Vector2) -> bool:
	return at.x > -MARGIN * 1.5 and at.x < _view.x + MARGIN * 1.5 \
		and at.y > -MARGIN * 1.5 and at.y < _view.y + MARGIN * 1.5


func _draw() -> void:
	draw_set_transform(-_view * 0.5, 0.0, Vector2.ONE)
	for index in range(falling()):
		var flake: Dictionary = _flakes[index]
		var at: Vector2 = Vector2(flake["at"]).floor()
		var size := float(flake["size"])
		draw_rect(Rect2(at, Vector2(size, size)), ASH_PALE if bool(flake["pale"]) else ASH)
