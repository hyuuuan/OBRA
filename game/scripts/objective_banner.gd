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

## Under the badge, which owns y 18..52.
const TOP := 56.0
## Longer than this is a sentence, and a sentence belongs to Lolo.
const MAX_WIDTH := 640.0

var _panel: PanelContainer
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

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 9)
	_panel.add_child(row)

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
	visible = not value.is_empty()
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
