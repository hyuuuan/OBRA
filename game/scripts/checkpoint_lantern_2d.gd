class_name CheckpointLantern2D
extends Node2D
## The mark on the ground that says the level has remembered you: a carved stone lantern,
## cold until you reach it and burning afterwards.
##
## IT WAS A FLAG AND THE FLAG READ AS A SIGNPOST. A pole with a small cloth on it is the
## checkpoint every platformer has used since checkpoints existed, and at this size, on this
## terrace, next to a level that is already full of actual wooden signboards, it was just one
## more thing on a stick -- "you placed a sign in the checkpoint spots". A signpost carries
## writing and asks to be read. This carries a FLAME, and a flame has exactly one state that
## matters and you can see it from the far end of a terrace.
##
## THE STATE IS LIGHT, NOT COLOUR. Unlit it is cold grey stone with a black opening, and the
## only thing moving anywhere near it is nothing. Lit, the window is a live fire that
## flickers, warm light lies on the stone's facing edges and pools on the ground under it,
## and it never stops. The previous mark changed from grey cloth to gold cloth, which is a
## difference you have to already be looking at it to notice.
##
## IT BELONGS HERE. A stone lantern on a path is a thing the Cordillera would have -- carved
## from the same rock the terrace walls are built out of -- and it is the one object in the
## level whose entire job is to be looked at from a distance.
##
## Everything below is measured in ART pixels and drawn at UNIT times that, so the pixel grid
## survives. An INTEGER, deliberately: every art pixel is exactly two screen pixels.

## Lit, or still cold. Setting it directly lights it with no ceremony, which is what a
## checkpoint restored from a save wants; `light()` is the version with the animation.
@export var lit: bool = false:
	set(value):
		if value == lit:
			return
		lit = value
		if value and not _lighting:
			_settle()
		queue_redraw()

const UNIT := 2.0
## Top of the finial, in art pixels. Times UNIT that is 110 -- a shade taller than the apo,
## which is the size a thing has to be before the eye picks it out of a terrace.
const HEIGHT := 55.0

const STONE := Color(0.443, 0.435, 0.412, 1.0)      # 716F69
const STONE_LIT := Color(0.596, 0.588, 0.557, 1.0)  # 98968E
const STONE_DARK := Color(0.271, 0.263, 0.243, 1.0) # 45433E
const EDGE := Color(0.110, 0.106, 0.098, 1.0)       # 1C1B19
const MOSS := Color(0.318, 0.376, 0.239, 1.0)       # 51603D

## The fire. Gold, because gold is what this interface has always meant by "yours now".
const FLAME_CORE := UISkin.GOLD_PALE
const FLAME := UISkin.GOLD
const FLAME_DEEP := Color(0.851, 0.443, 0.129, 1.0) # D97121
const COLD := Color(0.078, 0.075, 0.071, 1.0)       # 141312  the empty window

## How far the light reaches, in art pixels, and how much of it lands on the ground.
const GLOW_RADIUS := 46.0
const POOL_WIDTH := 44.0

## How hard the fire is burning, 0 cold to 1 alight. Driven by tweens through the setter, so
## the node has no idle work while it is cold.
var _fire := 0.0:
	set(value):
		_fire = value
		queue_redraw()
## The spark on its way from the player's hands to the window, and whether one is travelling.
var _spark_at := Vector2.ZERO:
	set(value):
		_spark_at = value
		queue_redraw()
var _sparking := false:
	set(value):
		_sparking = value
		queue_redraw()
## The flicker, which runs forever once it is lit. Whole art pixels of movement only.
var _flicker := 0.0
var _lighting := false

## Over the terrace, under the foreground planting: terrace tops and their props run 0..6,
## signposts sit at 7, and the front layer is at 30.
const LANTERN_Z := 8
## How far above the plant point the ground ray starts, and how far down it looks. STARTING
## ABOVE, NOT AT: a ray that begins exactly on a surface does not register it.
const LOOK_UP := 160.0
const GROUND_PROBE := 420.0
## Where else to look, in order, when there is nothing directly underneath. Negative first: a
## mark stands at the outgoing edge of a beat, so back toward the beat is back toward the
## ground the player was walking on.
const SWEEP: Array[float] = [0.0, -36.0, 36.0, -84.0, 84.0, -150.0, 150.0, -240.0, 240.0]


## Stand one at `at` in `parent`'s space, on whatever turns out to be underneath it.
static func plant(parent: Node2D, at: Vector2, lit_already: bool = false) -> CheckpointLantern2D:
	if parent == null or not is_instance_valid(parent):
		return null
	var lantern := CheckpointLantern2D.new()
	lantern.name = "Checkpoint"
	lantern.position = at
	lantern.z_index = LANTERN_Z
	lantern.lit = lit_already
	parent.add_child(lantern)
	lantern.stand_on_the_ground()
	return lantern


## Drop onto the first solid thing below. Deferred by one physics frame on purpose: the
## terraces build their own collision in _ready, so at the moment this is planted the physics
## server has not been told about the ground it is asking after.
func stand_on_the_ground() -> void:
	if not is_inside_tree():
		return
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var space := get_world_2d().direct_space_state
	if space == null:
		return
	for nudge in SWEEP:
		var from := global_position + Vector2(nudge, -LOOK_UP)
		var query := PhysicsRayQueryParameters2D.create(
			from, from + Vector2(0.0, GROUND_PROBE))
		query.collision_mask = 1
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		global_position = Vector2(global_position.x + nudge, Vector2(hit["position"]).y)
		return
	push_warning("CheckpointLantern2D at %s found no ground to stand on" % global_position)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if lit:
		# Restored, not lit: a level reloaded at a checkpoint opens with the fire already
		# burning rather than playing the moment again for a player who earned it before.
		_settle()
	set_process(lit)
	queue_redraw()


## Burning, with no ceremony. The state a restored checkpoint opens in.
func _settle() -> void:
	_fire = 1.0
	_sparking = false
	set_process(true)


func is_lit() -> bool:
	return lit


## THE MOMENT IT CATCHES. `taker` is where the apo is standing, in this node's space.
##
## A spark leaves them, travels up to the window, and the fire takes. Three quarters of a
## second, and the middle of it is the part that matters: the light comes FROM the player.
## A checkpoint that lights itself as you walk past is a thing that happened; one you carry
## the flame to is a thing you did, and it costs nothing to say it that way.
func light(taker: Vector2) -> void:
	if _lighting or lit:
		return
	_lighting = true
	lit = true
	if not is_inside_tree():
		_settle()
		_lighting = false
		return

	var hands := Vector2(clampf(taker.x / UNIT, -40.0, 40.0),
		minf(taker.y / UNIT - 28.0, -10.0))
	var window := Vector2(0.0, -35.0)
	_spark_at = hands
	_sparking = true
	set_process(true)

	var run := create_tween()
	run.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# 1. THE SPARK CROSSES. Rising, because a light being carried up to a lantern arcs.
	run.tween_property(self, "_spark_at", window + Vector2(0.0, -9.0), 0.30) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	run.tween_property(self, "_spark_at", window, 0.10) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# 2. IT TAKES. The fire overshoots and settles, the way a wick flares when it catches.
	run.tween_callback(func() -> void: _sparking = false)
	run.tween_callback(_catch)
	run.tween_property(self, "_fire", 1.28, 0.16) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	run.tween_property(self, "_fire", 1.0, 0.34) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	run.tween_callback(func() -> void: _lighting = false)


## The flare when the wick takes, thrown in the same gold and with the same vocabulary every
## other "yours now" in this game uses.
func _catch() -> void:
	PickupFlourish2D.burst(self, Vector2(0.0, -35.0 * UNIT), FLAME_CORE)


## THE FIRE NEVER STOPS. A checkpoint you have lit is the one thing in the level that is
## still moving when nothing else is, which is what makes it findable on the way back.
func _process(delta: float) -> void:
	if _fire <= 0.0 and not _sparking:
		set_process(false)
		return
	_flicker += delta * 6.4
	queue_redraw()


func _draw() -> void:
	# Everything is measured UP from this node's origin, which is the ground it stands on --
	# so the level places one by dropping it on a terrace rather than by working out where
	# its middle would be. And everything below is in ART pixels; see UNIT.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(UNIT, UNIT))
	_draw_pool()
	_draw_glow()
	_draw_stone()
	_draw_fire()
	_draw_spark()


## Whole-pixel bands of light lying on the ground under it, which is what tells the eye the
## lantern is a light source rather than a lit-up object.
func _draw_pool() -> void:
	if _fire <= 0.0:
		return
	var beat := 1.0 + sin(_flicker) * 0.05 + sin(_flicker * 2.7) * 0.03
	var reach := POOL_WIDTH * _fire * beat
	for step in range(3):
		var t := float(step) / 3.0
		var half := reach * (1.0 - t * 0.42)
		var alpha := (0.26 - t * 0.07) * clampf(_fire, 0.0, 1.0)
		draw_rect(Rect2(-half, -2.0 - float(step) * 2.0, half * 2.0, 2.0),
			Color(FLAME, alpha))


## The lit air around the window.
##
## ⚠ NOT `draw_circle`. The first cut of this drew four filled circles of low-alpha gold and
## it came out as a soft grey bubble hanging on the lantern -- a radial falloff is the one
## thing in this whole interface that is not pixel art, and against a bright terrace it read
## as a rendering fault rather than as light. Whole-pixel rings, stepped, breathing on the
## same clock as the flame.
func _draw_glow() -> void:
	if _fire <= 0.0:
		return
	var beat := 1.0 + sin(_flicker * 1.3) * 0.08
	var at := Vector2(0.0, -36.0)
	for ring in range(3):
		var reach := GLOW_RADIUS * 0.42 * _fire * beat * (0.45 + 0.34 * float(ring))
		var box := Rect2(at - Vector2(reach, reach * 0.72), Vector2(reach * 2.0, reach * 1.44))
		var alpha := (0.13 - 0.035 * float(ring)) * clampf(_fire, 0.0, 1.0)
		# Four one-pixel edges rather than an unfilled draw_rect, which strokes centred on
		# the boundary and lands on half pixels.
		draw_rect(Rect2(box.position.x, box.position.y, box.size.x, 1.0), Color(FLAME, alpha))
		draw_rect(Rect2(box.position.x, box.end.y - 1.0, box.size.x, 1.0), Color(FLAME, alpha))
		draw_rect(Rect2(box.position.x, box.position.y, 1.0, box.size.y), Color(FLAME, alpha))
		draw_rect(Rect2(box.end.x - 1.0, box.position.y, 1.0, box.size.y), Color(FLAME, alpha))


## The lantern itself: a plinth, a shaft, the fire box, a wide cap and a finial. Carved from
## the same grey the terrace walls are, so it belongs to the path rather than to the HUD.
func _draw_stone() -> void:
	var warm := clampf(_fire, 0.0, 1.0)
	# Facing edges catch the fire when it is burning. The stone itself never changes colour;
	# what changes is that there is now something lighting it.
	var lit_face := STONE_LIT.lerp(FLAME_CORE, 0.34 * warm)
	var body := STONE.lerp(FLAME_DEEP, 0.10 * warm)

	_block(Rect2(-15.0, -9.0, 30.0, 9.0), body, lit_face)      # plinth
	_block(Rect2(-11.0, -13.0, 22.0, 4.0), body, lit_face)     # plinth cap
	_block(Rect2(-6.0, -26.0, 12.0, 13.0), body, lit_face)     # shaft
	_block(Rect2(-13.0, -30.0, 26.0, 4.0), body, lit_face)     # the platform it stands on
	_block(Rect2(-11.0, -44.0, 22.0, 14.0), body, lit_face)    # the fire box
	_block(Rect2(-16.0, -49.0, 32.0, 5.0), body, lit_face)     # the cap
	_block(Rect2(-11.0, -52.0, 22.0, 3.0), body, lit_face)     # the cap's upper course
	_block(Rect2(-3.0, -HEIGHT, 6.0, 3.0), body, lit_face)     # the finial

	# Moss on the north side, because a stone that has stood on a terrace for a lifetime is
	# not a clean stone. Only on the plinth, where rain collects.
	draw_rect(Rect2(-15.0, -9.0, 5.0, 3.0), Color(MOSS, 0.7))
	draw_rect(Rect2(9.0, -7.0, 4.0, 2.0), Color(MOSS, 0.5))


## One carved block: an edge all the way round, a face, and a catch of light along the top
## and down the left, which is where the light in this game comes from.
func _block(box: Rect2, face: Color, lit_face: Color) -> void:
	draw_rect(box.grow(1.0), EDGE)
	draw_rect(box, face)
	draw_rect(Rect2(box.position, Vector2(box.size.x, 1.0)), lit_face)
	draw_rect(Rect2(box.position, Vector2(1.0, box.size.y)), lit_face)
	draw_rect(Rect2(box.position.x, box.end.y - 1.0, box.size.x, 1.0), STONE_DARK)


## The window, and what is in it. Cold it is a black slot with a stone mullion; lit it is a
## fire that moves, drawn as stacked whole-pixel rows so the flame steps rather than blurs.
func _draw_fire() -> void:
	var window := Rect2(-7.0, -42.0, 14.0, 11.0)
	draw_rect(window.grow(1.0), EDGE)
	if _fire <= 0.0:
		draw_rect(window, COLD)
		# The mullion, which is the detail that makes the dark slot read as an opening in a
		# stone rather than as a hole in the drawing.
		draw_rect(Rect2(-0.5, window.position.y, 1.0, window.size.y), STONE_DARK)
		return

	draw_rect(window, COLD)
	var strength := clampf(_fire, 0.0, 1.4)
	# The flame: rows narrowing toward the top, each one nudged by a whole pixel of flicker.
	var rows := int(clampf(roundf(9.0 * strength), 1.0, 10.0))
	for row in range(rows):
		var t := float(row) / 9.0
		var half := roundf(lerpf(5.0, 1.0, t * t) * strength)
		if half < 1.0:
			continue
		var sway := roundf(sin(_flicker * 1.7 + t * 3.1) * (1.0 + t * 1.6))
		var y := window.end.y - 1.0 - float(row)
		var tone := FLAME_DEEP if t < 0.18 else (FLAME if t < 0.62 else FLAME_CORE)
		draw_rect(Rect2(-half + sway, y, half * 2.0, 1.0), Color(tone, minf(1.0, strength)))
	# And the light thrown out of the opening onto the stone lip beneath it.
	draw_rect(Rect2(-8.0, -31.0, 16.0, 1.0), Color(FLAME_CORE, 0.5 * clampf(_fire, 0.0, 1.0)))


## The spark on its way from the player's hands. Drawn as a small cross rather than a dot so
## that at two screen pixels per art pixel it still reads as a light and not as dirt.
func _draw_spark() -> void:
	if not _sparking:
		return
	var at := _spark_at
	draw_rect(Rect2(at - Vector2(3.0, 0.5), Vector2(6.0, 1.0)), Color(FLAME_CORE, 0.9))
	draw_rect(Rect2(at - Vector2(0.5, 3.0), Vector2(1.0, 6.0)), Color(FLAME_CORE, 0.9))
	draw_rect(Rect2(at - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), Color(Color.WHITE, 0.9))
