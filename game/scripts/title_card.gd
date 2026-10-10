extends Control
## THE TITLE CARD: the vista, the logo and the tagline -- and, while something loads, the bar.
##
## Kent's design (October 2026): the apo looking out over the place the game is set, the logo
## at the top in the middle, "DRAW ◆ BECOME ◆ DISCOVER" under it, and at the foot a gold
## LOADING bar. One card for all three places it shows -- the import ImportGuard runs on a
## new or updated copy, the loading screen between boot and the menu, and the home screen
## itself -- so loading hands over to the menu without the picture moving: the bar goes, and
## the PLAY button is where it was.
##
## ⚠ NO class_name, AND IT NAMES NONE. ImportGuard shows this before anything is imported, on
## a copy with no class table yet; a script that names a class there does not compile.
## `from_source` loads the picture and the font straight from their files for that case.

enum Mode { HOME, LOADING, WAITING }

const VISTA := "res://assets/ui/title_vista.png"
const LOGO := "res://assets/ui/obra_logo.png"
const FONT := "res://ui/fonts/GeistPixel-Regular.ttf"

## Everything is laid out on the game's 1600 x 900 design frame, centred across the width:
## a wider window shows more vista at the sides, never a different layout.
const DESIGN := Vector2(1600.0, 900.0)
const LOGO_SCALE := 4.0
const LOGO_TOP := 96.0
const TAGLINE_Y := 432.0
const TAGLINE_SIZE := 34
const TAGLINE_WORDS: Array[String] = ["DRAW", "BECOME", "DISCOVER"]
const TAGLINE_GAP := 30.0
const STATUS_Y := 728.0
const STATUS_SIZE := 26
## The smaller words under the bar, a line apart.
const NOTE_Y := 834.0
const NOTE_SIZE := 18
const NOTE_LEADING := 26.0
## The bar's track, inside its frame. The PLAY button stands on this spot on the home screen.
const BAR := Rect2(565.0, 760.0, 470.0, 30.0)
## How far the vista drifts against the mouse on the home screen, at most.
const DRIFT := 10.0

const INK := Color("17120c")
const CREAM := Color(0.95, 0.92, 0.80)
const GOLD := Color("e9b43c")
const GOLD_LIGHT := Color("ffe39a")
const GOLD_DARK := Color("9a6516")
const TRACK := Color("25291f")

var mode := Mode.HOME:
	set(value):
		mode = value
		_redraw()
## 0..1, the LOADING bar's fill.
var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		_redraw()
## The word over the bar. Dots are added as it waits.
var status := "LOADING"
## Smaller words under the bar, saying what is happening: ImportGuard's. Shown in any mode.
var note := "":
	set(value):
		note = value
		_redraw()
## Load the picture and the font from their files, not from the import cache: for ImportGuard,
## which shows this while that cache is being made.
var from_source := false
## Whether the vista drifts with the mouse. The home screen's; a loading screen holds still.
var drifts := false

var _vista: TextureRect
var _logo: TextureRect
var _ink: Control
var _font: Font
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_vista = TextureRect.new()
	_vista.name = "Vista"
	_vista.texture = _picture(VISTA)
	_vista.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vista.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_vista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A little larger than the screen, so drifting never shows its edge.
	_vista.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]:
		_vista.set_offset(side, -DRIFT)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		_vista.set_offset(side, DRIFT)
	_vista.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_vista)
	_logo = TextureRect.new()
	_logo.name = "Logo"
	_logo.texture = _picture(LOGO)
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo)
	_ink = Control.new()
	_ink.name = "Ink"
	_ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink.draw.connect(_paint)
	add_child(_ink)
	_font = _typeface()
	resized.connect(_lay_out)
	_lay_out()


func _process(delta: float) -> void:
	_time += delta
	if mode != Mode.HOME:
		# The dots, and the waiting bar's sweep.
		_redraw()
	if drifts and _vista != null:
		var view := get_viewport_rect().size
		var toward := Vector2.ZERO
		if view.x > 0.0 and view.y > 0.0:
			toward = -(get_viewport().get_mouse_position() - view * 0.5) / view * DRIFT * 2.0
		# Held to DRIFT: a mouse far outside the window would otherwise show the picture's edge.
		toward = toward.clamp(-Vector2.ONE * DRIFT, Vector2.ONE * DRIFT)
		var rest := Vector2(-DRIFT, -DRIFT)
		_vista.position = _vista.position.lerp(rest + toward, 1.0 - exp(-4.0 * delta))


func _redraw() -> void:
	if _ink != null:
		_ink.queue_redraw()


## Where the design frame's left edge is on this screen: the frame is centred across the width.
func frame_left() -> float:
	return roundf((size.x - DESIGN.x) * 0.5)


## The bar's track on screen -- what the home screen puts its PLAY button over.
func bar_rect() -> Rect2:
	return Rect2(BAR.position + Vector2(frame_left(), 0.0), BAR.size)


func _lay_out() -> void:
	if _logo == null or _logo.texture == null:
		return
	var logo_size := _logo.texture.get_size() * LOGO_SCALE
	_logo.size = logo_size
	_logo.position = Vector2(roundf((size.x - logo_size.x) * 0.5), LOGO_TOP)
	_redraw()


## What is drawn over the picture: on _ink, not on this node, because a Control draws beneath
## its own children -- drawn here, the vista covered the tagline and the bar.
func _paint() -> void:
	if _font == null:
		return
	_draw_tagline()
	if mode != Mode.HOME:
		_draw_status()
		_draw_bar()
	_draw_note()


## "DRAW ◆ BECOME ◆ DISCOVER": the words in cream, outlined dark, with gold diamonds between.
func _draw_tagline() -> void:
	var widths: Array[float] = []
	var total := 0.0
	for word in TAGLINE_WORDS:
		var width := _font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, TAGLINE_SIZE).x
		widths.append(width)
		total += width
	total += TAGLINE_GAP * 2.0 * float(TAGLINE_WORDS.size() - 1)
	var x := roundf((size.x - total) * 0.5)
	var baseline := TAGLINE_Y + roundf(_font.get_ascent(TAGLINE_SIZE) * 0.5) - 2.0
	for index in range(TAGLINE_WORDS.size()):
		_word(Vector2(x, baseline), TAGLINE_WORDS[index], TAGLINE_SIZE)
		x += widths[index]
		if index < TAGLINE_WORDS.size() - 1:
			_diamond(Vector2(x + TAGLINE_GAP, TAGLINE_Y), 8.0)
			x += TAGLINE_GAP * 2.0


## LOADING, with dots that count up while it waits. The word stays put; the dots grow after it.
func _draw_status() -> void:
	var width := _font.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, STATUS_SIZE).x
	var x := roundf((size.x - width) * 0.5)
	var baseline := STATUS_Y + roundf(_font.get_ascent(STATUS_SIZE) * 0.5) - 2.0
	var dots := ".".repeat(1 + int(_time * 2.5) % 3)
	_word(Vector2(x, baseline), status + dots, STATUS_SIZE)


## The bar: a dark outline, a gold frame lit along its top, a dark track, the gold fill with a
## pale band along its top, and a gold diamond at each end.
func _draw_bar() -> void:
	var track := bar_rect()
	_ink.draw_rect(track.grow(7.0), INK)
	_ink.draw_rect(track.grow(5.0), GOLD_DARK)
	_ink.draw_rect(Rect2(track.grow(5.0).position, Vector2(track.size.x + 10.0, 3.0)), GOLD_LIGHT)
	_ink.draw_rect(track.grow(3.0), GOLD)
	_ink.draw_rect(track.grow(1.0), INK)
	_ink.draw_rect(track, TRACK)
	var fill := Rect2()
	if mode == Mode.WAITING:
		# Nothing to measure, so a band sweeps back and forth: the import is running, not stuck.
		var band := track.size.x * 0.3
		var sweep := (sin(_time * 2.2) * 0.5 + 0.5) * (track.size.x - band)
		fill = Rect2(track.position + Vector2(roundf(sweep), 0.0), Vector2(band, track.size.y))
	else:
		fill = Rect2(track.position, Vector2(roundf(track.size.x * progress), track.size.y))
	if fill.size.x >= 1.0:
		_ink.draw_rect(fill, GOLD)
		_ink.draw_rect(Rect2(fill.position, Vector2(fill.size.x, roundf(track.size.y * 0.3))), GOLD_LIGHT)
		_ink.draw_rect(Rect2(fill.position + Vector2(0.0, track.size.y - 4.0), Vector2(fill.size.x, 4.0)),
			GOLD_DARK)
	var middle := track.position.y + track.size.y * 0.5
	_diamond(Vector2(track.position.x - 14.0, middle), 13.0)
	_diamond(Vector2(track.end.x + 14.0, middle), 13.0)


## Under the bar -- or, with no bar, where the bar would be, so a note that has stopped the game
## stands in the middle of the foot rather than under nothing.
func _draw_note() -> void:
	var lines := note.split("\n")
	var top := NOTE_Y if mode != Mode.HOME else BAR.position.y
	for index in range(lines.size()):
		var width := _font.get_string_size(lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, NOTE_SIZE).x
		var at := Vector2(roundf((size.x - width) * 0.5), top + NOTE_LEADING * float(index))
		_ink.draw_string_outline(_font, at, lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, NOTE_SIZE, 6, INK)
		_ink.draw_string(_font, at, lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, NOTE_SIZE, CREAM)


func _word(at: Vector2, text: String, font_size: int) -> void:
	_ink.draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, INK)
	_ink.draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, CREAM)


## A gold diamond outlined in ink, lit on its upper-left faces.
func _diamond(centre: Vector2, half: float) -> void:
	var outline := half + 3.0
	_ink.draw_colored_polygon(PackedVector2Array([centre + Vector2(0, -outline),
		centre + Vector2(outline, 0), centre + Vector2(0, outline), centre + Vector2(-outline, 0)]),
		INK)
	_ink.draw_colored_polygon(PackedVector2Array([centre + Vector2(0, -half), centre + Vector2(half, 0),
		centre + Vector2(0, half), centre + Vector2(-half, 0)]), GOLD)
	_ink.draw_colored_polygon(PackedVector2Array([centre + Vector2(0, -half),
		centre + Vector2(0, 0), centre + Vector2(-half, 0)]), GOLD_LIGHT)
	_ink.draw_colored_polygon(PackedVector2Array([centre + Vector2(half, 0), centre + Vector2(0, half),
		centre + Vector2(0, 0)]), GOLD_DARK)


func _picture(path: String) -> Texture2D:
	if not from_source and ResourceLoader.exists(path):
		var imported := load(path) as Texture2D
		if imported != null:
			return imported
	var image := Image.load_from_file(path)
	return ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null


func _typeface() -> Font:
	if not from_source and ResourceLoader.exists(FONT):
		var imported := load(FONT) as Font
		if imported != null:
			return imported
	var raw := FontFile.new()
	if raw.load_dynamic_font(FONT) == OK:
		return raw
	return ThemeDB.fallback_font
