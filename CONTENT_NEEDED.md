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
| **Lolo** | **PLACEHOLDER** | `game/scripts/lolo_figure.gd` | A floating yellow blob with a leaf and two dot eyes, drawn in code. Same deal: one file. He is deliberately a floater, not a walker, so he needs no walk cycle — if the design gives him legs, tell us, because that changes the follow behaviour. His speech bubble is a separate node (`creatures/lolo.tscn` → `Bubble`) and can be restyled independently. |
| **Lola (the grandmother)** | **MISSING** | — | Appears in the Level 1 memory and at the Level 5 climax. No design, no art, no representation anywhere in the build. |
| **The Aswang** | **MISSING** | — | Level 4's confrontation (design §6). Nothing exists. |
| Lolo's spirit form | **MISSING** | — | Ending C has Lolo "sacrifice his spectral form". Undesigned. |

> The drawn creatures and objects the *player* makes are **not** on this list — those are
> generated from the player's own strokes at runtime and need no art.

---

## 3. Environment art

| What | Status | Where it goes | Notes |
|---|---|---|---|
| Level 1 backgrounds & tiles | **READY** | `game/assets/Level1/` | Parallax layers and a texture atlas, in use. |
| **All of Level 1's props** | **PLACEHOLDER** | code-drawn | Fifteen of them, and they now have their own brief: **`ART_PLACEHOLDERS.md`** lists every one with its exact size, its anchor, its collision, what the player has to understand from it, and every state it needs. `run_visual_props.gd` photographs the lot. That file supersedes this row. |
| **Levels 2–5 art** | **MISSING** | `game/assets/Level<N>/` | Piyesta (night festival, neon, buntings) · Dagat (storm sea, Coron cliffs) · Dilim (pitch-black forest, bioluminescence) · Mayon (erupting paint). Nothing exists for any of them. |
| **Lola's Studio (the Hub)** | **MISSING** | — | Design §2.2 anchors the whole game here — paintings on easels act as level portals. **It does not exist at all.** Right now the game goes menu → level select → level. This is the single biggest missing piece of structure, not just art. |
| Hidden Flowers 2–5 | **MISSING** | one per level | Flower 1 is placed in Level 1's gorge cave. The rest need their levels to exist first. |

---

## 3b. Interface

**Nothing outstanding.** The HUD, the menus and every overlay wear the 8-bit skin in
`HUD-assets-ideas/`, story boxes wear a drawn picture frame, and the whole game is set in
**Geist Pixel** (SIL Open Font License 1.1, bundled with its licence in
`game/ui/fonts/`), so no licensing decision is pending on anyone. **HUD_SKIN.md** says how to change
any of it.

## 4. Audio

**Status: nothing recorded, everything wired.** `game/config/audio.json` lists sound ids
with empty paths, and the audio director treats an empty path as "no file yet" and stays
silent. **Dropping a file path into that JSON is the entire integration** — no code change.

| Id | Status | Notes |
|---|---|---|
| `music.menu`, `music.level_1` | **MISSING** | Level 1 wants a "slow, acoustic *bandurria*" (design §6). |
| `sfx.ui_click`, `ui_open`, `ui_close`, `level_complete` | **MISSING** | Called already; silent. |
| Levels 2–5 music | **MISSING** | Add ids alongside `level_1`. |
| **Dynamic audio engine** | **MISSING** | Design §7: the mix strips layers when the player is speedrunning and adds strings when they explore. Needs stems, not a single mixdown — **tell us how the tracks are layered before they are bounced**, because that decides the file structure. |

---

## 5. Cutscenes & sequences

| What | Status | Notes |
|---|---|---|
| Level 1 memory (Lola painting the bridge) | **PLACEHOLDER** | Currently a text overlay with three lines and a CONTINUE button (`ui/memory_overlay.tscn`). It works and is on the Empathy route, but it is prose where the design says *cutscene*. The hook — `present(title, lines)` and a `dismissed` signal — is what a real sequence would replace. |
| Every other cutscene | **MISSING** | Design names memory cutscenes in Levels 2 and 4, an underwater ballet in Level 3, and the Level 5 climax. None exist. |
| Level 5 dynamic layout | **MISSING** | Design §6: Level 5's physical layout is generated from the paths taken in Levels 1–4. The telemetry that would drive it is being recorded already; the level is not built. |

---

## 6. Systems the developers still owe (not your job — listed so nothing looks forgotten)

These are **developer** gaps, flagged here so the team can see the whole picture:

- **Priority-queue dialogue** (design §4) — blocked on the line pool in §1.
- **Lola's Studio hub** — the level-select screen stands in for it.
- **Levels 2–5** — the level catalog lists them as locked "Coming Soon"; the framework
  loads any level from config, so they are content-blocked, not code-blocked.
- **Level furniture for the drawn tools.** All 27 utilities work, but **Level 1 places
  exactly one target: the dead tree on the Protector route.** Every other tool acts on
  loose physics bodies and water because there is nothing authored for it to act on. The
  contracts are written, tested and waiting — placing them is level-design work, not
  code:

  | Contract | What it wants placed | Which tools it would give a purpose |
  |---|---|---|
  | `Destructible2D` | wooden barricades, crates, roots, thick vines | axe, sword, scissors, cannon, anvil (`tool_effectiveness` already names them) |
  | `Lockable2D` | a locked door or chest | key |
  | `ConceptGate2D` | anything needing a concept from a later level | whatever the gate names — the gorge cave already uses one for the Flashlight |
  | `UtilityRequirement2D` | "this room needs X used in it" objectives | any tool, as a level-completion condition |

  Until these are placed, a player who draws a sword or a key gets a tool that works
  and has nothing to work on, which reads as the tool being broken. **This is the
  single highest-value thing a level designer can add**, and it needs no code.

---

## What is already done, so you can plan around it

- The drawing → recognition → ability loop works, live, on all 50 classes.
- Placement of drawn objects works; all 27 utilities do something when used.
- Level 1 is built and playable end to end, with the gorge and all three routes.
- Route choices, class diversity, redraw rate and collectibles are recorded, and the
  four endings resolve from them.
- Save/profile, pause, settings, level select and level completion all work.
