class_name IfugaoGuardian2D
extends Node2D
## The Ifugao guardian at Ang Bale: an elder woman who keeps Lola's house in the painting, and
## the one person in Payyo besides Lolo and the apo.
##
## SHE REPLACED THE BULUL (cultural panel, Chapter 5 Table 34). The two carved figures in front
## of the house were rendered with care and said nothing about it; the panel asked for more of
## everyday Ifugao life, so the house now has someone who lives by it and tells the apo how a
## bale is built -- the posts, the rat guards, the roof the rice is kept under.
##
## She keeps the bulul's rule, which is the level's strictest: ZERO COLLISION, ZERO INTERACTION,
## ZERO PUZZLE FUNCTION. She cannot be climbed, pushed, picked up, cut or drawn on, she opens
## nothing and no route needs her, and nothing she says is a hint (run_level1_audit). A person
## at her own house is not a lever. The only thing she does is speak, once, to somebody who
## stays near her.
##
## The art is a stand-in repainted from Lola's sheet by tools/build_payyo_guardian.py
## (ART_PLACEHOLDERS.md).

signal approached()

const ART := preload("res://assets/Level1/people/guardian.png")
## Where her feet are on the 128 x 144 cell: the bottom row, as Lola's are.
const FOOT_ROW := 144.0

## How near the player has to stay before she speaks. See LINGER.
@export var notice_radius := 96.0

var _spoken := false
var _sensor: Area2D


func _ready() -> void:
	add_to_group(&"bale_guardian")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_physics_process(false)
	var figure := Sprite2D.new()
	figure.name = "Figure"
	figure.texture = ART
	figure.centered = false
	figure.offset = Vector2(-roundf(ART.get_width() * 0.5), -FOOT_ROW)
	add_child(figure)
	_build_sensor()


func has_spoken() -> bool:
	return _spoken


## For the audit: a guardian with a collision shape has become something to stand on.
func has_collision() -> bool:
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D or child is PhysicsBody2D:
			return true
	return false


## Where the camera looks while she talks: her face, not her feet.
func speaking_point() -> Vector2:
	return global_position + Vector2(0.0, -FOOT_ROW * 0.6)


## An Area2D, which is NOT interaction: it never reports to the level director, never satisfies
## an obstacle, and nothing drawn can trigger it. It notices a person standing nearby.
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
	shape.position = Vector2(0.0, -40.0)
	_sensor.add_child(shape)
	_sensor.body_entered.connect(_on_body_entered)


## ⚠ LINGERING, NOT PASSING (the bulul's lesson). Walking up to the house fires Lolo's first
## words about it; a second voice on top of those took his advice off the bar a third of a
## second after it went up. She speaks to somebody who stays.
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
