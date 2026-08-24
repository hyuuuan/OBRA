class_name Lolo
extends Node2D
## The tutorial companion: he floats along beside whoever the player currently is and
## says the one thing that is worth saying where they are standing.
##
## His LOOK is a placeholder (see lolo_figure.gd). What is not placeholder is this
## interface -- follow(), say(), is_speaking() -- because TutorialDirector talks to it
## and a designed Lolo has to answer the same three calls.
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

@onready var _figure: Node2D = $Figure

## Where his HINTS are shown. Screen space, owned by the level, handed to him at spawn.
## He no longer carries a bubble, and he no longer owns the story channel either: a beat
## goes to the framed box through GameLevel, because it is a conversation with a queue and
## a key to advance it, and none of that belongs to a companion who floats.
var _hints: HintBar

var _target: Node2D
var _phase: float = 0.0
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
	_figure.set("bob", _phase)
	_figure.set("facing", _facing)
	_figure.queue_redraw()

	# The box counts its own line down -- it is the thing that knows whether the text has
	# even finished arriving yet. What is kept here is the mouth: he stops talking when
	# the line is no longer up, however it went away.
	if _speech_time > 0.0:
		_speech_time -= delta
		if _speech_time <= 0.0:
			_speech_time = 0.0
			_figure.set("talking", false)

	if _target == null or not is_instance_valid(_target):
		return
	var desired := _desired_position()
	if global_position.distance_to(desired) > teleport_distance:
		global_position = desired
	else:
		global_position = global_position.lerp(desired, clampf(follow_speed * delta, 0.0, 1.0))
	var to_target := _target_position().x - global_position.x
	if absf(to_target) > 24.0:
		_facing = signf(to_target)


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
