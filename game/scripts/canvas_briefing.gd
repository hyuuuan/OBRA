class_name CanvasBriefing
extends Control
## Lolo explains the canvas, the first time it is opened.
##
## THE ONE PLACE THE TUTORIAL IS ALLOWED TO STOP THE WORLD. `TutorialDirector`'s docstring
## is emphatic that lessons go to the hint bar and never to a dialogue box, because "pausing
## the world to explain walking is the exact complaint this class was written to answer".
## That objection is about cost, and here the cost is already paid: the drawing panel is a
## modal, the world is ALREADY stopped, and the player has just asked to be shown this
## screen. Explaining it while they are looking at it costs nothing and interrupts nothing.
##
## ⚠ AND IT LIVES INSIDE THE PANEL, not in the level's DialogueLayer. That layer is 8 and
## the drawing panel is 10, so the real `DialogueBox` renders UNDERNEATH the canvas -- a
## briefing routed through it would have paused the game to say something invisible.
##
## It reads as the same conversation the rest of the game has: Lolo's portrait, his name,
## his line, one press to turn the page. The look is the dialogue box's, deliberately, so a
## player does not have to learn a second thing that talks.

signal finished()

## ⚠ THE REAL DIALOGUE BOX'S OWN GEOMETRY, and not a size chosen for this panel.
##
## `DialoguePortrait` lays ITSELF out: it stands the bust against `DialogueBox.LIFT` and
## `DialogueBox.BOX`, at the right-hand end of where a conversation's box would be. Put the
## briefing anywhere else and his face goes to where the box ISN'T -- the first version sat
## the panel 96px off the bottom and left Lolo stranded half off the right edge, talking
## from outside the screen.
##
## Matching it is also the point. The player has been having conversations with this man all
## level; the screen he explains the canvas from should be the one he always speaks from.
const BOX := DialogueBox.BOX
const LIFT := DialogueBox.LIFT
const FADE := 0.28

var _scrim: ColorRect
var _portrait: DialoguePortrait
var _panel: PanelContainer
var _name: Label
var _text: Label
var _more: Label
var _lines: Array[String] = []
var _index := 0
var _done := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# STOP, not IGNORE. While Lolo is talking the canvas underneath must not take strokes --
	# a player who starts drawing through the briefing loses the strokes when it closes and
	# has no idea why.
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func _build() -> void:
	_scrim = ColorRect.new()
	_scrim.color = Color(0.02, 0.03, 0.02, 0.55)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_scrim)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override(&"panel", _box_style())
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 6)
	_panel.add_child(column)

	_name = Label.new()
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.text = Lolo.SPEAKER.to_upper()
	_name.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	_name.add_theme_color_override(&"font_color", UISkin.GOLD)
	column.add_child(_name)

	_text = Label.new()
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(BOX.x - 220.0, 0.0)
	_text.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	_text.add_theme_color_override(&"font_color", UISkin.CREAM_TEXT)
	column.add_child(_text)

	_more = Label.new()
	_more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_more.add_theme_font_size_override(&"font_size", UISkin.FONT_TINY)
	_more.add_theme_color_override(&"font_color", UISkin.GOLD_PALE)
	column.add_child(_more)

	# His face, for the same reason the dialogue box carries it: this is Lolo talking, and a
	# disembodied instruction in his voice is a tooltip pretending to be a character.
	_portrait = DialoguePortrait.new()
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait)


func _box_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.04, 0.96)
	style.border_color = UISkin.GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 12.0
	return style


func is_speaking() -> bool:
	return visible and not _done


## Say a beat. Nothing happens for an empty one, so a level with no briefing authored opens
## its canvas exactly as before.
func begin(lines: Array) -> void:
	_lines.clear()
	for value: Variant in lines:
		var line := String(value).strip_edges()
		if not line.is_empty():
			_lines.append(line)
	if _lines.is_empty():
		finished.emit()
		return
	_index = 0
	_done = false
	visible = true
	modulate.a = 0.0
	_portrait.show_for(Lolo.SPEAKER)
	_show_line()
	set_process_input(true)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE)


func _show_line() -> void:
	_text.text = _lines[_index]
	_more.text = "press to go on" if _index < _lines.size() - 1 else "press to draw"
	await get_tree().process_frame
	_lay_out()


## Exactly where a conversation sits. The portrait is NOT moved -- it places its own bust
## against these same two constants, and a Control that lays itself out cannot be helped by
## a second one also trying to.
func _lay_out() -> void:
	var screen := get_viewport_rect().size
	var top := screen.y - LIFT - BOX.y
	_panel.position = Vector2((screen.x - BOX.x) * 0.5, top)
	_panel.custom_minimum_size = Vector2(BOX.x, 0.0)


func _input(event: InputEvent) -> void:
	if not visible or _done:
		return
	var pressed := event.is_action_pressed(&"ui_accept")
	if not pressed and event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		pressed = click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	_index += 1
	if _index < _lines.size():
		_show_line()
		return
	_finish()


func _finish() -> void:
	_done = true
	set_process_input(false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE)
	tween.tween_callback(func() -> void:
		visible = false
		_portrait.hide_portrait()
		finished.emit())
