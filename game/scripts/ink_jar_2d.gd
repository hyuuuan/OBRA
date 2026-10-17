class_name InkJar2D
extends Area2D
## A jar of ink left on the way: walk into it and some ink comes back (Kent's design -- "Ink is the
## real difficulty curve of this level"; level_04.json's ink_economy puts one before each encounter
## that can only be passed by drawing).
##
## Found by her hurtbox, so taken by whoever she is; the level gives the ink (touched). One placed in
## the level carries a `pickup_id`, so a run that took it does not find it again. It glows faintly --
## a thing worth finding in a dark wood is a thing that can be seen. Dagat's jar, for now.

signal touched(jar: InkJar2D)

const ART := preload("res://assets/Level3/authored/ink_jar_0.png")
const REACH := 28.0
const GLOW_RADIUS := 56.0
const TAKE_SECONDS := 0.3

@export var amount := 2.0
@export var pickup_id := ""

var _taken := false


func _ready() -> void:
	add_to_group(LightField.GROUP)
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER_HURTBOX
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = REACH
	shape.shape = circle
	add_child(shape)
	var art := Sprite2D.new()
	art.texture = ART
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.offset = Vector2(0.0, -ART.get_height() * 0.5)
	art.scale = Vector2.ONE * 0.6
	add_child(art)
	z_index = 4
	area_entered.connect(func(area: Area2D) -> void:
		if not _taken and area is PlayerHurtbox2D:
			touched.emit(self))


func is_taken() -> bool:
	return _taken


func light_hole() -> Dictionary:
	if _taken:
		return {}
	return {"position": global_position + Vector2(0.0, -20.0), "radius": GLOW_RADIUS, "strength": 0.5}


func take() -> void:
	if _taken:
		return
	_taken = true
	set_deferred(&"monitoring", false)
	var lift := create_tween()
	lift.tween_property(self, "modulate:a", 0.0, TAKE_SECONDS)
	lift.tween_callback(queue_free)
