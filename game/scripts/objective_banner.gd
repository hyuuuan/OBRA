class_name ObjectiveBanner
extends Control
## WHAT TO DO NOW: the quest, on a card at the top of the screen.
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
## ⚠ IT WAS A STATUS LINE, AND IT HAS TO READ AS THE QUEST. Kent: "the quest ui is not that
## visible or not making any sense of importance so fix that since it is needed". It was a thin
## dark chip with the level's name small over a line of caption-sized cream -- the same dress
## as the readouts round it, so nothing said that THIS was the thing to do. Now:
##
##   * it is a framed card, in the ink plate's own gold ring, not a chip;
##   * a gold QUEST tag heads it, with the world marker's diamond on it, so it says what it is;
##   * the task is set at body size, the size Lolo speaks at, whenever it fits -- and at the
##     caption size it used to be when a long one does not;
##   * and a new one ARRIVES: the card lifts and warms, the tag flares, a gleam crosses the
##     card, and the old line rises out as the new one comes up into its place. An objective
##     that changes silently is one the player does not notice has changed.
##
## ⚠ THE WORDS COME FROM THE LEVEL'S CONFIG, not from here, so the audit that keeps every
## line of dialogue from naming a class the player has not earned can read them too.

## ⚠ THE BADGE IS INSIDE THIS NOW, so this sits where the badge used to. Where the player is
## and what they are doing there were two chips stacked on top of each other under the top
## edge, with Lolo's box under the pair of them. They are one object: the place, small beside
## the tag, and the task under it.
const TOP := 12.0
## THE CARD'S LOWEST EDGE, whatever it says. Its height does not change with its words -- the
## task's line is one line tall at either size -- so the hint bar's ceiling and the lesson
## card's top are measured from here, and move with it if this ever grows.
const BOTTOM := 104.0
## The widest the task may run. The card stands between the ink plate (to x 418) and the
## morph card (from x 1202) on the narrowest screen the game is shown on; this, its padding and
## its ring are what fits in that gap with a little air either side.
const MAX_WIDTH := 720.0
## The task's two sizes: body when it fits MAX_WIDTH, caption when it does not. Every
## objective in the game fits at SMALL -- the level audits hold them to it.
const LARGE := UISkin.FONT_BODY
const SMALL := UISkin.FONT_CAPTION
## The task's line is this tall at either size, so the card never changes height.
const LINE_HEIGHT := 40.0
## Not narrower than this, so a short task still reads as a card and not a tag.
const MIN_WIDTH := 420.0
## A new task: how far the old line rises out and the new one comes up from.
const SLIDE := 22.0
const SLIDE_TIME := 0.32
## The gleam that crosses the card when the task changes.
const GLEAM_TIME := 0.85
const GLEAM_WIDTH := 0.16

var _panel: PanelContainer
var _column: VBoxContainer
var _heading: HBoxContainer
var _tag: PanelContainer
## The level's own name, kept by the level and drawn in here. Adopted rather than copied, so
## whatever writes "LEVEL 1 · PAYYO · ANG TULAY" goes on writing to the same label.
var _place: Label
## The task's line: the task, and the one before it on its way out.
var _line: Control
var _label: Label
var _was: Label
var _text := ""
var _flash: Tween
var _gleam := -1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override(&"panel", UISkin.frame(16.0, 10.0))
	_panel.draw.connect(_draw_gleam)
	add_child(_panel)

	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 4)
	_panel.add_child(_column)

	_heading = HBoxContainer.new()
	_heading.name = "Heading"
	_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heading.add_theme_constant_override(&"separation", 12)
	_column.add_child(_heading)
	_tag = _quest_tag()
	_heading.add_child(_tag)

	_line = Control.new()
	_line.name = "Line"
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.clip_contents = true
	_column.add_child(_line)
	_label = _task_label("Text")
	_line.add_child(_label)
	_was = _task_label("Was")
	_was.visible = false
	_line.add_child(_was)


## The gold tag that says what this card is: the world marker's diamond, and the word.
func _quest_tag() -> PanelContainer:
	var tag := PanelContainer.new()
	tag.name = "Quest"
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = UISkin.GOLD_FILL
	box.border_color = UISkin.GOLD_EDGE
	box.set_border_width_all(UISkin.THIN)
	box.content_margin_left = 8.0
	box.content_margin_right = 10.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	tag.add_theme_stylebox_override(&"panel", UISkin.rounded(box, UISkin.KEY_RADIUS))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 7)
	tag.add_child(row)
	var mark := Control.new()
	mark.name = "Mark"
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.custom_minimum_size = Vector2(10.0, 10.0)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.draw.connect(func() -> void:
		var c := mark.size * 0.5
		var r := minf(c.x, c.y)
		mark.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -r), c + Vector2(r, 0.0),
			c + Vector2(0.0, r), c + Vector2(-r, 0.0)]), UISkin.GOLD_LABEL))
	row.add_child(mark)
	var word := Label.new()
	word.name = "Word"
	word.text = "QUEST"
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	word.add_theme_font_size_override(&"font_size", SMALL)
	word.add_theme_color_override(&"font_color", UISkin.GOLD_LABEL)
	word.add_theme_color_override(&"font_shadow_color", Color.TRANSPARENT)
	row.add_child(word)
	return tag


func _task_label(label_name: String) -> Label:
	var label := Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override(&"font_color", UISkin.CREAM_TEXT)
	label.add_theme_font_size_override(&"font_size", SMALL)
	return label


## The badge moves in here, beside the tag. The level still owns the label and still writes the
## beat's name into it; this decides where it is drawn, and how loud: quieter than the task.
func adopt_place(label: Label) -> void:
	if label == null:
		return
	if label.get_parent() != null:
		label.get_parent().remove_child(label)
	_place = label
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override(&"font_size", SMALL)
	label.add_theme_color_override(&"font_color", UISkin.MUTED)
	_heading.add_child(label)
	label.resized.connect(_relayout)
	visible = true
	_relayout.call_deferred()


func _ready() -> void:
	get_viewport().size_changed.connect(_relayout)


func text() -> String:
	return _text


## Say what the player is doing now. The same text twice is nothing; a new one arrives.
func set_objective(value: String) -> void:
	if value == _text:
		return
	var previous := _text
	_text = value
	_label.text = value
	_label.add_theme_font_size_override(&"font_size", size_for(value))
	_line.visible = not value.is_empty()
	# The card stays up for the place line even with no task in it: the level's name is the
	# one thing on this screen that is always true.
	visible = _line.visible or (_place != null and not _place.text.is_empty())
	if not visible:
		return
	_relayout()
	_arrive(previous)


## The size the task is set at: body when it fits, caption when it does not.
func size_for(value: String) -> int:
	var font := _label.get_theme_font(&"font")
	if font == null:
		return SMALL
	var wide := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, LARGE).x
	return LARGE if wide <= MAX_WIDTH else SMALL


## A new task, made to be noticed: the card lifts and warms, the tag flares, a gleam crosses
## it, and the line before rises out as the new one comes up into its place.
func _arrive(previous: String) -> void:
	if _flash != null and _flash.is_valid():
		_flash.kill()
	_panel.pivot_offset = _panel.size * 0.5
	_panel.modulate = Color(1.45, 1.3, 0.9, 1.0)
	_panel.scale = Vector2(1.06, 1.06)
	_tag.modulate = Color(1.7, 1.5, 1.1, 1.0)
	_flash = create_tween()
	# Through a pause: a task that changes under a line of dialogue would otherwise stand
	# half-lifted, warm and gleaming, until the conversation ended.
	_flash.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_flash.set_parallel(true)
	_flash.tween_property(_panel, "modulate", Color.WHITE, 0.7)
	_flash.tween_property(_panel, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash.tween_property(_tag, "modulate", Color.WHITE, 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flash.tween_method(_set_gleam, 0.0, 1.0, GLEAM_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if previous.is_empty() or not _line.visible:
		_was.visible = false
		_label.position.y = 0.0
		_label.modulate.a = 1.0
	else:
		_was.text = previous
		_was.add_theme_font_size_override(&"font_size", size_for(previous))
		_was.position = Vector2.ZERO
		_was.modulate.a = 1.0
		_was.visible = true
		_label.position.y = SLIDE
		_label.modulate.a = 0.0
		_flash.tween_property(_was, "position:y", -SLIDE, SLIDE_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_flash.tween_property(_was, "modulate:a", 0.0, SLIDE_TIME)
		_flash.tween_property(_label, "position:y", 0.0, SLIDE_TIME).set_delay(0.12) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_flash.tween_property(_label, "modulate:a", 1.0, SLIDE_TIME).set_delay(0.12)
	_flash.chain().tween_callback(_settle)


## Everything a new task moved, back where it rests.
func _settle() -> void:
	_was.visible = false
	_label.position.y = 0.0
	_label.modulate.a = 1.0
	_set_gleam(-1.0)


func is_arriving() -> bool:
	return _flash != null and _flash.is_valid() and _flash.is_running()


func _set_gleam(at: float) -> void:
	_gleam = at
	_panel.queue_redraw()


## A slanted band of pale gold, crossing the card's ground under its words. Kept inside the
## ring, and faded in and out over its run.
func _draw_gleam() -> void:
	if _gleam < 0.0:
		return
	var inner := Rect2(Vector2.ONE * UISkin.RING, _panel.size - Vector2.ONE * UISkin.RING * 2.0)
	var band := inner.size.x * GLEAM_WIDTH
	var lean := inner.size.y * 0.6
	var x := lerpf(inner.position.x - band - lean, inner.end.x, _gleam)
	var strength := sin(_gleam * PI) * 0.28
	var points := PackedVector2Array([
		Vector2(x + lean, inner.position.y), Vector2(x + lean + band, inner.position.y),
		Vector2(x + band, inner.end.y), Vector2(x, inner.end.y)])
	for index in range(points.size()):
		points[index].x = clampf(points[index].x, inner.position.x, inner.end.x)
	_panel.draw_colored_polygon(points, Color(UISkin.GOLD_PALE, strength))


## Measured off the font, for the reason HintBar gives: a Label reports almost no minimum
## width of its own, and a card sized to it is a sliver.
func _relayout() -> void:
	var font := _label.get_theme_font(&"font")
	if font == null:
		return
	var task_size := _label.get_theme_font_size(&"font_size")
	var width := minf(font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, task_size).x,
		MAX_WIDTH)
	var heading := _tag.get_combined_minimum_size().x
	if _place != null:
		var place_font := _place.get_theme_font(&"font")
		var place_size := _place.get_theme_font_size(&"font_size")
		if place_font != null:
			var place_width := ceilf(minf(place_font.get_string_size(
				_place.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, place_size).x, MAX_WIDTH))
			_place.custom_minimum_size = Vector2(place_width, 0.0)
			heading += 12.0 + place_width
	var inner := ceilf(clampf(maxf(width, heading), MIN_WIDTH, MAX_WIDTH))
	_line.custom_minimum_size = Vector2(inner, LINE_HEIGHT if _line.visible else 0.0)
	_label.size = Vector2(inner, LINE_HEIGHT)
	_was.size = Vector2(inner, LINE_HEIGHT)
	_panel.reset_size()
	var wanted := _panel.get_combined_minimum_size()
	_panel.size = wanted
	_panel.position = Vector2(floorf((get_viewport_rect().size.x - wanted.x) * 0.5), TOP)
	_panel.pivot_offset = wanted * 0.5
