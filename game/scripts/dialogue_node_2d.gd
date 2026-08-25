class_name DialogueNode2D
extends Area2D
## A juncture where Lolo pauses time to talk, and the answer physically changes the
## level (Game Design §3): one route opens, the other two are locked away for this
## playthrough. Level 1's node is the Broken Hanging Bridge over the gorge.
##
## The node owns only the MOMENT -- detecting arrival, stopping the world, asking. What
## a route then looks like belongs to RouteLayout2D, so adding a fourth answer is a
## scene edit rather than a code change.

signal route_chosen(route: String)
## Emitted when the player arrives, before the overlay opens, so Lolo can turn and
## the level can say what is in front of them.
signal approached()

## Which level this records against in the profile, so the ending resolver can count
## routes across a run.
@export var level_id: String = "level_1"
## Fires once. A player who walks back over the trigger has already answered.
@export var trigger_size := Vector2(120.0, 320.0)

var _answered := false
var _armed := true


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = trigger_size
	collision.shape = box
	collision.position = Vector2(0.0, -trigger_size.y * 0.5)
	add_child(collision)
	body_entered.connect(_on_body_entered)
	# The one moment in the level that cannot be taken back gets its own glyph, and it
	# stands at the gorge rather than being sprung on the player. See Signpost2D.
	Signpost2D.plant(self, Signpost2D.Mark.CHOICE)


func is_answered() -> bool:
	return _answered


## Answering is separate from the trigger so the choice overlay -- and a test -- can
## resolve the node without needing a body to walk into it.
## Report the answer. It does NOT write the tally or the telemetry any more.
##
## LevelDirector.commit_route owns both now, because it also writes the checkpoint, and
## three writers for one act is three chances to disagree about whether it happened. It
## was concretely wrong once the director arrived: this recorded the route, the director
## recorded it again, and a single choice counted twice towards an ending that needs
## 7 of 12. One writer, and the tally means what it says.
func choose(route: String) -> void:
	if _answered:
		return
	_answered = true
	route_chosen.emit(route)


func _on_body_entered(body: Node) -> void:
	if _answered or not _armed:
		return
	if not _is_player(body):
		return
	_armed = false
	approached.emit()


func _is_player(body: Node) -> bool:
	var node := body
	while node != null:
		if node.is_in_group(&"player_character") or node is ActiveRagdollMorph:
			return true
		node = node.get_parent()
	return false
