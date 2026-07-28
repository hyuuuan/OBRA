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

	if is_on_floor():
		if Input.is_action_just_pressed(&"jump"):
			velocity.y = JUMP_VELOCITY
	else:
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

	# The stride advances with actual speed, so it cannot look like it is running on
	# the spot while sliding to a stop.
	var moving := absf(velocity.x) > 12.0
	_phase += delta * STRIDE_HZ * (absf(velocity.x) / SPEED if moving else 0.0)
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
