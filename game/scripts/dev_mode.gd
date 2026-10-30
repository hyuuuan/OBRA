extends Node
## One development flag; the normal menu, house, brush pickup and saves stay in use.

const SETTING := "debug/dev_mode/enabled"
const IndicatorSkin := preload("res://scripts/ui_skin.gd")

var _indicator: Label
var _normal_window_title := ""
var enabled := false:
	set(value):
		enabled = value and OS.has_feature("debug")
		if _indicator != null:
			_update_identity()


func _init() -> void:
	# Existing probes exercise real progression. Each can opt in explicitly when testing
	# the bypass, without changing the project's flag or the player's data.
	enabled = bool(ProjectSettings.get_setting(SETTING, false)) \
		and not preload("res://scripts/user_data.gd").is_test_run()


func _ready() -> void:
	_normal_window_title = get_window().title
	var layer := CanvasLayer.new()
	layer.name = "DevIndicatorLayer"
	layer.layer = 99
	add_child(layer)
	_indicator = Label.new()
	_indicator.name = "Indicator"
	_indicator.text = "DEV MODE"
	_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicator.add_theme_font_size_override(&"font_size", IndicatorSkin.FONT_CAPTION)
	_indicator.add_theme_color_override(&"font_color", IndicatorSkin.GOLD_PALE)
	_indicator.add_theme_color_override(&"font_outline_color", IndicatorSkin.INK)
	_indicator.add_theme_constant_override(&"outline_size", 4)
	layer.add_child(_indicator)
	_indicator.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_indicator.offset_left = -180.0
	_indicator.offset_right = -24.0
	_indicator.offset_top = 12.0
	_indicator.offset_bottom = 42.0
	_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_update_identity()


func _update_identity() -> void:
	_indicator.visible = enabled
	get_window().title = _normal_window_title + " [DEV MODE]" if enabled else _normal_window_title
