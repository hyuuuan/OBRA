class_name HudPanel
extends PanelContainer
## The brush, ink count and checkpoint count, beneath the minimap at the top left.
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
## The gauge scales in whole art pixels to fit the minimap's width.

const GOLD := UISkin.GOLD
const CREAM := UISkin.CREAM_TEXT

## Four screen pixels per art pixel: 244px of brush inside the 256px map-width frame.
const GAUGE_SCALE := 4
const SIDE_PADDING := 6.0

var _value: Label
var _gauge: InkBrush
## The whole units the ink count last showed, so it pulses only when one comes or goes.
var _whole_ink := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override(&"panel", UISkin.frame(SIDE_PADDING))

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
	# drifting sideways as the readings below it change.
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


## THE CHECKPOINT COUNT, on the ink plate's own heading row rather than on a chip beside it.
##
## Thesis §4.5.3.5 puts the status line, the ink counter and the checkpoint indicator together
## at the top left, and a separate chip floating to the right of this plate was the piece the
## quest banner kept running into once the banner grew to two lines. On the heading row it is
## in the same corner, reading against the same ground, and the top band of the screen belongs
## to one thing again.
func adopt_checkpoints(label: Label) -> void:
	if label == null:
		return
	var parent := label.get_parent()
	if parent != null:
		parent.remove_child(label)
	var heading := $Column/Heading as HBoxContainer
	# A gap, so the flag does not read as part of the ink count beside it.
	var gap := Control.new()
	gap.name = "Gap"
	gap.custom_minimum_size = Vector2(12.0, 0.0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(gap)
	var mark := UIGlyph.new()
	mark.name = "Flag"
	mark.kind = UIGlyph.Kind.FLAG
	mark.custom_minimum_size = Vector2(12.0, 16.0)
	heading.add_child(mark)
	label.theme_type_variation = &"HudValue"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_child(label)


## THE LANTERN, where a level counts it as her health: a row of its own under the ink, in the same
## corner the thesis puts the things that are true whoever she currently is.
func adopt_lantern(health: PlayerHealth) -> LanternHud:
	var lantern := LanternHud.new()
	lantern.name = "Lantern"
	lantern.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lantern.bind(health)
	var column := $Column as VBoxContainer
	column.add_child(lantern)
	column.move_child(lantern, ($Column/Heading as Control).get_index() + 1)
	return lantern


## Whole units. `remaining` is continuous, so it is floored -- a gauge that rounds up claims
## ink the player does not have, and the one number they act on is "can I still draw
## something".
func set_ink(remaining: float, capacity: float, reserved: float) -> void:
	# The count answers when a whole unit comes or goes: a bigger pop for ink coming back.
	var whole := floori(maxf(0.0, remaining))
	if _whole_ink >= 0 and whole != _whole_ink:
		Motion.pulse(_value, Motion.PULSE_TO + 0.04 if whole > _whole_ink else 1.08)
	_whole_ink = whole
	_value.text = "%d of %d" % [whole, roundi(capacity)]
	_gauge.remaining = remaining
	_gauge.capacity = capacity
	_gauge.reserved = reserved
	_gauge.queue_redraw()
