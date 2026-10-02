class_name Painting2D
extends Area2D
## One of Lola's paintings, hanging in the house, and the way into the level it is of.
##
## THE LEVEL SELECT IS A ROOM, not a menu. Every level in this game is somewhere Lola
## painted, so the place you choose one from is her house, and what you choose is the
## picture. A grid of cards with the same five images on it would say the same thing and
## mean none of it.
##
## A LOCKED PAINTING IS STILL A PAINTING. It hangs, it is lit, you can walk up to it and
## read its name -- it simply is not finished being a place you can go yet. Hiding the four
## that are not built would leave one picture on a long wall and no sense of what the game
## is; greying them out would say "disabled button". They are dimmed the way a picture in a
## dark corner is dimmed, and the plate underneath says so in words.

signal chosen(level_id: String)

## Which level this is a painting of. The catalog is asked about it rather than the node
## carrying its own copy of the title -- one list of levels, in config/levels.json.
@export var level_id: String = ""
## The painting, at the size it hangs. Set by the room from the level id.
@export var art: Texture2D
## What the little brass plate under it says.
@export var plate_text: String = ""
## How wide the gilt moulding is around the picture. Eight, against a picture 128 wide: a
## frame is a hand's breadth of gold round the edge of a canvas, not a border round it.
@export var moulding: float = 8.0
## How far ALONG THE WALL the apo has to be standing for this painting to answer.
##
## Horizontal only, because you stand under a picture to look at it, not next to it. Judged
## as a straight distance to the painting's middle -- which is what it was first -- the apo
## is a room's height below it at all times and no painting ever answers.
##
## Under half the gap between two pictures, so that standing at one never reaches the next.
## run_hub_audit asserts exactly that, from where the apo actually stands.
@export var reach: float = 110.0

var _playable := false
var _art_size := Vector2(128.0, 72.0)
var _plate: Label

## LOCKED IS A STATE OF ITS OWN, AND IT LOOKS IT. Kent, of finishing Payyo: back to the house,
## and "there should be an animation wherein the level gets unlocked". There was nothing to
## animate from -- a painting that was built and not yet reached hung exactly as an open one
## did, and only a refusal on E said otherwise. It hangs dimmed now, with a padlock on the
## frame and LOCKED on its plate, and the house plays `reveal` on the one a level has opened.
var _locked := false
## How lit the picture is, 0 dimmed to 1 full colour. Driven by `reveal`.
var _light := 1.0:
	set(value):
		_light = value
		queue_redraw()
## The padlock: how much of it shows, how far it has fallen, and how hard it is shaking.
var _lock_alpha := 0.0:
	set(value):
		_lock_alpha = value
		queue_redraw()
var _lock_drop := 0.0:
	set(value):
		_lock_drop = value
		queue_redraw()
var _lock_shake := 0.0:
	set(value):
		_lock_shake = value
		queue_redraw()


func _ready() -> void:
	add_to_group(&"paintings")
	monitoring = false
	monitorable = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if art != null:
		_art_size = art.get_size()
	var manager := get_node_or_null(^"/root/LevelManager")
	_playable = manager != null and bool(manager.call("is_playable", level_id))
	_locked = _playable and not bool(manager.call("is_unlocked", level_id))
	_light = 1.0 if _playable and not _locked else 0.0
	_lock_alpha = 1.0 if _locked else 0.0
	# The reach is an Area2D only so the room can find the nearest one cheaply; nothing
	# collides with a painting.
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = _art_size + Vector2.ONE * moulding * 2.0
	shape.shape = box
	add_child(shape)
	_build_plate()
	queue_redraw()


## The little brass plate under the picture, which is where a gallery puts the name and is
## the only place in this room that says a level is not finished yet. Saying it in words
## beats greying the picture out: dimmed art reads as "disabled", a plate reads as a label.
func _build_plate() -> void:
	var plate := Label.new()
	plate.name = "Plate"
	_plate = plate
	_write_plate()
	plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	plate.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	plate.add_theme_constant_override(&"shadow_offset_x", 2)
	plate.add_theme_constant_override(&"shadow_offset_y", 2)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# HALF SIZE, IN A ROOM THE CAMERA DRAWS AT DOUBLE. The plate hangs on the wall, so it is
	# in world space and the hub's zoom of 2 applies to it: at the caption size it came out
	# forty screen pixels tall, which is HUD lettering on a brass plate the size of a hand.
	# Halved, it reads at the size the label under a picture in a gallery reads at -- and it
	# lands back on whole screen pixels, because the caption size is two font units and half
	# of it is one, which is the rule HUD_SKIN.md gives for keeping a pixel face crisp.
	plate.scale = Vector2(0.5, 0.5)
	# IN THE TREE BEFORE IT IS MEASURED, and this is the whole of why the names under the
	# pictures were crooked. A theme override does not reach a Control until it is inside the
	# tree -- Godot fires NOTIFICATION_THEME_CHANGED for one only when there is a tree to be
	# notified through -- so a Label sized out here is measured against the project theme's
	# 30pt rather than the 20 it will actually draw at, Control.set_size clamps up to that
	# minimum and never back down, and a plate positioned by a fixed left offset carries the
	# whole difference sideways. "MAYON  --  NOT YET PAINTED" measures 277px at 20 and 416 at
	# 30, so the name sat 48px right of its own picture, out past the moulding and into the
	# doorway beside it. The text drew at the right size the entire time, which is why this
	# took measuring a screenshot to see at all.
	add_child(plate)
	plate.size = Vector2((_art_size.x + moulding * 4.0) * 2.0, 28.0)
	# Centred on the width it GOT, not the width it asked for -- so a plate string long
	# enough to beat that minimum is still centred, instead of being centred right up until
	# the day somebody renames a level.
	plate.position = Vector2(-plate.size.x * plate.scale.x * 0.5,
		_art_size.y * 0.5 + moulding + 6.0)


## What the plate says, and in what light: the name of an open painting, LOCKED on one that is
## built and not yet reached, NOT YET PAINTED on one that is not built.
func _write_plate() -> void:
	if _plate == null:
		return
	_plate.text = plate_text if _playable and not _locked \
		else ("%s  —  LOCKED" % plate_text if _playable else "%s  —  NOT YET PAINTED" % plate_text)
	_plate.add_theme_color_override(&"font_color",
		UISkin.GILT_HI if _playable and not _locked else UISkin.GILT_DARK)


func is_playable() -> bool:
	return _playable


func is_locked() -> bool:
	return _locked


## Hang it as it was before it was opened, so the house can open it in front of the player.
func show_locked() -> void:
	if not _playable:
		return
	_locked = true
	_light = 0.0
	_lock_alpha = 1.0
	_lock_drop = 0.0
	_lock_shake = 0.0
	_write_plate()


## THE UNLOCK, played where the player can see it: the padlock shakes, lets go and falls, the
## picture comes up out of the dark into its colours with the burst every reward in the game
## uses, its plate takes its name, and UNLOCKED rises off it. Awaitable; about two seconds.
func reveal() -> void:
	if not _locked:
		return
	var run := create_tween()
	run.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	run.tween_property(self, "_lock_shake", 1.0, 0.5)
	run.tween_property(self, "_lock_drop", 1.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	run.parallel().tween_property(self, "_lock_alpha", 0.0, 0.4).set_ease(Tween.EASE_IN)
	run.tween_callback(func() -> void:
		_locked = false
		_write_plate()
		PickupFlourish2D.burst(self, Vector2.ZERO)
		_rise_word())
	run.tween_property(self, "_light", 1.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await run.finished


## UNLOCKED, rising off the picture and going. Half size, like the plate, because the house is
## drawn at double.
func _rise_word() -> void:
	var word := Label.new()
	word.name = "Unlocked"
	word.text = "UNLOCKED"
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	word.add_theme_color_override(&"font_color", UISkin.GILT_HI)
	word.add_theme_constant_override(&"outline_size", 6)
	word.add_theme_color_override(&"font_outline_color", UISkin.INK)
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	word.scale = Vector2(0.5, 0.5)
	add_child(word)
	word.size = Vector2(240.0, 28.0)
	var from := Vector2(-word.size.x * word.scale.x * 0.5, -_art_size.y * 0.5 - 18.0)
	word.position = from
	var rise := word.create_tween()
	rise.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	rise.tween_property(word, "position:y", from.y - 26.0, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rise.parallel().tween_property(word, "modulate:a", 0.0, 0.6).set_delay(0.9)
	rise.tween_callback(word.queue_free)


## How far the apo is from this painting, measured to its middle. The room uses it to pick
## which one the prompt belongs to.
func distance_to_point(point: Vector2) -> float:
	return absf(point.x - global_position.x)


func within_reach(point: Vector2) -> bool:
	return distance_to_point(point) <= reach


## Walked up to and pressed E on.
func choose() -> void:
	chosen.emit(level_id)


func _draw() -> void:
	var half := _art_size * 0.5
	var picture := Rect2(-half, _art_size)
	# The picture first, then the moulding over its edge, so the frame sits on the painting
	# rather than beside it.
	if art != null:
		draw_texture_rect(art, picture, false, Color(0.42, 0.40, 0.44, 1.0).lerp(Color.WHITE, _light))
	else:
		draw_rect(picture, UISkin.PANEL)
	_draw_moulding(picture)
	if _lock_alpha > 0.0:
		_draw_padlock(picture)


## A rectangular gilt moulding, stepped rather than smooth: four bands, lighter on the top
## and left where the light is and darker on the bottom and right, with a keyline round
## both edges. The oval on the canvas is the same gold and the same light; this is its
## square cousin, because a picture frame on a wall is square and a mirror is not.
func _draw_moulding(picture: Rect2) -> void:
	draw_gilt(self, picture, moulding, _light < 0.5)


## A padlock hung on the bottom rail of the frame: an iron body with a brass plate and a
## keyhole, and a shackle over it. Square-cut, to sit with the stepped gilt. It shakes as it is
## undone, then drops and fades.
func _draw_padlock(picture: Rect2) -> void:
	var shake := sin(_lock_shake * TAU * 5.0) * 3.0 * (1.0 - _lock_drop)
	var centre := Vector2(shake, picture.end.y - 4.0 + _lock_drop * 46.0)
	var tilt := _lock_drop * 0.6
	draw_set_transform(centre, tilt, Vector2.ONE)
	var alpha := _lock_alpha
	var iron := Color(0.16, 0.15, 0.17, alpha)
	var brass := Color(UISkin.GILT_LIT, alpha)
	var dark := Color(0.05, 0.05, 0.06, alpha)
	# Shackle: three bars, square, open at the bottom into the body.
	draw_rect(Rect2(Vector2(-8.0, -22.0), Vector2(16.0, 4.0)), iron)
	draw_rect(Rect2(Vector2(-8.0, -22.0), Vector2(4.0, 12.0)), iron)
	draw_rect(Rect2(Vector2(4.0, -22.0), Vector2(4.0, 12.0)), iron)
	# Body, rim and plate.
	draw_rect(Rect2(Vector2(-12.0, -12.0), Vector2(24.0, 20.0)), dark)
	draw_rect(Rect2(Vector2(-11.0, -11.0), Vector2(22.0, 18.0)), iron)
	draw_rect(Rect2(Vector2(-8.0, -8.0), Vector2(16.0, 12.0)), brass)
	# Keyhole.
	draw_rect(Rect2(Vector2(-2.0, -5.0), Vector2(4.0, 4.0)), dark)
	draw_rect(Rect2(Vector2(-1.0, -1.0), Vector2(2.0, 4.0)), dark)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## THE MOULDING, FOR ANY CANVAS ITEM. The house's paintings draw it round themselves; one of
## hers found somewhere else in the game -- half buried in Dagat's island sand -- draws the same
## gold the same way, so that it is recognisably one of this set of frames and not a picture
## that happens to be yellow round the edge.
static func draw_gilt(canvas: CanvasItem, picture: Rect2, width: float, dim := false) -> void:
	var bands := 4
	var step := width / float(bands)
	for band in range(bands):
		var inset := step * float(band)
		var rect := picture.grow(inset + step)
		# Across the moulding: brightest at the crown, which is the middle.
		var crown := 1.0 - absf(float(band) / float(bands - 1) * 2.0 - 1.0)
		var thickness := step
		# Top and left catch the light; bottom and right are in shadow.
		canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, thickness)),
			tone(0.86, crown, dim))
		canvas.draw_rect(Rect2(rect.position, Vector2(thickness, rect.size.y)),
			tone(0.78, crown, dim))
		canvas.draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - thickness),
			Vector2(rect.size.x, thickness)), tone(0.16, crown, dim))
		canvas.draw_rect(Rect2(Vector2(rect.end.x - thickness, rect.position.y),
			Vector2(thickness, rect.size.y)), tone(0.24, crown, dim))
	canvas.draw_rect(picture.grow(1.0), UISkin.GILT_EDGE, false, 1.0)
	canvas.draw_rect(picture.grow(width), UISkin.GILT_EDGE, false, 1.0)


## `lit` is how much this side faces the light, 0 to 1. Same ramp the canvas frame uses, so
## the gold in the house and the gold round the canvas are the same gold.
static func tone(lit: float, crown: float, dim := false) -> Color:
	var ramp: Array[Color] = [UISkin.GILT_EDGE, UISkin.GILT_DARK, UISkin.GILT_MID,
		UISkin.GILT, UISkin.GILT_LIT, UISkin.GILT_HI]
	var step := int(round(clampf(lit * 0.68 + crown * 0.40, 0.0, 1.0) * float(ramp.size() - 1)))
	var colour := ramp[step]
	# A painting you cannot walk into yet keeps its frame, dimmed with it.
	return colour.darkened(0.45) if dim else colour
