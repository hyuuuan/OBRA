class_name AsinThrow2D
extends Node2D
## A handful of asin, thrown: an arc ahead of her that burns the first aswang it lands on.
##
## Kent's design: "Throwable. Burns aswang flesh over time ... Common, stacks high, the workhorse
## item." It flies along a low arc from her middle to the ground `reach` px ahead and, on meeting
## an aswang's body, burns it (Enemy2D.apply_burn) and is spent; on the ground it is spent too.
## One throw, one burn.

const GRAVITY := 980.0
## How long it is in the air, and how far it falls in that time: thrown from her middle, it comes
## down on the ground at its full reach -- a low throw, over nothing taller than her.
const FLIGHT := 0.55
const DROP := 44.0
## How far past an aswang's body counts as landing on it: a handful spreads, more up and down.
const MARGIN := Vector2(10.0, 30.0)
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
	_velocity = Vector2(direction * reach / FLIGHT, (DROP - 0.5 * GRAVITY * FLIGHT * FLIGHT) / FLIGHT)
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
		var off := (global_position - foe.global_position).abs()
		if off.x <= foe.body_size.x * 0.5 + MARGIN.x and off.y <= foe.body_size.y * 0.5 + MARGIN.y:
			foe.apply_burn(burn_ticks, burn_seconds)
			_spend(foe)
			return
	# Down on the ground: spent.
	if global_position.y >= _from_y + DROP:
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
