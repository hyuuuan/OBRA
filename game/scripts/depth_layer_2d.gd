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


func update_for_camera(camera_position: Vector2) -> void:
	var camera_delta := camera_position - _camera_origin
	position = base_position + camera_delta * (1.0 - scroll_scale)
	scale = Vector2.ONE * visual_scale
	z_index = z_index_base
