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

	var prompt := Label.new()
	prompt.text = "Draw anything that reminds you of this place."
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	memory.add_child(prompt)

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


func present(memory_name: String, reference: Texture2D) -> void:
	_name.text = memory_name
	_reference.texture = reference
	canvas.clear_canvas()
	open()


func _submit() -> void:
	if is_open() and canvas.has_ink():
		submitted.emit(canvas.get_strokes())
