class_name FiestaTable2D
extends Node2D
## Fiesta food in the plaza: one long table on the way to the church, and Lolo says what is on it.
##
## The cultural panel asked for more of everyday Filipino life, food first (Chapter 5, Table 34).
## On a fiesta every house in a Cebu town opens its table, so the plaza has one: puso hung in a
## bunch, bibingka, adobo in a clay pot, pancit and mangoes (tools/build_fiesta_table.py). Stay by
## it and Lolo says "Kaon ta!" -- let's eat, in Cebuano -- and names them (`L2_PLAZA.food`).
##
## ⚠ SCENERY, NOT A SOURCE OF ANYTHING. Not to be confused with the scrap ASSEMBLY table
## (ScrapAssembly), which is a different thing. Nothing on this one can be taken, eaten, thrown
## or fed to the flock in the alleys -- the "feed" beat there wants a drawing -- so it has no
## collision and no interaction, the plaza's next puzzle is never answered by it, and nothing on
## it is one of the fifty classes (no lechon, no bread: see the tool). run_level2_audit holds it.

signal approached()

const ART := preload("res://assets/Level2/plaza/fiesta_table.png")

@export var notice_radius := 110.0
## Long enough that walking past to the church says nothing; a person who stops to look is told.
const LINGER := 0.8

var _spoken := false
var _someone_near := 0.0
var _sensor: Area2D


func _ready() -> void:
	add_to_group(&"fiesta_table")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_physics_process(false)
	var picture := Sprite2D.new()
	picture.name = "Picture"
	picture.texture = ART
	picture.centered = false
	# Feet of the legs on the plaza paving: the bottom row is the floor.
	picture.offset = Vector2(-roundf(ART.get_width() * 0.5), -ART.get_height())
	add_child(picture)
	_sensor = Area2D.new()
	_sensor.name = "NoticeArea"
	_sensor.collision_layer = 0
	_sensor.collision_mask = 1
	add_child(_sensor)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = notice_radius
	shape.shape = circle
	shape.position = Vector2(0.0, -40.0)
	_sensor.add_child(shape)
	_sensor.body_entered.connect(func(body: Node) -> void:
		if not _spoken and _is_a_person(body):
			set_physics_process(true))


func has_spoken() -> bool:
	return _spoken


## Ready to be told about again: the level asked too early (before the plaza was introduced).
func forget_telling() -> void:
	_spoken = false
	_someone_near = 0.0


## For the audit: a table of food with a collision shape has become something to stand on.
func has_collision() -> bool:
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D or child is PhysicsBody2D:
			return true
	return false


func _is_a_person(body: Node) -> bool:
	var node := body
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
