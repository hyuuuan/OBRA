# The interface skin — how to change how the game looks

**What this is.** The 8-bit HUD sheet in `HUD-assets-ideas/` is the design. This file says
where each part of it lives in the build, what to edit to change it, and the four things
about it that are not obvious.

**The one rule.** Every colour in the interface is in `game/scripts/ui_skin.gd`, and
`game/ui/obra_theme.tres` is **generated** from it. To restyle the game:

```bash
godot --headless --path game --script res://tools/build_theme.gd
```

Do not hand-edit `obra_theme.tres`. It works right up until someone regenerates and
silently loses the edit — the same arrangement `config/tags.json` has with
`tools/build_tags.py`. `run_tests.gd` checks one value from each button family against
the skin, so a palette edit without a regeneration fails the suite instead of shipping.

**See it.** `godot --path game --script res://tests/run_visual_hud.gd` writes six frames
to `/tmp/obra_hud_*.png`: the HUD over the level, the gauge full, mid-stroke and nearly
spent, a line still typing and the same line finished, both voices, the drawing panel, the
pause menu and settings. `run_visual_popups.gd` covers the decision and memory boxes, and `run_visual_menu.gd` the
title screen and the level selector — the menu is the one screen still carrying its own
StyleBoxes and sizes inline, so it is where a palette or type-scale change silently fails
to arrive. Nothing in it is an assertion, on
purpose — see *Why there is no test for this* below.

---

## The typeface

The game has its own. `tools/font_glyphs.py` is ninety-eight glyphs, **six pixels wide and
ten tall**, drawn as `#` and `.` — all of printable ASCII plus `·`, `—` and `…`, which a
scan of every string in the project says are the only ones beyond ASCII it renders.

```bash
python3 tools/build_font.py     # -> game/ui/obra_font.png + .fnt
```

Both outputs are generated; edit the glyph table, never them. Godot imports the `.fnt` as a
`FontFile` and `build_theme.gd` sets it as the theme's **default** font — not on `Label`,
because that leaves buttons, slider readouts and tooltips on the engine's face, which shows
up as *some* of the text having gone 8-bit.

**Six wide, not five.** The first cut was five, and at HUD sizes `a`, `e` and `o` collapsed
into the same blob while `r` and `n` ran together. A pixel letter needs an interior counter
that survives being two pixels across, and five columns does not leave one once you have
spent two on the stems.

**The type scale is multiples of the font's own line and has to be.** A bitmap scaled by
1.9 has some rows twice as thick as others. `FONT_UNIT` is 10; every size is a multiple of
it, in the theme, in the scripts and in the `.tscn` files.

| | px | = |
|---|---|---|
| `FONT_TINY` · `FONT_CAPTION` | 20 | 2× |
| `FONT_BODY` · `FONT_BUTTON` · `FONT_SUBTITLE` | 30 | 3× |
| `FONT_TITLE` | 40 | 4× |

**Two times the unit is the FLOOR for anything a player reads**, not the default for
anything small. The first scale put the status line and the keybind row at a size where the
letterforms stopped resolving; shrinking type is not how you make something secondary.
Placement and colour are.

**Changing the scale moves layouts**, and these are the places it has already moved:

| Where | What |
|---|---|
| `game_level.gd` `_build_hud_frame` | the ink panel's width, so a status line does not wrap |
| `MainMenu.CARD_HEIGHT` | the level blurb went from two lines to four |
| `settings_overlay.tscn` | the caption column, so "Sound effects" stops shortening its slider |
| `draw_panel.gd` `_build_header` | the header row, which was sitting on the frame |
| `controls_overlay.gd` | the table is a step down — twenty rows at body size overflow the screen |

Digits are the one monospaced part — the ink readout counts down while you draw, and a
proportional `1` makes the whole number jump sideways.

---

## The palette

Taken pixel by pixel off the sheet, not approximated.

| Name | Hex | What wears it |
|---|---|---|
| `INK` | `070906` | the ground behind everything; the gauge's trough; every scrim |
| `PANEL` | `0D1009` | the fill inside a framed panel |
| `PANEL_LIT` | `161810` | a surface raised off the panel — a full inventory slot |
| `RING_OUTER` | `1E2210` | the dark halo that separates a frame from bright level art |
| `RING_MID` | `4A5418` | an inset edge: the gauge channel, a slider track, a title rule |
| `MUTED` | `A9B487` | a status line, an empty slot's number, the keybind row |
| **`LIME`** | **`C9D94A`** | **every frame's bright ring, every meter's fill, every caption** |
| `LIME_PALE` | `DFE98C` | headline type — a banner, a screen title |
| `CREAM_TEXT` | `E8E3C4` | body type on a dark fill |
| `PENDING` | `FAE64F` | ink claimed but not spent; the slot currently in hand |
| `BEVEL` | `4D4E48` | the grey highlight ring inside a button's edge |
| `WOOD_EDGE` · `WOOD_DARK` · `WOOD` · `WOOD_LIT` | `140C06` `2E1B0E` `4A2E1A` `6B4526` | the frame's moulding, dark to lit |
| `FILLET` · `FILLET_LIT` | `B08A3C` `D8B968` | the frame's gold liner, and the speaker plaque |
| `MAT` | `38291C` | the mount between the frame and the picture |
| `KEYLINE` | `18140A` | the near-black outside a button |

Three button families, three states each:

| | normal | hover | pressed | edge | label |
|---|---|---|---|---|---|
| **green** — the act the screen exists for | `96BD58` | `A8CD6C` | `789644` | `587030` | `121808` |
| **cream** — everything that navigates | `E8E3C4` | `F5F1D6` | `CDC7A6` | `302812` | `1E1A0E` |
| **red** — the one that ends something | `C46048` | `D67660` | `A04E3A` | `78382A` | `1E0C08` |

Assign one with a `theme_type_variation`: `PrimaryButton` (green), `DangerButton` (red),
`Button` or `DialogButton` (cream, the default). **Which family a button is in is a
statement about what pressing it does, not a decoration.** RESUME is green wherever it
appears; QUIT is red wherever it appears.

---

## The picture frame

Story is framed. Menus are not.

`game/scripts/ui_frame.gd` draws a pixel picture frame at whatever size it is given, and
everything the *world* says wears it: Lolo's dialogue, the route decision, the Lola memory.
Pause, settings, controls, confirm and out-of-ink keep the plain HUD panel — they are
menus, and framing them would make the settings screen look like part of the fiction.

**Why a frame at all.** OBRA is about a grandmother's paintings. The hub is her studio, the
levels are her canvases, the player is holding her brush. A box that looks like a UI panel
says *this is software*; a box that looks like a frame says *this is one of hers*.

**The bands, outermost first** — widths in units, and `unit` defaults to 4 px:

| Band | Units | Colour |
|---|---|---|
| keyline | 1 | `INK` |
| outer bevel | 1 | `LIME` top+left, `RING_OUTER` bottom+right |
| moulding | 3 | `RING_MID`, with `RING_OUTER` notches cut into it |
| inner bevel | 1 | `RING_OUTER` top+left, `LIME` bottom+right |
| rabbet | 1 | `INK` |
| mat | 2 | `PANEL_LIT` |
| canvas | — | `PANEL` |

**Three things make it read as a frame rather than a thick border.** All three are load
bearing; drop any one and it looks like a panel someone made chunky.

1. **Bands of different widths.** A real moulding steps.
2. **The two bevels lean opposite ways.** The outer edge catches light, the inner edge
   falls into shadow. That opposition is what makes the band between them read as the top
   of something raised. Both bevels are mitred, so the light and dark meet on the diagonal
   the way a moulding is actually cut.
3. **Joint blocks at the corners.** The one part of a frame that has no equivalent in a UI
   panel, and therefore the strongest single cue. Drawn last, over everything.

**The carving is darker than the wood.** The first version drew lime ticks at a tight
pitch and the whole top rail became one bright dashed line. A notch is a recess and a
recess catches *less* light. They are `RING_OUTER` at a pitch of six units.

**To frame an existing panel**, call `UIFrame.wrap(panel)`. The panel stops drawing its own
background and takes enough padding to keep its content off the moulding. The frame is
added as that panel's first child so it draws behind the content — and it draws *outward*
past its own rect via `overdraw`, because a container lays its children out inside the very
padding the frame has to cover. Godot does not clip a Control's drawing to its rect unless
asked, so this needs no layout special case.

## The dialogue box

`game/scripts/dialogue_box.gd`, presented the way a console RPG presents dialogue, because
those conventions are load-bearing and players already know them.

- **One place.** The middle of the screen, always, like the decision and memory boxes. It
  does cover the ground the player is standing on while it is up — that is the trade for
  putting the story where the story belongs, and it is why a line given a duration clears
  itself.
- **One size, and a generous one.** 1040 × 330, fixed whatever the line. A box that resizes
  per line makes the reader re-find the first word every time.
- **Typed out**, then a **blinking arrow**. The arrow is the difference between "the game
  is still talking" and "the game is waiting for you", and it has its own gutter along the
  bottom so a three-line paragraph never runs underneath it.
- **A plaque** on the top rail says who is speaking.

**Two voices share it** — Lolo and the apo's own thoughts — so `current_speaker` says whose
line is up, and `Lolo.is_speaking()` compares against it rather than asking whether the box
is merely visible.

**The reveal is `visible_ratio` on a label whose text is already complete, never an
append.** Appending re-wraps on every character, so a word about to overflow jumps to the
next line as it is typed and the paragraph reflows under the reader. It also means a test
reading the label gets the whole line no matter when it looks.

**Anything that opens with story of its own calls `hide_line` first**, through the
`dialogue_box` group. A line left underneath a decision box is a second voice arguing with
the first.

---

## Four things that are not obvious

### 1. Godot gives you three tones per frame, and the sheet draws four

Every frame in the sheet is four rings deep. A `StyleBoxFlat` affords **fill, border, and
shadow** — and its shadow is drawn solid, not blurred, so it can stand in for a ring.

Which ring gets dropped differs by element, and both choices are deliberate:

- **A panel** keeps `LIME` as the border and `RING_OUTER` as the shadow, dropping the mid
  olive. The dark halo is what stops a lime frame glowing against the sky.
- **A button** keeps `BEVEL` as the border and the **family colour** as the shadow,
  dropping the keyline — which is within a couple of values of the panel it sits on and
  does almost no work. This preserves the nesting that carries the shape: in the sheet the
  family edge is OUTSIDE the grey bevel, so the family colour has to be the outer ring.

If you ever need all four, nest two `PanelContainer`s. Nothing does yet.

### 2. Almost none of it is shipped as an image

The only PNG in the skin is the font atlas, and that is generated from a text file. The
droplet and the flag (`ui_glyph.gd`) are eight-row bitmaps; the picture frame, the ink
gauge, the drawing page's corner brackets and the key badge are drawn in `_draw()`. That is cheaper than four textures, it scales to whatever the row turns out to
be, it cannot be imported with the wrong texture filter, and it does not put binaries in
the repo that nobody can diff. It also sidesteps the `assets/level1` / `assets/Level1`
case trap, which is real on this project.

### 3. Two controls are textures, and they must not go in the theme

Godot draws `HSlider`'s handle and `CheckButton`'s two states from **icons**, which no
StyleBox can express. They are generated as images in `UISkin.disc_texture` and
`UISkin.switch_texture` and applied in `settings_overlay.gd` with
`add_theme_icon_override`.

**They are deliberately not saved into the theme.** An `ImageTexture` written to a `.tres`
keeps its header and loses its pixels: the file loads fine, the handle is invisible, and
nothing says why.

### 4. A Tween is bound to its node's pause state

The dialogue box's fade-out never advanced under a modal that paused the game, so a stale
line sat on screen underneath the decision box. Its tweens are `TWEEN_PAUSE_PROCESS` now.
Anything that has to animate *because* a modal opened has the same problem.

### 5. An `HSeparator`'s margins set the thickness of the line

The rule under a screen title is an `HSeparator`. Godot draws its stylebox at the
**stylebox's own minimum height** and takes the surrounding space from the `separation`
constant. So content margins on that box are the LINE, not the padding — the first version
at 5 painted a ten-pixel olive slab across every panel. It is 1, with separation 16.

---

## Where each piece lives

| On screen | File |
|---|---|
| Palette, type scale, every frame factory, the two generated textures | `game/scripts/ui_skin.gd` |
| The typeface | `tools/font_glyphs.py` → `tools/build_font.py` → `game/ui/obra_font.fnt` |
| The generated theme | `game/ui/obra_theme.tres` ← `game/tools/build_theme.gd` |
| The picture frame every story box wears | `game/scripts/ui_frame.gd` |
| Lolo's dialogue, the plaque, the typing, the arrow | `game/scripts/dialogue_box.gd` |
| Route decision · Lola memory (both call `UIFrame.wrap`) | `game/scripts/dialogue_choice_overlay.gd` · `memory_overlay.gd` |
| Ink meter, its segmented gauge, the status line | `game/scripts/hud_panel.gd` |
| Droplet and flag pictograms | `game/scripts/ui_glyph.gd` |
| Level banner, goal chip, R-key action tag, controls strip | `game/scripts/game_level.gd` (`_build_hud_frame`) |
| The six-slot hotbar | `game/scripts/inventory_hud.gd` |
| Drawing panel, page brackets, live guess | `game/scripts/draw_panel.gd` |
| Slider handle and fullscreen switch | `game/scripts/settings_overlay.gd` (`_skin_controls`) |
| Pause menu | `game/game_level.tscn` (`PauseMenu`) |
| Main menu | `game/ui/main_menu.tscn` + `main_menu.gd` (`CARD_HEIGHT`) — see below |
| Every other screen | `game/ui/*.tscn`, all through theme variations |

**The main menu still carries its own StyleBoxes inline.** They now hold palette values,
but they are copies, not references — a `.tscn` cannot call a function. If you change a
green, change it there too. The note in `AGENTS.md` about the menu staying pixel-identical
is about the *theme* not reaching in and restyling it by accident, which is still a real
hazard; changing it on purpose is fine.

---

## What is deliberately not built

- **The keybind row still fades after fourteen seconds.** That is a design decision, not a
  look. The sheet shows it present because a sheet has no time axis.

---

## Why there is no test for this

`run_tests.gd` asserts the theme's *structure* — that every variation a scene names still
exists, that the theme still matches the skin it was generated from, that no focus
stylebox is opaque. It cannot assert that the thing looks right.

A stylebox with the wrong colour, rings collapsed into each other, a label sitting under an
icon, a gauge reading as one bar instead of twelve blocks: **all of these load without
error and all of them are obvious in a screenshot.** Eight defects in this project have now
passed green suites and been caught only by looking. Run `run_visual_hud.gd` and look at
the frames.
