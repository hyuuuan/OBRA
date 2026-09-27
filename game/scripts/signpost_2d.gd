class_name Signpost2D
extends Node2D
## A small wooden sign standing where the game is going to say something.
##
## WHY THE MAP NEEDS THEM. Every conversation in this level is triggered by walking into an
## Area2D that is invisible -- the obstacles, the route decision at the gorge, the bulul, the
## chest with the sketchbook page in it. A player who does not know they are there has no
## way to tell a stretch of terrace where something happens from a stretch where nothing
## does, so a beat they walked past reads as a beat that is not in the game. The triggers
## themselves cannot be shown: they are boxes three hundred pixels tall, and drawing one
## would be drawing the machinery rather than the promise.
##
## A sign is the promise. It is small, it stands on the ground where the trigger is, and it
## says only "there is something here" -- and what KIND of something, from four glyphs, so
## that walking toward a memory feels different from walking toward a choice.
##
## IT IS SCENERY AND CARRIES NO COLLISION. Nothing about the level's solution changes
## because a sign is next to it: it is not climbable, not choppable and not a platform, and
## nothing reads its position. Planted by the node it belongs to, in that node's `_ready`,
## so a beat that moves takes its sign with it and one that is deleted takes its sign away.

## What the board says. Five, because there are five kinds of moment in this level and a
## player can learn five shapes without being taught them.
##
## STORY AND HINT ARE THE TWO CHANNELS THE GAME ALREADY HAS. A beat of story goes to the
## framed DialogueBox -- the world stops, somebody speaks, the player presses a key. A hint
## goes to the HintBar -- no key, no pause, it clears itself. dialogue_script.kind_of has
## sorted every line in the game into one or the other for as long as there has been a
## script, and the signs had been flattening both into a single speech bubble, which told
## the player that a place where Lola is remembered and a place where a stair is broken
## are the same kind of place.
enum Mark {
	## Somebody is going to talk and there is nothing to solve: an arrival, an ending.
	STORY,
	## There is a problem here, and Lolo will help with it if you stand still long enough.
	HINT,
	## A choice that changes the level, and cannot be taken back. The gorge.
	CHOICE,
	## Something of Lola's -- a page, a memory, the inside of the chest.
	MEMORY,
	## A thing to find rather than a thing to solve. The hidden flower.
	FIND,
}

## Wood, and PALE wood. The first cut used the tones the rest of the level's timber is
## drawn in, and against wet terrace green at this size a dark brown board is a dark
## smudge -- the sign has to be legible from far enough away to be worth walking toward,
## which means it is lighter than anything it stands in front of rather than in keeping
## with it.
const POST := Color(0.545, 0.373, 0.216, 1.0)       # 8B5F37
const POST_DARK := Color(0.318, 0.204, 0.110, 1.0)  # 51341C
const BOARD := Color(0.816, 0.678, 0.443, 1.0)      # D0AD71
const BOARD_LIT := Color(0.918, 0.816, 0.596, 1.0)  # EAD098
const EDGE := Color(0.145, 0.086, 0.043, 1.0)       # 25160B
const NAIL := Color(0.478, 0.478, 0.463, 1.0)       # 7A7A76
## The glyph, and the one warm colour on the sign, so the eye goes to the mark rather than
## to the plank it is painted on.
const INK := Color(0.129, 0.086, 0.051, 1.0)        # 21160D
const LIT := Color(0.976, 0.847, 0.290, 1.0)        # F9D84A

## ⚠ AND ON THE SEABED IT IS NOT A WOODEN BOARD. A pale plank on a post stuck in the bottom of
## the sea is a land object dropped into the water, and Dagat has three of them at its
## encounter. Under the sea a board is a BROKEN PILLAR from the ruins the whole seabed is made
## of: a stump of their stone on its plinth, snapped off across the top, sunk in the silt,
## barnacled, with the same glyph carved into its face -- the five shapes the player already
## knows -- and glowing the sea's own light instead of the painted yellow. Chosen from where it
## stands; see under_the_sea.gd.
##
## ⚠ NOT A SLAB WITH A ROUNDED TOP. That was the first cut, and a grey arched stone standing on
## the seabed where Lolo drowned reads as a headstone. A column snapped off is architecture.
const UnderTheSea = preload("res://scripts/under_the_sea.gd")
const STONE := Color(0.361, 0.431, 0.529, 1.0)       # 5C6E87  lighter than the seabed, to read
const STONE_LIT := Color(0.541, 0.620, 0.722, 1.0)   # 8A9EB8
const STONE_DARK := Color(0.227, 0.278, 0.361, 1.0)  # 3A475C
const STONE_EDGE := Color(0.090, 0.114, 0.157, 1.0)  # 171D28
const SILT := Color(0.071, 0.227, 0.361, 1.0)        # 123A5C
const SILT_DARK := Color(0.043, 0.169, 0.290, 1.0)   # 0B2B4A
const SHELLS := Color(0.769, 0.780, 0.769, 1.0)      # C4C7C4  barnacles
const KELP := Color(0.200, 0.459, 0.337, 1.0)        # 337556
const CARVE := Color(0.063, 0.110, 0.157, 1.0)       # 101C28  the cut into the stone
const GLOW := Color(0.502, 0.941, 0.878, 1.0)        # 80F0E0  what lights the carving
const PILLAR_HALF := 12.0
const PILLAR_HEIGHT := 36.0
## The snapped top, as the drop below the tallest point for each pair of columns, left to right:
## high on the left, falling away jaggedly to the right where the rest of it broke off.
const BREAK := [0, 0, 1, 0, 2, 3, 2, 4, 5, 4, 6, 7]

## How big the board is, and how tall the post under it stands. Small on purpose: this is
## a hand-lettered marker beside the path, not a road sign, and the apo is 96 pixels.
const BOARD_SIZE := Vector2(34.0, 24.0)
const POST_HEIGHT := 24.0
const POST_WIDTH := 5.0

## How far the board rocks, and how slowly. A sign that is perfectly still is scenery; one
## pixel of sway at a third of a cycle a second is the difference between a plank in the
## ground and something the game is pointing at. It is deliberately not a bounce -- these
## sit beside cultural objects, and a jiggling arrow over a bulul would be the wrong tone.
const SWAY_PIXELS := 1.0
const SWAY_HZ := 0.35

## The dialogue hook this board will say again when the player presses the interact key
## beside it. Empty on most signs: a board with nothing to re-read is still a board that
## says "something happens here", which is what they were all for to begin with.
##
## WHY THE SIGN AND NOT THE TRIGGER. Arrival lore plays itself once and then stops seizing
## the screen (see DialogueScript.has_heard) -- but "stops" cannot mean "is gone", because
## the arrival line is the level telling you where you are and a player who walked in while
## reading something else has lost it for good. So it needs somewhere to live afterwards,
## and it wants to be somewhere the player can SEE, not a key that works invisibly across a
## four-hundred-pixel volume. The sign is already standing at the beat, already means
## "something here", and was already the thing Kent pointed at when describing the beat. It
## is the obvious place to put it and it costs no new art.
@export var reads: String = ""

@export var mark: Mark = Mark.STORY
## Set from the planting node so two signs side by side do not sway in lockstep.
@export var phase: float = 0.0
## How far down to look for something to stand on, and how far above the plant point to
## start looking. See _settle.
@export var reach: float = 260.0
const LOOK_UP := 40.0
## How close two signs have to be before one of them is redundant. See _yield_if_crowded.
const CROWD := 90.0
## How close the player stands before the board offers to be read. Matched to the 96px the
## interact key already reaches for a placed drawing, so one key has one range.
const READ_RANGE := 96.0

var _time: float = 0.0
var _sway: float = 0.0
var _offered := false
## Standing on the seabed of a level that asked for sea forms. See UnderTheSea.
var _sea := false
## How brightly the carving glows, in whole steps, so it is redrawn only when it changes.
var _pulse := 0


## Stand a sign at `where`, in `host`'s parent so it keeps the host's place in the world
## without inheriting a scale or a rotation the trigger might be carrying.
static func plant(host: Node2D, what: Mark, offset: Vector2 = Vector2.ZERO,
		reads: String = "", reach_down: float = 260.0) -> Signpost2D:
	var sign := Signpost2D.new()
	sign.name = "Signpost"
	sign.mark = what
	sign.reads = reads
	sign.reach = reach_down
	sign.position = offset
	# Seeded off where it stands, so the sway is scattered along the level rather than
	# synchronised, and so it is the same every run.
	sign.phase = fposmod(host.global_position.x * 0.013, 1.0)
	host.add_child(sign)
	return sign


func _ready() -> void:
	add_to_group(&"signposts")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# IN FRONT OF THE PROPS, and still behind the player at 10.
	#
	# It was 2, which is the same z the straw heap is authored at -- and equal z falls back
	# to tree order, where Dayami is a later sibling than Obstacles. So Node 2's hint board
	# was painted over by the haystack it stands at: the one marker saying "there is a puzzle
	# here" was drawn underneath the puzzle, on art that is 98.7% opaque at that spot. The
	# terraces and their props run 0..6 and the checkpoint flag is at 8, so 7 is the band
	# between a prop and a flag, which is exactly what a sign is.
	z_index = 7
	_sea = UnderTheSea.holds(self)
	set_process(true)
	_settle()


## Stand on whatever is underneath, rather than at the height of the thing that planted it.
##
## THE TRIGGERS ARE NOT ON THE GROUND. An obstacle's trigger is a box three hundred pixels
## tall centred on its own origin, so that origin is halfway up a terrace wall; the gorge's
## is anchored at its foot; the bulul's is at the figure's base. Planting each sign at its
## host's position put three of them in mid-air and, worse, would put them back there the
## next time a beat was nudged. So the sign asks the level where the floor is and stands on
## it, and a beat that moves takes a sign that lands correctly.
func _settle() -> void:
	# ONE PHYSICS FRAME FIRST. The terraces build their own collision shapes in their
	# _ready, so at the moment this sign is planted the physics server has not been told
	# about the ground it is asking after -- only the bodies whose shapes came out of the
	# scene file are there to be found, which is why the first cut of this dropped every
	# sign on a terrace all the way to the valley floor.
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var space := get_world_2d().direct_space_state
	# STARTED ABOVE THE PLANT POINT, because half of these nodes are already standing on
	# the floor they want to be found. A ray that begins exactly on a surface does not
	# register it, so the chest on the middle terrace fell four hundred pixels through its
	# own terrace and landed on the valley floor.
	var planted := global_position.y
	var hit := _ground_under(space, planted - LOOK_UP, planted)
	if hit.is_empty():
		# The look-up ray found a ceiling first and stopped there. Cast again from the
		# plant point itself, below whatever was in the way.
		hit = _ground_under(space, planted + 1.0, planted)
	# A SIGN ONLY EVER FALLS. Starting the ray above the plant point is what lets it find a
	# surface it is already standing on, and it also lets it find the underside of whatever
	# is over its head -- the last obstacle's trigger sits under an overhang, and the sign
	# went UP to meet it. Anything above where it was planted is a ceiling, not a floor.
	#
	# Nothing underneath at all is not a failure either: some of these stand on a ledge the
	# ray leaves through the side. The sign keeps the height it was given, and either way
	# still has to check whether it is standing on top of another one.
	if not hit.is_empty():
		# Whole pixels. Everything in this level is drawn on them, and a post standing on
		# a half one has a soft edge that nothing else on screen has.
		global_position = Vector2(global_position.x, roundf(float(hit["position"].y)))
	# Asked again where it has come to rest: the host that planted it may have been hanging
	# in the water column, and it is the seabed it ends up on that decides what it is.
	_sea = UnderTheSea.holds(self)
	queue_redraw()
	_yield_if_crowded()


## The first floor at or below `floor_at`, looking down from `start`. Empty when the only
## thing the ray found was over the sign's head.
func _ground_under(space: PhysicsDirectSpaceState2D, start: float,
                   floor_at: float) -> Dictionary:
	var from := Vector2(global_position.x, start)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, reach))
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	if hit.is_empty() or float(hit["position"].y) < floor_at:
		return {}
	return hit


## Two signs a stride apart are worse than one. The gorge is both the level's third
## obstacle and its route decision, so two nodes plant on the same spot -- and the one that
## matters is the choice, because the choice is the thing that cannot be taken back.
##
## Specific beats general and, between two of the same kind, the later one goes; that is
## arbitrary but it is DECIDED, which is what stops both of them removing each other.
func _yield_if_crowded() -> void:
	for other in get_tree().get_nodes_in_group(&"signposts"):
		var rival := other as Signpost2D
		if rival == null or rival == self:
			continue
		if absf(rival.global_position.x - global_position.x) > CROWD:
			continue
		if _rank(rival.mark) > _rank(mark):
			_hand_over(rival)
			queue_free()
			return
		if _rank(rival.mark) == _rank(mark) and get_instance_id() > rival.get_instance_id():
			_hand_over(rival)
			queue_free()
			return


## A board that stands down passes on whatever it could re-read, so crowding removes a
## post and never a beat. Without this, the sign carrying an arrival hook could be the one
## deleted -- silently, at load, on any narrow trigger where the two signs land together --
## and the player would be left with a key that does nothing beside the only board there is.
##
## The survivor keeps its own hook if it already has one. Two hooks on one board would need
## the player to press twice for a reason nothing on screen explains.
func _hand_over(survivor: Signpost2D) -> void:
	if survivor.reads.is_empty():
		survivor.reads = reads


## Which mark survives when two signs land on the same spot. A choice that cannot be taken
## back outranks a memory, a memory outranks a puzzle, and anything outranks "someone
## speaks here" -- because every one of the others speaks as well, and the more specific
## thing is the one worth the board.
func _rank(what: Mark) -> int:
	match what:
		Mark.CHOICE: return 4
		Mark.MEMORY: return 3
		Mark.FIND: return 2
		Mark.HINT: return 1
		_: return 0


## Whether the player is close enough to read this board, and it has something to say.
func can_be_read_from(where: Vector2) -> bool:
	return not reads.is_empty() and global_position.distance_to(where) <= READ_RANGE


## Light the board up because the player is standing at it. Set by the level, which is the
## only thing that knows both where the player is and whether the beat has been heard yet --
## a sign polling for a player every frame would be one raycast per board, forever, for a
## highlight.
func offer(on: bool) -> void:
	if _offered == on:
		return
	_offered = on
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	# Redrawn only when the board has actually moved. The sway is a WHOLE pixel either way,
	# so at a third of a cycle a second it changes about once a second -- asking for a
	# redraw every frame would be sixty times the work for the same picture, on every sign
	# in the level, forever.
	var sway := roundf(sin(TAU * (_time * SWAY_HZ + phase)) * SWAY_PIXELS)
	if not is_equal_approx(sway, _sway):
		_sway = sway
		queue_redraw()
	if _sea:
		# The carving breathes, slowly, in four steps -- light from something alive in the
		# grooves, not a lamp.
		var pulse := int(roundf((sin(TAU * (_time * 0.22 + phase)) * 0.5 + 0.5) * 3.0))
		if pulse != _pulse:
			_pulse = pulse
			queue_redraw()


func _draw() -> void:
	if _sea:
		_draw_pillar()
		var centre := Vector2(0.0, -PILLAR_HEIGHT * 0.5 - 1.0)
		if _offered:
			draw_rect(Rect2(-PILLAR_HALF - 7.0, -PILLAR_HEIGHT - 4.0,
				PILLAR_HALF * 2.0 + 14.0, PILLAR_HEIGHT + 6.0), GLOW, false, 2.0)
		# CUT, THEN LIT: the glyph once in the dark of the cut, a pixel down and right, and
		# again over it in the glow -- so it reads as carved into the stone and shining out of
		# the carving, and it reads against dark water, which a dark glyph would not.
		_draw_mark(centre + Vector2(1.0, 1.0), CARVE, CARVE)
		_draw_mark(centre, Color(GLOW, 0.62 + 0.12 * float(_pulse)),
			Color(0.85, 1.0, 0.97, 1.0))
		return
	_draw_post()
	var at := Vector2(0.0, -POST_HEIGHT - BOARD_SIZE.y * 0.5 + _sway)
	if _offered:
		# A ring of the same warm yellow the glyphs are painted in, one pixel off the
		# board on every side. It is not a key badge: the hint bar is already saying which
		# key, in the live binding, and a letter drawn on a 34-pixel plank would be four
		# pixels tall and unreadable at the distance the player is actually standing.
		draw_rect(Rect2(at - BOARD_SIZE * 0.5 - Vector2(3.0, 3.0),
			BOARD_SIZE + Vector2(6.0, 6.0)), LIT, false, 2.0)
	_draw_board(at)


## The post, with a little heap of earth at its foot so it reads as driven in rather than
## resting on the ground.
func _draw_post() -> void:
	draw_rect(Rect2(-POST_WIDTH * 0.5, -POST_HEIGHT, POST_WIDTH, POST_HEIGHT), POST)
	draw_rect(Rect2(-POST_WIDTH * 0.5, -POST_HEIGHT, 1.0, POST_HEIGHT), BOARD_LIT)
	draw_rect(Rect2(POST_WIDTH * 0.5 - 1.0, -POST_HEIGHT, 1.0, POST_HEIGHT), POST_DARK)
	draw_rect(Rect2(-5.0, -3.0, 10.0, 3.0), POST_DARK)
	draw_rect(Rect2(-3.0, -1.0, 6.0, 1.0), EDGE)


func _draw_board(at: Vector2) -> void:
	var board := Rect2(at - BOARD_SIZE * 0.5, BOARD_SIZE)
	draw_rect(board, BOARD)
	# Two planks rather than one, because a single flat rectangle reads as a card.
	draw_rect(Rect2(board.position, Vector2(board.size.x, 1.0)), BOARD_LIT)
	draw_rect(Rect2(board.position.x, at.y - 1.0, board.size.x, 1.0), POST_DARK)
	draw_rect(Rect2(board.position.x, board.end.y - 2.0, board.size.x, 2.0), POST_DARK)
	draw_rect(board, EDGE, false, 1.0)
	for side: float in [-1.0, 1.0]:
		draw_rect(Rect2(at.x + side * (BOARD_SIZE.x * 0.5 - 3.0) - 1.0,
			board.position.y + 3.0, 2.0, 2.0), NAIL)
	_draw_mark(at)


## THE PILLAR. A plinth sunk in the silt, a shaft on it lit down its left and in shade on its
## right, two flutes cut down its sides, and its top snapped off across -- high on the left,
## falling away jaggedly to the right. Barnacles where the current has left them, and a strand
## of kelp moving at its foot.
func _draw_pillar() -> void:
	var half := PILLAR_HALF
	var shaft_top := -PILLAR_HEIGHT
	# The shaft, column by column, so the broken top can drop by its own amount in each.
	for x in range(int(-half), int(half)):
		var drop := float(BREAK[clampi(int((float(x) + half) / 2.0), 0, BREAK.size() - 1)])
		var top := shaft_top + drop
		var colour := STONE
		if x <= int(-half) + 1:
			colour = STONE_LIT
		elif x >= int(half) - 2:
			colour = STONE_DARK
		elif x == int(-half) + 4 or x == int(half) - 5:
			colour = STONE_DARK
		draw_rect(Rect2(float(x), top, 1.0, -top - 5.0), colour)
		# The break: raw stone, pale on its upper face, a dark edge above it.
		draw_rect(Rect2(float(x), top, 1.0, 1.0), STONE_LIT)
		draw_rect(Rect2(float(x), top - 1.0, 1.0, 1.0), STONE_EDGE)
	draw_rect(Rect2(-half - 1.0, shaft_top, 1.0, -shaft_top - 5.0), STONE_EDGE)
	draw_rect(Rect2(half, shaft_top + float(BREAK[BREAK.size() - 1]), 1.0,
		-shaft_top - 5.0 - float(BREAK[BREAK.size() - 1])), STONE_EDGE)
	# The plinth it stands on: wider, a course of the same stone, lit along its top.
	draw_rect(Rect2(-half - 4.0, -6.0, half * 2.0 + 8.0, 5.0), STONE_EDGE)
	draw_rect(Rect2(-half - 3.0, -5.0, half * 2.0 + 6.0, 4.0), STONE)
	draw_rect(Rect2(-half - 3.0, -5.0, half * 2.0 + 6.0, 1.0), STONE_LIT)
	draw_rect(Rect2(half + 1.0, -5.0, 2.0, 4.0), STONE_DARK)
	# A crack down the shaft's shaded side.
	for step in range(6):
		draw_rect(Rect2(6.0 + float(step % 2), -26.0 + float(step) * 3.0, 1.0, 3.0), STONE_DARK)
	# Barnacles.
	for spot: Vector2 in [Vector2(-10.0, -9.0), Vector2(-7.0, -8.0), Vector2(8.0, -27.0),
			Vector2(9.0, -12.0)]:
		draw_rect(Rect2(spot, Vector2(2.0, 2.0)), SHELLS)
		draw_rect(Rect2(spot, Vector2(1.0, 1.0)), Color.WHITE)
	# Sunk in the silt: a low heap either side of its foot.
	draw_rect(Rect2(-half - 7.0, -3.0, half * 2.0 + 14.0, 3.0), SILT)
	draw_rect(Rect2(-half - 5.0, -4.0, 7.0, 1.0), SILT)
	draw_rect(Rect2(half - 2.0, -4.0, 7.0, 1.0), SILT)
	draw_rect(Rect2(-half - 7.0, -1.0, half * 2.0 + 14.0, 1.0), SILT_DARK)
	# A strand of kelp at its foot, moving on the board's own sway.
	draw_rect(Rect2(-half - 6.0, -8.0, 1.0, 6.0), KELP)
	draw_rect(Rect2(-half - 5.0 + _sway, -13.0, 1.0, 5.0), KELP)
	draw_rect(Rect2(-half - 6.0 + _sway, -17.0, 1.0, 4.0), KELP)


## The glyph, drawn out of whole pixels like everything else. Each is built so that its
## SILHOUETTE carries it: at eighteen pixels of board nobody reads a picture, they read a
## shape, and the four have to be different shapes before they are different drawings.
func _draw_mark(at: Vector2, ink: Color = INK, lit: Color = LIT) -> void:
	match mark:
		Mark.HINT:
			# A question mark. Nothing else on a board this size says "work something out"
			# in one shape, and it is the one glyph here nobody has to be taught.
			draw_rect(Rect2(at.x - 6.0, at.y - 9.0, 12.0, 4.0), ink)
			draw_rect(Rect2(at.x - 8.0, at.y - 7.0, 4.0, 4.0), ink)
			draw_rect(Rect2(at.x + 4.0, at.y - 7.0, 4.0, 5.0), ink)
			draw_rect(Rect2(at.x, at.y - 3.0, 5.0, 4.0), ink)
			draw_rect(Rect2(at.x - 2.0, at.y + 1.0, 4.0, 4.0), ink)
			draw_rect(Rect2(at.x - 2.0, at.y + 7.0, 4.0, 4.0), ink)
			draw_rect(Rect2(at.x - 5.0, at.y - 8.0, 10.0, 2.0), lit)
		Mark.STORY:
			# A speech bubble with a tail: the roundest of the five.
			draw_rect(Rect2(at.x - 9.0, at.y - 7.0, 18.0, 10.0), ink)
			draw_rect(Rect2(at.x - 7.0, at.y - 8.0, 14.0, 1.0), ink)
			draw_rect(Rect2(at.x - 7.0, at.y + 3.0, 9.0, 2.0), ink)
			draw_rect(Rect2(at.x - 6.0, at.y + 5.0, 4.0, 2.0), ink)
			for dot: float in [-5.0, 0.0, 5.0]:
				draw_rect(Rect2(at.x + dot - 1.0, at.y - 4.0, 3.0, 3.0), lit)
		Mark.CHOICE:
			# A road that forks. Two arms and a stem, which is a shape and not a picture.
			draw_rect(Rect2(at.x - 2.0, at.y - 1.0, 3.0, 8.0), ink)
			draw_rect(Rect2(at.x - 8.0, at.y - 3.0, 17.0, 3.0), ink)
			for side: float in [-1.0, 1.0]:
				draw_rect(Rect2(at.x + side * 7.0 - 1.0, at.y - 8.0, 3.0, 6.0), ink)
				draw_rect(Rect2(at.x + side * 6.0 - 1.0, at.y - 9.0, 3.0, 3.0), lit)
		Mark.MEMORY:
			# A page with writing on it, leaning the way a loose sheet does.
			draw_rect(Rect2(at.x - 7.0, at.y - 9.0, 14.0, 18.0), ink)
			draw_rect(Rect2(at.x - 5.0, at.y - 7.0, 10.0, 14.0), lit)
			for line in range(3):
				draw_rect(Rect2(at.x - 3.0, at.y - 4.0 + float(line) * 4.0, 7.0, 2.0), ink)
		Mark.FIND:
			# A four-petal flower, which is what there is to find.
			draw_rect(Rect2(at.x - 3.0, at.y - 9.0, 6.0, 6.0), lit)
			draw_rect(Rect2(at.x - 3.0, at.y + 2.0, 6.0, 6.0), lit)
			draw_rect(Rect2(at.x - 9.0, at.y - 3.0, 6.0, 6.0), lit)
			draw_rect(Rect2(at.x + 3.0, at.y - 3.0, 6.0, 6.0), lit)
			draw_rect(Rect2(at.x - 3.0, at.y - 3.0, 6.0, 6.0), ink)
