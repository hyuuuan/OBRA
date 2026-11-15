class_name Bulul2D
extends Node2D
## A bulul, and the strictest rule in the level.
##
## ZERO COLLISION. ZERO INTERACTION. ZERO PUZZLE FUNCTION. It cannot be climbed, pushed,
## picked up, chopped, drawn on, or required by anything. It is the most carefully rendered
## thing in the attic and it does nothing, on purpose.
##
## A bulul is a rice-granary guardian figure, carved and kept by a family, and treating one
## as a collectible or a lever is the exact failure this project has to avoid. The build
## spec lists it under cultural guardrails as non-negotiable, so the constraint is written
## here as code -- no collision shape is ever built -- and asserted in run_level1_audit
## rather than left to whoever edits the scene next.
##
## The only thing it does is make Lolo speak, once, if the player stays close: "Do not.
## Those are not decoration, and they are not yours." That is a refusal, not a hint, and it
## unlocks nothing.

signal approached()

## How near the player has to stay before Lolo says anything. See LINGER.
@export var notice_radius := 96.0

var _spoken := false
var _sensor: Area2D


func _ready() -> void:
	add_to_group(&"bulul")
	set_physics_process(false)
	_build_figure()
	_build_sensor()


func has_spoken() -> bool:
	return _spoken


## For the audit: a bulul that has grown a collision shape has stopped being a bulul.
func has_collision() -> bool:
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			return true
		if child is PhysicsBody2D:
			return true
	return false


func _build_figure() -> void:
	# Seated, arms on knees, the posture these are carved in. Rendered in flat shapes
	# rather than from the terrain atlas: it is wood a person carved, not scenery.
	var wood := Color(0.36, 0.24, 0.15)
	var lit := Color(0.47, 0.32, 0.2)

	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(-11.0, 0.0), Vector2(-13.0, -26.0), Vector2(-8.0, -34.0),
		Vector2(8.0, -34.0), Vector2(13.0, -26.0), Vector2(11.0, 0.0),
	])
	body.color = wood
	add_child(body)

	var head := Polygon2D.new()
	head.name = "Head"
	head.polygon = PackedVector2Array([
		Vector2(-7.0, -34.0), Vector2(-8.0, -46.0), Vector2(-4.0, -51.0),
		Vector2(4.0, -51.0), Vector2(8.0, -46.0), Vector2(7.0, -34.0),
	])
	head.color = lit
	add_child(head)

	for side in [-1.0, 1.0]:
		var arm := Polygon2D.new()
		arm.polygon = PackedVector2Array([
			Vector2(side * 9.0, -30.0), Vector2(side * 15.0, -28.0),
			Vector2(side * 15.0, -8.0), Vector2(side * 9.0, -10.0),
		])
		arm.color = wood
		add_child(arm)

	var base := Polygon2D.new()
	base.name = "Base"
	base.polygon = PackedVector2Array([
		Vector2(-15.0, 0.0), Vector2(-15.0, -6.0), Vector2(15.0, -6.0), Vector2(15.0, 0.0),
	])
	base.color = Color(0.28, 0.19, 0.12)
	add_child(base)


## An Area2D, which is NOT interaction: it never reports to the level, never satisfies an
## obstacle, and cannot be triggered by anything the player draws. It notices a person
## standing nearby so that a line can be said.
func _build_sensor() -> void:
	_sensor = Area2D.new()
	_sensor.name = "NoticeArea"
	_sensor.collision_layer = 0
	_sensor.collision_mask = 1
	_sensor.monitoring = true
	add_child(_sensor)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = notice_radius
	shape.shape = circle
	shape.position = Vector2(0.0, -26.0)
	_sensor.add_child(shape)
	_sensor.body_entered.connect(_on_body_entered)


## ⚠ LINGERING, NOT PASSING. The line is Lolo telling her not to touch, and it fired on anybody
## walking up to the house: "Do not." with her hands at her sides, on top of his first words
## about the house, which took the advice off the bar a third of a second after it went up.
const LINGER := 1.2
var _someone_near := 0.0


func _on_body_entered(body: Node) -> void:
	if _spoken or not _is_a_person(body):
		return
	set_physics_process(true)


func _is_a_person(body: Node) -> bool:
	var node := body as Node
	while node != null:
		if node.is_in_group(&"player_character"):
			return true
		node = node.get_parent()
	return false


func _physics_process(delta: float) -> void:
	var near := false
	for body in _sensor.get_overlapping_bodies():
		if _is_a_person(body):
			near = true
			break
	if not near:
		_someone_near = 0.0
		set_physics_process(false)
		return
	_someone_near += delta
	if _someone_near >= LINGER:
		_spoken = true
		set_physics_process(false)
		approached.emit()
