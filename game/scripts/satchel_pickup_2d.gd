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
##
## AND ITS NAME, AS SHE COMES NEAR. A white heap at her feet in the dark said nothing about what
## it was or that it could be taken (Kent: "no clear instructions"): within TAG_NEAR its name
## rises over it on a soft tag, drawn over the dark so it reads past the glow. The level that owns
## the satchel says what it is called (`title`); with no title there is no tag.

signal touched(pickup: SatchelPickup2D)

const ICONS := "res://assets/Level4/props/"
const REACH := 26.0
const BOB := 3.0
const BOB_HZ := 0.7
const GLOW_RADIUS := 52.0
const GLOW_STRENGTH := 0.55
const TAKE_SECONDS := 0.3
## How near she comes, in px, before its name shows; how high over it the tag stands; how fast
## the tag fades in or out (a share of full per second).
const TAG_NEAR := 300.0
const TAG_RISE := 62.0
const TAG_FADE := 5.0
const TAG_FONT := UISkin.FONT_CAPTION
const TAG_PAD := Vector2(10.0, 5.0)

@export var item := "asin"
@export var amount := 1
@export var pickup_id := ""
## What the tag over it says, e.g. "Asin · salt". Set by the level when it wires the pickup.
@export var title := ""

var _art: Sprite2D
var _clock := 0.0
var _taken := false
## The name tag: its own world-following layer over the dark (DarknessLayer is 3, the HUD 5).
var _tag: Node2D
var _tag_alpha := 0.0


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
	var layer := CanvasLayer.new()
	layer.layer = DarknessLayer.LAYER + 1
	layer.follow_viewport_enabled = true
	add_child(layer)
	_tag = Node2D.new()
	_tag.visible = false
	layer.add_child(_tag)
	_tag.draw.connect(_draw_tag)


func _process(delta: float) -> void:
	_clock += delta
	if _art != null and not _taken:
		_art.position.y = sin(_clock * TAU * BOB_HZ) * BOB
	var want := 1.0 if tag_wanted() else 0.0
	if _tag_alpha != want:
		_tag_alpha = move_toward(_tag_alpha, want, delta * TAG_FADE)
		_tag.visible = _tag_alpha > 0.0
		_tag.modulate.a = _tag_alpha
	if _tag.visible:
		_tag.position = (global_position + Vector2(0.0, -TAG_RISE)).round()
		_tag.queue_redraw()


## Whether its name should be showing: it has one, it is still lying there, and she is near.
func tag_wanted() -> bool:
	if title.is_empty() or _taken:
		return false
	var her := get_tree().get_first_node_in_group(PlayerHurtbox2D.GROUP) as Node2D
	return her != null and her.global_position.distance_to(global_position) <= TAG_NEAR


## How shown its name is, 0 to 1, for a probe.
func tag_shown() -> float:
	return _tag_alpha if _tag != null and _tag.visible else 0.0


func _draw_tag() -> void:
	var theme := ThemeDB.get_project_theme()
	var font: Font = theme.default_font if theme != null and theme.default_font != null else ThemeDB.fallback_font
	var text_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT)
	var box := Rect2(Vector2(-text_size.x * 0.5, -text_size.y) - TAG_PAD, text_size + TAG_PAD * 2.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UISkin.PANEL, 0.88)
	style.border_color = UISkin.GOLD
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.anti_aliasing = true
	_tag.draw_style_box(style, box)
	_tag.draw_string(font, Vector2(-text_size.x * 0.5, -text_size.y + font.get_ascent(TAG_FONT)),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT, UISkin.CREAM_TEXT)


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
	_tag_alpha = 0.0
	_tag.visible = false
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
