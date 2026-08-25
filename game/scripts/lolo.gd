class_name Lolo
extends Node2D
## The tutorial companion: he floats along beside whoever the player currently is and
## says the one thing that is worth saying where they are standing.
##
## HE HANGS BEHIND WHAT THE PLAYER DRAWS. `lolo.tscn` puts him at z 7, and the number is
## load-bearing: the drawn ink renders at 10 (RuntimeRig2D.INK_Z_INDEX) and so does the apo,
## so at the 12 he used to be at he floated over every ladder, plank and creature the player
## had put down -- hovering at their shoulder is exactly the height a drawing tends to be,
## so he was in front of the thing they had just made about half the time they made one.
##
## Seven keeps him clear of the terrain he must never sink into: the terraces are 0, the
## stair is 3, the felled tree and the crumbling ledges are 6. It puts him under the hidden
## flower at 8, which is correct -- a secret should not be behind a companion either.
##
## His LOOK lives in lolo_figure.gd, which draws the delivered ghost art. What this file
## owns is the same three calls it always did -- follow(), say(), is_speaking() -- because
## TutorialDirector talks to them and none of them care what he looks like. What it also
## owns now, exactly as wanderer.gd does for the apo, is WHICH POSE he is in: the figure
## draws a pose, it does not decide one.
##
## He deliberately does not collide with anything. A companion who can be stood on, or
## who can wedge the player into a wall, is a hazard rather than a guide.

## What the box's plaque says when he is the one talking. The apo shares the same box for
## their own thoughts, so the name is how either of them is told apart -- by the player
## reading it, and by is_speaking() below.
const SPEAKER := "Lolo"

## How far behind and above the player he settles.
@export var follow_offset := Vector2(-92.0, -74.0)
## Higher is snappier. He is slower than the camera so he trails rather than sticks.
@export var follow_speed: float = 3.4
## He gives up chasing past this and simply appears -- after a morph across the level,
## a companion drifting through the scenery for ten seconds looks broken.
@export var teleport_distance: float = 900.0
@export var bob_hz: float = 0.55
## How fast his drift cycle runs when he is holding station, in cycles per second. Slower
## than a walk on purpose -- it is a hover, and six frames a second on a ghost reads as
## paddling.
@export var drift_hz: float = 0.9
## How fast he has to be moving before the drift becomes a hurry, in pixels per second.
## Above this he is visibly chasing the player rather than keeping pace with them.
@export var hurry_speed: float = 180.0
## Below this he is holding station rather than travelling, and shows the idle rather than
## the drift. Well under hurry_speed: the three poses are stopped, drifting and chasing.
@export var drift_threshold: float = 26.0

@onready var _figure: Node2D = $Figure

## Where his HINTS are shown. Screen space, owned by the level, handed to him at spawn.
## He no longer carries a bubble, and he no longer owns the story channel either: a beat
## goes to the framed box through GameLevel, because it is a conversation with a queue and
## a key to advance it, and none of that belongs to a companion who floats.
var _hints: HintBar

var _target: Node2D
var _phase: float = 0.0
var _stride: float = 0.0
var _speech_time: float = 0.0
var _facing: float = 1.0


func _ready() -> void:
	add_to_group(&"companion")


func follow(target: Node2D) -> void:
	_target = target
	if target != null and is_instance_valid(target):
		global_position = _desired_position()


## Show a line until something replaces it. `seconds` of 0 means "until told
## otherwise", which is what a hint about the obstacle in front of you wants to be.
##
## THE SIGNATURE IS THE CONTRACT. TutorialDirector, LevelDirector and game_level all call
## say/hush/is_speaking and none of them should have to know that the line is now drawn in
## a framed box at the bottom of the screen rather than in a bubble over his head.
func say(text: String, seconds: float = 0.0) -> void:
	if text.is_empty():
		hush()
		return
	if _hints != null:
		_hints.show_hint(text, SPEAKER, seconds)
	_speech_time = seconds
	_figure.set("talking", true)


## Handed the hint bar to speak through. Without one he simply says nothing, which keeps
## every headless fixture that spawns a bare Lolo working.
func set_hint_bar(bar: HintBar) -> void:
	_hints = bar


func hush() -> void:
	_speech_time = 0.0
	_figure.set("talking", false)
	if _hints != null:
		_hints.clear()


func is_speaking() -> bool:
	return _hints != null and _hints.is_showing()


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * bob_hz, 1.0)

	# The box counts its own line down -- it is the thing that knows whether the text has
	# even finished arriving yet. What is kept here is the mouth: he stops talking when
	# the line is no longer up, however it went away.
	if _speech_time > 0.0:
		_speech_time -= delta
		if _speech_time <= 0.0:
			_speech_time = 0.0
			_figure.set("talking", false)

	var was := global_position
	if _target != null and is_instance_valid(_target):
		var desired := _desired_position()
		if global_position.distance_to(desired) > teleport_distance:
			global_position = desired
		else:
			global_position = global_position.lerp(
				desired, clampf(follow_speed * delta, 0.0, 1.0))
		var to_target := _target_position().x - global_position.x
		if absf(to_target) > 24.0:
			_facing = signf(to_target)

	# Measured off how far he actually moved rather than off the player's speed, because
	# the two are not the same thing: he lerps toward a point behind their shoulder, so he
	# is still hurrying for a moment after they have stopped, which is exactly when a
	# companion should still look like he is catching up.
	#
	# A TELEPORT IS NOT A SPRINT. Crossing the level in one frame after a morph would read
	# as an enormous speed and flip him to the hurry cycle for the frame he arrives on.
	var speed := 0.0 if delta <= 0.0 else was.distance_to(global_position) / delta
	if speed > teleport_distance:
		speed = 0.0
	var hurrying := speed > hurry_speed
	# Whole cycles either way. Holding station he drifts at his own rate; chasing, the
	# cycle is driven by the ground he is covering, so the pose and the motion agree.
	_stride = fmod(_stride + delta * (speed / 90.0 if hurrying else drift_hz), 1.0)
	_figure.set("pose", _pose_for(speed, hurrying))
	_figure.set("stride", _stride)
	_figure.set("bob", _phase)
	_figure.set("facing", _facing)
	_figure.call("refresh")


## Which of the ghost's drawings to show.
##
## HE HAD FOUR HE NEVER USED. The sheet came with an idle, a wave, a cheer and a head-on
## turnaround, and every one of them sat in the pose table unreferenced while he played the
## drift cycle through all of it -- holding station, catching up, and talking alike. What
## that reads as on screen is a companion whose animation has nothing to do with what he is
## doing, which is worse than a companion with one animation, because the game keeps
## implying he is about to do something and he never does.
##
## Talking wins over moving. A line of Lola's story is the only moment in this game where
## Lolo is the thing you are meant to be looking at, and a gesture is what says it is him
## saying it rather than the box.
func _pose_for(speed: float, hurrying: bool) -> StringName:
	if _speech_time != 0.0 or bool(_figure.get("talking")):
		return &"wave"
	if hurrying:
		return &"hurry"
	# The drift is for actually covering ground. Parked at the player's shoulder he is
	# STILL -- which is not motionless, because the idle frame still rides the bob.
	return &"float" if speed > drift_threshold else &"still"


func _desired_position() -> Vector2:
	return _target_position() + Vector2(follow_offset.x * _approach_side(), follow_offset.y)


## Which shoulder to sit on: he stays behind the player rather than in front, so he
## never floats between them and the obstacle they are being told to look at.
func _approach_side() -> float:
	var to_target := _target_position().x - global_position.x
	return 1.0 if to_target > 0.0 else -1.0


func _target_position() -> Vector2:
	if _target.has_method("get_physics_anchor"):
		var anchor := _target.call("get_physics_anchor") as Node2D
		if anchor != null:
			return anchor.global_position
	return _target.global_position
