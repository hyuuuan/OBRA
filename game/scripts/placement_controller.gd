class_name PlacementController
extends Node2D
## Cursor-driven placement transaction. It owns only the preview; confirmed
## objects stay under WorldItemRoot and canceled previews are destroyed.

signal placement_confirmed(item: DrawnItemData, utility: UtilityObject, source_slot: int)
signal placement_canceled(item: DrawnItemData, source_slot: int)
signal placement_changed(active: bool, valid: bool)

@export var maximum_distance: float = 320.0
@export var rotation_step_degrees: float = 15.0
@export var keyboard_rotation_speed: float = 100.0

var registry: EntityRegistry
var world_item_root: Node2D

var _item: DrawnItemData
var _preview: UtilityObject
var _actor: Node2D
var _source_slot: int = -1
var _valid: bool = false


func is_placing() -> bool:
	return _preview != null and is_instance_valid(_preview)


func begin_placement(item: DrawnItemData, actor: Node2D, source_slot: int = -1) -> bool:
	if item == null or actor == null or registry == null or world_item_root == null:
		return false
	if is_placing():
		cancel_placement()
	var instance := registry.instantiate_entity(item.entity_id) as UtilityObject
	if instance == null:
		return false
	_item = item
	_actor = actor
	_source_slot = source_slot
	_preview = instance
	world_item_root.add_child(_preview)
	_preview.apply_item_data(item)
	_preview.set_preview(true)
	_preview.global_rotation = item.placement_transform.get_rotation()
	_update_preview_position()
	placement_changed.emit(true, _valid)
	return true


func cancel_placement() -> void:
	if not is_placing():
		return
	var item := _item
	var slot := _source_slot
	_preview.queue_free()
	_clear_transaction()
	placement_canceled.emit(item, slot)
	placement_changed.emit(false, false)


func _process(delta: float) -> void:
	if not is_placing():
		return
	var rotate_axis := Input.get_axis("rotate_left", "rotate_right")
	if absf(rotate_axis) > 0.05:
		_preview.rotation += deg_to_rad(keyboard_rotation_speed) * rotate_axis * delta
	_update_preview_position()


func _unhandled_input(event: InputEvent) -> void:
	if not is_placing():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_preview.rotation -= deg_to_rad(rotation_step_degrees)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_preview.rotation += deg_to_rad(rotation_step_degrees)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			get_viewport().set_input_as_handled()
			confirm_placement()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			get_viewport().set_input_as_handled()
			cancel_placement()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel_placement()


func confirm_placement() -> bool:
	if not is_placing() or not _valid:
		return false
	var item := _item
	var utility := _preview
	var slot := _source_slot
	item.placement_transform = utility.global_transform
	utility.confirm_placement()
	_clear_transaction(false)
	placement_confirmed.emit(item, utility, slot)
	placement_changed.emit(false, true)
	return true


func _update_preview_position() -> void:
	if not is_placing() or not is_instance_valid(_actor):
		return
	var actor_position := _actor_position()
	var desired := get_global_mouse_position()
	var delta := desired - actor_position
	if delta.length() > maximum_distance:
		desired = actor_position + delta.normalized() * maximum_distance
	_preview.global_position = desired
	_valid = _position_is_clear() and delta.length() <= maximum_distance + 0.1
	_preview.set_preview_valid(_valid)
	placement_changed.emit(true, _valid)


func _actor_position() -> Vector2:
	if _actor.has_method("get_physics_anchor"):
		var anchor := _actor.call("get_physics_anchor") as Node2D
		if anchor != null:
			return anchor.global_position
	return _actor.global_position


func _position_is_clear() -> bool:
	var space := get_world_2d().direct_space_state
	for child in _preview.find_children("*", "CollisionShape2D", true, false):
		var collision := child as CollisionShape2D
		if collision == null or collision.shape == null or collision.get_parent() is Area2D:
			continue
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = collision.shape
		query.transform = collision.global_transform
		query.collision_mask = 1
		var excluded: Array[RID] = [_preview.get_rid()]
		for area_node in _preview.find_children("*", "Area2D", true, false):
			excluded.append((area_node as Area2D).get_rid())
		query.exclude = excluded
		for hit in space.intersect_shape(query, 8):
			var collider := hit.get("collider") as Node
			if collider == _preview or (collider != null and _preview.is_ancestor_of(collider)):
				continue
			return false
	return true


func _clear_transaction(clear_preview: bool = true) -> void:
	_item = null
	_actor = null
	_source_slot = -1
	if clear_preview:
		_preview = null
	else:
		_preview = null
	_valid = false
