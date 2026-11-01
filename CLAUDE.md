# OBRA — instructions for the coding agent

You are working on **O.B.R.A.**, a thesis game. The player draws a freehand sketch, and a CNN classifies it into one of **50 classes** (20 creatures, 27 objects, 3 primitives). The game then either turns the player into the drawing (a physics-rigged "morph" built from their actual strokes) or makes it a placeable utility. Abilities come from **ConceptNet, resolved offline** into a static table, with no runtime queries.

- **Client:** Godot **4.7** (standard build, not .NET), in `game/`.
- **Recogniser:** FastAPI + ONNX Runtime, in `backend/`. It classifies only; all animation and physics live in Godot.
- **Model and data:** `model/` (Quick, Draw! training, ONNX export) and `shared/` (manifest validation).
- **Repo:** `hyuuuan/OBRA` on GitHub.

The thesis manuscript governs where it and the SRS disagree.

---

## 1. Read these before you touch anything

1. **`AGENTS.md`**: the architecture contracts, notes on every level, the traps this project keeps re-learning, and the commands. It is long; read the Project Map, Stable Contracts, Building a level, your level's section, and **Traps** in full.
2. **`LEVEL_TEMPLATE.md`**: the shape every level has, the gate rules R1–R9, the invariants to assert, the tests a level owes, and the build order.
3. **`LEVEL_<N>.md`** for the level you are on. For Mayon that is **`LEVEL_5.md`**. Its "Decisions — do not re-litigate" table is settled; do not reopen it.
4. As needed: `HUD_SKIN.md` (the UI look), `GATES.md`, `ART_PLACEHOLDERS.md` (every stand-in art piece, by name), `CONTENT_NEEDED.md`.

When code and docs disagree, trust the code and fix the doc in the same PR.

---

## 2. How we work (team rules, not suggestions)

### Planning
- **Before building a level or a large feature, plan it and ask the questions only a person can answer.** Do this once, up front. Then build from the decisions without re-asking.
- **Split the work into small PRs that each ship green**, in a written order. Build the riskiest technical piece first, and the heart of the level before the polish.
- **Add every new behaviour as a `LevelBase` hook that defaults to off**, so Levels 1–4 are untouched until a level opts in. Levels extend `level_base.gd` **by path** (`extends "res://scripts/level_base.gd"`), not by class name.

### Git
- **Work on a branch per PR, off `main`.** Never commit to `main` directly.
- **Commit messages explain *why*, not just what.** The first line is short and plain; the body gives the reason.
- **This repo's own style, not Conventional Commits.** Subjects are plain-English sentences with no `feat:` or `fix:` prefix (e.g. "A pickup shows its name as she nears it"), and branch names are short kebab-case with no `feat/` or `fix/` prefix (e.g. `dilim-fix-2`, `mayon-polish`). This holds even where a personal or global instruction asks for Conventional Commits.
- **Open the PR and merge it once its suites pass.** Afterwards, `git pull --ff-only` on main, run the import, and delete the branch (local and remote).

### Testing
- **First, in a fresh checkout or after art changes:** `godot --headless --path game --import`. Without it, no `class_name` resolves.
- **Run only the suites your change touches:** `tools/run_suites.sh only <suite> <suite> …`. Run the **full** suite (`tools/run_suites.sh`, 25–40 min) only when shipping, or when a change cuts across every level (an autoload, shared `LevelBase` plumbing).
- **Run one Godot process at a time per checkout.** Each test run keeps its data in its own `user://test_runs/<pid>/` folder, but runs in one checkout still share its `.godot` import cache.
- **A green suite is not a silent one.** Grep the output for `SCRIPT ERROR`, `Parse Error`, `^ERROR` and `Error calling`.
- **Mutation-test every new check.** Break the line the check guards, run the probe, confirm that the check fails, then restore the line. A check that cannot fail is not a check, so do this for every assertion you add.
- **Probe conventions:**
  - Add a `CHECKS` constant and a `checked` counter, so a crash cannot print OK.
  - Set `BackendSupervisor.auto_start_backend = false`.
  - Call `DialogueBox.set_auto_dismiss(true)`. Note that it hides pause bugs, so turn it off when chasing one.
  - Poll for a condition with a timeout instead of fixed sleeps.
  - Autoload names do not compile in `--script` runs; look them up from `root`.
  - GDScript lambdas capture locals **by value**. Use a member variable for anything a signal has to set.
- **Look at anything visual.** Headless draws nothing. Capture a window and look at the image:
  `godot -t --path game --resolution 1600x900 --script res://tests/_tmp_<name>.gd`.
  Throwaway capture scripts are named `tests/_tmp_*.gd` and deleted before the PR. On a Retina Mac the frames come back at about 2.1×; resize with NEAREST for pixel art.

---

## 3. What the game looks and reads like

- **Pixel-art idiom.** Positions are whole pixels. Motion goes through the `Motion` helpers (stepped at 15 fps, alpha in eighths). **Reduce motion** is respected: check `Motion.reduced()`.
- **All UI is soft-cornered**, built from `UISkin` styleboxes (`UISkin.frame()`, `UISkin.chip()`, and so on) and `UISkin` colours. No raw hex colours in UI code.
- **Readable text is never under 20 px** (`UISkin.FONT_CAPTION`). Text drawn in a `Node2D` uses `ThemeDB.get_project_theme().default_font` (Geist Pixel), not `ThemeDB.fallback_font`.
- **The game is never shown below 1600×900.**
- **Tutorials follow these rules:**
  - The picture comes first (`LessonVisual`); the caption is 8 words or fewer and comes second.
  - One card at a time; the screen dims and the lesson's subject is lit.
  - **Never** draw a picture of one of the 50 classes in a lesson. A ladder, a square or stairs in a picture is a hint the level did not mean to give.
- **No dialogue or objective line names a drawable class**, in English or Filipino (*tulay, hagdan, pinto, puno* …). Audits enforce this.
- **Gates are tags, not classes.** Every gate must resolve to at least 2 classes with held-out recall ≥ 0.70 after exclusions (BR-7, using `model/metrics.json`).
- **`modulate` multiplies, so it can never make anything lighter.** To add light, draw a lit layer on top or use a shader.
- **Comments say why:** the bug a line prevents, and the design reason behind it. Mark traps with ⚠. Match the density of the surrounding code.

---

## 4. Level 5 — Mayon

**Status: built and shipped (PRs #120–#133). The run ends on it.** `LEVEL_5.md` is the full design and as-built record. This section is the working summary.

### The level in brief
- Mayon is the last painting coming apart. **No combat, no health.** The ash is weather; the antagonist is the clock and the ink.
- **The ink is finite, with no refills anywhere:** 6 units, and every drawing costs 1.
- **Act One, the ascent.**
  - Two gates: SPAN, then CLIMB. Both are tag routes.
  - What the ash settles on goes white, then blank.
- **Act Two, the heart.**
  - Twelve fragments in three four-memory areas go white, and there is ink to save about four.
  - To save one, she draws something that belongs in it (1 ink). A drawing that doesn't belong is handed back free.
  - Three fragments hold Lolo, and saving one steadies him. One holds the 5th flower.
- **Lolo goes.** Near the top she tries to draw him and the brush refuses. He vanishes mid-sentence, in one frame.
- **Act Three, the summit.**
  - Lola paints with her back turned, and the brush refuses twice.
  - She draws the places instead: one drawing, no recognition, no ink, so the climax cannot fail. The saved fragments bloom, and Lola turns.
  - Five flowers means the perfect ending; fewer means the standard one.
- **The frame returns.** The real room appears, the apo tells Lola the stories she saved, and then she picks up an ordinary brush. Cut to black, then the house.

### Decisions (made by the team; do not reopen)
| Topic | Decision |
|---|---|
| Ending | **The summit is the ending.** Endings A–D are still computed (`EndingResolver`) and logged to telemetry; they are never shown. |
| Combat | **None.** |
| Lola, the room, Lolo's fading | Dedicated generated performances and room in the delivered art's idiom, with originals, prompts, and replacement contracts listed in `ART_PLACEHOLDERS.md`. Lolo's fading is a shader over his existing sheet. |
| Drawing the places | **One drawing blooms them.** |
| Running out of ink | **A hidden reserve of 2 units.** Only the two gates may use it, and only when the gauge can't pay. Fragments and transformations never touch it. |
| Saves | **Silent**: no lantern, letterbox, line or counter. |
| Her drawings | The ash never takes what she draws. |
| Tally | Saving the flower fragment is the only fork: it counts **artist**. The summit monologue is voiced by `PlayerProfile.dominant_route()`. |

### Where it lives
| Area | Files |
|---|---|
| Level | `game/level_5.tscn` · `game/scripts/level_5.gd` · `game/levels/level_5/level_5_environment.tscn` |
| Data | `game/config/level_05.json` · `game/config/dialogue_l5.json` |
| Ash | `shaders/drain.gdshader` · `Drainable` · `AshFall2D` · `ScreenTremor` |
| Fragments | `MemoryFragment2D` (`set_targeted` draws the gold rim on the fragment a drawing would go into) · `tools/build_mayon_fragments.py` |
| Lolo | `Lolo.set_thinness` / `vanish` · `shaders/lolo_fade.gdshader` |
| Summit and frame | `Lola2D` · `FrameReturn` · `tools/build_mayon_lola.py` |
| Refusal | `DrawPanel.set_refusing` / `quietly_refused` · LevelBase `_brush_refuses_here` / `_brush_refused` |
| Art | `tools/build_mayon.py` (originals in `LEVEL5_Mayon/`, cuts to `game/assets/Level5/`) · `MayonBackdrop2D` · `MayonTerrain2D` |

**Hooks `level_5.gd` turns on:**
- `_every_drawing_costs_ink`
- `_morph_has_a_life` (false, so a creature form drains ink)
- `_may_use_hidden_ink`
- `_saves_silently`
- `_ink_always_visible`
- `_camera_follows_height`
- `_ends_with_its_own_scene` / `_play_own_ending`
- `_brush_refuses_here` / `_brush_refused`
- `_on_ink_emptied`

**Tests:**
- Level probes: `run_level5_audit` · `run_level5_act_one_probe` · `run_level5_act_two_probe` · `run_level5_summit_probe` · `run_level5_frame_probe` · `run_level5_enablers_probe`
- Shared pieces: `run_brush_refusal_probe` · `run_drain_probe` · `run_mayon_probe`
- Art checks: `test_build_mayon(_fragments)` (Python)
- The whole run: `run_journey_probe` (Dilim → Mayon → the frame → home); `run_level5_finish_walk` continuously walks Mayon through the room, with normal recognition fixtures and actual quiet/free canvas input.

**Play it directly:** `godot --path game res://level_5.tscn`

### Mayon traps (each one cost time)
- **`_camera_follows_height` alone does not free the camera.** It is read only when a room is framed. A level with no rooms frees it in `_build_level_furniture` (`world_camera.set_vertical_free(true)`, then `snap_to_target()`).
- **`DrawPanel` processes only while the tree is paused.** Any tween it owns must use `Tween.TWEEN_PAUSE_PROCESS`, or it hangs the moment something unpauses.
- **A fragment's reach is a straight-line distance**, so the flower on its ledge cannot be saved from the path beneath it. A jump from the path peaks inside that reach, so the flower also `needs_footing`.
- **The summit waits for Lolo to be gone.** Otherwise the brush raised at Lola is taken by his moment. His portrait must disappear with his world sprite, leaving the interrupted line onscreen.
- **A checkpoint restore clears the old camera room.** A landing before the memories must not leave the camera framing their departed cluster.
- **The refusals must not reuse any decline feedback**, and both must look identical.
- **The `Painting_Covers` file names lie.** "Mt Makiling Completed Look" is Dagat's storm, and Dilim's forest is "Completed Look from Mayon".
- **`Array(arr)` returns the same array, not a copy.** Use `.duplicate()` for anything saved.
- **A hole in a darkness layer, high up, shows the backdrop's daytime sky.** Keep light holes low and tight.
- **The delivered art is painted with checkerboards**: never key it with a threshold. Use the `checker_key` / `without_fringe` helpers from `tools/build_dilim.py`.

### Still open on Mayon
- The landscape now uses broad generated cliffs and a continuous registered vista; inspect the actual scene after art changes.
- The optional light gate is intentionally omitted to preserve the memory ink budget.
- Generated Mayon performances and room need human art-direction review; originals and prompts are retained in `LEVEL5_Mayon/authored/`.
- Generated landscape/prop art and procedural memory targets remain provisional; summit scenery reuses existing transparent art. Mayon is silent (its synthesized audio was removed; its sound ids remain as hooks with no file), and Lola has no recorded voice (see the authored README).

---

## 5. Commands

| What | Command |
|---|---|
| Play | `./play.sh` (macOS/Linux) · `play_mac.command` · `play_windows.bat` |
| Import | `godot --headless --path game --import` |
| Some suites | `tools/run_suites.sh only run_level5_audit run_drain_probe` |
| Every suite except `run_tests` | `tools/run_suites.sh quick` |
| Everything | `tools/run_suites.sh` |
| One probe | `godot --headless --path game --script res://tests/<probe>.gd` |
| Live progress bar for a background run | `python3 tools/suite_watch.py <log>` (run with `OBRA_SUITE_LOG=<log>`) |
| Physics regression (more than 10 min) | `godot --headless --path game --script res://tests/run_tests.gd` |
| Python tests | `.venv/bin/python -m unittest -v tests.test_manifest_contract` |
| Art checks | `.venv/bin/python tools/build_mayon.py --check` (some `build_*.py --check` scripts rewrite files; snapshot `git status` first) |
