class_name HudPanel
extends PanelContainer
## The player's own state, in one frame instead of scattered across the screen.
##
## The HUD used to be five separate things in five places -- a bare status line top left, a
## progress bar and a number beside it, a level badge, a permanent keybind row, a goal
## readout -- all in unstyled text over busy pixel art, and none of it wearing the language
## the main menu had already established. This is the top-left half of the fix: ink and
## whatever the game is currently telling you, framed together, so there is one place to
## look for "how am I doing".
##
## INK IS THE WHOLE ECONOMY, so it gets a gauge rather than a sentence. "Ink 12.0 / 12.0"
## is a debug print: the decimals move while you draw, they invite reading a number that
## does not mean anything on its own, and 12.0 of 12.0 tells you nothing 12 does not.

const FRAME_BG := Color(0.075, 0.095, 0.075, 0.94)
const FRAME_BORDER := Color(0.55, 0.62, 0.24, 1.0)
const LIME := Color(0.72, 0.82, 0.23, 1.0)
const CREAM := Color(0.88, 0.9, 0.8, 1.0)

var _value: Label
var _gauge: Gauge


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override(&"panel", frame())

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override(&"separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	var heading := HBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(heading)

	var caption := Label.new()
	caption.text = "INK"
	caption.add_theme_color_override(&"font_color", LIME)
	caption.add_theme_font_size_override(&"font_size", 15)
	caption.add_theme_constant_override(&"outline_size", 0)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(caption)

	_value = Label.new()
	_value.name = "Value"
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value.add_theme_color_override(&"font_color", CREAM)
	_value.add_theme_font_size_override(&"font_size", 15)
	heading.add_child(_value)

	_gauge = Gauge.new()
	_gauge.name = "Gauge"
	_gauge.custom_minimum_size = Vector2(0.0, 16.0)
	column.add_child(_gauge)


## The status line lives inside the frame rather than floating on the level behind it, so
## it has something to be read against. It stays the node the rest of game_level already
## writes to -- there are thirty of those call sites and none of them need to know.
func adopt_status(label: Label) -> void:
	if label == null:
		return
	var parent := label.get_parent()
	if parent != null:
		parent.remove_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(0.0, 22.0)
	label.add_theme_color_override(&"font_color", CREAM)
	label.add_theme_font_size_override(&"font_size", 15)
	($Column as VBoxContainer).add_child(label)


## Whole units. `remaining` is continuous, so it is floored -- a gauge that rounds up
## claims ink the player does not have, and the one number they act on is "can I still
## draw something".
func set_ink(remaining: float, capacity: float, reserved: float) -> void:
	_value.text = "%d of %d" % [floori(maxf(0.0, remaining)), roundi(capacity)]
	_gauge.remaining = remaining
	_gauge.capacity = capacity
	_gauge.reserved = reserved
	_gauge.queue_redraw()


## A compact version of the same frame, for the readouts pinned to the far corners.
static func chip() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = FRAME_BG
	box.border_color = FRAME_BORDER
	box.set_border_width_all(2)
	box.set_corner_radius_all(2)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 5.0
	return box


static func frame() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = FRAME_BG
	box.border_color = FRAME_BORDER
	box.set_border_width_all(3)
	box.set_corner_radius_all(2)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 12.0
	return box


## The gauge. Drawn rather than a ProgressBar because it carries two quantities: what is
## left, and how much of it the sketch on the canvas is about to cost. A player mid-drawing
## needs to see the second one eating the first.
class Gauge extends Control:
	const TROUGH := Color(0.04, 0.06, 0.04, 1.0)
	const EDGE := Color(0.35, 0.4, 0.26, 1.0)
	const FILL := Color(0.72, 0.82, 0.23, 1.0)
	## Ink the current sketch has claimed but not yet spent. Warm, because it is not gone
	## and clearing the canvas hands it straight back.
	const PENDING := Color(0.98, 0.9, 0.31, 1.0)

	var remaining := 12.0
	var capacity := 12.0
	var reserved := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var box := Rect2(Vector2.ZERO, size)
		draw_rect(box, TROUGH)
		var span := maxf(0.001, capacity)
		var free_width := size.x * clampf(remaining / span, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, Vector2(free_width, size.y)), FILL)
		if reserved > 0.001:
			var pending_width := size.x * clampf(reserved / span, 0.0, 1.0)
			draw_rect(Rect2(Vector2(free_width, 0.0), Vector2(pending_width, size.y)), PENDING)
		draw_rect(box, EDGE, false, 2.0)
		# One notch per unit, so the budget can be read as a count and not only as a
		# length. Twelve of them is the whole economy.
		var units := maxi(1, roundi(capacity))
		for index in range(1, units):
			var x := size.x * float(index) / float(units)
			draw_line(Vector2(x, size.y * 0.55), Vector2(x, size.y), EDGE, 1.0)
