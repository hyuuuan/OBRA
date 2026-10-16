class_name PlayerHurtbox2D
extends Area2D
## Where an enemy's attack lands on the player -- whoever the player is right now.
##
## It belongs to the level, not to a body. The apo and every drawn creature take turns being the
## player, and a hurtbox that lived inside one of them would leave with it the moment she changed.
## So the level owns one, points it at whoever it adopts, and it follows that body every physics
## frame: centred on her middle, since the apo's anchor is the soles of her feet and a creature's
## is its torso.
##
## It only receives. An enemy's hitbox finds it on PLAYER_HURTBOX and calls receive_hit; this
## passes the blow to PlayerHealth and shoves the body away from where the blow came from.

signal struck(from_position: Vector2)

## How an enemy finds it: there is one per fighting level.
const GROUP := &"player_hurtbox"

const SIZE := Vector2(30.0, 72.0)
## The apo's anchor is her soles; her middle is this far above them.
const FEET_TO_MIDDLE := 44.0
## A blow's shove away from where it came from, and how long it takes her controls.
const DEFAULT_KNOCK := Vector2(300.0, -220.0)
const DEFAULT_LOCK := 0.22

var health: PlayerHealth = null
var player: Node2D = null


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = PhysicsLayers.PLAYER_HURTBOX
	collision_mask = 0
	monitoring = false
	monitorable = true
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = SIZE
	shape.shape = box
	add_child(shape)


func _physics_process(_delta: float) -> void:
	follow()


func follow() -> void:
	if player != null and is_instance_valid(player):
		global_position = middle()


## The middle of whoever is the player, in world space.
func middle() -> Vector2:
	if player == null or not is_instance_valid(player):
		return global_position
	if player is Wanderer:
		return player.global_position - Vector2(0.0, FEET_TO_MIDDLE)
	if player.has_method("get_physics_anchor"):
		var anchor := player.call("get_physics_anchor") as Node2D
		if anchor != null:
			return anchor.global_position
	return player.global_position


## A blow from `from_position`. Returns whether it landed: not during the grace after the last.
##
## ⚠ THE LAST LIGHT IS NOT SHOVED. A blow while guttering snuffs the lantern, and whoever listens
## puts her back at the checkpoint -- a knock-back applied after that would throw her from the
## checkpoint instead of from the fight.
func receive_hit(from_position: Vector2, knock: Vector2 = DEFAULT_KNOCK,
		lock: float = DEFAULT_LOCK) -> bool:
	if health == null or player == null or not is_instance_valid(player):
		return false
	var last_light := health.stage <= PlayerHealth.GUTTERING
	if not health.take_hit():
		return false
	struck.emit(from_position)
	if last_light:
		return true
	var away := signf(middle().x - from_position.x)
	if away == 0.0:
		away = 1.0
	var shove := Vector2(knock.x * away, knock.y)
	if player.has_method("knock_back"):
		player.call("knock_back", shove, lock)
	elif player.has_method("apply_external_impulse"):
		player.call("apply_external_impulse", shove)
	return true
