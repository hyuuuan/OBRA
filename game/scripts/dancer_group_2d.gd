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
## THE DANCERS ARE THE PAINTING'S OWN, CUT OUT. For a long time this class drew nothing:
## `mg_people.png` painted all four into the plaza, so a sprite on top would have put eight
## dancers where the picture has four, and the scare was mechanically complete and visually
## invisible. The authored 8-bit dancers existed and were nowhere near the painted ones, so
## using them meant trading four beautiful figures for an animation.
##
## `tools/build_dancers.py` settles it by lifting the dancers OUT of the plate -- two come
## away as whole connected components, the two in front of the palm legs are cleared and the
## poles grown back down through the holes -- and handing them back as `painted_dancer_a` and
## `painted_dancer_b`. So the plaza looks exactly as it did, and they can leave.

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

## The apo is 96 tall, so an adult is about 118 at seventy-two pixels to the metre. Used for
## the notice volume only: the SPRITES are the painting's own scale, which is taller again,
## and matching them to this ruler would shrink four figures the whole plaza is composed
## around.
const HEIGHT := 118.0
const WIDTH := 34.0

## WHERE THE PAINTING HAD THEM, as offsets from `DancersMark` (world x 720). The backdrop is
## placed so that world x IS plate x, so these come straight off the artist's own columns --
## 697, 857, 1022 and 1174 -- as CENTRES, since that is what a sprite is drawn about. The
## first version used the left edges and stood all four half a dancer to the west.
##
## Slots 1 and 2 are EXACT: their sprites were cut from plate columns 857 and 1022 and these
## offsets put them straight back. Slots 0 and 3 are the two that had to be cleared, measured
## off the fused component before it went.
const STANDS: Array[float] = [50.0, 213.0, 375.0, 530.0]
## Which cut goes where. Two poses alternating, and NOT MIRRORED: all four painted dancers
## hold the fan in the same hand and face the same way, so flipping the outer pair was both
## unfaithful to the picture and, as it turned out, broken -- see `_draw`.
const CUTS: Array[String] = [
	"painted_dancer_b", "painted_dancer_a", "painted_dancer_b", "painted_dancer_a"]
## How far each bobs, and how out of step with the next. A painted figure that is perfectly
## still reads as scenery; four moving in lockstep read as one sprite drawn four times.
const BOB := 3.0
const OFF_BEAT := 0.7
## Where they go. East, which is the way the player has not been yet -- running back past the
## apo would read as being chased rather than as leaving.
const FLEE_RUN := 520.0

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


## Four figures on the artist's own marks, breathing while they dance and gone when they go.
##
## ⚠ THE PAINTED CUTS, NOT THE AUTHORED 8-BIT ONES. `dancer_a` / `dancer_b` in the plaza sheet
## are the hand-authored pair and belong to the dance screen; `painted_dancer_a` / `_b` are
## the plate's own, and they are what the plaza is missing exactly where these stand. Swapping
## them would leave four blocky figures in a painting composed around four painted ones.
func _draw() -> void:
	if _state == State.GONE:
		return
	for index in range(mini(dancers, STANDS.size())):
		var cut := CUTS[index]
		var size := PiyestaTiles.size_of(cut)
		if size == Vector2.ZERO:
			continue
		var at := Vector2(STANDS[index], 0.0)
		var fade := 1.0
		if _state == State.FLEEING:
			# Away east, gathering pace, and lifting very slightly -- a run, not a slide.
			# Eased rather than linear so the first frames read as deciding to go.
			var t: float = ease(_flee, 2.4)
			at.x += t * FLEE_RUN * (1.0 + float(index) * 0.14)
			at.y -= sin(_flee * PI) * 6.0
			fade = 1.0 - clampf((_flee - 0.55) / 0.45, 0.0, 1.0)
		else:
			at.y -= absf(sin(_phase * 2.1 + float(index) * OFF_BEAT)) * BOB
		# Drawn from the FEET, because the ground line is the one thing in this plaza that
		# every other measurement is taken from.
		var box := Rect2(at.x - size.x * 0.5, at.y - size.y, size.x, size.y)
		var texture := PiyestaTiles.get_tile(cut)
		if texture == null:
			continue
		# ⚠ NO NEGATIVE RECTS, IN EITHER ARGUMENT. Two dancers were mirrored here for a while.
		# A region rect of negative width draws NOTHING AT ALL, and every headless suite stayed
		# green, because a sprite that fails to draw is not an error -- the same fault that hid
		# five birds and a whole dancer class before. Flipping the destination instead does not
		# fail loudly either: Godot normalises the rect, so the sprite came back unmirrored and
		# shifted its own width to the east. If a flip is ever wanted here, write the flipped
		# PNG in `build_dancers.py` and load it by name.
		draw_texture_rect_region(texture, box, Rect2(Vector2.ZERO, size),
			Color(1.0, 1.0, 1.0, fade))
