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

**See it.** `godot --path game --script res://tests/run_visual_hud.gd` writes frames
to `/tmp/obra_hud_*.png`: the HUD over the level, the brush gauge full, mid-stroke, low,
nearly spent and dry, a line still typing and the same line finished, both voices, the
drawing panel, the pause menu and settings. `run_visual_hub.gd` writes `/tmp/obra_hub_*.png`
— the house, the brush in its case at the end of the hall, and a painting refusing before
the brush is taken. `run_visual_popups.gd` covers the decision and memory boxes, and `run_visual_menu.gd` the
title screen and the level selector — the menu is the one screen still carrying its own
StyleBoxes and sizes inline, so it is where a palette or type-scale change silently fails
to arrive. Nothing in it is an assertion, on
purpose — see *Why there is no test for this* below.

---

## The typeface

**Geist Pixel**, by the Geist Project (Vercel), under the SIL Open Font License 1.1. The
`.ttf` and its `OFL.txt` live in `game/ui/fonts/`. Nothing needs generating — Godot imports
the font directly and `build_theme.gd` sets it as the theme's **default** font, not on
`Label`, because that leaves buttons, slider readouts and tooltips on the engine's face,
which shows up as *some* of the text having gone 8-bit.

**The import options are the whole trick.** A pixel face rendered like an outline face is a
blurry pixel face, so `GeistPixel-Regular.ttf.import` sets:

| Option | Value | Why |
|---|---|---|
| `antialiasing` | `0` | no grey softening the edge of a hard pixel |
| `hinting` | `0` | hinting nudges stems off the grid the face was drawn on |
| `subpixel_positioning` | `0` | otherwise identical letters land on half-pixels and render differently along one line |
| `keep_rounding_remainders` | `false` | same reason, for advances |

If text ever goes soft, check those four before anything else.

**The type scale** is multiples of `FONT_UNIT` (10). An outline font will render at any
size, so this is not a rasteriser constraint — it is so that four sizes chosen on a grid
stay in proportion when one of them changes. The suite checks it.

| | px | = |
|---|---|---|
| `FONT_TINY` · `FONT_CAPTION` | 20 | 2× |
| `FONT_BODY` · `FONT_BUTTON` · `FONT_SUBTITLE` | 30 | 3× |
| `FONT_TITLE` | 40 | 4× |

**Two times the unit is the FLOOR for anything a player reads**, not the default for
anything small. Shrinking type is not how you make something secondary — placement and
colour are.

**Changing the face or the scale moves layouts.** These are the places it has already
moved, and the first ones to check next time:

| Where | What |
|---|---|
| `game_level.gd` `_build_hud_frame` | the ink panel's width, so a status line neither wraps nor sits in half an empty frame |
| `MainMenu.CARD_HEIGHT` | the level blurb runs to four lines |
| `settings_overlay.tscn` | the caption column, so "Sound effects" stops shortening its slider |
| `draw_panel.gd` `_build_header` | the header row, which was sitting on the frame |
| `controls_overlay.gd` + `.tscn` | twenty-five rows, the tallest thing in the game — its own tighter panel padding and row separation, or BACK falls off the bottom |

**Handjet was in the same request and is deliberately not used.** It is a condensed
dot-matrix face: at 20 px it is markedly harder to read than Geist Pixel, and mixing the
two would have cost the consistency that was the point of the change. It is a drop-in if
it is ever wanted for titles alone.

---

## The palette

Taken pixel by pixel off the sheet, not approximated.

| Name | Hex | What wears it |
|---|---|---|
| `INK` | `070906` | the ground behind everything; the gauge's trough; every scrim |
| `PANEL` | `0D1009` | the fill inside a framed panel |
| `PANEL_LIT` | `161810` | a surface raised off the panel — a full inventory slot |
| `RING_OUTER` | `221A0C` | the dark halo that separates a frame from bright level art |
| `RING_MID` | `6B4E17` | an inset edge: the gauge channel, a slider track, a title rule |
| `MUTED` | `CEC19C` | a status line, an empty slot's number, the keybind row |
| **`GOLD`** | **`DBA835`** | **every frame's bright ring, every meter's fill, every caption — taken off the logo** |
| `GOLD_PALE` | `F1DA9D` | headline type — a banner, a screen title |
| `CREAM_TEXT` | `E8E3C4` | body type on a dark fill |
| `PENDING` | `FFBD3D` | ink claimed but not spent; the slot currently in hand |
| `BEVEL` | `4D4E48` | the grey highlight ring inside a button's edge |

### What you ARE is top right; what you HAVE is top left

The two corners split by whether a reading survives a morph. The left frame holds the brush
and the ink, which are true whoever you currently are. The right holds `MorphCard`, which
exists only while the player is a drawing.

**The card is shaped like a battle plate** — name left, a rating right, a bar beneath with
its caption beside it, the portrait boxed off the end — because that layout is legible in
the corner of an eye during a jump, and no player has to be taught it. The three readings
map onto what this game actually has: the class the recogniser settled on, **how sure it
was** (a number the player had never been shown, and the one fact about a morph that is
fixed for its whole life), and the life left. The portrait is the submitted sketch, in the
same frame the hotbar keeps a stored drawing in — a drawing you are *wearing* and one you
are *carrying* belong in the same kind of box.

It replaced the R-DRAW chip, which said one word the player needs once; the controls strip
still reads R DRAW.

### The top-left frame reads top to bottom as *what you are, then what you have*

The plate at the top is shaped the way a battle screen shapes one — **name left, clock
right, a bar beneath** — because that arrangement is already legible to everyone who has
played anything, and what it now carries is genuinely the same thing: the drawing you are
currently fielding and how much of it is left. It is only present while the player IS a
drawing; the apo has no life, so being yourself folds the whole section away and the frame
shrinks to the ink it still has to show.

The life bar runs the classic three-stop health ramp — `GOLD_PALE` above half, `PENDING`
above a quarter, `RED_FILL` below it — in this game's own metal rather than the green such
bars are usually drawn in. The colour says what the length already says, so a player
watching the level and not the corner still catches it going wrong.

**The frame around all of it came back, and the version without it is why.** The brush was
drawn straight onto the level with an outline on every line of type. That reads fine in a
still and badly in motion: this corner sits over Payyo's sky on nearly every frame, and an
outline gives a glyph an *edge* without giving it a *ground*. Small type over moving art
needs a ground.

**THE ACCENT IS THE LOGO'S GOLD.** It was a lime, `C9D94A`, and the title card is gold
lettering in a gold frame on a dark green ground — so every button, ring and caption in the
game was arguing with the first thing anybody sees. `GOLD` is measured straight off
`HUD-assets-ideas/Logo.jpg`. The dark grounds above were already that logo's field, near
enough; only the accent and the green button family were wrong, and the green family is now
gold. The frames on Lola's paintings (`GILT`) were always this colour — see *Story is
framed* below for what now separates them from UI chrome, since hue no longer does.
| `WOOD_EDGE` · `WOOD_DARK` · `WOOD` · `WOOD_LIT` | `140C06` `2E1B0E` `4A2E1A` `6B4526` | the frame's moulding, dark to lit |
| `FILLET` · `FILLET_LIT` | `B08A3C` `D8B968` | the frame's gold liner, and the speaker plaque |
| `MAT` | `38291C` | the mount between the frame and the picture |
| `KEYLINE` | `18140A` | the near-black outside a button |

Three button families, three states each:

| | normal | hover | pressed | edge | label |
|---|---|---|---|---|---|
| **gold** — the act the screen exists for | `DAA83D` | `ECC45C` | `B08229` | `7A5519` | `1B1305` |
| **cream** — everything that navigates | `E8E3C4` | `F5F1D6` | `CDC7A6` | `302812` | `1E1A0E` |
| **red** — the one that ends something | `C46048` | `D67660` | `A04E3A` | `78382A` | `1E0C08` |

**Button labels are emboldened.** Geist Pixel ships one weight, so rather than pull in a
second face `build_theme.gd` gives the button families a `FontVariation` with
`variation_embolden = 0.08` — FreeType dilates the outline before rasterising, so stems
thicken and the glyph stays on its own grid. Kept small on purpose: a pixel face pushed
hard closes its own counters and stops being readable at exactly the point it looks
strongest in the editor.

Assign one with a `theme_type_variation`: `PrimaryButton` (gold), `DangerButton` (red),
`Button` or `DialogButton` (cream, the default). **Which family a button is in is a
statement about what pressing it does, not a decoration.** RESUME is gold wherever it
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
| outer bevel | 1 | `GOLD` top+left, `RING_OUTER` bottom+right |
| moulding | 3 | `RING_MID`, with `RING_OUTER` notches cut into it |
| inner bevel | 1 | `RING_OUTER` top+left, `GOLD` bottom+right |
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

**The carving is darker than the wood.** The first version drew accent-coloured ticks at a tight
pitch and the whole top rail became one bright dashed line. A notch is a recess and a
recess catches *less* light. They are `RING_OUTER` at a pitch of six units.

**To frame an existing panel**, call `UIFrame.wrap(panel)`. The panel stops drawing its own
background and takes enough padding to keep its content off the moulding. The frame is
added as that panel's first child so it draws behind the content — and it draws *outward*
past its own rect via `overdraw`, because a container lays its children out inside the very
padding the frame has to cover. Godot does not clip a Control's drawing to its rect unless
asked, so this needs no layout special case.

## Two channels: story and hints

They are not the same act, and they were sharing one box.

| | Story | Hint |
|---|---|---|
| Example | "Four hundred years. They built this while the Spanish were burning the lowlands." | "Draw something that can SPAN it." |
| Where | `dialogue_box.gd` — the picture frame, screen centre | `hint_bar.gd` — a compact strip at the TOP of the screen, under the level badge |
| Stops the world | yes | no |
| Advanced by | the player, one line at a time | nothing; it clears itself |
| Camera | pushes in on the speaker | untouched |

**The hint bar sits at the top, and that was a bug fix.** It used to be lifted 396 off the
bottom of the screen — a number chosen to clear the dialogue box's top rail, which on a
900-tall canvas puts it at y 454: dead centre, straight across the path the player is trying
to walk. It never needed to clear the box at all, because `_process` fades the panel out
while anybody is speaking and the two are never on screen together. `HintBar.TOP` is 66,
under the level badge (y 20..52) and in the gap between the HUD frame (ends at x 418) and
the morph card (begins at x 1202). `MAX_WIDTH` came down from 720 to 560 and the chip
padding from 16/9 to 11/6 for the same reason: a hint is one instruction read once, and at
half the width of the screen it was dressed as a beat of story.

**Which channel a line takes is decided by the script, from the hook.** `dialogue_script.gd`
treats `.teach`, `.sub1`, `.sub2` and `.ward.fail*` as hints — they fire when the player is
stuck in front of something — and everything else as story. A line may carry an explicit
`"kind": "hint"` or `"lore"`, and the data wins.

### Signposts: the two channels, standing in the world

Both channels are triggered by walking into an `Area2D` that nothing draws. A player who
does not know one is there has no way to tell a stretch of terrace where something happens
from a stretch where nothing does — so a beat they walked past reads as a beat that is not
in the game. The trigger itself cannot be shown: it is a box several hundred pixels wide
and three hundred tall, and drawing one is drawing the machinery rather than the promise.

`signpost_2d.gd` draws the promise. A small pale board on a post, standing on the ground
where the beat fires, carrying one of five marks:

| Mark | Board | Means | Planted by |
|---|---|---|---|
| `STORY` | a speech bubble | Somebody speaks and there is nothing to solve. An arrival, an ending. | `level_obstacle_2d.gd`, at the trigger's leading edge |
| `HINT` | a question mark | There is a problem here, and Lolo will help if you stand still long enough. | `level_obstacle_2d.gd`, at the obstacle itself |
| `CHOICE` | a fork in the road | A decision that changes the level and cannot be taken back. | `dialogue_node_2d.gd` |
| `MEMORY` | a written page | Something of Lola's — a page, a memory, the inside of the chest. | `baul_2d.gd`, `concept_gate_2d.gd` |
| `FIND` | a four-petal flower | A thing to find rather than a thing to solve. | nothing yet — see below |

Each mark is built so its **silhouette** carries it. At twenty-four pixels of board nobody
reads a picture, they read a shape, and the five have to be different shapes before they
are different drawings. `run_visual_signposts.gd` photographs all five side by side, which
is the only way to check that.

**A beat is two moments in two places.** An obstacle's opening line fires the instant the
player crosses the leading edge of its trigger, and the thing to be solved is somewhere in
the middle of it — so an obstacle plants two signs, a `STORY` at the edge and a `HINT` at
the middle. Planted at the trigger's origin instead, the first sign in Level 1 stood three
hundred and fifty pixels past the point where the game's first line of dialogue had already
come and gone.

**Where two land together, rank decides.** `CHOICE` > `MEMORY` > `FIND` > `HINT` > `STORY`,
because every one of the others speaks as well and the more specific thing is worth the
board. That is why the gorge shows a fork rather than a question mark, and the sketchbook
chest a page.

**A `STORY` board can be read again, on the interact key.** Arrival lore plays itself the
first time and never again — see *Arrival speaks once* in **LEVEL_1.md** — so it needs somewhere to
live afterwards. `level_obstacle_2d.gd` hands its board the beat's `.enter` hook in
`Signpost2D.reads`; stand within 96px of it (the same reach the key already has for a
placed drawing) and the board lights up with a yellow ring while the hint bar names the
binding. The key tries a reachable drawing first and falls through to the board only when
there is nothing to pick up.

A board that stands down under the rank rule **hands its hook to the survivor**, so
crowding removes a post and never a beat. Without that, the sign carrying an arrival could
be the one deleted, silently, at load, and the player would be left pressing a key at the
only board there is and getting nothing.

**Two things deliberately have no sign, and both would be actively wrong.** The bulul,
because `bulul_2d.gd` exists to make a granary guardian un-interactable and a signpost
beside one says "interact here" — Lolo still speaks when you walk up, he is just not
advertised. And the hidden flower, because it is hidden; signing it is removing it. The
gate into the cave it sits behind does get one, which is the honest amount of help.

**The sign finds its own ground.** It waits one physics frame — the terraces build their
collision in `_ready`, so at plant time the physics server has not been told about the
floor yet — then casts down and stands on what it finds. It only ever falls: a hit above
where it was planted is a ceiling, not a floor.

### The story box

`game/scripts/dialogue_box.gd`, presented the way a console RPG presents dialogue, because
those conventions are load-bearing and players already know them.

- **A queue, and the player turns the page.** First press catches up the line being typed,
  the next moves on. One press doing both lets a fast reader skip a line they never saw.
  Advance is `ui_accept` or a left click.
- **Face at the top, words at the bottom.** The speaker's bust stands on the box's top
  rail and the box runs across the bottom of the screen, 1300 × 300. The two are one
  object, and the arrangement leaves the middle of the screen — where the reader's eye
  travels between them — clear.
- **One size**, fixed whatever the line: a box that resizes per line makes the reader
  re-find the first word every time.
- **Typed out**, then a **blinking arrow** in its own gutter: the difference between "still
  talking" and "waiting for you".
- **A plaque** on the top rail says who is speaking. Two voices share the box — Lolo and the
  apo's own thoughts — so `current_speaker` says whose line is up.
- **A bust of the speaker stands above it** (`dialogue_portrait.gd`) — head, shoulders and
  hands, cut at the hip. This is what the camera push-in could not do: zooming the world
  makes the speaker slightly larger and still forty pixels tall and still side-on, and what
  a player needs while someone talks is a face.
- **The world stops and the camera pushes in** on the speaker
  (`WorldCameraController.focus_on`), gently — the portrait carries the focus, and a hard
  push-in behind a large figure makes the background compete with it.

**Half the body, not the whole of it.** A full figure standing at the bottom of the screen
puts the head in the *middle* of it, which is exactly where the eye travels between the
face and the text. Cutting at the hip lifts the face to the top and leaves that path clear
— and the cut line has the box's own rail to hide behind, which is what a bust needs and
what it did not have when the box sat beside it rather than under it.

**Lolo's portrait is rendered through a `SubViewport` and scaled up with nearest
filtering.** He is drawn in code from circles and arcs, and drawing him big draws him
*smooth* — a 400-pixel antialiased circle beside a six-pixels-per-pixel sprite looks like a
bug rather than a placeholder. Rasterising him at sprite size first makes him chunky in the
same way everything around him is. He is still a blob; that is logged in
`CONTENT_NEEDED.md` as art the team owes, and he speaks most of Level 1.

**`set_auto_dismiss(true)` is the skip.** Every headless fixture needs it, because a
conversation stops the tree until somebody presses a key and there is nobody there —
and it has to stay on, not fire once: the first obstacle queues a beat of its own, and
without it a walkthrough reports the paddy as a wall.

**The reveal is `visible_ratio` on a label whose text is already complete, never an
append.** Appending re-wraps on every character, so a word about to overflow jumps to the
next line as it is typed. It also means a test reading the label gets the whole line no
matter when it looks.

---

## Six things that are not obvious

### 1. Godot gives you three tones per frame, and the sheet draws four

Every frame in the sheet is four rings deep. A `StyleBoxFlat` affords **fill, border, and
shadow** — and its shadow is drawn solid, not blurred, so it can stand in for a ring.

Which ring gets dropped differs by element, and both choices are deliberate:

- **A panel** keeps `GOLD` as the border and `RING_OUTER` as the shadow, dropping the mid
  tone. The dark halo is what stops a gold frame glowing against the sky.
- **A button** keeps `BEVEL` as the border and the **family colour** as the shadow,
  dropping the keyline — which is within a couple of values of the panel it sits on and
  does almost no work. This preserves the nesting that carries the shape: in the sheet the
  family edge is OUTSIDE the grey bevel, so the family colour has to be the outer ring.

If you ever need all four, nest two `PanelContainer`s. Nothing does yet.

### 2. Almost none of it is shipped as an image

The only PNGs in the skin are the font atlas, which is generated from a text file, and the
three brush sheets in `assets/hud/` — those are artwork rather than skin, and they are the
one thing here a palette change does not reach. The droplet and the flag (`ui_glyph.gd`)
are eight-row bitmaps; the picture frame, the drawing page's corner brackets and the key
badge are drawn in `_draw()`. That is cheaper than four textures, it scales to whatever the row turns out to
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

### 6. A theme override does not reach a Control until it is in the tree

`add_theme_font_size_override` is silent outside the tree. Godot only fires
`NOTIFICATION_THEME_CHANGED` for an override when there is a tree to notify through, so a
`Label` built in code still holds the theme's own `font_size` in its cache until
`add_child`. Anything measured before that — and `Control.set_size` **clamps up to the
minimum size and never back down** — is measured against the wrong number and stays wrong.

This is what made the names under the hub's paintings crooked. The plates are sized at
`FONT_CAPTION` (20) and the theme's default is 30; `"MAYON  —  NOT YET PAINTED"` is 277px
at 20 and **416px at 30**, so the label reserved 416, and a plate positioned by a fixed
left offset carried the whole 96px difference sideways — 48px to the right of its own
picture, out past the moulding and across the doorway beside it. The text drew at 20 the
entire time, so nothing about it looked like a font problem.

**The rule: `add_child` first, then set `size` and `position`, and derive a centred
position from the size you actually got** (`-size.x * scale.x * 0.5`), not from the size
you asked for. Controls inside a container are safe — the container re-lays them out from
the correct minimum once they are in the tree — so this only bites where a Control is
placed by hand. `run_hub_audit` asserts every plate is centred within a pixel, because a
headless suite could not otherwise see it and a screenshot is how it was found.

---

## Where each piece lives

| On screen | File |
|---|---|
| Palette, type scale, every frame factory, the two generated textures | `game/scripts/ui_skin.gd` |
| The typeface | `tools/font_glyphs.py` → `tools/build_font.py` → `game/ui/obra_font.fnt` |
| The generated theme | `game/ui/obra_theme.tres` ← `game/tools/build_theme.gd` |
| The picture frame every story box wears | `game/scripts/ui_frame.gd` |
| Lolo's dialogue, the plaque, the typing, the arrow | `game/scripts/dialogue_box.gd` |
| The speaker's portrait behind the box | `game/scripts/dialogue_portrait.gd` |
| Hints, which never stop play | `game/scripts/hint_bar.gd` |
| The signs in the world saying which of those two is coming | `game/scripts/signpost_2d.gd` |
| Route decision · Lola memory (both call `UIFrame.wrap`) | `game/scripts/dialogue_choice_overlay.gd` · `memory_overlay.gd` |
| The top-left frame: the nameplate, the life bar, the ink row | `game/scripts/hud_panel.gd` |
| The ink gauge itself — Lola's brush, drying out | `game/scripts/ink_brush.gd` |
| How long the drawing has left | `game/scripts/morph_life.gd` |
| The brush in its case in the house | `game/scripts/brush_stand_2d.gd` |
| The checkpoint flag, and the apo raising it | `game/scripts/checkpoint_flag_2d.gd` |
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
icon, an ink gauge whose spent half is brighter than its full half: **all of these load
without error and all of them are obvious in a screenshot.** Eight defects in this project have now
passed green suites and been caught only by looking. Run `run_visual_hud.gd` and look at
the frames.
