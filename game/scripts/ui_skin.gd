class_name UISkin
## Every colour and every frame in the interface, in one file.
##
## The HUD used to be styled in five places at once: constants in `hud_panel.gd`, more in
## `inventory_hud.gd`, StyleBoxes built inline in `draw_panel.gd`, sub-resources typed into
## `ui/main_menu.tscn`, and `ui/obra_theme.tres`. They agreed by hand and drifted the moment
## anything moved. Changing the look of the game meant finding all five.
##
## Now there is one: this file is the skin, `ui/obra_theme.tres` is GENERATED from it by
## `tests/build_theme.gd`, and everything that draws its own frame calls a factory here.
## To restyle the game, change the palette below and re-run the generator.
##
## The look is the 8-bit HUD sheet in `HUD-assets-ideas/`. Read `HUD_SKIN.md` for the
## anatomy, the one place Godot cannot reproduce the mockup exactly, and why.

# --- Ground -----------------------------------------------------------------------------
## Deepest black-green. Behind everything, and the scrim tends toward it.
const INK := Color(0.027, 0.035, 0.024, 1.0)          # 070906
## The fill inside a framed panel.
const PANEL := Color(0.051, 0.063, 0.035, 1.0)        # 0D1009
## A surface raised off the panel: a slot, a sheet, the strip behind a row of buttons.
const PANEL_LIT := Color(0.086, 0.094, 0.063, 1.0)    # 161810
## The dark ring that separates a frame from bright level art behind it.
const RING_OUTER := Color(0.118, 0.133, 0.063, 1.0)   # 1E2210
## The olive between the outer ring and the bright one. See HUD_SKIN.md -- Godot's
## StyleBoxFlat affords three tones, so this is the ring that gets dropped on small chips.
const RING_MID := Color(0.290, 0.329, 0.094, 1.0)     # 4A5418

# --- Accent -----------------------------------------------------------------------------
## THE colour of this interface. Every frame's bright ring, every meter's fill, every
## caption. If one value defines the look, it is this one.
const LIME := Color(0.788, 0.851, 0.290, 1.0)         # C9D94A
## Headline text on a dark fill -- a banner, a title. Lime is too saturated to read as type.
const LIME_PALE := Color(0.875, 0.914, 0.549, 1.0)    # DFE98C
## Body text on a dark fill.
const CREAM_TEXT := Color(0.910, 0.890, 0.769, 1.0)   # E8E3C4
## Secondary text: a status line, a caption, an empty slot's number.
##
## Was 78805A, which measured like a sensible "quiet" olive and was in practice unreadable:
## against PANEL it has barely two stops of contrast, and at HUD sizes the status line --
## the one that tells you why the game just refused something -- was the hardest text on
## screen to read. Quiet is a job for size and placement. Not for hiding it.
const MUTED := Color(0.663, 0.706, 0.529, 1.0)        # A9B487
## Ink the current sketch has claimed but not yet spent. Warm, because clearing the
## canvas hands it straight back.
const PENDING := Color(0.980, 0.900, 0.310, 1.0)      # FAE64F

# --- The frame -------------------------------------------------------------------------
## Dark wood and a gold liner, and the only warm colours in the interface.
##
## Deliberately not lime. The frame is a PAINTING'S frame, not a piece of UI chrome, and
## the whole point of framing the story is that it is a different kind of thing from the
## menu it opens over. Sharing the HUD's palette would have undone that.
##
## Restrained on purpose too. The first cut was a bright vermillion-and-gold thing with a
## crest and stepped corners, which is a fairground frame -- it drew more attention than
## the words inside it, which is the one thing a frame must never do.
const WOOD_EDGE := Color(0.078, 0.047, 0.024, 1.0)    # 140C06  the outer keyline
const WOOD_DARK := Color(0.180, 0.106, 0.055, 1.0)    # 2E1B0E  the shaded side
const WOOD := Color(0.290, 0.180, 0.102, 1.0)         # 4A2E1A  the body of the moulding
const WOOD_LIT := Color(0.420, 0.271, 0.149, 1.0)     # 6B4526  the side the light hits
## The gold liner between the wood and the picture. One pixel of it is the whole difference
## between a brown rectangle and a frame.
const FILLET := Color(0.690, 0.541, 0.235, 1.0)       # B08A3C
const FILLET_LIT := Color(0.847, 0.725, 0.408, 1.0)   # D8B968
## The mount the picture sits on, inside the rabbet.
const MAT := Color(0.220, 0.161, 0.110, 1.0)          # 38291C

# --- The gilt oval ----------------------------------------------------------------------
## Lifted off the wordmark, which is where this shape comes from: the O of OBRA is an
## ornate oval mirror with a little landscape inside it, and the canvas the player draws on
## is the same object -- you look into it and something appears.
##
## Six stops rather than the wood frame's four, because an oval has no flat sides to carry
## a bevel. A rectangle can be shaded with one light edge and one dark one; a ring is lit
## differently at every point around it, so it needs enough steps to turn smoothly and not
## band into a string of beads.
const GILT_HI := Color(0.984, 0.898, 0.404, 1.0)      # FBE567  the catch of light
const GILT_LIT := Color(0.929, 0.792, 0.322, 1.0)     # EDCA52
const GILT := Color(0.859, 0.655, 0.212, 1.0)         # DBA736  the body of the moulding
const GILT_MID := Color(0.784, 0.588, 0.216, 1.0)     # C89637
const GILT_DARK := Color(0.647, 0.447, 0.137, 1.0)    # A57223
const GILT_EDGE := Color(0.549, 0.341, 0.114, 1.0)    # 8C571D  the keyline and the shadow

## Light comes from up and to the left, which is where it comes from in the wordmark. Every
## bevel in the frame is derived from this one vector rather than from a per-part guess.
const GILT_LIGHT := Vector2(-0.7071, -0.7071)


# --- Button anatomy ---------------------------------------------------------------------
## The grey highlight ring immediately inside a button's edge. Identical across all three
## families in the mockup -- it is what makes a button read as raised rather than painted.
const BEVEL := Color(0.302, 0.306, 0.282, 1.0)        # 4D4E48
## The near-black keyline outside a button. Almost invisible against PANEL_LIT by design;
## it exists to hold the shape against a lighter background.
const KEYLINE := Color(0.094, 0.078, 0.039, 1.0)      # 18140A

## Green: the thing you came here to do. START, RESUME, CONFIRM, TRANSFORM.
const GREEN_FILL := Color(0.588, 0.741, 0.345, 1.0)   # 96BD58
const GREEN_LIT := Color(0.659, 0.804, 0.424, 1.0)    # A8CD6C
const GREEN_DARK := Color(0.471, 0.588, 0.267, 1.0)   # 789644
const GREEN_EDGE := Color(0.345, 0.439, 0.188, 1.0)   # 587030
const GREEN_LABEL := Color(0.071, 0.094, 0.031, 1.0)  # 121808

## Cream: everything else. BACK, SETTINGS, CONTROLS, the level cards.
const CREAM_FILL := Color(0.910, 0.890, 0.769, 1.0)   # E8E3C4
const CREAM_LIT := Color(0.961, 0.945, 0.839, 1.0)    # F5F1D6
const CREAM_DARK := Color(0.804, 0.780, 0.651, 1.0)   # CDC7A6
const CREAM_EDGE := Color(0.188, 0.157, 0.071, 1.0)   # 302812
const CREAM_LABEL := Color(0.118, 0.102, 0.055, 1.0)  # 1E1A0E

## Red: the one that ends something. CANCEL, EXIT, QUIT.
const RED_FILL := Color(0.769, 0.376, 0.282, 1.0)     # C46048
const RED_LIT := Color(0.839, 0.463, 0.376, 1.0)      # D67660
const RED_DARK := Color(0.627, 0.306, 0.227, 1.0)     # A04E3A
const RED_EDGE := Color(0.471, 0.220, 0.165, 1.0)     # 78382A
const RED_LABEL := Color(0.118, 0.047, 0.031, 1.0)    # 1E0C08

## A button nobody can press. Not a fourth family -- the same shape drained of its colour,
## because a disabled control should read as the same object, switched off.
const OFF_FILL := Color(0.157, 0.173, 0.118, 1.0)
const OFF_EDGE := Color(0.204, 0.216, 0.157, 1.0)
const OFF_LABEL := Color(0.400, 0.424, 0.353, 1.0)

# --- Metrics ----------------------------------------------------------------------------
## Ring widths, in the mockup's own pixels. Every frame in the sheet is 4 px per ring; a
## chip small enough that three rings would eat it uses THIN.
const RING := 4
const THIN := 2
## Everything is very slightly cut rather than square. Pure 90-degree corners read as a
## debug rect; a 2 px radius reads as a drawn box.
const RADIUS := 2

## THE TYPE SCALE.
##
## The face is Geist Pixel (SIL OFL 1.1, ui/fonts/OFL.txt) -- a real outline font drawn on
## a pixel grid, rasterised with antialiasing, hinting and subpixel positioning all off.
## That last part is what keeps it crisp, and it is set in the .import file rather than
## here; a pixel face rendered with any of the three on is a blurry pixel face.
##
## FONT_UNIT is what a step of this scale is worth, and every size is a multiple of it.
## Not because the rasteriser demands it -- an outline font will render at any size -- but
## because four sizes chosen on a grid stay in proportion when one of them changes, and a
## scale of arbitrary numbers does not. It is also what the suite checks.
##
## Two times the unit is the FLOOR for anything a player has to read. Shrinking type is
## not how you make something secondary; placement and colour are.
const FONT_UNIT := 10
const FONT_TITLE := FONT_UNIT * 4     # 40
const FONT_SUBTITLE := FONT_UNIT * 3  # 30
const FONT_BUTTON := FONT_UNIT * 3    # 30
const FONT_BODY := FONT_UNIT * 3      # 30
const FONT_CAPTION := FONT_UNIT * 2   # 20
const FONT_TINY := FONT_UNIT * 2      # 20

enum Family { GREEN, CREAM, RED }
enum State { NORMAL, HOVER, PRESSED, DISABLED }


# --- Frames -----------------------------------------------------------------------------

## The panel frame: bright lime ring, dark fill, dark halo. Everything that holds content
## wears this -- the ink meter, the pause panel, the dialogue box, the draw panel.
static func frame(pad_x: float = 14.0, pad_y: float = 11.0) -> StyleBoxFlat:
	var box := _ringed(PANEL, LIME, RING, RING_OUTER, RING)
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	return box


## The same frame at chip scale, for the readouts pinned to the corners. Two-pixel rings,
## because a 4 px ring around a one-line label is mostly ring.
static func chip(pad_x: float = 10.0, pad_y: float = 5.0) -> StyleBoxFlat:
	var box := _ringed(PANEL, LIME, THIN, RING_OUTER, THIN)
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	return box


## An inset trough: the ink gauge's channel, a slider's track, the edge around the drawing
## page. Reads as cut INTO the panel rather than sitting on it, so the ring is the mid
## olive and there is no halo.
static func well() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = INK
	box.border_color = RING_MID
	box.set_border_width_all(THIN)
	box.set_corner_radius_all(RADIUS)
	return box


## An unframed dark strip, for a row that needs a ground to be read against but must not
## look like a panel: the controls legend along the bottom of the screen.
static func strip(pad_x: float = 12.0, pad_y: float = 4.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(PANEL.r, PANEL.g, PANEL.b, 0.90)
	box.border_color = RING_MID
	box.set_border_width_all(THIN)
	box.set_corner_radius_all(RADIUS)
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	return box


# --- Buttons ----------------------------------------------------------------------------

## One button, in one family, in one state.
##
## The mockup's button is four rings deep -- keyline, family edge, grey bevel, fill. A
## StyleBoxFlat affords three tones, so the keyline is the one dropped: it is within a
## couple of values of the panel it sits on and does almost no work. What survives is the
## nesting that carries the shape, edge OUTSIDE bevel, which is why the family colour is
## the shadow and the grey is the border.
static func button(family: Family, state: State) -> StyleBoxFlat:
	if state == State.DISABLED:
		var off := _ringed(OFF_FILL, OFF_EDGE, THIN, KEYLINE, THIN)
		_pad_button(off)
		return off
	var box := _ringed(_fill_for(family, state), BEVEL, RING, _edge_for(family), RING)
	# Raised: the halo is thicker below than above, so the button sits on the panel.
	box.shadow_offset = Vector2(0.0, 2.0)
	_pad_button(box)
	return box


## The focus ring. Bright lime, no fill, so it reads over any of the three families and
## never covers the label -- an opaque focus stylebox has hidden buttons in this project
## before.
static func focus_ring() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = LIME_PALE
	box.set_border_width_all(THIN)
	box.set_corner_radius_all(RADIUS)
	_pad_button(box)
	return box


static func label_color(family: Family) -> Color:
	match family:
		Family.GREEN:
			return GREEN_LABEL
		Family.RED:
			return RED_LABEL
		_:
			return CREAM_LABEL


# --- Slots ------------------------------------------------------------------------------

## An inventory slot.
##
## The ring stays lime whatever the slot holds, because the ring is the SLOT -- six of
## them in a row are the bag, and a bag that dims to invisible when it is empty stops
## telling the player they have one. What changes is the fill (raised once something is
## in it) and, for the one in hand, the ring going warm to match the ink it was drawn
## with. Two cues, so held and merely-full are never one step apart.
static func slot(occupied: bool, selected: bool) -> StyleBoxFlat:
	var box := _ringed(PANEL_LIT if occupied else PANEL,
		PENDING if selected else LIME, THIN, RING_OUTER, THIN)
	box.set_corner_radius_all(RADIUS)
	return box


# --- Generated pictograms ----------------------------------------------------------------

## A round grabber for a slider, drawn rather than shipped.
##
## Godot draws HSlider's handle from a TEXTURE, which is the one part of this skin a
## StyleBox cannot express -- so it is built as an image at load. It is deliberately NOT
## saved into the theme: an ImageTexture written to a .tres keeps its header and loses its
## pixels, so the file would load with an invisible handle and nothing to say why.
static func disc_texture(diameter: int, fill: Color, ring: Color) -> ImageTexture:
	var image := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var centre := (float(diameter) - 1.0) * 0.5
	var radius := float(diameter) * 0.5
	for y in range(diameter):
		for x in range(diameter):
			var distance := Vector2(float(x) - centre, float(y) - centre).length()
			if distance <= radius - 2.0:
				image.set_pixel(x, y, fill)
			elif distance <= radius:
				image.set_pixel(x, y, ring)
	return ImageTexture.create_from_image(image)


## The fullscreen switch: a track with the knob at whichever end it is pointing to, lime
## when on and dark when off. Same reason as the disc -- CheckButton's two states are
## icons, not styleboxes.
static func switch_texture(on: bool) -> ImageTexture:
	var width := 48
	var height := 24
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var track := LIME if on else PANEL
	var edge := LIME if on else RING_MID
	for y in range(height):
		for x in range(width):
			if x < 1 or x >= width - 1 or y < 1 or y >= height - 1:
				continue
			var border: bool = x < 4 or x >= width - 4 or y < 3 or y >= height - 3
			image.set_pixel(x, y, edge if border else track)
	# The knob's END is the only cue that survives being looked at for a quarter second.
	var knob := GREEN_LABEL if on else MUTED
	var knob_radius := float(height - 8) * 0.5
	var knob_centre := Vector2(
		float(width) - 5.0 - knob_radius if on else 5.0 + knob_radius,
		float(height - 1) * 0.5)
	for y in range(height):
		for x in range(width):
			if Vector2(float(x), float(y)).distance_to(knob_centre) <= knob_radius:
				image.set_pixel(x, y, knob)
	return ImageTexture.create_from_image(image)


# --- Internals --------------------------------------------------------------------------

## fill + inner ring (border) + outer ring (shadow). The shadow is Godot's only second
## ring and it is drawn solid, not blurred, which is why it can stand in for one.
static func _ringed(fill: Color, inner: Color, inner_w: int,
		outer: Color, outer_w: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = inner
	box.set_border_width_all(inner_w)
	box.set_corner_radius_all(RADIUS)
	box.shadow_color = outer
	box.shadow_size = outer_w
	box.shadow_offset = Vector2.ZERO
	return box


static func _pad_button(box: StyleBoxFlat) -> void:
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 9.0
	box.content_margin_bottom = 9.0


static func _fill_for(family: Family, state: State) -> Color:
	match family:
		Family.GREEN:
			return GREEN_LIT if state == State.HOVER else (
				GREEN_DARK if state == State.PRESSED else GREEN_FILL)
		Family.RED:
			return RED_LIT if state == State.HOVER else (
				RED_DARK if state == State.PRESSED else RED_FILL)
		_:
			return CREAM_LIT if state == State.HOVER else (
				CREAM_DARK if state == State.PRESSED else CREAM_FILL)


static func _edge_for(family: Family) -> Color:
	match family:
		Family.GREEN:
			return GREEN_EDGE
		Family.RED:
			return RED_EDGE
		_:
			return CREAM_EDGE
