class_name HiddenFlower2D
extends Area2D
## One of the five Hidden Flowers (Game Design §2.2, §5). Level 1's sits in the cave at
## the bottom of the gorge, behind a ConceptGate2D that wants Illumination -- a concept
## the player does not have yet, which is the point: it is a reason to come back once
## Level 4 has taught them to draw a Torch.
##
## Collection is recorded in the profile, not in the level, so a flower found on a
## backtrack counts toward the ending from any session.

signal collected(collectible_id: String)

@export var collectible_id: String = "flower_1"
## Set when the flower is inside a dark place: it stays unlit and untakeable until the
## gate in front of it opens.
@export var starts_hidden: bool = true

var _taken := false
var _revealed := false
var _phase: float = 0.0


func _ready() -> void:
	add_to_group(&"hidden_flowers")
	collision_layer = 0
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26.0
	collision.shape = circle
	add_child(collision)
	body_entered.connect(_on_body_entered)
	z_index = 8
	var profile := get_node_or_null(^"/root/PlayerProfile")
	_taken = profile != null and bool(profile.call("is_collectible_found", collectible_id))
	_revealed = not starts_hidden
	visible = not _taken
	set_process(not _taken)


## Called by the gate in front of it. A flower nobody can see is not a secret, it is a
## bug -- so revealing it is an explicit act, not a side effect of standing nearby.
func reveal() -> void:
	if _revealed or _taken:
		return
	_revealed = true
	var bloom := create_tween()
	bloom.tween_property(self, "scale", Vector2(1.25, 1.25), 0.25).set_trans(Tween.TRANS_BACK)
	bloom.tween_property(self, "scale", Vector2.ONE, 0.2)


func is_available() -> bool:
	return _revealed and not _taken


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * 0.5, 1.0)
	queue_redraw()


func _draw() -> void:
	if _taken:
		return
	var lift := sin(TAU * _phase) * 3.0
	var centre := Vector2(0.0, lift)
	# Unrevealed it is a bud in the dark: present, but plainly not ready.
	var petal_colour := Color(0.98, 0.72, 0.82) if _revealed else Color(0.3, 0.3, 0.36, 0.55)
	var heart_colour := Color(1.0, 0.86, 0.35) if _revealed else Color(0.36, 0.36, 0.42, 0.6)
	if _revealed:
		draw_circle(centre, 24.0, Color(1.0, 0.86, 0.5, 0.16))
	for index in range(5):
		var angle := TAU * float(index) / 5.0 + _phase * 0.4
		draw_circle(centre + Vector2(cos(angle), sin(angle)) * 9.0, 7.0, petal_colour)
	draw_circle(centre, 5.5, heart_colour)
	draw_line(centre + Vector2(0.0, 6.0), centre + Vector2(0.0, 24.0),
		Color(0.36, 0.6, 0.32) if _revealed else Color(0.3, 0.32, 0.34, 0.6), 3.0)


func _on_body_entered(body: Node) -> void:
	if _taken or not _revealed or not _is_player(body):
		return
	_taken = true
	var profile := get_node_or_null(^"/root/PlayerProfile")
	if profile != null:
		profile.call("record_collectible", collectible_id)
	var telemetry := get_node_or_null(^"/root/Telemetry")
	if telemetry != null:
		telemetry.call("record_event", "collectible_found", {"collectible_id": collectible_id})
	collected.emit(collectible_id)
	var pick := create_tween()
	pick.set_parallel(true)
	pick.tween_property(self, "position:y", position.y - 60.0, 0.5)
	pick.tween_property(self, "modulate:a", 0.0, 0.5)
	pick.chain().tween_callback(queue_free)


func _is_player(body: Node) -> bool:
	var node := body
	while node != null:
		if node.is_in_group(&"player_character") or node is ActiveRagdollMorph:
			return true
		node = node.get_parent()
	return false
