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

## What the board says. Four, because there are four kinds of moment in this level and a
## player can learn four shapes without being taught them.
enum Mark {
	## Somebody is going to talk: an obstacle's beat, or Lolo at the bulul.
	TALK,
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

@export var mark: Mark = Mark.TALK
## Set from the planting node so two signs side by side do not sway in lockstep.
@export var phase: float = 0.0
## How far down to look for something to stand on, and how far above the plant point to
## start looking. See _settle.
@export var reach: float = 260.0
const LOOK_UP := 40.0
## How close two signs have to be before one of them is redundant. See _yield_if_crowded.
const CROWD := 90.0

var _time: float = 0.0
var _sway: float = 0.0


## Stand a sign at `where`, in `host`'s parent so it keeps the host's place in the world
## without inheriting a scale or a rotation the trigger might be carrying.
static func plant(host: Node2D, what: Mark, offset: Vector2 = Vector2.ZERO) -> Signpost2D:
	var sign := Signpost2D.new()
	sign.name = "Signpost"
	sign.mark = what
	sign.position = offset
	# Seeded off where it stands, so the sway is scattered along the level rather than
	# synchronised, and so it is the same every run.
	sign.phase = fposmod(host.global_position.x * 0.013, 1.0)
	host.add_child(sign)
	return sign


func _ready() -> void:
	add_to_group(&"signposts")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# In front of the terrain and behind the player, who is at 10.
	z_index = 2
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
		var mine := mark != Mark.TALK
		var theirs := rival.mark != Mark.TALK
		if theirs and not mine:
			queue_free()
			return
		if mine == theirs and get_instance_id() > rival.get_instance_id():
			queue_free()
			return


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


func _draw() -> void:
	_draw_post()
	_draw_board(Vector2(0.0, -POST_HEIGHT - BOARD_SIZE.y * 0.5 + _sway))


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


## The glyph, drawn out of whole pixels like everything else. Each is built so that its
## SILHOUETTE carries it: at eighteen pixels of board nobody reads a picture, they read a
## shape, and the four have to be different shapes before they are different drawings.
func _draw_mark(at: Vector2) -> void:
	match mark:
		Mark.TALK:
			# A speech bubble with a tail: the roundest of the four.
			draw_rect(Rect2(at.x - 9.0, at.y - 7.0, 18.0, 10.0), INK)
			draw_rect(Rect2(at.x - 7.0, at.y - 8.0, 14.0, 1.0), INK)
			draw_rect(Rect2(at.x - 7.0, at.y + 3.0, 9.0, 2.0), INK)
			draw_rect(Rect2(at.x - 6.0, at.y + 5.0, 4.0, 2.0), INK)
			for dot: float in [-5.0, 0.0, 5.0]:
				draw_rect(Rect2(at.x + dot - 1.0, at.y - 4.0, 3.0, 3.0), LIT)
		Mark.CHOICE:
			# A road that forks. Two arms and a stem, which is a shape and not a picture.
			draw_rect(Rect2(at.x - 2.0, at.y - 1.0, 3.0, 8.0), INK)
			draw_rect(Rect2(at.x - 8.0, at.y - 3.0, 17.0, 3.0), INK)
			for side: float in [-1.0, 1.0]:
				draw_rect(Rect2(at.x + side * 7.0 - 1.0, at.y - 8.0, 3.0, 6.0), INK)
				draw_rect(Rect2(at.x + side * 6.0 - 1.0, at.y - 9.0, 3.0, 3.0), LIT)
		Mark.MEMORY:
			# A page with writing on it, leaning the way a loose sheet does.
			draw_rect(Rect2(at.x - 7.0, at.y - 9.0, 14.0, 18.0), INK)
			draw_rect(Rect2(at.x - 5.0, at.y - 7.0, 10.0, 14.0), LIT)
			for line in range(3):
				draw_rect(Rect2(at.x - 3.0, at.y - 4.0 + float(line) * 4.0, 7.0, 2.0), INK)
		Mark.FIND:
			# A four-petal flower, which is what there is to find.
			draw_rect(Rect2(at.x - 3.0, at.y - 9.0, 6.0, 6.0), LIT)
			draw_rect(Rect2(at.x - 3.0, at.y + 2.0, 6.0, 6.0), LIT)
			draw_rect(Rect2(at.x - 9.0, at.y - 3.0, 6.0, 6.0), LIT)
			draw_rect(Rect2(at.x + 3.0, at.y - 3.0, 6.0, 6.0), LIT)
			draw_rect(Rect2(at.x - 3.0, at.y - 3.0, 6.0, 6.0), INK)
