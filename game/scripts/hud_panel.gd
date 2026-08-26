class_name HudPanel
extends PanelContainer
## What the player has to draw with, and what the game just said, in one frame.
##
## THE FRAME IS BACK, and the unframed version is why. The brush was drawn straight onto the
## level with an outline on every line of type, which reads fine in a still and badly in
## motion: this corner sits over Payyo's SKY on nearly every frame, a large bright field,
## and a gold brush with a dark edge on pale blue is a gold brush you have to look for. An
## outline gives a glyph an edge. It does not give it a GROUND, and small type over moving
## art needs a ground. So the rectangle is back, and the brush keeps the size it earned.
##
## WHAT YOU ARE IS NOT HERE. The nameplate and the life bar used to sit above the brush;
## they are `MorphCard` in the opposite corner now, holding the drawing itself rather than
## a word for it. This corner is the things that are true whoever you currently are.
##
## INK IS THE CLOCK THIS CORNER OWNS. "Ink 12.0 / 12.0" was a debug print -- the decimals
## move while you draw, and 12.0 of 12.0 tells you nothing 12 does not -- so it gets the
## brush at six screen pixels to the art pixel, which is the artwork at native size.

const GOLD := UISkin.GOLD
const CREAM := UISkin.CREAM_TEXT

## Screen pixels to the art pixel. Six is the artwork 1:1 -- 366 by 66 -- as big as the
## brush can be drawn without inventing pixels, and the size this corner is built around.
const GAUGE_SCALE := 6

var _value: Label
var _gauge: InkBrush


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override(&"panel", UISkin.frame())

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override(&"separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	_build_ink(column)


## The brush, and the count under it.
func _build_ink(column: VBoxContainer) -> void:
	# Sized exactly and pinned left. A VBoxContainer stretches its children to its own
	# width, which would leave InkBrush centring itself in whatever was left over and
	# drifting sideways every time the status line under it changed length.
	_gauge = InkBrush.new()
	_gauge.name = "Gauge"
	_gauge.custom_minimum_size = InkBrush.size_at(GAUGE_SCALE)
	_gauge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_gauge)

	var heading := HBoxContainer.new()
	heading.name = "Heading"
	heading.add_theme_constant_override(&"separation", 7)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The brush's own width, so the count lands under the bristles.
	heading.custom_minimum_size = Vector2(InkBrush.size_at(GAUGE_SCALE).x, 0.0)
	heading.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(heading)

	var drop := UIGlyph.new()
	drop.name = "Droplet"
	drop.kind = UIGlyph.Kind.DROPLET
	drop.custom_minimum_size = Vector2(12.0, 16.0)
	heading.add_child(drop)

	var caption := Label.new()
	caption.name = "Caption"
	caption.text = "INK"
	caption.theme_type_variation = &"HudCaption"
	caption.add_theme_constant_override(&"outline_size", 0)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(caption)

	_value = Label.new()
	_value.name = "Value"
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value.theme_type_variation = &"HudValue"
	heading.add_child(_value)


## The status line lives inside the frame rather than floating on the level behind it, so it
## has something to be read against. It stays the node the rest of game_level already writes
## to -- there are thirty of those call sites and none of them need to know.
func adopt_status(label: Label) -> void:
	if label == null:
		return
	var parent := label.get_parent()
	if parent != null:
		parent.remove_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(0.0, 22.0)
	label.add_theme_color_override(&"font_color", UISkin.MUTED)
	label.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	($Column as VBoxContainer).add_child(label)


## Whole units. `remaining` is continuous, so it is floored -- a gauge that rounds up claims
## ink the player does not have, and the one number they act on is "can I still draw
## something".
func set_ink(remaining: float, capacity: float, reserved: float) -> void:
	_value.text = "%d of %d" % [floori(maxf(0.0, remaining)), roundi(capacity)]
	_gauge.remaining = remaining
	_gauge.capacity = capacity
	_gauge.reserved = reserved
	_gauge.queue_redraw()
