class_name ChurchInterior2D
extends Node2D
## What is inside the church, and the one thing in it the player may touch.
##
## SCENE 2 IS THE ONLY PLACE IN THIS LEVEL WHERE THE PACE DROPS. The design says so in as
## many words -- *"this is a checkpoint, and the only place in the level where the pace
## drops. Let it breathe before the alley sequence."* Nothing here is a puzzle. The kandila
## goes on the rack, a priest walks over and says where Lola went, and the far door opens.
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
## The supplied church plates are packed by tools/build_church.py. The room draws the
## architecture and sacred images; this node owns only the live rack and priest.

## The kandila is on the rack. Scene 2's first beat, and the only one the player performs.
signal kandila_placed()
## Standing at the rack, or stepped away from it.
signal at_rack(standing: bool)
## The priest has finished walking over and is ready to speak.
signal priest_arrived()

## Where the nave ends, measured from this node. Set by the level off the room's own length
## so the furniture cannot outgrow the room it is in.
@export var nave_length := 1800.0
@export var nave_height := 720.0
## Whether the candle is already on the rack. Rides the level's run state, so a restore
## inside the church does not ask for it twice.
@export var kandila_on_rack := false

const ART = preload("res://scripts/church_art.gd")
const RACK_REACH := Vector2(170.0, 190.0)
const FLAME_SOFT := Color(0.988, 0.812, 0.451, 0.16)
## The supplied elderly priest sheet: front while waiting, six walking frames, and the
## left-facing turnaround while speaking. tools/build_priest.py packs the cutouts into
## matching cells with one foot baseline. He walks over once the candle is lit.
const PRIEST_WAITING := preload("res://assets/characters/priest/priest_idle.png")
const PRIEST_WALK := preload("res://assets/characters/priest/priest_walk.png")
const PRIEST_TALKING := preload("res://assets/characters/priest/priest_side.png")
## Fit to the world once at build time; keep runtime pixels at their native size.
const PRIEST_SCALE := 1.0
## Shared animation cell and the row his feet stand on in it.
const PRIEST_CELL := Vector2(80.0, 124.0)
const PRIEST_FOOT_ROW := 123.0
## A walk: 1.4 metres a second at the church's seventy-two pixels to the metre.
const PRIEST_SPEED := 100.0
## One full cycle of the six walk frames, in pixels walked, so his feet keep pace with the floor.
const PRIEST_STRIDE := 84.0
## Where he stops: near enough to be talking TO the apo, not standing in them.
const PRIEST_STAND_OFF := 88.0

var _rack_area: Area2D
var _standing := false
var _flicker := 0.0
var _priest: Sprite2D
var _priest_x := 0.0
## Where the person he is walking over to is, asked every frame while he walks. He goes to the
## PERSON, not to a spot by the rack: the apo may have stepped away, and a man who walks up to
## where you WERE is a quest marker. A Callable rather than a node, because drawing a creature
## in here replaces the body he would have been walking toward.
var _priest_toward := Callable()
var _priest_walked := 0.0
var _priest_here := false


func _ready() -> void:
	add_to_group(&"church_interiors")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_rack_reach()
	_priest_x = _priest_waiting_x()
	_build_the_priest()
	_check_the_guardrail()
	set_process(true)


func _process(delta: float) -> void:
	_flicker += delta
	_walk_the_priest(delta)
	queue_redraw()


# --- The one thing in here that answers ------------------------------------------------

## Left of the altar and against the wall, which is where Lolo says she always went.
func rack_point() -> Vector2:
	return global_position + Vector2(ART.RACK_FOOT.x, 0.0)


func rack_marker_point() -> Vector2:
	return global_position + ART.RACK_FOOT - Vector2(0.0, ART.RACK.get_height() + 24.0)


func _priest_waiting_x() -> float:
	return ART.PRIEST_X


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


## Send the priest over to whoever `toward` says is there (a global position). He waits by the
## altar until there is a reason to come across -- a man who walks up to you the moment you
## enter a church is a quest marker.
func send_the_priest(toward: Callable) -> void:
	if _priest_toward.is_valid() or _priest_here or not toward.is_valid():
		return
	_priest_toward = toward


## Whether he has walked over, and so has said -- or is saying -- where she went.
func priest_has_arrived() -> bool:
	return _priest_here


func priest_point() -> Vector2:
	return global_position + Vector2(_priest_x, 0.0)


## What the camera looks at while he talks.
func priest_figure() -> Node2D:
	return _priest


func _build_the_priest() -> void:
	_priest = Sprite2D.new()
	_priest.name = "Priest"
	_priest.texture = PRIEST_WAITING
	_priest.centered = false
	_priest.offset = Vector2(-PRIEST_CELL.x * 0.5, -PRIEST_FOOT_ROW)
	_priest.scale = Vector2.ONE * PRIEST_SCALE
	_priest.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_priest.position = Vector2(_priest_x, 0.0)
	add_child(_priest)


## ⚠ HE WALKS, HE DOES NOT SLIDE. The old one eased a rectangle across the nave over a fixed
## 2.2 seconds to a fixed spot by the rack, wherever the apo was standing. He goes to where the
## apo IS now, at a walking pace, with his feet in step with the floor, and stops on his own
## side of them -- coming from the altar, that is the far side -- and never outside the nave.
func _walk_the_priest(delta: float) -> void:
	if not _priest_toward.is_valid() or _priest_here:
		return
	var where: Variant = _priest_toward.call()
	if not (where is Vector2) or not (where as Vector2).is_finite():
		return
	var them := to_local(where as Vector2).x
	var side := 1.0 if _priest_x >= them else -1.0
	var inside := nave_length * 0.5 - 60.0
	var goal := clampf(them + side * PRIEST_STAND_OFF, -inside, inside)
	var gap := goal - _priest_x
	if absf(gap) <= 1.0:
		# Only an arrival if that is actually beside them: a player who walked out of the
		# church leaves him waiting at the end of the nave, not talking to an empty room.
		if absf(them - _priest_x) <= PRIEST_STAND_OFF + 24.0:
			_arrive(side)
		return
	var step := minf(absf(gap), PRIEST_SPEED * delta)
	_priest_x += signf(gap) * step
	_priest_walked += step
	_priest.position.x = _priest_x
	if _priest.texture != PRIEST_WALK:
		_priest.texture = PRIEST_WALK
		_priest.hframes = 6
	_priest.frame = int(_priest_walked / (PRIEST_STRIDE / 6.0)) % 6
	# The walk is drawn facing right; mirrored about his own axis to go left.
	_priest.scale.x = PRIEST_SCALE * (1.0 if gap > 0.0 else -1.0)


func _arrive(side: float) -> void:
	_priest_here = true
	_priest.frame = 0
	_priest.hframes = 1
	_priest.texture = PRIEST_TALKING
	# The side-on cell faces LEFT as drawn, which is toward the apo when he stops on its right.
	_priest.scale.x = PRIEST_SCALE * (1.0 if side > 0.0 else -1.0)
	priest_arrived.emit()


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

## The altar and pews are already in the room plate. Only the rack changes when E is pressed.
func _draw() -> void:
	draw_texture(ART.RACK, ART.RACK_FOOT - Vector2(ART.RACK.get_width() * 0.5,
		ART.RACK.get_height()))
	if not kandila_on_rack:
		return
	draw_texture(ART.CANDLE, ART.CANDLE_FOOT - Vector2(ART.CANDLE.get_width() * 0.5,
		ART.CANDLE.get_height()))
	var glow := 0.85 + 0.15 * sin(_flicker * 3.0)
	draw_circle(ART.CANDLE_FOOT - Vector2(0.0, ART.CANDLE.get_height() - 10.0), 28.0,
		Color(FLAME_SOFT, FLAME_SOFT.a * glow))
