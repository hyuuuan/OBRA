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

@export var trunk_size := Vector2(54.0, 300.0)
## How far the fallen trunk reaches across the gorge. It lands to the right, which is
## the way the player is travelling.
@export var span_length: float = 460.0
@export var blocked_hint: String = "That dead tree would reach across. Draw something with an edge — E to pick it up, F to swing."

var _standing: StaticBody2D
var _fallen: StaticBody2D
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
	queue_redraw()


func _draw() -> void:
	if _is_felled:
		_draw_span()
		return
	var half := trunk_size.x * 0.5
	var top := -trunk_size.y
	draw_rect(Rect2(Vector2(-half, top), trunk_size), Color(0.32, 0.24, 0.18))
	draw_rect(Rect2(Vector2(-half, top), trunk_size), Color(0.13, 0.09, 0.06), false, 4.0)
	# Bare branches, so it reads as dead rather than as a post.
	for branch in [
		[-half, top + 40.0, -46.0, -34.0],
		[half, top + 74.0, 52.0, -28.0],
		[-half, top + 120.0, -38.0, 24.0],
	]:
		var start := Vector2(branch[0], branch[1])
		draw_line(start, start + Vector2(branch[2], branch[3]), Color(0.24, 0.18, 0.13), 7.0, true)
	# Grain, which is also where the axe bites.
	for offset in [-12.0, 4.0, 16.0]:
		draw_line(Vector2(offset, top + 20.0), Vector2(offset, -14.0), Color(0.22, 0.16, 0.11), 2.5)


func _draw_span() -> void:
	var span := Rect2(Vector2(0.0, -34.0), Vector2(span_length, 34.0))
	draw_rect(span, Color(0.32, 0.24, 0.18))
	draw_rect(span, Color(0.13, 0.09, 0.06), false, 4.0)
	for step in range(1, 9):
		var x := span_length * float(step) / 9.0
		draw_line(Vector2(x, -32.0), Vector2(x, -2.0), Color(0.22, 0.16, 0.11), 2.5)


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
	if _standing != null and is_instance_valid(_standing):
		_standing.queue_free()
	_fallen.collision_layer = 1
	_fallen.collision_mask = 1
	queue_redraw()
	felled.emit()
