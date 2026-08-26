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
## How far below the preview to look for the ground when it is NOT resting on anything, so
## the drop line can be drawn to where the object is really going to end up. Longer than any
## fall in the level; it is one shape cast per aim, not a loop.
const _FALL_PROBE := 1800.0
## How far inside the allowed box the preview is held, when there is one, ON TOP OF the
## object's own half-size.
##
## A room's box is its PICTURE, and the walls the player can actually touch stand inside
## that: the heap's bamboo is 8 units outside its bounds and the house's is 22 inside them.
## So the clamp has to clear the widest of those by more than the object's own half-width,
## or the aim pins itself to a spot the overlap test then refuses -- a preview stuck red
## against a wall, which is worse than the fall it replaced. Fifty-six is about half a body
## and clears both rooms' bamboo with the biggest thing that can be drawn.
const _INSIDE_MARGIN := 56.0

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
## The cursor was outside the room and the preview was pinned to its wall. Reported apart
## from the reach limit because they are two different refusals and the player is owed the
## right one: "your arm does not reach" and "the room ends here" call for different moves.
var _held_by_room: bool = false
## Whether the preview is standing on something. When it is not, confirming drops the
## object and the ghost is no longer a promise -- so the fall gets drawn instead of hidden.
var _resting: bool = false
var _fall_landing: Vector2 = Vector2.ZERO
var _will_fall: bool = false
var _excluded_rids: Array[RID] = []
## THE BOX A PLACEMENT MAY NOT LEAVE. Empty means the level, which needs none.
##
## The reach circle is 360 units wide because that is arm's length in a valley four thousand
## units across. Inside a room it is most of the screen -- and a room is a floor a few hundred
## units long parked in the empty sky above the level, with nothing under it for two thousand
## units. So aiming anywhere past the boards put the object down in the sky, and confirming
## dropped it out of the room, through the roof of the world and onto the valley floor. It
## looked exactly like the game throwing the thing off the map, because it was.
##
## The room hands its own box in on the way through the door and takes it back on the way out.
var _allowed: Rect2 = Rect2()


func _ready() -> void:
	# Above the gameplay plane and its front layer (z_index 20) so the reach ring is
	# not buried behind terraces. The HUD is on its own CanvasLayer and stays on top.
	z_index = 100


func is_placing() -> bool:
	return _preview != null and is_instance_valid(_preview)


func is_at_reach_limit() -> bool:
	return _at_reach_limit


func is_held_by_room() -> bool:
	return _held_by_room


## Where placement is allowed from now on. An empty rect lifts the restriction.
func set_allowed_area(rect: Rect2) -> void:
	_allowed = rect
	if is_placing():
		update_target(_preview.global_position)


## Pull an aim back inside the allowed box, if there is one.
##
## The inset is the clearance PLUS the object's own half-size, because what is clamped is the
## preview's CENTRE: pinning the middle of a wide object to the wall stands half of it inside
## the bamboo.
func _held_inside(at: Vector2) -> Vector2:
	if _allowed.size.x <= 1.0 or _allowed.size.y <= 1.0:
		return at
	var margin := Vector2(_INSIDE_MARGIN, _INSIDE_MARGIN) + _preview_rect().size * 0.5
	var inset := Rect2(_allowed.position + margin, _allowed.size - margin * 2.0)
	if inset.size.x <= 0.0 or inset.size.y <= 0.0:
		return _allowed.get_center()
	return Vector2(
		clampf(at.x, inset.position.x, inset.end.x),
		clampf(at.y, inset.position.y, inset.end.y))


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
	# AND INSIDE THE ROOM, if there is one. Held rather than refused: pinning the preview to
	# the wall is the same answer the reach circle gives, and a spot the player can see the
	# ghost sitting in is a better answer than a click that does nothing.
	var pulled_in := _held_inside(world_position)
	var held_by_room := not pulled_in.is_equal_approx(world_position)
	world_position = pulled_in
	_preview.global_position = world_position
	_refresh_preview_exclusions()
	# Aim first, then climb. Validity is judged where the preview ACTUALLY ended up:
	# the old check measured the pre-clamp cursor distance, so pointing anywhere past
	# the reach radius pinned the preview to a perfectly placeable spot and then
	# refused it forever -- the object looked like it had been dropped at random and
	# every click was swallowed with "blocked or out of range".
	var placeable := _lift_clear_of_obstacles()
	if placeable:
		_settle_onto_support()
	else:
		_resting = false
	_refresh_fall_line(placeable)
	if placeable != _valid or beyond_reach != _at_reach_limit \
			or held_by_room != _held_by_room:
		_valid = placeable
		_at_reach_limit = beyond_reach
		_held_by_room = held_by_room
		placement_changed.emit(true, _valid)
	_preview.set_preview_valid(_valid)
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
	var limit := _climb_budget()
	var lifted := 0.0
	while lifted <= limit:
		_preview.global_position = base - Vector2(0.0, lifted)
		if _position_is_clear():
			return true
		lifted += _LIFT_STEP
	_preview.global_position = base
	return false


## How far the preview may travel vertically, up out of solid ground or back down onto it.
## An object buried in the ground has to move most of its own height before it is standing on
## top of it, so the budget scales with the object -- a fixed one sized for a small shape let
## circles through and reported "no room" for a ladder.
func _climb_budget() -> float:
	return maxf(maximum_lift, _preview_height() * 1.25)


## PUT THE GHOST WHERE THE OBJECT IS GOING TO BE. The climb above takes the preview UP out of
## anything solid it landed in and stops there. Nothing ever brought it back down, and
## confirming unfreezes it -- so it fell from wherever the climb happened to end. Aim at your
## own feet, which is exactly where a player building a step aims, and the climb went a body's
## height over your head, went green up there, and dropped the thing on you when you clicked.
##
## The drop budget is the climb's budget on purpose. Any lift out of solid ground is undone
## back onto the first surface beneath it, and a deliberate aim into open air with nothing
## within reach below stays where it was put rather than teleporting to the floor.
func _settle_onto_support() -> void:
	var drop := _fall_distance(_climb_budget())
	_resting = drop >= 0.0
	if drop > 0.0:
		_preview.global_position += Vector2(0.0, drop)


## How far the preview would fall before something stopped it, or -1.0 if nothing does within
## `distance`. Same shapes, mask and exclusions as the overlap test, so it never settles onto
## the player -- who is excluded precisely because they can walk away.
func _fall_distance(distance: float) -> float:
	if distance <= 0.0:
		return -1.0
	var space := get_world_2d().direct_space_state
	var closest := 1.0
	var supported := false
	for child in _preview.get_children():
		var collision := child as CollisionShape2D
		if collision == null or collision.shape == null:
			continue
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = collision.shape
		query.transform = collision.global_transform
		query.motion = Vector2(0.0, distance)
		query.collision_mask = 1
		query.exclude = _excluded_rids
		var result := space.cast_motion(query)
		if result.size() < 1:
			continue
		var safe := float(result[0])
		if safe < 1.0:
			supported = true
		closest = minf(closest, safe)
	return closest * distance if supported else -1.0


## A placement into open air is allowed -- a bridge is set across a gorge, not onto its
## floor -- but it should not be a surprise. When the preview is resting on nothing, find
## where it lands and draw the fall.
func _refresh_fall_line(placeable: bool) -> void:
	_will_fall = false
	if not placeable or _resting:
		return
	var drop := _fall_distance(_FALL_PROBE)
	if drop <= 0.0:
		return
	_will_fall = true
	_fall_landing = _preview.global_position + Vector2(0.0, drop)


## World-space box the preview's own collision occupies, rotation included. Only its SIZE is
## ever used, which is why it does not matter that this is measured before the aim moves it.
func _preview_rect() -> Rect2:
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
	return bounds


## World-space vertical extent of the preview's own collision, rotation included.
func _preview_height() -> float:
	return _preview_rect().size.y


func _draw() -> void:
	if not is_placing() or not is_instance_valid(_actor):
		return
	var tint := Color(0.42, 0.95, 0.55) if _valid else Color(1.0, 0.42, 0.38)
	if show_reach_ring:
		var origin := to_local(_actor_position())
		# Drawn twice: a wide soft band that reads over busy level art, and a crisp line on
		# top so the edge the preview pins to is unambiguous.
		draw_arc(origin, maximum_distance, 0.0, TAU, 96, Color(tint, 0.16), 9.0, true)
		draw_arc(origin, maximum_distance, 0.0, TAU, 96, Color(tint, 0.85), 2.5, true)
	if _will_fall:
		# It is legal to place into the air, and sometimes it is the answer. It should just
		# never be a surprise: this is the one case where the ghost is not where the object
		# ends up, so the drop is drawn rather than left to be discovered on the click.
		var from := to_local(_preview.global_position)
		var to := to_local(_fall_landing)
		draw_dashed_line(from, to, Color(tint, 0.55), 2.0, 10.0)
		draw_arc(to, 12.0, 0.0, TAU, 32, Color(tint, 0.8), 2.0, true)


func _actor_position() -> Vector2:
	if _actor.has_method("get_physics_anchor"):
		var anchor := _actor.call("get_physics_anchor") as Node2D
		if anchor != null:
			return anchor.global_position
	return _actor.global_position


## Everything the preview carries that could report itself as an obstacle: its own
## body, its interaction area, and the skin's rig bodies. Rebuilt per aim because a
## rig can be replaced under a live preview.
##
## AND THE PLAYER. They stand on collision layer 1 like the terrain, so the ground under
## their own feet came back occupied and the spot a player most wants -- right here, at the
## foot of the thing I am trying to climb -- was the one spot the preview refused. It did not
## even refuse honestly: the climb lifted the object a body's height over their head, went
## green up there, and dropped it on them. The player is the only obstacle in the world that
## can walk away, so it is the only one that should not get a vote.
func _refresh_preview_exclusions() -> void:
	_excluded_rids = [_preview.get_rid()]
	for node in _preview.find_children("*", "CollisionObject2D", true, false):
		var object := node as CollisionObject2D
		if object != null:
			_excluded_rids.append(object.get_rid())
	if _actor == null or not is_instance_valid(_actor):
		return
	# A drawn creature is a body with rig bodies under it; the wanderer is one body. Both
	# answer the same sweep.
	var actor_body := _actor as CollisionObject2D
	if actor_body != null:
		_excluded_rids.append(actor_body.get_rid())
	for node in _actor.find_children("*", "CollisionObject2D", true, false):
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
	_held_by_room = false
	_resting = false
	_will_fall = false
	queue_redraw()
