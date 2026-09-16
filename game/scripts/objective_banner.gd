class_name ObjectiveBanner
extends Control
## WHAT TO DO NOW, in one line under the level's name.
##
## Thesis §4.5.3.5: "The quest banner runs along the top, stating the current objective." The
## badge up there stated the LEVEL, and then the beat the player was standing in -- a place,
## never a task. Everything that said what to do was spoken once and then gone: a line of
## Lolo's as the player walked into a beat, a hint that stood until something replaced it.
## A player who read it and then walked somewhere else to think, or who got it in the middle
## of a jump, had nothing on screen to come back to. Two playtests in a row ended with "I am
## still confused on what to do" in both levels, from somebody who had read every line.
##
## So this line is not a message; it is a STATE. The level works out what the player should be
## doing from the state of the run -- which beat is open, which route was taken, what is in
## hand, which room they are in -- and this shows that, every time it is asked, for as long as
## it is true. It is never spoken over anything and it never expires.
##
## ⚠ THE WORDS COME FROM THE LEVEL'S CONFIG, not from here, so the audit that keeps every
## line of dialogue from naming a class the player has not earned can read them too.

## ⚠ THE BADGE IS INSIDE THIS NOW, so this sits where the badge used to. Where the player is
## and what they are doing there were two chips stacked on top of each other under the top
## edge, with Lolo's box under the pair of them -- three framed boxes in a column down the
## middle of the screen, which is what "everything is overlapping" looks like from outside
## even when the rectangles do not actually touch. They are one object: a small line naming
## the place, and the task under it.
const TOP := 18.0
## Longer than this is a sentence, and a sentence belongs to Lolo.
const MAX_WIDTH := 640.0

var _panel: PanelContainer
var _column: VBoxContainer
## The level's own name, kept by the level and drawn in here. Adopted rather than copied, so
## whatever writes "LEVEL 1 · PAYYO · ANG TULAY" goes on writing to the same label.
var _place: Label
var _mark: Control
var _label: Label
var _text := ""
var _flash: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override(&"panel", UISkin.chip(12.0, 4.0))
	add_child(_panel)

	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 1)
	_panel.add_child(_column)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 9)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_child(row)

	_mark = Control.new()
	_mark.name = "Mark"
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.custom_minimum_size = Vector2(12.0, 12.0)
	_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mark.draw.connect(_draw_mark)
	row.add_child(_mark)

	_label = Label.new()
	_label.name = "Text"
	_label.theme_type_variation = &"HudValue"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_label)


## The badge moves in here, above the objective and centred over it. The level still owns the
## label and still writes the beat's name into it; this decides where it is drawn.
func adopt_place(label: Label) -> void:
	if label == null:
		return
	if label.get_parent() != null:
		label.get_parent().remove_child(label)
	_place = label
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_child(label)
	_column.move_child(label, 0)
	label.resized.connect(_relayout)
	visible = true
	_relayout.call_deferred()


func _ready() -> void:
	get_viewport().size_changed.connect(_relayout)


func text() -> String:
	return _text


## Say what the player is doing now. The same text twice is nothing; a new one arrives with a
## brief lift, because an objective that changes silently is one the player does not notice
## has changed -- and the change is usually the most useful thing on the screen.
func set_objective(value: String) -> void:
	if value == _text:
		return
	_text = value
	_label.text = value
	_label.visible = not value.is_empty()
	_mark.visible = _label.visible
	# The chip stays up for the place line even with no task in it: the level's name is the
	# one thing on this screen that is always true.
	visible = _label.visible or (_place != null and not _place.text.is_empty())
	if not visible:
		return
	_relayout()
	if _flash != null and _flash.is_valid():
		_flash.kill()
	_panel.pivot_offset = _panel.size * 0.5
	_panel.modulate = Color(1.45, 1.3, 0.9, 1.0)
	_panel.scale = Vector2(1.06, 1.06)
	_flash = create_tween()
	_flash.set_parallel(true)
	_flash.tween_property(_panel, "modulate", Color.WHITE, 0.7)
	_flash.tween_property(_panel, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Measured off the font, for the reason HintBar gives: a Label reports almost no minimum
## width of its own, and a chip sized to it is a sliver.
func _relayout() -> void:
	var font := _label.get_theme_font(&"font")
	var font_size := _label.get_theme_font_size(&"font_size")
	if font == null:
		return
	var width := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	_label.custom_minimum_size = Vector2(ceilf(minf(width, MAX_WIDTH)), 0.0)
	# The chip is as wide as the wider of its two lines, and the place line is centred in it.
	if _place != null:
		var place_font := _place.get_theme_font(&"font")
		var place_size := _place.get_theme_font_size(&"font_size")
		if place_font != null:
			_place.custom_minimum_size = Vector2(ceilf(minf(place_font.get_string_size(
				_place.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, place_size).x, MAX_WIDTH)), 0.0)
	_panel.reset_size()
	var wanted := _panel.get_combined_minimum_size()
	_panel.size = wanted
	_panel.position = Vector2(floorf((get_viewport_rect().size.x - wanted.x) * 0.5), TOP)
	_panel.pivot_offset = wanted * 0.5


## A small gold diamond: a waypoint, and the same mark the marker in the world draws.
func _draw_mark() -> void:
	var c := _mark.size * 0.5
	var r := minf(c.x, c.y)
	_mark.draw_colored_polygon(PackedVector2Array([
		c + Vector2(0.0, -r), c + Vector2(r, 0.0), c + Vector2(0.0, r), c + Vector2(-r, 0.0)]),
		UISkin.GOLD)
