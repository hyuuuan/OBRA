class_name Kapre2D
extends Node2D
## The kapre: up its tree, smoking, keeping to itself -- and its smoke turns travellers round
## (Kent's design: "ground the loop in the smoke ... a visible cause the player can act on").
##
## What it is, the level asks about: the smoke bank west of its tree (SMOKE_WIDTH px, ending at the
## trunk) until it is cleared; its cigar, up the tree at CIGAR_TIP, which is a small light and a target --
## anything thrown that reaches it knocks it out of its hand (cigar_knocked); and its tree, which
## falls after CHOPS_TO_FELL chops. Which of those answers the encounter is the level's to judge.
## Answered any way, the smoke is gone; felled or knocked, the kapre leaves.

signal cigar_knocked

const SMOKE_WIDTH := 600.0
## Where its cigar's tip is drawn (tools/dilim_kapre.py CIGAR_TIP), in its teeth up the tree: the
## cigar's hit area and its light are there, so a click on the cigar is a click on the cigar.
const CIGAR_TIP := Vector2(-122.0, -280.0)
const CHOPS_TO_FELL := 3
const TRUNK := Vector2(70.0, 340.0)
## How far its ember lights, and which way: enough that its face -- 56 px off the tip -- is in the
## full light (LightField.SOFT_EDGE of it) and shows in the dark; and back over that face and the
## tree behind it, a cone, not out into the open air west of it, where a round light 280 px up
## opened a window onto the backdrop's sky.
const CIGAR_GLOW := 110.0
const CIGAR_LIGHT_TOWARD := Vector2(1.0, -0.1)
const CIGAR_LIGHT_HALF_ANGLE := 1.05
## Where its drawn strip stands in the tree (tools/dilim_kapre.py ART_AT): the bottom-centre of the
## frame, which is its hanging foot, sat on the balete's branch.
const ART_AT := Vector2(-68.0, -110.0)
const FADE_SECONDS := 1.0
const BARK := Color(0.16, 0.11, 0.08)
const HIDE := Color(0.08, 0.07, 0.06)
const SMOKE := Color(0.72, 0.72, 0.74)
const EMBER := Color(1.0, 0.55, 0.18)

## Its smoke, drawn (kapre_smoke_idle, tools/dilim_kapre.py: PUFFS puffs, PUFF px square -- four
## billows, then a middling and a small one); the discs in _draw stand in only while there is none.
const PUFF := 96
const PUFFS := 6
## The bank over the path -- billows over a haze as high as HAZE -- and the thread of it off the
## cigar that comes down into it at STREAM_TO, growing as it comes.
const BANK_PUFFS := 34
const HAZE := 150.0
const SMOKE_TONE := Color(0.5, 0.48, 0.46)
const STREAM_PUFFS := 12
const STREAM_TO := Vector2(-250.0, -120.0)
## Blown clear -- by a fan, a cloud, a sun, her as a butterfly -- the smoke goes this far, east past
## the tree and up, as it thins; cleared any other way, it thins where it is.
const BLOWN_AWAY := Vector2(260.0, -100.0)
## Knocked out of its mouth, the cigar (kapre_cigar_idle) tumbles down to the ground below, thrown
## out west, sparks trailing off it -- FALL_GRAVITY px/s², FALL_THROW px/s -- and lies there LIES_AT
## px up, its ember a small light (FALLEN_GLOW) until it dies EMBER_DIES seconds after it lands.
const FALL_GRAVITY := 900.0
const FALL_THROW := -60.0
const LIES_AT := -4.0
const FALLEN_GLOW := 46.0
const EMBER_DIES := 2.5
## Leaving, startled: with its cigar knocked away ('knocked') it climbs CLIMBS px up into its crown
## and is lost in it; with its tree gone under it ('falling', the cigar still in its teeth) it drops
## to the ground, its ember lighting it down, and walks off east into the dark.
const CLIMBS := 90.0
const CLIMB_SECONDS := 1.4
const DROP_SECONDS := 0.4
const WALKS_OFF := 50.0
const WALK_SECONDS := 0.9

var _smoke := 1.0
var _smoke_sheet: Texture2D
var _blown := false
var _cigar_art: Texture2D
var _fall_clock := -1.0
var _chops := 0
var _felled := false
var _cigar_lit := true
var _gone := false
var _clock := 0.0
var cigar: Area2D


## The balete it sits in, drawn (kapre_tree_idle / kapre_tree_felled); the code's tree below stands
## in only while there is none.
var tree_art: PixelStripAnimator

## Its strips (tools/build_dilim_creatures.py, or drawn art under the same names); the code-drawn
## body below stands in only while there are none.
var art: PixelStripAnimator


func _make_art(kind: String, anims: Array, centre: bool, at: Vector2) -> void:
	art = PixelStripAnimator.new()
	art.name = "Art"
	art.centre = centre
	art.position = at
	add_child(art)
	art.load_kind(Enemy2D.ART, kind, anims)
	art.play("idle")


func _ready() -> void:
	# Its balete first, behind the kapre and the smoke: standing, or felled once it is down.
	tree_art = PixelStripAnimator.new()
	tree_art.name = "TreeArt"
	tree_art.z_index = -1
	add_child(tree_art)
	tree_art.load_kind(Enemy2D.ART, "kapre_tree", ["idle", "felled"])
	tree_art.play("idle")
	_make_art("kapre", ["idle", "knocked", "falling"], false, ART_AT)
	var puffs := Enemy2D.ART + "kapre_smoke_idle.png"
	if ResourceLoader.exists(puffs):
		_smoke_sheet = load(puffs) as Texture2D
	var dropped := Enemy2D.ART + "kapre_cigar_idle.png"
	if ResourceLoader.exists(dropped):
		_cigar_art = load(dropped) as Texture2D
	add_to_group(Enemy2D.GROUP)
	add_to_group(LightField.GROUP)
	z_index = 3
	cigar = Area2D.new()
	cigar.name = "Cigar"
	cigar.collision_layer = PhysicsLayers.WORLD | PhysicsLayers.ENEMY_HURTBOX
	cigar.collision_mask = 0
	cigar.monitoring = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	cigar.add_child(shape)
	cigar.position = CIGAR_TIP
	add_child(cigar)


func _process(delta: float) -> void:
	_clock += delta
	if _fall_clock >= 0.0:
		_fall_clock += delta
	queue_redraw()


## A weapon's blow, as every weapon delivers it (the walk up from its shape to here). Only one that
## reaches the cigar counts -- a blade cannot, from the ground.
func apply_tool_hit(_tool: String, _impulse: float, _actor: Node2D) -> bool:
	if not _cigar_lit:
		return false
	_cigar_lit = false
	_fall_clock = 0.0
	cigar.set_deferred(&"collision_layer", 0)
	cigar_knocked.emit()
	return true


## Whether the smoke still stands, and where it is in world x.
func smoke_stands() -> bool:
	return _smoke > 0.0


func smoke_span() -> Vector2:
	return Vector2(global_position.x - SMOKE_WIDTH, global_position.x)


## `blown`: blown away by moving air, rather than gone with its cigar or its tree.
func clear_smoke(blown := false) -> void:
	if _smoke <= 0.0:
		return
	_blown = _blown or blown
	var thin := create_tween()
	thin.tween_property(self, "_smoke", 0.0, FADE_SECONDS)


## Where the smoke is drawn, off where it stands: going away east and up as it is blown clear.
func smoke_offset() -> Vector2:
	return BLOWN_AWAY * (1.0 - _smoke) if _blown else Vector2.ZERO


## One chop at its tree. Returns whether that one felled it.
func chop() -> bool:
	if _felled:
		return false
	_chops += 1
	if _chops >= CHOPS_TO_FELL:
		_felled = true
		tree_art.play("felled")
		clear_smoke()
		leave()
		return true
	return false


func chops() -> int:
	return _chops


func is_felled() -> bool:
	return _felled


func cigar_is_lit() -> bool:
	return _cigar_lit


## Where the knocked cigar is, from the tree's foot: falling, or lying where it fell. INF until it
## is knocked.
func fallen_cigar() -> Vector2:
	if _fall_clock < 0.0:
		return Vector2.INF
	return _cigar_at(minf(_fall_clock, _landing()))


func _cigar_at(t: float) -> Vector2:
	return CIGAR_TIP + Vector2(FALL_THROW * t, 0.5 * FALL_GRAVITY * t * t)


## How long the cigar takes to come down from its tip to where it lies.
func _landing() -> float:
	return sqrt(2.0 * (LIES_AT - CIGAR_TIP.y) / FALL_GRAVITY)


## Whether the fallen cigar's ember is still alight.
func _ember_alight() -> bool:
	return _fall_clock >= 0.0 and _fall_clock < _landing() + EMBER_DIES


## Away into the dark, and seen to go: knocked, it climbs up into its crown; felled, it drops with
## its tree and walks off.
func leave() -> void:
	if _gone:
		return
	_gone = true
	clear_smoke()
	if art == null or not art.has_art():
		return
	art.play("falling" if _felled else "knocked")
	var away := create_tween()
	if _felled:
		away.tween_property(art, "position:y", 0.0, DROP_SECONDS).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		away.tween_property(art, "position:x", ART_AT.x + WALKS_OFF, WALK_SECONDS)
		away.parallel().tween_property(art, "modulate:a", 0.0, WALK_SECONDS)
	else:
		away.tween_property(art, "position:y", ART_AT.y - CLIMBS, CLIMB_SECONDS).set_trans(Tween.TRANS_SINE)
		away.parallel().tween_property(art, "modulate:a", 0.0, CLIMB_SECONDS)
	away.tween_callback(art.hide)


func is_gone() -> bool:
	return _gone


func light_hole() -> Dictionary:
	if not _cigar_lit and _ember_alight():
		var dying := clampf((_fall_clock - _landing()) / EMBER_DIES, 0.0, 1.0)
		return {"position": global_position + fallen_cigar(), "radius": FALLEN_GLOW, "strength": 0.6 * (1.0 - dying)}
	if not _cigar_lit:
		return {}
	# Felled, it takes its cigar down with it, and the light goes where its face goes -- until it
	# has faded into the dark.
	var carried := Vector2.ZERO
	var shown := 1.0
	if _gone:
		if not _felled or art == null or not art.visible:
			return {}
		carried = art.position - ART_AT
		shown = art.modulate.a
	return {"position": global_position + cigar.position + carried, "radius": CIGAR_GLOW, "strength": 0.7 * shown,
		"direction": CIGAR_LIGHT_TOWARD, "half_angle": CIGAR_LIGHT_HALF_ANGLE}


## Back to before she came -- unless it was answered; a restore does not grow a tree back.
func reset_for_restore() -> void:
	if _gone or _felled or not _cigar_lit:
		return
	_chops = 0


## PLACEHOLDER until it has art: its tree, the kapre up it, the cigar's ember, and the smoke.
func _draw() -> void:
	if not tree_art.has_art() and not _felled:
		draw_rect(Rect2(-TRUNK.x * 0.5, -TRUNK.y, TRUNK.x, TRUNK.y), BARK)
		draw_circle(Vector2(0.0, -TRUNK.y - 40.0), 110.0, Color(0.07, 0.12, 0.07))
	elif not tree_art.has_art():
		draw_rect(Rect2(-TRUNK.y * 0.5, -TRUNK.x, TRUNK.y, TRUNK.x), BARK)
	var drawn := art != null and art.has_art()
	if drawn:
		art.advance(get_process_delta_time())
	if not _gone and not drawn:
		draw_rect(Rect2(CIGAR_TIP + Vector2(40.0, -20.0), Vector2(50.0, 90.0)), HIDE)
		draw_circle(CIGAR_TIP + Vector2(56.0, -10.0), 18.0, HIDE)
	if _cigar_lit and not _gone and not drawn:
		draw_circle(cigar.position, 4.0, EMBER)
	if _smoke > 0.0 and _smoke_sheet != null:
		_draw_smoke()
	elif _smoke > 0.0:
		for index in range(18):
			var x := -SMOKE_WIDTH + fmod(index * 37.0 + _clock * 14.0, SMOKE_WIDTH)
			var y := -40.0 - fmod(index * 53.0, 240.0)
			draw_circle(Vector2(x, y), 46.0, Color(SMOKE, 0.16 * _smoke))
	if _fall_clock >= 0.0 and _cigar_art != null:
		_draw_fallen_cigar()


## The knocked cigar tumbling down, sparks trailing off its ember, a burst of them where it lands;
## then lying there until its ember dies, and fading out a second after.
func _draw_fallen_cigar() -> void:
	var landed := _landing()
	var spin := minf(_fall_clock, landed) / landed * 3.0 * PI
	var gone := clampf((_fall_clock - landed - EMBER_DIES) / 1.0, 0.0, 1.0)
	if gone < 1.0:
		draw_set_transform(fallen_cigar().round(), spin)
		draw_texture(_cigar_art, -_cigar_art.get_size() * 0.5, Color(1.0, 1.0, 1.0, 1.0 - gone))
		draw_set_transform(Vector2.ZERO)
	for spark in range(6):
		var back := _fall_clock - 0.05 * float(spark + 1)
		if back > 0.0 and back < landed:
			var at := _cigar_at(back) + Vector2(sin(spark * 2.3) * 4.0, 0.0)
			draw_rect(Rect2(at.round(), Vector2(2.0, 2.0)), Color(EMBER, 1.0 - spark / 6.0))
	var since := _fall_clock - landed
	if since > 0.0 and since < 0.5:
		for spark in range(8):
			var a := -PI * (0.1 + 0.8 * spark / 7.0)
			var at := fallen_cigar() + Vector2(cos(a), sin(a)) * (10.0 + 70.0 * since) + Vector2(0.0, 160.0 * since * since)
			draw_rect(Rect2(at.round(), Vector2(2.0, 2.0)), Color(EMBER, 1.0 - since / 0.5))


## The bank of it over the path, low and drifting west, each puff fading in and out on its own
## clock so none pops in; and while the cigar burns, the thread of it coming off the tip and down
## into the bank. All of it as faint as the smoke left.
func _draw_smoke() -> void:
	var away := smoke_offset()
	# The haze: one faint sheet over the whole bank, its top rolling, thinning out at the west end.
	var sheet := PackedVector2Array()
	var shades := PackedColorArray()
	var steps := 24
	for step in range(steps + 1):
		var x := -SMOKE_WIDTH + SMOKE_WIDTH * float(step) / steps
		sheet.append(away + Vector2(x, -HAZE + sin(x * 0.018 + _clock * 0.5) * 16.0))
		shades.append(Color(SMOKE_TONE, 0.24 * _smoke * clampf(float(step) / 4.0, 0.0, 1.0)))
	for step in range(steps, -1, -1):
		sheet.append(away + Vector2(-SMOKE_WIDTH + SMOKE_WIDTH * float(step) / steps, 0.0))
		shades.append(Color(SMOKE_TONE, 0.30 * _smoke * clampf(float(step) / 4.0, 0.0, 1.0)))
	draw_polygon(sheet, shades)
	for index in range(BANK_PUFFS):
		# Spread over the bank evenly, along and up, and not in a line (the R2 sequence).
		var spread := fmod(0.5 + index * 0.7548777, 1.0)
		var height := fmod(0.5 + index * 0.5698403, 1.0)
		var home := Vector2(-SMOKE_WIDTH + PUFF * 0.4 + spread * (SMOKE_WIDTH - PUFF * 0.6), -24.0 - pow(height, 1.5) * 170.0)
		var life := fmod(_clock / (7.0 + float(index % 5)) + height, 1.0)
		var drift := Vector2(-40.0 * life, -12.0 * life + sin(_clock * 0.7 + index) * 3.0)
		_puff(index % (PUFFS - 2), away + home + drift, sin(life * PI) * 0.65)
	if _cigar_lit and not _gone:
		for index in range(STREAM_PUFFS):
			var life := fmod(_clock / 6.0 + float(index) / STREAM_PUFFS, 1.0)
			var at := CIGAR_TIP.lerp(STREAM_TO, life) + Vector2(0.0, -sin(life * PI) * 30.0)
			var size := PUFFS - 1 if life < 0.3 else (PUFFS - 2 if life < 0.65 else index % (PUFFS - 2))
			_puff(size, away + at, sin(life * PI) * 0.55)


## One puff, `frame` of the sheet, centred on `centre`, on whole pixels so it stays crisp.
func _puff(frame: int, centre: Vector2, alpha: float) -> void:
	var corner := (centre - Vector2(PUFF, PUFF) * 0.5).round()
	draw_texture_rect_region(_smoke_sheet, Rect2(corner, Vector2(PUFF, PUFF)),
		Rect2(frame * PUFF, 0, PUFF, PUFF), Color(1.0, 1.0, 1.0, alpha * _smoke))
