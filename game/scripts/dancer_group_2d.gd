class_name DancerGroup2D
extends Node2D
## The dancers in the plaza, and the one thing in Piyesta the player can destroy.
##
## THE PLAZA IS LOLO'S MEMORY. The design says it plainly, and it is the reason Problem 1's
## Protector route costs anything at all: *"the dancers are gone from the plaza permanently
## once scared. They do not return... the plaza is lolo's memory, and the player has just
## emptied it."* Nothing is blocked by their going. The level does not get harder. What
## happens is that a man who has been dead for the whole game watches the thing he brought
## you here to see walk off, and says so.
##
## SO SCATTERING IS ONE-WAY AND IS SAID OUT LOUD BEFORE IT HAPPENS. The design asks for the
## irreversibility to be signalled before the player commits, and `L2_N1.protector.warn` is
## the line: *"Apo. If you do this they will not come back. Not today, not for us."* It fires
## from this group's own approach volume rather than from the choice screen, so it arrives
## while the player is looking at the dancers and can still walk away.
##
## ⚠ THE DANCE ITSELF IS NOT PLAYABLE YET. `dance_minigame.gd` is the scoring model -- cues,
## windows, two attempts, what clears -- and there is no screen that puts a cue on the player
## and times their stroke. Until there is, the Artist route hands over the kandila without a
## performance and the flower cannot be earned. That is a gap, not a design, and it is
## recorded in LEVEL_2.md and CONTENT_NEEDED.md rather than papered over with a dance that
## always succeeds.
##
## THE ART ALREADY HAS THEM. `mg_people.png` paints all four into the plaza, so this class
## draws nothing -- see `_draw`. What the design still owes it is a costume sheet with a flee
## and a hand-over-candle, and the no-dancers variant of the plate.

## The player has come close enough to be told what scaring them would cost.
signal noticed(text: String)
signal notice_left()
## They have finished leaving. Nothing waits on this; it is what the quiet line hangs off.
signal scattered()

enum State { DANCING, FLEEING, GONE }

## How many are dancing. Four reads as a set rather than as a crowd or a couple.
@export var dancers := 4
## How far apart they stand. A little over a metre, which is dancing distance.
@export var spacing := 84.0
## How far out the warning carries. Wide, because it has to arrive while the player can
## still turn round -- the dialogue node that offers the choice is only a little nearer.
@export var notice_range := 300.0

## The apo is 96 tall, so an adult is about 118 at seventy-two pixels to the metre.
const HEIGHT := 118.0
const WIDTH := 34.0

## Fiesta dress: saya and barong in festival colours, one per dancer so the group reads as
## several people rather than as a repeated sprite.
const COSTUMES: Array[Color] = [
	Color(0.902, 0.376, 0.353, 1.0),   # E6605A
	Color(0.361, 0.596, 0.780, 1.0),   # 5C98C7
	Color(0.937, 0.729, 0.294, 1.0),   # EFBA4B
	Color(0.478, 0.694, 0.435, 1.0),   # 7AB16F
	Color(0.741, 0.478, 0.769, 1.0),   # BD7AC4
]
const COSTUME_DARK := Color(0.0, 0.0, 0.0, 0.22)
const SKIN := Color(0.769, 0.612, 0.478, 1.0)         # C49C7A
const HAIR := Color(0.161, 0.129, 0.114, 1.0)         # 29211D
## What they are dancing over. A shadow is what stands a figure on the ground.
const SHADOW := Color(0.0, 0.0, 0.0, 0.16)

var _state: int = State.DANCING
var _phase := 0.0
## How far through leaving they are, 0 to 1. They run off the way the player did not come.
var _flee := 0.0
var _area: Area2D
var _told := false


func _ready() -> void:
	add_to_group(&"dancer_groups")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_notice()
	set_process(true)


func _process(delta: float) -> void:
	if _state == State.GONE:
		return
	_phase += delta
	if _state == State.FLEEING:
		# Still on a clock, even with nothing drawn: `scattered` is what Lolo's quiet line
		# waits for, and firing it on the same frame as the choice would put it over the top
		# of the commit line.
		_flee = minf(1.0, _flee + delta * 0.55)
		if _flee >= 1.0:
			_state = State.GONE
			set_process(false)
			scattered.emit()
	queue_redraw()


func _build_notice() -> void:
	_area = Area2D.new()
	_area.name = "Notice"
	_area.position = Vector2(0.0, -HEIGHT * 0.5)
	add_child(_area)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(notice_range * 2.0, HEIGHT * 2.0)
	shape.shape = box
	_area.add_child(shape)
	_area.body_entered.connect(_on_body.bind(true))
	_area.body_exited.connect(_on_body.bind(false))


func _on_body(body: Node, coming_in: bool) -> void:
	if _state != State.DANCING or not body.is_in_group(&"player_character"):
		return
	if coming_in:
		# ONCE. A warning that repeats every time the player walks past becomes something
		# they read around rather than something they weigh.
		if _told:
			return
		_told = true
		noticed.emit("")
		return
	notice_left.emit()


func state() -> int:
	return _state


func are_gone() -> bool:
	return _state == State.GONE


## Problem 1's Protector route. ONE WAY: there is no unscatter, deliberately, because the
## whole weight of the choice is that it cannot be taken back.
func scatter() -> bool:
	if _state != State.DANCING:
		return false
	_state = State.FLEEING
	return true


## Restored from a checkpoint written after they had already gone. Skips the running-away,
## because replaying it would make the level look like it was happening again.
func set_already_gone() -> void:
	_state = State.GONE
	_flee = 1.0
	set_process(false)
	if _area != null:
		_area.set_deferred("monitoring", false)
	queue_redraw()


## ⚠ THEY DRAW AGAIN, AND THE SCARE FINALLY SHOWS.
##
## For two passes this drew nothing, because the dancers were painted into `mg_people` and the
## composite would not give them up -- a bounding-box cut took the palm trunks standing behind
## two of them, and a colour mask keyed on the white saya left the hats, hands, fans and shoes
## behind. So Problem 1's Protector route was mechanically complete and visually invisible:
## the flag was set, the route closed, and nothing on screen changed.
##
## Authoring the plaza dissolved that. The dancers are sprites now
## (`tools/build_plaza_art.py`), so they can simply leave -- which is what the design asked for
## all along and what the "MG_People no-dancers variant" was only ever a way to fake.
##
## Sinulog, not Pahiyas: red and gold, and a candle in the raised hand. It is a candle dance
## before it is anything else.
func _draw() -> void:
	if _state == State.GONE:
		return
	for index in range(dancers):
		var home := (float(index) - float(dancers - 1) * 0.5) * spacing
		# They run west, away from the church, spreading as they go -- a group that leaves in
		# a line is a group marching.
		var away := _flee * (560.0 + float(index) * 90.0)
		var fade := 1.0 - _flee * 0.85
		var tint := Color(1.0, 1.0, 1.0, fade)
		if _state == State.FLEEING:
			# The stride, so they are running rather than sliding.
			var bob := absf(sin(_phase * 9.0 + float(index) * 1.3)) * 5.0
			PiyestaTiles.stand(self, "dancer_flee",
				Vector2(home - away, -bob), 1.0, tint)
			continue
		# On the beat: the two frames alternate, and neighbours are out of phase so four of
		# them read as a group dancing rather than as one dancer copied four times.
		var beat := sin(_phase * 2.2 + float(index) * 1.05)
		var lift := absf(beat) * 5.0
		PiyestaTiles.stand(self, "dancer_a" if beat > 0.0 else "dancer_b",
			Vector2(home, -lift), 1.0, tint)
