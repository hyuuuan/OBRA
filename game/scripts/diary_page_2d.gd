class_name DiaryPage2D
extends Node2D
## A loose page of Lola's diary, lying in a level: walk into it to find it (DIARY.md).
##
## LevelBase lays every one out (`_lay_out_diary_pages`): one this save already holds is not
## there, and walking into the rest calls `find_diary_page`, which keeps the page and opens the
## book at it. A level only places the page and says which it is.
##
## ⚠ FOUND BY DISTANCE, NOT BY AN AREA. Dilim's satchel things look for her hurtbox, and only
## Dilim has one (it is her health): in Piyesta a page that waited for a hurtbox was walked over
## and never found. So LevelBase tells each page where she is every physics frame (`notice`),
## from her body's anchor, which is wherever she is -- the apo or anything she has become.
##
## Named the way the satchel things are, a tag rising over it as she comes near
## (SatchelPickup2D.draw_name_tag): a scrap of paper on a busy floor says nothing by itself.
##
## ⚠ NOT A LIGHT. Satchel things glow in Dilim's dark by joining LightField.GROUP, and Dilim counts
## every member of that group as light she made (`_drawn_light`). A page left near a creature would
## have answered it.


const GROUP := &"diary_pages"
const ART := preload("res://assets/hud/diary_page.png")
## Two of its pixels to one of the world's: at the rooms' zoom it is a page, not a crumb.
const SCALE := 2
## How near her anchor (about her middle) comes before it is found: standing over it, from the
## ground or a step above.
const REACH := 60.0
const BOB := 2.0
const BOB_HZ := 0.6
const TAKE_SECONDS := 0.3
const TAG_NEAR := 300.0
const TAG_RISE := 70.0
const TAG_FADE := 5.0
const TITLE := "A page of her diary"

## Which entry of config/diary.json this is.
@export var entry_id := ""
## How near she comes before it is found. A page she must not miss -- Dilim's bestiary, which
## the woods' creatures open at -- is given more than a jump's height, so it cannot be hopped over.
@export var reach := REACH
## Set down where the level has no floor plan to read a height off (Dilim's woods): on the first
## physics frame it drops onto the ground beneath it.
@export var settles := false

var _art: Sprite2D
var _clock := 0.0
var _taken := false
var _tag: Node2D
var _tag_alpha := 0.0
## How far she was when last noticed; INF before then.
var _her_distance := INF


func _ready() -> void:
	add_to_group(GROUP)
	_art = Sprite2D.new()
	_art.name = "Page"
	_art.texture = ART
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.scale = Vector2.ONE * SCALE
	# Lying on the floor at its feet, a little askew, as a dropped page lies.
	_art.offset = Vector2(0.0, -ART.get_height() * 0.5)
	_art.rotation = -0.12
	add_child(_art)
	z_index = 4
	var layer := CanvasLayer.new()
	layer.layer = DarknessLayer.LAYER + 1
	layer.follow_viewport_enabled = true
	add_child(layer)
	_tag = Node2D.new()
	_tag.visible = false
	layer.add_child(_tag)
	_tag.draw.connect(func() -> void: SatchelPickup2D.draw_name_tag(_tag, TITLE))
	if settles:
		_settle.call_deferred()


## Down onto whatever world is under it, within SETTLE_DEPTH. A physics frame first: a ray cast
## before the space has its bodies finds nothing.
const SETTLE_DEPTH := 800.0


func _settle() -> void:
	await get_tree().physics_frame
	var from := global_position + Vector2(0.0, -SETTLE_DEPTH * 0.25)
	var ray := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, SETTLE_DEPTH),
		PhysicsLayers.WORLD)
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		global_position = (hit["position"] as Vector2).round()


func _process(delta: float) -> void:
	_clock += delta
	if not _taken:
		# Whole pixels: a page that drifts by fractions shimmers at the pixel idiom's zoom.
		_art.position.y = roundf(sin(_clock * TAU * BOB_HZ) * BOB)
	var want := 1.0 if tag_wanted() else 0.0
	if _tag_alpha != want:
		_tag_alpha = move_toward(_tag_alpha, want, delta * TAG_FADE)
		_tag.visible = _tag_alpha > 0.0
		_tag.modulate.a = _tag_alpha
	if _tag.visible:
		_tag.position = (global_position + Vector2(0.0, -TAG_RISE)).round()
		_tag.queue_redraw()


## Where she is now. True when she is standing over it and it is still lying there: found.
func notice(at: Vector2) -> bool:
	_her_distance = at.distance_to(global_position)
	return not _taken and _her_distance <= reach


func tag_wanted() -> bool:
	return not _taken and _her_distance <= TAG_NEAR


func is_taken() -> bool:
	return _taken


## Picked up: it lifts, fades, and is freed.
func take() -> void:
	if _taken:
		return
	_taken = true
	_tag_alpha = 0.0
	_tag.visible = false
	# It goes as the book opens over it, which pauses the tree: a lift bound to the pause would
	# hang in the air behind the book and only finish once it is put down.
	var lift := create_tween()
	lift.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	lift.tween_property(self, "position:y", position.y - 24.0, TAKE_SECONDS)
	lift.parallel().tween_property(self, "modulate:a", 0.0, TAKE_SECONDS)
	lift.tween_callback(queue_free)

