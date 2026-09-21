class_name DepthLayer2D
extends Node2D
## Visual-only pseudo-depth layer. Gameplay stays 2D; this node offsets its
## children against the active camera so each plane can scroll at its own rate.

@export var depth: float = 0.0
@export var scroll_scale: float = 1.0
@export var visual_scale: float = 1.0
@export var base_position: Vector2 = Vector2.ZERO
@export var z_index_base: int = 0

var _camera_origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	z_index = z_index_base
	position = base_position
	scale = Vector2.ONE * visual_scale


func set_camera_origin(camera_position: Vector2) -> void:
	_camera_origin = camera_position
	update_for_camera(camera_position)


## ⚠ ONLY WHAT CHANGED, AND FOR THE GAMEPLAY PLANE THAT IS NOTHING. Node2D.set_position does
## not skip an equal value: it re-sends the transform to every child, and a RigidBody2D that
## hears its transform change hands the server the transform its NODE holds -- which the
## server had already moved on from. The gameplay plane scrolls at 1, so its position never
## changes, and it was still being re-set every frame the camera moved: every rigid body under
## it was snapped back to where the node last saw it. Dagat's bangka reported 240 px/s and
## crossed the sea at 14; a boat is the first rigid body anyone has had to steer across a
## moving camera for four thousand pixels. Anything placed under the plane felt it too.
func update_for_camera(camera_position: Vector2) -> void:
	var camera_delta := camera_position - _camera_origin
	var next_position := base_position + camera_delta * (1.0 - scroll_scale)
	if position != next_position:
		position = next_position
	var next_scale := Vector2.ONE * visual_scale
	if scale != next_scale:
		scale = next_scale
	if z_index != z_index_base:
		z_index = z_index_base
