# Content still needed from the team

**What this file is.** The game code is ahead of the game's *content*. Everything below
is authored material — writing, character design, art, audio — that **the developers have
not made and are not going to invent**. Where something was needed to make a system
testable, a developer wrote a placeholder and said so in the code; those placeholders are
listed here too, because shipping them would be worse than shipping nothing.

**How to use it.** Each entry says where the finished thing plugs in and what the code
already expects, so a delivery drops in without a code change. When something is ready,
tell the developers and point at the row.

**Authority for content decisions** is `Game Design.pdf` and `50 Classes.pdf` (in the
Arc/obra folder), not this file and not the code. Where they disagree with something
built, the documents win and the code is the bug.

Status key: **MISSING** = does not exist · **PLACEHOLDER** = a developer stand-in is in
the build right now and needs replacing · **READY** = code and hook exist, waiting on you.

---

## 1. Writing

| What | Status | Where it goes | What the code expects |
|---|---|---|---|
| Lolo's Level 1 lines | **PLACEHOLDER** | `game/config/dialogue.json` → `levels.level_1` | Written by a developer to make the level playable. Keys: `greeting`, `climb`, `node` (`speaker`/`context`/`choices`), `routes` (one per route), `memory` (`title` + `lines[]`), `cave`, `arrival`. Replace the strings; no code change. |
| The three dialogue-node choices | **PLACEHOLDER — verbatim from the design** | same file, `node.choices` | Currently copied word-for-word out of `Game Design.pdf`. If the final script rewords them, change them here. The route ids `artist` / `pragmatist` / `protector` must not change — the ending resolver counts them. |
| Levels 2–5 dialogue | **MISSING** | `game/config/dialogue.json` → add `level_2` … `level_5` | Same shape as `level_1`. Nothing is hardcoded per level, so a new block is all it takes. |
| The Level 1 memory of Lola | **PLACEHOLDER** | `dialogue.json` → `level_1.memory.lines[]` | Three lines a developer wrote. The design calls for "a memory cutscene showing Lola painting this exact bridge" — see §5 for the cutscene itself. |
| Ambient / hint dialogue pool | **MISSING** | not built yet — see §6 | Design §4.1 calls for a **priority queue / shuffle bag**: unseen lines weighted +100, recently played drop to 0 and recover over time, so a player replaying Level 1 hears three different stories. Right now each key holds exactly one line and repeats it. **We need the pool of lines before the system is worth building** — how many alternates per beat is a writing decision. |
| Path-nudge dialogue | **MISSING** | same system | Design §4.2: on replay, Lolo suggests the path not taken ("We rushed past this last time… shouldn't we stay and fix the bridge today?"). Needs one nudge line per route per level. |
| Ending text | **MISSING** | `game/scripts/ending_screen.gd` renders it | The four endings resolve correctly and are titled (*The Masterpiece*, *The Rushed Sketch*, *The Protector's Canvas*, *The Persevering Spirit*). There is **no ending prose** — the screen shows a title and the player's stats. |

---

## 2. Character design

| What | Status | Where it goes | Notes |
|---|---|---|---|
| **The player character** | **DONE** (2026-08-24) | `game/assets/characters/apo/`, cut by `tools/build_art.py` | The delivered design sheet, twenty-three poses: a turnaround, a six-frame walk, a six-frame run, and idle / look up / look down / wave / jump / cheer. `wanderer_figure.gd` draws them; `Wanderer._pose_for` picks which. Six are wired to gameplay — the walk and run cycles, idle, the jump, and the two look poses — and climbing borrows the turnaround's BACK view. **Wave and cheer are cut and unused**: cheer is the obvious level-complete pose and wave the obvious one for talking to Lolo, and neither is wired to anything yet. |
| **Lolo** | **DONE** (2026-08-25) | `game/assets/characters/lolo/`, cut by `tools/build_art.py` | The delivered ghost sheet, laid out to the same grid as the apo's and cut by the same script. `lolo_figure.gd` draws them; `lolo.gd` picks which. He came back a floater as hoped — the walk and run cycles undulate a tail rather than stepping, so nothing has to meet the ground and the follow behaviour was untouched. Those two are wired as `float` and `hurry`; **still, wave, cheer and the turnaround are cut and unused.** He is drawn at 84px against the apo's 96, and anchored on the middle of his body rather than on his feet, because he never touches the floor. |
| **Lolo's dialogue portrait** | **DONE** (2026-08-25) | `game/assets/characters/lolo/lolo_wave.png` | The speaker behind the dialogue box is the WAVE pose off each sheet — a raised hand and an open mouth, which reads as a line being spoken. The SubViewport that used to rasterise the code-drawn blob at its own size and blow it back up is gone, and with it the half-height rule that kept it from filling the corner; the two speakers differ in one number now, which is where the bust is cut. **The hero cards are still cut and shipped as `*_portrait.png` and nothing loads them** — they are the more detailed drawing but the wrong pose, a character standing still and looking at the camera. Swap the two entries in `dialogue_portrait.gd` to get them back. |
| **Lola (the grandmother)** | **MISSING** | — | Appears in the Level 1 memory and at the Level 5 climax. No design, no art, no representation anywhere in the build. |
| **Dilim's creatures** | **PLACEHOLDER — authored strips** (2026-10-19) | `game/assets/Level4/creatures/<kind>_<anim>.png`, cut by `tools/build_dilim_creatures.py` | All of them: the aswang (**the lean one** and **the old one**, `aswang_dog` and `aswang_pig`, six strips each: `idle`, `run`, `windup`, `attack`, `hurt`, `death`), santelmo, nuno's mound, sigbin, tikbalang, kapre and its balete (standing and felled), tiyanak, bungisngis, manananggal (both halves), wakwak and tik-tik. A developer sculpted them in the game's idiom -- chibi, cel-lit from the upper left, each part edged in a darker tone of its own colour -- and they read inside the lantern's light. `ART_PLACEHOLDERS.md`, "Dilim", names every strip and what each body has to say; a delivered set with the same names drops straight in. `run_visual_dilim_creatures.gd` lays them side by side in her light. The aswang is its night form, crawling; its day form, a woman, nothing shows. |
| Lolo's spirit form | **MISSING** | — | Ending C has Lolo "sacrifice his spectral form". Undesigned. |

> The drawn creatures and objects the *player* makes are **not** on this list — those are
> generated from the player's own strokes at runtime and need no art.

---

## 3. Environment art

| What | Status | Where it goes | Notes |
|---|---|---|---|
| Level 1 backgrounds & tiles | **READY** | `game/assets/Level1/` | Parallax layers and a texture atlas, in use. |
| **All of Level 1's props** | **PLACEHOLDER** | code-drawn | Fifteen of them, and they now have their own brief: **`ART_PLACEHOLDERS.md`** lists every one with its exact size, its anchor, its collision, what the player has to understand from it, and every state it needs. `run_visual_props.gd` photographs the lot. That file supersedes this row. |
| **Level 2 art** | **DELIVERED, not imported** (2026-08-28) | `LEVEL2_Piyesta/` at the repo root | Six parallax layers and a labelled tileset for **Piyesta**, a church plaza in **broad daylight** — this row used to say "night festival, neon" and that was wrong. The `TRANSPARENT/` set is 1920 × 1080, matching Level 1's layers, with the 1672 × 941 art letterboxed inside it. Commit as `level-2-assets/`, then cut into `game/assets/Level2/`. Inventory and per-file mapping: **`LEVEL_2.md`**. |
| **Level 2's four insides and their contents** | **AUTHORED 8-BIT PLACEHOLDER** (2026-08-31) | code-drawn, `piyesta_room_2d.gd`, `church_interior_2d.gd`, `piyesta_door_2d.gd`, `kandila_2d.gd` | The delivered set is the plaza and nothing else. The design lists all of this under what does not exist: the **church interior** (nave, altar, candle rack, pews, window light — `MG_Church` is a facade), **Alley 1 and Alley 2** (background, midground, foreground, ground), a **dark-palette variant of `TextureMap_Piyesta`**, the **house door set** (closed / lit from inside / keyhole / open) and its small interior, and the **kandila** in three states. The interiors are now ORIGINAL 8-bit art, authored by `tools/build_interiors.py` on a logical pixel grid with short colour ramps and Bayer dithering — **not** the plaza tileset, which is the OUTSIDE of a town (mossy rubble, packed earth) and was wrong indoors. Church: dressed limestone ashlar under lime plaster, stone flags, timber ceiling, arched window, pews, retablo with a santo, candle rack. House: sawali over plank boards under nipa, capiz shutter. Alleys: lime plaster over rubble with the render fallen away, damp, granite setts and a drain. **Still owed by a real artist**: the church interior and both alley layer sets as painted plates, and the dark-palette tileset — this is a good placeholder, not the delivered set. |
| **Level 2 plaza** | **DELIVERED PAINTING, CUT** (2026-09-01) | `tools/build_plaza.py` + `tools/build_dancers.py` → `game/assets/Level2/plaza_backdrop.png` | The plaza is `Level2_CompletedLook` — the six plates flattened offline (they are one painting, not a parallax rig), **cut off at the painted dancers' feet**, and composited **without `ground.png`**. Two deliberate omissions: the crop is the fix for the doubled platform (the painting is a vista with a wall behind the dancers and a verge in front, sixty pixels apart, and the apo is ninety-six tall — both walls are *in the picture*), and `ground.png` is not ground at all but the artist's own head-height terrace, which read as a dirt platform hanging behind everybody. `mg_church` shows through and reaches below the walk line, so nothing is missing. ✅ **The `MG_People` no-dancers blocker is CLOSED**: `build_dancers.py` lifts all four dancers out of the plate — two as clean components, two by clearing the box and regrowing the palm leg behind them — so Problem 1's Protector scare empties the plaza on screen for the first time. |
| **Level 4 art** | **DELIVERED, CUT IN PART** (2026-10-16) | `LEVEL4_Mt.Makiling/` at the repo root → `tools/build_dilim.py` → `game/assets/Level4/backdrop/` and `tiles/` | `Mt Makiling Level 4.zip`: forest plates and a labelled tileset, **no creature art**. Six plates are cut and in use (sky, two mountains, two grounds, the vine frame -- the frame stands only behind her, since in front of play it hid her) and four seamless tiles (leaf, mud, mossy stone, path). Not cut, because nothing has needed them yet: the slopes, root and log platforms, the waterfall and mist, and the props. |

---

## 4. Audio

**There is no sound in the game yet, and the code is built so that is a content gap, not a code
one.** `AudioDirector` (`game/scripts/audio_director.gd`) plays a sound by id; the ids live in
`game/config/audio.json` with empty paths, so every call is written and does nothing until an
`.ogg` is named beside its id. The profile keeps master, music and SFX volumes and `AudioDirector` applies
them to the buses; the Settings screen's sliders for them are taken out until there is something to hear
(their rows come back in `ui/settings_overlay.tscn`).

| What | Status | Where it goes | Notes |
|---|---|---|---|
| UI sounds | **MISSING** | `audio.json` → `sfx.ui_click`, `ui_open`, `ui_close` | Already called by the UI; a file is all they need. |
| Level and pickup sounds | **MISSING** | `audio.json` → `sfx.level_complete`, `checkpoint`, `item_acquired` | Ids exist; not all are called yet. |
| Music | **MISSING** | `audio.json` → `music.menu`, `music.level_1` | One id per level is the shape; Levels 2–5 have none yet. |
| **Dilim's sounds** | **MISSING — ids READY** (2026-10-19) | `audio.json` → `sfx.tiktik_call`, `tiyanak_cry`, `lantern_hit`, `dawn` | Played already, silent until a file is named. The **tik-tik's call** plays at its call's strength (louder the further off it is), and the **tiyanak's cry** at its ripple's (`play_sfx` takes a loudness). The lantern's hit and the dawn play at full. The design: "every audio cue has a visual equivalent" -- the edge ripples (`EdgeRipple.cue`) stay when a sound is delivered; they are how a player who cannot hear plays the level. The santelmo and the aswang have no sound and no ids yet. `run_level4_sound_probe` checks each is asked for. |
