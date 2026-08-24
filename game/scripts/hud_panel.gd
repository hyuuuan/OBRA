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
##
## Every colour here comes from UISkin. The frame factories stay on this class because
## draw_panel and game_level already call them by name.

const LIME := UISkin.LIME
const CREAM := UISkin.CREAM_TEXT

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
	heading.name = "Heading"
	heading.add_theme_constant_override(&"separation", 7)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	_gauge = Gauge.new()
	_gauge.name = "Gauge"
	_gauge.custom_minimum_size = Vector2(0.0, 16.0)
	column.add_child(_gauge)


## The status line lives inside the frame rather than floating on the level behind it, so
## it has something to be read against. It stays the node the rest of game_level already
## writes to -- there are thirty of those call sites and none of them need to know.
##
## Muted, and deliberately quieter than the gauge above it. It is the least urgent thing
## in the frame: the gauge is a resource the player is spending, this is the game saying
## what just happened.
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
	return UISkin.chip()


static func frame() -> StyleBoxFlat:
	return UISkin.frame()


## The gauge. Drawn rather than a ProgressBar because it carries two quantities: what is
## left, and how much of it the sketch on the canvas is about to cost. A player mid-drawing
## needs to see the second one eating the first.
##
## ONE BLOCK PER UNIT, with a gap between them. It was a continuous bar with hairlines
## scratched across it, which is a bar with marks on it -- you read the length and then
## have to count the marks to turn it into a number. Twelve separate blocks IS the number:
## the ink budget is twelve discrete things you can spend and the gauge should look like
## twelve discrete things.
class Gauge extends Control:
	const TROUGH := UISkin.INK
	const EDGE := UISkin.RING_MID
	const FILL := UISkin.LIME
	## Ink the current sketch has claimed but not yet spent. Warm, because it is not gone
	## and clearing the canvas hands it straight back.
	const PENDING := UISkin.PENDING
	## Between blocks. Held constant rather than scaled with the gauge, because it is a
	## gap and a gap that grows reads as a second colour.
	const GUTTER := 3.0

	var remaining := 12.0
	var capacity := 12.0
	var reserved := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), TROUGH)
		draw_rect(Rect2(Vector2.ZERO, size), EDGE, false, 2.0)

		var units := maxi(1, roundi(capacity))
		var span := maxf(0.001, capacity)
		var inset := 2.0
		var track := size.x - inset * 2.0 - GUTTER * float(units - 1)
		if track <= 0.0:
			return
		var block := track / float(units)
		var spent_at := clampf(remaining / span, 0.0, 1.0) * span
		var claimed_to := clampf((remaining + maxf(0.0, reserved)) / span, 0.0, 1.0) * span

		for index in range(units):
			# What this one block covers of the budget, so a block straddling the boundary
			# is drawn part full and part warm rather than rounded to whichever wins.
			var low := float(index) / float(units) * span
			var high := float(index + 1) / float(units) * span
			var left := inset + float(index) * (block + GUTTER)
			var top := inset
			var height := size.y - inset * 2.0
			_band(left, top, block, height, low, high, 0.0, spent_at, FILL)
			_band(left, top, block, height, low, high, spent_at, claimed_to, PENDING)

	## Paint the part of one block that falls inside [from, to] of the budget.
	func _band(left: float, top: float, block: float, height: float,
			low: float, high: float, from: float, to: float, color: Color) -> void:
		var start := maxf(low, from)
		var end := minf(high, to)
		if end <= start:
			return
		var unit := high - low
		var x := left + (start - low) / unit * block
		var width := (end - start) / unit * block
		if width <= 0.0:
			return
		draw_rect(Rect2(Vector2(x, top), Vector2(width, height)), color)
