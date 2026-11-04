class_name FanWind2D
extends Node2D
## The wind out of the front of a drawn fan while it is on.
##
## A switched-on fan used to look exactly like a switched-off one -- the ink in her hand, a
## line of text, and things in front of it moving for no reason anyone could see (Kent: "when
## i draw a fan, there should be like a wind that comes out to it"). These are Mayon's gusts
## (wind_streaks_2d.gd: the same sheet, columns and frames), carried out along the fan's own
## wind from its blades to its reach, so the stream on screen is the stream that pushes:
## UtilityObject.in_the_wind is asked of the same origin, axis, reach and spread drawn here.
##
## Driven by its fan (`advance`), not by its own clock, so it can never show a wind the fan is
## not blowing. It sits on its own world-following layer OVER THE DARK (DarknessLayer is 3, the
## HUD 5), the placement guides' layer: in Dilim it is seen past her lamp, and it is not a light
## -- it cuts nothing out of the dark and LightField never counts it.
##
## Pixel motion like everything else (Motion): positions on whole pixels, held at PIXEL_FPS,
## fades in eighths. Under reduced motion the gusts stand still where they are, so the wind still
## says which way and how far, and nothing travels.

const Streaks := preload("res://scripts/wind_streaks_2d.gd")
const GUSTS := 4
## Where each gust runs across the stream, -1 (one edge) to 1 (the other).
const LANES := [-0.5, 0.4, -0.05, 0.7]
## How fast a gust travels out, px/s: a held fan is a breeze, not a storm.
const SPEED := 260.0
## A gust is never shorter-lived than this, however short the reach.
const SHORTEST_LIFE := 0.45
## How solid a gust is at its fullest.
const OPACITY := 0.875
## ⚠ A CREAM GUST VANISHES OVER PAYYO'S RIPE TERRACES. Each one has a soft dark shade a step
## under it, the way the ink has its halo: it is what reads on a bright field, and over the dark
## it is dark on dark and costs nothing.
const SHADE := Color(0.1, 0.12, 0.1)
const SHADE_OPACITY := 0.5
const SHADE_DROP := Vector2(0.0, 2.0)
## Coming on and going off.
const FADE_SECONDS := 0.2
## A gust is this share of its stream's length, so two or three are always out at once.
const GUST_SHARE := 0.5
## Under reduced motion, where along the stream each gust stands.
const STILL_AT := [0.15, 0.55, 0.85, 0.35]

var _gusts: Array[Sprite2D] = []
var _shades: Array[Sprite2D] = []
var _clock := 0.0
var _frame := -1
## 0 (off) to 1 (on), stepped in eighths.
var _shown := 0.0
var _origin := Vector2.ZERO
var _axis := Vector2.RIGHT
var _front := 0.0
var _reach := 0.0
var _base := 0.0
var _spread := 0.0


## A wind for `fan`, on its own layer over the dark, made once and kept.
static func make_for(fan: Node) -> FanWind2D:
	var layer := CanvasLayer.new()
	layer.name = "WindLayer"
	layer.layer = DarknessLayer.LAYER + 1
	layer.follow_viewport_enabled = true
	fan.add_child(layer)
	var wind := FanWind2D.new()
	wind.name = "Wind"
	layer.add_child(wind)
	return wind


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Every shade first, so no gust is ever under another gust's shade.
	for list in [_shades, _gusts]:
		for index in range(GUSTS):
			var sprite := Sprite2D.new()
			sprite.name = "%s%d" % ["Shade" if is_same(list, _shades) else "Gust", index + 1]
			sprite.texture = Streaks.ART
			sprite.hframes = Streaks.COLUMNS
			sprite.vframes = Streaks.FRAMES
			sprite.hide()
			add_child(sprite)
			list.append(sprite)


## One frame of the wind. `blowing` is whether the fan is on; the rest is its stream, in world
## px: from `origin` (the hub) along `axis` (unit), gusts from `front` out to `reach`, `base` wide
## either side at the blades and widening by `spread` per px out.
func advance(delta: float, blowing: bool, origin: Vector2, axis: Vector2, front: float,
		reach: float, base: float, spread: float) -> void:
	_origin = origin
	_axis = axis.normalized() if axis != Vector2.ZERO else Vector2.RIGHT
	_front = front
	_reach = maxf(reach, front)
	_base = base
	_spread = spread
	var want := 1.0 if blowing else 0.0
	if _shown != want:
		var fade := move_toward(_shown, want, delta / FADE_SECONDS)
		# Snapped up as it comes on and down as it goes, so a quick tap still shows a step.
		_shown = (ceilf(fade * Motion.ALPHA_STEPS) if want > _shown else floorf(fade * Motion.ALPHA_STEPS)) \
			/ Motion.ALPHA_STEPS
	if _shown > 0.0 and not Motion.reduced():
		_clock += delta
	# How far each gust has travelled is held at PIXEL_FPS; where the stream starts is not --
	# it is pinned to the fan, and a fan in a walking hand moves between held frames.
	_frame = floori(_clock * Motion.PIXEL_FPS)
	_place_gusts()


## How on the wind is, 0 to 1 (in eighths), for a probe.
func shown() -> float:
	return _shown


## The gusts on screen now, for a probe: each one's world position, whether it is drawn
## flipped, and how solid it is.
func gusts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for gust in _gusts:
		if gust.visible:
			out.append({"position": gust.global_position, "flip_h": gust.flip_h,
				"alpha": gust.modulate.a})
	return out


func _place_gusts() -> void:
	var still := Motion.reduced()
	var length := _reach - _front
	var cell := Streaks.ART.get_size() / Vector2(Streaks.COLUMNS, Streaks.FRAMES)
	var wide := maxf(1.0, length * GUST_SHARE)
	var scale_by := roundf(wide / cell.x * Motion.SCALE_STEPS) / Motion.SCALE_STEPS
	var gust_width := cell.x * scale_by
	var run := maxf(0.0, length - gust_width)
	var life := maxf(SHORTEST_LIFE, length / SPEED)
	var clock := float(maxi(0, _frame)) / Motion.PIXEL_FPS
	for index in range(_gusts.size()):
		var gust := _gusts[index]
		var shade := _shades[index]
		if _shown <= 0.0 or length <= 0.0:
			gust.hide()
			shade.hide()
			continue
		var progress: float
		var pass_index := 0
		if still:
			progress = STILL_AT[index]
		else:
			var elapsed := clock + life * float(index) / float(_gusts.size())
			pass_index = floori(elapsed / life)
			progress = fposmod(elapsed, life) / life
		var along := _front + gust_width * 0.5 + run * progress
		# Inside the stream: a gust's lane is a share of the stream's half-width where it is.
		var half := _base + (along - _front) * _spread
		var across := float(LANES[index]) * maxf(0.0, half - cell.y * scale_by * 0.5)
		var side := Vector2(-_axis.y, _axis.x)
		gust.global_position = (_origin + _axis * along + side * across).round()
		gust.scale = Vector2.ONE * scale_by
		# The sheet blows to the left (Mayon's weather comes from the east).
		gust.flip_h = _axis.x > 0.0
		var variant := posmod(index + pass_index * 2, Streaks.COLUMNS)
		var frame := Streaks.FRAMES - 1 if still else mini(Streaks.FRAMES - 1, int(progress * Streaks.FRAMES))
		gust.frame = frame * Streaks.COLUMNS + variant
		var fade := 1.0 if still else smoothstep(0.0, 0.18, progress) * (1.0 - smoothstep(0.7, 1.0, progress))
		gust.modulate.a = roundf(fade * OPACITY * _shown * Motion.ALPHA_STEPS) / Motion.ALPHA_STEPS
		gust.visible = gust.modulate.a > 0.0
		shade.position = gust.position + SHADE_DROP
		shade.scale = gust.scale
		shade.flip_h = gust.flip_h
		shade.frame = gust.frame
		shade.modulate = Color(SHADE, roundf(gust.modulate.a * SHADE_OPACITY * Motion.ALPHA_STEPS)
			/ Motion.ALPHA_STEPS)
		shade.visible = gust.visible
