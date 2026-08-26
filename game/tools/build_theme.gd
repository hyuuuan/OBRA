extends SceneTree
## Writes `ui/obra_theme.tres` from the palette in `scripts/ui_skin.gd`.
##
##   godot --headless --path game --script res://tools/build_theme.gd
##
## The theme is GENERATED. Do not hand-edit `obra_theme.tres` -- change the skin and run
## this, the same arrangement `config/tags.json` and `tools/build_tags.py` already have.
## Hand-editing it works right up until someone regenerates and silently loses the edit.
##
## Written by Godot rather than by hand on purpose: a `.tres` assembled with a text editor
## fails to load without saying why, and there was no example in this repo to copy a header
## from. `ResourceSaver` always produces a file the engine can read back.

const OUT := "res://ui/obra_theme.tres"
## Geist Pixel, SIL Open Font License 1.1 -- see ui/fonts/OFL.txt. Imported with
## antialiasing, hinting and subpixel positioning all off, because it is a pixel face and
## all three of those exist to make an outline face look smooth off the grid.
const FONT := "res://ui/fonts/GeistPixel-Regular.ttf"

# Loaded rather than referenced by class_name: a `--script` run compiles before the global
# class cache is guaranteed, and a null here would write a theme of engine defaults.
const Palette = preload("res://scripts/ui_skin.gd")


func _initialize() -> void:
	var theme := Theme.new()
	theme.default_font_size = Palette.FONT_BODY
	# One font for the whole game, set as the DEFAULT rather than per type. Setting it on
	# Label alone leaves every Button, every slider readout and every tooltip on the
	# engine's face, which is the mismatch the theme exists to remove -- and it would show
	# up as "some of the text went 8-bit".
	var font := load(FONT) as Font
	if font == null:
		push_error("no font at %s" % FONT)
		quit(1)
		return
	theme.default_font = font

	# A LABEL ON A BUTTON IS THE ONE PIECE OF TYPE THAT HAS TO CARRY AT A GLANCE, and Geist
	# Pixel ships one weight. Rather than pull in a second face -- which would be a second
	# thing to keep consistent, and there is no bold Geist Pixel to pull -- the same font is
	# emboldened: FreeType dilates the outline before rasterising, so the stems thicken and
	# the glyph stays on its own grid. Kept small on purpose; a pixel face pushed hard
	# closes up its own counters and stops being readable at exactly the moment it looks
	# strongest in the editor.
	var bold := FontVariation.new()
	bold.base_font = font
	bold.variation_embolden = 0.08

	_labels(theme)
	_buttons(theme, bold)
	_panels(theme)
	_ranges(theme)

	var error := ResourceSaver.save(theme, OUT)
	if error != OK:
		push_error("could not write %s (%d)" % [OUT, error])
		quit(1)
		return
	print("wrote %s" % OUT)
	quit(0)


## Type is what a label is FOR, not how big it is. A caption is gold because captions label
## things; a hint is muted because it is the least important line on screen.
func _labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", Palette.CREAM_TEXT)
	theme.set_color("font_shadow_color", "Label", Palette.INK)
	theme.set_constant("shadow_offset_x", "Label", 2)
	theme.set_constant("shadow_offset_y", "Label", 2)
	theme.set_font_size("font_size", "Label", Palette.FONT_BODY)

	_label_variation(theme, "ScreenTitle", Palette.GOLD_PALE, Palette.FONT_TITLE)
	_label_variation(theme, "ScreenSubtitle", Palette.CREAM_TEXT, Palette.FONT_SUBTITLE)
	## The one that names a thing: INK, DRAW, GOAL. Small, gold, and always beside what
	## it names rather than above it.
	_label_variation(theme, "HudCaption", Palette.GOLD, Palette.FONT_CAPTION)
	## A number the player reads off a gauge.
	_label_variation(theme, "HudValue", Palette.CREAM_TEXT, Palette.FONT_CAPTION)
	## Text on a banner or a chip -- pale rather than full gold, because the saturated
	## accent at body weight is hard to read.
	_label_variation(theme, "HudBanner", Palette.GOLD_PALE, 17)

	## Outlined rather than shadowed: this one sits directly on level art, where a
	## two-pixel shadow disappears into whatever is behind it.
	theme.set_type_variation("HudHint", "Label")
	theme.set_color("font_color", "HudHint", Palette.MUTED)
	theme.set_color("font_outline_color", "HudHint", Palette.INK)
	theme.set_constant("outline_size", "HudHint", 4)
	theme.set_font_size("font_size", "HudHint", 14)


func _label_variation(theme: Theme, name: String, color: Color, size: int) -> void:
	theme.set_type_variation(name, "Label")
	theme.set_color("font_color", name, color)
	theme.set_font_size("font_size", name, size)


## Three families, and which one a button belongs to is a statement about what pressing it
## does. Cream is the default because most buttons navigate; gold is reserved for the act
## the screen exists for; red for the one that ends something.
func _buttons(theme: Theme, bold: Font) -> void:
	_family(theme, "Button", Palette.Family.CREAM, Palette.FONT_BUTTON, bold)
	_family(theme, "PrimaryButton", Palette.Family.GOLD, Palette.FONT_BUTTON, bold)
	_family(theme, "DangerButton", Palette.Family.RED, Palette.FONT_BUTTON, bold)
	_family(theme, "DialogButton", Palette.Family.CREAM, Palette.FONT_BUTTON, bold)

	## A level card is a panel you can press, not a button: it holds a title, a subtitle
	## and a lock state, so it wears the frame and brightens rather than changing colour.
	theme.set_type_variation("LevelCard", "Button")
	theme.set_stylebox("normal", "LevelCard", Palette.frame(16.0, 14.0))
	var lit := Palette.frame(16.0, 14.0)
	lit.bg_color = Palette.PANEL_LIT
	lit.border_color = Palette.GOLD_PALE
	theme.set_stylebox("hover", "LevelCard", lit)
	theme.set_stylebox("pressed", "LevelCard", lit)
	theme.set_stylebox("focus", "LevelCard", Palette.focus_ring())
	var locked := Palette.frame(16.0, 14.0)
	locked.bg_color = Palette.PANEL
	locked.border_color = Palette.OFF_EDGE
	locked.shadow_color = Palette.INK
	theme.set_stylebox("disabled", "LevelCard", locked)
	theme.set_color("font_color", "LevelCard", Palette.CREAM_TEXT)
	theme.set_color("font_hover_color", "LevelCard", Palette.GOLD_PALE)
	theme.set_color("font_disabled_color", "LevelCard", Palette.OFF_LABEL)

	## An inventory slot draws its own frame per state (see inventory_hud.gd) because the
	## state it cares about -- empty, holding, held -- is not a mouse state. All the theme
	## owes it is a transparent ground to draw on and a font for the slot number.
	theme.set_type_variation("InventorySlot", "Button")
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		theme.set_stylebox(state, "InventorySlot", StyleBoxEmpty.new())
	theme.set_font_size("font_size", "InventorySlot", Palette.FONT_CAPTION)


func _family(theme: Theme, name: String, family: int, size: int, bold: Font = null) -> void:
	if name != "Button":
		theme.set_type_variation(name, "Button")
	theme.set_stylebox("normal", name, Palette.button(family, Palette.State.NORMAL))
	theme.set_stylebox("hover", name, Palette.button(family, Palette.State.HOVER))
	theme.set_stylebox("pressed", name, Palette.button(family, Palette.State.PRESSED))
	theme.set_stylebox("disabled", name, Palette.button(family, Palette.State.DISABLED))
	theme.set_stylebox("focus", name, Palette.focus_ring())
	if bold != null:
		theme.set_font("font", name, bold)
	var label := Palette.label_color(family)
	theme.set_color("font_color", name, label)
	theme.set_color("font_hover_color", name, label)
	theme.set_color("font_pressed_color", name, label)
	theme.set_color("font_focus_color", name, label)
	theme.set_color("font_disabled_color", name, Palette.OFF_LABEL)
	theme.set_font_size("font_size", name, size)


func _panels(theme: Theme) -> void:
	for type in ["Panel", "PanelContainer", "PopupPanel"]:
		theme.set_stylebox("panel", type, Palette.frame(28.0, 24.0))
	## Scroll containers must not paint a second frame inside the one they sit in.
	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())


## A gauge and a slider are the same object seen twice: a trough cut into the panel with
## gold in it. They share the trough so they cannot drift apart.
func _ranges(theme: Theme) -> void:
	theme.set_stylebox("background", "ProgressBar", Palette.well())
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.GOLD
	fill.set_corner_radius_all(Palette.RADIUS)
	theme.set_stylebox("fill", "ProgressBar", fill)
	theme.set_color("font_color", "ProgressBar", Palette.CREAM_TEXT)

	# A trough with a thickness. A StyleBox with no content margins has no minimum height
	# and HSlider takes the track's height from exactly that, so the volume sliders were
	# drawn as a hairline with a handle threaded onto it.
	var track := Palette.well()
	track.content_margin_top = 6.0
	track.content_margin_bottom = 6.0
	theme.set_stylebox("slider", "HSlider", track)
	var grabbed := StyleBoxFlat.new()
	grabbed.bg_color = Palette.GOLD
	grabbed.set_corner_radius_all(Palette.RADIUS)
	theme.set_stylebox("grabber_area", "HSlider", grabbed)
	var grabbed_lit := StyleBoxFlat.new()
	grabbed_lit.bg_color = Palette.GOLD_PALE
	grabbed_lit.set_corner_radius_all(Palette.RADIUS)
	theme.set_stylebox("grabber_area_highlight", "HSlider", grabbed_lit)
	theme.set_constant("grabber_offset", "HSlider", 0)

	# The hairline under a screen's title. The engine's default separator is a grey line
	# that belongs to no palette, and it was showing through on every panel.
	# A HAIRLINE, not a bar. HSeparator draws this stylebox at its own minimum height and
	# gets its breathing room from the separation constant, so the margins here set the
	# thickness of the line and anything above 1 paints a slab across the panel.
	var rule := StyleBoxFlat.new()
	rule.bg_color = Palette.RING_MID
	rule.content_margin_top = 1.0
	rule.content_margin_bottom = 1.0
	theme.set_stylebox("separator", "HSeparator", rule)
	theme.set_constant("separation", "HSeparator", 16)

	theme.set_color("font_color", "CheckButton", Palette.CREAM_TEXT)
	theme.set_color("font_hover_color", "CheckButton", Palette.GOLD_PALE)
	theme.set_color("font_color", "CheckBox", Palette.CREAM_TEXT)
	theme.set_color("font_hover_color", "CheckBox", Palette.GOLD_PALE)
	for type in ["CheckButton", "CheckBox"]:
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			theme.set_stylebox(state, type, StyleBoxEmpty.new())
