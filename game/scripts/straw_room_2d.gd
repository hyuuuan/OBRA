class_name StrawRoom2D
extends Node2D
## Inside the heap, and it is a great deal bigger in here than the hole suggested.
##
## BUILT THE WAY THE HOUSE IN THE HUB IS BUILT, and that is the whole of what changed on the
## third attempt. The first two were a cutaway of the heap and then a wall of tiled painting,
## and both read as a picture of straw rather than as a room -- there was nothing in either
## of them that was made, only texture. A room is made: it has courses, and joints, and a
## lintel over the door, and a floor laid in boards. hub_room.gd is that argument already
## won once, so this is the same argument in straw.
##
## THE RULER IS THE APO, exactly as it is in the house. He is 96 pixels tall and a child of
## about a metre thirty, which puts a METRE AT SEVENTY-TWO PIXELS, and every number below is
## a real measurement divided by that -- a four-metre wall because that is a barn, a bale
## forty-five centimetres deep because that is a bale, a chest at knee height because that is
## a chest. Every one carries the metres it came from in the comment beside it, so if
## something looks wrong the argument is about the measurement and not about the number.
##
## And it is SEEN AT 2, like the house, which is the other half of it. The level is drawn at
## 1 because it is a valley; a room is somewhere you are standing in, so the camera comes in
## until the room fills the frame and the apo is a fifth of the height of it.
##
## WHAT IS IN IT. Her baul, still locked; that lock is Node 3's problem and the line closing
## Node 2 is "Locked. Of course." The brass key to the HOUSE, hung on a nail out of reach.
## And the ants that were living in here before anybody came looking.
##
## THE CANVAS USED TO HANG IN HERE AND DOES NOT ANY MORE. The room held the hub's own
## painting of Pista, and the key on the floor opened nothing -- "finding a key that does
## not fit is the point". That made the heap the place you collect the next level and the
## house the place you collect nothing, which is backwards: the house is the harder of the
## two and the one the level ends at. So the chain is now heap -> key -> house -> painting,
## and each thing you find is the way into the next thing rather than a promise about it.

signal key_taken()
## The apo has walked into the opening that leads back out to the terrace.
signal exit_reached()

## How long the room is. Fifteen metres of barn, against a screenful of eleven at this zoom
## -- so the way out and the chest are never quite on screen together and there is somewhere
## to walk to. At eight hundred the whole room fitted in one view and the walking went.
@export var room_length := 1100.0
## Floor to eaves. Four metres, which is a storey in a building with a roof this shape.
@export var wall_height := 270.0
## Eaves to ridge. A metre and a quarter of thatch closing over the top.
@export var roof_height := 90.0
## How far the floor runs toward the viewer before the frame ends. One metre thirty.
@export var floor_depth := 100.0
## WHERE THE KEY HANGS, measured off the floor the apo stands on -- and it is OUT OF REACH
## on purpose. The apo's jump apex is 94.3px (wanderer.gd) and she is 96 tall, so standing on
## the floor she can reach a little under 190. At 250 the nail is comfortably above that and
## below the eaves at 270, so the answer is anything at all to stand on: the room is the one
## place in the level where the puzzle is height and nothing else.
##
## It used to lie on the floor and you took it by walking over it. A key that is the way into
## the house should cost something, and the cheapest honest cost in a game about drawing is
## "you cannot reach that".
@export var key_at := Vector2(-40.0, -250.0)
## What the profile records when the key is taken. It opens Ang Bale -- see game_level's
## _use_the_found_key.
@export var collectible_id: String = "L1_bale_key"
## How far in the camera sits while she is in here. Two, like the house.
@export var room_zoom := 2.0

## STRAW IN FOUR VALUES AND ONE HUE. Taken off Kent's heap, so the wall in here and the heap
## on the terrace are the same material -- a room in contrasting golds reads as a bonfire.
const STRAW_DARK := StrawPile2D.EDGE      # 5E3A12  the shadow under a course
const STRAW_SHADE := StrawPile2D.DARK     # 96601E
const STRAW := StrawPile2D.MID            # C98A2B  the field of a bale
const STRAW_LIT := StrawPile2D.BODY       # EDB53A  the cut end of it, facing the light
const STRAW_HI := StrawPile2D.LIT         # FFD75E
const STRAW_PALE := StrawPile2D.HI        # FFF0A8
## Split bamboo: the poles the thatch is bound to, and the only hard thing in the room. Its
## being a different material from the straw is what gives the wall its structure.
const POLE := Color(0.639, 0.545, 0.294, 1.0)       # A38B4B
const POLE_LIT := Color(0.792, 0.706, 0.443, 1.0)   # CAB471
const POLE_DARK := Color(0.400, 0.325, 0.161, 1.0)  # 665329
## The twine the poles are lashed on with, and what makes a lashing read as one.
const TWINE := Color(0.478, 0.404, 0.267, 1.0)      # 7A6744
const TWINE_LIT := Color(0.616, 0.541, 0.376, 1.0)  # 9D8A60
## The dark between the courses and behind everything.
const DEEP := Color(0.118, 0.071, 0.031, 1.0)       # 1E1208
const DEEPER := Color(0.063, 0.035, 0.016, 1.0)     # 100904
## The floor: trodden earth, in courses like the boards in the house, because a floor that
## somebody has walked on for a season is not one flat colour.
const EARTH := Color(0.267, 0.180, 0.110, 1.0)      # 442E1C
const EARTH_LIT := Color(0.353, 0.251, 0.161, 1.0)  # 5A4029
const EARTH_DARK := Color(0.157, 0.102, 0.063, 1.0) # 281A10
const PEBBLE := Color(0.463, 0.424, 0.369, 1.0)     # 766C5E
## Daylight in the opening back out. Warm and washed out, because it is the terrace out
## there and the eye in here is used to the dark.
const DAYLIGHT := Color(0.980, 0.941, 0.792, 1.0)     # FAF0CA
const DAYLIGHT_DIM := Color(0.847, 0.784, 0.588, 1.0) # D8C896
## The valley through the doorway, in the three bands anybody can see through a hole the
## width of a person: sky, the terrace behind, and the one she is standing on.
const OUTSIDE_SKY := Color(0.643, 0.831, 0.933, 1.0)   # A4D4EE
const OUTSIDE_GREEN := Color(0.478, 0.667, 0.353, 1.0) # 7AAA5A
const OUTSIDE_EARTH := Color(0.749, 0.647, 0.443, 1.0) # BFA571
## Brass, dulled. A key that has been in a straw heap is not a bright one.
const BRASS := Color(0.831, 0.667, 0.216, 1.0)      # D4AA37
const BRASS_LIT := Color(0.949, 0.851, 0.427, 1.0)  # F2D96D
const BRASS_DARK := Color(0.502, 0.376, 0.098, 1.0) # 806019

## How wide the way out is, and how tall. A doorway in a barn: one metre by two.
const DOOR := Vector2(72.0, 144.0)

var _taken := false
var _key_area: Area2D
var _exit_area: Area2D
var _ants: StrawAnts2D
## The brass leaving the nail: how far it has risen and how much of it is left. Driven by a
## tween through the setters, so the node has no idle work while nothing is being taken.
##
## IT USED TO JUST STOP BEING DRAWN -- one frame on the nail, the next frame gone. The whole
## of Node 2 is about getting up to this, and the moment it paid out said nothing at all.
var _key_lift := 0.0:
	set(value):
		_key_lift = value
		queue_redraw()
var _key_fade := 1.0:
	set(value):
		_key_fade = value
		queue_redraw()


func _ready() -> void:
	add_to_group(&"straw_rooms")
	# The group the level asks "which room is the player standing in", shared with the bale's
	# interior so one camera rule covers both insides.
	add_to_group(&"interiors")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_floor()
	_build_key_area()
	_build_exit_area()
	_build_ants()
	# NOT DRAWN WHILE NOBODY IS IN IT, and that is not an optimisation.
	#
	# The room paints a dark ground behind itself so the sky it is standing in never shows
	# through the straw, and that ground has to reach past the walls because the camera leads
	# the player. Left switched on it painted the whole valley: the level came up with black
	# where the sky should be and the heap's wall across the top of it, which is what "the
	# map in the overworld is still black at some parts" was.
	visible = false
	set_process(true)


## Whether the apo is standing in here. Asked of her position every frame rather than set by
## the doorway, because a checkpoint restore, a fall or a morph can move her out of this room
## without going through it -- and a room that is still drawn once she has left is a room
## painted over the level.
func _process(_delta: float) -> void:
	var here := false
	for node in get_tree().get_nodes_in_group(&"player_character"):
		var body := node as Node2D
		if body != null and bounds().grow(90.0).has_point(body.global_position):
			here = true
			break
	if here == visible:
		return
	visible = here
	if _ants != null:
		_ants.set_process(here)


## HOW FAR EVERYTHING IN HERE IS DRAWN PAST THE WALLS SHE CAN REACH.
##
## The camera sees four hundred units either side of her at this zoom and she can walk right
## up to the end wall, so a room drawn only as far as it is walkable puts its own end on
## screen with the level's sky behind it -- which is what the first cut of this did. It is
## safe to be generous because the room is not drawn at all while she is somewhere else.
func _span() -> float:
	return room_length * 0.5 + 480.0


## The box the room occupies, floor centre at this node's origin.
func bounds() -> Rect2:
	return Rect2(global_position - Vector2(room_length * 0.5, wall_height + roof_height),
		Vector2(room_length, wall_height + roof_height + floor_depth))


## THE BOX THE CAMERA MAY NOT LOOK OUT OF, which is NOT `bounds()`.
##
## `bounds()` is the walkable room, and this one is deliberately longer than a screenful --
## fifteen metres of barn against eleven of view, so there is somewhere to walk to. Clamping
## the camera to that would pin it to the middle three hundred units and let the apo walk to
## the edge of the frame and out of it. The room is DRAWN a good deal wider than it is walked
## (see `_span`) precisely so the camera can lead her, and this is that painted extent.
func camera_rect() -> Rect2:
	var span := _span()
	return Rect2(global_position - Vector2(span, wall_height + roof_height),
		Vector2(span * 2.0, wall_height + roof_height + floor_depth))


## Kept for the level and the suites, which ask how big the room is rather than where it is.
var room_size: Vector2:
	get:
		return Vector2(room_length, wall_height + roof_height)


func key_is_taken() -> bool:
	return _taken


func how_far_in() -> float:
	return room_zoom


## Where the camera sits to look at this room: halfway between the ridge and the front edge
## of the floor, so a screenful shows the whole height of it and neither the roof nor the
## floor slides off as she walks.
func eye_level() -> float:
	return global_position.y - (wall_height + roof_height - floor_depth) * 0.5


## Where the apo appears when she ducks in: just inside the way out, so the first thing she
## can see is how to leave, and the room is in front of her rather than behind.
func entry_point() -> Vector2:
	return global_position + Vector2(-room_length * 0.5 + DOOR.x * 1.6, 0.0)


## The opening back out to the terrace, in the room's own space.
func exit_rect() -> Rect2:
	return Rect2(Vector2(-room_length * 0.5 + 26.0, -DOOR.y), DOOR)


## SOMETHING TO STAND ON. The room is in the sky above the level, so it brings its own floor;
## without it the apo drops out of the bottom of it and the level fishes her back to a
## checkpoint on the terrace, which is a very confusing way to leave a room.
func _build_floor() -> void:
	var body := StaticBody2D.new()
	body.name = "Floor"
	add_child(body)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(room_length, 120.0)
	shape.shape = box
	shape.position = Vector2(0.0, 60.0)
	body.add_child(shape)
	# And a wall at each end, so she cannot walk out of the ends of the room into the sky it
	# is standing in.
	#
	# FLOOR TO RIDGE, NOT FLOOR TO EAVES. At `wall_height` the ends stopped level with the
	# eaves and everything above that was open sky. That was survivable while the apo was the
	# only thing in here -- she jumps 94px -- and it stopped being survivable the moment a
	# drawing could be one: this room's entire puzzle is "the nail is forty pixels out of
	# reach", so the player is being ASKED to bring something that climbs or flies, and the
	# obvious answers went straight over the top of the room and out into two thousand units
	# of nothing.
	var enclosure := wall_height + roof_height
	for side: float in [-1.0, 1.0]:
		var wall := StaticBody2D.new()
		wall.name = "Wall%s" % ("L" if side < 0.0 else "R")
		add_child(wall)
		var wall_shape := CollisionShape2D.new()
		var wall_box := RectangleShape2D.new()
		wall_box.size = Vector2(48.0, enclosure)
		wall_shape.shape = wall_box
		wall_shape.position = Vector2(side * (room_length * 0.5 + 8.0), -enclosure * 0.5)
		wall.add_child(wall_shape)

	# THE THATCH IS SOLID. Same reason: a room with no lid is a room a bird leaves.
	var roof := StaticBody2D.new()
	roof.name = "Roof"
	add_child(roof)
	var roof_shape := CollisionShape2D.new()
	var roof_box := RectangleShape2D.new()
	roof_box.size = Vector2(room_length + 96.0, 48.0)
	roof_shape.shape = roof_box
	# Just INSIDE the room's own bounds rather than level with them: a body resting exactly
	# on the top edge of bounds() is a body `_room_holding_player` has to be generous about.
	roof_shape.position = Vector2(0.0, -enclosure + 24.0)
	roof.add_child(roof_shape)


## WALKED ONTO, not pressed at. E reaches only placed drawings -- that is what the group is
## and what its 96px is measured against -- and a second meaning for that button, in the one
## room where the player has just learned the first, is one meaning too many. The level
## already picks things up by being walked into: that is what a checkpoint is.
func _build_key_area() -> void:
	_key_area = Area2D.new()
	_key_area.name = "Key"
	_key_area.collision_layer = 0
	_key_area.collision_mask = 1
	_key_area.position = key_at
	add_child(_key_area)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(70.0, 96.0)
	shape.shape = box
	shape.position = Vector2(0.0, -34.0)
	_key_area.add_child(shape)
	_key_area.body_entered.connect(_on_key_body)


func _build_exit_area() -> void:
	_exit_area = Area2D.new()
	_exit_area.name = "WayOut"
	_exit_area.collision_layer = 0
	_exit_area.collision_mask = 1
	add_child(_exit_area)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	var opening := exit_rect()
	box.size = Vector2(46.0, opening.size.y)
	shape.shape = box
	shape.position = opening.get_center()
	_exit_area.add_child(shape)
	_exit_area.body_entered.connect(_on_exit_body)


## They walk about on their own, so they get their own node: the room is a wall of courses
## and a floor of boards, and repainting all of that every frame to move six legs would be
## the smallest thing on screen costing the most.
func _build_ants() -> void:
	_ants = StrawAnts2D.new()
	_ants.name = "Ants"
	_ants.patrol = Vector2(-room_length * 0.4, room_length * 0.4)
	_ants.position = Vector2(0.0, 12.0)
	_ants.z_index = 1
	add_child(_ants)


func _is_the_player(body: Node) -> bool:
	var node := body as Node
	while node != null:
		if node.is_in_group(&"player_character") or node is ActiveRagdollMorph:
			return true
		node = node.get_parent()
	return false


func _on_key_body(body: Node) -> void:
	if _taken or not _is_the_player(body):
		return
	_taken = true
	# DEFERRED. Godot refuses to switch an area's monitoring while it is in the middle of
	# delivering a signal from it, and this is that signal.
	_key_area.set_deferred(&"monitoring", false)
	var profile := get_node_or_null(^"/root/PlayerProfile")
	if profile != null:
		profile.call("record_collectible", collectible_id)
	# IT COMES OFF THE NAIL AND GOES UP, and it is thrown a flourish on the way. The signal
	# fires NOW rather than at the end of the tween: nothing downstream should wait on an
	# animation to know the player has it, and the beat that follows plays over the top.
	PickupFlourish2D.burst(self, key_at + Vector2(0.0, -8.0), BRASS_LIT)
	var take := create_tween()
	take.set_parallel(true)
	take.tween_property(self, "_key_lift", 30.0, 0.45) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	take.tween_property(self, "_key_fade", 0.0, 0.4).set_delay(0.1)
	queue_redraw()
	key_taken.emit()


func _on_exit_body(body: Node) -> void:
	if _is_the_player(body):
		exit_reached.emit()


## A deterministic scatter, so the straw does not crawl from one redraw to the next. Same
## hash the house uses, for the same reason.
func _hash(value: int) -> int:
	var x := (value * 374761393 + 668265263) & 0x7FFFFFFF
	x = (x ^ (x >> 13)) * 1274126177
	return x & 0x7FFFFFFF


func _draw() -> void:
	_draw_dark()
	_draw_wall()
	_draw_roof()
	_draw_way_out()
	_draw_floor()
	# THE NAIL STAYS. It is part of the wall, and an empty nail is the room telling a player
	# who comes back that they already took what was hanging on it -- which the old code,
	# which stopped drawing both together, could not say.
	_draw_nail(key_at)
	if _key_fade > 0.0:
		_draw_key(key_at - Vector2(0.0, _key_lift), _key_fade)


## What the room is seen against, and only just bigger than the room: a ground that reaches
## a screen past the walls is a ground painted over the level, which is exactly what it was.
func _draw_dark() -> void:
	var span := _span()
	draw_rect(Rect2(-span, -wall_height - roof_height - 200.0,
		span * 2.0, wall_height + roof_height + floor_depth + 400.0), DEEPER)


## THE WALL IS THATCH ON A FRAME, and getting there took two wrong answers.
##
## The house in the hub is timber, capiz and pressed tin, and crisp rectangles with a lit
## edge and a shadow edge are exactly right for those. Applying the same method to straw
## gives you a wall of crates: the first cut of this stacked bound BALES in a running bond,
## and however much the tone and the grain were varied, the eye found the boxes before it
## found the material.
##
## So the structure comes from the frame and the material stays soft. Vertical straw the full
## height of the wall, in clumps rather than one stalk at a time, held by horizontal binding
## poles at four heights -- which is how a thatched wall is actually built, and which gives
## the courses, the joints and the rhythm the house gets out of its stiles and rails without
## pretending straw is a plank.
func _draw_wall() -> void:
	var span := _span()
	draw_rect(Rect2(-span, -wall_height, span * 2.0, wall_height), DEEP)
	_draw_thatch(-span, span, -wall_height, 0.0)
	# The poles that hold it on. Four, evenly up the wall, plus the sill at the foot -- the
	# same job the chair rail does on a pier in the house.
	for index in range(4):
		_draw_binding(-span, span, -wall_height * (0.22 + 0.20 * float(index)))
	_draw_binding(-span, span, -14.0)
	# A corner post at each end she can walk to, so the room has a length the eye can read
	# rather than running on forever.
	for side: float in [-1.0, 1.0]:
		_draw_post(side * room_length * 0.5)


## A field of hanging straw. Clumped, because straw falls in handfuls: a run of neighbouring
## strands shares a tone and a length, and the clump is what the eye reads rather than the
## strand.
func _draw_thatch(left: float, right: float, top: float, foot: float) -> void:
	var tones: Array[Color] = [STRAW_DARK, STRAW_SHADE, STRAW, STRAW_LIT, STRAW_HI]
	var x := left
	var clump_end := left
	var clump_tone := 2
	var clump_drop := 0.0
	while x < right:
		if x >= clump_end:
			var roll := _hash(int(x) * 761)
			clump_end = x + 5.0 + float(roll % 14)
			# Weighted toward the middle of the ramp, so the wall has a colour rather than
			# being a stripe of every value it owns.
			var picks: Array[int] = [2, 3, 3, 4, 1, 3]
			clump_tone = picks[roll % picks.size()]
			clump_drop = float((roll >> 7) % 9)
		var noise := _hash(int(x) * 37 + 11)
		var strand_top := top + float(noise % 5)
		var strand_foot := foot - clump_drop + float((noise >> 4) % 6)
		var step := int(noise % 3) - 1
		# THE LIGHT COMES IN THE DOOR, and there is nowhere else for it to come from: this
		# is the inside of a heap. So the wall is brightest at the end the daylight is at and
		# falls away down the length of the room, which is the only thing in here saying the
		# far end is further away.
		var reach := clampf((x - left) / maxf(1.0, right - left), 0.0, 1.0)
		var fall := -1 if reach > 0.62 else 0
		var tone: Color = tones[clampi(clump_tone + step + fall, 0, tones.size() - 1)]
		draw_rect(Rect2(x, strand_top, 1.0, strand_foot - strand_top), tone)
		# The shadow between one strand and the next, so the wall has depth rather than
		# being a comb of lines on a flat ground.
		if noise % 6 == 0:
			draw_rect(Rect2(x + 1.0, strand_top + float((noise >> 8) % 11), 1.0,
				(strand_foot - strand_top) * 0.7), DEEP)
		x += 2.0


## A corner post: one upright of bamboo, floor to eaves, with its nodes.
func _draw_post(x: float) -> void:
	var wide := 13.0
	draw_rect(Rect2(x - wide * 0.5 - 2.0, -wall_height, wide + 4.0, wall_height),
		Color(0.0, 0.0, 0.0, 0.35))
	draw_rect(Rect2(x - wide * 0.5, -wall_height, wide, wall_height), POLE)
	draw_rect(Rect2(x - wide * 0.5, -wall_height, 3.0, wall_height), POLE_LIT)
	draw_rect(Rect2(x + wide * 0.5 - 3.0, -wall_height, 3.0, wall_height), POLE_DARK)
	var y := -wall_height + 26.0
	while y < 0.0:
		draw_rect(Rect2(x - wide * 0.5 - 1.0, y, wide + 2.0, 3.0), POLE_DARK)
		draw_rect(Rect2(x - wide * 0.5 - 1.0, y + 3.0, wide + 2.0, 1.0), POLE_LIT)
		y += 44.0 + float(_hash(int(y)) % 22)


## One binding pole across the wall: split bamboo, lashed on. Lit along the top, dark
## underneath, with a hairline of shadow thrown onto the straw below it -- and a lashing
## every so often, which is the detail that says it is tied on rather than painted across.
func _draw_binding(left: float, right: float, y: float) -> void:
	var deep := 7.0
	draw_rect(Rect2(left, y, right - left, deep), POLE)
	draw_rect(Rect2(left, y, right - left, 2.0), POLE_LIT)
	draw_rect(Rect2(left, y + deep - 2.0, right - left, 2.0), POLE_DARK)
	draw_rect(Rect2(left, y + deep, right - left, 3.0), Color(0.0, 0.0, 0.0, 0.34))
	# The nodes, and the lashings between them.
	var x := left + float(_hash(int(y) * 13) % 40)
	while x < right:
		var noise := _hash(int(x) * 53 + int(y))
		draw_rect(Rect2(x, y - 1.0, 2.0, deep + 2.0), POLE_DARK)
		draw_rect(Rect2(x + 2.0, y, 1.0, deep), POLE_LIT)
		if noise % 3 == 0:
			var lash := x + 14.0 + float(noise % 20)
			draw_rect(Rect2(lash, y - 2.0, 3.0, deep + 4.0), TWINE)
			draw_rect(Rect2(lash, y - 2.0, 1.0, deep + 4.0), TWINE_LIT)
		x += 46.0 + float(noise % 34)


## The roof: loose thatch over the bales, hanging in courses like a thatched ridge, because
## the top of a barn full of straw is not another course of bales.
func _draw_roof() -> void:
	var half := room_length * 0.5
	var eaves := -wall_height
	draw_rect(Rect2(-half, eaves - roof_height, room_length, roof_height), STRAW_SHADE)
	# Three courses of thatch, each overhanging the one below, darkest at the top where the
	# ridge shades it.
	var courses := 3
	for index in range(courses):
		var band := roof_height / float(courses)
		var y := eaves - band * float(index + 1)
		var tones: Array[Color] = [STRAW, STRAW_SHADE, STRAW_DARK]
		draw_rect(Rect2(-half, y, room_length, band), tones[index])
		# The fringe of the course above hanging over this one.
		var x := -half
		while x < half:
			var noise := _hash(int(x) * 13 + index * 977)
			draw_rect(Rect2(x, y + band - 1.0, 1.0, 2.0 + float(noise % 5)),
				STRAW_DARK if noise % 3 == 0 else STRAW_LIT)
			x += 2.0 + float(noise % 3)
		draw_rect(Rect2(-half, y, room_length, 1.0), DEEP)
	# The ridge itself, and the beam under the eaves that the roof sits on.
	draw_rect(Rect2(-half, eaves - roof_height, room_length, 3.0), DEEP)
	draw_rect(Rect2(-half, eaves - 5.0, room_length, 5.0), STRAW_DARK)
	draw_rect(Rect2(-half, eaves - 5.0, room_length, 1.0), STRAW_LIT)


## The way back out: a doorway cut through the bales, with a straw lintel over it and the
## terrace's daylight behind. It is the only bright thing in the room, which is what makes it
## read as the way out without a label -- and it is built like the doorways in the house,
## with something holding the wall up over it, because a hole with nothing over it reads as
## damage rather than as a door.
func _draw_way_out() -> void:
	var opening := exit_rect()
	var jamb := 8.0
	draw_rect(opening.grow(jamb), STRAW_DARK)
	draw_rect(opening.grow(jamb), DEEP, false, 2.0)
	# The lintel: a pole across the head of it, carrying the wall over the opening. A hole
	# with nothing over it reads as damage rather than as a door.
	_draw_binding(opening.position.x - jamb - 10.0, opening.end.x + jamb + 10.0,
		opening.position.y - jamb - 9.0)
	# WHAT IS OUT THERE, as three bands rather than a picture: sky, the green of the terrace
	# behind it and the earth of the one she is standing on. A flat slab of cream reads as a
	# hole cut in the drawing; three bands read as outside, and at the width of a person
	# that is as much of the valley as anybody can see through it anyway.
	draw_rect(opening, DAYLIGHT_DIM)
	var inner := opening.grow(-5.0)
	draw_rect(inner, OUTSIDE_SKY)
	draw_rect(Rect2(inner.position.x, inner.position.y + inner.size.y * 0.52,
		inner.size.x, inner.size.y * 0.30), OUTSIDE_GREEN)
	draw_rect(Rect2(inner.position.x, inner.position.y + inner.size.y * 0.82,
		inner.size.x, inner.size.y * 0.18), OUTSIDE_EARTH)
	# The glare round the edge of it, because the eye in here is used to the dark.
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, 4.0)), DAYLIGHT)
	draw_rect(Rect2(inner.position, Vector2(4.0, inner.size.y)), DAYLIGHT)
	# Straw hanging across it, so it is a hole worn in a heap and not a fitted door.
	var x := opening.position.x
	while x < opening.end.x:
		var noise := _hash(int(x) * 29 + 4409)
		draw_rect(Rect2(x, opening.position.y, 1.0, 4.0 + float(noise % 26)),
			STRAW_DARK if noise % 3 == 0 else STRAW_SHADE)
		x += 2.0 + float(noise % 3)
	# And the light it throws on the floor in front of it, the same spill the doorways in
	# the house cast on the boards.
	var spill := 0
	while spill < int(floor_depth):
		var reach := float(spill) / floor_depth
		var wide := opening.size.x * (0.5 + reach * 0.55)
		draw_rect(Rect2(opening.get_center().x - wide, float(spill), wide * 2.0, 4.0),
			Color(0.980, 0.941, 0.792, 0.13 * (1.0 - reach)))
		spill += 4


## Trodden earth, laid in courses the way the boards in the house are, because a floor that
## is one flat colour is a floor nobody has walked on.
func _draw_floor() -> void:
	var half := _span()
	var room_length := half * 2.0
	draw_rect(Rect2(-half, 0.0, room_length, floor_depth + 60.0), EARTH_DARK)
	draw_rect(Rect2(-half, 0.0, room_length, floor_depth), EARTH)
	var y := 0.0
	var course := 0
	while y < floor_depth:
		var band := 18.0
		var shade := EARTH.lerp(EARTH_LIT, float(_hash(course) % 100) / 260.0)
		draw_rect(Rect2(-half, y, room_length, band), shade)
		draw_rect(Rect2(-half, y, room_length, 1.0), EARTH_DARK)
		# What has been walked into it: grit, and wisps of straw off the wall.
		var x := float(_hash(course * 3 + 1) % 90)
		while x < room_length:
			var noise := _hash(course * 7 + int(x))
			var at := Vector2(-half + x, y + 3.0 + float(noise % 9))
			if noise % 5 == 0:
				draw_rect(Rect2(at, Vector2(2.0 + float(noise % 3), 2.0)), PEBBLE)
			else:
				draw_rect(Rect2(at, Vector2(4.0 + float(noise % 11), 1.0)),
					STRAW_SHADE if noise % 3 == 0 else STRAW_DARK)
			x += 14.0 + float(noise % 30)
		y += band
		course += 1
	# The line where the floor meets the wall, and the shadow the wall drops onto it.
	draw_rect(Rect2(-half, 0.0, room_length, 3.0), Color(0.0, 0.0, 0.0, 0.36))
	draw_rect(Rect2(-half, 3.0, room_length, 3.0), Color(0.0, 0.0, 0.0, 0.20))
	draw_rect(Rect2(-half, 6.0, room_length, 3.0), Color(0.0, 0.0, 0.0, 0.10))


## One of Lola's, hung on the bales. Framed like the ones in the house, because it is one of
## the ones in the house -- and hung on a nail with a shadow under it, because a picture that
## is simply printed on the wall is a poster.
## The nail, and the shadow the key throws on the straw beside it. Small on purpose: the
## thing the eye should find in here is the brass, and a nail drawn large enough to notice
## is a nail the player tries to interact with.
func _draw_nail(at: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(-2.0, -26.0), Vector2(9.0, 3.0)), Color(0.42, 0.40, 0.38))
	draw_rect(Rect2(at + Vector2(-3.0, -27.0), Vector2(4.0, 4.0)), Color(0.60, 0.58, 0.55))


## A key, lying flat: a bow, a shank and two teeth. Twenty centimetres of brass, which is a
## door key of the age the chest beside it is -- and the reason it is worth drawing at all
## rather than being a glint on the floor.
func _draw_key(at: Vector2, alpha: float = 1.0) -> void:
	# The shadow it casts on the wall goes as it leaves, so the brass does not fade out over
	# a dark smear that stays behind.
	draw_rect(Rect2(at + Vector2(-20.0, -3.0), Vector2(44.0, 5.0)), Color(0, 0, 0, 0.45 * alpha))
	# The bow.
	draw_rect(Rect2(at + Vector2(-19.0, -15.0), Vector2(15.0, 15.0)), Color(BRASS_DARK, alpha))
	draw_rect(Rect2(at + Vector2(-18.0, -14.0), Vector2(13.0, 13.0)), Color(BRASS, alpha))
	draw_rect(Rect2(at + Vector2(-18.0, -14.0), Vector2(13.0, 2.0)), Color(BRASS_LIT, alpha))
	draw_rect(Rect2(at + Vector2(-14.0, -11.0), Vector2(6.0, 7.0)), Color(DEEPER, alpha))
	# The shank, and the two teeth on the end of it.
	draw_rect(Rect2(at + Vector2(-4.0, -11.0), Vector2(26.0, 6.0)), Color(BRASS_DARK, alpha))
	draw_rect(Rect2(at + Vector2(-4.0, -11.0), Vector2(26.0, 4.0)), Color(BRASS, alpha))
	draw_rect(Rect2(at + Vector2(-4.0, -11.0), Vector2(26.0, 1.0)), Color(BRASS_LIT, alpha))
	draw_rect(Rect2(at + Vector2(14.0, -5.0), Vector2(4.0, 5.0)), Color(BRASS_DARK, alpha))
	draw_rect(Rect2(at + Vector2(20.0, -5.0), Vector2(3.0, 4.0)), Color(BRASS_DARK, alpha))
