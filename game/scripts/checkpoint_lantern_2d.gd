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

## ⚠ THE ROCK IS NOT THE SAME ROCK IN EVERY LEVEL, and it used to be.
##
## This was carved out of the Cordillera terrace walls, which is right where it was born and
## wrong the moment it was planted anywhere else: two cold grey bollards standing in a Cebu
## church plaza in full sun, next to a painting made of ochre, coral and Sinulog red. Nothing
## about the lantern was wrong except its colour, and a colour is not worth a second class.
##
## A LEVEL SETS THIS BY META, NOT BY CODE. `plant()` walks up from wherever it is standing
## looking for `checkpoint_stone` / `checkpoint_moss` on an ancestor -- normally the
## environment scene's root -- so a level re-skins its checkpoints in the .tscn, next to the
## marks they stand on. No static, because a static would follow the player back to Level 1;
## no argument, because `plant` is called from three places and two of them are generic.
@export var stone_tone := Color(0.443, 0.435, 0.412, 1.0)   # 716F69, Cordillera grey
## The moss. ALPHA ZERO MEANS NONE -- a stone that has stood on a terrace for a lifetime is
## not a clean stone, but a lamp on a swept plaza on the morning of the fiesta is.
@export var moss_tone := Color(0.318, 0.376, 0.239, 1.0)    # 51603D

## ⚠ AND UNDER THE SEA IT IS NOT A LANTERN AT ALL. A fire burning on the seabed is not a thing,
## which is why Dagat's encounter used to have no mark: the checkpoint was written, a line said
## so, and there was nothing to see. There it is a GIANT CLAM -- a taklobo, the Philippine seas'
## own -- and it keeps the lantern's whole grammar: shut and dull until it is reached, then it
## opens, and what was a fire is a pearl giving off the same gold, with light lying on the sand
## under it and bubbles rising off it for the rest of the level. The spark the player carries
## to it is a bubble. Chosen by plant(), from where it stands -- see under_the_sea.gd.
enum Form { LANTERN, CLAM }
var form: int = Form.LANTERN
const UnderTheSea = preload("res://scripts/under_the_sea.gd")
const GroundShadow = preload("res://scripts/ground_shadow.gd")

## The clam's own colours: a shell weathered pale enough to read against the dark seabed, and
## the mantle a taklobo shows when it opens -- blue and turquoise, spotted.
const SHELL_EDGE := Color(0.106, 0.110, 0.188, 1.0)   # 1B1C30
const SHELL_DARK := Color(0.255, 0.255, 0.388, 1.0)   # 414163
const SHELL := Color(0.435, 0.427, 0.569, 1.0)        # 6F6D91
const SHELL_LIT := Color(0.635, 0.624, 0.753, 1.0)    # A29FC0
const SHELL_HI := Color(0.831, 0.820, 0.906, 1.0)     # D4D1E7
const MANTLE_DEEP := Color(0.043, 0.271, 0.400, 1.0)  # 0B4566
const MANTLE := Color(0.118, 0.518, 0.667, 1.0)       # 1E84AA
const MANTLE_LIT := Color(0.337, 0.808, 0.878, 1.0)   # 56CEE0
const MANTLE_SPOT := Color(0.667, 0.945, 0.965, 1.0)  # AAF1F6
const BARNACLE := Color(0.769, 0.780, 0.769, 1.0)     # C4C7C4
const WEED := Color(0.200, 0.459, 0.337, 1.0)         # 337556
const BUBBLE_RIM := Color(0.749, 0.945, 1.0, 1.0)     # BFF1FF
## Half the clam's width, how far its lid lifts when it is open, and how many ribs it is folded
## into, in art pixels. 38 art pixels is 76 across in the world -- about a metre at the house's
## ruler of 72 to the metre, which is a giant clam and not a shell on the beach.
const CLAM_HALF := 19
const CLAM_LIFT := 9.0
const CLAM_RIBS := 5.0
## Rows of the lower valve and of the lid. The lips meet in the two rows between them.
const LOWER_ROWS := 10
const LID_ROWS := 8
## Behind the creature and the jars, in front of the painted seabed: the coral pieces stand at
## 3, and a checkpoint the bakunawa swims over should be under it, not pinned on top of it.
const CLAM_Z := 3

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


## The stone, taken down into shade or up into the light. Multiplying below one and going
## toward white above it, so a warm stone stays warm in both directions.
func _stone(scale: float) -> Color:
	if scale <= 1.0:
		return Color(stone_tone.r * scale, stone_tone.g * scale, stone_tone.b * scale, 1.0)
	return stone_tone.lerp(Color(1.0, 1.0, 1.0, 1.0), minf(scale - 1.0, 1.0))


## The level's own rock, if it has an opinion. Walked up the tree rather than read off a
## fixed node, because a lantern is planted under a checkpoint area in one level and under an
## obstacle volume in another, and neither of them is a place to put a level's palette.
static func _skin_from(node: Node) -> Dictionary:
	var walk := node
	while walk != null:
		if walk.has_meta(&"checkpoint_stone") or walk.has_meta(&"checkpoint_moss"):
			return {
				"stone": walk.get_meta(&"checkpoint_stone", null),
				"moss": walk.get_meta(&"checkpoint_moss", null),
			}
		walk = walk.get_parent()
	return {}


## Stand one at `at` in `parent`'s space, on whatever turns out to be underneath it.
static func plant(parent: Node2D, at: Vector2, lit_already: bool = false) -> CheckpointLantern2D:
	if parent == null or not is_instance_valid(parent):
		return null
	var lantern := CheckpointLantern2D.new()
	lantern.name = "Checkpoint"
	lantern.position = at
	lantern.z_index = LANTERN_Z
	lantern.lit = lit_already
	var skin := _skin_from(parent)
	if skin.get("stone") != null:
		lantern.stone_tone = Color(skin["stone"])
	if skin.get("moss") != null:
		lantern.moss_tone = Color(skin["moss"])
	parent.add_child(lantern)
	if UnderTheSea.holds(lantern):
		lantern.form = Form.CLAM
		lantern.z_index = CLAM_Z
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
	# ⚠ ON THE SEABED THE GROUND IS FURTHER DOWN. A lantern looks 260 below where it was planted,
	# which on a terrace is the ledge it stands on; a clam is planted in the middle of the water
	# column, where the bottom is five hundred below. It looks down to the bottom of the water.
	var probe := GROUND_PROBE
	if form == Form.CLAM:
		var depth := UnderTheSea.depth_below(self, global_position)
		if is_finite(depth):
			probe = maxf(GROUND_PROBE, depth + LOOK_UP + 40.0)
	for nudge in SWEEP:
		var from := global_position + Vector2(nudge, -LOOK_UP)
		var query := PhysicsRayQueryParameters2D.create(
			from, from + Vector2(0.0, probe))
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
	var window := _heart()
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
	PickupFlourish2D.burst(self, _heart() * UNIT, FLAME_CORE)


## Where the light lives, in art pixels: the lantern's window, or the clam's pearl.
func _heart() -> Vector2:
	if form == Form.CLAM:
		return Vector2(0.0, -float(LOWER_ROWS) - 3.0)
	return Vector2(0.0, -35.0)


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
	if form == Form.CLAM:
		GroundShadow.draw(self, float(CLAM_HALF) + 4.0, 2.0, 0.55)
		_draw_pool()
		_draw_clam()
		_draw_glow(_heart() - Vector2(0.0, 1.0))
		_draw_bubbles()
		_draw_spark()
		return
	# Under the plinth's footprint, which runs back DEPTH pixels up and to the right.
	GroundShadow.draw(self, 18.0 + DEPTH * 0.5, 2.0, 0.5, Vector2(DEPTH * 0.5, -DEPTH * 0.5))
	_draw_pool()
	_draw_glow(Vector2(0.0, -36.0))
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
func _draw_glow(at: Vector2) -> void:
	if _fire <= 0.0:
		return
	var beat := 1.0 + sin(_flicker * 1.3) * 0.08
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
	var lit_face := _stone(1.28).lerp(FLAME_CORE, 0.34 * warm)
	var body := stone_tone.lerp(FLAME_DEEP, 0.10 * warm)

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
	if moss_tone.a > 0.0:
		draw_rect(Rect2(-15.0, -9.0, 5.0, 3.0), Color(moss_tone, moss_tone.a * 0.7))
		draw_rect(Rect2(9.0, -7.0, 4.0, 2.0), Color(moss_tone, moss_tone.a * 0.5))


## ⚠ HOW DEEP A CARVED BLOCK IS, AND WHY IT HAS ANY DEPTH. Each block was a flat face with a
## one-pixel catch of light along its top and left -- a stone lantern drawn as a paper cut-out,
## which is what Kent's "how 3d they are" was looking at. Seen a little from above and to the
## left, a block shows a top face going back up to the right, lit because it faces the sky, and
## its right side in shade. Three art pixels of it.
const DEPTH := 3.0


## One carved block: the outline of the whole solid, its top face in the light, its right side
## in shade, then the front face with a catch of light along its top and left edges.
func _block(box: Rect2, face: Color, lit_face: Color) -> void:
	var outline := _stone(0.25)
	var depth := int(DEPTH)
	draw_rect(box.grow(1.0), outline)
	for step in range(1, depth + 1):
		var back := float(step)
		draw_rect(Rect2(box.position.x + back - 1.0, box.position.y - back - 1.0,
			box.size.x + 2.0, 3.0), outline)
		draw_rect(Rect2(box.end.x + back - 2.0, box.position.y - back - 1.0,
			3.0, box.size.y + 2.0), outline)
	for step in range(1, depth + 1):
		var back := float(step)
		draw_rect(Rect2(box.position.x + back, box.position.y - back, box.size.x, 1.0),
			lit_face if step < depth else lit_face.lerp(face, 0.3))
		draw_rect(Rect2(box.end.x - 1.0 + back, box.position.y - back, 1.0, box.size.y),
			_stone(0.66).lerp(face, 0.15 * float(step)))
	draw_rect(box, face)
	draw_rect(Rect2(box.position, Vector2(box.size.x, 1.0)), face.lerp(lit_face, 0.6))
	draw_rect(Rect2(box.position, Vector2(1.0, box.size.y)), lit_face)
	draw_rect(Rect2(box.position.x, box.end.y - 1.0, box.size.x, 1.0), _stone(0.61))


## The window, and what is in it. Cold it is a black slot with a stone mullion; lit it is a
## fire that moves, drawn as stacked whole-pixel rows so the flame steps rather than blurs.
func _draw_fire() -> void:
	var window := Rect2(-7.0, -42.0, 14.0, 11.0)
	draw_rect(window.grow(1.0), _stone(0.25))
	if _fire <= 0.0:
		draw_rect(window, COLD)
		# The mullion, which is the detail that makes the dark slot read as an opening in a
		# stone rather than as a hole in the drawing.
		draw_rect(Rect2(-0.5, window.position.y, 1.0, window.size.y), _stone(0.61))
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
	if form == Form.CLAM:
		# A bubble, carried down to it: a ring with a glint, the way the sea draws a light.
		_bubble(at.round(), 2, 0.95)
		return
	draw_rect(Rect2(at - Vector2(3.0, 0.5), Vector2(6.0, 1.0)), Color(FLAME_CORE, 0.9))
	draw_rect(Rect2(at - Vector2(0.5, 3.0), Vector2(1.0, 6.0)), Color(FLAME_CORE, 0.9))
	draw_rect(Rect2(at - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), Color(Color.WHITE, 0.9))


## ⚠ THE CLAM, drawn out of whole art pixels like the lantern. Everything is measured up from
## the sand it sits in. `_fire` is how far open it is: shut at 0, open at 1, and the lantern's
## overshoot as it catches is the lid springing a pixel past open and settling back.
##
## ⚠ RIBS THAT FAN, AND LIPS THAT INTERLOCK. The first cut shaded ribs at a fixed width, and a
## shell of straight vertical stripes read as a barrel. A clam's ribs run out from its hinge, so
## here they are measured across each row rather than across the world: five of them in every
## row, converging where the row narrows. And a taklobo is known by its wavy mouth -- the lower
## lip rises to a point at each rib and the lid's lip drops between them, so shut, the seam is a
## zig-zag of light and dark; open, the same teeth frame the mantle.
func _draw_clam() -> void:
	var open := clampf(_fire, 0.0, 1.15)
	var lift := roundf(CLAM_LIFT * open)
	var lean := -roundf(2.0 * clampf(open, 0.0, 1.0))
	var lid_rows := LID_ROWS - int(roundf(2.0 * clampf(open, 0.0, 1.0)))
	var lid_bottom := -float(LOWER_ROWS) - 3.0 - lift
	_draw_lower_valve()
	if lift >= 1.0:
		_draw_mantle(lid_bottom)
	_draw_lower_teeth()
	if lift >= 1.0:
		_draw_pearl(open)
	_draw_lid(lid_bottom, lid_rows, lean)
	# Two barnacles on the lid and a tuft of weed at its foot: it has sat here a long time.
	draw_rect(Rect2(-11.0 + lean, lid_bottom - 5.0, 2.0, 2.0), BARNACLE)
	draw_rect(Rect2(-11.0 + lean, lid_bottom - 5.0, 1.0, 1.0), SHELL_HI)
	draw_rect(Rect2(6.0 + lean, lid_bottom - 6.0, 2.0, 1.0), BARNACLE)
	draw_rect(Rect2(-4.0, -4.0, 2.0, 1.0), BARNACLE)
	var sway := roundf(sin(_flicker * 0.35) * clampf(open, 0.0, 1.0))
	draw_rect(Rect2(float(CLAM_HALF) - 3.0, -4.0, 1.0, 4.0), WEED)
	draw_rect(Rect2(float(CLAM_HALF) - 2.0 + sway, -7.0, 1.0, 3.0), WEED)
	draw_rect(Rect2(float(CLAM_HALF) - 1.0 + sway, -10.0, 1.0, 3.0), WEED)
	draw_rect(Rect2(-float(CLAM_HALF) + 1.0, -3.0, 1.0, 3.0), WEED)


## Where across the ribs `x` is, 0..CLAM_RIBS, measured against this row's own half-width -- so
## the ribs converge where the shell narrows, and fan where it is wide.
func _rib(x: float, half: float) -> float:
	return clampf((x / maxf(1.0, half) + 1.0) * 0.5 * CLAM_RIBS, 0.0, CLAM_RIBS - 0.001)


## One pixel of rib: lit on its left, where the light comes from, in shade on its right.
func _rib_colour(x: float, half: float, lighter: int) -> Color:
	var across := fposmod(_rib(x, half), 1.0)
	var step := 0 if across < 0.34 else (1 if across < 0.7 else 2)
	var ramp: Array[Color] = [SHELL_EDGE, SHELL_DARK, SHELL, SHELL_LIT, SHELL_HI]
	return ramp[clampi(3 - step + lighter, 0, ramp.size() - 1)]


## The bowl, widest at its lip and narrowing to the sand, darkest where it sits in it.
func _draw_lower_valve() -> void:
	for r in range(LOWER_ROWS):
		var t := float(r) / (float(LOWER_ROWS) + 0.5)
		var half := roundf(float(CLAM_HALF) * sqrt(maxf(0.0, 1.0 - t * t)))
		var y := -float(LOWER_ROWS) + float(r)
		var lighter := -1 if r >= LOWER_ROWS - 3 else 0
		for x in range(int(-half), int(half) + 1):
			var colour := SHELL_EDGE if absf(float(x)) >= half else _rib_colour(float(x), half, lighter)
			draw_rect(Rect2(float(x), y, 1.0, 1.0), colour)
	draw_rect(Rect2(-float(CLAM_HALF) + 6.0, -1.0, float(CLAM_HALF) * 2.0 - 11.0, 1.0), SHELL_EDGE)


## The lower lip's teeth: two pixels up at the middle of every rib, none at its edges, lit.
func _draw_lower_teeth() -> void:
	var lip := -float(LOWER_ROWS)
	for x in range(-CLAM_HALF + 1, CLAM_HALF):
		var f := fposmod(_rib(float(x), float(CLAM_HALF)), 1.0)
		var bump := int(roundf(2.0 * (1.0 - absf(2.0 * f - 1.0))))
		for k in range(bump):
			draw_rect(Rect2(float(x), lip - 1.0 - float(k), 1.0, 1.0),
				SHELL_HI if k == bump - 1 else SHELL_LIT)


## The lid, a dome over the bowl, with its own teeth hanging between the lower lip's -- offset
## half a rib, which is what makes the two interlock.
func _draw_lid(bottom: float, rows: int, lean: float) -> void:
	for r in range(rows):
		var t := float(r) / (float(rows) + 0.5)
		var half := roundf(float(CLAM_HALF) * sqrt(maxf(0.0, 1.0 - t * t)))
		var y := bottom - float(r)
		var lighter := 1 if r >= rows - 3 else 0
		for x in range(int(-half), int(half) + 1):
			var colour := SHELL_EDGE if absf(float(x)) >= half else _rib_colour(float(x), half, lighter)
			if r == rows - 1:
				colour = SHELL_EDGE
			draw_rect(Rect2(float(x) + lean, y, 1.0, 1.0), colour)
	for x in range(-CLAM_HALF + 1, CLAM_HALF):
		var f := fposmod(_rib(float(x), float(CLAM_HALF)) + 0.5, 1.0)
		var drop := int(roundf(2.0 * (1.0 - absf(2.0 * f - 1.0))))
		for k in range(drop):
			draw_rect(Rect2(float(x) + lean, bottom + 1.0 + float(k), 1.0, 1.0),
				SHELL_EDGE if k == drop - 1 else SHELL_DARK)


## The inside, which is only there while it is open: the mantle filling the gap between the
## lips, dark at the back and lit at the front, spotted the way a giant clam's is.
func _draw_mantle(lid_bottom: float) -> void:
	var low := -float(LOWER_ROWS) - 1.0
	var high := lid_bottom + 2.0
	var rows := int(low - high) + 1
	for r in range(rows):
		var y := low - float(r)
		var half := CLAM_HALF - 2 - int(float(r) * 0.25)
		for x in range(-half, half + 1):
			var wave := sin(float(x) * 0.7 + float(r) * 1.3 + _flicker * 0.25)
			var colour := MANTLE
			if r >= rows - 2:
				colour = MANTLE_DEEP
			elif wave > 0.5:
				colour = MANTLE_LIT
			if (x * 5 + r * 3 + 40) % 11 == 0:
				colour = MANTLE_SPOT
			draw_rect(Rect2(float(x), y, 1.0, 1.0), colour)


## The pearl on the lip at the front of the mantle: the fire's gold, and the same breathing.
func _draw_pearl(open: float) -> void:
	if open < 0.3:
		return
	var at := _heart()
	var core := FLAME_CORE.lerp(Color.WHITE, 0.15 + 0.1 * sin(_flicker))
	var shape := [[-1, 1], [-2, 2], [-3, 3], [-3, 3], [-3, 3], [-2, 2], [-1, 1]]
	for index in range(shape.size()):
		var span: Array = shape[index]
		var y := at.y - 3.0 + float(index)
		for x in range(int(span[0]), int(span[1]) + 1):
			var colour := core
			if (x >= 1 and index >= 4) or index == shape.size() - 1:
				colour = FLAME
			draw_rect(Rect2(at.x + float(x), y, 1.0, 1.0), colour)
	draw_rect(Rect2(at.x - 1.0, at.y - 2.0, 1.0, 1.0), Color.WHITE)
	draw_rect(Rect2(at.x - 2.0, at.y - 1.0, 1.0, 1.0), Color.WHITE)


## Bubbles, rising off it forever once it is open -- the sea's version of the fire that never
## stops, and the thing that makes it findable from across the seabed on the way back.
func _draw_bubbles() -> void:
	if _fire <= 0.3:
		return
	var from := _heart()
	for index in range(3):
		var phase := float(index) * 0.37
		var rise := fposmod(_flicker * 0.11 + phase, 1.0)
		var y := from.y - 3.0 - rise * 34.0
		var x := from.x + roundf(sin(_flicker * 0.5 + float(index) * 2.1) * 2.0) \
			+ float(index - 1) * 3.0
		_bubble(Vector2(x, roundf(y)), 1 if index != 1 else 2, (1.0 - rise) * 0.85)


func _bubble(at: Vector2, radius: int, alpha: float) -> void:
	if alpha <= 0.02:
		return
	var rim := Color(BUBBLE_RIM, alpha)
	var r := float(radius)
	draw_rect(Rect2(at.x - r, at.y - r - 1.0, r * 2.0 + 1.0, 1.0), rim)
	draw_rect(Rect2(at.x - r, at.y + r + 1.0, r * 2.0 + 1.0, 1.0), rim)
	draw_rect(Rect2(at.x - r - 1.0, at.y - r, 1.0, r * 2.0 + 1.0), rim)
	draw_rect(Rect2(at.x + r + 1.0, at.y - r, 1.0, r * 2.0 + 1.0), rim)
	draw_rect(Rect2(at.x - r + 1.0, at.y - r, 1.0, 1.0), Color(Color.WHITE, alpha))
