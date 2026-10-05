extends Node2D
## THE CAST LINE: the hook in flight, then in the water, and -- with something on it -- the fight
## to bring it in, all of it out in the world where it can be watched. Kent (2026-10-05): "the
## player casts the hook and we see the camera following the hook", and then "in most fishing games,
## we visibly see the fish getting pulled back, not a circle screen".
##
## THE CAST is held to charge (level_3.gd): `power` 0..1 is how far it flies and how deep it is let
## sink -- "if i hold the button longer, the stronger the cast is and the deeper it gets". Up and
## down still work the depth once it is in.
##
## THE FIGHT. Holding the reel winds the hook -- and whatever is on it -- toward the rod. The
## creature makes runs, pulling away hard for a moment and then tiring for a moment, each kind its
## own way (SeaCreature2D.KINDS["pull"...]). Winding against a run builds the line's TENSION; at the
## top of it the line snaps and the creature is gone. Not winding, the line pays out as it runs, and
## if it takes the whole line it is gone too. Brought up beside the rod, it is landed.
##
## ⚠ PRELOADED BY PATH, NOT BY class_name -- see sea_creature_2d.gd.

signal splashed(at: Vector2)
signal reeled_in
signal landed(creature: Node2D)
signal escaped(creature: Node2D, why: String)

const HOOK_ART := preload("res://assets/Level3/creatures/fishing_hook.png")
const GRAVITY := 900.0
## The cast's speed and how deep it may sink, from a tap to a full charge.
const CAST_SPEED := Vector2(320.0, 920.0)
const SINK_DEPTH := Vector2(110.0, 1090.0)
const SINK := 230.0
const WORK := 160.0
const LINE_REACH := 1250.0
## Winding with nothing on, and with something on.
const REEL_SPEED := 760.0
## Faster than any of them runs between runs, slower than the strongest run: easing off when it
## runs and winding while it tires always gains, and winding through every run snaps the line.
const REEL_HOOKED := 300.0
## How near the rod, along the water, a creature is landed.
const LAND_REACH := 80.0

## Where the rod's tip is, in the world, every frame.
var rod_tip: Callable
## Whether the reel is being wound this frame (the held key, or a probe).
var reeling: Callable
var waterline := 560.0
var floor_y := 1700.0
var hook: Node2D
## How deep the hook is let sink, in world y. Set by the cast's power; worked by up and down.
var max_depth := 900.0
## 0..1. At 1 the line snaps.
var tension := 0.0

var _velocity := Vector2.ZERO
var _in_water := false
var _winding_home := false
var _fish: Node2D
var _fight: Dictionary = {}
var _running := false
var _run_left := 0.0
var _run_dir := Vector2.RIGHT


func _ready() -> void:
	z_index = 12
	hook = Node2D.new()
	hook.name = "Hook"
	add_child(hook)
	var art := Sprite2D.new()
	art.texture = HOOK_ART
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.scale = Vector2.ONE * 2.0
	art.offset = Vector2(0.0, 8.0)
	hook.add_child(art)


## Out from `from`, toward `toward`, rising a little first the way a cast does; `power` 0..1.
func cast(from: Vector2, toward: Vector2, power: float = 0.6) -> void:
	power = clampf(power, 0.0, 1.0)
	hook.global_position = from
	var direction := (toward - from).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2(1.0, 0.0)
	direction = (Vector2(direction.x, minf(direction.y, 0.2)) + Vector2(0.0, -0.5)).normalized()
	_velocity = direction * lerpf(CAST_SPEED.x, CAST_SPEED.y, power)
	max_depth = minf(waterline + lerpf(SINK_DEPTH.x, SINK_DEPTH.y, power), floor_y - 24.0)
	_in_water = false
	_winding_home = false


func in_water() -> bool:
	return _in_water and not _winding_home


func has_fish() -> bool:
	return _fish != null and is_instance_valid(_fish)


func is_fish_running() -> bool:
	return has_fish() and _running


func is_reeling() -> bool:
	return _winding_home


func hook_position() -> Vector2:
	return hook.global_position


## Back to the rod on its own, empty -- after something got away.
func reel_in() -> void:
	_winding_home = true


## Something has taken it. `fight` is its kind's pull, how long it runs and rests, and how hard it
## is on the line (SeaCreature2D.fight()).
func hook_creature(creature: Node2D, fight: Dictionary) -> void:
	_fish = creature
	_fight = fight
	_running = true
	_run_left = float(fight.get("run", 1.2)) * 0.6
	_choose_a_run()
	tension = 0.0


func _choose_a_run() -> void:
	var tip: Vector2 = rod_tip.call() if rod_tip.is_valid() else global_position
	var away := (hook.global_position - tip)
	away.y = 0.0
	if away.length() < 1.0:
		away = Vector2(1.0, 0.0)
	_run_dir = (away.normalized() + Vector2(randf_range(-0.3, 0.3), randf_range(0.2, 0.8))).normalized()


func _winding() -> bool:
	return reeling.is_valid() and bool(reeling.call())


func _physics_process(delta: float) -> void:
	var tip: Vector2 = rod_tip.call() if rod_tip.is_valid() else global_position
	var at := hook.global_position
	if has_fish():
		_fight_it(delta, tip)
		queue_redraw()
		return
	if _winding_home or (_in_water and _winding()):
		var to := tip - at
		if to.length() <= REEL_SPEED * delta + 4.0:
			hook.global_position = tip
			_winding_home = false
			reeled_in.emit()
			set_physics_process(false)
			queue_redraw()
			return
		hook.global_position = at + to.normalized() * REEL_SPEED * delta
		queue_redraw()
		return
	if not _in_water:
		_velocity.y += GRAVITY * delta
		at += _velocity * delta
		if at.y >= waterline:
			at.y = waterline + 4.0
			_in_water = true
			_velocity = Vector2(_velocity.x * 0.25, 0.0)
			splashed.emit(at)
	else:
		# Sinks to the depth the cast allowed; up and down work it from there.
		var work := Input.get_axis(&"move_up", &"move_down")
		max_depth = clampf(max_depth + work * WORK * delta, waterline + 20.0, floor_y - 24.0)
		at.y = move_toward(at.y, max_depth, SINK * delta)
		at.x += _velocity.x * delta
		_velocity.x = move_toward(_velocity.x, 0.0, 400.0 * delta)
	var line := at - tip
	if line.length() > LINE_REACH:
		at = tip + line.normalized() * LINE_REACH
	hook.global_position = at
	queue_redraw()


func _fight_it(delta: float, tip: Vector2) -> void:
	var at := hook.global_position
	_run_left -= delta
	if _run_left <= 0.0:
		_running = not _running
		_run_left = float(_fight.get("run" if _running else "rest", 1.0)) * randf_range(0.7, 1.3)
		if _running:
			_choose_a_run()
	var pull := float(_fight.get("pull", 120.0)) * (1.0 if _running else 0.18)
	if _fish.has_method("pulled"):
		_fish.call("pulled", _running, _run_dir.x)
	var strength := float(_fight.get("strength", 1.0))
	var winding := _winding()
	var move := _run_dir * pull
	if winding:
		move += (tip - at).normalized() * REEL_HOOKED
		# Winding against a run is what strains the line.
		tension += delta * (0.75 * strength if _running else -0.35)
	else:
		tension -= delta * 0.6
	tension = clampf(tension, 0.0, 1.0)
	at += move * delta
	at.y = clampf(at.y, waterline + 10.0, floor_y - 24.0)
	hook.global_position = at
	if tension >= 1.0:
		_let_go("snapped")
		return
	if (at - tip).length() >= LINE_REACH:
		_let_go("ran")
		return
	if absf(at.x - tip.x) <= LAND_REACH and at.y <= waterline + 60.0:
		var fish := _fish
		_fish = null
		tension = 0.0
		landed.emit(fish)


func _let_go(why: String) -> void:
	var fish := _fish
	_fish = null
	tension = 0.0
	_winding_home = true
	escaped.emit(fish, why)


func _draw() -> void:
	var tip: Vector2 = rod_tip.call() if rod_tip.is_valid() else global_position
	var from := to_local(tip)
	var to := to_local(hook.global_position)
	# Slack in the air, straight under the water -- and taut and reddening as the tension rises.
	var sag := 0.0 if _in_water else 30.0
	if has_fish():
		sag = lerpf(26.0, 0.0, clampf(tension * 1.5 + (0.4 if _winding() else 0.0), 0.0, 1.0))
	var points := PackedVector2Array()
	for step in range(13):
		var t := float(step) / 12.0
		points.append(from.lerp(to, t) + Vector2(0.0, sin(PI * t) * sag))
	var colour := Color(0.92, 0.94, 0.96, 0.85).lerp(Color(1.0, 0.3, 0.25, 1.0), tension)
	draw_polyline(points, colour, 1.5 + tension * 1.5, true)
	if has_fish():
		# The tension, over the fight: green to red, and how close it is to going.
		var bar := Rect2(to + Vector2(-50.0, -78.0), Vector2(100.0, 10.0))
		draw_rect(bar.grow(3.0), Color(0.02, 0.04, 0.08, 0.8))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * tension, bar.size.y)),
			Color(0.45, 0.85, 0.5).lerp(Color(1.0, 0.25, 0.2), tension))
		draw_rect(bar, Color(1, 1, 1, 0.6), false, 1.0)
