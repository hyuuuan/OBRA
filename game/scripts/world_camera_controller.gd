class_name WorldCameraController
extends Camera2D
## Camera tuned for the full game canvas. It follows a world target while
## keeping the target centered in the visible play area whenever bounds allow.

signal camera_moved(camera_position: Vector2)

@export var play_area_left: float = 0.0
@export var follow_lerp_speed: float = 10.0
@export var vertical_lerp_speed: float = 5.5
@export var vertical_dead_zone: float = 20.0
@export_range(0.0, 1.0) var vertical_follow_scale: float = 0.75
@export var target_offset: Vector2 = Vector2(0.0, -160.0)
@export var world_bounds: Rect2 = Rect2(0.0, -520.0, 3760.0, 1200.0)
@export var camera_move_epsilon: float = 0.05
## CENTRE ON THE TARGET INSTEAD OF ANCHORING TO THE GROUND.
##
## The vertical follow below exists for a level: it pins the camera near the bottom of the
## world and lets the player rise off it by three quarters of the distance, so the ground
## stays in shot and a jump does not swing the view. Somewhere that is not a level -- the
## room inside the straw heap, which sits in the empty sky above it -- that is exactly
## wrong: the camera stays a thousand units below the floor being stood on and points at
## nothing. This is not `focus_on`, deliberately: focus is what a line of dialogue takes and
## gives back, and a room would lose its framing the moment somebody finished a sentence.
@export var vertical_free: bool = false
## THE TOP OF THE PAINTED SKY, which is not the top of the world any more.
##
## The world grew a thousand units of headroom so the room inside the straw heap has
## somewhere to be, and the camera's ceiling came with it -- so flying up as a bird went
## straight past the sky and showed the black above it. The bounds are for physics; this is
## for the camera, and in ordinary play it stops here. Somewhere that brings its own
## backdrop turns `vertical_free` on and is allowed the rest.
@export var sky_top_y: float = -520.0
## HOW FAR IN THE CAMERA SITS WHEN IT IS NOT PUSHED IN ON ANYBODY.
##
## release_focus used to tween back to 1.0 flat, which was right only for as long as one was
## the only answer. The room inside the straw heap is built to the same ruler as the house
## in the hub -- seventy-two pixels to the metre, seen at 2 -- so going in changes this, and
## a line of dialogue in there has to give the camera back at 2 and not at 1.
@export var base_zoom: float = 1.0
## WHERE TO LOOK WHILE `vertical_free` IS ON, if anywhere in particular.
##
## A room is a fixed thing and the camera should sit at its eye level and stay there, the way
## the house in the hub pins itself: following the player's height instead means the framing
## slides as she walks and the top of the wall leaves the screen. NAN means "no opinion",
## which is centring on her.
@export var vertical_pin_y: float = NAN
## THE BOX THE CAMERA MAY NOT LOOK OUT OF, when what is being looked at is smaller than the
## level.
##
## An interior is a room parked in the empty sky above the valley, and outside its own walls
## there is nothing painted at all. The camera's ordinary clamp is the LEVEL's bounds --
## four thousand units of terrace -- so walking to the end of a small room slid the view off
## the picture and filled the screen with the void the room is standing in. Rooms hand their
## own box in here on the way through the door and take it back on the way out; an empty
## rect means "no opinion", which is the level clamping itself as it always did.
@export var room_bounds: Rect2 = Rect2()

var target: Node2D = null
## What the camera is pushed in on for a beat, and how far. Null means it is doing its
## ordinary job of following the player.
var _focus: Node2D = null
var _focus_zoom := 1.0
var _focus_lift := 0.0
var _focus_tween: Tween = null
var _rest_process_mode := Node.PROCESS_MODE_INHERIT
var _vertical_rest_y: float = 0.0
var _has_vertical_rest := false
var _last_emitted_position := Vector2(INF, INF)


func _ready() -> void:
	make_current()
	snap_to_target()


func _process(delta: float) -> void:
	var desired := _clamped_target_position()
	if not _vector_is_finite(desired):
		desired = world_bounds.get_center()
	if not _vector_is_finite(global_position):
		global_position = desired
	var x_weight := 1.0
	if follow_lerp_speed > 0.0:
		x_weight = 1.0 - exp(-follow_lerp_speed * delta)
	var y_weight := 1.0
	if vertical_lerp_speed > 0.0:
		y_weight = 1.0 - exp(-vertical_lerp_speed * delta)

	var next_position := Vector2(
		lerpf(global_position.x, desired.x, x_weight),
		lerpf(global_position.y, desired.y, y_weight)
	)
	global_position = next_position
	_emit_camera_moved_if_needed()


## Push in on something and hold there until released.
##
## A line of dialogue over a wide shot is a caption on a landscape: the player reads the
## box and never looks at who is talking. Moving the camera in makes the speaker the
## subject, which is the whole difference between a cutscene and a notification.
##
## The camera keeps processing while the tree is paused, because that is exactly when this
## is used -- the world is stopped for the conversation and the push-in is the only thing
## that should still be moving.
## `lift` is how far up the SCREEN the subject is placed, in pixels, so the dialogue box
## sitting across the middle does not cover the person talking. The camera moves down by
## that much in world units, which is why it is divided by the zoom.
## Gentler than it was. The portrait carries the focus now, and a hard push-in behind a
## large figure makes the background compete with it rather than recede.
func focus_on(node: Node2D, zoom_scale: float = 1.15, seconds: float = 0.45,
		lift: float = 240.0) -> void:
	if node == null or not is_instance_valid(node):
		return
	if _focus == null:
		_rest_process_mode = process_mode
	_focus = node
	# A MULTIPLE OF WHERE THE CAMERA ALREADY IS, not an absolute. Pushing in on a speaker
	# means a little closer than we were, and in a room already seen at 2 that is 2.3 rather
	# than a jump back out to 1.15.
	_focus_zoom = maxf(0.1, zoom_scale * base_zoom)
	_focus_lift = lift
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tween_zoom(Vector2(_focus_zoom, _focus_zoom), seconds)


func release_focus(seconds: float = 0.35) -> void:
	if _focus == null:
		return
	_focus = null
	_focus_zoom = 1.0
	var restore := _rest_process_mode
	_tween_zoom(Vector2(base_zoom, base_zoom), seconds).finished.connect(
		func() -> void: process_mode = restore)


func is_focused() -> bool:
	return _focus != null


## Pause-immune, because a tween is bound to its node's pause state by default and this
## one exists to run while the tree is stopped.
func _tween_zoom(to: Vector2, seconds: float) -> Tween:
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	_focus_tween = create_tween()
	_focus_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_focus_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_focus_tween.tween_property(self, "zoom", to, seconds)
	return _focus_tween


func set_target(new_target: Node2D) -> void:
	target = new_target
	_has_vertical_rest = false


func set_bounds(bounds: Rect2) -> void:
	world_bounds = bounds


## What the camera is framing: a room while it is in one, the level otherwise.
func set_room_bounds(rect: Rect2) -> void:
	room_bounds = rect


## The box the clamps below measure against. Both the horizontal clamp and the vertical one
## read this rather than `world_bounds` directly, or a room would hold the view in on one
## axis and let it wander off the picture on the other.
func _framing_bounds() -> Rect2:
	if room_bounds.size.x > 1.0 and room_bounds.size.y > 1.0:
		return room_bounds
	return world_bounds


## Going back to anchoring on the ground forgets where the ground was, or the camera keeps
## measuring the player's height above a rest line taken somewhere they are no longer.
func set_vertical_free(free: bool, pin_y: float = NAN) -> void:
	vertical_pin_y = pin_y
	if vertical_free == free:
		return
	vertical_free = free
	_has_vertical_rest = false


## How far in the camera sits from now on. Applied at once unless a beat of dialogue has it,
## in which case that beat gives it back at the new number when it is done.
func set_base_zoom(scale: float) -> void:
	base_zoom = maxf(0.1, scale)
	if _focus != null:
		return
	# APPLIED AT ONCE, not tweened over zero seconds. A zero-length tween still does not land
	# until the next process step, and the caller's very next line is snap_to_target() --
	# which works out how much WORLD the camera can see by dividing the viewport by the zoom.
	# Snapping at the old zoom framed the first frame in a room against the level's ruler and
	# then slid out of it.
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	zoom = Vector2(base_zoom, base_zoom)


func snap_to_target() -> void:
	global_position = _clamped_target_position()
	_emit_camera_moved_if_needed(true)


func _clamped_target_position() -> Vector2:
	var desired := global_position
	# While focused the subject wins, and the vertical follow's "rest" logic is skipped:
	# it exists to stop the camera chasing a jumping player, and there is nobody jumping.
	if _focus != null and is_instance_valid(_focus):
		var focus_position := _focus.global_position
		if _vector_is_finite(focus_position):
			var drop := _focus_lift / maxf(0.01, zoom.y)
			desired = Vector2(focus_position.x, _clamp_camera_y(focus_position.y + drop))
			return _clamp_to_bounds(desired)
	if target != null and is_instance_valid(target):
		var target_position := target.global_position
		if _vector_is_finite(target_position):
			desired.x = target_position.x + target_offset.x
			if not vertical_free:
				desired.y = _vertical_follow_y(target_position.y)
			elif is_finite(vertical_pin_y):
				desired.y = _clamp_camera_y(vertical_pin_y)
			else:
				desired.y = _clamp_camera_y(target_position.y + target_offset.y)

	return _clamp_to_bounds(desired)


func _clamp_to_bounds(desired: Vector2) -> Vector2:
	var frame := _framing_bounds()
	var half_view := _viewport_size() * 0.5
	var bounds_end := frame.position + frame.size

	var min_x := frame.position.x + half_view.x - play_area_left
	var max_x := bounds_end.x - half_view.x
	if min_x <= max_x:
		desired.x = clampf(desired.x, min_x, max_x)
	else:
		desired.x = frame.position.x + frame.size.x * 0.5

	desired.y = _clamp_camera_y(desired.y)

	return desired


func _vector_is_finite(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


func _clamp_camera_y(value: float) -> float:
	var min_y := _min_camera_y()
	var max_y := _max_camera_y()
	if min_y <= max_y:
		return clampf(value, min_y, max_y)
	var frame := _framing_bounds()
	return frame.position.y + frame.size.y * 0.5


func _vertical_follow_y(target_y: float) -> float:
	if not _has_vertical_rest or target_y > _vertical_rest_y:
		_vertical_rest_y = target_y
		_has_vertical_rest = true

	var upward_distance := maxf(0.0, _vertical_rest_y - target_y - vertical_dead_zone)
	var desired_y := _max_camera_y() - upward_distance * vertical_follow_scale
	return _clamp_camera_y(desired_y)


func _min_camera_y() -> float:
	var frame := _framing_bounds()
	var top := frame.position.y if vertical_free \
		else maxf(frame.position.y, sky_top_y)
	return top + _viewport_size().y * 0.5


func _max_camera_y() -> float:
	var frame := _framing_bounds()
	return frame.position.y + frame.size.y - _viewport_size().y * 0.5


## How much WORLD the camera can see, which is the viewport divided by the zoom. It used
## to return the raw viewport, which was right for as long as the zoom was always one --
## and would have clamped a pushed-in camera as though it still saw the whole screen.
func _viewport_size() -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1600.0, 900.0)
	var scale := Vector2(maxf(0.01, zoom.x), maxf(0.01, zoom.y))
	return viewport_size / scale


func _emit_camera_moved_if_needed(force: bool = false) -> void:
	var threshold_sq := camera_move_epsilon * camera_move_epsilon
	if force or _last_emitted_position.distance_squared_to(global_position) >= threshold_sq:
		_last_emitted_position = global_position
		camera_moved.emit(global_position)
