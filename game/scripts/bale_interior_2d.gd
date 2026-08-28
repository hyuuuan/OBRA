class_name BaleInterior2D
extends Node2D
## Inside Ang Bale: one room under the thatch, and Lola's next painting propped against the
## wall of it.
##
## IT IS THE ARTIST'S ROOM NOW. This was drawn by hand, board by board, and it is not any
## more: `assets/Level1/hut_interior.png` is the real thing -- bamboo walls, the thatch seen
## from underneath, a hearth on the floor with the drying rack hung over it, pots, a sleeping
## platform, and a doorway open onto the terraces. What is left in this file is the part a
## picture cannot do: where the floor is, where the walls stop, where the way out is, and
## what is in here to be taken.
##
## THE SCALE CAME FROM THE DOORWAY. The art was drawn at a size where a person would be
## about 290 pixels tall; the apo is 96. Rather than guess a number, the picture was reduced
## until its DOOR was about 140 tall -- a door is roughly two metres and the apo is one metre
## thirty, so a door they can walk through is half again their height. Everything else in the
## room then sits at the size it should relative to them.
##
## IT IS A PLACE, NOT A BACKDROP -- the arrangement the straw heap already uses. The house
## stands on the terrace at Node 3, and its inside is a room parked in the empty sky a long
## way above the level, which the player is stepped into when they get in. Same body, same
## level, so ink and the bag and every checkpoint carry in with them. It brings its own floor
## and its own end walls, because there is nothing under it but sky.
##
## AND IT FILLS THE SCREEN. The level is drawn at 1 because it is a valley; this is somewhere
## you are standing IN, so the camera comes in until the picture covers the frame edge to edge
## and is held inside it -- see `room_zoom` and `camera_rect`. A room with visible edges and a
## border of nothing around it is a diorama, not a place.

## The apo has walked into the doorway, which is the way back down the ladder.
signal exit_reached()
## Lola's painting has been taken.
signal painting_taken()
## The apo is standing at something in here worth a sentence, or has walked away from it.
##
## THE ROOM HAD ONE THING IN IT AND THAT WAS THE PROBLEM. Getting in is the hard part of
## Node 3, and what was on the other side was a picture of a room, a canvas to walk into, and
## a way out -- so the reward for the level's longest puzzle was a corridor. The hearth, the
## jars and the sleeping platform are all painted in the art already; these make them things
## the player finds rather than things they walk past. It is the HINT channel: no key press,
## no pause, and it clears itself, because none of it is story and none of it may stop play.
signal noticed(text: String)
signal notice_left()

const ART: Texture2D = preload("res://assets/Level1/hut_interior.png")

## The picture, and where this node's origin sits in it: the middle of the room, on the
## FLOOR LINE the apo stands on -- which is the boards in front of the hearth, not the bottom
## edge of the image. The art carries another sixty pixels of floor below that, running
## toward the viewer, and the apo walks in front of none of it.
const ART_SIZE := Vector2(557.0, 314.0)
const ART_ORIGIN := Vector2(278.0, 250.0)

## How far along the floor the apo may walk, either side of the middle. Short of the walls,
## so they never stand inside the bamboo.
const WALK_HALF := 232.0
## The doorway, in room space: the opening on the left with the rail across it and the
## terraces beyond. Walking into it is climbing back down.
const DOOR_AT := Vector2(-206.0, -42.0)
const DOOR_SIZE := Vector2(64.0, 84.0)
## Where the canvas leans: against the wall between the doorway and the hearth, beside the
## boards already stacked there -- which is where you would actually put a picture you had
## just carried up a ladder.
##
## ITS Y IS NOT THE WALK LINE. The apo walks at y 0, which in this picture is the boards in
## FRONT of the hearth; the floor keeps receding above that, and the foot of the bamboo is
## about thirty-four units up it. A canvas drawn at 0 stands in the middle of the room with
## nothing behind it, which is exactly what it looked like. The trigger still reaches down to
## the walk line, so it is picked up by walking past it and not by standing on the wall.
## AND CLEAR OF THE DOORWAY. The apo arrives at `entry_point`, which is 54 units in from the
## opening, and `_sweep_for_taker` hands over anything they are already standing on -- so a
## canvas moved a little way toward the door is a canvas collected before the player has
## looked at the room. It sits at the right-hand end of the stacked boards instead, which is
## a walk in rather than a step. `run_room_probe` measures the gap.
const PAINTING_AT := Vector2(-76.0, -34.0)
## How big it is: about a third of the apo's height. It was two thirds, which at this zoom
## made a two-hundred-pixel slab of flat colour the biggest thing in a room full of detail.
## LANDSCAPE, AND THE SAME SHAPE AS THE HUB'S FRAMES. It was 36 x 46, an upright canvas
## carrying a hand-placed sketch of a plaza; the picture it is supposed to BE is
## `assets/hub/paintings/level_2.png`, which is 128 x 72. Sixty-four by thirty-six is that
## ratio exactly, and with the moulding it comes to 74 wide -- the width of the trigger that
## was already authored around it.
const CANVAS_SIZE := Vector2(64.0, 36.0)

## THE THINGS IN HERE THAT ARE WORTH A SENTENCE, read off the artist's own picture: the
## hearth on the floor with its drying rack overhead, her stacked jars, and the sleeping
## platform along the right-hand wall. Each is an x on the floor and a band around it, and
## the bands do not touch -- two notices firing on one step would fight over the bar.
##
## NOT ONE OF THESE NAMES A DRAWABLE CLASS. That is a level-wide rule (LEVEL_1.md), it is
## asserted, and it is easiest to break somewhere like this where the writing is about
## objects. "Jars", not the thing you carry water in; "way back down", not the thing in a
## wall you open.
const NOTICE_WIDTH := 72.0
const NOTICES: Array[Dictionary] = [
	{
		"at": -23.0,
		"text": "Cold ash in the hearth, and the rack still hung over it.",
	},
	{
		"at": 49.0,
		"text": "Her jars, lidded and stacked. Somebody meant to come back for these.",
	},
	{
		"at": 182.0,
		"text": "A sleeping mat, rolled and put by. People lived up here.",
	},
]

## HOW FAR IN THE CAMERA SITS, and it is THREE rather than the two the heap uses.
##
## The heap's room is fifteen metres of barn drawn a good deal wider than the screen, so at
## 2 there is always more of it past the edge of the frame. This one is a single picture, 557
## by 314, and at 2 the screen shows 800 by 450 -- so the house sat in the middle of the
## screen at two thirds size with a black border painted around it, floating in the sky it is
## actually standing in. A room you are inside should not have edges you can see.
##
## Three is the number because the art is drawn at ONE world pixel to one art pixel and the
## screen is 1600 by 900: at 3 a screenful is 533 by 300, which the picture (557 by 314)
## covers completely with a dozen pixels to spare on each side. It is also an INTEGER, so
## every art pixel is exactly three screen pixels and the pixel grid survives -- 2.87 would
## have filled the frame to the millimetre and made the whole room shimmer.
@export var room_zoom := 3.0
## What the profile records when the painting is taken. It is the way into Pista -- see
## game_level's _grant_the_canvas.
@export var painting_id: String = "canvas_2_pista"

# --- The canvas ---------------------------------------------------------------------------
## Gilt, the same gold the hub's frames and the HUD are drawn in, because this is one of
## Lola's and the player has already seen four of them hanging on her wall.
const FRAME_EDGE := UISkin.GILT_EDGE
const FRAME_DARK := UISkin.GILT_DARK
const FRAME := UISkin.GILT
const FRAME_LIT := UISkin.GILT_HI
## WHAT IS PAINTED ON IT, AND IT IS THE ACTUAL PAINTING.
##
## This was a plaza roughed in out of thirty draw_rect calls -- a sky band, a church, some
## bunting -- standing in for a picture that already exists in the project and is already
## loaded by the hub: the player is going to walk up to this exact image on Lola's wall five
## minutes later. Two drawings of one painting is one drawing too many, and the one the
## player is told to remember should be the one they are shown.
const PISTA_ART: Texture2D = preload("res://assets/hub/paintings/level_2.png")

const SHADOW := Color(0.0, 0.0, 0.0, 0.35)
## Outside the room entirely, and a BACKSTOP rather than the normal case now. The picture
## covers the frame at this zoom and the camera is clamped inside it, so in ordinary play none
## of this is ever seen; it is there for the frame during a zoom tween, and for anything that
## moves the camera before the room has told it where it may look. Without it the room floats
## in the middle of Payyo's sky with clouds going by on both sides of it, which is what a room
## parked a thousand units above a valley actually has behind it and exactly what it must not
## look like. Generous, because it costs one rect and it is only drawn while she is in here.
const BEYOND := Color(0.031, 0.024, 0.016, 1.0)

var _painting_area: Area2D
## How many of the room's notice bands the player is standing in. A COUNT rather than a bool,
## because leaving one band as you enter the next arrives as exit-then-enter or the reverse
## depending on the step, and a bool would blink the bar off in the middle of a walk.
var _in_notices := 0
var _taken := false
## Seconds left before the hatch means "leave" again.
var _way_down_grace := 0.0
## The lift and fade when it is picked up, driven by a tween through the setters so the node
## has no idle work when nothing is happening.
var _lift := 0.0:
	set(value):
		_lift = value
		queue_redraw()
var _fade := 1.0:
	set(value):
		_fade = value
		queue_redraw()


func _ready() -> void:
	add_to_group(&"bale_interiors")
	# The group the level asks "which room is the player standing in", shared with the straw
	# room so the camera rule is written once for both.
	add_to_group(&"interiors")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -10
	_build_floor()
	_build_painting_area()
	_build_notices()
	refresh_from_profile()


## Re-read whether the painting is still here, and set the room to match.
##
## ASKED ON ENTRY, NOT CACHED AT _READY. The room is built when the level loads and entered
## much later, and the profile can move in between -- a checkpoint restore, a reload, or the
## suite clearing the canvas to run a route again. A snapshot taken at build time goes stale
## silently and in the worst possible direction: the room decides the painting is already
## gone, switches its trigger off for good, and the player walks through an empty house that
## will never hand them anything.
## AND IT ASKS THE RUN, NOT THE PROFILE. `has_object` is permanent by design -- it is what
## opens Pista and what a concept gate two levels away reads -- so once anybody had taken
## this painting, every later run of Level 1 opened the house empty. A player who finished
## the level and started it again solved Node 3, climbed the ladder, and found the room the
## whole level is for with nothing in it. Whether the world still HAS one is a question about
## this run; whether the player OWNS one is a question for the profile, and they were the
## same line of code. See GameLevel.pickup_taken_this_run.
##
## The profile is still the fallback for a room instantiated on its own, with no level around
## it, which is how several fixtures build one.
func refresh_from_profile() -> void:
	var run := get_tree().get_first_node_in_group(&"level_run_state")
	if run != null and run.has_method("pickup_taken_this_run"):
		_taken = bool(run.call("pickup_taken_this_run", painting_id))
	else:
		var profile := get_node_or_null(^"/root/PlayerProfile")
		_taken = profile != null and bool(profile.call("has_object", painting_id))
	_fade = 0.0 if _taken else 1.0
	_lift = 0.0
	if _painting_area != null:
		_painting_area.monitoring = not _taken
		if not _taken:
			_sweep_for_taker.call_deferred()
	queue_redraw()


## Take it if somebody is ALREADY STANDING ON IT when the trigger arms.
##
## `body_entered` is a TRANSITION, and there is no transition for a body that was already
## inside. The player is put into this room by a teleport rather than by walking through a
## door, so where they land is decided by `entry_point()` -- and the day somebody moves that
## a few pixels closer to the wall, the canvas becomes permanently unpickable and the room
## quietly has nothing in it. Cheap to sweep once; impossible to notice if it is missing.
##
## THE COST OF IT IS THE OPPOSITE MISTAKE, and that one has been made: put the canvas near
## the doorway and this hands it over on arrival, so the reward for the level's longest
## puzzle is collected before the player has looked at the room. `run_room_probe` measures
## the gap between where they land and where the trigger starts.
func _sweep_for_taker() -> void:
	if _taken or _painting_area == null or not _painting_area.monitoring:
		return
	for body in _painting_area.get_overlapping_bodies():
		if _is_player(body):
			_on_painting_body(body)
			return


# --- Being a place ------------------------------------------------------------------------

## The box the room occupies. The level asks this to decide whether the apo is in here rather
## than tracking a flag -- so a checkpoint restore or a fall that moves them without going
## through the doorway cannot strand the camera.
func bounds() -> Rect2:
	return Rect2(global_position - ART_ORIGIN, ART_SIZE)


func how_far_in() -> float:
	return room_zoom


## THE BOX THE CAMERA MAY NOT LOOK OUT OF: the picture itself, and nothing past it.
##
## Filling the screen is only half of it. The camera follows the apo horizontally, and at 3
## it can see 533 of the picture's 557 -- so without this it slid twenty-odd units off the
## edge as she walked and put the void the room is parked in back on screen at the side.
## Handed to the camera on the way through the door; see GameLevel._walk_through.
func camera_rect() -> Rect2:
	return bounds()


## Where the camera sits to look at this room: the middle of the picture, so a screenful
## shows the whole of it and neither the roof nor the floor slides off as they walk.
func eye_level() -> float:
	return global_position.y - ART_ORIGIN.y + ART_SIZE.y * 0.5


## Where the apo appears when they get in: just inside the doorway, so the first thing they
## can see is how to leave and the room is in front of them rather than behind.
func entry_point() -> Vector2:
	return global_position + Vector2(DOOR_AT.x + 54.0, 0.0)


## The doorway, in the room's own space.
func exit_rect() -> Rect2:
	return Rect2(DOOR_AT - DOOR_SIZE * Vector2(0.5, 1.0), DOOR_SIZE)


func painting_is_taken() -> bool:
	return _taken


## SOMETHING TO STAND ON. The room is in the sky above the level, so it brings its own floor;
## without it the apo drops out of the bottom of it and the level fishes them back to a
## checkpoint on the terrace, which is a very confusing way to leave a room.
func _build_floor() -> void:
	var body := StaticBody2D.new()
	body.name = "Floor"
	add_child(body)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(ART_SIZE.x, 120.0)
	shape.shape = box
	shape.position = Vector2(0.0, 60.0)
	body.add_child(shape)
	# And a wall at each end, so they cannot walk out of the ends of the room into the sky it
	# is standing in. Set at the WALK LIMIT rather than at the picture's edge: the bamboo is
	# drawn in perspective and its foot is well inside the frame.
	# FLOOR TO RIDGE, not just to head height. At 240 the wall stopped level with the eaves,
	# and anything that got above it -- a placed object bumped up a step, a morph mid-jump --
	# went over the top and out of the room into the sky. It costs nothing to close.
	for side: float in [-1.0, 1.0]:
		var wall := StaticBody2D.new()
		wall.name = "Wall%s" % ("L" if side < 0.0 else "R")
		add_child(wall)
		var wall_shape := CollisionShape2D.new()
		var wall_box := RectangleShape2D.new()
		wall_box.size = Vector2(48.0, 420.0)
		wall_shape.shape = wall_box
		wall_shape.position = Vector2(side * (WALK_HALF + 24.0), -170.0)
		wall.add_child(wall_shape)

	# AND A CEILING, for the same reason the ends are floor-to-ridge. The walls close the
	# sides and closed nothing overhead, so anything that could climb or fly -- which is a
	# thing the player can now draw, in here, at will -- left through the roof of the picture
	# into the empty sky this room is parked in. A house you can walk out of the top of is
	# not a room.
	var roof := StaticBody2D.new()
	roof.name = "Roof"
	add_child(roof)
	var roof_shape := CollisionShape2D.new()
	var roof_box := RectangleShape2D.new()
	roof_box.size = Vector2(ART_SIZE.x + 96.0, 48.0)
	roof_shape.shape = roof_box
	# At the top of the PICTURE, which is ART_ORIGIN.y up from here -- not ART_SIZE.y, which
	# would put it above the room's own bounds and let a flier out of them before it hit.
	roof_shape.position = Vector2(0.0, -ART_ORIGIN.y + 24.0)
	roof.add_child(roof_shape)


## WALKED INTO, not pressed at -- the same rule the straw room's way out follows. E reaches
## placed drawings and nothing else, and a second meaning for it inside a room would be one
## meaning too many.
## THE WAY DOWN IS A DISTANCE, NOT A TRIGGER -- the same fix, and the same reason, as
## StrawRoom2D's doorway.
##
## `entry_point()` puts the player 34 pixels from this opening, which is clear for the apo's
## capsule and not clear for a DRAWN CREATURE: a rig is a graph of bodies spread over whatever
## was drawn, so a morph arriving in the house is already touching the hatch and drops straight
## back onto the terrace. Node 3's Artist route is Climb, so arriving here as a spider is the
## intended way in -- this was reachable in normal play.
##
## Arming on `body_exited` does not work either: a rig's bodies cross a threshold dozens of
## times a second while it settles. One position, measured, so a capsule and a twelve-body
## spider behave the same.
## Measured against where they land, and on ONE position rather than on overlaps.
## `entry_point()` is about seventy units from the middle of the hatch. ⚠ No "walk further in
## first" rule: the straw room had one and it made that room a trap for anybody who turned
## straight back. A short grace after arrival is all this needs.
const WAY_DOWN_FIRES_AT := 44.0
const WAY_DOWN_GRACE := 0.5


## Called by the level on the way in: every visit starts inert.
func disarm_the_way_out() -> void:
	_way_down_grace = WAY_DOWN_GRACE


## The room already has to know whether the player is in it; this rides the same answer.
func _process(delta: float) -> void:
	if _way_down_grace > 0.0:
		_way_down_grace -= delta
		return
	var at := Vector2.INF
	for node in get_tree().get_nodes_in_group(&"player_character"):
		var body := node as Node2D
		if body != null and bounds().grow(90.0).has_point(body.global_position):
			at = body.global_position
			break
	if at == Vector2.INF:
		return
	if at.distance_to(global_position + exit_rect().get_center()) < WAY_DOWN_FIRES_AT:
		_way_down_grace = WAY_DOWN_GRACE
		exit_reached.emit()


## And the painting is taken the same way, for the same reason.
func _build_painting_area() -> void:
	_painting_area = Area2D.new()
	_painting_area.name = "Painting"
	_painting_area.collision_layer = 0
	_painting_area.collision_mask = 1
	_painting_area.position = PAINTING_AT
	add_child(_painting_area)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(74.0, 96.0)
	shape.shape = box
	shape.position = Vector2(0.0, -44.0)
	_painting_area.add_child(shape)
	_painting_area.body_entered.connect(_on_painting_body)
	_painting_area.monitoring = not _taken


## The three things in here that are worth a sentence. Same rule as the way out and the
## canvas: walked into, not pressed at.
func _build_notices() -> void:
	for entry: Variant in NOTICES:
		var notice: Dictionary = entry
		var area := Area2D.new()
		area.name = "Notice%d" % int(float(notice["at"]))
		area.collision_layer = 0
		area.collision_mask = 1
		area.position = Vector2(float(notice["at"]), 0.0)
		add_child(area)
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(NOTICE_WIDTH, 108.0)
		shape.shape = box
		shape.position = Vector2(0.0, -54.0)
		area.add_child(shape)
		var text := String(notice["text"])
		area.body_entered.connect(func(body: Node) -> void: _on_notice_entered(body, text))
		area.body_exited.connect(_on_notice_exited)


func _on_notice_entered(body: Node, text: String) -> void:
	if not _is_player(body):
		return
	_in_notices += 1
	noticed.emit(text)


func _on_notice_exited(body: Node) -> void:
	if not _is_player(body):
		return
	_in_notices = maxi(0, _in_notices - 1)
	if _in_notices == 0:
		notice_left.emit()


func _on_painting_body(body: Node) -> void:
	if _taken or not _is_player(body):
		return
	_taken = true
	# DEFERRED. Godot blocks writes to `monitoring` from inside an area's own body_entered --
	# "Function blocked during in/out signal" -- and the write silently does nothing, so the
	# trigger stays armed and a second body walking over the same spot runs all of this
	# again. Set on the next idle frame instead, which is what the engine's error message
	# asks for.
	_painting_area.set_deferred(&"monitoring", false)
	# It leaves before it is gone. `painting_taken` fires NOW rather than when the tween
	# ends, because nothing downstream should wait on an animation to know the player has
	# it -- the profile is written on the other end of this signal.
	# AND IT IS THROWN A FLOURISH, the same one the brass on the nail gets. This is the object
	# the whole level is for; it used to lift and fade and that was all, which at a glance is
	# indistinguishable from a sprite being switched off.
	PickupFlourish2D.burst(self, PAINTING_AT - Vector2(0.0, CANVAS_SIZE.y * 0.5))
	var lift := create_tween()
	lift.set_parallel(true)
	lift.tween_property(self, "_lift", 44.0, 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	lift.tween_property(self, "_fade", 0.0, 0.45).set_delay(0.1)
	painting_taken.emit()


## The same test the straw room's key uses, and it has to be: for most of Node 3 the player
## is a DRAWN CREATURE rather than the apo, and a check that only knew about the wanderer
## would refuse to hand the painting to the body that climbed in to get it.
func _is_player(body: Node) -> bool:
	var node := body as Node
	while node != null:
		if node.is_in_group(&"player_character") or node is ActiveRagdollMorph:
			return true
		node = node.get_parent()
	return false


# --- Drawing --------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(-ART_ORIGIN - Vector2(700.0, 500.0),
		ART_SIZE + Vector2(1400.0, 1000.0)), BEYOND)
	draw_texture_rect(ART, Rect2(-ART_ORIGIN, ART_SIZE), false)
	if _fade > 0.0:
		_draw_painting()


## Lola's canvas, leaning face-out against the bamboo.
##
## LEANING, NOT HUNG. A picture on a nail is part of the room and reads as decoration; one
## standing on the floor with its back against the wall is a thing somebody carried in and
## put down -- which is what this is, and it is the only object in here that does not belong
## to the house.
##
## It is PISTA -- the artist's own picture, the one that hangs second on Lola's wall, drawn
## here at one world pixel to one art pixel inside a moulding built the same way the hub's
## frames are. The player is going to stand in front of this exact image in the house five
## minutes from now, and the whole point of the beat is that they recognise it when they do.
func _draw_painting() -> void:
	var w := CANVAS_SIZE.x
	var h := CANVAS_SIZE.y
	var at := PAINTING_AT - Vector2(0.0, _lift)

	# Its shadow on the boards, which is what stops it floating.
	draw_rect(Rect2(at.x - w * 0.5 - 3.0, at.y - 3.0, w + 6.0, 4.0),
		Color(SHADOW.r, SHADOW.g, SHADOW.b, SHADOW.a * _fade))

	var canvas := Rect2(at.x - w * 0.5, at.y - h, w, h)
	# The moulding: stepped bands, lighter on the top and left where the light is, which is
	# the same ramp the frames in the hub are drawn with.
	draw_rect(canvas.grow(5.0), Color(FRAME_EDGE, _fade))
	draw_rect(canvas.grow(4.0), Color(FRAME_DARK, _fade))
	draw_rect(canvas.grow(3.0), Color(FRAME, _fade))
	draw_rect(Rect2(canvas.position.x - 3.0, canvas.position.y - 3.0, w + 6.0, 2.0),
		Color(FRAME_LIT, _fade))
	draw_rect(Rect2(canvas.position.x - 3.0, canvas.position.y - 3.0, 2.0, h + 6.0),
		Color(FRAME_LIT, _fade))

	draw_texture_rect(PISTA_ART, canvas, false, Color(1.0, 1.0, 1.0, _fade))

	# A catch of light down the left of the canvas, because it is leaning toward the door.
	draw_rect(Rect2(canvas.position, Vector2(2.0, h)),
		Color(1.0, 1.0, 1.0, 0.13 * _fade))


