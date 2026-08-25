class_name HintBar
extends Control
## What the game says while you are still playing, as opposed to what the story says.
##
## THESE ARE TWO DIFFERENT KINDS OF SPEECH AND THEY WERE SHARING ONE BOX. "Draw something
## that can span it" and "Four hundred years. Maybe less. They built this while the Spanish
## were burning the lowlands" are not the same act: the first is the game telling you what
## to do and must never stop you doing it, and the second is the game telling you something
## and deserves your attention. One box for both meant either the hint froze the game or
## the story went past unread, and in practice it did both.
##
## So this is the hint channel: small, off to the side, non-blocking, no key to press, and
## it clears itself. It wears HUD colours rather than the picture frame, because a hint is
## the interface talking and the frame is reserved for the fiction.

## Where it sits: centred, above the hotbar, out of the middle of the screen where the
## thing the hint is about usually is.
## How far the bar's BOTTOM sits above the bottom of the screen.
##
## Clear of the dialogue box, which is the whole reason for the number. The box is 300 tall
## and lifted 44, so it owns everything from 556 down; at 210 the hint sat at 620 and the
## two drew straight through each other -- a hint about what to draw printed across a line
## of Lola's story. This clears the box's top rail with a margin, and it is horizontally
## clear of the speaker's portrait too, which stands on that rail over at the right.
const LIFT := 396.0
const MAX_WIDTH := 720.0

var _panel: PanelContainer
var _speaker: Label
var _text: Label
var _life := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	modulate.a = 0.0

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.add_theme_stylebox_override(&"panel", UISkin.chip(16.0, 9.0))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)

	_speaker = Label.new()
	_speaker.name = "Speaker"
	_speaker.theme_type_variation = &"HudCaption"
	_speaker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_speaker)

	_text = Label.new()
	_text.name = "Text"
	_text.theme_type_variation = &"HudValue"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0.0, 0.0)
	row.add_child(_text)

	set_process(false)


func _ready() -> void:
	_relayout()
	get_viewport().size_changed.connect(_relayout)


## `seconds` of 0 means "until something replaces it", which is what a hint about the
## obstacle in front of you wants to be.
## Whether a story line is up. A hint and a line of dialogue on screen together are two
## voices talking over each other, and the hint is the one that can wait: it is advice about
## the obstacle in front of you and the obstacle is not going anywhere.
func _someone_is_speaking() -> bool:
	for node in get_tree().get_nodes_in_group(DialogueBox.GROUP):
		var box := node as CanvasItem
		if box != null and box.visible:
			return true
	return false


func show_hint(text: String, speaker: String = "", seconds: float = 0.0) -> void:
	if text.is_empty():
		clear()
		return
	_speaker.text = "%s:" % speaker.to_upper() if not speaker.is_empty() else ""
	_speaker.visible = not speaker.is_empty()
	_text.text = text
	_life = seconds
	set_process(true)
	if not visible:
		visible = true
		var appear := create_tween()
		appear.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		appear.tween_property(self, "modulate:a", 1.0, 0.14)
	_relayout()
	_relayout.call_deferred()


func clear() -> void:
	_life = 0.0
	set_process(false)
	if not visible:
		return
	var fade := create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(self, "modulate:a", 0.0, 0.14)
	fade.tween_callback(func() -> void: visible = false)


func is_showing() -> bool:
	return visible


func current_speaker() -> String:
	return _speaker.text


func _process(delta: float) -> void:
	# Stood down while the box is speaking, and back up the moment it closes. Suppressed
	# rather than cancelled: the hint the director asked for is still the current one, so a
	# player who reads a line of story does not have to re-trigger the advice underneath it.
	# FADED, NEVER HIDDEN. _relayout sizes the panel from get_combined_minimum_size(), and a
	# container measured while it is invisible does not report the size it will be -- so
	# toggling `visible` here let a deferred relayout land on a hidden frame and stick an
	# eight-hundred-pixel empty black slab across the top of the level. Alpha changes nothing
	# about layout.
	#
	# It is the PANEL's alpha and not this node's, because show_hint and clear both tween
	# this node's, and two things writing one property is how a bar ends up half-faded.
	var speaking := _someone_is_speaking()
	if _panel != null:
		_panel.modulate.a = 0.0 if speaking else 1.0
	if speaking:
		return
	if _life <= 0.0:
		return
	_life -= delta
	if _life <= 0.0:
		clear()


## Sized to its own text up to a limit, then centred. It has no fixed width because unlike
## the story box it is not something the eye returns to -- it appears, is read once, and
## goes, and a fixed bar would be mostly empty for most hints.
##
## The width is MEASURED off the font rather than asked of the layout. A Label with
## autowrap on reports a minimum width of nearly nothing -- it will happily be one
## character wide and a hundred tall -- so sizing the panel to its own minimum produced
## exactly that: a vertical strip of single letters down the middle of the screen.
func _relayout() -> void:
	var view := get_viewport_rect().size
	var font := _text.get_theme_font(&"font")
	var font_size := _text.get_theme_font_size(&"font_size")
	if font == null:
		return
	var single := font.get_string_size(
		_text.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	_text.custom_minimum_size = Vector2(ceilf(minf(single, MAX_WIDTH)), 0.0)
	var wanted := _panel.get_combined_minimum_size()
	_panel.size = wanted
	_panel.position = Vector2(
		floorf((view.x - wanted.x) * 0.5), floorf(view.y - LIFT - wanted.y))
