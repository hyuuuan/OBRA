class_name CollapsingPlatform2D
extends StaticBody2D
## The escape the Protector route buys (Game Design, Level 1, Choice 3): the felled
## tree gets you across, and then the ledge you land on starts going. Standing still
## is the failure state, which is what makes it an escape rather than a corridor.
##
## It does not kill. Level 1 is the tutorial and its mechanic focus is getting
## comfortable with the drawing interface -- dropping the player into the gorge is a
## setback that costs them the climb back, not a death.

signal collapsed()

@export var platform_size := Vector2(220.0, 40.0)
## Grace between the first footfall and the fall, so the player can read the shake and
## keep running.
@export var delay_before_fall: float = 0.85
@export var shake_pixels: float = 3.0

var _triggered := false
var _shake_phase: float = 0.0
var _base_position := Vector2.ZERO


func _ready() -> void:
	add_to_group(&"collapsing_platforms")
	_base_position = position
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = platform_size
	collision.shape = box
	add_child(collision)
	# The trigger is its own area rather than contact monitoring, because a StaticBody2D
	# has no contacts to report -- it is the thing being stood on, not the thing moving.
	var sensor := Area2D.new()
	sensor.name = "Footfall"
	sensor.collision_layer = 0
	sensor.collision_mask = 1
	var sensor_collision := CollisionShape2D.new()
	var sensor_box := RectangleShape2D.new()
	sensor_box.size = Vector2(platform_size.x, 26.0)
	sensor_collision.shape = sensor_box
	sensor_collision.position = Vector2(0.0, -platform_size.y * 0.5 - 13.0)
	sensor.add_child(sensor_collision)
	add_child(sensor)
	sensor.body_entered.connect(_on_stepped_on)
	z_index = 6
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-platform_size * 0.5, platform_size)
	draw_rect(rect, Color(0.44, 0.38, 0.29))
	draw_rect(rect, Color(0.16, 0.13, 0.1), false, 3.0)
	# Cracks, so it looks like it was going to give way before it did.
	for step in range(1, 4):
		var x := rect.position.x + platform_size.x * float(step) / 4.0
		draw_line(Vector2(x, rect.position.y + 4.0), Vector2(x - 7.0, rect.end.y - 4.0),
			Color(0.2, 0.16, 0.12), 2.0)


func _process(delta: float) -> void:
	if not _triggered:
		return
	_shake_phase += delta * 42.0
	position = _base_position + Vector2(sin(_shake_phase) * shake_pixels, 0.0)


func _on_stepped_on(body: Node) -> void:
	if _triggered or not _is_player(body):
		return
	_triggered = true
	set_process(true)
	await get_tree().create_timer(delay_before_fall).timeout
	if not is_inside_tree():
		return
	collapsed.emit()
	var drop := create_tween()
	drop.set_parallel(true)
	drop.tween_property(self, "position:y", _base_position.y + 640.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(self, "rotation", 0.5, 0.9)
	drop.tween_property(self, "modulate:a", 0.0, 0.9)
	set_deferred(&"collision_layer", 0)
	drop.chain().tween_callback(queue_free)


func _is_player(body: Node) -> bool:
	var node := body
	while node != null:
		if node.is_in_group(&"player_character") or node is ActiveRagdollMorph:
			return true
		node = node.get_parent()
	return false
