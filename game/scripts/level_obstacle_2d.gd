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
## HOW FAR IN FROM THE LEADING EDGE THE STORY BOARD STANDS. Zero for every beat but one.
##
## The board goes where the beat fires, which is the trigger's leading edge -- and for Beat 0
## the leading edge is not a place, it is the spawn. B0_HAGDAN's volume has to reach x 300
## because the near bank runs 0..340 and that bank is the only ground the first sub-beat can
## be answered from (the plank is in the water and the apo cannot swim), so the volume cannot
## be narrowed to move the board. This moves the BOARD without moving the trigger: it stands
## at the water's edge, which is where the beat actually is, instead of on top of the player
## the moment the level opens.
@export var story_sign_offset := 0.0
## AND WHERE THE HINT BOARD STANDS, measured from the middle of the volume. Zero puts it at
## the obstacle's own centre, which is right when the centre is clear ground and wrong at
## Ang Dayami, where the centre is the middle of a two-hundred-pixel haystack and the board
## ends up planted in the doorway the player is meant to walk through.
@export var hint_sign_offset := 0.0
## AND WHERE THE CHECKPOINT MARK STANDS. Zero puts it near the outgoing edge of the volume,
## which is right for a beat you walk out of and wrong at the gorge: the outgoing edge is the
## far lip, there is no ground under it, and the mark's own ground sweep walks it back onto
## the near lip -- straight into the dead tree the Protector route is there to cut.
@export var checkpoint_mark_offset := 0.0

var _inside := false


func _ready() -> void:
	add_to_group(&"level_obstacles")
	# TWO SIGNS, BECAUSE A BEAT IS TWO MOMENTS IN TWO PLACES. See Signpost2D.
	#
	# The trigger is up to seven hundred pixels wide, and the beat's opening line fires the
	# instant the player crosses its LEADING EDGE while the thing to be solved is somewhere
	# in the middle of it. Planted at the trigger's own origin, the first sign in the level
	# stood three hundred and fifty pixels past the point where the level's first line of
	# dialogue had already come and gone -- so the story the game opens with was the one
	# beat with nothing to announce it.
	#
	# So the story sign stands where the story fires and the hint sign stands at the
	# obstacle. On a narrow trigger the two land on the same spot and Signpost2D drops one
	# of them, which is the right answer there too.
	# The story board carries this beat's arrival hook, so the lines it announces can be
	# read again at the board after they have played themselves once. See Signpost2D.reads.
	Signpost2D.plant(self,
		Signpost2D.Mark.STORY,
		Vector2(-trigger_size.x * 0.5 + story_sign_offset, 0.0),
		"%s.enter" % obstacle_id)
	Signpost2D.plant(self, Signpost2D.Mark.HINT, Vector2(hint_sign_offset, 0.0))
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
	else:
		_fit_authored_shape()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## `trigger_size` IS THE VOLUME, even when the shape was authored in the scene.
##
## The level file carried both -- an exported trigger_size and a RectangleShape2D
## sub-resource -- and only the sub-resource was doing anything. trigger_size was read by
## exactly one caller, the offset the story signpost is planted at, so the two numbers
## could disagree and the only visible symptom was a sign standing somewhere that was not
## the edge of the trigger. They disagreed silently for as long as both existed.
##
## So the shape is fitted to the export rather than trusted alongside it, and re-sizing a
## trigger is one number in one place. DUPLICATED FIRST: a sub-resource can be shared
## between two nodes in a scene file, and resizing a shared shape would quietly resize the
## other obstacle too. Anything that is not a plain rectangle is left alone -- a level that
## wants a polygon means it.
func _fit_authored_shape() -> void:
	for child in get_children():
		var collision := child as CollisionShape2D
		if collision == null:
			continue
		var box := collision.shape as RectangleShape2D
		if box == null:
			continue
		box = box.duplicate() as RectangleShape2D
		box.size = trigger_size
		collision.shape = box


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
