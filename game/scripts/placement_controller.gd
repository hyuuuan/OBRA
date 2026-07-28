class_name PlacementController
extends Node2D
## Cursor-driven placement transaction. It owns only the preview; confirmed
## objects stay under WorldItemRoot and canceled previews are destroyed.

signal placement_confirmed(item: DrawnItemData, utility: PhysicsShapeObject, source_slot: int)
signal placement_canceled(item: DrawnItemData, source_slot: int)
signal placement_changed(active: bool, valid: bool)
## A confirm click on a spot the preview could not be freed into. Without this the
## click was simply swallowed and nothing on screen said why.
signal placement_rejected()

@export var maximum_distance: float = 360.0
@export var rotation_step_degrees: float = 15.0
@export var keyboard_rotation_speed: float = 100.0
## How far the preview may climb out of solid geometry before the spot counts as
## unusable. About a body height: enough to stand a ladder on the ground or on a
## ledge, not enough to escape the middle of a hill.
@export var maximum_lift: float = 168.0
## The reach circle, drawn while placing. Without it, a preview that stops following
## the cursor at an invisible radius reads as the game dropping things at random.
@export var show_reach_ring: bool = true

## Granularity of the climb out of an obstacle. Small enough that the object looks
## like it is resting on the surface rather than hovering over it.
const _LIFT_STEP := 12.0

var registry: EntityRegistry
var world_item_root: Node2D

var _item: DrawnItemData
## Typed as the BASE, not UtilityObject: a drawn circle or ramp is placed the same way
## a drawn axe is, and casting to UtilityObject made every shape fail to start.
var _preview: PhysicsShapeObject
var _actor: Node2D
var _source_slot: int = -1
var _valid: bool = false
## The cursor was outside the reach circle and the preview was pinned to its edge.
## Reported separately from validity because it is not a refusal -- the pinned spot
## is placeable -- it just explains why the preview stopped following the mouse.
var _at_reach_limit: bool = false
var _excluded_rids: Array[RID] = []


func _ready() -> void:
	# Above the gameplay plane and its front layer (z_index 20) so the reach ring is
	# not buried behind terraces. The HUD is on its own CanvasLayer and stays on top.
	z_index = 100


func is_placing() -> bool:
	return _preview != null and is_instance_valid(_preview)


func is_at_reach_limit() -> bool:
	return _at_reach_limit


## Called by UIRouter, AHEAD of the pause menu in the cancel chain. This used to be a
## ui_cancel branch in _unhandled_input and was unreachable: the pause menu is the
## last child of GameLevel and input propagates in reverse tree order, so Escape while
## placing opened the pause menu instead. Right-click still cancels, which is why the
## placement was never actually stuck -- but Escape did the wrong thing.
func handle_cancel() -> bool:
	if not is_placing():
		return false
	cancel_placement()
	return true


func begin_placement(item: DrawnItemData, actor: Node2D, source_slot: int = -1) -> bool:
	if item == null or actor == null or registry == null or world_item_root == null:
		return false
	if is_placing():
		cancel_placement()
	var instance := registry.instantiate_entity(item.entity_id) as PhysicsShapeObject
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
	update_target(get_global_mouse_position())
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
	update_target(get_global_mouse_position())


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
			if not confirm_placement():
				placement_rejected.emit()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
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
	_clear_transaction()
	placement_confirmed.emit(item, utility, slot)
	placement_changed.emit(false, true)
	return true


## Where the preview wants to go, in world space. Public because the mouse is only one
## way to point at a spot -- a test has no pointer, and driving this directly is the
## only way to reproduce a reach or overlap failure headlessly.
func update_target(world_position: Vector2) -> void:
	if not is_placing() or not is_instance_valid(_actor):
		return
	var origin := _actor_position()
	var offset := world_position - origin
	var beyond_reach := offset.length() > maximum_distance
	if beyond_reach:
		world_position = origin + offset.normalized() * maximum_distance
	_preview.global_position = world_position
	_refresh_preview_exclusions()
	# Aim first, then climb. Validity is judged where the preview ACTUALLY ended up:
	# the old check measured the pre-clamp cursor distance, so pointing anywhere past
	# the reach radius pinned the preview to a perfectly placeable spot and then
	# refused it forever -- the object looked like it had been dropped at random and
	# every click was swallowed with "blocked or out of range".
	var placeable := _lift_clear_of_obstacles()
	if placeable != _valid or beyond_reach != _at_reach_limit:
		_valid = placeable
		_at_reach_limit = beyond_reach
		placement_changed.emit(true, _valid)
	_preview.set_preview_valid(_valid)
	if show_reach_ring:
		queue_redraw()


## Climbs the preview out of anything solid it landed in and reports whether it found
## air. Overlapping used to be an outright refusal, which made the one thing players
## actually do -- rest a ramp ON the ground -- impossible: terrain, the player and
## every placed object share collision layer 1, so the only legal spots were floating
## in mid-air out of arm's reach of the character. Everything placeable is a rigid
## body that would settle onto the surface anyway, so an overlap was never a reason to
## say no; it only ever meant "spawned inside something", which the lift resolves.
func _lift_clear_of_obstacles() -> bool:
	var base := _preview.global_position
	# An object buried in the ground has to travel most of its own height before it is
	# standing on top of it, so the budget scales with the object. A fixed one sized for
	# a small shape let circles through and reported "no room" for a ladder.
	var limit := maxf(maximum_lift, _preview_height() * 1.25)
	var lifted := 0.0
	while lifted <= limit:
		_preview.global_position = base - Vector2(0.0, lifted)
		if _position_is_clear():
			return true
		lifted += _LIFT_STEP
	_preview.global_position = base
	return false


## World-space vertical extent of the preview's own collision, rotation included.
func _preview_height() -> float:
	var bounds := Rect2()
	var started := false
	for child in _preview.get_children():
		var collision := child as CollisionShape2D
		if collision == null or collision.shape == null or not collision.shape.has_method("get_rect"):
			continue
		var rect: Rect2 = collision.shape.call("get_rect")
		var basis := collision.global_transform
		for corner in [
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			Vector2(rect.position.x, rect.end.y),
			rect.end,
		]:
			var point: Vector2 = basis * corner
			bounds = bounds.expand(point) if started else Rect2(point, Vector2.ZERO)
			started = true
	return bounds.size.y


func _draw() -> void:
	if not show_reach_ring or not is_placing() or not is_instance_valid(_actor):
		return
	var origin := to_local(_actor_position())
	var tint := Color(0.42, 0.95, 0.55) if _valid else Color(1.0, 0.42, 0.38)
	# Drawn twice: a wide soft band that reads over busy level art, and a crisp line on
	# top so the edge the preview pins to is unambiguous.
	draw_arc(origin, maximum_distance, 0.0, TAU, 96, Color(tint, 0.16), 9.0, true)
	draw_arc(origin, maximum_distance, 0.0, TAU, 96, Color(tint, 0.85), 2.5, true)


func _actor_position() -> Vector2:
	if _actor.has_method("get_physics_anchor"):
		var anchor := _actor.call("get_physics_anchor") as Node2D
		if anchor != null:
			return anchor.global_position
	return _actor.global_position


## Everything the preview carries that could report itself as an obstacle: its own
## body, its interaction area, and the skin's rig bodies. Rebuilt per aim because a
## rig can be replaced under a live preview.
func _refresh_preview_exclusions() -> void:
	_excluded_rids = [_preview.get_rid()]
	for node in _preview.find_children("*", "CollisionObject2D", true, false):
		var object := node as CollisionObject2D
		if object != null:
			_excluded_rids.append(object.get_rid())


func _position_is_clear() -> bool:
	var space := get_world_2d().direct_space_state
	# Only the shapes the OBJECT body collides with. This used to sweep the whole
	# subtree, which on a drawn object means the skin's rig bodies too -- their shapes
	# are authored in the drawing's own space and, before they were pinned, sat
	# wherever the ragdoll had flopped to. The query was asking whether the world was
	# clear at points that had nothing to do with the cursor, and limbs counted each
	# other as obstacles, so placement was refused at random, everywhere.
	for child in _preview.get_children():
		var collision := child as CollisionShape2D
		if collision == null or collision.shape == null:
			continue
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = collision.shape
		query.transform = collision.global_transform
		query.collision_mask = 1
		query.exclude = _excluded_rids
		# One hit is enough to know this rung of the climb is blocked, and the climb
		# runs every frame the cursor moves -- there is no reason to gather eight.
		if not space.intersect_shape(query, 1).is_empty():
			return false
	return true


func _clear_transaction() -> void:
	_item = null
	_actor = null
	_source_slot = -1
	_preview = null
	_valid = false
	_at_reach_limit = false
	if show_reach_ring:
		queue_redraw()
