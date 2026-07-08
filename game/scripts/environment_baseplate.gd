class_name EnvironmentBaseplate
extends Node2D
## Owns the layered visual world, gameplay collision plane, and camera target.

@export var world_bounds: Rect2 = Rect2(560.0, -520.0, 3200.0, 1200.0)
@export var floor_thickness: float = 48.0
@export var wall_thickness: float = 48.0
@export var fallback_target_path: NodePath = NodePath("GameplayPlane/SpawnPoint")
@export var entity_root_path: NodePath = NodePath("GameplayPlane/EntityRoot")
@export var camera_path: NodePath = NodePath("WorldCamera")

@onready var camera: Node = get_node(camera_path)
@onready var camera_2d: Camera2D = camera as Camera2D
@onready var entity_root: Node2D = get_node(entity_root_path)

var _layers: Array[Node] = []


func _ready() -> void:
	_collect_layers()
	camera.connect("camera_moved", _on_camera_moved)
	set_bounds(world_bounds)

	var fallback_target := get_node_or_null(fallback_target_path) as Node2D
	if fallback_target != null:
		set_target(fallback_target)
	else:
		_sync_layer_origins(camera_2d.global_position)


func set_target(target: Node2D) -> void:
	if target == null:
		return
	camera.call("set_target", target)
	camera.call("snap_to_target")
	_sync_layer_origins(camera_2d.global_position)
	_update_layers(camera_2d.global_position)


func set_bounds(bounds: Rect2) -> void:
	world_bounds = bounds
	if camera != null:
		camera.call("set_bounds", bounds)
	_layout_collision_bounds()


func get_entity_root() -> Node2D:
	return entity_root


func _collect_layers() -> void:
	_layers.clear()
	for child in get_children():
		if child.has_method("set_camera_origin") and child.has_method("update_for_camera"):
			_layers.append(child)
	_layers.sort_custom(_sort_layers_by_depth)


func _sort_layers_by_depth(a: Node, b: Node) -> bool:
	return float(a.get("depth")) > float(b.get("depth"))


func _sync_layer_origins(camera_position: Vector2) -> void:
	for layer in _layers:
		layer.call("set_camera_origin", camera_position)


func _on_camera_moved(camera_position: Vector2) -> void:
	_update_layers(camera_position)


func _update_layers(camera_position: Vector2) -> void:
	for layer in _layers:
		layer.call("update_for_camera", camera_position)


func _layout_collision_bounds() -> void:
	var floor_body := get_node_or_null("GameplayPlane/Floor") as StaticBody2D
	var left_wall := get_node_or_null("GameplayPlane/LeftWall") as StaticBody2D
	var right_wall := get_node_or_null("GameplayPlane/RightWall") as StaticBody2D
	var center_x := world_bounds.position.x + world_bounds.size.x * 0.5
	var center_y := world_bounds.position.y + world_bounds.size.y * 0.5
	var floor_y := world_bounds.position.y + world_bounds.size.y - floor_thickness * 0.5

	if floor_body != null:
		floor_body.position = Vector2(center_x, floor_y)
		_set_rectangle_shape_size(floor_body, Vector2(world_bounds.size.x, floor_thickness))
	if left_wall != null:
		left_wall.position = Vector2(world_bounds.position.x, center_y)
		_set_rectangle_shape_size(left_wall, Vector2(wall_thickness, world_bounds.size.y))
	if right_wall != null:
		right_wall.position = Vector2(world_bounds.position.x + world_bounds.size.x, center_y)
		_set_rectangle_shape_size(right_wall, Vector2(wall_thickness, world_bounds.size.y))


func _set_rectangle_shape_size(body: StaticBody2D, size: Vector2) -> void:
	var collision_shape := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		return
	var shape := collision_shape.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		collision_shape.shape = shape
	shape.size = size
