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
## `apo_portrait.png` is cut by tools/build_art.py from the hero panel of the design sheet:
## 177 x 312 against the world sprite's 80 x 106, and a different drawing rather than the
## same one bigger -- shading in the hair, folds in the shirt. A dialogue portrait is the
## one place a game can afford detail the world sprite has no room for, and this sheet had
## been carrying it unused.
const PORTRAIT := preload("res://assets/characters/apo/apo_portrait.png")
## How much of the drawing is head, shoulders and hands, before the hip.
const BUST_FRACTION := 0.62
## How tall the bust stands on screen. Rounded DOWN to a whole multiple of the source, so
## the drawing is never resampled onto a half pixel.
const HEIGHT := 400.0
## How far the bust's cut edge sinks behind the box's top rail, so it stands ON the box
## rather than balancing above it.
const OVERLAP := 34.0
## How far in from the right edge of the screen the bust stands.
const INSET := 90.0

## LOLO IS NOT A BUST AND MUST NOT BE DRAWN AS ONE.
##
## He has no design yet -- he is a 19-unit ball with a leaf, drawn from primitives in
## lolo_figure.gd. Scaled to fill the apo's bust box he became a four-hundred-pixel
## smooth yellow circle with two dots on it, which is not a placeholder looking rough,
## it is a placeholder looking like a bug.
##
## Two things fix that and both are about honesty. He is rendered at his OWN size into a
## small viewport and then blown up with nearest filtering, so his edges are chunky like
## everything else on screen instead of being the only antialiased thing in the frame.
## And he is drawn SMALL -- a little over half the bust's height -- because he is a
## companion who hovers at your shoulder, not a face filling the corner. Give him a real
## design and this whole branch goes away; see CONTENT_NEEDED.md.
##
## His own canvas, in the units lolo_figure.gd draws in. Tall enough for the leaf above
## his head and the soft shadow below him -- the viewport clips, and half a shadow reads
## as a bite taken out of him.
const LOLO_FRAME := Vector2i(72, 112)
## Where his origin sits in that canvas. He floats, so there is air underneath.
const LOLO_ORIGIN := Vector2(36.0, 58.0)
## Where he actually is inside that canvas, in the same units. Measured off
## lolo_figure.gd: the leaf tip is nine above his origin plus the stem and the ball, and
## the ball bottom is nineteen below it. THE FRAME IS MOSTLY EMPTY -- it has to be, to
## hold the leaf and the soft shadow without clipping either -- so sizing and standing him
## by the frame puts a small blob in the middle of a large nothing, which is exactly how
## he came out the first time. Both are done off his BODY instead.
const LOLO_BODY_TOP := 21.0
const LOLO_BODY_BOTTOM := 77.0
## How tall his body is next to the apo's bust.
const LOLO_SHARE := 0.58
## How fast he bobs while a line is up, in cycles per second. The same rate lolo.gd uses
## in the world, so the portrait and the sprite behind it breathe together.
const BOB_HZ := 0.55

var _apo: TextureRect
var _lolo: TextureRect
var _lolo_viewport: SubViewport
var _lolo_figure: Node2D
var _bob: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	modulate.a = 0.0

	var bust := AtlasTexture.new()
	bust.atlas = PORTRAIT
	bust.region = Rect2(0.0, 0.0, float(PORTRAIT.get_width()),
		floorf(float(PORTRAIT.get_height()) * BUST_FRACTION))
	_apo = TextureRect.new()
	_apo.name = "Apo"
	_apo.texture = bust
	_apo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_apo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_apo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apo.visible = false
	add_child(_apo)

	_lolo_viewport = SubViewport.new()
	_lolo_viewport.name = "LoloViewport"
	_lolo_viewport.size = LOLO_FRAME
	_lolo_viewport.transparent_bg = true
	_lolo_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_lolo_viewport.disable_3d = true
	add_child(_lolo_viewport)

	_lolo_figure = Node2D.new()
	_lolo_figure.name = "Figure"
	_lolo_figure.set_script(load("res://scripts/lolo_figure.gd"))
	_lolo_figure.position = LOLO_ORIGIN
	# He faces LEFT here, back toward the text and the player, rather than off the edge of
	# the screen he is standing at the right of.
	_lolo_figure.set(&"facing", -1.0)
	_lolo_viewport.add_child(_lolo_figure)

	_lolo = TextureRect.new()
	_lolo.name = "Lolo"
	_lolo.texture = _lolo_viewport.get_texture()
	_lolo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_lolo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lolo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_lolo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lolo.visible = false
	add_child(_lolo)


func _ready() -> void:
	# The bob has to keep going while the tree is paused: a memory overlay stops the world
	# and a portrait that freezes mid-breath underneath it looks like the game hung.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	get_viewport().size_changed.connect(_relayout)


## Lolo breathes while his line is up, at the rate lolo.gd bobs him in the world, so the
## portrait and the sprite it is standing in front of are in step rather than beating
## against each other. Only ever running while he is the one showing -- the apo's portrait
## is a still drawing and there is nothing here for it to do.
func _process(delta: float) -> void:
	if _lolo_figure == null or not is_instance_valid(_lolo_figure):
		return
	_bob = fmod(_bob + delta * BOB_HZ, 1.0)
	_lolo_figure.set(&"bob", _bob)
	_lolo_figure.queue_redraw()


func show_for(speaker: String) -> void:
	var is_lolo := speaker == Lolo.SPEAKER
	_lolo.visible = is_lolo
	_apo.visible = not is_lolo
	# The open mouth is the whole of his expression, and this is the one place in the game
	# where something is unambiguously being said out loud.
	_lolo_figure.set(&"talking", is_lolo)
	set_process(is_lolo)
	_relayout()
	if visible:
		return
	visible = true
	var appear := create_tween()
	appear.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	appear.tween_property(self, "modulate:a", 1.0, 0.18)


## Where the speaker's picture actually is, whichever of them is up. The two are NOT the
## same rectangle any more -- they share a baseline and a centre line, but Lolo is drawn
## at a little over half the apo's height, so a caller measuring the portrait has to be
## told which one it got.
func bust_rect() -> Rect2:
	var showing := _lolo if _lolo.visible else _apo
	return Rect2(showing.position, showing.size)


func hide_portrait() -> void:
	set_process(false)
	if _lolo_figure != null and is_instance_valid(_lolo_figure):
		_lolo_figure.set(&"talking", false)
	if not visible:
		return
	var fade := create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(self, "modulate:a", 0.0, 0.18)
	fade.tween_callback(func() -> void: visible = false)


## The apo's drawing, cropped at the hip. This is the bust the layout is measured from;
## Lolo is then fitted against the result rather than against the screen, so the two stay
## in proportion to each other whatever the window is doing.
func _source_size() -> Vector2i:
	return Vector2i(PORTRAIT.get_width(),
		int(floorf(float(PORTRAIT.get_height()) * BUST_FRACTION)))


func _relayout() -> void:
	var view := get_viewport_rect().size
	var source := _source_size()
	var scale := maxf(1.0, floorf(HEIGHT / float(source.y)))
	var width := float(source.x) * scale
	var height := float(source.y) * scale
	# The box's own top rail is the shelf the bust stands on.
	var box_top := view.y - DialogueBox.LIFT - DialogueBox.BOX.y
	# To the RIGHT of the box rather than over the middle of it. The plaque naming the
	# speaker is at the box's top left, so putting the face at the other end spreads the
	# two things that identify who is talking instead of stacking them.
	var rect := Rect2(
		Vector2(floorf(view.x - INSET - width), floorf(box_top + OVERLAP - height)),
		Vector2(width, height))

	_apo.position = rect.position
	_apo.size = rect.size

	# Lolo, fitted to his own frame rather than stretched into the apo's. Whole multiples
	# only: he is upscaled with nearest filtering, and a fractional one doubles some of his
	# pixels and not others, which on a figure made of circles reads as a dent.
	var body := LOLO_BODY_BOTTOM - LOLO_BODY_TOP
	var lolo_scale := maxf(1.0, roundf(rect.size.y * LOLO_SHARE / body))
	var lolo_size := Vector2(float(LOLO_FRAME.x) * lolo_scale, float(LOLO_FRAME.y) * lolo_scale)
	# Same baseline, same centre line. A beat that hands the line from one of them to the
	# other should swap the picture without the reader's eye having to go and find it.
	# Stood on the BALL rather than on the bottom of the canvas, so what rests on the box's
	# rail is Lolo and not the empty strip his shadow lives in.
	_lolo.position = Vector2(
		floorf(rect.position.x + (rect.size.x - lolo_size.x) * 0.5),
		floorf(rect.end.y - LOLO_BODY_BOTTOM * lolo_scale))
	_lolo.size = lolo_size
