class_name LanternHud
extends Control
## The lantern on the ink plate: the flame she has left, where a level counts it as her health.
##
## The checkpoint lantern's own pixel rows, big enough to read at a glance, and nothing beside
## it: the lantern IS the count. Its capiz shells warm from cold grey to lit gold with the stage,
## the pixel flame inside stands four rows tall when full and shortens a row each stage down, and
## a stepped pixel glow round it fades with it. (Kent, 2026-10-30: the old round pips were "not
## pixelated and designed well".) Three cues, kept apart on purpose:
## - a HIT shakes the row and edges it red for a moment. Red is used for nothing else, because a
##   blow is the one thing here that is her loss.
## - `lean()` sways the lantern away from something close (the tik-tik) -- never red.
## - `gutter()` makes the flame flutter while something pulls the light down -- never red.

const GLYPH_SCALE := 3
## The flame inside, art pixels, bottom row first: o orange, y gold, w white-hot core.
const FLAME_ROWS := [".ooo.", "oywyo", ".ywy.", "..y.."]
const FLAME_COLOURS := {"o": Color(0.89, 0.42, 0.13), "y": Color(1.0, 0.8, 0.29), "w": Color(1.0, 0.97, 0.85)}
## Where the flame's bottom row sits in the lantern's art pixels, and its left edge.
const FLAME_BASE := Vector2(4.0, 12.0)
## The stepped glow: rings this many art pixels out, each fainter.
const GLOW_RINGS := 3
const SHAKE_TIME := 0.35
const SHAKE_PX := 3.0
const RED_TIME := 0.5
const HIT_RED := Color(0.93, 0.27, 0.22)
const LIT := UISkin.PENDING
## A spent pip is an empty slot, not nothing: dark inside, with an outline that still reads on the
## plate, so "one left of four" is counted at a glance.

var health: PlayerHealth = null

var _shake := 0.0
var _red := 0.0
var _lean := 0.0
var _gutter := 0.0
var _clock := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var halo := Vector2.ONE * GLOW_RINGS * GLYPH_SCALE * 2.0
	custom_minimum_size = glyph_size() + halo


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
	var jitter := roundf(sin(_clock * 70.0) * SHAKE_PX * (_shake / SHAKE_TIME))
	var glyph := glyph_size()
	var origin := ((size - glyph) * 0.5).round()
	var lit := float(stage()) / float(PlayerHealth.FULL)
	var flicker := 1.0
	if stage() > 0 and (_gutter > 0.0 or stage() <= PlayerHealth.GUTTERING):
		flicker = 0.6 + 0.4 * absf(sin(_clock * 9.0))
	# The glow: whole-pixel rings, square-stepped, fainter outward and with the stage.
	for ring in range(GLOW_RINGS, 0, -1):
		var grow := float(ring * GLYPH_SCALE)
		var alpha := 0.10 * lit * flicker * (1.0 - float(ring - 1) / float(GLOW_RINGS))
		if alpha > 0.0:
			draw_rect(Rect2(origin - Vector2.ONE * grow + Vector2(jitter, GLYPH_SCALE * 3.0),
				glyph + Vector2.ONE * grow * 2.0 - Vector2(0.0, GLYPH_SCALE * 6.0)),
				Color(LIT, alpha))
	# The lantern, swinging from its ring when something leans on it.
	draw_set_transform(origin + Vector2(jitter + glyph.x * 0.5, 0.0), -_lean * 0.35, Vector2.ONE)
	paint(self, Vector2(-glyph.x * 0.5, 0.0), GLYPH_SCALE, stage(), flicker)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _red > 0.0:
		var edge := StyleBoxFlat.new()
		edge.draw_center = false
		edge.border_color = Color(HIT_RED, red_edge())
		edge.set_border_width_all(2)
		draw_style_box(UISkin.rounded(edge, UISkin.KEY_RADIUS), Rect2(Vector2(-4.0, -3.0),
			size + Vector2(8.0, 6.0)))


## The lantern at `stage` (0 to PlayerHealth.FULL), its top-left at `origin`, each art pixel
## `scale` px: cold shells warmed toward lit gold by how much flame is left, and the flame, a row
## shorter for each stage down, gone at none. On any canvas, so a lesson's picture shows the very
## lamp the HUD does.
static func paint(canvas: CanvasItem, origin: Vector2, scale: int, stage: int, flicker := 1.0) -> void:
	var lit := float(stage) / float(PlayerHealth.FULL)
	var rows: Array = CheckpointLantern2D.LANTERN_ROWS
	var cold: Dictionary = CheckpointLantern2D.LANTERN_PALETTE
	var warm: Dictionary = CheckpointLantern2D.LANTERN_ALIGHT
	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(row.length()):
			var key := row[x]
			if not cold.has(key):
				continue
			var colour: Color = cold[key]
			if warm.has(key):
				colour = colour.lerp(warm[key], lit * flicker)
			canvas.draw_rect(Rect2(origin + Vector2(x, y) * scale, Vector2.ONE * scale), colour)
	var tall := mini(stage, FLAME_ROWS.size())
	for index in range(tall):
		var row: String = FLAME_ROWS[index]
		for x in range(row.length()):
			if FLAME_COLOURS.has(row[x]):
				var colour: Color = FLAME_COLOURS[row[x]]
				colour.a = flicker
				canvas.draw_rect(Rect2(origin + (FLAME_BASE + Vector2(x, -index)) * scale,
					Vector2.ONE * scale), colour)


## How big the lantern is with each art pixel `scale` px.
static func glyph_size(scale: int = GLYPH_SCALE) -> Vector2:
	var rows: Array = CheckpointLantern2D.LANTERN_ROWS
	return Vector2(String(rows[0]).length(), rows.size()) * scale
