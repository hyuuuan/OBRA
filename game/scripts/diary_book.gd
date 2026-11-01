class_name DiaryBook
extends Control
## Her diary, as a book whose pages turn: the bag's DIARY tab, and the page shown as it is found.
##
## THE BOOK IS KENT'S CHOICE OF ART (HUD-assets-ideas/Book-Inventory-Animation.gif): "it should
## flip like a book ... but i only want the book not the tabs because i already have an inventory
## tabs thing". tools/build_diary_book.py keeps its eight-frame page turn and keys the ribbon tabs
## out; this shows it at a whole-pixel scale and sets her words on the pages in Godot.
##
## A SPREAD IS TWO PAGES, and an entry always starts on the left one: a page of hers sharing a
## spread with the end of an older entry would read as one day running into the next. An entry
## with an odd number of pages leaves its right page blank.
##
## THE WORDS ARE OFF THE PAGE WHILE IT TURNS, as in the source animation, whose pages are blank
## in flight. The turn is held to Motion's pixel rate, and with reduced motion there is no turn:
## the spread simply changes.
##
## Keys and the wheel are the owner's to route (the bag already answers them in `_input`); this
## answers a click: on the left page, back; on the right, on.

## A page was turned, or the book was opened somewhere new.
signal turned(spread: int)

const SHEET := preload("res://assets/hud/diary_book.png")
const FRAME := Vector2i(134, 112)
## Frames 0..6 are a page in flight from right to left; 7 is the book at rest.
const REST := 7
## Six times: the most the bag's lining takes without growing past a 900-tall screen (the
## lining is 667 tall; the book is 672), and enough for a page to hold her lines at 20 px.
const SCALE := 6
## The paper of each page at rest, in the sheet's own pixels (measured off frame 7).
const PAPER: Array[Rect2i] = [Rect2i(8, 10, 57, 89), Rect2i(70, 10, 59, 89)]
## How far her writing keeps off the paper's edges (left, top, right, bottom), in sheet pixels.
## The bottom keeps a line for the page number.
const MARGIN := [5, 4, 5, 13]
## Where the page number sits, up from the paper's bottom edge, in sheet pixels.
const FOLIO_UP := 11

## The bag's parchment ink and its painter's red and quiet brown (InventoryScreen), so the diary
## reads as written in the same hand as the labels around it.
const INK := Color(0.227, 0.149, 0.094)        # 3A2618
const DATE_INK := Color(0.604, 0.247, 0.133)   # 9A3F22
const FOLIO_INK := Color(0.364, 0.276, 0.188)  # 5D4630
const NO_SHADOW := Color(0, 0, 0, 0)
const LINE_GAP := 2

## What the book says before any page is in it. Says the pages are out there, names nothing.
const EMPTY := "Her diary. Most of it is loose pages now, and they are somewhere in her paintings."

## Each: {"entry": id, "pages": [bbcode, bbcode], "numbers": [int, int]}. Never empty.
var _spreads: Array[Dictionary] = []
## "entry_id" and "entry_id#anchor" -> the spread that page is on.
var _anchors: Dictionary = {}
var _at := 0
var _frame := REST
## +1 or -1 while a page is in flight; 0 at rest.
var _turning := 0
var _clock := 0.0
var _pages: Array[RichTextLabel] = []
var _folios: Array[Label] = []


func _init() -> void:
	custom_minimum_size = Vector2(FRAME * SCALE)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var font := ThemeDB.get_project_theme().default_font
	for side in range(2):
		var area := text_rect(side)
		var page := RichTextLabel.new()
		page.name = "LeftPage" if side == 0 else "RightPage"
		page.bbcode_enabled = true
		page.scroll_active = false
		page.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.position = area.position
		page.size = area.size
		_letter(page, font)
		add_child(page)
		_pages.append(page)
		var folio := Label.new()
		folio.name = "LeftNumber" if side == 0 else "RightNumber"
		folio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		folio.mouse_filter = Control.MOUSE_FILTER_IGNORE
		folio.add_theme_font_override(&"font", font)
		folio.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
		folio.add_theme_color_override(&"font_color", FOLIO_INK)
		folio.add_theme_color_override(&"font_shadow_color", NO_SHADOW)
		var paper := PAPER[side]
		folio.position = Vector2(paper.position.x * SCALE, (paper.end.y - FOLIO_UP) * SCALE)
		folio.size = Vector2(paper.size.x * SCALE, UISkin.FONT_CAPTION + 8)
		add_child(folio)
		_folios.append(folio)
	set_entries([])


## Where a page's words go, in this control's pixels. Static so a probe can lay a page out
## without a book.
static func text_rect(side: int) -> Rect2:
	var paper := PAPER[side]
	var left := paper.position.x + int(MARGIN[0])
	var top := paper.position.y + int(MARGIN[1])
	var right := paper.end.x - int(MARGIN[2])
	var bottom := paper.end.y - int(MARGIN[3])
	return Rect2(left * SCALE, top * SCALE, (right - left) * SCALE, (bottom - top) * SCALE)


## A label set in her hand: the game's pixel face at the caption size, ink with no shadow (ink on
## paper casts none; the theme's shadow doubles every stroke on cream -- see InventoryScreen).
static func _letter(page: RichTextLabel, font: Font) -> void:
	page.add_theme_font_override(&"normal_font", font)
	page.add_theme_font_size_override(&"normal_font_size", UISkin.FONT_CAPTION)
	page.add_theme_color_override(&"default_color", INK)
	page.add_theme_color_override(&"font_shadow_color", NO_SHADOW)
	page.add_theme_constant_override(&"line_separation", LINE_GAP)


## A page as the book sets it: the date she headed it with on an entry's first page.
static func page_bbcode(entry: Dictionary, index: int) -> String:
	var pages: Array = entry.get("pages", [])
	if index < 0 or index >= pages.size():
		return ""
	var text := Diary.page_text(pages[index])
	var date := String(entry.get("date", ""))
	if index == 0 and not date.is_empty():
		return "[color=#%s]%s[/color]\n\n%s" % [DATE_INK.to_html(false), date, text]
	return text


## How tall a page's words stand, set on the page they go on. A scratch label, laid out in the real
## font at the real size: what fits here fits in the book.
## ⚠ IN THE TREE, OR IT MEASURES NOTHING. A RichTextLabel outside the tree never lays its text
## out, and get_content_height() said a page three times too long fitted.
static func content_height(entry: Dictionary, index: int, side: int) -> int:
	var page := RichTextLabel.new()
	page.bbcode_enabled = true
	page.scroll_active = false
	page.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_letter(page, ThemeDB.get_project_theme().default_font)
	page.size = text_rect(side).size
	page.text = page_bbcode(entry, index)
	(Engine.get_main_loop() as SceneTree).root.add_child(page)
	var tall := page.get_content_height()
	page.free()
	return tall


## Whether a page's words run past the bottom of the page they are set on.
static func overflows(entry: Dictionary, index: int, side: int) -> bool:
	return content_height(entry, index, side) > int(text_rect(side).size.y)


## What the book holds: these entries, in this order. Keeps the spread it was open at where it
## can (the bag refreshes it while it is being read).
func set_entries(list: Array[Dictionary]) -> void:
	_spreads.clear()
	_anchors.clear()
	var number := 1
	for entry in list:
		var id := String(entry.get("id", ""))
		var pages: Array = entry.get("pages", [])
		_anchors[id] = _spreads.size()
		for index in range(0, pages.size(), 2):
			for side in range(2):
				var anchor := Diary.page_anchor(pages[index + side]) if index + side < pages.size() else ""
				if not anchor.is_empty():
					_anchors["%s#%s" % [id, anchor]] = _spreads.size()
			var right_number := number + 1 if index + 1 < pages.size() else 0
			_spreads.append({
				"entry": id,
				"pages": [page_bbcode(entry, index), page_bbcode(entry, index + 1)],
				"numbers": [number, right_number],
			})
			number += 2
	if _spreads.is_empty():
		_spreads.append({"entry": "", "pages": [EMPTY, ""], "numbers": [0, 0]})
	_at = clampi(_at, 0, _spreads.size() - 1)
	_turning = 0
	_frame = REST
	_show_spread()
	queue_redraw()


## Open at an entry's first page, or at the page of it a level asked for. No turn: the book is
## opened there. False if it is not in the book.
func open_at(entry_id: String, anchor: String = "") -> bool:
	var key := entry_id if anchor.is_empty() else "%s#%s" % [entry_id, anchor]
	if not _anchors.has(key):
		return false
	_at = int(_anchors[key])
	_turning = 0
	_frame = REST
	_show_spread()
	queue_redraw()
	turned.emit(_at)
	return true


## Turn a page: +1 on, -1 back. False at either end of the book, or with a page already in flight.
func turn(direction: int) -> bool:
	if _turning != 0 or direction == 0:
		return false
	var to := _at + signi(direction)
	if to < 0 or to >= _spreads.size():
		return false
	_at = to
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio != null:
		audio.call(&"play_sfx", &"page_turn")
	if Motion.reduced():
		_show_spread()
		turned.emit(_at)
		return true
	_turning = signi(direction)
	_clock = 0.0
	_frame = 0 if _turning > 0 else REST - 1
	for page in _pages:
		page.visible = false
	for folio in _folios:
		folio.visible = false
	queue_redraw()
	return true


func spread_index() -> int:
	return _at


func spread_count() -> int:
	return _spreads.size()


func is_turning() -> bool:
	return _turning != 0


## The frame of the sheet on show, for a probe watching a turn.
func frame() -> int:
	return _frame


## Which entry the open spread belongs to ("" for the empty book).
func entry_on_show() -> String:
	return String(_spreads[_at].get("entry", ""))


## The words on the open spread as a reader sees them, left then right ("" while in flight).
func page_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for page in _pages:
		out.append(page.get_parsed_text() if page.visible else "")
	return out


func _process(delta: float) -> void:
	if _turning == 0:
		return
	# ONE FRAME A TICK AT MOST. A hitch slows the turn rather than skipping a drawing of it:
	# there are only seven, and a page that jumps from lifting to half over reads as a glitch.
	_clock += delta
	var step := 1.0 / Motion.PIXEL_FPS
	if _clock < step:
		return
	_clock -= step
	_frame += _turning
	if (_turning > 0 and _frame >= REST) or (_turning < 0 and _frame < 0):
		_frame = REST
		_turning = 0
		_show_spread()
		turned.emit(_at)
	queue_redraw()


func _show_spread() -> void:
	var spread := _spreads[_at]
	var pages: Array = spread["pages"]
	var numbers: Array = spread["numbers"]
	for side in range(2):
		_pages[side].text = String(pages[side])
		_pages[side].visible = true
		var number := int(numbers[side])
		_folios[side].text = str(number) if number > 0 else ""
		_folios[side].visible = number > 0


func _draw() -> void:
	draw_texture_rect_region(SHEET, Rect2(Vector2.ZERO, Vector2(FRAME * SCALE)),
		Rect2(_frame * FRAME.x, 0, FRAME.x, FRAME.y))


## A click on the left page goes back, on the right page on.
func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	turn(-1 if click.position.x < size.x * 0.5 else 1)
