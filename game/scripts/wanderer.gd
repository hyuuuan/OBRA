class_name Wanderer
extends CharacterBody2D
## The player character: who the journey belongs to, and what a drawn animal replaces.
##
## DELIBERATELY A PLACEHOLDER. It is drawn in code from a handful of primitives rather
## than from art, so it can be thrown away whole when the real design lands without
## anything else having to change. What is NOT placeholder is the interface: the level
## talks to whoever is the player through get_physics_anchor / get_camera_target /
## capture_morph_state / set_world_bounds, and a drawn creature answers exactly the
## same calls. That is what lets the two swap.
##
## It is a CharacterBody2D and not a ragdoll on purpose. The morphs are ragdolls
## because they are the player's own drawing and have to keep its shape; the wanderer
## has no drawing to preserve, and a character controller is what makes it reliable to
## walk around with while everything else is being built.

const SPEED := 260.0
const ACCELERATION := 1800.0
const FRICTION := 2200.0
const JUMP_VELOCITY := -430.0
const MAX_FALL := 900.0

## Limbs swing this far at full stride, in radians.
const STRIDE := 0.7
const STRIDE_HZ := 2.2

## Climbing a drawn ladder. Slower than walking, and sideways movement is throttled so
## stepping off is deliberate rather than something that happens while aiming upward.
const CLIMB_SPEED := 190.0
const CLIMB_DRIFT := 0.35
## How far from the ladder you can get before you are no longer on it.
const CLIMB_RELEASE := 120.0
## An open umbrella is a parachute you are holding.
const UMBRELLA_FALL_LIMIT := 190.0

## Wading. Deep water is meant to stop a walker, so it costs most of your speed, pulls
## you steadily down, and leaves you barely able to jump out of it.
const WADE_DRAG := 0.55
const WADE_SINK := 0.42
const WADE_SINK_SPEED := 120.0
const WADE_JUMP := 0.45

@onready var _figure: Node2D = $Figure

var world_bounds := Rect2(0.0, -520.0, 3760.0, 1200.0)

var _gravity: float = 980.0
var _phase: float = 0.0
var _facing: float = 1.0
var _carrying := ""
## Outside forces, in acceleration and in velocity, both cleared every physics frame.
var _assist := Vector2.ZERO
var _impulse := Vector2.ZERO
var _fall_limit := MAX_FALL
## The rest of the contract the utilities call on whoever the player is. None of this
## was answered before, so for the character the player actually starts as, a drawn
## ladder was scenery and a drawn umbrella did nothing.
var _ladder: Node2D = null
var _vehicle: Node2D = null
var _equipped_utility: Node2D = null
var _umbrella_open := false
var _grip: Marker2D = null


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	add_to_group(&"player_character")


func _physics_process(delta: float) -> void:
	var direction := Input.get_axis(&"move_left", &"move_right")
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)
		_facing = signf(direction)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	if _riding():
		# A passenger does not walk. The vehicle puts us where it is going, and our own
		# locomotion would otherwise carry us straight off the deck -- which is exactly
		# what a boat "leaving the player behind" was.
		velocity = Vector2.ZERO
		if Input.is_action_just_pressed(&"jump"):
			end_ride()
			velocity.y = JUMP_VELOCITY
		_advance_stride(delta, 0.0)
		return
	if _climbing():
		# On a ladder the whole point is that gravity is not the thing deciding where
		# you go. Up and down drive directly; sideways is throttled so stepping off is
		# something you mean rather than something that happens while aiming upward.
		velocity.y = Input.get_axis(&"move_up", &"move_down") * CLIMB_SPEED
		velocity.x = direction * SPEED * CLIMB_DRIFT
		if Input.is_action_just_pressed(&"jump"):
			end_ladder()
			velocity.y = JUMP_VELOCITY
	elif is_in_water():
		# WADING, NOT WALKING. Water used to be scenery you strolled through at full
		# speed, which made a drawn boat pointless and a swimmer morph a novelty. It
		# drags now, and it pulls you down: you can cross a shallow paddy on foot and
		# you cannot cross deep water, which is the whole reason to draw something that
		# floats or something that swims.
		velocity.x *= WADE_DRAG
		velocity.y = minf(velocity.y + _gravity * WADE_SINK * delta, WADE_SINK_SPEED)
		if Input.is_action_just_pressed(&"jump"):
			velocity.y = JUMP_VELOCITY * WADE_JUMP
	elif is_on_floor():
		if Input.is_action_just_pressed(&"jump"):
			velocity.y = JUMP_VELOCITY
	else:
		if _umbrella_open:
			_fall_limit = minf(_fall_limit, UMBRELLA_FALL_LIMIT)
		velocity.y = minf(velocity.y + (_gravity + _assist.y) * delta, _fall_limit)
	velocity.x += _assist.x * delta
	velocity += _impulse
	_impulse = Vector2.ZERO
	# One frame's worth. A utility that means it re-applies every frame, which is what
	# makes a parachute stop lifting the moment it is folded away.
	_assist = Vector2.ZERO
	_fall_limit = MAX_FALL

	move_and_slide()
	# Keep it inside the level rather than letting it walk off the end of the world.
	global_position.x = clampf(global_position.x, world_bounds.position.x, world_bounds.end.x)
	if global_position.y > world_bounds.end.y:
		global_position = Vector2(global_position.x, world_bounds.position.y)
		velocity = Vector2.ZERO

	_advance_stride(delta, velocity.x)


## The stride advances with actual speed, so it cannot look like it is running on the
## spot while sliding to a stop -- or while sitting still on a boat.
func _advance_stride(delta: float, horizontal_speed: float) -> void:
	var moving := absf(horizontal_speed) > 12.0
	_phase += delta * STRIDE_HZ * (absf(horizontal_speed) / SPEED if moving else 0.0)
	_figure.scale.x = _facing
	_figure.set("stride", _phase)
	_figure.set("carrying", _carrying)
	_figure.queue_redraw()


# --- the contract every player answers ---------------------------------------

## A utility pushing on the player: an acceleration held for one frame. A fan, a
## parachute's drag, a balloon's lift all arrive here and are re-applied every frame
## for as long as the utility is doing it. Drawn creatures answer the same call by
## pushing their whole rig, so an effect feels identical whoever the player is --
## which matters because the wanderer is who the player IS until they draw an animal.
func apply_external_force(acceleration: Vector2) -> void:
	_assist += acceleration


## An instant velocity change: a mushroom's bounce, a cannon's recoil.
func apply_external_impulse(velocity_change: Vector2) -> void:
	_impulse += velocity_change


## Caps how fast the player may fall this frame. A parachute is mostly this.
func limit_fall_speed(limit: float) -> void:
	_fall_limit = minf(_fall_limit, maxf(0.0, limit))


## Where a held tool sits: the forward hand, so an equipped axe is in a hand rather
## than at the character's feet. equip_to falls back to the actor itself when this is
## missing, which is why every tool used to hang off the wanderer's origin.
func get_grip_anchor() -> Node2D:
	if _grip == null or not is_instance_valid(_grip):
		_grip = Marker2D.new()
		_grip.name = "GripAnchor"
		add_child(_grip)
	_grip.position = Vector2(14.0 * _facing, -48.0)
	return _grip


func set_equipped_utility(utility: Node2D) -> void:
	_equipped_utility = utility
	if utility == null:
		_umbrella_open = false


## Riding a drawn vehicle. Same shape as the ladder: the thing you are on takes over
## where you go, and you get off deliberately.
func begin_ride(vehicle: Node2D) -> void:
	_vehicle = vehicle


func end_ride() -> void:
	_vehicle = null


func is_riding(vehicle: Node2D = null) -> bool:
	if _vehicle == null or not is_instance_valid(_vehicle):
		_vehicle = null
		return false
	return vehicle == null or vehicle == _vehicle


func _riding() -> bool:
	return is_riding()


func begin_ladder(ladder: Node2D) -> void:
	_ladder = ladder


func end_ladder() -> void:
	_ladder = null


func is_using_ladder(ladder: Node2D) -> bool:
	return _ladder == ladder


func set_umbrella_open(is_open: bool) -> void:
	_umbrella_open = is_open


## WaterArea2D tags the bodies inside it, so this is the same answer a drawn creature
## gives -- a boat asking "is my passenger in the water" gets a real reply either way.
func is_in_water() -> bool:
	return int(get_meta("water_overlap_count", 0)) > 0


## Letting go of a ladder by walking away from it, rather than only by pressing E again.
## A ladder you can drift off and still be silently attached to is a ladder that eats
## the next jump.
func _climbing() -> bool:
	if _ladder == null or not is_instance_valid(_ladder):
		_ladder = null
		return false
	# Measured HORIZONTALLY, and generously: a ladder is a tall thing whose origin sits
	# at its middle, so a straight distance check released the player the moment they
	# had climbed a bit of it -- which read as the ladder simply not working.
	if absf(global_position.x - (_ladder as Node2D).global_position.x) > CLIMB_RELEASE:
		_ladder = null
		return false
	return true


func set_world_bounds(bounds: Rect2) -> void:
	world_bounds = bounds


## The morphs return a rigid body here; the level only ever reads its position, so a
## plain node is a valid answer.
func get_physics_anchor() -> Node2D:
	return self


func get_camera_target() -> Node2D:
	return self


## Carried across a morph so the drawn creature appears where the wanderer stood
## rather than back at the spawn point.
func capture_morph_state() -> Dictionary:
	return {
		"position": global_position,
		"velocity": velocity,
		"facing": _facing,
	}


func apply_morph_state(state: Dictionary) -> void:
	if state.has("position"):
		global_position = state["position"]
	if state.has("velocity"):
		velocity = state["velocity"]
	if state.has("facing"):
		_facing = float(state["facing"])


## Show an item in the character's hand. The level calls this when a utility is
## equipped, so what the player is holding is visible on the character rather than
## only in a status line that has already scrolled away.
func set_carried(entity_id: String) -> void:
	_carrying = entity_id
	if _figure != null:
		_figure.queue_redraw()


## Phase of the stride, so the morph flash can start from the pose it was standing in.
func stride_phase() -> float:
	return _phase
