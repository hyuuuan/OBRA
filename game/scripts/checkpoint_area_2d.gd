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
## said nothing. `CheckpointLantern2D` stands at the foot of the trigger and is lit when the
## snapshot is written, which is the whole of the feedback: you walked past a thing, the
## thing changed, the level remembers you from here.

signal reached(checkpoint_id: String)

## Must match an id in level_01.json's `checkpoints`, or the level has a checkpoint that
## the data does not know about.
@export var checkpoint_id: String = ""
@export var trigger_size := Vector2(160.0, 220.0)
## Whether to plant a mark. On by default; a checkpoint hidden inside a cutscene or under
## the floor would want it off rather than a lantern standing in mid-air.
@export var shows_mark: bool = true
## WHERE THE MARK STANDS RELATIVE TO THE TRIGGER, and it is not the middle of it.
##
## A checkpoint's whole feedback is a flag going up, and the flag was planted at the
## trigger's own centre -- which is exactly where a player walking east comes to rest. So the
## one moment the animation plays, the thing playing it is directly behind a 96px character
## sprite. Ahead and to the east: the player crosses the leading edge, and the mark is a
## hundred and thirty pixels in front of them, in clear ground, going up while they watch.
@export var mark_offset := Vector2(56.0, 0.0)
## Whether walking in lights its lantern as well as writing it. On by default. Off where the
## lantern is lit by what she does there: a clearing in Dilim is saved the moment she walks in --
## a fall past it must never send her back to the start -- and its lantern is lit by the light
## she makes, so a lit lantern says she rested there, not that she walked by.
@export var lights_on_entry := true

var _written := false
var _mark: CheckpointLantern2D


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
	if shows_mark:
		# Planted at the trigger's own middle and then DROPPED onto the ground, because the
		# trigger is not the ground: CP0's box is 200 tall and authored to catch a player
		# jumping through it, so its foot is sixty units inside the terrace. The flag, the
		# cloth and the stones were all buried under the path -- which is why the animation
		# nobody could find appeared not to exist. CheckpointLantern2D.plant owns that now, so
		# the level's other flags land the same way this one does.
		_mark = CheckpointLantern2D.plant(self, mark_offset)
	body_entered.connect(_on_body_entered)


func is_written() -> bool:
	return _written


func _on_body_entered(body: Node) -> void:
	if _written or checkpoint_id.is_empty() or not _is_player(body):
		return
	_written = true
	if lights_on_entry:
		light_mark(body as Node2D)
	reached.emit(checkpoint_id)


## Its lantern lit, the spark carried from where `from` stands. A lit one stays as it is.
func light_mark(from: Node2D = null) -> void:
	if _mark == null or _mark.lit:
		return
	# The apo's position IN THE LANTERN'S SPACE, because the spark travels FROM them: the light
	# is carried to the lantern, and that needs to know whose hands.
	_mark.light(_mark.to_local(from.global_position) if from != null else Vector2(0.0, -60.0))


func is_mark_lit() -> bool:
	return _mark != null and _mark.lit


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
