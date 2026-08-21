class_name CheckpointArea2D
extends Area2D
## A checkpoint you reach by walking into it, for the places that have no dialogue to hang
## one on.
##
## Most of Payyo's checkpoints are written when a route is committed, which covers every
## node. Beat 0 has no node -- it is the tutorial and it deliberately asks nothing -- so the
## climb out of it had no checkpoint at all, and a slip on the terrace above sent the player
## back to the very start of the level having already solved two sub-beats.
##
## Fires once. Re-entering is not progress, and CheckpointManager would only overwrite the
## snapshot with a later one anyway, which is the opposite of what a checkpoint is for.

signal reached(checkpoint_id: String)

## Must match an id in level_01.json's `checkpoints`, or the level has a checkpoint that
## the data does not know about.
@export var checkpoint_id: String = ""
@export var trigger_size := Vector2(160.0, 220.0)

var _written := false


func _ready() -> void:
	add_to_group(&"checkpoint_areas")
	monitoring = true
	# Detects the player without being something anything can stand on or bump into.
	collision_layer = 0
	collision_mask = 1
	var has_shape := false
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			has_shape = true
	if not has_shape:
		var collision := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = trigger_size
		collision.shape = box
		add_child(collision)
	body_entered.connect(_on_body_entered)


func is_written() -> bool:
	return _written


func _on_body_entered(body: Node) -> void:
	if _written or checkpoint_id.is_empty() or not _is_player(body):
		return
	_written = true
	reached.emit(checkpoint_id)


## Group rather than class, so it keeps working after a morph -- which is most of the game.
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
