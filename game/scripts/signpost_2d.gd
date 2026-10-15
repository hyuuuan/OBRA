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

## ⚠ IT WAS A CARD ON A STICK, AND THE WORLD IS PAINTED. Kent: "fix the design of the
## signs/dialogue signs since it does not match the style of the game". It was a pale plank
## and a five-pixel stick drawn rectangle by rectangle at one screen pixel to the pixel, with a
## one-pixel outline and flat colour -- beside bamboo houses and terraces painted at two screen
## pixels to the pixel, shaded, and edged in dark brown, it read as a sticker on the picture.
##
## So it is drawn the way the checkpoint lantern is: as rows of pixels at UNIT, the world's own
## grain, in the outline every painted thing here wears. A bamboo post, jointed, driven into a
## few pebbles; a board of dark carved wood in a bevelled frame, lit along its top and left and
## shaded along its bottom and right, with its grain showing, lashed to the post above and below;
## and over it a peaked cap of straw with its fringe hanging loose, the way a roof is made here.
## The mark is PAINTED on the wood in cream -- pale on dark reads against the green of the
## terraces, the gold of the plaza and the blue of the sea alike -- with a touch of gold, and
## the whole mark turns gold when the board can be read back.
const UNIT := 2.0
## The post's column, so the sign stands centred on where it was planted.
const POST_X := 10
## Where the mark is painted on the board, and the board's own box, in art pixels.
const FACE := Vector2i(4, 10)
const BOARD := Rect2i(1, 8, 19, 13)
const SIGN_ROWS := [
	".....kkkTTTTTkkk......",
	"..kkkTTttthTtthhkkk...",
	"kkTTtthTttthTttthhhkk.",
	"TThTttthTttthTttthThhk",
	"HHHHHHHHHHHHHHHHHHHHHk",
	"khHkHhkhHLBDkhHkHhkhk.",
	"........kLBDk.........",
	".kkkkkkkkccCkkkkkkkk..",
	"keeeeeeeeeeeeeeeeeeek.",
	"keOOOOOOOOOOOOOOOOOek.",
	"keOooooooooooooooodek.",
	"keOogggooooooooooodek.",
	"keOooooooooooogggodek.",
	"keOooooooooooooooodek.",
	"keOooooooooooooooodek.",
	"keOooooooooooooooodek.",
	"keOooooooooooooooodek.",
	"keOoggggoooooooooodek.",
	"keOoooooooooogggoodek.",
	"keOddddddddddddddddek.",
	"keeeeeeeeeeeeeeeeeeek.",
	".kkkkkkkkccCkkkkkkkk..",
	"........kCBCk.........",
	"........kLBDk.........",
	"........kLBDk.........",
	"........kLBDk.........",
	"........kLLDk.........",
	"........kNNNk.........",
	"........kLBDk.........",
	".......kkLBDkk........",
	"......kSkLBDkZk.......",
	"......kssLBDssk.......",
	".......kkkkkkk........",
]
const GLYPH_ROWS := {
	Mark.STORY: [
		"..PPPPPPPP..",
		".PPPPPPPPPP.",
		"PPYPPYPPYPPp",
		"PPYPPYPPYPPp",
		".PPPPPPPPPpp",
		"..PPPPPPPpp.",
		"..PPp.......",
		".PPp........",
		".pp.........",
	],
	Mark.HINT: [
		"...PPPPP....",
		"..PPPPPPPp..",
		"..PPp..PPPp.",
		".......PPPp.",
		".....PPPPp..",
		"....PPPpp...",
		"....PPp.....",
		"............",
		"....YYp.....",
	],
	Mark.CHOICE: [
		"PPp......PPp",
		"YPPp....PPYp",
		"..PPp..PPp..",
		"...PPPPPp...",
		"....PPPp....",
		"....PPp.....",
		"....PPp.....",
		"....PPp.....",
		"...PPPPp....",
	],
	Mark.MEMORY: [
		"...PPPPPPp..",
		"...PYYYYPp..",
		"...PPPPPPp..",
		"...PYYYPPp..",
		"...PPPPPPp..",
		"...PYYYYPp..",
		"...PPPPPPp..",
		"...PPPPPPp..",
		"....pppppp..",
	],
	Mark.FIND: [
		"....PP......",
		"...PPPp.....",
		".PP.PP.PPp..",
		"PPPpYYpPPPp.",
		".PPpYYpPPp..",
		"..PPp.PPp...",
		".PPp...PPp..",
		"..p.....p...",
		"............",
	],
}
const SIGN_PALETTE := {
	"k": Color(0.165, 0.102, 0.055, 1.0),   # 2A1A0E  the outline the lantern and the world wear
	"B": Color(0.788, 0.643, 0.361, 1.0),   # C9A45C  bamboo
	"L": Color(0.910, 0.812, 0.541, 1.0),   # E8CF8A  the light down its side
	"D": Color(0.561, 0.416, 0.184, 1.0),   # 8F6A2F  its shade
	"N": Color(0.431, 0.310, 0.133, 1.0),   # 6E4F22  a node
	"c": Color(0.722, 0.588, 0.376, 1.0),   # B89660  the lashing
	"C": Color(0.541, 0.424, 0.243, 1.0),   # 8A6C3E  the lashing, round the back
	"T": Color(0.933, 0.808, 0.494, 1.0),   # EECE7E  straw in the light
	"t": Color(0.839, 0.659, 0.306, 1.0),   # D6A84E  straw
	"h": Color(0.612, 0.431, 0.173, 1.0),   # 9C6E2C  straw in shade
	"H": Color(0.420, 0.275, 0.102, 1.0),   # 6B461A  the eave, and the fringe under it
	"e": Color(0.290, 0.169, 0.078, 1.0),   # 4A2B14  the board's frame
	"O": Color(0.659, 0.420, 0.227, 1.0),   # A86B3A  its lit bevel
	"o": Color(0.525, 0.322, 0.165, 1.0),   # 86522A  its face
	"g": Color(0.455, 0.275, 0.133, 1.0),   # 744622  the grain
	"d": Color(0.384, 0.227, 0.110, 1.0),   # 623A1C  its shaded bevel
	"S": Color(0.557, 0.541, 0.502, 1.0),   # 8E8A80  a pebble
	"s": Color(0.384, 0.373, 0.345, 1.0),   # 625F58  pebbles in shade
	"Z": Color(0.706, 0.690, 0.643, 1.0),   # B4B0A4  a pebble in the light
}
## The mark: paint, the shade it leaves on the wood, and its touch of gold.
const GLYPH_PALETTE := {
	"P": Color(0.953, 0.906, 0.776, 1.0),   # F3E7C6
	"p": Color(0.788, 0.718, 0.557, 1.0),   # C9B78E
	"Y": Color(0.961, 0.784, 0.259, 1.0),   # F5C842
}
## The mark when the board can be read back: gold, and its gold gone pale.
const GLYPH_LIT := {
	"P": Color(1.0, 0.859, 0.361, 1.0),     # FFDB5C
	"p": Color(0.690, 0.478, 0.118, 1.0),   # B07A1E
	"Y": Color(1.0, 0.965, 0.847, 1.0),     # FFF6D8
}
## The ring round a board that can be read back, the mark's own gold.
const LIT := Color(1.0, 0.859, 0.361, 1.0)

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
const GroundShadow = preload("res://scripts/ground_shadow.gd")
const STONE := Color(0.361, 0.431, 0.529, 1.0)       # 5C6E87  lighter than the seabed, to read
const STONE_LIT := Color(0.541, 0.620, 0.722, 1.0)   # 8A9EB8
const STONE_HI := Color(0.710, 0.776, 0.847, 1.0)    # B5C6D8  where the light lands on it
const STONE_DARK := Color(0.227, 0.278, 0.361, 1.0)  # 3A475C
const STONE_EDGE := Color(0.090, 0.114, 0.157, 1.0)  # 171D28
const SILT := Color(0.071, 0.227, 0.361, 1.0)        # 123A5C
const SILT_DARK := Color(0.043, 0.169, 0.290, 1.0)   # 0B2B4A
const SHELLS := Color(0.769, 0.780, 0.769, 1.0)      # C4C7C4  barnacles
const KELP := Color(0.200, 0.459, 0.337, 1.0)        # 337556
const CARVE := Color(0.063, 0.110, 0.157, 1.0)       # 101C28  the cut into the stone
const GLOW := Color(0.502, 0.941, 0.878, 1.0)        # 80F0E0  what lights the carving
## ⚠ A COLUMN, SO IT IS ROUND, AND BIG ENOUGH TO BE SEEN FROM ACROSS THE BED. It was 24 by 36
## and shaded as a flat slab with a lit left column and a dark right one: from where a diver
## is, a small grey card on the sand. A drum of stone 30 wide and 50 tall, shaded across as
## the cylinder it is, fluted, on a square plinth seen a little from above.
const PILLAR_HALF := 15.0
const PILLAR_HEIGHT := 50.0
## Where the shaft stands on its plinth, and how deep the plinth is seen to go back.
const PILLAR_FOOT := -9.0
const PLINTH_DEPTH := 3.0
## The snapped top, as the drop below the tallest point for each pair of columns, left to right:
## high on the left, falling away jaggedly to the right where the rest of it broke off.
const BREAK := [0, 0, 1, 0, 2, 3, 2, 4, 5, 4, 6, 7, 8, 7, 9]

## The kelp at a pillar's foot moves, a whole pixel either way at a third of a cycle a second.
## The board on land does not: it is lashed to its post, and the painted mark is what says
## "something here".
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
## The sign's pictures, built once for every sign: the post, board and cap, and each mark
## plain and lit. See _picture.
static var _pictures: Dictionary = {}
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
	if not _sea:
		return
	# Redrawn only when the kelp has actually moved. The sway is a WHOLE pixel either way, so
	# at a third of a cycle a second it changes about once a second.
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
		# Under the plinth, whose footprint runs back up and to the right.
		GroundShadow.draw(self, PILLAR_HALF + 9.0, 3.0, 0.55,
			Vector2(PLINTH_DEPTH * 0.5, -PLINTH_DEPTH * 0.5))
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
	GroundShadow.draw(self, 14.0, 2.0, 0.45)
	# Art pixels from here, drawn at UNIT. The post's foot is on the ground at the origin.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(UNIT, UNIT))
	var origin := Vector2(-float(POST_X), -float(SIGN_ROWS.size() - 1))
	if _offered:
		# A ring of the mark's own gold round the board, a pixel off it on every side. Not a
		# key badge: the hint bar is already saying which key, in the live binding.
		draw_rect(Rect2(origin + Vector2(BOARD.position) - Vector2.ONE * 1.5,
			Vector2(BOARD.size) + Vector2.ONE * 3.0), LIT, false, 1.0)
	draw_texture(_picture("sign", SIGN_ROWS, SIGN_PALETTE), origin)
	draw_texture(_picture("%d%s" % [mark, " lit" if _offered else ""], GLYPH_ROWS[mark],
		GLYPH_LIT if _offered else GLYPH_PALETTE), origin + Vector2(FACE))
	draw_set_transform(Vector2.ZERO)


## A picture from rows of pixels, built once and shared by every sign: each character is a
## colour in `palette`, and one it does not name is clear.
static func _picture(key: String, rows: Array, palette: Dictionary) -> Texture2D:
	var cached: Texture2D = _pictures.get(key)
	if cached != null:
		return cached
	var width := String(rows[0]).length()
	var image := Image.create_empty(width, rows.size(), false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(rows.size()):
		var row := String(rows[y])
		for x in range(mini(width, row.length())):
			if palette.has(row[x]):
				image.set_pixel(x, y, palette[row[x]] as Color)
	var texture := ImageTexture.create_from_image(image)
	_pictures[key] = texture
	return texture


## THE PILLAR. A square plinth sunk in the silt, seen a little from above; on it a fluted drum
## of stone shaded across as the cylinder it is, lit on its left, turning into shade on its
## right; its top snapped off across -- high on the left, falling away jaggedly to the right,
## the broken face pale where it looks up at the light. Barnacles where the current has left
## them, a crack down its shaded side, and a strand of kelp moving at its foot.
func _draw_pillar() -> void:
	var half := PILLAR_HALF
	var foot := PILLAR_FOOT
	var ramp: Array[Color] = [STONE_EDGE, STONE_DARK, STONE, STONE_LIT, STONE_HI]
	# The plinth: a block with a top going back up to the right in the light, a right side in
	# shade, and a front face -- the same solid the lantern's blocks are.
	var plinth := Rect2(-half - 5.0, foot, half * 2.0 + 10.0, -foot - 1.0)
	var depth := int(PLINTH_DEPTH)
	draw_rect(plinth.grow(1.0), STONE_EDGE)
	for step in range(1, depth + 1):
		var back := float(step)
		draw_rect(Rect2(plinth.position.x + back - 1.0, plinth.position.y - back - 1.0,
			plinth.size.x + 2.0, 3.0), STONE_EDGE)
		draw_rect(Rect2(plinth.end.x + back - 2.0, plinth.position.y - back - 1.0,
			3.0, plinth.size.y + 2.0), STONE_EDGE)
	for step in range(1, depth + 1):
		var back := float(step)
		draw_rect(Rect2(plinth.position.x + back, plinth.position.y - back,
			plinth.size.x, 1.0), STONE_LIT)
		draw_rect(Rect2(plinth.end.x - 1.0 + back, plinth.position.y - back,
			1.0, plinth.size.y), STONE_DARK)
	draw_rect(plinth, STONE)
	draw_rect(Rect2(plinth.position, Vector2(plinth.size.x, 1.0)), STONE_LIT)
	draw_rect(Rect2(plinth.position, Vector2(1.0, plinth.size.y)), STONE_LIT)
	# The shaft, column by column: each column its step of the cylinder's light, every fifth a
	# flute cut into it with the lip beside it catching the light, and its own drop at the break.
	for x in range(int(-half), int(half)):
		var across := (float(x) + 0.5) / half
		# A band of light a third of the way in from the lit side, the terminator on the
		# shaded side, and a little light thrown back onto the lit rim by the water behind it.
		var v := 1.2 + 2.2 * sqrt(maxf(0.0, 1.0 - across * across)) - 1.2 * across
		var column := x + int(half)
		if column % 5 == 4:
			v -= 1.0
		elif column % 5 == 0 and column > 0:
			v += 0.5
		var drop := float(BREAK[clampi(column / 2, 0, BREAK.size() - 1)])
		var top := -PILLAR_HEIGHT + drop
		draw_rect(Rect2(float(x), top, 1.0, foot - top), ramp[clampi(int(roundf(v)), 1, 4)])
		# The break: raw stone looking up, two rows of it, and a dark edge above.
		draw_rect(Rect2(float(x), top, 1.0, 2.0), STONE_HI if across < 0.3 else STONE_LIT)
		draw_rect(Rect2(float(x), top - 1.0, 1.0, 1.0), STONE_EDGE)
	var first := float(BREAK[0])
	var last := float(BREAK[BREAK.size() - 1])
	draw_rect(Rect2(-half - 1.0, -PILLAR_HEIGHT + first, 1.0, foot + PILLAR_HEIGHT - first),
		STONE_EDGE)
	draw_rect(Rect2(half, -PILLAR_HEIGHT + last, 1.0, foot + PILLAR_HEIGHT - last), STONE_EDGE)
	# A crack down the shaft's shaded side.
	for step in range(8):
		draw_rect(Rect2(8.0 + float(step % 2), -38.0 + float(step) * 3.0, 1.0, 3.0), STONE_EDGE)
	# Barnacles.
	for spot: Vector2 in [Vector2(-13.0, -13.0), Vector2(-10.0, -12.0), Vector2(10.0, -36.0),
			Vector2(11.0, -17.0), Vector2(-16.0, -6.0)]:
		draw_rect(Rect2(spot, Vector2(2.0, 2.0)), SHELLS)
		draw_rect(Rect2(spot, Vector2(1.0, 1.0)), Color.WHITE)
	# Sunk in the silt: a low heap either side of its foot.
	draw_rect(Rect2(-half - 9.0, -3.0, half * 2.0 + 18.0, 3.0), SILT)
	draw_rect(Rect2(-half - 7.0, -4.0, 8.0, 1.0), SILT)
	draw_rect(Rect2(half - 1.0, -4.0, 9.0, 1.0), SILT)
	draw_rect(Rect2(-half - 9.0, -1.0, half * 2.0 + 18.0, 1.0), SILT_DARK)
	# A strand of kelp at its foot, moving on the board's own sway.
	draw_rect(Rect2(-half - 8.0, -10.0, 1.0, 7.0), KELP)
	draw_rect(Rect2(-half - 7.0 + _sway, -16.0, 1.0, 6.0), KELP)
	draw_rect(Rect2(-half - 8.0 + _sway, -21.0, 1.0, 5.0), KELP)


## The glyph carved into a seabed pillar, drawn out of whole pixels. Each is built so that its
## SILHOUETTE carries it: at eighteen pixels nobody reads a picture, they read a shape, and the
## five have to be different shapes before they are different drawings. (The board on land
## paints its mark from GLYPH_ROWS.)
func _draw_mark(at: Vector2, ink: Color, lit: Color) -> void:
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
