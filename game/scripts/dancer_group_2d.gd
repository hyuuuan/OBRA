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
## THE DANCE IS VISIBLE BEFORE IT IS PLAYABLE. The three supplied troupe plates are authored
## animation frames, not references: the world cycles 1 -> 2 -> 3 -> 2, and committing the
## Artist route restarts that phrase and lets it play in the plaza before the timing overlay
## opens. The popup is therefore an invitation to join a dance the player has just watched,
## not a rhythm exercise that replaces the dancers with a panel.

## The player has come close enough to be told what scaring them would cost.
signal noticed(text: String)
signal notice_left()
## They have finished leaving. Nothing waits on this; it is what the quiet line hangs off.
signal scattered()
## The complete in-world phrase has played and the timing puzzle may take over.
signal puzzle_lead_in_finished()

enum State { DANCING, FLEEING, GONE }

## How many are dancing. Four reads as a set rather than as a crowd or a couple.
@export var dancers := 4
## How far out the warning carries. Wide, because it has to arrive while the player can
## still turn round -- the dialogue node that offers the choice is only a little nearer.
@export var notice_range := 300.0

## The apo is 96 tall, so an adult is about 118 at seventy-two pixels to the metre. This is
## the notice volume's height; the authored plates keep their own visual scale below.
const HEIGHT := 118.0

## The user's three complete troupe frames. They share a 2172 x 724 transparent canvas, so
## one destination rect keeps feet, spacing and scale stable while the pose changes.
const DANCE_FRAME_PATHS: Array[String] = [
	"res://assets/Level2/dancers/dance_frame_01.png",
	"res://assets/Level2/dancers/dance_frame_02.png",
	"res://assets/Level2/dancers/dance_frame_03.png",
]
const DANCE_FRAMES: Array[Texture2D] = [
	preload("res://assets/Level2/dancers/dance_frame_01.png"),
	preload("res://assets/Level2/dancers/dance_frame_02.png"),
	preload("res://assets/Level2/dancers/dance_frame_03.png"),
]
## Returning through frame 2 avoids a hard 3 -> 1 snap at the loop seam.
const FRAME_SEQUENCE: Array[int] = [0, 1, 2, 1]
const FRAME_SECONDS := 0.24
## Long enough to see two full four-pose phrases after choosing to dance.
const PUZZLE_LEAD_IN := 2.4
## From `DancersMark`: full source canvas fitted to the plaza, feet on y = 0. The negative x
## accounts for the transparent source margin and restores the leftmost dancer to the old
## troupe's first stand.
const FRAME_RECT := Rect2(-50.0, -211.5, 660.0, 220.0)
## Where they go. East, which is the way the player has not been yet -- running back past the
## apo would read as being chased rather than as leaving.
const FLEE_RUN := 520.0

var _state: int = State.DANCING
var _phase := 0.0
## How far through leaving they are, 0 to 1. They run off the way the player did not come.
var _flee := 0.0
var _area: Area2D
var _told := false
var _puzzle_lead_in := 0.0


func _ready() -> void:
	add_to_group(&"dancer_groups")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_notice()
	set_process(true)


func _process(delta: float) -> void:
	if _state == State.GONE:
		return
	_phase += delta
	if _puzzle_lead_in > 0.0:
		_puzzle_lead_in = maxf(0.0, _puzzle_lead_in - delta)
		if _puzzle_lead_in <= 0.0:
			puzzle_lead_in_finished.emit()
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


## Restart the authored phrase when the player chooses to join it. The level awaits the
## signal rather than an unrelated timer, so a paused world cannot silently spend the dance.
func begin_puzzle_lead_in() -> void:
	_phase = 0.0
	_puzzle_lead_in = PUZZLE_LEAD_IN
	queue_redraw()


func puzzle_lead_in_active() -> bool:
	return _puzzle_lead_in > 0.0


func animation_frame() -> int:
	return frame_index_at(_phase)


static func frame_index_at(seconds: float) -> int:
	var step := int(floor(maxf(0.0, seconds) / FRAME_SECONDS)) % FRAME_SEQUENCE.size()
	return FRAME_SEQUENCE[step]


static func frame_texture_at(seconds: float) -> Texture2D:
	return DANCE_FRAMES[frame_index_at(seconds)]


## Problem 1's Protector route. ONE WAY: there is no unscatter, deliberately, because the
## whole weight of the choice is that it cannot be taken back.
func scatter() -> bool:
	if _state != State.DANCING:
		return false
	_puzzle_lead_in = 0.0
	_state = State.FLEEING
	return true


## Restored from a checkpoint written after they had already gone. Skips the running-away,
## because replaying it would make the level look like it was happening again.
func set_already_gone() -> void:
	_state = State.GONE
	_flee = 1.0
	_puzzle_lead_in = 0.0
	set_process(false)
	if _area != null:
		_area.set_deferred("monitoring", false)
	queue_redraw()


## One complete four-dancer plate per frame. The plate moves as one during the irreversible
## scare route; changing art sets halfway through their exit would look like a replacement,
## not the same people leaving.
func _draw() -> void:
	if _state == State.GONE:
		return
	var texture := frame_texture_at(_phase)
	if texture == null:
		return
	var box := FRAME_RECT
	var fade := 1.0
	if _state == State.FLEEING:
		# Away east, gathering pace, and lifting very slightly -- a run, not a slide.
		# Eased rather than linear so the first frames read as deciding to go.
		var t: float = ease(_flee, 2.4)
		box.position.x += t * FLEE_RUN
		box.position.y -= sin(_flee * PI) * 6.0
		fade = 1.0 - clampf((_flee - 0.55) / 0.45, 0.0, 1.0)
	draw_texture_rect_region(texture, box, Rect2(Vector2.ZERO, texture.get_size()),
		Color(1.0, 1.0, 1.0, fade))
