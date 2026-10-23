class_name LanternHud
extends Control
## The lantern on the ink plate: the flame she has left, where a level counts it as her health.
##
## A little lantern drawn from the checkpoint lantern's own pixel rows, and four soft flame pips
## beside it -- full, dim, low, guttering. Three cues, kept apart on purpose:
## - a HIT shakes the row and edges it red for a moment. Red is used for nothing else, because a
##   blow is the one thing here that is her loss.
## - `lean()` sways the lantern away from something close (the tik-tik) -- never red.
## - `gutter()` makes the lit pips flutter while something pulls the light down -- never red.

const GLYPH_SCALE := 2
const PIP := Vector2(12.0, 18.0)
const PIP_GAP := 6.0
const GAP := 10.0
const SHAKE_TIME := 0.35
const SHAKE_PX := 3.0
const RED_TIME := 0.5
const HIT_RED := Color(0.93, 0.27, 0.22)
const LIT := UISkin.PENDING
const LIT_CORE := Color(1.0, 0.95, 0.78)
## A spent pip is an empty slot, not nothing: dark inside, with an outline that still reads on the
## plate, so "one left of four" is counted at a glance.
const SPENT := Color(0.027, 0.035, 0.024, 0.75)
const SPENT_EDGE := Color(0.808, 0.757, 0.612, 0.5)

var health: PlayerHealth = null

var _shake := 0.0
var _red := 0.0
var _lean := 0.0
var _gutter := 0.0
var _clock := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(_glyph_size().x + GAP + PIP.x * 4.0 + PIP_GAP * 3.0,
		maxf(_glyph_size().y, PIP.y))


## The stage it last showed, so it can tell brighter from dimmer.
var _last_stage := PlayerHealth.FULL

func bind(source: PlayerHealth) -> void:
	health = source
	_last_stage = health.stage
	# Brighter -- oil, a clearing's fire -- it pops; dimmer, hit() has already shaken it.
	health.stage_changed.connect(func(stage: int) -> void:
		if stage > _last_stage:
			Motion.pulse(self)
		_last_stage = stage
		queue_redraw())
	health.hit_taken.connect(func(_stage: int) -> void: hit())
	queue_redraw()


func stage() -> int:
	return health.stage if health != null else PlayerHealth.FULL


## A blow landed: shake, and the red edge.
func hit() -> void:
	_shake = SHAKE_TIME
	_red = RED_TIME
	queue_redraw()


## Something close is pulling at the flame: the lantern leans away, 0 (not at all) to 1.
func lean(amount: float) -> void:
	_lean = clampf(amount, 0.0, 1.0)
	queue_redraw()


## The light is being dragged down for `seconds`: the lit pips flutter.
func gutter(seconds: float) -> void:
	_gutter = maxf(_gutter, seconds)


func is_shaking() -> bool:
	return _shake > 0.0


func red_edge() -> float:
	return _red / RED_TIME


func is_guttering() -> bool:
	return _gutter > 0.0


func _process(delta: float) -> void:
	_clock += delta
	_shake = maxf(0.0, _shake - delta)
	_red = maxf(0.0, _red - delta)
	_gutter = maxf(0.0, _gutter - delta)
	if _shake > 0.0 or _red > 0.0 or _gutter > 0.0 or _lean > 0.0 or stage() <= PlayerHealth.GUTTERING:
		queue_redraw()


func _draw() -> void:
	var jitter := sin(_clock * 70.0) * SHAKE_PX * (_shake / SHAKE_TIME)
	var glyph := _glyph_size()
	var top := (size.y - glyph.y) * 0.5
	# The lantern, swinging from its ring when something leans on it.
	draw_set_transform(Vector2(jitter + glyph.x * 0.5, top), -_lean * 0.35, Vector2.ONE)
	_draw_lantern(Vector2(-glyph.x * 0.5, 0.0))
	draw_set_transform(Vector2(jitter, 0.0), 0.0, Vector2.ONE)
	var x := glyph.x + GAP
	var pip_top := (size.y - PIP.y) * 0.5
	for index in range(PlayerHealth.FULL):
		var lit := index < stage()
		var colour := LIT if lit else SPENT
		if lit and (_gutter > 0.0 or stage() <= PlayerHealth.GUTTERING):
			colour.a = 0.55 + 0.45 * absf(sin(_clock * 9.0 + index))
		var box := StyleBoxFlat.new()
		box.bg_color = colour
		box.border_color = UISkin.KEYLINE if lit else SPENT_EDGE
		box.set_border_width_all(1)
		draw_style_box(UISkin.rounded(box, int(PIP.x * 0.5)), Rect2(x, pip_top, PIP.x, PIP.y))
		if lit:
			draw_circle(Vector2(x + PIP.x * 0.5, pip_top + PIP.y * 0.62), PIP.x * 0.18, LIT_CORE)
		x += PIP.x + PIP_GAP
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _red > 0.0:
		var edge := StyleBoxFlat.new()
		edge.draw_center = false
		edge.border_color = Color(HIT_RED, red_edge())
		edge.set_border_width_all(2)
		draw_style_box(UISkin.rounded(edge, UISkin.KEY_RADIUS), Rect2(Vector2(-4.0, -3.0),
			size + Vector2(8.0, 6.0)))


func _draw_lantern(origin: Vector2) -> void:
	var rows: Array = CheckpointLantern2D.LANTERN_ROWS
	var palette: Dictionary = CheckpointLantern2D.LANTERN_PALETTE.duplicate()
	if stage() > 0:
		palette.merge(CheckpointLantern2D.LANTERN_ALIGHT, true)
	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(row.length()):
			var key := row[x]
			if palette.has(key):
				draw_rect(Rect2(origin + Vector2(x, y) * GLYPH_SCALE,
					Vector2.ONE * GLYPH_SCALE), palette[key])


static func _glyph_size() -> Vector2:
	var rows: Array = CheckpointLantern2D.LANTERN_ROWS
	return Vector2(String(rows[0]).length(), rows.size()) * GLYPH_SCALE
