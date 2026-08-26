class_name CheckpointFlag2D
extends Node2D
## The mark on the ground that says the level has remembered you.
##
## THERE WAS NOTHING HERE BEFORE. Checkpoints in Payyo were pure data -- an Area2D with no
## visual and a snapshot written into CheckpointManager -- so the one moment the game does
## something generous for the player was the one moment it said nothing at all. A player who
## slipped and reappeared partway up had to infer that a checkpoint existed from the fact
## that they had not lost everything.
##
## A FLAG ON A POST, because that is what a checkpoint has looked like since games had
## checkpoints, and a shape everyone already knows beats a clever one nobody does. Furled
## and grey until you reach it; raised and gold once you have. The two states are different
## SILHOUETTES, not just different colours -- at this size on a green terrace, colour alone
## is not a state change.
##
## THE APO RAISES IT. It used to hoist itself the instant the trigger fired, which is a
## checkpoint announcing itself rather than a player earning one. Now the cloth comes OFF
## the pole and travels to whoever walked in, is held for a beat while they take it, and
## then goes back up and unfurls -- three moves, and the middle one is the whole point. It
## costs nothing and it is the difference between a thing that happened and a thing you did.
##
## IT IS BAMBOO AND CLOTH, not a plastic banner. Payyo is a working terrace and everything
## planted in it is something a farmer would have: a bamboo pole with its nodes showing, a
## stone at the foot to keep it standing, and a strip of dyed cloth. The gold it turns is
## the game's own gold -- the same metal as Lola's brush -- because that is the colour this
## interface uses for "yours now".

## Raised, or still waiting. Setting it directly raises it with no ceremony, which is what a
## checkpoint restored from a save wants; `hoist()` is the version with the animation.
@export var raised: bool = false:
	set(value):
		if value == raised:
			return
		raised = value
		if value and not _hoisting:
			_settle()
		queue_redraw()

## How tall the pole stands. Small on purpose: the apo is 96 pixels and this is a marker
## beside the path, not a landmark.
const POLE_HEIGHT := 46.0
const POLE_WIDTH := 4.0
## Where the bamboo nodes fall, as a fraction of the pole. Two, unevenly spaced, because a
## bamboo cane's joints are not regular and evenly spaced ones read as a drawn ruler.
const NODES: Array[float] = [0.34, 0.68]

const BAMBOO := Color(0.639, 0.616, 0.353, 1.0)      # A39D5A
const BAMBOO_LIT := Color(0.784, 0.769, 0.494, 1.0)  # C8C47E
const BAMBOO_DARK := Color(0.396, 0.376, 0.196, 1.0) # 656032
const EDGE := Color(0.129, 0.106, 0.055, 1.0)        # 211B0E

## Waiting: undyed cloth, the colour of a rice sack, hanging down the pole.
const CLOTH := Color(0.612, 0.588, 0.502, 1.0)       # 9C9680
const CLOTH_DARK := Color(0.427, 0.408, 0.341, 1.0)  # 6D6857
## Reached: the interface's own gold, so the mark the level puts on the ground and the
## brush the player carries are the same metal.
const FLAG := UISkin.GOLD
const FLAG_LIT := UISkin.GOLD_PALE
const FLAG_DARK := UISkin.GILT_DARK

const STONE := Color(0.478, 0.443, 0.396, 1.0)       # 7A7165
const STONE_LIT := Color(0.596, 0.561, 0.502, 1.0)   # 988F80
const STONE_DARK := Color(0.290, 0.263, 0.227, 1.0)  # 4A433A

## The raise: the flag climbs the pole and the cloth snaps out. Driven by tweens through the
## setters, so the node has no idle work when nothing is happening.
var _lift := 0.0:
	set(value):
		_lift = value
		queue_redraw()
## How far the cloth is flying, 0 furled to 1 out. Separate from the lift so the climb and
## the snap can be shaped differently -- the pennant catches AFTER it is up, not during.
var _fly := 0.0:
	set(value):
		_fly = value
		queue_redraw()
## Where the cloth is while it is off the pole, in this node's space, and whether it is off
## it at all.
##
## THE FLAG IS TWO SEPARATE FACTS, and collapsing them into one was a bug worth keeping the
## note for: the first cut used Vector2.ZERO to mean "back on the pole", so the return leg
## tweened toward the ORIGIN -- which is the ground the pole is planted in. The cloth slid
## down to the stones and then snapped to the top. Position and off-the-pole-ness are
## independent, so they are two variables.
var _carried := false:
	set(value):
		_carried = value
		queue_redraw()
var _carry := Vector2.ZERO:
	set(value):
		_carry = value
		queue_redraw()
## How hard the pole is still ringing from the hoist, 0 to 1.
var _recoil := 0.0:
	set(value):
		_recoil = value
		queue_redraw()
## Sparks thrown when the pennant catches: [offset, age] pairs, aged by _process.
var _sparks: Array[Vector3] = []
var _hoisting := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)
	if raised:
		# Restored, not raised: a level reloaded at a checkpoint should open with the flag
		# already up rather than playing the moment again for a player who earned it before
		# the reload.
		_settle()
	queue_redraw()


## Up, with no ceremony. The state a restored checkpoint opens in.
func _settle() -> void:
	_lift = 1.0
	_fly = 1.0
	_carried = false


## THE THREE MOVES. `taker` is where the apo is standing, in this node's space -- the cloth
## goes to them, waits while they take it, and goes back up the pole.
##
## Every leg is a tween on a plain variable rather than on a child node's transform, so the
## whole animation is one _draw() reading four numbers. A flag built out of moving nodes
## would need the same four numbers anyway, plus the nodes.
func hoist(taker: Vector2) -> void:
	if _hoisting or raised:
		return
	_hoisting = true
	raised = true
	if not is_inside_tree():
		_settle()
		_hoisting = false
		return

	# Where the cloth goes to be taken: the apo's hands, which are about two thirds of the
	# way up a 96px child. Clamped in close so a flag reached from a distance does not go
	# sailing across the terrace to meet them.
	var hands := Vector2(clampf(taker.x, -34.0, 34.0), minf(taker.y - 58.0, -20.0))
	var furled := Vector2(0.0, -POLE_HEIGHT * 0.42)
	var masthead := Vector2(0.0, -POLE_HEIGHT + 4.0)

	_carry = furled
	_carried = true
	var run := create_tween()
	# 1. OFF THE POLE. Quick, and it dips before it goes -- a bundle pulled loose drops
	#    before the hand takes the weight.
	run.tween_property(self, "_carry", hands + Vector2(0.0, 10.0), 0.20) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	run.tween_property(self, "_carry", hands, 0.10) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 2. HELD. The beat that makes it a pick-up rather than a fly-past.
	run.tween_interval(0.22)
	# 3. BACK UP THE POLE -- to the MASTHEAD, which is where the pole ends, not to this
	#    node's origin, which is the ground it is planted in.
	run.tween_property(self, "_carry", masthead, 0.26) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# And the pennant catches once it is up there, not on the way.
	run.tween_callback(func() -> void:
		_carried = false
		_lift = 1.0)
	run.tween_callback(_catch)
	run.tween_property(self, "_fly", 1.0, 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	run.tween_callback(func() -> void: _hoisting = false)


## The moment it reaches the top: the pole rings, and the cloth throws sparks.
func _catch() -> void:
	var ring := create_tween()
	ring.tween_property(self, "_recoil", 1.0, 0.0)
	ring.tween_property(self, "_recoil", 0.0, 0.55).set_trans(Tween.TRANS_ELASTIC) \
		.set_ease(Tween.EASE_OUT)
	# Fixed offsets rather than randf(), so the burst is the same every time and a
	# screenshot of it can be compared with the last one.
	_sparks.clear()
	for index in range(7):
		var angle := TAU * (float(index) / 7.0) + 0.4
		_sparks.append(Vector3(cos(angle) * 13.0, sin(angle) * 9.0 - 4.0, 0.0))
	set_process(true)


func _process(delta: float) -> void:
	if _sparks.is_empty():
		set_process(false)
		return
	var alive: Array[Vector3] = []
	for spark in _sparks:
		var aged := spark.z + delta * 2.4
		if aged < 1.0:
			alive.append(Vector3(spark.x, spark.y, aged))
	_sparks = alive
	queue_redraw()


func _draw() -> void:
	# Everything is measured UP from this node's origin, which is the ground it is planted
	# in -- so the level places one by dropping it on a terrace rather than by working out
	# where its middle would be.
	_draw_stones()
	_draw_pole()
	_draw_cloth()
	_draw_sparks()


## The burst when the pennant catches. Whole-pixel squares travelling out and fading, which
## at this size reads as light coming off the cloth rather than as particles.
func _draw_sparks() -> void:
	for spark in _sparks:
		var age: float = spark.z
		var at := Vector2(spark.x, spark.y) * (0.4 + age * 1.5) \
			+ Vector2(0.0, -POLE_HEIGHT + 6.0)
		var size := 3.0 - age * 2.0
		if size <= 0.0:
			continue
		draw_rect(Rect2(at - Vector2(size, size) * 0.5, Vector2(size, size)),
			Color(FLAG_LIT, 1.0 - age))


## Three stones round the foot, holding it up. Uneven on purpose: a tidy ring of identical
## pebbles reads as a game object, a heap of three different ones reads as something
## somebody did with the stones that were there.
func _draw_stones() -> void:
	var feet := [
		Rect2(-11.0, -7.0, 9.0, 7.0),
		Rect2(3.0, -5.0, 8.0, 5.0),
		Rect2(-4.0, -9.0, 8.0, 9.0),
	]
	for index in range(feet.size()):
		var stone: Rect2 = feet[index]
		draw_rect(stone.grow(1.0), EDGE)
		draw_rect(stone, STONE if index != 2 else STONE_DARK)
		# The catch of light on top, on the left, where the light in this game comes from.
		draw_rect(Rect2(stone.position, Vector2(stone.size.x * 0.6, 2.0)), STONE_LIT)


## A bamboo cane: a shaft, a lit edge down the left, and two nodes across it.
func _draw_pole() -> void:
	# The ring after the hoist: the top of the shaft whips and the foot does not, so the
	# lean is scaled by height rather than applied to the whole pole.
	var whip := sin(_recoil * TAU * 1.5) * _recoil * 3.0
	var shaft := Rect2(-POLE_WIDTH * 0.5, -POLE_HEIGHT, POLE_WIDTH, POLE_HEIGHT)
	if absf(whip) >= 0.5:
		for row in range(int(POLE_HEIGHT)):
			var t := float(row) / (POLE_HEIGHT - 1.0)
			var y := -float(row)
			var x := -POLE_WIDTH * 0.5 + whip * t * t
			draw_rect(Rect2(x - 1.0, y - 1.0, POLE_WIDTH + 2.0, 1.0), EDGE)
			draw_rect(Rect2(x, y - 1.0, POLE_WIDTH, 1.0), BAMBOO)
			draw_rect(Rect2(x, y - 1.0, 1.0, 1.0), BAMBOO_LIT)
		return
	draw_rect(shaft.grow(1.0), EDGE)
	draw_rect(shaft, BAMBOO)
	draw_rect(Rect2(shaft.position, Vector2(1.0, shaft.size.y)), BAMBOO_LIT)
	draw_rect(Rect2(shaft.end.x - 1.0, shaft.position.y, 1.0, shaft.size.y), BAMBOO_DARK)
	for fraction in NODES:
		var y := -POLE_HEIGHT * fraction
		draw_rect(Rect2(-POLE_WIDTH * 0.5 - 1.0, y, POLE_WIDTH + 2.0, 2.0), BAMBOO_DARK)
		draw_rect(Rect2(-POLE_WIDTH * 0.5 - 1.0, y - 1.0, POLE_WIDTH + 2.0, 1.0), BAMBOO_LIT)


## The cloth. Two silhouettes: a furled strip hanging down the pole, and a pennant flying
## off it. `_lift` slides it up the pole and `_fly` opens it out.
func _draw_cloth() -> void:
	# Furled it hangs from a third of the way up; raised it sits just under the tip. While it
	# is being carried, `_carry` takes it off the pole entirely and puts it in the apo's
	# hands -- so the same two drawings serve all three moves of the hoist.
	var top := lerpf(-POLE_HEIGHT * 0.42, -POLE_HEIGHT + 4.0, _lift)
	var hoist := POLE_WIDTH * 0.5
	if _carried:
		top = _carry.y
	var carried := _carry.x if _carried else 0.0
	# It turns gold when it is TAKEN, not when it reaches the top -- the colour change is
	# the pick-up, and the unfurl at the top is the flourish on it.
	var gold := _lift > 0.0 or _carried
	var body := FLAG if gold else CLOTH
	var shade := FLAG_DARK if gold else CLOTH_DARK
	var lit := FLAG_LIT if gold else CLOTH

	if _fly <= 0.0:
		# FURLED: cloth BOUND ROUND THE POLE, tapering to a point, with a tie across it.
		#
		# The first cut drew a plain rectangle beside the pole, which came out as a grey
		# slab standing next to a stick -- two objects, neither of them a flag. Wrapping it
		# round the shaft and narrowing it toward the bottom is what makes the silhouette
		# read as one thing that is not open yet, which is the whole job of this state.
		var rows := 18
		for row in range(rows):
			var t := float(row) / float(rows - 1)
			var half := lerpf(3.5, 1.0, t * t)
			var y := top + float(row)
			draw_rect(Rect2(carried - half - 1.0, y, half * 2.0 + 2.0, 1.0), EDGE)
			draw_rect(Rect2(carried - half, y, half * 2.0, 1.0), body)
			draw_rect(Rect2(carried - half, y, 1.0, 1.0), shade)
		# The tie holding it shut. One band, off centre, because a flag is bound where the
		# hand reached rather than at its exact middle.
		draw_rect(Rect2(carried - 4.5, top + 5.0, 9.0, 2.0), EDGE)
		draw_rect(Rect2(carried - 4.0, top + 5.0, 8.0, 1.0), shade)
		return

	# FLYING: a swallowtail pennant, drawn as stacked rows so the notch in its trailing
	# edge is cut out of whole pixels rather than approximated by a polygon.
	var reach := 22.0 * _fly
	var rows := 14
	for row in range(rows):
		var t := float(row) / float(rows - 1)
		# The trailing edge is notched: full reach at top and bottom, cut back in the
		# middle, which is what makes this a pennant and not a rectangle.
		var notch := absf(t - 0.5) * 2.0
		var length := reach * (0.45 + 0.55 * notch)
		if length < 1.0:
			continue
		var y := top + float(row)
		draw_rect(Rect2(hoist, y, length + 1.0, 1.0), EDGE)
		draw_rect(Rect2(hoist, y, length, 1.0), body if row % 4 != 0 else shade)
	# The hoist edge, where the cloth is bound to the pole, and the catch of light along
	# the top of the fly.
	draw_rect(Rect2(hoist - 1.0, top, 2.0, float(rows)), shade)
	draw_rect(Rect2(hoist, top, reach * 0.5, 1.0), lit)
