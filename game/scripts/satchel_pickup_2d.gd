class_name SatchelPickup2D
extends Area2D
## One of Lola's things lying in the woods, or dropped by a fallen aswang: walk into it to take it.
##
## It finds her hurtbox, not her body, so it is taken by whoever she is. The level decides what
## taking means (touched): into the satchel if there is room -- and if there is not, it stays where
## it is, for later. A thing placed in the level carries a `pickup_id`, so a run that has taken it
## does not find it again; a drop has none.
##
## A faint glow of its own: a thing worth picking up in a dark wood is a thing that can be seen.

signal touched(pickup: SatchelPickup2D)

const ICONS := "res://assets/Level4/props/"
const REACH := 26.0
const BOB := 3.0
const BOB_HZ := 0.7
const GLOW_RADIUS := 52.0
const GLOW_STRENGTH := 0.55
const TAKE_SECONDS := 0.3

@export var item := "asin"
@export var amount := 1
@export var pickup_id := ""

var _art: Sprite2D
var _clock := 0.0
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
	_art = Sprite2D.new()
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var path := ICONS + item + ".png"
	_art.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_art.offset = Vector2(0.0, -16.0)
	add_child(_art)
	z_index = 4
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	_clock += delta
	if _art != null and not _taken:
		_art.position.y = sin(_clock * TAU * BOB_HZ) * BOB


func is_taken() -> bool:
	return _taken


func light_hole() -> Dictionary:
	if _taken:
		return {}
	return {"position": global_position + Vector2(0.0, -16.0), "radius": GLOW_RADIUS,
		"strength": GLOW_STRENGTH}


## Gone into the satchel: it lifts, fades, and is freed.
func take() -> void:
	if _taken:
		return
	_taken = true
	set_deferred(&"monitoring", false)
	var lift := create_tween()
	lift.tween_property(self, "position:y", position.y - 24.0, TAKE_SECONDS)
	lift.parallel().tween_property(self, "modulate:a", 0.0, TAKE_SECONDS)
	lift.tween_callback(queue_free)


## Asked again after it was left -- the satchel had no room then, and may now.
func offer_again() -> void:
	for area in get_overlapping_areas():
		_on_area_entered(area)


func _on_area_entered(area: Area2D) -> void:
	if not _taken and area is PlayerHurtbox2D:
		touched.emit(self)
