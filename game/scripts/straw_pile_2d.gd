class_name StrawPile2D
extends Node2D
## A heap of cut cogon and rice straw, and the thing Node 2's three routes disagree about.
##
## CUT STRAW, NOT HARVESTED GRAIN, and that is a build constraint rather than a detail.
## Scattering someone's *tinawon* harvest across a terrace is not a neutral image to stage,
## and the Protector route below does exactly that -- straw keeps the picture and removes
## the problem. See the build spec's cultural guardrails.
##
## IT IS DRAWN AS STRANDS, and that is the whole difference from what was here before. A
## textured mound is a shape with straw printed on it; a heap of straw is hundreds of stalks
## thrown over one another, radiating from where the last armful was dropped on top. Only
## the second one has a silhouette that reads at a glance, and only the second one can have
## a HOLE in it -- which is what Node 2 needs, because "combed" and "tunnelled" were the
## same heap at two slightly different sizes and could not be told apart.
##
## Three ways to search it, and the pile remembers which:
##   comb    patient, section by section. The pile is left standing
##   tunnel  in underneath and out again. One hole, otherwise undisturbed
##   scatter fastest, and it does not go back. Lolo does not stop the player, and he
##           mentions it at the marker stone on the way out
##
## No collision. A shoulder-high pile of straw is something you push through, not something
## you climb, and a solid one would be a wall across the only route out of the level.

signal searched(how: String)
## The apo is standing in the mouth of a heap that has one, or has stepped back off it.
##
## IT IS NOT "SHE HAS GONE IN". The mouth sits on the path east -- Terrace5 is how you get
## to Node 3 -- so a heap that swallows anybody who walks past it is a hole in the floor of
## the level, and run_nodraw found exactly that: the bot's run east stopped dead at the
## doorway. Going in is a deliberate press; this only says the offer is there.
signal at_mouth(standing: bool)

enum State { INTACT, COMBED, TUNNELLED, SCATTERED }

@export var pile_size := Vector2(150.0, 96.0)
## Straw catches the light unevenly; a row of identical mounds reads as wallpaper. This
## multiplies the whole ramp, so a pile can be a shade greener or greyer than its neighbour
## without any of them leaving the same family of golds.
@export var tint := Color(1.0, 1.0, 1.0, 1.0)
## How many stalks. Scaled by the pile's own width so a big heap is not a sparse one.
@export var strand_density := 1.0
## THIS ONE HAS A WAY IN.
##
## One heap on the terrace is big enough to walk into and is hollow, and it is the only
## place in Level 1 with an inside. Standing in the mouth cuts the front of it away -- you
## are looking into the heap rather than at it -- which is why the pile has to be tall
## enough to stand up in: the apo is 96px, so a heap under about 190 has a mouth she has to
## crawl through and a cutaway with no headroom. run_level1_audit measures it.
@export var entrance := false

var _inside := false

## The golds, darkest to lightest. Straw is one hue and a dozen values of it: a heap with
## contrasting colours in it reads as a bonfire, which this is not.
##
## WHEAT, NOT NEON. The first cut of this was pure saturated yellow and sat on the terrace
## like a highlighter next to the tileset, which is warm and slightly dusty in everything it
## draws. These are the same golds pulled toward ochre.
const EDGE := Color(0.369, 0.227, 0.071, 1.0)   # 5E3A12  the shadow between clumps
const DARK := Color(0.588, 0.376, 0.118, 1.0)   # 96601E
const MID := Color(0.788, 0.541, 0.169, 1.0)    # C98A2B
const BODY := Color(0.929, 0.710, 0.227, 1.0)   # EDB53A
const LIT := Color(1.000, 0.843, 0.369, 1.0)    # FFD75E
const HI := Color(1.000, 0.941, 0.659, 1.0)     # FFF0A8  the catch on a stalk facing up
## Inside the heap, seen through a hole. Not black: it is straw in shade, and a black hole
## in a yellow mound reads as a bite taken out of it rather than as a way in.
const HOLLOW := Color(0.267, 0.145, 0.031, 1.0) # 442508
const HOLLOW_DEEP := Color(0.161, 0.086, 0.024, 1.0) # 291606
## The floor of the hollow: trodden earth, because a heap that has been crawled into has a
## worn floor and not a straw one. Same reasoning as the pool of light out of the doorways
## in the house -- it is the small untidy thing that says somebody has been here.
const EARTH := Color(0.235, 0.157, 0.098, 1.0)      # 3C2819
const EARTH_LIT := Color(0.337, 0.239, 0.153, 1.0)  # 563D27
const PEBBLE := Color(0.443, 0.404, 0.353, 1.0)     # 71675A

## Where the light comes from. Up and a little to the left, the same as the joinery in the
## house and the gilt on every frame in this game.
const LIGHT := Vector2(-0.35, -0.94)

var _state: int = State.INTACT


func _ready() -> void:
	add_to_group(&"straw_piles")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if entrance:
		_build_mouth_area()
	queue_redraw()


func is_inside() -> bool:
	return _inside


## Where the way in is, in the heap's own space: sitting on the ground, a little off centre
## because a hole worn in a heap of straw is not an architectural feature.
func mouth_rect() -> Rect2:
	var size := Vector2(pile_size.x * 0.46, pile_size.y * 0.62)
	return Rect2(Vector2(pile_size.x * -0.06 - size.x * 0.5, -size.y), size)


## The volume that notices the apo standing in the mouth. It is an Area2D and nothing else:
## the heap has no collision, deliberately, so walking in is walking in.
func _build_mouth_area() -> void:
	var area := Area2D.new()
	area.name = "Mouth"
	area.collision_layer = 0
	area.collision_mask = 1
	add_child(area)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	var mouth := mouth_rect()
	box.size = mouth.size
	shape.shape = box
	shape.position = mouth.get_center()
	area.add_child(shape)
	area.body_entered.connect(_on_mouth_body.bind(true))
	area.body_exited.connect(_on_mouth_body.bind(false))


func _on_mouth_body(body: Node, coming_in: bool) -> void:
	var node := body as Node
	while node != null:
		if node.is_in_group(&"player_character") or node is ActiveRagdollMorph:
			if _inside == coming_in:
				return
			_inside = coming_in
			queue_redraw()
			at_mouth.emit(coming_in)
			return
		node = node.get_parent()


func state() -> int:
	return _state


func is_disturbed() -> bool:
	return _state != State.INTACT


## Patient. The pile settles a little and stays standing.
func comb() -> void:
	if _state != State.INTACT:
		return
	_state = State.COMBED
	queue_redraw()
	searched.emit("comb")


## In underneath. One hole, and the top of the pile keeps its shape.
func tunnel() -> void:
	if _state != State.INTACT:
		return
	_state = State.TUNNELLED
	queue_redraw()
	searched.emit("tunnel")


## Gone, and it does not come back. The one route with a cost you can see.
func scatter() -> void:
	if _state == State.SCATTERED:
		return
	_state = State.SCATTERED
	queue_redraw()
	searched.emit("scatter")


## Put it back the way it was found.
##
## Nothing in the level calls this yet -- a checkpoint restore re-homes placed props and
## leaves the straw where the route left it, which is arguably right, since a route commit
## is written to a checkpoint and is not meant to be undone. It exists because the prop
## photographer has to take four pictures of one heap, and comb() and tunnel() both refuse
## to run on a pile that is not intact: it was calling them in order on the same three
## piles, so the frame labelled "tunnelled" has been a picture of a COMBED pile for as long
## as the node has existed. That is half of why the two were recorded as indistinguishable.
func restore_intact() -> void:
	_state = State.INTACT
	queue_redraw()


## How wide and how tall the heap stands in each state. Combed settles and tidies; tunnelled
## keeps its height because the hole is underneath it.
func _settle() -> Vector2:
	match _state:
		State.COMBED:
			return Vector2(0.88, 0.86)
		State.TUNNELLED:
			return Vector2(0.98, 0.96)
		_:
			return Vector2.ONE


## SEEDED FROM WHERE THE PILE STANDS, so the same heap draws the same way every frame and
## after a restored checkpoint. A heap that reshuffles on every redraw crawls, and a heap
## that reshuffles on a death is a different heap.
func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(position.x) * 7919.0 + absf(position.y) * 104729.0) | 1
	return rng


func _draw() -> void:
	if _state == State.SCATTERED:
		_draw_scattered()
		return
	if entrance and _inside:
		_draw_cutaway()
		return
	_draw_heap()


## The heap.
##
## DRAWN IN COLUMNS, ONE WORLD UNIT WIDE, and that is the whole of why this version sits on
## the terrace and the one before it did not. The first cut fanned hundreds of thin diagonal
## lines out of a crown: at any angle that is not 0 or 45 degrees a line has no pixel grid to
## sit on, so it came out as scratchy hairlines with ragged points all over the silhouette --
## spikey, and nothing like the tileset it stands next to.
##
## The tileset, and hub_room.gd, and every frame in this game are built the same way instead:
## axis-aligned runs, each with a lit edge and a shadow edge. So is this. Straw hangs, so the
## runs are vertical; the heap is a shaded dome of them, with clump seams cut down through it
## and a crown of short strands over the top where the last armful landed.
func _draw_heap() -> void:
	var settle := _settle()
	var half := pile_size.x * 0.5 * settle.x
	var high := pile_size.y * settle.y
	var rng := _rng()
	_draw_ground_shadow(half)
	_draw_columns(rng, half, high)
	_draw_clump_seams(rng, half, high)
	_draw_crown(rng, half, high)
	if entrance:
		var mouth := mouth_rect()
		_draw_mouth(rng, Vector2(mouth.get_center().x, 0.0),
			mouth.size.x * 0.5, mouth.size.y)
	elif _state == State.TUNNELLED:
		# WHAT A TUNNEL LOOKS LIKE. Combed and tunnelled were the same heap at two sizes
		# for as long as this node has existed, which made two of its three routes the same
		# route to look at.
		_draw_mouth(rng, Vector2(half * -0.14, 0.0), half * 0.5, high * 0.6)


## What stops it floating. Everything in the house that stands on the floor has one of these
## and the heaps did not.
func _draw_ground_shadow(half: float) -> void:
	draw_rect(Rect2(-half - 4.0, -3.0, half * 2.0 + 8.0, 5.0), Color(0.0, 0.0, 0.0, 0.30))
	draw_rect(Rect2(-half - 9.0, -1.0, half * 2.0 + 18.0, 3.0), Color(0.0, 0.0, 0.0, 0.16))


## How tall the heap is at `across`, -1 to 1. A bell rather than a half-ellipse: a heap of
## straw is dropped from the middle, so it is rounded over the top and flares at the foot.
func _profile(across: float) -> float:
	var t := clampf(absf(across), 0.0, 1.0)
	return pow(cos(t * PI * 0.5), 0.62)


## The body of it, a column at a time.
##
## Three things and no more: a lumpy outline, a shaded dome, and a grain of stalk ends.
##
## THE OUTLINE IS TUFTED, not smooth. A bell curve with per-column noise on it is still a
## bell curve -- the noise is one unit tall and invisible -- so the top edge is cut into
## tufts six to twelve units wide, each sitting at its own height. That is what makes the
## silhouette read as an armful of straw rather than as a loaf.
##
## THE GRAIN IS STALK ENDS. Each column is broken into short runs a value or two apart, and
## every column starts its run at a different offset, so the breaks stagger across the heap.
## Even runs would band it horizontally, which is the one thing straw never does.
func _draw_columns(rng: RandomNumberGenerator, half: float, high: float) -> void:
	var tuft_top := 0.0
	var tuft_left := -half - 1.0
	var tuft_width := 0.0
	var x := -half
	while x < half:
		if x >= tuft_left + tuft_width:
			tuft_left = x
			tuft_width = rng.randf_range(6.0, 12.0)
			tuft_top = rng.randf_range(-0.055, 0.03)
		var across := x / half
		var top := -high * (_profile(across) + tuft_top)
		if top > -3.0:
			x += 1.0
			continue
		# Left flank lit, right flank in shade, and the foot darker than the shoulder.
		var side := 0.74 - across * 0.46
		var phase := rng.randf_range(0.0, 6.0)
		var run := top + phase
		draw_rect(Rect2(x, top, 1.0, phase), _tone(_ramp(clampf(side + 0.2, 0.0, 1.0))))
		while run < 0.0:
			var depth := run / top if top < 0.0 else 0.0
			# THE FOOT IS IN SHADE. Straw hanging off a heap keeps almost none of the light
			# by the time it reaches the ground, and a dome lit evenly top to bottom is a
			# dome with no weight to it.
			var lit := clampf(side + depth * 0.52 - 0.36
				+ rng.randf_range(-0.11, 0.11), 0.0, 1.0)
			var step := rng.randf_range(3.0, 7.0)
			draw_rect(Rect2(x, run, 1.0, minf(step, -run)), _tone(_ramp(lit)))
			# The end of a stalk, one unit of shade where the next one starts behind it.
			if rng.randf() < 0.42 and run + step < 0.0:
				draw_rect(Rect2(x, run + step - 1.0, 1.0, 1.0), _tone(EDGE))
			run += step
		x += 1.0


## The seams between one armful and the next.
##
## THEY RADIATE, they do not hang plumb. Drawn as vertical rects they came out as a picket
## fence across the front of the heap; straw thrown on a pile falls away from where it
## landed, so a seam leans further from upright the further out it is. Each one is a dark
## line with a lit stalk beside it, which is the trick the joinery in the house uses to make
## a stile stand proud of a panel.
func _draw_clump_seams(rng: RandomNumberGenerator, half: float, high: float) -> void:
	var count := int(maxf(14.0, half / 3.4))
	var apex := Vector2(0.0, -high * 0.92)
	for index in range(count):
		var across := lerpf(-0.96, 0.96, (float(index) + rng.randf_range(0.15, 0.85))
			/ float(count))
		var foot := Vector2(roundf(half * across), -high * rng.randf_range(0.0, 0.16))
		var from := apex.lerp(foot, rng.randf_range(0.28, 0.72))
		_pixel_line(from, foot, _tone(EDGE))
		_pixel_line(from + Vector2(1.0, 3.0), foot + Vector2(1.0, -rng.randf_range(3.0, 12.0)),
			_tone(LIT if across < 0.05 else MID))
		# A stray or two hanging off the seam, because straw is not joinery.
		if rng.randf() < 0.45:
			var at := from.lerp(foot, rng.randf_range(0.3, 0.8))
			_pixel_line(at, at + Vector2(rng.randf_range(-5.0, 5.0),
				rng.randf_range(6.0, 18.0)), _tone(DARK))
	# And the line where the whole heap meets the ground.
	draw_rect(Rect2(-half, -5.0, half * 2.0, 5.0), _tone(EDGE))
	draw_rect(Rect2(-half, -7.0, half * 2.0, 2.0), _tone(DARK))


## The crown: the last armful, dropped on top and still splayed. Stepped rather than ruled --
## each strand is a stair of one-unit rects, so it lands on the same grid as everything else.
func _draw_crown(rng: RandomNumberGenerator, half: float, high: float) -> void:
	var count := int(maxf(22.0, half / 2.6))
	var apex := Vector2(roundf(half * rng.randf_range(-0.12, 0.12)), -high)
	for index in range(count):
		var angle := lerpf(PI * 0.86, PI * 0.14, (float(index) + rng.randf())
			/ float(count))
		var length := high * rng.randf_range(0.06, 0.22)
		var tip := apex + Vector2(-cos(angle), -sin(angle)) * length
		var lit := clampf(0.74 - (tip.x - apex.x) / maxf(1.0, half) * 0.5
			+ rng.randf_range(-0.1, 0.1), 0.0, 1.0)
		_pixel_line(apex, tip, _tone(_ramp(lit)))
		if rng.randf() < 0.45:
			_pixel_line(apex + Vector2(0.0, 1.0), tip + Vector2(0.0, 2.0), _tone(EDGE))


## A line as a stair of single units, so a strand at any angle still lands on whole pixels.
## draw_line does not: at anything off the axis or the diagonal it lays down a smear that is
## a value paler than what it is drawn in, which is exactly what made the first version of
## this look like scratches rather than art.
func _pixel_line(from: Vector2, to: Vector2, colour: Color) -> void:
	var at := Vector2(roundf(from.x), roundf(from.y))
	var end := Vector2(roundf(to.x), roundf(to.y))
	var delta := (end - at).abs()
	var step := Vector2(signf(end.x - at.x), signf(end.y - at.y))
	var error := delta.x - delta.y
	for guard in range(400):
		draw_rect(Rect2(at, Vector2.ONE), colour)
		if at.is_equal_approx(end):
			return
		var doubled := error * 2.0
		if doubled > -delta.y:
			error -= delta.y
			at.x += step.x
		if doubled < delta.x:
			error += delta.x
			at.y += step.y


## INSIDE THE HEAP, which is the one place in Level 1 that has an inside.
##
## The front of the heap is simply not drawn while the apo is standing in it: what is left
## is the hollow, its two straw walls, the straw hanging off the roof of it, and a floor of
## trodden earth. It is a cutaway rather than a room somewhere else, so the terrace, the
## sky and the other two heaps stay exactly where they were and the apo never leaves the
## world -- which is also why nothing here needs collision, a second camera or a way back.
func _draw_cutaway() -> void:
	var half := pile_size.x * 0.5
	var high := pile_size.y
	var rng := _rng()
	draw_colored_polygon(_silhouette(half, high), _tone(HOLLOW_DEEP))
	_draw_hollow_wall(rng, half, high, -1.0)
	_draw_hollow_wall(rng, half, high, 1.0)
	_draw_hollow_roof(rng, half, high)
	_draw_hollow_floor(rng, half)


## One wall of the hollow: straw hanging from the crown down the inside of the heap, lit on
## the edge nearest the opening because that is where the light is coming from.
func _draw_hollow_wall(rng: RandomNumberGenerator, half: float, high: float,
		side: float) -> void:
	var count := int(maxf(40.0, 70.0 * strand_density * (half / 75.0)))
	for index in range(count):
		var across := lerpf(0.30, 1.04, (float(index) + rng.randf()) / float(count))
		var x := side * half * across
		var top := -high * rng.randf_range(0.72, 1.0) * (1.0 - (across - 0.3) * 0.35)
		var drop := absf(top) * rng.randf_range(0.55, 1.05)
		# Inner stalks catch the daylight coming in the mouth; the ones deep in the corner
		# do not. That gradient is the only thing making this read as a space with a
		# near side and a far side.
		var lit := clampf(1.05 - across + rng.randf_range(-0.16, 0.16), 0.0, 1.0)
		draw_line(Vector2(x + side * rng.randf_range(-3.0, 3.0), top),
			Vector2(x + rng.randf_range(-7.0, 7.0), top + drop),
			_tone(_ramp(lit)), 3.0 if rng.randf() < 0.2 else 2.0, false)


## The roof of it, so the top of the hollow is straw hanging down rather than a cut edge.
func _draw_hollow_roof(rng: RandomNumberGenerator, half: float, high: float) -> void:
	var count := int(maxf(30.0, 60.0 * strand_density * (half / 75.0)))
	for index in range(count):
		var across := lerpf(-0.72, 0.72, (float(index) + rng.randf()) / float(count))
		# SHORT, AND SPARSE IN THE MIDDLE. Long stalks hanging down the centre read as bars
		# across the opening rather than as the underside of a roof, and the middle of the
		# hollow is the part that has to stay dark and empty -- it is where the player is
		# standing and where everything worth looking at is going to be.
		if absf(across) < 0.34 and rng.randf() < 0.7:
			continue
		var x := half * across
		var top := -high * (0.88 - absf(across) * 0.24)
		draw_line(Vector2(x, top), Vector2(x + rng.randf_range(-5.0, 5.0),
			top + high * rng.randf_range(0.03, 0.13)),
			_tone(_ramp(rng.randf_range(0.1, 0.45))), 2.0, false)


## Trodden earth, with what has been walked into it.
func _draw_hollow_floor(rng: RandomNumberGenerator, half: float) -> void:
	draw_rect(Rect2(-half, -13.0, half * 2.0, 13.0), EARTH)
	draw_rect(Rect2(-half, -13.0, half * 2.0, 3.0), EARTH_LIT)
	for index in range(int(half * 0.5)):
		var at := Vector2(rng.randf_range(-half * 0.94, half * 0.94),
			rng.randf_range(-11.0, -2.0))
		var wide := rng.randf_range(2.0, 5.0)
		draw_rect(Rect2(at, Vector2(wide, maxf(2.0, wide * 0.6))),
			PEBBLE if rng.randf() < 0.4 else EARTH_LIT)
	# A few stalks trodden into the floor, so the two materials meet rather than abut.
	for index in range(int(half * 0.3)):
		var at := Vector2(rng.randf_range(-half, half), rng.randf_range(-12.0, -1.0))
		draw_line(at, at + Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(-3.0, 2.0)),
			_tone(_ramp(rng.randf_range(0.2, 0.6))), 2.0, false)


## The body under the stalks. A half-ellipse, sampled coarsely: it never has to look like
## anything on its own, it only has to stop the terrace showing between the stalks.
func _silhouette(half: float, high: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := 22
	for index in range(steps + 1):
		var phi := PI * float(index) / float(steps)
		points.append(Vector2(-half * cos(phi) * 0.94, -high * sin(phi) * 0.92))
	points.append(Vector2(half, 0.0))
	points.append(Vector2(-half, 0.0))
	return points


## A hole in the heap, and the way into it.
##
## DRAWN AFTER THE STALKS AND THEN FRINGED. A dark arch on its own is a shape painted on the
## front of the pile; what says "this goes in" is the handful of stalks still hanging across
## the top of it, in front of the dark. Same reason a doorway in the house has an architrave.
func _draw_mouth(rng: RandomNumberGenerator, at: Vector2, half: float, high: float) -> void:
	var arch := PackedVector2Array()
	var steps := 16
	for index in range(steps + 1):
		var phi := PI * float(index) / float(steps)
		var wobble := rng.randf_range(0.9, 1.1)
		arch.append(at + Vector2(-half * cos(phi) * wobble, -high * sin(phi) * wobble))
	draw_colored_polygon(arch, _tone(HOLLOW))
	var inner := PackedVector2Array()
	for index in range(steps + 1):
		var phi := PI * float(index) / float(steps)
		inner.append(at + Vector2(-half * 0.66 * cos(phi), -high * 0.7 * sin(phi)))
	draw_colored_polygon(inner, _tone(HOLLOW_DEEP))
	# The fringe: stalks hanging over the opening, in front of the dark.
	for index in range(int(half * 0.34)):
		var x := at.x + rng.randf_range(-half, half)
		var top := at.y - high * (0.35 + 0.55 * rng.randf())
		var drop := high * rng.randf_range(0.18, 0.55)
		draw_line(Vector2(x, top), Vector2(x + rng.randf_range(-4.0, 4.0), top + drop),
			_tone(_ramp(rng.randf_range(0.15, 0.55))), 2.0, false)


## What is left after the wind: loose handfuls across the terrace, which is the whole
## point of the Protector cost being visible rather than described.
func _draw_scattered() -> void:
	var rng := _rng()
	# LOOSE HANDFULS, not a few scratches. It has to read from across the terrace as the
	# heap having been pulled apart, because it is the only one of the three routes whose
	# cost the player can see, and Lolo brings it up again at the marker stone.
	for index in range(int(150.0 * strand_density)):
		var across := rng.randf_range(-1.0, 1.0)
		# Thickest where the heap stood and thinning outward, the way thrown straw lands.
		var at := Vector2(across * pile_size.x * 1.25,
			rng.randf_range(-11.0, 1.0) * (1.0 - absf(across) * 0.6))
		var run := Vector2(rng.randf_range(-24.0, 24.0), rng.randf_range(-8.0, 2.0))
		draw_line(at, at + run, _tone(_ramp(rng.randf_range(0.3, 1.0))),
			3.0 if rng.randf() < 0.2 else 2.0, false)


## Six values of one gold. `lit` is how much of the light a stalk is catching, 0 to 1.
func _ramp(lit: float) -> Color:
	var ramp: Array[Color] = [EDGE, DARK, MID, BODY, LIT, HI]
	return ramp[int(round(clampf(lit, 0.0, 1.0) * float(ramp.size() - 1)))]


func _tone(colour: Color) -> Color:
	return colour * tint
