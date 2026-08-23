class_name LevelObstacle2D
extends Area2D
## The scene's half of an obstacle: a volume that knows which obstacle the player is
## standing in. Everything about what the obstacle WANTS lives in level_01.json and is
## resolved by LevelDirector -- this node carries an id and nothing else.
##
## That split is deliberate and is the reason obstacle difficulty is a data edit. If the
## required tags lived here as exports, tuning the level would mean opening the scene, and
## the load-time audit could not read them without instantiating a world.

signal player_entered(obstacle_id: String)
signal player_exited(obstacle_id: String)

## Must match an `id` in level_01.json. A mismatch is a silent dead obstacle, so it is
## checked at load rather than trusted.
@export var obstacle_id: String = ""
@export var trigger_size := Vector2(320.0, 400.0)

var _inside := false


func _ready() -> void:
	add_to_group(&"level_obstacles")
	monitoring = true
	# Layer 0 / mask 1: it detects the player without being something the player, or a
	# placed object, can collide with. An obstacle volume that pushed things around would
	# be a physics body pretending to be a trigger.
	collision_layer = 0
	collision_mask = 1
	if get_shape_count() == 0:
		var collision := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = trigger_size
		collision.shape = box
		add_child(collision)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func get_shape_count() -> int:
	var count := 0
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			count += 1
	return count


func is_player_inside() -> bool:
	return _inside


func _on_body_entered(body: Node) -> void:
	if _inside or not _is_player(body):
		return
	_inside = true
	player_entered.emit(obstacle_id)


func _on_body_exited(body: Node) -> void:
	if not _inside or not _is_player(body):
		return
	# A ragdoll morph is many bodies, and they leave the volume one at a time. Exiting on
	# the first one out would report the player as gone while most of them is still here.
	for other in get_overlapping_bodies():
		if other != body and _is_player(other):
			return
	_inside = false
	player_exited.emit(obstacle_id)


## The player is whoever is in the player_character group -- the wanderer answers to it,
## and so does every drawn creature's rig. Asking for a concrete class here would make the
## trigger stop working the moment the player morphs, which is most of the game.
func _is_player(body: Node) -> bool:
	if body == null:
		return false
	if body.is_in_group(&"player_character"):
		return true
	var parent := body.get_parent()
	while parent != null:
		if parent.is_in_group(&"player_character"):
			return true
		parent = parent.get_parent()
	return false
