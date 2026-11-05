extends ModalOverlay
## A sketchbook page for one memory. The canvas keeps the player's strokes in
## screen space and the level decides whether it can commit the preservation.

signal submitted(strokes: Array)

const DrawingCanvas = preload("res://scripts/drawing_canvas.gd")

class SketchPaper extends DrawingCanvas:
	func accepts(at: Vector2) -> bool:
		return Rect2(Vector2.ZERO, size).has_point(at)


var canvas: SketchPaper
var preserve_button: Button
var _name: Label
var _reference: TextureRect
## THE MEMORY ITSELF, FAINT ON THE PAPER (Kent, 2026-11-05: "the instructions are very unclear like
## how are they supposed to know what to draw in that moment"). A blank page and "draw anything"
## left a player guessing; the picture on the paper is the answer -- trace it, or sketch it freely.
## A sibling under the strokes: it is never part of what she drew (get_strokes is her lines only).
var _trace: TextureRect
var _ink_left: Label
## How faint the picture to trace is: there to follow, never mistaken for her own lines.
const TRACE_ALPHA := 0.22


func _ready() -> void:
	super()
	layer = 10

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(UISkin.INK, 0.76)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", UISkin.frame(24, 22))
	centre.add_child(panel)

	var contents := VBoxContainer.new()
	contents.add_theme_constant_override(&"separation", 16)
	panel.add_child(contents)

	var title := Label.new()
	title.text = "PRESERVE A MEMORY"
	title.add_theme_font_size_override(&"font_size", UISkin.FONT_TITLE)
	title.add_theme_color_override(&"font_color", UISkin.GOLD_PALE)
	contents.add_child(title)

	var pages := HBoxContainer.new()
	pages.add_theme_constant_override(&"separation", 24)
	contents.add_child(pages)

	var paper := ColorRect.new()
	paper.color = Color(0.965, 0.95, 0.9)
	paper.custom_minimum_size = Vector2(680, 440)
	paper.clip_contents = true
	pages.add_child(paper)

	_trace = TextureRect.new()
	_trace.name = "TraceGuide"
	_trace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_trace.offset_left = 40
	_trace.offset_top = 30
	_trace.offset_right = -40
	_trace.offset_bottom = -30
	_trace.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_trace.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_trace.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_trace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trace.modulate = Color(0.55, 0.47, 0.38, TRACE_ALPHA)
	paper.add_child(_trace)

	canvas = SketchPaper.new()
	canvas.name = "MemoryPaper"
	canvas.mouse_default_cursor_shape = Control.CURSOR_CROSS
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.add_child(canvas)
	canvas.stroke_cost_changed.connect(func(cost: float) -> void: preserve_button.disabled = cost <= 0.0)

	var memory := VBoxContainer.new()
	memory.custom_minimum_size.x = 300
	memory.add_theme_constant_override(&"separation", 14)
	pages.add_child(memory)

	_name = Label.new()
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.add_theme_font_size_override(&"font_size", UISkin.FONT_SUBTITLE)
	_name.add_theme_color_override(&"font_color", UISkin.GOLD_PALE)
	memory.add_child(_name)

	_reference = TextureRect.new()
	_reference.name = "LandmarkReference"
	_reference.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reference.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_reference.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_reference.custom_minimum_size.y = 220
	memory.add_child(_reference)

	# What to do, in the order she does it: the picture is the subject, any lines are enough, and
	# what it costs and where it goes. Short lines at caption size, never under 20px.
	for step: String in ["1  Trace or sketch the picture", "2  A few lines are enough",
			"3  Press Preserve - 1 ink"]:
		var line := Label.new()
		line.name = "Step%s" % step.left(1)
		line.text = step
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
		line.add_theme_color_override(&"font_color", UISkin.CREAM_TEXT)
		memory.add_child(line)
	var after := Label.new()
	after.name = "WhereItGoes"
	after.text = "It returns with you at the summit."
	after.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	after.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	after.add_theme_color_override(&"font_color", UISkin.MUTED)
	memory.add_child(after)
	_ink_left = Label.new()
	_ink_left.name = "InkLeft"
	_ink_left.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	_ink_left.add_theme_color_override(&"font_color", UISkin.GOLD_PALE)
	memory.add_child(_ink_left)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override(&"separation", 12)
	contents.add_child(actions)

	preserve_button = Button.new()
	preserve_button.text = "Preserve · 1 ink"
	preserve_button.theme_type_variation = &"PrimaryButton"
	preserve_button.pressed.connect(_submit)
	actions.add_child(preserve_button)

	var clear := Button.new()
	clear.text = "Clear"
	clear.pressed.connect(canvas.clear_canvas)
	actions.add_child(clear)

	var leave := Button.new()
	leave.text = "Close"
	leave.pressed.connect(close)
	actions.add_child(leave)


## `ink_left`: whole units she has, shown so the choice is hers to weigh; below zero, not shown.
func present(memory_name: String, reference: Texture2D, ink_left: int = -1) -> void:
	_name.text = memory_name
	_reference.texture = reference
	_trace.texture = reference
	_ink_left.text = "Ink left: %d" % ink_left if ink_left >= 0 else ""
	_ink_left.visible = ink_left >= 0
	canvas.clear_canvas()
	open()


## What the page tells her to do, in order -- for a probe.
func instructions() -> String:
	var out: PackedStringArray = []
	for child in find_children("Step*", "Label", true, false) + find_children("WhereItGoes", "Label", true, false) \
			+ find_children("InkLeft", "Label", true, false):
		if (child as Label).is_visible_in_tree():
			out.append((child as Label).text)
	return "\n".join(out)


func _submit() -> void:
	if is_open() and canvas.has_ink():
		submitted.emit(canvas.get_strokes())
