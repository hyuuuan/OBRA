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
## How far behind his station he has to fall before the drift becomes a chase, in pixels.
##
## ⚠ THIS WAS A SPEED, AND A SPEED CANNOT ANSWER IT. He lerps toward a point behind the
## player's shoulder, so once he has settled HIS SPEED IS THEIR SPEED -- 260, the apo's own
## run -- no matter what he is doing. Measured against the old 180px/s threshold: over 240
## frames of a full run he was in the chase for 225 of them and in the drift for 13, so the
## hover the sheet was drawn for never actually played.
##
## What separates keeping pace from catching up is not how fast he is going, it is HOW FAR
## BEHIND HE IS. The lag settles around 76px at a full run, so 130 leaves him drifting while
## he keeps up and breaks into the run only when something has really opened a gap -- a jump,
## a morph, an obstacle he has to go round.
@export var catch_up_distance: float = 130.0
## Below this he is holding station rather than travelling, and shows the idle rather than
## the drift. The three poses are stopped, drifting and chasing, in that order.
@export var drift_threshold: float = 26.0

## How long the turn-to-camera is held for a line the caller gave no length. Read the note
## on `say`: without this he turns on the level's first frame and never turns back.
const GESTURE_PER_CHAR := 0.05
const GESTURE_MIN := 2.4
const GESTURE_MAX := 7.0

## PRELOADED FOR THE STATIC, duck-typed for everything else. lolo_figure.gd declares no
## class_name -- this file reaches the body through set/get/call on purpose -- so the one
## thing that has to be asked of the SCRIPT rather than of the node needs the script.
const Figure = preload("res://scripts/lolo_figure.gd")

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
var _pose_time: float = 0.0
var _current_pose: StringName = &""
var _cheer_time: float = 0.0
var _turn_back_time: float = 0.0
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
	# ⚠ THE GESTURE HAS A LENGTH EVEN WHEN THE LINE DOES NOT, and this is the whole of why
	# he never animated. `seconds = 0` means "stand on the bar until something replaces it",
	# which is a rule about THE BAR -- and the greeting fired the moment he spawns is exactly
	# that call. `_speech_time` was therefore 0 from the first frame of Level 1, the countdown
	# below never ran, and `talking` was a latch only `hush()` could unset. He held `face`
	# -- cell 0 of the turnaround, head-on -- for the entire level: the drift and the chase,
	# six cells each, never played once in a whole playthrough.
	#
	# So the WORDS keep the bar's rule and the TURN keeps its own. He faces you for as long
	# as the line takes to read, then goes back to floating beside you with it still up.
	_speech_time = seconds if seconds > 0.0 else _gesture_length(text)
	_figure.set("talking", true)


## How long he holds the turn for a line that carries no length of its own. The same shape
## the hint bar uses to decide how long one line of a beat dwells, for the same reason: a
## sentence takes as long to read as it is long.
func _gesture_length(text: String) -> float:
	return clampf(float(text.length()) * GESTURE_PER_CHAR, GESTURE_MIN, GESTURE_MAX)


## Handed the hint bar to speak through. Without one he simply says nothing, which keeps
## every headless fixture that spawns a bare Lolo working.
func set_hint_bar(bar: HintBar) -> void:
	_hints = bar


func hush() -> void:
	var was_talking := _speech_time != 0.0 or bool(_figure.get("talking"))
	_speech_time = 0.0
	_figure.set("talking", false)
	if was_talking:
		_begin_turn_back()
	if _hints != null:
		_hints.clear()


func is_speaking() -> bool:
	return _hints != null and _hints.is_showing()


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * bob_hz, 1.0)
	_pose_time += delta
	if _cheer_time > 0.0:
		_cheer_time = maxf(0.0, _cheer_time - delta)
	if _turn_back_time > 0.0:
		_turn_back_time = maxf(0.0, _turn_back_time - delta)

	# The box counts its own line down -- it is the thing that knows whether the text has
	# even finished arriving yet. What is kept here is the mouth: he stops talking when
	# the line is no longer up, however it went away.
	if _speech_time > 0.0:
		_speech_time -= delta
		if _speech_time <= 0.0:
			_speech_time = 0.0
			_figure.set("talking", false)
			_begin_turn_back()

	var was := global_position
	# How far he is from where he wants to be, AFTER moving. Zero for a level with no
	# player in it, which is every fixture that spawns him on his own.
	var behind := 0.0
	if _target != null and is_instance_valid(_target):
		var desired := _desired_position()
		if global_position.distance_to(desired) > teleport_distance:
			global_position = desired
		else:
			global_position = global_position.lerp(
				desired, clampf(follow_speed * delta, 0.0, 1.0))
		behind = global_position.distance_to(_desired_position())
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
	var hurrying := behind > catch_up_distance
	# Whole cycles either way, and the ground he covers drives both of them -- a drift
	# played at a fixed rate while he travels at a run is a ghost sliding. `drift_hz` is
	# the FLOOR rather than the rate now: it is what the cycle falls back to when he is
	# barely moving, which is the one case where there is no ground to take a rate from.
	_stride = fmod(_stride + delta
		* maxf(drift_hz, speed / (90.0 if hurrying else 150.0)), 1.0)
	var wanted := _pose_for(speed, hurrying)
	# RESET ON CHANGE, not every frame: a one-shot reads pose_time from zero, so leaving it
	# running would have him arrive mid-turn, and restarting it every frame would freeze him
	# on the first cell -- which is exactly what the old held `face` looked like.
	if wanted != _current_pose:
		_current_pose = wanted
		_pose_time = 0.0
	_figure.set("pose", wanted)
	_figure.set("pose_time", _pose_time)
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
	# A SOLVE OUTRANKS EVERYTHING, briefly. It is the only moment he reacts to the player
	# rather than to the level, and it is over in well under a second.
	if _cheer_time > 0.0:
		return &"cheer"
	# HE TURNS TO YOU TO SPEAK, and the turn is the animation -- five frames that had never
	# been drawn before. `face` plays through and holds him head-on for the rest of the
	# line, which is what makes a line of Lola's story feel addressed to the apo instead of
	# narrated past them.
	# THE CLOCK, NOT THE FLAG. `talking` is the figure's own business -- it breathes wider
	# while a line of his is up -- and the two are set and cleared together, so asking both
	# said nothing extra. What it DID do was survive the clock: a `talking` that had been
	# latched true outranked a `_speech_time` of zero, which is the state the greeting left
	# him in for the whole level.
	# ⚠ AND MOVING TAKES IT BACK WHEN HE IS ACTUALLY HAVING TO MOVE.
	#
	# `face` is a STANDING pose -- he turns head-on to the player and holds it for the rest
	# of the line -- and it used to outrank the chase unconditionally. That is right at the
	# player's shoulder, which is where it was written and looked at. It is wrong the moment
	# he is half a screen behind, because his gesture clock runs 2.4 to 7 seconds past the
	# end of a line: a player who walks off mid-sentence watches him cross five hundred
	# pixels of terrace facing them, perfectly still, like a cutout being dragged.
	#
	# MEASURED, over ten seconds of running east out of the spawn: he fell 556px behind
	# against a `catch_up_distance` of 130, and `hurry` played for 36 frames out of 600.
	# A third of that run he was drawn standing.
	#
	# So the chase wins over the gesture, and the gesture keeps everything else: he still
	# turns to speak whenever he is drifting or parked, which is every line the player
	# stands still for and is the case the pose was drawn for.
	if hurrying:
		return &"hurry"
	if _speech_time > 0.0:
		return &"face"
	# And back again when he is done, rather than snapping to the drift on the frame the
	# line clears.
	if _turn_back_time > 0.0:
		return &"turn_back"
	# The drift is for actually covering ground. Parked at the player's shoulder he is
	# STILL -- which is not motionless, because the idle frame still rides the bob.
	return &"float" if speed > drift_threshold else &"still"


## Turn back to the drift over the length of the turnaround itself, so the two halves of
## the gesture are the same length and it reads as one movement rather than a turn out and
## a cut back.
func _begin_turn_back() -> void:
	_turn_back_time = Figure.pose_duration(&"turn_back")


## He is pleased with you. Called when a beat is answered -- the one time in the level the
## companion has something to say about the player rather than about the place.
func cheer(seconds: float = 0.9) -> void:
	_cheer_time = maxf(_cheer_time, seconds)


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
