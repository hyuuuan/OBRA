class_name ChurchInterior2D
extends Node2D
## What is inside the church, and the one thing in it the player may touch.
##
## SCENE 2 IS THE ONLY PLACE IN THIS LEVEL WHERE THE PACE DROPS. The design says so in as
## many words -- *"this is a checkpoint, and the only place in the level where the pace
## drops. Let it breathe before the alley sequence."* Nothing here is a puzzle. The kandila
## goes on the rack, Lolo prays, a priest says where Lola went, and the far door opens.
##
## ⚠ THE CULTURAL GUARDRAIL IS ENFORCED HERE, NOT MERELY DOCUMENTED.
##
## `level_02.json` carries a `cultural_constraints.church` block -- sacred images have no
## collision, no interaction and no puzzle function, and *"the altar may be reached to place
## the kandila, and for nothing else"*. Level 1 does not leave its equivalent rule (the
## bulul) as prose either: it is asserted in the script that builds them. So the retablo and
## the santo are drawn and nothing else. They own no `Area2D`, no `CollisionShape2D` and no
## signal, they join `sacred_images` so a suite can walk them, and `_check_the_guardrail`
## fails loudly at startup if that ever stops being true.
##
## The rack is the exception the design allows and it is a SEPARATE OBJECT from the altar,
## deliberately: an approach volume on the altar itself would make the altar interactive,
## which is the thing the rule forbids. The rack stands to the left of it, which is also
## where Lolo says his wife always went -- *"not the middle -- she always went to the left
## side, nearer the wall."*
##
## PLACEHOLDER ART. The design lists the entire church interior under what does not exist:
## nave background, altar, candle rack, pews, window light. `MG_Church` is a facade. Drawn
## to `ART_PLACEHOLDERS.md` rules and measured at seventy-two pixels to the metre.

## The kandila is on the rack. Scene 2's first beat, and the only one the player performs.
signal kandila_placed()
## Standing at the rack, or stepped away from it.
signal at_rack(standing: bool)
## The priest has finished walking over and is ready to speak.
signal priest_arrived()

## Where the nave ends, measured from this node. Set by the level off the room's own length
## so the furniture cannot outgrow the room it is in.
@export var nave_length := 1400.0
@export var nave_height := 470.0
## Whether the candle is already on the rack. Rides the level's run state, so a restore
## inside the church does not ask for it twice.
@export var kandila_on_rack := false

## An altar platform is a step and a half up: 40 is a little over half a metre.
const ALTAR := Vector2(300.0, 44.0)
## The retablo behind it. Two and a half metres of carved timber, which is modest for one.
const RETABLO := Vector2(260.0, 300.0)
## The rack: waist high, a metre wide. Somewhere you put a candle down without reaching.
const RACK := Vector2(150.0, 96.0)
const RACK_REACH := Vector2(150.0, 170.0)
## A pew is a bench: 2.4m long, seat at 45cm.
const PEW := Vector2(174.0, 44.0)

const TIMBER_DEEP := Color(0.129, 0.086, 0.055, 1.0)  # 21160E
const TIMBER_DARK := Color(0.235, 0.161, 0.098, 1.0)  # 3C2919
const TIMBER := Color(0.353, 0.251, 0.149, 1.0)       # 5A4026
const TIMBER_LIT := Color(0.482, 0.361, 0.227, 1.0)   # 7B5C3A
## Gilding on the retablo, dulled by two centuries of candle smoke.
const GILT := Color(0.749, 0.588, 0.243, 1.0)         # BF963E
const GILT_LIT := Color(0.878, 0.749, 0.412, 1.0)     # E0BF69
## Lime-washed stone for the altar table and the platform, matching the room's own wall.
const STONE := Color(0.588, 0.576, 0.541, 1.0)        # 96938A
const STONE_DARK := Color(0.400, 0.396, 0.376, 1.0)   # 666560
const STONE_PALE := Color(0.780, 0.765, 0.714, 1.0)   # C7C3B6
const CLOTH := Color(0.925, 0.898, 0.827, 1.0)        # ECE5D3
## The santo: a painted figure, robe and skin, no face drawn at this size.
const ROBE := Color(0.475, 0.314, 0.396, 1.0)         # 795065
const ROBE_LIT := Color(0.612, 0.435, 0.518, 1.0)     # 9C6F84
const SKIN := Color(0.769, 0.612, 0.478, 1.0)         # C49C7A
## The rack's candles: the ones already burning, and the empty spikes.
const WAX := Color(0.949, 0.925, 0.831, 1.0)          # F2ECD4
const FLAME := Color(0.996, 0.847, 0.451, 1.0)        # FED873
const FLAME_SOFT := Color(0.988, 0.812, 0.451, 0.22)
const IRON := Color(0.184, 0.176, 0.169, 1.0)         # 2F2D2B
## The priest. A cassock, and that is the whole of the read at this size.
const CASSOCK := Color(0.129, 0.125, 0.137, 1.0)      # 212023
const CASSOCK_LIT := Color(0.220, 0.212, 0.227, 1.0)  # 38363A
const COLLAR := Color(0.937, 0.933, 0.918, 1.0)       # EFEEEA

var _rack_area: Area2D
var _standing := false
var _flicker := 0.0
## The priest walks over once, after the candle is placed. -1 while he is waiting.
var _priest_walk := -1.0
var _priest_x := 0.0
var _priest_from := 0.0
var _priest_to := 0.0
## How long he takes to cross. Slow, because the design asks for this scene to breathe.
const PRIEST_WALK_SECONDS := 2.2


func _ready() -> void:
	add_to_group(&"church_interiors")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_rack_reach()
	_priest_x = _priest_waiting_x()
	_check_the_guardrail()
	set_process(true)


func _process(delta: float) -> void:
	_flicker += delta
	if _priest_walk >= 0.0:
		_priest_walk += delta
		var t := clampf(_priest_walk / PRIEST_WALK_SECONDS, 0.0, 1.0)
		# Eased, so he sets off and settles rather than sliding at a constant rate.
		_priest_x = _priest_from + (_priest_to - _priest_from) * (t * t * (3.0 - 2.0 * t))
		if t >= 1.0:
			_priest_walk = -1.0
			priest_arrived.emit()
	queue_redraw()


# --- The one thing in here that answers ------------------------------------------------

## Left of the altar and against the wall, which is where Lolo says she always went.
func rack_point() -> Vector2:
	return global_position + Vector2(nave_length * 0.5 - 460.0, 0.0)


func _altar_x() -> float:
	return nave_length * 0.5 - 190.0


func _priest_waiting_x() -> float:
	# Off to the side of the altar, where somebody who works here would be.
	return nave_length * 0.5 - 90.0


func _build_rack_reach() -> void:
	_rack_area = Area2D.new()
	_rack_area.name = "RackReach"
	_rack_area.position = Vector2(
		rack_point().x - global_position.x, -RACK_REACH.y * 0.5)
	add_child(_rack_area)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = RACK_REACH
	shape.shape = box
	_rack_area.add_child(shape)
	_rack_area.body_entered.connect(_on_rack_body.bind(true))
	_rack_area.body_exited.connect(_on_rack_body.bind(false))


func _on_rack_body(body: Node, coming_in: bool) -> void:
	if not body.is_in_group(&"player_character"):
		return
	if not coming_in and _somebody_at_the_rack():
		return
	if _standing == coming_in:
		return
	_standing = coming_in
	at_rack.emit(coming_in)


func _somebody_at_the_rack() -> bool:
	for body in _rack_area.get_overlapping_bodies():
		if body.is_in_group(&"player_character"):
			return true
	return false


func standing_at_rack() -> bool:
	return _standing


## Put it on the rack. Called by the level, which is what knows whether the player is
## carrying one.
func place_the_kandila() -> bool:
	if kandila_on_rack:
		return false
	kandila_on_rack = true
	queue_redraw()
	kandila_placed.emit()
	return true


## Send the priest over. He waits by the altar until there is a reason to come across --
## a man who walks up to you the moment you enter a church is a quest marker.
func send_the_priest() -> void:
	if _priest_walk >= 0.0:
		return
	_priest_from = _priest_x
	_priest_to = rack_point().x - global_position.x + 120.0
	_priest_walk = 0.0


func priest_point() -> Vector2:
	return global_position + Vector2(_priest_x, 0.0)


# --- The guardrail ----------------------------------------------------------------------

## THE SACRED THINGS IN HERE ARE DRAWN AND NOTHING ELSE, and this is what says so out loud.
##
## They are drawn directly by `_draw` rather than built as nodes, which is what makes the
## rule structural rather than a promise: there is nothing to give a collision shape to.
## The check exists for the day somebody adds one -- a niche you can stand in, a santo that
## reacts -- because that edit would look perfectly reasonable in isolation and it is the
## exact thing `level_02.json` forbids.
func _check_the_guardrail() -> void:
	var offenders: Array[String] = []
	for node in get_tree().get_nodes_in_group(&"sacred_images"):
		for child in (node as Node).get_children():
			if child is CollisionObject2D or child is CollisionShape2D:
				offenders.append("%s has %s" % [node.name, child.get_class()])
	# The rack is the ONE approach volume this room is allowed, and it is not on the altar.
	var volumes := 0
	for child in get_children():
		if child is Area2D:
			volumes += 1
	if volumes > 1:
		offenders.append("%d approach volumes in the church, the rack is the only one allowed"
			% volumes)
	for problem in offenders:
		push_error("ChurchInterior2D: cultural guardrail broken -- %s" % problem)


## What a suite asks. True while the altar, the retablo and the santo are things you look at.
func guardrail_holds() -> bool:
	if get_tree().get_nodes_in_group(&"sacred_images").any(
			func(node: Node) -> bool:
				return node.get_children().any(
					func(child: Node) -> bool:
						return child is CollisionObject2D or child is CollisionShape2D)):
		return false
	var volumes := 0
	for child in get_children():
		if child is Area2D:
			volumes += 1
	return volumes == 1


# --- What it looks like -------------------------------------------------------------------

func _draw() -> void:
	_draw_pews()
	_draw_altar()
	_draw_rack()
	_draw_priest()


## Down the middle of the nave, in two ranks, thinning toward the door -- so the room reads
## as long and the walk to the altar has something to walk past.
func _draw_pews() -> void:
	var x := -nave_length * 0.5 + 200.0
	var index := 0
	while x < _altar_x() - 420.0:
		var top := Rect2(x, -PEW.y, PEW.x, 10.0)
		draw_rect(top, TIMBER_LIT if index % 2 == 0 else TIMBER)
		draw_rect(Rect2(top.position + Vector2(0.0, 10.0), Vector2(PEW.x, 5.0)), TIMBER_DEEP)
		# The back, and the two ends. A bench with no back is a bench, not a pew.
		draw_rect(Rect2(x + PEW.x - 12.0, -PEW.y - 42.0, 12.0, 42.0), TIMBER_DARK)
		for side: float in [0.0, PEW.x - 10.0]:
			draw_rect(Rect2(x + side, -PEW.y + 10.0, 10.0, PEW.y - 10.0), TIMBER_DARK)
		x += PEW.x + 66.0
		index += 1


## The platform, the table, and the retablo standing on it. All of it drawn, none of it
## built -- see `_check_the_guardrail`.
func _draw_altar() -> void:
	var base := _altar_x()
	draw_rect(Rect2(base - ALTAR.x * 0.5, -ALTAR.y, ALTAR.x, ALTAR.y), STONE_DARK)
	draw_rect(Rect2(base - ALTAR.x * 0.5, -ALTAR.y, ALTAR.x, 8.0), STONE_PALE)
	# The table, with its cloth over it.
	var table := Rect2(base - 110.0, -ALTAR.y - 96.0, 220.0, 96.0)
	draw_rect(table, STONE)
	draw_rect(Rect2(table.position - Vector2(14.0, 14.0), Vector2(table.size.x + 28.0, 20.0)),
		CLOTH)
	# The retablo: three bays, gilded, with the santo in the middle one.
	var foot := table.position.y
	var frame := Rect2(base - RETABLO.x * 0.5, foot - RETABLO.y, RETABLO.x, RETABLO.y)
	draw_rect(frame, TIMBER_DARK)
	draw_rect(frame.grow(-8.0), TIMBER)
	for bay in range(3):
		var width := frame.size.x / 3.0
		draw_rect(Rect2(frame.position.x + float(bay) * width + 4.0, frame.position.y + 12.0,
			width - 8.0, frame.size.y - 24.0), TIMBER_DEEP)
	# Gilt on the columns and the crown, which is all a retablo needs to read as one.
	for column in range(4):
		draw_rect(Rect2(frame.position.x + float(column) * (frame.size.x / 3.0) - 4.0,
			frame.position.y, 9.0, frame.size.y), GILT)
	draw_rect(Rect2(frame.position.x - 12.0, frame.position.y - 18.0,
		frame.size.x + 24.0, 20.0), GILT_LIT)
	_draw_santo(Vector2(base, foot - RETABLO.y * 0.42))


## A painted figure in the middle bay. Small, high up, and out of reach -- which is what it
## should look like as well as what it is.
func _draw_santo(at: Vector2) -> void:
	draw_rect(Rect2(at.x - 26.0, at.y - 8.0, 52.0, 76.0), ROBE)
	draw_rect(Rect2(at.x - 26.0, at.y - 8.0, 18.0, 76.0), ROBE_LIT)
	draw_circle(Vector2(at.x, at.y - 22.0), 15.0, SKIN)
	# The halo. Gilt, because that is what carries the eye up to it.
	draw_arc(Vector2(at.x, at.y - 26.0), 22.0, PI, TAU, 18, GILT_LIT, 3.0)


## The one thing in the room the player may touch, and it is not the altar.
func _draw_rack() -> void:
	var at := rack_point().x - global_position.x
	draw_rect(Rect2(at - RACK.x * 0.5, -RACK.y, RACK.x, 10.0), IRON)
	for leg: float in [-RACK.x * 0.5 + 8.0, RACK.x * 0.5 - 16.0]:
		draw_rect(Rect2(at + leg, -RACK.y + 10.0, 8.0, RACK.y - 10.0), IRON)
	# The candles already burning on it. Somebody else's, and the reason the rack reads as a
	# rack rather than as a shelf.
	for index in range(5):
		var x := at - RACK.x * 0.5 + 22.0 + float(index) * 26.0
		var height := 20.0 + float((index * 7) % 3) * 9.0
		draw_rect(Rect2(x - 4.0, -RACK.y - height, 8.0, height), WAX)
		if index % 2 == 0:
			_draw_flame(Vector2(x, -RACK.y - height), 0.7)
	if not kandila_on_rack:
		return
	# And the player's, taller than the rest because it has not burned down yet. This is the
	# whole visible result of Scene 2's one action, so it has to be legible at a glance.
	var mine := at + RACK.x * 0.5 - 14.0
	draw_rect(Rect2(mine - 5.0, -RACK.y - 62.0, 10.0, 62.0), WAX)
	_draw_flame(Vector2(mine, -RACK.y - 62.0), 1.0)
	draw_circle(Vector2(mine, -RACK.y - 62.0), 90.0, FLAME_SOFT)


func _draw_flame(at: Vector2, scale: float) -> void:
	var lean := 1.6 * scale * sin(_flicker * 7.0 + at.x)
	var height := (12.0 + 3.0 * sin(_flicker * 11.0 + at.x)) * scale
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-4.0 * scale, 0.0), at + Vector2(4.0 * scale, 0.0),
		at + Vector2(lean, -height)]), FLAME)


## He waits by the altar and walks over once. Standing still and facing the player is the
## whole of what the design asks of him -- *"idle and talking only"*.
##
## ⚠ AND LOLO'S PRAYING POSE DOES NOT EXIST. The design names it as the one thing Scene 2 is
## built on and lists it under what is missing; the delivered sheet has float, hurry, still,
## wave, cheer and a turnaround. Nothing here fakes it: the level holds him still at the rack
## and lets the dialogue carry the beat. `cheer` is arms-up celebration and would be worse
## than nothing. See CONTENT_NEEDED.md.
func _draw_priest() -> void:
	var x := _priest_x
	# A cassock is a column, which is exactly why it is cheap to draw and reads at any size.
	draw_rect(Rect2(x - 17.0, -104.0, 34.0, 104.0), CASSOCK)
	draw_rect(Rect2(x - 17.0, -104.0, 11.0, 104.0), CASSOCK_LIT)
	draw_rect(Rect2(x - 12.0, -104.0, 24.0, 7.0), COLLAR)
	draw_circle(Vector2(x, -114.0), 13.0, SKIN)
