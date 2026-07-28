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

## How far behind and above the player he settles.
@export var follow_offset := Vector2(-92.0, -74.0)
## Higher is snappier. He is slower than the camera so he trails rather than sticks.
@export var follow_speed: float = 3.4
## He gives up chasing past this and simply appears -- after a morph across the level,
## a companion drifting through the scenery for ten seconds looks broken.
@export var teleport_distance: float = 900.0
@export var bob_hz: float = 0.55

@onready var _figure: Node2D = $Figure
@onready var _bubble: Control = $Bubble
@onready var _bubble_label: Label = $Bubble/Panel/Text

var _target: Node2D
var _phase: float = 0.0
var _speech_time: float = 0.0
var _facing: float = 1.0


func _ready() -> void:
	add_to_group(&"companion")
	_bubble.visible = false
	_bubble.modulate.a = 0.0


func follow(target: Node2D) -> void:
	_target = target
	if target != null and is_instance_valid(target):
		global_position = _desired_position()


## Show a line until something replaces it. `seconds` of 0 means "until told
## otherwise", which is what a hint about the obstacle in front of you wants to be.
func say(text: String, seconds: float = 0.0) -> void:
	if text.is_empty():
		hush()
		return
	_bubble_label.text = text
	_speech_time = seconds
	if not _bubble.visible:
		_bubble.visible = true
		var appear := create_tween()
		appear.tween_property(_bubble, "modulate:a", 1.0, 0.18)
	_figure.set("talking", true)


func hush() -> void:
	_speech_time = 0.0
	_figure.set("talking", false)
	if not _bubble.visible:
		return
	var fade := create_tween()
	fade.tween_property(_bubble, "modulate:a", 0.0, 0.18)
	fade.tween_callback(func() -> void: _bubble.visible = false)


func is_speaking() -> bool:
	return _bubble.visible


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * bob_hz, 1.0)
	_figure.set("bob", _phase)
	_figure.set("facing", _facing)
	_figure.queue_redraw()

	if _speech_time > 0.0:
		_speech_time -= delta
		if _speech_time <= 0.0:
			hush()

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
	# The bubble hangs above him in world space but must not flip with him, or the
	# text would read backwards every time the player turned around.
	_bubble.scale = Vector2.ONE


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
