class_name DialoguePortrait
extends Control
## The speaker, big, standing behind the dialogue box.
##
## THIS IS WHAT THE CAMERA PUSH-IN COULD NOT DO. Zooming the world camera makes the
## speaker slightly larger and still forty pixels tall, still side-on, still with their
## back half behind a terrace. What a player needs while someone talks is a FACE, and every
## game that leans on dialogue solves it the same way: a bust of the speaker, drawn at a
## size the in-game sprite never reaches, standing behind the text.
##
## HALF THE BODY, ABOVE THE BOX. Head, shoulders and hands, cut at the hip and standing on
## the box's top rail -- the two read as one object, a face with its words underneath.
##
## A full figure was tried and is wrong for this arrangement: standing someone at the
## bottom of the screen puts their head in the middle of it, which is exactly where the
## reader's eye travels between the portrait and the text. Cutting at the hip lifts the
## face to the top of the screen and leaves that path clear. The cut line has the box's own
## rail to sit on, which is what a bust needs and what it did not have when the box was
## beside it.

## THE PORTRAIT IS ITS OWN DRAWING, not the world sprite enlarged.
##
## Both are cut by tools/build_art.py from the hero card of the speaker's design sheet:
## around two hundred by three hundred against the world sprite's eighty by a hundred, and
## a different drawing rather than the same one bigger -- shading in the hair, folds in the
## cloth. A dialogue portrait is the one place a game can afford detail the world sprite
## has no room for, and both sheets had been carrying it.
##
## LOLO USED TO BE THE EXCEPTION AND IS NOT ANY MORE. He had no design, so he was rendered
## from primitives into a SubViewport at his own tiny size, blown back up with nearest
## filtering to keep his edges chunky, and stood at a little over half the apo's height so
## that a four-hundred-pixel smooth yellow circle with two dots on it never appeared in the
## corner of the screen. All of that was scaffolding around a missing drawing. He has one
## now, so the two speakers are one code path again: one rectangle, one scale rule, one
## baseline, and a row in the table below apiece.

## `bust` is how much of the drawing is head, shoulders and hands, before the cut.
##
## IT IS PER SPEAKER BECAUSE THEY ARE NOT BUILT THE SAME. The apo is a child drawn at
## roughly four heads tall and cuts at the hip. Lolo is a chibi ghost whose head is two
## fifths of him and whose legs are a tail, so the same fraction landed just under his
## chin and put a head on a plate behind the box. His cut is where the tail starts, which
## is the lowest line that is not through a hand.
const PORTRAITS := {
	"Lolo": {"art": preload("res://assets/characters/lolo/lolo_portrait.png"),
		"bust": 0.78},
}
## Anyone without an entry above. The apo's own lines share the box with a different
## plaque, and they are the only other speaker there is.
const DEFAULT_PORTRAIT := {
	"art": preload("res://assets/characters/apo/apo_portrait.png"), "bust": 0.62,
}
## How tall the bust wants to stand on screen. A TARGET, not a ceiling: what it is rounded
## to is a whole multiple of the source, so the drawing is never resampled onto a half
## pixel, and the nearest multiple is taken rather than the one below. Lolo's bust is a
## third taller than the apo's in source pixels for the same face, and rounding down put
## him at 1x -- a portrait half the size of the other one, for no reason a player could
## see. Both land on 2x, which is why their faces come out the same size.
const HEIGHT := 400.0
## How far the bust's cut edge sinks behind the box's top rail, so it stands ON the box
## rather than balancing above it.
const OVERLAP := 34.0
## How far in from the right edge of the screen the bust stands.
const INSET := 90.0

var _bust: TextureRect
var _source: Vector2i = Vector2i.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	modulate.a = 0.0

	_bust = TextureRect.new()
	_bust.name = "Bust"
	_bust.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bust.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bust.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_bust.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bust)
	_wear(DEFAULT_PORTRAIT)


func _ready() -> void:
	# The fade has to keep running while the tree is paused: a memory overlay stops the
	# world and a portrait frozen half-faded under it looks like the game hung.
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_relayout)


## The drawing, cropped at this speaker's own cut line.
func _wear(entry: Dictionary) -> void:
	var portrait: Texture2D = entry["art"]
	_source = Vector2i(portrait.get_width(),
		int(floorf(float(portrait.get_height()) * float(entry["bust"]))))
	var bust := AtlasTexture.new()
	bust.atlas = portrait
	bust.region = Rect2(Vector2.ZERO, Vector2(_source))
	_bust.texture = bust


func show_for(speaker: String) -> void:
	_wear(PORTRAITS.get(speaker, DEFAULT_PORTRAIT))
	_relayout()
	if visible:
		return
	visible = true
	var appear := create_tween()
	appear.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	appear.tween_property(self, "modulate:a", 1.0, 0.18)


## Where the speaker's picture actually is. The two busts share a baseline and a centre
## line but not a width, so a caller measuring the portrait is measuring THIS speaker's.
func bust_rect() -> Rect2:
	return Rect2(_bust.position, _bust.size)


func hide_portrait() -> void:
	if not visible:
		return
	var fade := create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(self, "modulate:a", 0.0, 0.18)
	fade.tween_callback(func() -> void: visible = false)


func _relayout() -> void:
	if _source.y <= 0:
		return
	var view := get_viewport_rect().size
	# Whole multiples only: the bust is upscaled with nearest filtering, and a fractional
	# one doubles some of its pixels and not others, which on a drawing made of curves
	# reads as a dent.
	var scale := maxf(1.0, roundf(HEIGHT / float(_source.y)))
	var width := float(_source.x) * scale
	var height := float(_source.y) * scale
	# The box's own top rail is the shelf the bust stands on.
	var box_top := view.y - DialogueBox.LIFT - DialogueBox.BOX.y
	# To the RIGHT of the box rather than over the middle of it. The plaque naming the
	# speaker is at the box's top left, so putting the face at the other end spreads the
	# two things that identify who is talking instead of stacking them.
	_bust.position = Vector2(floorf(view.x - INSET - width),
		floorf(box_top + OVERLAP - height))
	_bust.size = Vector2(width, height)
