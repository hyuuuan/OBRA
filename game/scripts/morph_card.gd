class_name MorphCard
extends Control
## What the player currently IS, top right: the drawing, what the recogniser made of it, and
## how much of its life is left.
##
## SHAPED LIKE A BATTLE PLATE, because that is a layout every player can already read without
## being taught it: name on the left, a rating on the right, a bar underneath with what it is
## a bar OF written beside it, and the portrait of the thing boxed off at the end. Nothing
## here is a novel arrangement, and that is the point -- the card has to be legible in the
## corner of an eye during a jump.
##
## THE THREE READINGS MAP ONTO WHAT THIS GAME ACTUALLY HAS:
##
##   the name        the class the recogniser settled on -- SPIDER, not "spider_04"
##   the rating      HOW SURE IT WAS. A drawing is a guess about a drawing, and the player
##                   has never been shown the number their sketch scored. It belongs here:
##                   it is the one fact about this morph that is fixed for its whole life.
##   the bar         the life. Ink buys the transformation; this is what is left of it.
##   the portrait    the sketch itself, in the frame the hotbar keeps a stored drawing in,
##                   because a drawing you are WEARING and one you are CARRYING should be
##                   kept in the same kind of box.
##
## IT REPLACED THE R-DRAW CHIP, which said one word the player needs once. The controls strip
## along the bottom still reads R DRAW, so nothing was lost.
##
## IT IS NOT THERE WHEN THERE IS NOTHING TO SAY. The apo is not a drawing and has no life, so
## being yourself hides the card rather than leaving an empty frame and a dead bar.

## The plate, and the portrait boxed off the end of it. Deliberately large: this is the
## second-biggest thing on the HUD after the brush, because it is the thing on a clock.
const PLATE := Vector2(300.0, 74.0)
const PORTRAIT := 84.0
## How far the portrait's box overlaps the plate, so the two read as one assembly rather
## than as a panel with a picture parked next to it.
const OVERLAP := 10.0

var _name: Label
var _rating: Label
var _percent: Label
var _caption: Label
var _art: TextureRect
var _life: LifeBar
var _art_source: Image


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(PLATE.x + PORTRAIT - OVERLAP, maxf(PLATE.y, PORTRAIT))
	visible = false

	var plate := Panel.new()
	plate.name = "Plate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.position = Vector2(0.0, (PORTRAIT - PLATE.y) * 0.5)
	plate.size = PLATE
	plate.add_theme_stylebox_override(&"panel", UISkin.frame(12.0, 8.0))
	add_child(plate)

	# THE NAME, big. It is the first thing read and the only word on the card.
	_name = Label.new()
	_name.name = "Name"
	_name.theme_type_variation = &"HudBanner"
	_name.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	_name.position = Vector2(12.0, 4.0)
	_name.size = Vector2(PLATE.x * 0.62, 24.0)
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.add_child(_name)

	# HOW SURE THE RECOGNISER WAS, in the slot a battle plate puts a level in. Right
	# aligned against the plate's inner edge so it holds still as the name changes length.
	_rating = Label.new()
	_rating.name = "Rating"
	_rating.theme_type_variation = &"HudValue"
	_rating.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rating.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rating.position = Vector2(PLATE.x * 0.5, 4.0)
	_rating.size = Vector2(PLATE.x * 0.5 - 24.0, 24.0)
	plate.add_child(_rating)

	# LIFE, the caption beside the bar, in the slot a battle plate writes HP in.
	_caption = Label.new()
	_caption.name = "Caption"
	_caption.text = "LIFE"
	_caption.theme_type_variation = &"HudCaption"
	_caption.add_theme_constant_override(&"outline_size", 0)
	_caption.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	_caption.position = Vector2(12.0, 30.0)
	_caption.size = Vector2(52.0, 24.0)
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.add_child(_caption)

	_life = LifeBar.new()
	_life.name = "Life"
	_life.position = Vector2(64.0, 34.0)
	_life.size = Vector2(PLATE.x - 88.0, 16.0)
	plate.add_child(_life)

	# The percentage, ON the bar, the way the reference plate carries it.
	_percent = Label.new()
	_percent.name = "Percent"
	_percent.theme_type_variation = &"HudValue"
	_percent.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_percent.add_theme_constant_override(&"outline_size", 5)
	_percent.add_theme_color_override(&"font_outline_color", UISkin.INK)
	_percent.add_theme_constant_override(&"shadow_offset_x", 0)
	_percent.add_theme_constant_override(&"shadow_offset_y", 0)
	_percent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_percent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_life.add_child(_percent)

	# THE PORTRAIT, boxed off the right-hand end and standing taller than the plate.
	var box := Panel.new()
	box.name = "Portrait"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = Vector2(PLATE.x - OVERLAP, 0.0)
	box.size = Vector2(PORTRAIT, PORTRAIT)
	box.add_theme_stylebox_override(&"panel", UISkin.chip(4.0, 4.0))
	add_child(box)

	_art = TextureRect.new()
	_art.name = "Drawing"
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.offset_left = 7.0
	_art.offset_top = 7.0
	_art.offset_right = -7.0
	_art.offset_bottom = -7.0
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_art)


## Become a drawing.
##
## `confidence` is the recogniser's own 0-1 score for this sketch. It is shown as a whole
## percent and never changes for the life of the morph -- it is a fact about the drawing,
## not a reading that moves.
func show_form(form_name: String, image: Image, confidence: float) -> void:
	_name.text = form_name.to_upper()
	_rating.text = "%d%% SURE" % roundi(clampf(confidence, 0.0, 1.0) * 100.0)
	if image != _art_source:
		_art_source = image
		_art.texture = ImageTexture.create_from_image(image) if image != null else null
	visible = true


## Back to being the apo. The card goes entirely -- see the class note.
func hide_form() -> void:
	visible = false
	_art.texture = null
	_art_source = null
	_name.text = ""
	_rating.text = ""
	_percent.text = ""


## How much of the drawing is left. The percentage is floored so the bar never claims a
## whole point the player does not have, and it reads 1% for the whole of the last sliver
## rather than dropping to 0 under a creature still standing where it was left.
func set_life(remaining: float, capacity: float) -> void:
	_life.remaining = remaining
	_life.capacity = capacity
	_life.queue_redraw()
	if capacity <= 0.0:
		_percent.text = ""
		return
	var ratio := clampf(remaining / capacity, 0.0, 1.0)
	_percent.text = "%d%%" % (0 if ratio <= 0.0 else maxi(1, floori(ratio * 100.0)))


## The life bar: a trough with a fill that drains and changes colour on the way down.
##
## GOLD, AMBER, RED -- the three-stop health ramp, in this game's own metal rather than the
## green such bars are usually drawn in. The colour says what the length already says, so a
## player watching the level and not the corner still catches it going wrong.
class LifeBar extends Control:
	const TROUGH := UISkin.INK
	const EDGE := UISkin.RING_MID
	const FULL := UISkin.GOLD_PALE
	const LOW := UISkin.PENDING
	const CRITICAL := UISkin.RED_FILL
	const LOW_AT := 0.5
	const CRITICAL_AT := 0.25

	var remaining := 0.0
	var capacity := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), TROUGH)
		draw_rect(Rect2(Vector2.ZERO, size), EDGE, false, 2.0)
		if capacity <= 0.0:
			return
		var ratio := clampf(remaining / capacity, 0.0, 1.0)
		if ratio <= 0.0:
			return
		var inset := 2.0
		var track := size.x - inset * 2.0
		# Any life left keeps a sliver of bar. Rounding the last fraction of a second down
		# to nothing shows an empty bar under a creature still standing where it was left.
		var width := minf(track, maxf(3.0, track * ratio))
		var tone := _tone(ratio)
		draw_rect(Rect2(Vector2(inset, inset), Vector2(width, size.y - inset * 2.0)), tone)
		# A lit strip along the top of the fill, which is what stops a flat bar reading as
		# a coloured rectangle rather than as something with a surface.
		draw_rect(Rect2(Vector2(inset, inset), Vector2(width, 2.0)), tone.lightened(0.35))

	func _tone(ratio: float) -> Color:
		if ratio <= CRITICAL_AT:
			return CRITICAL
		if ratio <= LOW_AT:
			return LOW
		return FULL
