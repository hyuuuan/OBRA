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
		velocity.y = minf(velocity.y + _gravity * delta, MAX_FALL)

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
	_figure.queue_redraw()


# --- the contract every player answers ---------------------------------------

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


## Phase of the stride, so the morph flash can start from the pose it was standing in.
func stride_phase() -> float:
	return _phase
