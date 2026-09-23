class_name DagatLife2D
extends Node2D
## The things that move in Dagat and are not the player: gulls over the beach, jellyfish in the
## deep, surf against both shores, rain hitting the sea and lightning in the storm, a wake behind
## the boat, bubbles off whatever is swimming, and a glint where something is found.
##
## WHY ONE NODE AND NOT A SCRIPT ON EACH. Almost all of it answers the same two questions every
## frame -- where is the camera, and is it day or storm there -- and gulls in a thunderstorm or
## rain on a sunny beach are the mistakes that come of each thing asking for itself. The level
## hands this node the camera and the storm band once; everything here reads them.
##
## Nothing here is gameplay. No collision, no triggers, no ink: every sprite is decoration and
## is freed when it has finished or wandered off screen, so a long session does not accumulate
## a thousand dead gulls. The art is tools/build_dagat_props.py's, in the level's own palette.

const AUTHORED := "res://assets/Level3/authored/"
const PropClass = preload("res://scripts/dagat_prop_2d.gd")

## Handed in by the level before this enters the tree.
var camera: Camera2D
var storm: Node2D
var waterline_y := 560.0
var bed_y := 1709.0
## The seaward edges of the two shores, where the surf breaks.
var shore_edges := Vector2(1000.0, 4500.0)
## Where the jellyfish hang. Set by the level; the coral field's own jelly is separate.
var jelly_spots: Array[Vector2] = []
## Callables so this node never needs to know how the level stores them.
var player_anchor: Callable
var player_swimming: Callable
var boat: Callable
## The bakunawa, so the sea can churn where it breaks the surface.
var creature: Node2D

var _frames_cache: Dictionary = {}
var _gull_clock := 2.0
var _rain_clock := 0.0
var _thunder_clock := 6.0
var _wake_clock := 0.0
var _bubble_clock := 0.0
var _churn_clock := 0.0
var _flash: Polygon2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20260922
	_plant_the_surf()
	_release_the_jellies()
	_build_the_flash()


func _process(delta: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var at := camera.global_position
	var weather := _weather_at(at.x)
	_gull_clock -= delta
	if _gull_clock <= 0.0:
		_gull_clock = _rng.randf_range(4.0, 8.0)
		if weather < 0.35:
			send_gulls(at, _rng.randi_range(1, 3))
	if weather > 0.5:
		_rain_clock -= delta
		while _rain_clock <= 0.0:
			_rain_clock += 0.09 / weather
			_splash_rain(at)
		_thunder_clock -= delta
		if _thunder_clock <= 0.0:
			_thunder_clock = _rng.randf_range(5.0, 11.0)
			_lightning(weather)
	_thin_the_flock(delta)
	_trail_the_boat(delta)
	_breathe(delta)
	_churn(delta)


## ⚠ A GULL IS SENT OVER A CALM SKY AND THEN FLIES FOR TEN SECONDS. The check that keeps them
## off the storm is made where they are SENT, which is right and not enough: the crossing is
## one continuous world, so a bird launched over the beach travels into weather that did not
## exist when it left, and three of them were last seen over a thunderstorm with lightning
## behind them. They climb out of it and are gone, rather than vanishing on a line.
func _thin_the_flock(delta: float) -> void:
	for node in get_tree().get_nodes_in_group(GULLS):
		var gull := node as Node2D
		if not is_instance_valid(gull) or _weather_at(gull.global_position.x) < 0.4:
			continue
		gull.set("drift", Vector2(gull.get("drift")) + Vector2(0.0, -38.0 * delta))
		gull.modulate.a -= delta * 1.5
		if gull.modulate.a <= 0.0:
			gull.queue_free()


## How stormy it is over this x, 0..1 -- the storm band's own fade, times however far it has
## cleared. With no storm band, it is always day.
func _weather_at(x: float) -> float:
	if storm == null or not is_instance_valid(storm) or not storm.has_method("weather_at"):
		return 0.0
	return float(storm.call("weather_at", x))


func _frames(prefix: String) -> Array[Texture2D]:
	if _frames_cache.has(prefix):
		return _frames_cache[prefix]
	var out: Array[Texture2D] = []
	var index := 0
	while ResourceLoader.exists("%s%s_%d.png" % [AUTHORED, prefix, index]):
		out.append(load("%s%s_%d.png" % [AUTHORED, prefix, index]) as Texture2D)
		index += 1
	_frames_cache[prefix] = out
	return out


## A sprite that plays `prefix` at `fps`, looping or once. Centred, pixel-filtered.
func _sprite(prefix: String, fps: float, loop := true) -> _Flipbook:
	var sprite := _Flipbook.new()
	sprite.frames = _frames(prefix)
	sprite.fps = fps
	sprite.loop = loop
	return sprite


# --- Gulls ---------------------------------------------------------------------------------

## Gulls are swept for one reason only -- see _thin_the_flock.
const GULLS := &"dagat_gull"


## A few gulls across the sky in view, all going the same way. Public because the opening
## sends a flock over on purpose.
func send_gulls(at: Vector2, count: int, rightward := -1) -> void:
	var view := _view_size()
	var going_right := rightward == 1 or (rightward == -1 and _rng.randf() < 0.5)
	var start_x := at.x - view.x * 0.6 if going_right else at.x + view.x * 0.6
	var sky_top := at.y - view.y * 0.45
	var sky_bottom := minf(waterline_y - 170.0, at.y - 40.0)
	if sky_bottom <= sky_top + 20.0:
		return
	var height := _rng.randf_range(sky_top + 30.0, sky_bottom)
	for index in range(count):
		var gull := _sprite("gull", _rng.randf_range(7.0, 9.5))
		gull.flip_h = not going_right
		gull.scale = Vector2.ONE * _rng.randf_range(0.85, 1.1)
		gull.z_index = -140
		gull.drift = Vector2((1.0 if going_right else -1.0) * _rng.randf_range(115.0, 150.0), 0.0)
		gull.bob = _rng.randf_range(5.0, 10.0)
		gull.lifetime = (view.x * 1.4) / absf(gull.drift.x)
		gull.phase = float(index)
		gull.add_to_group(GULLS)
		add_child(gull)
		gull.global_position = Vector2(start_x - (1.0 if going_right else -1.0) * index * 46.0,
			height + index * _rng.randf_range(-18.0, 18.0))


# --- The deep --------------------------------------------------------------------------------

func _release_the_jellies() -> void:
	for spot in jelly_spots:
		var jelly := _sprite("jelly", _rng.randf_range(3.5, 5.0))
		jelly.z_index = -18
		jelly.modulate = Color(1.0, 1.0, 1.0, 0.88)
		jelly.bob = _rng.randf_range(26.0, 42.0)
		jelly.bob_speed = _rng.randf_range(0.7, 1.0)
		jelly.sway = _rng.randf_range(18.0, 34.0)
		jelly.phase = _rng.randf_range(0.0, TAU)
		add_child(jelly)
		jelly.home = spot
		jelly.global_position = spot


# --- The surf, against both shores ---------------------------------------------------------

## ⚠ IT HAS TO BREATHE, OR IT IS A RULER. Two flat strips laid end to end at a fixed y read
## as a dashed line ruled along the waterline -- the eye finds the repeat before it finds the
## foam. Three now, each one sitting a little lower and fainter than the one inshore of it, and
## each riding its own bob and sway so the line moves as water rather than sitting as a mark.
## The reach is the rocks': the clump that ends each shore stands about four hundred pixels out
## over the shallows, and foam that stopped at the collision edge broke against nothing.
func _plant_the_surf() -> void:
	for edge in [[shore_edges.x, false], [shore_edges.y, true]]:
		var seaward := bool(edge[1])
		for strip in range(3):
			var surf := _sprite("foam", 2.6 + float(strip) * 0.7)
			surf.centered = false
			surf.phase = float(strip) * 1.3 + (2.1 if seaward else 0.0)
			surf.bob = 2.0 + float(strip)
			surf.bob_speed = 0.9 + 0.17 * float(strip)
			surf.sway = 3.0 + 2.0 * float(strip)
			surf.flip_h = seaward
			surf.z_index = -148
			add_child(surf)
			var width := float(surf.frames[0].get_width()) if not surf.frames.is_empty() else 144.0
			var x := float(edge[0]) + (width * strip if not seaward else -width * (strip + 1))
			surf.home = Vector2(x, waterline_y - 14.0 + 3.0 * float(strip))
			surf.global_position = surf.home
			surf.modulate = Color(1.0, 1.0, 1.0, 0.95 - 0.32 * float(strip))


# --- The storm -----------------------------------------------------------------------------

func _splash_rain(at: Vector2) -> void:
	var view := _view_size()
	var x := at.x + _rng.randf_range(-view.x * 0.55, view.x * 0.55)
	if x < shore_edges.x + 20.0 or x > shore_edges.y - 20.0:
		return
	var splash := _sprite("splash", 14.0, false)
	splash.z_index = -150
	splash.modulate = Color(0.85, 0.92, 1.0, 0.85)
	add_child(splash)
	splash.global_position = Vector2(x, waterline_y + _rng.randf_range(-6.0, 10.0))


func _build_the_flash() -> void:
	_flash = Polygon2D.new()
	_flash.name = "Lightning"
	_flash.color = Color(0.85, 0.9, 1.0, 0.0)
	_flash.z_index = 55
	_flash.polygon = PackedVector2Array([Vector2(-3000, -3000), Vector2(3000, -3000),
		Vector2(3000, 3000), Vector2(-3000, 3000)])
	add_child(_flash)


## Two quick flashes, the second fainter: the sky lights and the storm band flares with it.
func _lightning(weather: float) -> void:
	if camera != null and is_instance_valid(camera):
		_flash.global_position = camera.global_position
	var peak := 0.22 * weather
	var run := create_tween()
	run.tween_property(_flash, "color:a", peak, 0.04)
	run.tween_property(_flash, "color:a", 0.0, 0.12)
	run.tween_interval(0.09)
	run.tween_property(_flash, "color:a", peak * 0.6, 0.03)
	run.tween_property(_flash, "color:a", 0.0, 0.35)
	if storm != null and is_instance_valid(storm):
		var lit := Color(1.7, 1.7, 1.9, storm.modulate.a)
		var flare := create_tween()
		flare.tween_method(func(k: float) -> void:
			if is_instance_valid(storm):
				storm.modulate = Color(lerpf(1.0, lit.r, k), lerpf(1.0, lit.g, k),
					lerpf(1.0, lit.b, k), storm.modulate.a), 1.0, 0.0, 0.5)


# --- The boat and the swimmer --------------------------------------------------------------

func _trail_the_boat(delta: float) -> void:
	var hull := boat.call() as RigidBody2D if boat.is_valid() else null
	if hull == null or not is_instance_valid(hull):
		return
	var speed := hull.linear_velocity.x
	if absf(speed) < 50.0:
		return
	_wake_clock -= delta
	if _wake_clock > 0.0:
		return
	_wake_clock = 0.12
	var wake := _sprite("wake", 8.0, false)
	wake.flip_h = speed < 0.0
	wake.z_index = -151
	wake.fade = 0.9
	add_child(wake)
	wake.global_position = hull.global_position + Vector2(-signf(speed) * 70.0, 6.0)


func _breathe(delta: float) -> void:
	if not player_swimming.is_valid() or not bool(player_swimming.call()):
		return
	_bubble_clock -= delta
	if _bubble_clock > 0.0:
		return
	_bubble_clock = _rng.randf_range(0.45, 0.9)
	var at: Vector2 = player_anchor.call()
	var bubble := _sprite("bubble", 3.0)
	bubble.z_index = 20
	bubble.drift = Vector2(0.0, -_rng.randf_range(55.0, 80.0))
	bubble.sway = 6.0
	bubble.lifetime = _rng.randf_range(1.4, 2.2)
	bubble.fade = bubble.lifetime
	bubble.ceiling = waterline_y + 6.0
	add_child(bubble)
	bubble.global_position = at + Vector2(_rng.randf_range(-10.0, 10.0), -18.0)


## WHERE IT BREAKS THE SURFACE, THE SEA SAYS SO. Staged at the surface for a boat player, the
## creature is a long dark shape just under the waves; splashes along its length are what
## make it read as something in the water rather than something painted behind it.
func _churn(delta: float) -> void:
	if creature == null or not is_instance_valid(creature):
		return
	if creature.global_position.y > waterline_y + 260.0:
		return
	_churn_clock -= delta
	if _churn_clock > 0.0:
		return
	_churn_clock = _rng.randf_range(0.12, 0.28)
	var splash := _sprite("splash", 11.0, false)
	splash.z_index = -150
	splash.scale = Vector2.ONE * _rng.randf_range(1.2, 1.8)
	add_child(splash)
	splash.global_position = Vector2(creature.global_position.x + _rng.randf_range(-430.0, 430.0),
		waterline_y + _rng.randf_range(-4.0, 8.0))


# --- Found things --------------------------------------------------------------------------

## A little burst of glints -- where the creature finds what it lost, and where the painting
## waits on the island.
func sparkle(at: Vector2, count := 6, spread := 60.0) -> void:
	for index in range(count):
		var glint := _sprite("spark", 10.0, false)
		glint.z_index = 30
		glint.delay = index * 0.12
		add_child(glint)
		glint.global_position = at + Vector2(_rng.randf_range(-spread, spread),
			_rng.randf_range(-spread, spread * 0.4))


func _view_size() -> Vector2:
	var size := get_viewport_rect().size
	if camera != null and is_instance_valid(camera):
		size /= camera.zoom
	return size


## One animated decoration: frames at a rate, and optionally a drift, a bob, a sway around a
## home point, a fade, a lifetime and a ceiling it pops at. Frees itself when it is done.
class _Flipbook extends Sprite2D:
	var frames: Array[Texture2D] = []
	var fps := 6.0
	var loop := true
	var drift := Vector2.ZERO
	var bob := 0.0
	var bob_speed := 3.0
	var sway := 0.0
	var phase := 0.0
	var home := Vector2.INF
	var lifetime := 0.0
	var fade := 0.0
	var delay := 0.0
	var ceiling := -INF
	var _age := 0.0
	var _clock := 0.0
	var _frame := 0
	var _base := Vector2.INF
	var _alpha := 1.0

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if frames.is_empty():
			queue_free()
			return
		texture = frames[0]
		_alpha = modulate.a
		if delay > 0.0:
			visible = false

	func _process(delta: float) -> void:
		if delay > 0.0:
			delay -= delta
			if delay > 0.0:
				return
			visible = true
		_age += delta
		if _base == Vector2.INF:
			_base = global_position if home == Vector2.INF else home
		_base += drift * delta
		var t := _age * bob_speed + phase
		global_position = _base + Vector2(sin(t * 0.6) * sway, sin(t) * bob)
		_clock += delta
		var step := 1.0 / maxf(0.01, fps)
		while _clock >= step:
			_clock -= step
			_frame += 1
			if _frame >= frames.size():
				if not loop:
					queue_free()
					return
				_frame = 0
			texture = frames[_frame]
		if fade > 0.0:
			modulate.a = _alpha * clampf(1.0 - _age / fade, 0.0, 1.0)
		if (lifetime > 0.0 and _age >= lifetime) or global_position.y <= ceiling:
			queue_free()
