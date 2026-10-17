class_name AsinThrow2D
extends Node2D
## A handful of asin, thrown: an arc ahead of her that burns the first aswang it lands on.
##
## Kent's design: "Throwable. Burns aswang flesh over time ... Common, stacks high, the workhorse
## item." It flies `reach` px ahead along a low arc and, on meeting an aswang's body, burns it
## (Enemy2D.apply_burn) and is spent; on the ground it is spent too. One throw, one burn.

const GRAVITY := 980.0
## How long the arc takes to come back down to where it was thrown from.
const FLIGHT := 0.7
## How close to an aswang's middle counts as landing on it, past half its body.
const MARGIN := 10.0
const GRAIN := Color(0.95, 0.96, 0.98)

@export var reach := 300.0
@export var direction := 1.0
@export var burn_ticks := 3
@export var burn_seconds := 2.4

var _velocity := Vector2.ZERO
var _from_y := 0.0
var _clock := 0.0
var _spent := false

signal landed(on: Enemy2D)


func _ready() -> void:
	_velocity = Vector2(direction * reach / FLIGHT, -GRAVITY * FLIGHT * 0.5)
	_from_y = global_position.y
	z_index = 7


func _physics_process(delta: float) -> void:
	if _spent:
		return
	_clock += delta
	_velocity.y += GRAVITY * delta
	global_position += _velocity * delta
	for node in get_tree().get_nodes_in_group(Enemy2D.GROUP):
		var foe := node as Enemy2D
		if foe == null or foe.is_dead():
			continue
		if global_position.distance_to(foe.global_position) <= maxf(foe.body_size.x, foe.body_size.y) * 0.5 + MARGIN:
			foe.apply_burn(burn_ticks, burn_seconds)
			_spend(foe)
			return
	# Back down past where it left her hand: on the ground, spent.
	if _clock > FLIGHT * 0.5 and global_position.y > _from_y + 40.0:
		_spend(null)
	queue_redraw()


func _spend(on: Enemy2D) -> void:
	_spent = true
	landed.emit(on)
	queue_free()


## PLACEHOLDER until it has art: a few white grains.
func _draw() -> void:
	for offset in [Vector2(0, 0), Vector2(-4, 2), Vector2(3, -2), Vector2(-1, -4)]:
		draw_rect(Rect2(offset, Vector2(2.5, 2.5)), GRAIN)
