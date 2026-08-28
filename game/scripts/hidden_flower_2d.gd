class_name HiddenFlower2D
extends Area2D
## One of the five Hidden Flowers (Game Design §2.2, §5). Level 1's sits in the cave at
## the bottom of the gorge, behind a ConceptGate2D that wants Illumination -- a concept
## the player does not have yet, which is the point: it is a reason to come back once
## Level 4 has taught them to draw a Torch.
##
## Collection is recorded in the profile, not in the level, so a flower found on a
## backtrack counts toward the ending from any session.
##
## IT IS THE REAL FLOWER NOW. This was five circles and a line -- a placeholder that read as
## a cartoon daisy -- and `assets/Level1/hidden_flower.png` is the sampaguita it was standing
## in for. The two states it has to carry are the same two as before and neither needs a
## second drawing: UNREVEALED it is the same sprite drained to a cold silhouette, because a
## flower in an unlit cave is a shape you can make out and not a thing you can pick; revealed
## it is the picture, lit, with a warm halo under it.

signal collected(collectible_id: String)

const ART: Texture2D = preload("res://assets/Level1/hidden_flower.png")
## Its own size, and the point in it the bob and the glow are measured from.
const ART_SIZE := Vector2(59.0, 56.0)
## Unrevealed: the sprite multiplied down to a cold blue-grey. Kept as a MODULATE rather
## than a second sprite so the two states cannot drift apart when the art is re-exported.
const UNLIT := Color(0.30, 0.32, 0.40, 0.62)

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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26.0
	collision.shape = circle
	add_child(collision)
	body_entered.connect(_on_body_entered)
	z_index = 8
	refresh_for_run()


## WHETHER THE LEVEL STILL HAS ONE, asked of the RUN and not of the profile -- the same fix
## Ang Bale's canvas needed, and for the same reason. `is_collectible_found` is permanent by
## design, so once anybody had picked this flower it was gone from EVERY later run: the one
## optional thing in Payyo simply was not in the world any more, and the gate in front of it
## opened onto nothing.
##
## ⚠ CALLED AGAIN BY THE LEVEL, not only from _ready. A child's _ready runs BEFORE its
## parent's, and GameLevel joins the run-state group in its own -- so at the moment this node
## is built there is nothing to ask yet, and the profile fallback answers "already taken".
## GameLevel calls this once it is findable.
func refresh_for_run() -> void:
	var run := get_tree().get_first_node_in_group(&"level_run_state")
	if run != null and run.has_method("pickup_taken_this_run"):
		_taken = bool(run.call("pickup_taken_this_run", collectible_id))
	else:
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
	# WHOLE PIXELS OF BOB. The lift used to be a raw sine read straight into a position,
	# which slid a 59px sprite across the pixel grid and shimmered every edge on it. Rounded,
	# it reads as a thing floating and drawn by hand.
	var lift := roundf(sin(TAU * _phase) * 3.0)
	var at := Vector2(-ART_SIZE.x * 0.5, -ART_SIZE.y * 0.5 + lift)
	if _revealed:
		# The halo, under the flower rather than over it, so it lights the sprite instead of
		# washing it out. Two rings, because one hard circle reads as a coin.
		draw_circle(Vector2(0.0, lift), 34.0, Color(1.0, 0.86, 0.5, 0.10))
		draw_circle(Vector2(0.0, lift), 22.0, Color(1.0, 0.90, 0.6, 0.13))
	draw_texture_rect(ART, Rect2(at, ART_SIZE), false,
		Color.WHITE if _revealed else UNLIT)


func _on_body_entered(body: Node) -> void:
	if _taken or not _revealed or not _is_player(body):
		return
	_taken = true
	var profile := get_node_or_null(^"/root/PlayerProfile")
	if profile != null:
		profile.call("record_collectible", collectible_id)
	var run := get_tree().get_first_node_in_group(&"level_run_state")
	if run != null and run.has_method("note_pickup_taken"):
		run.call("note_pickup_taken", collectible_id)
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
