class_name CinematicBars
extends CanvasLayer
## The two black bars that say "watch this".
##
## Payyo's set pieces all used to happen at the same size as walking around: the checkpoint
## lit itself somewhere off to the right while the player carried on holding a direction, the
## straw came apart in the corner of the screen, and the level ended with a panel appearing
## over an unchanged view. A beat that the game does not frame is a beat the player is not
## looking at, and every one of these is a thing they earned.
##
## SO IT LETTERBOXES. Bars slide in, the camera takes hold of whatever the moment is about,
## the moment plays, and the bars go. It is the oldest signal in the medium and it needs no
## explanation the first time it happens.
##
## ⚠ IT DOES NOT PAUSE, and that is deliberate rather than lazy. A checkpoint is crossed at a
## run and frequently in mid-air; freezing the player inside their own jump to show them a
## lantern would be taking the game away to give them a reward. They keep control the whole
## time -- and in practice they stop, because the screen just told them to.
##
## It is also not a ModalOverlay: it decides nothing, answers no key, and must never appear
## in the cancel chain, or Escape would "close" a camera move.

signal finished()

## How much of the screen each bar eats at full extension. An eighth top and bottom is the
## shallowest letterbox that still reads as one -- deeper starts hiding the terrace the beat
## is standing on.
const BAR_FRACTION := 0.13
const SLIDE_IN := 0.34
const SLIDE_OUT := 0.30
## What the caption is drawn in. The bars are the one place in this interface that is allowed
## to be pure black, because they are not a panel -- they are the frame going away.
const BAR := Color(0.0, 0.0, 0.0, 1.0)

var _top: ColorRect
var _bottom: ColorRect
var _caption: Label
## 0 fully open, 1 fully letterboxed.
var _closed := 0.0:
	set(value):
		_closed = value
		_relayout()
var _run: Tween
var _playing := false


func _ready() -> void:
	# Over the HUD (5) and the dialogue layer (8), under the draw panel (10): while a beat is
	# framed, the interface is part of what is being framed out.
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()
	get_viewport().size_changed.connect(_relayout)


func _build() -> void:
	_top = ColorRect.new()
	_top.name = "Top"
	_top.color = BAR
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top)

	_bottom = ColorRect.new()
	_bottom.name = "Bottom"
	_bottom.color = BAR
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bottom)

	_caption = Label.new()
	_caption.name = "Caption"
	_caption.theme_type_variation = &"HudCaption"
	_caption.add_theme_color_override(&"font_color", UISkin.GOLD)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)


## Whole pixels, and measured off the live viewport rather than a constant: the bars have to
## meet the edges of whatever size the window actually is.
func _relayout() -> void:
	if _top == null:
		return
	var view := get_viewport().get_visible_rect().size
	var depth := floorf(view.y * BAR_FRACTION * _closed)
	_top.position = Vector2.ZERO
	_top.size = Vector2(view.x, depth)
	_bottom.position = Vector2(0.0, view.y - depth)
	_bottom.size = Vector2(view.x, depth)
	_caption.size = Vector2(view.x, maxf(depth, 1.0))
	_caption.position = Vector2(0.0, view.y - depth)
	_caption.modulate.a = clampf(_closed * 1.6 - 0.6, 0.0, 1.0)


func is_playing() -> bool:
	return _playing


## Bring the bars in and hold them until `open()`. `caption` is drawn in the lower bar, which
## is what the bar is FOR -- a letterbox with nothing in it is just a smaller screen.
func close(caption: String = "") -> void:
	_caption.text = caption
	visible = true
	_playing = true
	if _run != null and _run.is_valid():
		_run.kill()
	var run := create_tween()
	run.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	run.tween_property(self, "_closed", 1.0, SLIDE_IN) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_run = run


## And take them away again.
func open() -> void:
	if _run != null and _run.is_valid():
		_run.kill()
	var run := create_tween()
	run.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	run.tween_property(self, "_closed", 0.0, SLIDE_OUT) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	run.tween_callback(func() -> void:
		visible = false
		_playing = false
		finished.emit())
	_run = run
