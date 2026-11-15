extends ModalOverlay
## The player's submitted drawings, shown in order after the scene in the house.

const COLUMNS := 4
const PAGE_SIZE := COLUMNS * 3
const TILE_SIZE := Vector2(242.0, 158.0)
const GAP := 16

var _paths := PackedStringArray()
var _page := 0
var _grid: GridContainer
var _holder: CenterContainer
var _previous: Button
var _next: Button
var _page_label: Label
var _continue: Button
var _paper: StyleBoxFlat


func _ready() -> void:
	super()
	layer = 70
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(UISkin.INK, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override(&"panel", UISkin.frame(24, 22))
	centre.add_child(frame)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override(&"separation", GAP)
	frame.add_child(contents)
	var title := Label.new()
	title.text = "Your Drawings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", UISkin.FONT_TITLE)
	title.add_theme_color_override(&"font_color", UISkin.GOLD_PALE)
	contents.add_child(title)
	_holder = CenterContainer.new()
	contents.add_child(_holder)
	_grid = GridContainer.new()
	_grid.name = "Drawings"
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override(&"h_separation", GAP)
	_grid.add_theme_constant_override(&"v_separation", GAP)
	_holder.add_child(_grid)
	_paper = StyleBoxFlat.new()
	_paper.bg_color = Color(0.965, 0.95, 0.9)
	_paper.border_color = UISkin.GILT_DARK
	_paper.set_border_width_all(2)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override(&"separation", 14)
	contents.add_child(actions)
	_previous = _button(actions, "Previous", _step.bind(-1))
	_page_label = Label.new()
	actions.add_child(_page_label)
	_next = _button(actions, "Next", _step.bind(1))
	_continue = _button(actions, "Continue", close)
	_continue.theme_type_variation = &"PrimaryButton"


func _button(parent: Control, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.theme_type_variation = &"DialogButton"
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func present(paths: PackedStringArray) -> void:
	if paths.is_empty() or is_open():
		return
	_paths = paths
	_page = 0
	var rows := ceili(float(mini(PAGE_SIZE, paths.size())) / COLUMNS)
	if paths.size() == 1:
		rows = 2
	_holder.custom_minimum_size = Vector2(COLUMNS * (TILE_SIZE.x + GAP) - GAP,
		rows * (TILE_SIZE.y + GAP) - GAP)
	_show_page()
	open()
	_continue.grab_focus()


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right"):
		get_viewport().set_input_as_handled()
		_step(-1 if event.is_action_pressed(&"ui_left") else 1)


func _step(direction: int) -> void:
	var next_page := clampi(_page + direction, 0, (_paths.size() - 1) / PAGE_SIZE)
	if next_page != _page:
		_page = next_page
		_show_page()


func _show_page() -> void:
	for tile in _grid.get_children():
		_grid.remove_child(tile)
		tile.queue_free()
	var start := _page * PAGE_SIZE
	var count := mini(PAGE_SIZE, _paths.size() - start)
	for index in range(start, start + count):
		var tile := _SketchTile.new()
		tile.custom_minimum_size = TILE_SIZE * 2.0 + Vector2.ONE * GAP if count == 1 else TILE_SIZE
		tile.add_theme_stylebox_override(&"panel", _paper)
		_grid.add_child(tile)
		tile.show_drawing(_paths[index])
	var pages := ceili(float(_paths.size()) / PAGE_SIZE)
	_previous.visible = pages > 1
	_next.visible = pages > 1
	_page_label.visible = pages > 1
	_previous.disabled = _page == 0
	_next.disabled = _page == pages - 1
	_page_label.text = "%d / %d" % [_page + 1, pages]


class _SketchTile extends Panel:
	var _art := Node2D.new()
	var _bounds := Rect2()

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_art)
		resized.connect(_fit)

	func show_drawing(path: String) -> void:
		if path.ends_with(".png"):
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			if image != null and not image.is_empty():
				var sprite := Sprite2D.new()
				sprite.texture = ImageTexture.create_from_image(image)
				sprite.centered = false
				_art.add_child(sprite)
				_bounds.size = Vector2(image.get_size())
		else:
			var file := FileAccess.open(path, FileAccess.READ)
			var data: Variant = file.get_var() if file != null else null
			if data is Array:
				for stroke: Variant in data:
					if stroke is Dictionary and stroke.get("points") is PackedVector2Array:
						_add_stroke(stroke)
		_fit()

	func _add_stroke(stroke: Dictionary) -> void:
		var points: PackedVector2Array = stroke["points"]
		if points.size() < 2:
			return
		var line := Line2D.new()
		line.points = points
		line.default_color = stroke.get("color", Color.BLACK)
		line.width = float(stroke.get("width", 8.0))
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		var bounds := Rect2(points[0], Vector2.ZERO)
		for point in points:
			bounds = bounds.expand(point)
		bounds = bounds.grow(line.width * 0.5)
		_bounds = _bounds.merge(bounds) if _bounds.has_area() else bounds
		_art.add_child(line)

	func _fit() -> void:
		if not _bounds.has_area() or size.x < 28.0 or size.y < 28.0:
			return
		var available := size - Vector2(28.0, 28.0)
		var factor := minf(available.x / _bounds.size.x, available.y / _bounds.size.y)
		_art.scale = Vector2.ONE * factor
		_art.position = size * 0.5 - _bounds.get_center() * factor
