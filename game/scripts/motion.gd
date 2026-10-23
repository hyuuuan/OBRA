class_name Motion
extends RefCounted
## The game's motion, in one place: how things come in, go out, and answer. Kent, 2026-10-23:
## "add animations for everything ... appropriate to the game and to make the game smoother" --
## and, asked, a MIX: a pop that overshoots and settles for what the player acts on (the idiom
## of the drawing canvas's entrance and of every button's press, ui_feedback.gd), soft fades and
## slides for menus, overlays and the HUD. One family, so the interface reads as one thing.
##
## REDUCE MOTION. A setting (PlayerProfile "reduce_motion", in Settings) for players who find
## motion uncomfortable: every scale, slide and shake is dropped and what is left is a short
## fade, so things still arrive and leave visibly but nothing moves. Every helper here asks
## `reduced()`; nothing that animates should decide that for itself.
##
## ⚠ STATIC, NOT AN AUTOLOAD. Autoload names do not compile in the scripts a `--script` probe
## loads up front, and overlays are built in those probes; a class_name with static functions
## works everywhere. The profile is looked up on the tree at call time.
##
## PIXEL MOTION (Kent, 2026-10-23: "pixelated style similar to the game, also for all other
## animations"). Nothing glides: every move is played the way pixel art is animated -- in whole
## frames at PIXEL_FPS, its curve (the overshoot, the ease) sampled at those frames and held between
## them; positions on whole pixels, sizes in sixty-fourths (a pop from 0.9 overshoots by ~1%: in
## sixteenths it rounded away), fades in eighths. One routine does it
## (`step`), so every helper -- and anything else that wants the look -- moves the same way.
##
## ⚠ TWEENS RUN WHILE PAUSED. A menu that pauses the game must still animate, so every tween here
## is TWEEN_PAUSE_PROCESS. And each item keeps one motion at a time (META): a new one kills the
## old, so an overlay closed and reopened at once does not end up half-faded.

## The pop: from POP_FROM of its size, overshooting (TRANS_BACK) as it settles -- the canvas's
## own entrance (draw_panel.gd: 0.84 over ~0.3 s), a little gentler for smaller things.
const POP_FROM := 0.9
const POP_SECONDS := 0.28
## Fades and slides: the canvas's scrim (0.34 s) and panel fade (0.28 s) curves.
const FADE_SECONDS := 0.24
const SLIDE_SECONDS := 0.26
const SLIDE := 24.0
## Going: quicker than coming, and easing in, so it gets out of the way.
const EXIT_SECONDS := 0.14
const EXIT_TO := 0.96
## A pulse, for something that changed and should be noticed (a count, a pip, a slot).
const PULSE_TO := 1.14
const PULSE_SECONDS := 0.24
## A shake, for something that refused or was hit.
const SHAKE_SECONDS := 0.3
## What reduced motion keeps of any of these: a short fade, nothing moving.
const QUICK_FADE := 0.1
const META := &"motion_tween"
## The frames a second every move is held to, and the steps a fade or a size moves in.
const PIXEL_FPS := 15.0
const ALPHA_STEPS := 8.0
const SCALE_STEPS := 64.0


## Whether the player has asked for less motion.
static func reduced() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	var profile := tree.root.get_node_or_null(^"PlayerProfile")
	if profile == null or not profile.has_method(&"get_setting"):
		return false
	return bool(profile.call(&"get_setting", "reduce_motion"))


## In with a pop: scaled up from POP_FROM about its middle, overshooting as it settles, fading in.
static func pop_in(item: CanvasItem, delay: float = 0.0) -> Tween:
	var tween := _fresh(item)
	_show(item)
	item.modulate.a = 0.0
	if reduced():
		step(tween, item, "modulate:a", 1.0, QUICK_FADE, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, delay)
		return tween
	_centre(item)
	if item is Control:
		(item as Control).scale = Vector2.ONE * POP_FROM
	elif item is Node2D:
		(item as Node2D).scale = Vector2.ONE * POP_FROM
	tween.set_parallel(true)
	step(tween, item, "modulate:a", 1.0, FADE_SECONDS, Tween.TRANS_CUBIC, Tween.EASE_OUT, delay)
	step(tween, item, "scale", Vector2.ONE, POP_SECONDS, Tween.TRANS_BACK, Tween.EASE_OUT, delay)
	return tween


## In with a fade alone (a scrim, a dim, a backdrop).
static func fade_in(item: CanvasItem, seconds: float = FADE_SECONDS, delay: float = 0.0) -> Tween:
	var tween := _fresh(item)
	_show(item)
	item.modulate.a = 0.0
	step(tween, item, "modulate:a", 1.0, QUICK_FADE if reduced() else seconds, Tween.TRANS_CUBIC, Tween.EASE_OUT, delay)
	return tween


## In with a soft slide: from `from` px off where it belongs, fading in. Where it belongs is
## where it is now.
static func slide_in(item: Control, from: Vector2 = Vector2(0.0, SLIDE), delay: float = 0.0) -> Tween:
	var tween := _fresh(item)
	_show(item)
	item.modulate.a = 0.0
	if reduced():
		step(tween, item, "modulate:a", 1.0, QUICK_FADE, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, delay)
		return tween
	var home := item.position
	item.position = home + from
	tween.set_parallel(true)
	step(tween, item, "modulate:a", 1.0, FADE_SECONDS, Tween.TRANS_CUBIC, Tween.EASE_OUT, delay)
	step(tween, item, "position", home, SLIDE_SECONDS, Tween.TRANS_CUBIC, Tween.EASE_OUT, delay)
	return tween


## Out: shrinking a little toward its middle as it fades, then hidden; `done` runs at the end.
static func leave(item: CanvasItem, done: Callable = Callable()) -> Tween:
	var tween := _fresh(item)
	if reduced():
		step(tween, item, "modulate:a", 0.0, QUICK_FADE, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, 0.0)
	else:
		_centre(item)
		tween.set_parallel(true)
		step(tween, item, "modulate:a", 0.0, EXIT_SECONDS, Tween.TRANS_CUBIC, Tween.EASE_IN, 0.0)
		step(tween, item, "scale", Vector2.ONE * EXIT_TO, EXIT_SECONDS, Tween.TRANS_CUBIC, Tween.EASE_IN, 0.0)
		tween.chain()
	tween.tween_callback(func() -> void:
		item.modulate.a = 1.0
		if item is Control:
			(item as Control).scale = Vector2.ONE
		elif item is Node2D:
			(item as Node2D).scale = Vector2.ONE
		if done.is_valid():
			done.call())
	return tween


## A pulse: up to PULSE_TO and back, overshooting -- for a count or a pip that just changed.
## Reduced motion keeps it still (a change in a number reads without it).
static func pulse(item: CanvasItem, to: float = PULSE_TO) -> Tween:
	var tween := _fresh(item)
	if reduced():
		return tween
	_centre(item)
	step(tween, item, "scale", Vector2.ONE * to, PULSE_SECONDS * 0.35, Tween.TRANS_CUBIC, Tween.EASE_OUT, 0.0)
	step(tween, item, "scale", Vector2.ONE, PULSE_SECONDS * 0.65, Tween.TRANS_BACK, Tween.EASE_OUT, 0.0)
	return tween


## A shake side to side, settling -- for a refusal or a hit. Reduced motion keeps it still.
static func shake(item: Control, strength: float = 8.0) -> Tween:
	var tween := _fresh(item)
	if reduced():
		return tween
	var home := item.position
	for i in range(5):
		var side := strength * (1.0 - i / 5.0) * (1.0 if i % 2 == 0 else -1.0)
		step(tween, item, "position", home + Vector2(side, 0.0), SHAKE_SECONDS / 6.0, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, 0.0)
	step(tween, item, "position", home, SHAKE_SECONDS / 6.0, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, 0.0)
	return tween


## Each in turn, the same entrance a beat apart -- a list arriving item by item.
static func stagger(items: Array, step: float = 0.04, from: Vector2 = Vector2(0.0, 10.0)) -> void:
	var delay := 0.0
	for node in items:
		var control := node as Control
		if control == null or not control.visible:
			continue
		slide_in(control, from, delay)
		delay += step


## Each in turn, faded in a beat apart and NOT moved -- for what a container has just been handed
## (dialogue choices): it lays them out a frame later, and a position tween started before that
## would hold them where they were made.
static func fade_stagger(items: Array, step: float = 0.06) -> void:
	var delay := 0.0
	for node in items:
		var item := node as CanvasItem
		if item == null or not item.visible:
			continue
		fade_in(item, FADE_SECONDS, delay)
		delay += step


## One property moved the pixel way, as part of `tween` (parallel or in sequence, as the tween is
## set): `seconds` cut into frames at PIXEL_FPS, the eased value of each frame held until the next,
## snapped to the pixel (position), a sixty-fourth (scale) or an eighth (alpha). Where it starts from is
## read as it starts, so a move chained after another starts where that one ended.
static func step(tween: Tween, item: Object, property: String, to: Variant, seconds: float,
		trans: Tween.TransitionType = Tween.TRANS_LINEAR, ease: Tween.EaseType = Tween.EASE_IN_OUT,
		delay: float = 0.0) -> MethodTweener:
	var frames := maxi(1, roundi(seconds * PIXEL_FPS))
	var state := {}
	var path := NodePath(property)
	var mover := func(t: float) -> void:
		if not state.has("from"):
			state["from"] = item.get_indexed(path)
		var held := floorf(t * frames) / float(frames) if t < 1.0 else 1.0
		var eased := Tween.interpolate_value(0.0, 1.0, held, 1.0, trans, ease) as float
		var from: Variant = state["from"]
		item.set_indexed(path, _snap(property, from + (to - from) * eased))
	return tween.tween_method(mover, 0.0, 1.0, seconds).set_delay(delay)


static func _snap(property: String, value: Variant) -> Variant:
	if property.begins_with("position") and value is Vector2:
		return (value as Vector2).round()
	if property == "scale" and value is Vector2:
		return ((value as Vector2) * SCALE_STEPS).round() / SCALE_STEPS
	if property.ends_with(":a") and value is float:
		return clampf(roundf(float(value) * ALPHA_STEPS) / ALPHA_STEPS, 0.0, 1.0)
	return value


static func _fresh(item: CanvasItem) -> Tween:
	var old: Variant = item.get_meta(META) if item.has_meta(META) else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tween := item.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	item.set_meta(META, tween)
	return tween


static func _show(item: CanvasItem) -> void:
	item.visible = true
	if item is Control:
		(item as Control).scale = Vector2.ONE
	elif item is Node2D:
		(item as Node2D).scale = Vector2.ONE


static func _centre(item: CanvasItem) -> void:
	if item is Control:
		var control := item as Control
		control.pivot_offset = control.size * 0.5
