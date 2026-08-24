class_name DeadTree2D
extends Destructible2D
## The Protector route's answer to the gorge (Game Design, Level 1, Choice 3): a huge
## dead tree at the chasm lip that a drawn edge fells INTO a crossing. The tree is the
## bridge -- chopping it is not clearing an obstacle, it is building the path.
##
## It IS the Destructible2D and owns its bodies as children, because that is the shape
## a tool can find: UtilityObject resolves a collider to the nearest ANCESTOR that
## answers apply_tool_hit, so a Destructible2D hung UNDER a body would never be hit no
## matter how hard the axe swung.

signal felled()

const ART := preload("res://assets/Level1/props/dead_tree.png")
## The trunk is columns 10..21 of the art; everything either side is bare branches. The
## sprite is hung off the middle of THOSE, not the middle of the picture, so the collision
## box and the wood the axe is aimed at are the same column.
const TRUNK_CENTRE := 15.5

@export var trunk_size := Vector2(54.0, 300.0)
## How far the fallen trunk reaches across the gorge. It lands to the right, which is
## the way the player is travelling.
@export var span_length: float = 460.0
@export var blocked_hint: String = "That dead tree would reach across. Draw something with an edge — E to pick it up, F to swing."

var _standing: StaticBody2D
var _fallen: StaticBody2D
var _art: Sprite2D
var _initial_health: float = 100.0
var _is_felled := false


func _ready() -> void:
	add_to_group(&"drawing_gates")
	_initial_health = maxf(1.0, health)
	_build()
	destroyed.connect(_on_destroyed)
	damaged.connect(_on_damaged)


func gate_hint() -> String:
	return blocked_hint


func is_open() -> bool:
	return _is_felled


func _build() -> void:
	_standing = StaticBody2D.new()
	_standing.name = "Trunk"
	add_child(_standing)
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = trunk_size
	collision.shape = box
	collision.position = Vector2(0.0, -trunk_size.y * 0.5)
	_standing.add_child(collision)

	# Hung off the trunk body rather than off this node, so the lean every axe hit adds
	# moves the tree and not just its collider.
	_art = Sprite2D.new()
	_art.name = "Art"
	_art.texture = ART
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.centered = false
	# Whole multiples only. 300/58 is 5.17, and the sixth of a pixel that buys is paid for
	# with a resampled trunk -- five is 290px of tree against a 300px box, which nobody can
	# see, and every pixel stays square.
	var factor := maxf(1.0, roundf(trunk_size.y / float(ART.get_height())))
	_art.scale = Vector2(factor, factor)
	_art.offset = Vector2(-TRUNK_CENTRE, -float(ART.get_height()))
	_standing.add_child(_art)

	# The crossing it becomes, built now and kept intangible until it is earned. Making
	# it up front means the felled trunk lands on a surface that is already the right
	# shape, rather than one assembled a frame later under the player's feet.
	_fallen = StaticBody2D.new()
	_fallen.name = "FallenSpan"
	_fallen.collision_layer = 0
	_fallen.collision_mask = 0
	add_child(_fallen)
	var span_collision := CollisionShape2D.new()
	var span_box := RectangleShape2D.new()
	span_box.size = Vector2(span_length, 34.0)
	span_collision.shape = span_box
	span_collision.position = Vector2(span_length * 0.5, -17.0)
	_fallen.add_child(span_collision)
	z_index = 6


## Every hit leans it further toward the gorge, so a swing that did not finish the job
## still visibly moved it.
func _on_damaged(remaining: float, _impulse: float) -> void:
	var progress := 1.0 - clampf(remaining / _initial_health, 0.0, 1.0)
	var lean := progress * 0.22
	if _standing == null or not is_instance_valid(_standing):
		return
	var shake := create_tween()
	shake.tween_property(_standing, "rotation", lean, 0.09)
	shake.tween_property(_standing, "rotation", lean * 0.55, 0.13)


func _on_destroyed() -> void:
	if _is_felled:
		return
	_is_felled = true
	# THE SAME TREE LIES THERE. It is taken off the trunk body before that is freed and
	# turned a quarter clockwise, so what the player walks across is the thing they were
	# just looking at rather than a plank that appeared where it used to be.
	#
	# A quarter turn CLOCKWISE, not anticlockwise: rotating by +PI/2 sends the art's own
	# up-axis to +x, which is the way the gorge runs and the way the player is travelling.
	# The other direction lays it back across the ground they came from.
	if _art != null and is_instance_valid(_art):
		_art.reparent(self, false)
		_art.rotation = PI * 0.5
		_art.position = Vector2(0.0, -17.0)
	if _standing != null and is_instance_valid(_standing):
		_standing.queue_free()
	_fallen.collision_layer = 1
	_fallen.collision_mask = 1
	felled.emit()
