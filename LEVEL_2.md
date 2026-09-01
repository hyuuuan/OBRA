# Level 2 — Piyesta

**Status: playable end to end. Every beat resolves and the level can be finished.**
Not offered from the hub yet — see What remains.
`levels.json` keeps an empty `scene_path` for `level_2` and three tests assert it stays
that way until the level can be finished. `run_level2_audit` is one of them.

**The design is `Level 2 Pista Design Refined.pdf` (revision 3), at the repo root.** This
document is the build record: what was decided, what is built, what broke on the way, and
what is left. The superseded provisional design is folded away at the bottom.

**Read with:** `LEVEL_TEMPLATE.md` (the shape every level inherits, R1–R10),
`AGENTS.md` (the eleven hooks a level owes), `LEVEL_1.md` (the worked example).

---

## The level in one paragraph

Recover **seven scraps** of the Pista painting and assemble them. Scene-based rather than
one continuous walk: plaza → church interior → Alley 1 (five birds carry five scraps) →
Alley 2 (the bandaritas hold two) → assembly. **Flight is a restriction, not an ability** —
the bandarita line is a ceiling, and it lifts only when the line is cut. Three dialogue
nodes; the last has **two routes, not three**, deliberately.

| Beat | `artist` | `pragmatist` | `protector` |
|---|---|---|---|
| **L2_N1** Ang Kandila | dance for the dancers *(no drawing)* | find the lit house, make a way in | scare them off — they never come back |
| **L2_N2** Alley 1, five birds | feed them | chase them — deferred, not lost | knock them down, on a 45–60 s timer |
| **L2_N3** Alley 2, the bandaritas | climb to them | *(none, by design)* | cut them down — and the sky opens |

---

## The decisions, and why

1. **Answer sets stayed on the tag layer.** The PDF names single classes (`bread`,
   `boomerang`) and an explicit scare list. Those became three tag memberships — `feed`,
   `startle`, `strike` — so every route still resolves ≥2 classes and no obstacle names a
   class. `strike` was declared for Level 3 and is populated here instead; Level 3 keeps
   `swim`.
2. **The host was extracted, not forked.** `game_level.gd` (3046 lines) split into
   `level_base.gd` + `game_level.gd`, eleven hooks. See `LEVEL_TEMPLATE.md` for the method.
3. **`mushroom` → `bread`**, retrained and shipped as one versioned set. Still 50 classes.
4. **`fly` stays empty and its unlock moved off this level.** The refined design never asks
   the player to fly; it stops them. Populating a tag no obstacle asks for buys nothing.
5. **The two restrictions fire through different doors.** A banned small animal is
   **refused at submission** — no ink, a reason, nothing moves. The flight ceiling is a
   **violation** — that drawing was legal and the player went where they were told not to,
   so position resets and *nothing else does*. The PDF's flowchart routes both to the
   checkpoint handler; its own UI list and its own note about message specificity argue for
   this split.
6. **The crease is visual only.** Level 1's `cross_level_effect` now reads
   `L2_PISTA.painting.creased`. **This is a recorded debt, not a design** — see `LEVEL_1.md`.

---

## What is built

| | |
|---|---|
| `game/config/level_02.json` | the level. Adds `restrictions`, `scrap_economy`, and `answered_by` to the schema |
| `game/config/dialogue_l2.json` | 59 lines, none naming a class |
| `game/level_2.tscn` | a **text** copy of `game_level.tscn`, three lines changed |
| `game/levels/level_2/level_2_environment.tscn` | the plaza, six parallax layers, four room shells |
| `game/scripts/level_2.gd` | the eleven hooks |
| `game/scripts/level_restrictions.gd` | the two rules, validated against `labels.json` at load |
| `game/scripts/scrap_ledger.gd` | seven pieces; none can be permanently lost |
| `game/scripts/scrap_bird_2d.gd` | five addressable birds, three verbs, one answer each |
| `game/scripts/dance_minigame.gd` | two attempts; **cannot dead-end the run** |
| `game/scripts/scrap_assembly.gd` | seven slots, drag and snap, no fail state |
| `game/scripts/piyesta_room_2d.gd` | all four insides -- one script, one contract, three dressings |
| `game/scripts/piyesta_door_2d.gd` | the plaza's four doors; two open onto a room, two are the search |
| `game/scripts/church_interior_2d.gd` | Scene 2's furniture, and the cultural guardrail in code |
| `game/scripts/kandila_2d.gd` | the candle on the table, which is what Path C is FOR |
| `game/scripts/dancer_group_2d.gd` | the dancers, and the one thing here the player can destroy |
| `game/scripts/bandarita_line_2d.gd` | the bunting: the ceiling, two scraps, and the trade |
| `game/scripts/dance_overlay.gd` | the screen the dance is played on -- lane, cues, verdicts, two goes |
| `game/scripts/assembly_overlay.gd` | Scene 3's table: seven torn pieces, drag and snap, and the end of the level |
| `tools/build_scraps.py` | tears the painting into the seven pieces, along noise-perturbed Voronoi |
| `tools/build_plaza.py` | flattens the six plates, and **cuts the painting at the walk line** |
| `tools/pixelart.py` | the shared 8-bit library: logical pixel grid, short ramps, Bayer dither |
| `tools/build_interiors.py` | original art for the four insides -- ashlar, sawali, plaster over rubble |
| `tools/build_plaza_art.py` | the plaza's ground and props -- paving, retaining wall, rooftops |
| `game/scripts/piyesta_plaza_2d.gd` | the ground under the cut painting. Nothing draws in front of the player |
| `game/scripts/piyesta_door_2d.gd` | takes `wall_tone` off the plate at its own x -- four doors, four stones |
| `game/assets/Level2/`, `level-2-assets/` | the delivered art, imported and tracked |

```bash
godot --headless --path game --script res://tests/run_level2_audit.gd
```
```bash
godot --headless --path game --script res://tests/run_level2_systems_probe.gd
```
```bash
godot --headless --path game --script res://tests/run_level2_scene_probe.gd
```
```bash
godot --headless --path game --script res://tests/run_level2_chain_probe.gd
```
```bash
godot --headless --path game --script res://tests/run_nodraw_level2.gd
```
```bash
godot --headless --path game --script res://tests/run_dance_probe.gd
```
```bash
godot --headless --path game --script res://tests/run_assembly_probe.gd
```
```bash
godot --path game --script res://tests/run_visual_level2.gd
```

---

## The art, and why almost none of it is the delivered set

The plaza arrived as a painting and a tileset. Both were used and both were wrong for the
job, in the same way twice:

* **`TextureMap_Piyesta` is the OUTSIDE of a town** -- mossy rubble with grass on top, packed
  earth underfoot. Tiled into the church it put moss and dirt inside a building that has
  neither. The interiors are authored now: dressed limestone ashlar under lime plaster for
  the nave, sawali over plank boards for the house, lime plaster over rubble with granite
  setts for the alleys.
* **`Level2_CompletedLook` is a VISTA, not a set** -- and that is a crop, not a rewrite.
  It has a low wall with planting BEHIND the dancers and a grass verge over a retaining wall
  IN FRONT of them, about sixty pixels of cobble between, and the apo is ninety-six tall. He
  spans the strip with a wall above his knees and another below. Both walls are in the
  picture, so moving the collision was never going to help. **The fix is to cut the plate at
  the painted dancers' feet** and build the ground below it: the near half goes, everything
  left stands on the cut, and there is one ground line -- the line the artist stood four
  dancers on. **Nothing draws in front of the player**; an authored kerb is how the doubling
  comes back.

Three things had to change once the plaza was a painting again, and all three are the same
lesson: **a level standing in front of a picture cannot bring its own palette.**

* **`ground.png` is not the ground.** It is a mossy rubble terrace with a grass top, plate
  rows 474..680, which in the composite runs across the picture at head height -- the artist's
  own platform, for a game where you walk along the top of it. Cut at the dancers' feet it was
  a slab of dirt hanging behind everybody. It is not composited; `mg_church` shows through and
  its bottom edge is below the walk line, so nothing is missing.
* **Reimport after regenerating an asset.** A `--script` run uses `.godot/imported` as it
  stands, and three renders were read as evidence about a backdrop that had already changed.
* **The camera needed a floor of its own.** It rests at the bottom of `world_bounds`, which
  has to be well under the plaza so a fall is caught -- so it showed three hundred units of
  retaining wall. `WorldCameraController.world_bottom_y` (Piyesta: 722) stops it, and the
  walk line sits about four fifths of the way down the frame.
* **The plates are letterboxed.** Fifty-five transparent rows at the top, which showed as a
  band of the level's flat `SkyFill` in the wrong blue. Trimmed in the tool; `SkyFill` is now
  the painting's own top sky.
* **The doors and the checkpoint lanterns were the wrong colour, twice.** First grey slabs,
  then one pale limestone ramp for all four doors -- which looked right on the sunlit church
  front and chalky in the shade under the kiosko stair. Each door now takes a `wall_tone`
  sampled off the plate at its own x, and the lantern reads `checkpoint_stone` /
  `checkpoint_moss` meta off an ancestor so Level 1 keeps its Cordillera grey.

The plaza was authored from scratch for one pass in between, themed on the **Basilica del
Santo Nino, Cebu** (`level_02.json` still records that change from Pahiyas, and the church
inside is still built to it). It was never as good as the plate. What survives of that pass
is the material under the cut -- paving, retaining wall, receding rooftops -- and the props
the rest of the level draws with.

**8-bit here is a method, not a look**: everything is drawn on a logical pixel grid and scaled
by nearest-neighbour, colour comes from six-step ramps, and gradients are ordered Bayer
dithers between two adjacent steps. One light, from the upper left, everywhere.

⚠ **The Santo Nino is drawn and never built.** It appears in the facade's niche and in the
retablo indoors, and in both places it is part of a texture: no node, no area, no collision.
`ChurchInterior2D._check_the_guardrail` still fails loudly if anybody gives it one.

## The scars

Every one of these was found by a check or a frame, not by reasoning, and every one is
now guarded.

1. **A tag membership leaked backwards into Level 1.** Adding `frog` to `startle` changed a
   Payyo hint to "A frog can LEAP or STARTLE" — naming an ability two levels early.
   `AbilityTags.tags_for_class_by_level` filters on the tag's own `unlocked_in_level`, not
   on the profile, because a hint that changes with what a previous run unlocked is a hint
   no test can pin down.
2. **`bat` was an answer the ceiling punished.** It carries `climb`, and L2_N3's Artist
   route asks the player to climb *to* the bandaritas, which **are** the ceiling. Excluded,
   and `_audit_no_route_fights_the_ceiling` guards it.
3. **An answer that cannot reach is not an answer.** `strike` resolved L2_N2's Protector
   route to boomerang, axe and sword; only the boomerang leaves the hand (`_swing_blade`
   works inside `TOOL_REACH`, 96px). The reaches are named constants now
   (`BOOMERANG_THROW`, `CANNON_RANGE`) and the audit **reads them** rather than copying.
4. **The two-answer floor has to be measured after the ban list**, because a banned class
   still carries its tag and `AbilityTags` counts it. Level 1 never needed this.
5. **The scare gate was a wall for half its own answers.** The dancers stood 900px out;
   `startle` is answered by a snake, which covers 428px in `MorphLife`'s usable window
   (R10). Moved to 300px.
6. **The scene had no obstacle volumes at all**, so no beat could ever have fired.
7. **Commit marks floated with no floor**, and the scene probe was *green while the scene
   warned twice*. The warning is a failure now — and that check was itself vacuous on its
   first run, asking a group the lanterns do not join.
8. **The level thought it was Level 1.** Running a scene directly falls back to the first
   card in `levels.json`, so `Telemetry.begin_level` and every profile write took `level_1`.
9. **The picture and the collision were 279px apart** — the apo drawn in the sky above the
   kiosko roof, in the first frame ever rendered of this level.

10. **A room that answers nothing cannot be entered.** The four insides were bare Node2Ds
    with a collision box; none joined `interiors`, so `_refresh_room_framing` never saw
    them and three of the level's four beats were unreachable. They are one script now --
    four copies of `bounds()` is four chances for one to drift off its own collision.
11. **An opening armed by a timer can never fire for a body put down inside it.**
    `body_entered` is a transition and there is no transition for a body that was already
    there, so the first alley could be walked into and not out of. Openings arm by being
    LEFT, which cannot be outrun by a fast machine or missed on a slow one.
12. **`ScrapLedger.defer` assigns; it does not add.** Correct for the ledger, whose
    `BIRDS_IN_ALLEY2` is an integer -- and calling it once per escaping bird left the count
    at one. Worse, the level recovered deferred scraps by index from `alley1_0`, when the
    birds that actually got away might be 2, 3 and 4; `recover` is idempotent, so those
    calls hit nothing. Together they finished the pragmatist route at **three of seven** in
    silence. The ledger stays a count; the level remembers which pieces went on ahead.
13. **`ScrapBird2D` had no `_draw` at all.** Five birds carrying five of the seven pieces,
    orbiting on a real physics process, invisible -- and every headless suite was green,
    because the ledger, the ids, the three verbs and the reach are all true of an object
    nobody can see. Found by looking at a frame. There is now a check that every prop the
    level places defines `_draw`.
14. **Overriding `CanvasItem.draw_ellipse` detached the whole `DancerGroup2D` class**, the
    plaza came up empty, and the scene probe stayed green. Trap 1 for the fourth time.
15. **A no-draw bot placed inside solid rock passes every "cannot" you write.** The first
    cut of `run_nodraw_level2` started at (300, 480), which is inside the left terrace; it
    stood still for twenty seconds and reported three green results. Every segment asserts
    how far the body actually travelled now.

16. **A model with no screen is a route that dead-ends, and every suite stayed green.**
    `DanceMinigame` had cues, windows, two attempts and a clear condition, all tested --
    and nothing called any of it, so committing "I will dance for them" closed the other
    two routes and then nothing happened. The same shape as `run_level1_audit` proving Beat
    0 accepted a square while the level was unplayable. `run_dance_probe` drives the screen
    rather than the model.
17. **The verdict was going to be a coloured bar.** Early and late are named separately in
    the model for one reason -- it is the whole teaching -- and a bar cannot say which way.
    The word is drawn, and it is drawn on the side of the line the stroke fell on, so a
    player who reads nothing still learns from where it appeared.
18. **The draw pad was filled with the panel's own colour**, so the surface the player is
    told to draw on was invisible and the bottom half of the screen read as empty. Found by
    looking at a frame. Sixth time.

**Three things `LEVEL_2.md` claimed about the art were wrong**, found by looking: the
`TRANSPARENT/` set is a registered 1920 × 1080 layer set and **not** a letterboxed copy
(nothing is cropped); the bandaritas are painted into **three** layers, not two; and
**`Ground.png` is not the playable ground** — the terrace, stair and kiosko are on
`FG_Huts`.

---

## What remains

Nothing here stops the level being played. It is all art, plus one decision.

1. **The `MG_People` no-dancers variant is a blocking art need again.** The plaza is the
   delivered painting, so the dancers are back in the pixels: `DancerGroup2D._draw()` is
   `pass`, and Problem 1's Protector scare is mechanically complete and visually invisible.
   The composite will not give them up -- a bbox cut takes the palm trunks behind two of
   them, a colour mask leaves the hats, hands, fans and shoes.
2. **Piyesta's INSIDES are authored placeholder, not delivered art.** They are coherent and
   the right material, but a real artist would still improve on them: the alleys use a cool
   ramp rather than a dark-palette set made for shade, and the church interior and both alley
   layer sets are still owed as painted plates.
3. **`LOLOGHOST` has no praying pose and no laughing pose.** Scene 2 is built on the first
   and every restriction violation fires the second. Nothing fakes them.
4. **The thrown-projectile aiming does not exist.** Problem 2's Protector route resolves to
   boomerang and cannon, both of which have a real reach, but there is no aim or trajectory
   preview -- the design asks for "angry birds style".
5. **The house doors are authored, not the delivered set.** They are arched stone openings
   cut into the painted wall and lit from inside, which is what the puzzle needs -- but the
   design still asks for a four-state door set: closed / lit from inside / keyhole / open.
6. **`levels.json` `scene_path` is still empty.** Nothing mechanical blocks it now -- the
   level can be started, played and finished. What it is waiting on is the art above, and
   `run_level2_audit` asserts the empty path until somebody decides Piyesta looks finished
   enough to offer from the hub. **That is a judgement call, not a task.**

---

<details>
<summary>The superseded provisional design, kept for the record</summary>

> ## ⚠ THIS WAS A TEMPORARY DESIGN
>
> There was no design for Level 2 at all — the art arrived first. This document exists so
> the level has *a* shape to argue with, and every number in it is a **target derived from
> published constants**, not a measurement off a built scene. Nothing here is loaded by the
> game: there is no `level_02.json`, no scene, no dialogue file, and `levels.json` still
> says *Coming Soon* with an empty `scene_path` — which three tests assert, so **do not fill
> that in until a scene exists**.
>
> Read **`LEVEL_TEMPLATE.md`** first — the shape, schemas, rules and build order every
> level inherits — and `LEVEL_1.md` for the worked example. This document is the template's
> first instance: the same machine with one new tag in it, and the parts that are already
> settled are settled because Level 1 shipped them.
>
> **The template's build order puts two things ahead of everything in this file:** measure
> what the new tag's classes actually do in the engine (step 2), and decide what
> `game_level.gd` becomes — fork or extract (the host is Level 1, despite the generic name).
> Neither is a design question, and both gate the rest.
>
> **What to trust here:** the inventory of delivered art, the flight code as it actually
> behaves today, and the four commitments the repo has already made (below). **What to
> throw away freely:** the beat order, the route assignments, and every pixel number.

---

## Already committed, before anyone designs anything

Four things about this level are written into files that ship today. A redesign has to
honour them or edit them deliberately.

| Commitment | Where it is written |
|---|---|
| Level 2 is **`L2_PISTA`** and Level 1 unlocks it at **CP3** | `game/config/level_01.json` — `unlocks_on_complete`, `unlocks_at_checkpoint` |
| The player arrives holding **`canvas_2_pista`**, granted at `L1_N3` | `level_01.json` → `grants_item`; picked up in the bale, or handed over on exit |
| **`fly` is Level 2's tag** — declared, glossed, deliberately empty | `tools/build_tags.py` → `HELD_TAGS`, `UNLOCK_LEVEL["fly"] = 2` |
| **Hidden Flower 2 can be destroyed from Level 1.** Node 3's Protector route sets `canvas_2_creased`, whose `cross_level_effect` is the string `L2_PISTA.hidden_flower_2.unreachable` | `level_01.json:245`, `game/scripts/game_level.gd:1229` |

That last one is the interesting one. A decision made two levels of dialogue ago — cutting
open Lola's chest rather than unlocking it — has to cost something **in this level**, and
the repo already names the thing it costs. So Level 2 owes the player a Hidden Flower 2 and
owes some players its absence.

**Naming.** The hub plate says `PISTA` (`game/scripts/hub.gd`), the artist's folder says
`Piyesta`, and `CONTENT_NEEDED.md` says *Piyesta*. Display name should be **Piyesta** —
it is the artist's own spelling and the one the folder will be committed under. The
**runtime id stays `level_2`** (profiles key on it) and the **design id stays `L2_PISTA`**,
because that exact string is compared in `game_level.gd` and rewriting it buys nothing.
This is the same split Level 1 made for Payyo.

---

## The idea, in one paragraph

Level 1 was a walk east along the terraces, and everything that stopped you was in front of
you. Piyesta is the same distance turned on its side: a town plaza dressed for the fiesta,
where what stops you is **above** you — a bunting line come down, a stage you cannot get
onto, an arch with nothing left holding it up, and a belfry. The new tag is **Fly**, and
against Level 1's ten-second morph clock flight is not travel: it is the seven usable
seconds in which you have to decide *where you want to be standing when it runs out*.

---

## What the art actually is

Delivered in `LEVEL2_Piyesta/`, untracked at the repo root. **It should be committed as
`level-2-assets/`**, matching `level-1-assets/`, and only then cut into `game/assets/Level2/`.

**Two copies of the same seven pictures.** The flat files are 1672 × 941 composites; the
`TRANSPARENT/` set is the same art letterboxed into **1920 × 1080** — 124 px of margin left
and right, ~70 px top and bottom. 1920 × 1080 is exactly Level 1's parallax layer size, so
**the `TRANSPARENT/` set is the one to import**, and the margin has to come off (or be
accounted for) before anything tiles.

| File | What it is | Level 1's equivalent band |
|---|---|---|
| `TRANSPARENT/13.png` | `BG_Sky` — flat gradient, a few far clouds | `scroll_scale` 0.02 |
| `TRANSPARENT/12.png` | `BG_Clouds` — cumulus **with a bunting line drawn into them** | 0.08 |
| `TRANSPARENT/8.png` | `MG_Church` — the stone church, town houses, hills | 0.18 |
| `TRANSPARENT/9.png` | `MG_People` — dancers, two pairs of children, the woven palm arch with its *aranya* crown, banner poles | 0.38 |
| `TRANSPARENT/11.png` | `FG_Huts` — the kiosko and its stone stair, the market stall, lamp post, clay jars, bunting | 0.72 |
| `TRANSPARENT/10.png` | `Ground` — a raised left terrace with a stone stair down, a long low run, one step up | 1.08 (playable) |
| `TRANSPARENT/7.png` | `TextureMap_Piyesta` — the tileset (also flat at 1448 × 1086) | `assets/Level1/texturemap.png` |
| `Level2_CompletedLook.png` | Reference composite. Not an import. | — |

⚠ **The bunting is baked into the clouds layer.** `BG_Clouds` has a *banderitas* line
painted across it at 0.08 scroll. If the level's first Fly gate is "get the line back up",
the line the player fixes is a foreground object and the painted one is scenery — two
bunting lines on screen at different depths, one interactive and one not. Either strip it
out of the cloud plate or pick a different first gate. This is trap 2 of
`ART_PLACEHOLDERS.md` ("nothing may imply an affordance it does not have") waiting to
happen.

⚠ **One plaza is not a level.** Level 1 runs x 0 → 4760. The plaza is one screen and a bit.
The backdrops tile; the ground the player stands on gets **composed from
`TextureMap_Piyesta.png`** the way the terraces are composed from Level 1's atlas — and the
tileset is generous enough for it: plaza flags, mossy stone, church stucco with a window,
terracotta roof, thatch and plank, full nine-way edge sets for three materials, stairs,
ledge caps, and a decorative shelf of banners, lanterns, potted plants, clay jars,
balustrade and festival ornaments.

⚠ **Trap 10 applies here too.** Those tiles are labelled *and gridded*, which the Level 1
atlas was not — so `atlas_tile.gd` should have an easier time. Take the band you mean;
do not fill a polygon from the page.

**The hub already shows this art.** `assets/hub/paintings/level_2.png` is a 128 × 72
downscale of `Level2_CompletedLook.png`, and `bale_interior_2d.gd` preloads it as
`PISTA_ART` — the canvas leaning against the wall inside the bale *is this plaza*. Whatever
the level becomes, it has to look like the picture the player was shown in Level 1.

⚠ **`CONTENT_NEEDED.md` was wrong about this level** and is corrected as of this document:
it described Piyesta as a "night festival, neon". The delivered art is **broad daylight**.

---

## The new tag: Fly

`tags.json` says `fly` is `declared_only`, `unlocked_in_level: 2`, and empty. Populating it
is the single most consequential thing this level does, because a tag membership works at
**every** obstacle asking that tag, forever.

**Proposed membership** — to be added to `LEVEL_1_TAGS`'s successor table in
`tools/build_tags.py` and regenerated. **Do not hand-edit `tags.json`.**

```python
"fly": ["bird", "bat", "butterfly", "bee", "parachute", "umbrella"],
```

Six members, and they are **three different things**, which is the whole design of the
level. This is not a guess — it is what `playable_entity._drive_flier` does today:

| | classes | gravity | tap `jump` | **hold** `jump` |
|---|---|---|---|---|
| **Flutter** | butterfly, bee | 0.34 | −250 impulse | **−390 force — a real, sustained climb** |
| **Soar / auto** | bird, bat | 0.82 | −330 impulse | glide only: caps descent at 105 px/s |
| **Canopy** | parachute, umbrella | — | — | not a body at all; `_umbrella_open` caps descent at 130 px/s |

So under one tag: two classes that **go up and stay up**, two that **climb in ~68 px steps
and then hang**, and two that **only come down more slowly**. The exclusion list is
therefore the lesson, exactly the way `span` excludes `bridge` and `ladder` at Beat 0's
stair:

- An obstacle asking Fly **for height** must `exclude: ["parachute", "umbrella"]` → four
  answers. Otherwise a player draws an umbrella, the tag layer accepts it, and nothing
  happens — the worst failure this game has, because the game agreed with them.
- An obstacle asking Fly **for distance or descent** excludes nothing → six answers.

**Left out on purpose:** `hot_air_balloon`. It is in the roster and in `object_sizes.json`
at 164 × 220, but `game/objects/` has no scene for it — it would fall through to the generic
`utility_object`, which is a placed prop and not a ride. Add it to `fly` when it can carry
somebody. **`cloud` is left out too**, though it is tempting: it belongs to `weather`, and a
176 × 100 placed cloud is a platform, which is `span`'s job.

**This retires three of the fifteen unhintable classes.** `tags.json` predicts it in so
many words — "a bird ... is unhintable today and will not be once Fly ... exist". Adding
this membership makes **bird, parachute and umbrella** requestable for the first time.
`hot_air_balloon` stays unhintable until it has a scene.

---

## R9 — what makes a gate a Fly gate *(proposed rule)*

`GATES.md` R7 says a gate must have **at least 180 px of clear ground on the approach side**,
because a gate you cannot build against is unplayable. Fly is the exception that proves it,
and it needs its own rule or every Fly gate in this level will be answered with a ladder.

> **R9 (proposed).** *A Fly gate is a gate with nothing under it to build on.* It must
> either stand more than **362 px** above the nearest surface wide enough to build on, or
> offer less than **180 px** of floor beneath it. Preferably both.

362 is not a taste. It is the tallest thing the player can place and then jump off:

| stacked answer | reach |
|---|---|
| drawn primitive 80 + jump 94.3 | 174 px |
| `stairs` 232 × 176 + jump | 270 px |
| `ladder` 72 × **244** + jump | 338 px |
| `tree` 150 × **268** + jump | **362 px** ← the number to beat |
| `bridge` **340** long | the number a Fly *crossing* has to beat |

A Fly gate at 300 px is a `climb` gate wearing a costume. A Fly crossing under 340 px is a
`span` gate. This is **X15 from Level 1 pointed the other way**: there, the obstacle asked
for something none of its own answers could do; here the danger is an obstacle whose answer
is something it never asked for.

---

## The beats *(all of this is the throwaway part)*

Four beats, west to east, in Level 1's shape: a tutorial with no fail state, then three
dialogue nodes with three routes each, then the exit. Route meanings carry over —
**Artist** restores Lola's work, **Pragmatist** takes the plain physical way,
**Protector** forces it and leaves a mark on the world.

### B0 — Ang Banderitas (tutorial, no dialogue node, no fail state)

The plaza is dressed but the long bunting line has come down at one end. Lolo will not
explain flight; he will point at the crosstree it is supposed to be tied to.

- **sub1 = Fly, for height.** `exclude: ["parachute", "umbrella"]`. The banner pole's
  crosstree is **~420 px** above the plaza flags — clear of R9's 362 — and the balustrade
  and potted plants leave under 180 px of buildable floor beneath it. Four answers: two
  that hold a hover (butterfly, bee) and two that have to work for it in flaps (bird, bat).
- **sub2 = Fly, for distance.** `exclude: []`. From the crosstree, the far anchor is
  **~430 px** across and 260 px down — past `bridge`'s 340. Now the umbrella works, and
  the canopy classes get their one moment where they are the *elegant* answer rather than
  the wrong one.
- **CP0** where the line goes taut.

Two sub-beats, one tag, opposite exclusion lists. That is the entire teaching load of this
level and it happens before anyone says a word about routes.

⚠ **Order matters and this is the order.** Level 1 shipped its Beat 0 backwards for two
months (X15). Up first: the player learns that Fly means *up* while the only classes
present can actually go up. Across second: the exclusion comes off and the set gets bigger,
which reads as a reward. Reverse it and sub1 teaches "Fly means glide", after which the
tall gate is unanswerable with the mental model the game just handed out.

### L2_N1 — Ang Entablado (the kiosko)

The stage the band should be playing on, up on its stone platform. Its stair is out. The
platform is ~330 px up with a 200 px shelf in front of it — **buildable on purpose**, so
this node is answered three ways rather than by Fly again.

| route | tag | exclude | notes |
|---|---|---|---|
| Artist | `span` | — | Rebuild the stair the way she painted it. 4 answers. Reward: the memory cutscene. |
| Pragmatist | `climb` | `crab`, `snake` | Up the corner post. 6 answers after exclusions. |
| Protector | `fly` | `parachute`, `umbrella` | Straight over the balustrade — and you land on thatch, which gives. `persistent_effect: kiosko_thatch_holed`. 4 answers. |

**CP1** on commit.

### L2_N2 — Ang Arko (the woven palm arch)

The arch with the *aranya* crown, and the plaza narrows so that it is also the way east.
The crown is down on the flags.

| route | tag | exclude | notes |
|---|---|---|---|
| Artist | `carry` | `horse`, `elephant` | Bring the crown back and hang it. 4 answers. Reward: sketchbook page, `sets_flag: knows_about_bell`. |
| Pragmatist | `fly` | — | Over the top and down the far side. A descent, so all 6 answers. |
| Protector | `cut` | `elephant` | Cut the lashings and walk through. 3 answers. `persistent_effect: arko_down`. |

⚠ **The Protector cost here is social, not material.** See the cultural guardrails: the
arch is food. What the player breaks is the *fiesta* — the dancers stop, the plaza empties
for the rest of the level, and the closing beat happens to a bare square. That is a heavier
mark than a hole in a prop and it costs nobody a grain of rice.

**CP2** on commit.

### L2_N3 — Ang Kampanaryo (the belfry) — and the level does not end until it is answered

The church, its steps, and the bell tower. Mirrors G8: choosing one of Lolo's three lines
is free and is not an answer.

| route | tag | exclude | notes |
|---|---|---|---|
| Artist | `fly` | `parachute`, `umbrella` | Up to the belfry window, the way there is a bird in her painting. Reward: `item_photograph_*`; halved search if `knows_about_bell`. 4 answers. |
| Pragmatist | `unlock` | — | The side door. **2 answers** — the audit will print this, as it prints Level 1's five. |
| Protector | `cut` | `elephant` | Cut the bell rope down and climb it. `persistent_effect: bell_silent` — the fiesta starts without the bell. 3 answers. |

**CP3** on commit → this is the checkpoint that unlocks Level 3. **CP4** at the exit.
`grants_item: canvas_3_dagat`; `unlocks_on_complete: "L3_DAGAT"`.

### Hidden Flower 2

**In the belfry, above the bell.** Gated on **`strike`** — a Level 3 tag, empty today, whose
gloss is "able to hit hard in one place". So it behaves exactly as Hidden Flower 1 does in
the cave: visible, `canvas_opens_normally_entities_spawn_inert`, **not a fail state**, and
collectable on a later visit.

And if the player creased the canvas in Level 1, **the crease runs through the top of the
tower**. There is no paint up there, so there is nothing to find and never will be. That is
what `L2_PISTA.hidden_flower_2.unreachable` buys.

---

## Gates *(targets, not measurements)*

Nothing is built, so nothing is measured. These exist so that whoever lays out the scene
knows what each gate has to beat.

| id | where | what must stop you | target | opens with |
|---|---|---|---|---|
| **P1** | the fallen bunting | height with no floor under it | **> 362 px** up, **< 180 px** of floor | Fly (height) |
| **P2** | crosstree → far anchor | a gap longer than a bridge | **> 340 px** across | Fly (any) |
| **P3** | the kiosko | a platform face | ~330 px, **with** a 200 px shelf | Span / Climb / Fly |
| **P4** | the arch | the way east is 200 px of woven palm | — | Carry / Fly / Cut |
| **P5** | the belfry | the level will not end until it is answered | **> 362 px** from the church steps, which are **< 180 px** deep | Fly / Unlock / Cut |

**T1 and T2 apply unchanged.** A `run_nodraw_level2.gd` that finishes the level is a bug,
and every gate above needs its opening half tested too (R3). A Fly gate that cannot be flown
in the time available is a wall, and it will look exactly like a puzzle in a green report.

---

## The ten-second clock is this level's whole difficulty

`MorphLife` is 10 s, and its own comment says the question at every obstacle is *"where do I
want to be standing when this one runs out"*. In a level about height that stops being a
nice line and becomes the design.

- **Every Fly gate must be answerable in ~7 s** of flight with 3 s of margin, from the
  ground the player is standing on when they draw. Nobody has measured how fast a bird
  climbs — `_rig_impulse` is an impulse on a rigid body, so mass and the drawn shape both
  matter, and two players' birds will not climb at the same rate. **Measure this before
  anything else in this document is worth costing out.**
- **Expiry mid-air is a fall.** `_revert_to_base_form()` puts the apo where the creature
  was. There is no fall damage in this project, so the punishment is losing the height and
  the ink — which is a fair punishment, and only stays fair if **there is nothing under a
  flight path but plaza stone**. This level must not put water, a pit or a hazard under
  anything the player is expected to fly over. Level 1's paddy is a gate; here the same
  idea would be a tax on every attempt.
- **Ink is 12** and `GATES.md` already flags that a full run has never been measured against
  it. This level asks for a drawing at P1, one at P2, one per node, and flight is the
  easiest thing in the game to have to redo. Piyesta is where the budget breaks if it
  breaks. Count it before playtesting, not after.

---

## Cultural guardrails

Level 1 asserted its guardrails in code rather than documenting them, and this level needs
the same treatment. The plaza is a church plaza and the fiesta is a religious feast.

- **The church is not a puzzle.** No cutting, burning, breaking or standing on any sacred
  image — the cross on the pediment, the santo, the carroza if one is ever drawn. The
  **bulul rule ported**: zero collision, zero interaction, zero puzzle function, asserted
  in the script that builds them. The belfry may be climbed and the bell may be rung —
  people do both — and the side door may be unlocked. The altar may not be reached.
- **The arch is food.** The *aranya* and the woven leaves are **kiping**, which is made of
  rice. This is `straw_pile_is_grain: false` from Level 1 wearing different clothes: cut
  straw could be scattered because it was not a harvest. Kiping *is* the harvest. So the
  Protector route cuts **lashings**, the arch swings aside intact, and no rice is trampled
  on screen.
- **Audio inverts Level 1's list.** Payyo forbids `bandurria` because it is not Cordilleran;
  in a lowland plaza the *rondalla* and the town brass band are exactly right. Use
  bandurria, brass band, church bells. **Forbid** recordings of actual liturgy — a real
  Mass or a real prayer looped as ambience is not ambience.
- **Name the fiesta or keep it generic, but decide.** A palm arch crowned with a kiping
  *aranya* is specifically **Pahiyas**, Lucban, Quezon, for San Isidro Labrador, 15 May.
  The art has already made that choice. Either commit to it and get the details right, or
  ask the artist to drop the aranya. Half-committing is the failure mode.
- **No dialogue line may name a drawable class.** Level 1's hardest authoring constraint
  and it does not relax. Watch this level's vocabulary in particular: *kampana*, *susi*,
  *pinto*, *hagdan*, *puno* and *ibon* are all classes in the roster, and *ibon* is the one
  this level most wants to say out loud.

---

## What is temporary about this, specifically

Everything below is a real question this document answered by picking something.

1. **Is the new tag really `fly`?** `tags.json` says so. It is also the only held tag whose
   rigs already exist. Treated as settled.
2. **Beat order and route assignment.** Invented here. The one part with an argument behind
   it is B0's up-then-across ordering (X15).
3. **Every pixel number.** All derived from `object_sizes.json` and R1–R7, none measured.
4. **The geography.** The delivered art reads left-to-right as kiosko → plaza → arch →
   church → stall, and the beats above assume the player moves east through it in that
   order. If the scene is laid out differently, the beats move; nothing else changes.
5. **What Protector costs at N3.** `bell_silent` is local. Level 1's Protector at N3 reached
   *forward* into this level. Whether N3 here should reach into `L3_DAGAT` the same way is
   an open question and should be answered when Level 3 has a design, not now.
6. **Whether N1 needs to exist.** Three nodes is Level 1's shape, not a law. If this level
   is thin, N1 is the one to cut — B0 already teaches Fly twice and N1 mostly repeats it.

---

## If this becomes real, in this order

1. **Measure the bird.** Draw one, hold jump, and find out how high it gets in 7 seconds and
   how far a flutter climb goes. Every number in this document is downstream of that, and it
   is one afternoon.
2. Commit the art as `level-2-assets/`, cut the `TRANSPARENT/` set into `game/assets/Level2/`,
   strip the letterbox margin.
3. Add `fly` to the design table in `tools/build_tags.py`, regenerate, and run
   `python3 tools/build_tags.py --check`. Confirm bird/parachute/umbrella leave the
   unhintable list and that no obstacle drops below two answers after exclusions.
4. Write `game/config/level_02.json` against `level_01.json`'s schema, and
   `dialogue_l2.json` against `dialogue_l1.json`'s. Port the load-time assertions verbatim.
5. Build the scene, then fill in `levels.json` — **`scene_path` last**, because three tests
   assert Level 2 is not playable while it is empty and they are right to.
6. Port `run_level1_audit.gd`, `run_nodraw_level1.gd` and `run_walk_level1.gd`. The nodraw
   bot is the one that matters: a plaza is flat, and a flat level is the easiest kind to
   finish by walking.
7. **Look at the frames.** `run_visual_*` needs a real viewport. Four defects in this project
   passed green suites and were caught only by screenshotting, and this level's whole idea
   lives in the vertical axis, which is the axis a headless test reports as a number.

</details>
