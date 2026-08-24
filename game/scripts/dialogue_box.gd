class_name DialogueBox
extends Control
## The game's voice, in a frame, in one place on the screen.
##
## It used to be a speech bubble pinned to Lolo in world space. That is fine for a
## companion barking one word and wrong for everything else this game does with dialogue:
## the bubble moved while you read it, it shrank and grew per line, it could be behind
## terrain or off the side of the camera, and it put the story at whatever height Lolo
## happened to be floating. Story is not a property of where a character is standing.
##
## Presented the way a console RPG presents it, because those conventions are load-bearing
## and players already know them:
##
##   * ONE PLACE. Lower centre, always, so the eye never hunts for it and it never covers
##     the obstacle the line is telling you to look at.
##   * ONE SIZE. A fixed box, whatever the line. A box that resizes per line makes the
##     reader re-find the first word every time.
##   * TYPED OUT. Text arrives at a readable rate rather than appearing whole. This is
##     what makes a line feel spoken, and it gives a slow reader a pace to follow.
##   * AN ARROW WHEN IT IS DONE. A blinking mark is the difference between "the game is
##     still talking" and "the game is waiting for you".
##
## The frame is UIFrame, for the reason written at the top of that file: in this game the
## story is a painting, so it is presented in a picture frame.

## Emitted when the last character has landed, so a caller can gate on the line being
## readable rather than on the line having been requested.
signal finished()

## Characters per second. Fast enough not to be a wait, slow enough to read along with.
## A line of Payyo's runs about ninety characters, so this is a shade under two seconds.
const SPEED := 52.0

## The box, in screen pixels. Sized for THREE lines at the body size and then fixed there,
## whatever the line -- a box that grows and shrinks per line makes the reader re-find the
## first word every time, and Payyo's script runs from "Here." to a full sentence about the
## Spanish burning the lowlands.
const BOX := Vector2(800.0, 205.0)
## Reserved along the bottom of the canvas for the advance arrow, so the last line of a
## three-line paragraph does not run underneath it.
const ARROW_GUTTER := 18.0
## How far the bottom of the box sits above the bottom of the screen. Clears the hotbar
## and the controls strip, both of which live down there.
const LIFT := 150.0

const UNIT := 4.0

var _frame: UIFrame
var _label: Label
var _speaker_tab: PanelContainer
var _speaker: Label
var _arrow: Control

## Whose line is up. Two voices share this box -- Lolo and the apo's own thoughts -- and
## a caller asking "am I still speaking?" means itself, not the box.
var current_speaker := ""

var _full := ""
var _shown := 0.0
var _hold := 0.0
var _blink := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	modulate.a = 0.0

	_frame = UIFrame.new()
	_frame.name = "Frame"
	_frame.unit = UNIT
	add_child(_frame)

	var pad := UIFrame.inset_for(UNIT) + 12.0
	_label = Label.new()
	_label.name = "Text"
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.add_theme_font_size_override(&"font_size", 19)
	_label.add_theme_color_override(&"font_color", UISkin.CREAM_TEXT)
	# No drop shadow. The canvas behind it is flat and dark; a shadow on type that is
	# already high-contrast only makes it look out of focus.
	_label.add_theme_constant_override(&"shadow_offset_x", 0)
	_label.add_theme_constant_override(&"shadow_offset_y", 0)
	_label.add_theme_constant_override(&"line_spacing", 6)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_label)
	_label.position = Vector2(pad, pad)
	_label.size = BOX - Vector2(pad, pad) * 2.0 - Vector2(0.0, ARROW_GUTTER)

	# Who is speaking, on a tab let into the top rail -- the way a painting carries a
	# plaque. It is also the only part of the box that changes shape, and it sits on the
	# frame rather than inside it so it costs the text no room.
	_speaker_tab = PanelContainer.new()
	_speaker_tab.name = "SpeakerTab"
	_speaker_tab.add_theme_stylebox_override(&"panel", _tab_style())
	_speaker_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speaker_tab.visible = false
	_frame.add_child(_speaker_tab)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	_speaker.add_theme_color_override(&"font_color", UISkin.GREEN_LABEL)
	_speaker.add_theme_constant_override(&"shadow_offset_x", 0)
	_speaker.add_theme_constant_override(&"shadow_offset_y", 0)
	_speaker_tab.add_child(_speaker)

	_arrow = Arrow.new()
	_arrow.name = "Arrow"
	_arrow.visible = false
	_frame.add_child(_arrow)
	_arrow.size = Vector2(18.0, 12.0)

	set_process(false)


## Anything that takes over the screen with story of its own -- a decision, a memory --
## calls this to clear the running line first. Through a group rather than a reference,
## because those overlays are authored siblings that know nothing about the HUD, and a
## line left underneath a decision box is a second voice arguing with the first.
const GROUP := &"dialogue_box"


func _ready() -> void:
	add_to_group(GROUP)
	_relayout()
	get_viewport().size_changed.connect(_relayout)


## Say something. `speaker` may be empty for narration, which shows no tab.
func show_line(text: String, speaker: String = "", seconds: float = 0.0) -> void:
	if text.is_empty():
		hide_line()
		return
	_full = text
	current_speaker = speaker
	_shown = 0.0
	_hold = seconds
	_label.text = text
	# The whole line is set and then revealed by ratio rather than by appending to the
	# label. Appending re-wraps on every character, so a word about to overflow jumps to
	# the next line as it is typed and the paragraph reflows under the reader.
	_label.visible_ratio = 0.0
	_speaker.text = speaker.to_upper()
	_speaker_tab.visible = not speaker.is_empty()
	_arrow.visible = false
	set_process(true)
	if not visible:
		visible = true
		_fade_to(1.0)
	_relayout()


## Skip to the end of the line. What a press of the advance key does.
func complete() -> void:
	if not visible:
		return
	_shown = float(_full.length())
	_label.visible_ratio = 1.0
	_arrow.visible = true
	finished.emit()


func is_typing() -> bool:
	return visible and _label.visible_ratio < 1.0


func hide_line() -> void:
	current_speaker = ""
	_hold = 0.0
	set_process(false)
	if not visible:
		return
	_fade_to(0.0).tween_callback(func() -> void: visible = false)


## A tween is bound to its node's pause state by default, and this box is a plain child of
## the level -- so under a modal that pauses the game, the fade never advances and the box
## stays on screen at full opacity underneath. That is exactly when it must go away: a
## decision box opens over it and the stale line argues with the question.
func _fade_to(alpha: float) -> Tween:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", alpha, 0.16)
	return tween


func _process(delta: float) -> void:
	var length := float(_full.length())
	if _shown < length:
		_shown = minf(length, _shown + SPEED * delta)
		_label.visible_ratio = _shown / maxf(1.0, length)
		if _shown >= length:
			_arrow.visible = true
			finished.emit()
		return

	_blink = fmod(_blink + delta, 1.0)
	_arrow.modulate.a = 1.0 if _blink < 0.6 else 0.15

	# A line given a duration clears itself; one given none stays until something
	# replaces it, which is what a hint about the obstacle in front of you wants.
	if _hold > 0.0:
		_hold -= delta
		if _hold <= 0.0:
			hide_line()


func _relayout() -> void:
	var view := get_viewport_rect().size
	_frame.size = BOX
	_frame.position = Vector2(floorf((view.x - BOX.x) * 0.5), floorf(view.y - LIFT - BOX.y))
	# On the top rail, indented from the corner boss so it does not sit on the joint.
	_speaker_tab.position = Vector2(UNIT * 7.0, -UNIT * 2.0)
	_speaker_tab.size = _speaker_tab.get_combined_minimum_size()
	var pad := UIFrame.inset_for(UNIT) + 12.0
	_arrow.position = Vector2(BOX.x - pad - _arrow.size.x, BOX.y - pad - 4.0)


func _tab_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UISkin.LIME
	box.set_corner_radius_all(UISkin.RADIUS)
	box.content_margin_left = 9.0
	box.content_margin_right = 9.0
	box.content_margin_top = 1.0
	box.content_margin_bottom = 2.0
	box.shadow_color = UISkin.INK
	box.shadow_size = 2
	return box


## The "there is more, press on" mark. A solid triangle, drawn rather than typed, because
## the glyph a font gives for it is at the mercy of whichever font is loaded.
class Arrow extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_colored_polygon(PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(w, 0.0), Vector2(w * 0.5, h),
		]), UISkin.LIME)
