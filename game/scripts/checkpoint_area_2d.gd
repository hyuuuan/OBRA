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
##
## IT PLANTS ITS OWN FLAG. A checkpoint used to be entirely invisible -- a trigger and a
## snapshot -- so the one moment the game is generous to the player was the one moment it
## said nothing. `CheckpointFlag2D` stands at the foot of the trigger and goes up when the
## snapshot is written, which is the whole of the feedback: you walked past a thing, the
## thing changed, the level remembers you from here.

signal reached(checkpoint_id: String)

## Must match an id in level_01.json's `checkpoints`, or the level has a checkpoint that
## the data does not know about.
@export var checkpoint_id: String = ""
@export var trigger_size := Vector2(160.0, 220.0)
## Whether to plant a flag. On by default; a checkpoint hidden inside a cutscene or under
## the floor would want it off rather than a flag standing in mid-air.
@export var shows_flag: bool = true

## How far below the trigger to keep looking for ground, when the box does not reach it.
const GROUND_PROBE := 240.0
## Over the terrace, under the foreground planting. The terrace tops and the props on them
## are drawn at 0 to 6 and the front layer is at 30; a flag left at 0 is a flag behind the
## path it is standing on.
const FLAG_Z := 8

var _written := false
var _flag: CheckpointFlag2D


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
	set_physics_process(shows_flag)
	if shows_flag:
		_plant_flag()
	body_entered.connect(_on_body_entered)


## ONE PHYSICS FRAME, then never again. Where the ground is has to be asked of the physics
## server, and the server has nothing to say about a body that was added this frame.
func _physics_process(_delta: float) -> void:
	set_physics_process(false)
	_stand_flag_on_the_ground()


## Below the trigger to start with, and then dropped onto whatever is actually under it.
func _plant_flag() -> void:
	_flag = CheckpointFlag2D.new()
	_flag.name = "Flag"
	_flag.position = Vector2(0.0, trigger_size.y * 0.5)
	_flag.z_index = FLAG_Z
	add_child(_flag)


## Stand it on the ground the player walks on.
##
## IT WAS PLANTED AT THE FOOT OF THE TRIGGER, AND THE TRIGGER IS NOT THE GROUND. CP0's box is
## 200 tall and its middle sits 40 ABOVE the terrace it belongs to, because it is authored
## tall enough to catch a player jumping through it -- so "the foot of the box" was sixty
## units inside the terrace, and the pole, the cloth and the stones were all buried under the
## path. The one piece of feedback a checkpoint has was invisible from the day it was
## written, which is why the animation nobody could find appeared not to exist.
##
## How far the bottom of a trigger is from the ground is an accident of how tall the trigger
## had to be. So it is measured rather than assumed: a ray from the top of the box down past
## the bottom of it, and the flag stands on the first thing it meets.
func _stand_flag_on_the_ground() -> void:
	if _flag == null:
		return
	var space := get_world_2d().direct_space_state
	if space == null:
		return
	var from := global_position - Vector2(0.0, trigger_size.y * 0.5)
	var query := PhysicsRayQueryParameters2D.create(
		from, from + Vector2(0.0, trigger_size.y + GROUND_PROBE))
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		# Nothing under it at all. Left where it was rather than dropped into the sky: a flag
		# at the foot of the box is wrong, and a flag two hundred units below that is worse.
		return
	_flag.global_position = Vector2(global_position.x, Vector2(hit["position"]).y)


func is_written() -> bool:
	return _written


func _on_body_entered(body: Node) -> void:
	if _written or checkpoint_id.is_empty() or not _is_player(body):
		return
	_written = true
	if _flag != null:
		# The apo's position IN THE FLAG'S SPACE, because the cloth travels to them: the
		# animation is a pick-up, and a pick-up needs to know whose hands.
		_flag.hoist(_flag.to_local((body as Node2D).global_position))
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
