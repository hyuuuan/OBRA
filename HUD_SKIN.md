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
spent, the drawing panel, the pause menu and settings. Nothing in it is an assertion, on
purpose — see *Why there is no test for this* below.

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
| **`LIME`** | **`C9D94A`** | **every frame's bright ring, every meter's fill, every caption** |
| `LIME_PALE` | `DFE98C` | headline type — a banner, a screen title |
| `CREAM_TEXT` | `E8E3C4` | body type on a dark fill |
| `MUTED` | `78805A` | a status line, an empty slot's number, the keybind row |
| `PENDING` | `FAE64F` | ink claimed but not spent; the slot currently in hand |
| `BEVEL` | `4D4E48` | the grey highlight ring inside a button's edge |
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

### 2. Some of it is drawn, not shipped

No part of this skin is a PNG. The droplet and the flag (`ui_glyph.gd`) are eight-row
bitmaps; the ink gauge, the drawing page's corner brackets and the key badge are drawn in
`_draw()`. That is cheaper than four textures, it scales to whatever the row turns out to
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

### 4. An `HSeparator`'s margins set the thickness of the line

The rule under a screen title is an `HSeparator`. Godot draws its stylebox at the
**stylebox's own minimum height** and takes the surrounding space from the `separation`
constant. So content margins on that box are the LINE, not the padding — the first version
at 5 painted a ten-pixel olive slab across every panel. It is 1, with separation 16.

---

## Where each piece lives

| On screen | File |
|---|---|
| Palette, every frame factory, the two generated textures | `game/scripts/ui_skin.gd` |
| The generated theme | `game/ui/obra_theme.tres` ← `game/tools/build_theme.gd` |
| Ink meter, its segmented gauge, the status line | `game/scripts/hud_panel.gd` |
| Droplet and flag pictograms | `game/scripts/ui_glyph.gd` |
| Level banner, goal chip, R-key action tag, controls strip | `game/scripts/game_level.gd` (`_build_hud_frame`) |
| The six-slot hotbar | `game/scripts/inventory_hud.gd` |
| Drawing panel, page brackets, live guess | `game/scripts/draw_panel.gd` |
| Slider handle and fullscreen switch | `game/scripts/settings_overlay.gd` (`_skin_controls`) |
| Pause menu | `game/game_level.tscn` (`PauseMenu`) |
| Main menu | `game/ui/main_menu.tscn` — see below |
| Every other screen | `game/ui/*.tscn`, all through theme variations |

**The main menu still carries its own StyleBoxes inline.** They now hold palette values,
but they are copies, not references — a `.tscn` cannot call a function. If you change a
green, change it there too. The note in `AGENTS.md` about the menu staying pixel-identical
is about the *theme* not reaching in and restyling it by accident, which is still a real
hazard; changing it on purpose is fine.

---

## What is deliberately not built

- **No custom font.** The sheet is set in a pixel typeface and the build uses Godot's
  default. A font is a licensing decision and an import, not a colour, so it is the team's
  call — everything else here is already sized for one. Dropping it in is one
  `theme.set_font` in `build_theme.gd`; note the suite asserts the theme defines **no**
  `Label` font today, because one would restyle the main menu, so that assertion moves at
  the same time.
- **No second dialogue box.** The sheet shows a screen-anchored dialogue panel. Lolo's
  speech is a world-space bubble that points at him and follows him, and it already reads
  like the sheet's box. Adding a screen-space one would be two places for one line.
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
