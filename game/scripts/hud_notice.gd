class_name HudNotice
extends PanelContainer
## Brief action feedback, separate from the brush's permanent readings.

const HOLD_SECONDS := 5.0
var _label: Label
var _last_text := ""
var _remaining := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override(&"panel", UISkin.chip())
	hide()


func adopt(label: Label) -> void:
	_label = label
	label.reparent(self)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2.ZERO
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override(&"font_color", UISkin.MUTED)
	label.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)


func _process(delta: float) -> void:
	if _label == null:
		return
	if _label.text != _last_text:
		_last_text = _label.text
		_remaining = HOLD_SECONDS if not _last_text.is_empty() else 0.0
		reset_size()
	else:
		_remaining = maxf(0.0, _remaining - delta)
		if _remaining == 0.0:
			_label.text = ""
			_last_text = ""
	visible = _remaining > 0.0
