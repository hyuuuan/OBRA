# O.B.R.A. agent instructions

O.B.R.A. is a Godot 4 thesis game. The FastAPI/ONNX backend classifies drawings.
Godot uses the original stroke vectors to animate a morph or create a utility.

## Tool use

- **Codebase Memory owns source discovery and reading.** Use `search_graph` to
  find symbols, `get_code_snippet` to read them, and `trace_path` when you need
  callers or callees. A graph hit requires a snippet lookup before opening its
  source file. Keep result limits small. If `file_pattern` comes back empty,
  retry by symbol name or `qn_pattern`.
- **Context Mode owns verbose output.** Use `ctx_batch` for commands whose
  output you expect to query, such as audits, build logs, or large diffs. Use
  `ctx_execute` for computed summaries and `ctx_search` to retrieve relevant
  indexed passages without rerunning the command. For test commands, capture
  the test process's exit status explicitly along with the relevant diagnostics.
- For code the graph cannot supply, identify the gap first (missing symbol,
  incomplete snippet, or newer worktree source) and read only the necessary
  lines. Use direct searches for literal strings and direct reads for small
  scenes, configs, and docs. Apply the same output limits to tool calls you
  batch together. Context Mode is for filtering output, never a bypass for
  graph-first source lookup.
- Run edits and small checks through the normal tools. For long-running jobs
  that need normal process control, or when Context Mode is unavailable,
  capture verbose output in a temporary log, retain the exit status, and read
  only the summary and relevant failures. Use `ctx_index` and `ctx_search` on
  that log when helpful.

## Project map and contracts

- `game/` is the client. Its startup scene is `game/ui/main_menu.tscn`, Level 1
  uses `game/game_level.tscn`, and input bindings live in `game/project.godot`.
  `backend/` serves `POST /predict`. `model/` trains and exports ONNX, and
  `shared/` validates the manifest.
- `game/config/entities.json` defines enabled entities, Quick Draw labels, model
  output order, runtime roles, rig profiles, and scene paths. If enabled
  entities or their labels change, retrain and export so `model/labels.json`
  exactly matches the manifest.
- Pass original strokes from `drawing_canvas.gd` through `draw_panel.gd` and the
  level host to `apply_drawing(drawing, strokes)`. Spawnable scenes also support
  `configure_entity(entry)`. Living entities use `playable_entity.gd`, basic
  shapes use `physics_shape_object.gd`, and utilities use `utility_object.gd`
  without replacing the player.
- Keep `RuntimeRig2D` driven by drawn strokes and rig profiles. Every rendered
  polyline must be an exact contiguous slice of a player stroke. The post-build
  audit demotes divergent rigs to an intact compound body. Preserve
  `_test_ink_integrity` in `game/tests/run_tests.gd`. To move part of a drawing
  (a fan's blades), turn whole strokes by their `Line2D` transform
  (`RuntimeRig2D.turn_strokes`), never by rewriting their points.
- Obstacles declare ability tags. `AbilityTags` resolves classes and
  `tools/build_tags.py` generates `game/config/tags.json`. Run
  `python3 tools/audit_abilities.py --check` after changing a rig profile,
  behavior switch, or ability table. Use profile flags for capabilities.
- Preserve `PlayerProfile` as the durable profile owner and `UserData` as the
  storage path resolver. Test runners must use the isolated test profile and
  telemetry paths. In `--script` probes, resolve autoloads under `/root` after
  startup.

## Levels and UI

- Read [LEVEL_TEMPLATE.md](LEVEL_TEMPLATE.md) before designing or building
  Levels 2–5, including the gate rules, schemas, and required tests. Each
  level extends `"res://scripts/level_base.gd"` by path, supplies
  `level_config_path()` and `dialogue_path()`, and opts into behavior through
  hooks. Preserve the defaults other levels rely on.
- Read the matching level spec before changing its gameplay, data, dialogue,
  or art. Read [Level 1](LEVEL_1.md) before editing `tags.json` or Payyo's
  files. The other specs cover [Piyesta](LEVEL_2.md), [Dagat](LEVEL_3.md),
  [Dilim](LEVEL_4.md), and [Mayon](LEVEL_5.md). Read [DIARY.md](DIARY.md) before
  changing diary pages or `diary.json`.
- Payyo teaches the common controls. Later levels teach mechanics they change.
  The clue ladder opens after one, two, and three misses. Only the third clue
  names one class. Solved beats stop giving advice.
- Keep application copy to essential labels and actions. Add subtitles,
  taglines, example copy, or persistent footer/status copy only when requested.
  Show necessary validation or a brief confirmation beside the affected control.
  Use the shared `UISkin` and `UIFeedback`. See [HUD_SKIN.md](HUD_SKIN.md) and
  the UI Contracts section of the implementation notes when changing the UI.

## Audio

- Music and sound are FamiTracker text modules (2A03 + VRC7) in `audio/`, rendered by
  `tools/build_music.py` into WAVs with their loop in a `smpl` chunk. Read
  [audio/README.md](audio/README.md) before writing or changing one. Change the module and
  re-render; never edit a WAV. `build_music.py --check` fails a stale render.
- Author an id in `game/config/audio.json` with the code that plays it before its module.
  The builder refuses a module for an unknown id, and `run_audio_probe` fails a file nothing
  plays, a music file that does not loop seamlessly in Godot, and a sound effect that loops.
- Every sound cue has a visual equivalent (Dilim's rule). Mayon stays silent, which
  `run_level5_audit` asserts.
- Rendering compiles and runs `tools/vendor/emu2413`, so `build_music.py` runs only inside
  the macOS sandbox `tools/famirender.sb`. Do not edit the vendored files; their hashes are
  pinned, and their README says how to update them.

## Verification

- Run the smallest relevant audit or probe first. Exercise actual player input
  for input changes and verify the probe's setup before interpreting a failure.
  Run Godot suites separately from model training. `run_level1_audit.gd` is
  timing-sensitive under CPU load.
- Import changed Godot assets with `godot --headless --path game --import`
  before screenshot or visual probes. On macOS, launch the actual game window
  through LaunchServices using the command in the window QA notes.
- Consult [implementation notes](docs/IMPLEMENTATION_NOTES.md) by section for
  level history, gameplay and persistence, UI contracts, known traps, commands,
  and [macOS window QA](docs/IMPLEMENTATION_NOTES.md#finding-the-actual-godot-game-window-on-macos).
  `tools/run_suites.sh` lists the Godot suites.

## Working rules

- While implementation is unfinished, compact at a safe checkpoint when
  available. Preserve the working tree and jobs and record the objective,
  constraints, edits, remaining work, and test results before resuming. Stay in
  the current context for verification unless a finding requires more edits.
- If a usage limit blocks substantive work and an eligible earned reset is
  available, ask for explicit confirmation for each redemption. Verification,
  tests, probes, and waiting alone do not require a reset.
- Commit the task's changes and push to `origin/main`. Prefer Python 3.11 or
  3.12 for ONNX Runtime and PyTorch. Keep re-downloadable datasets, local runtime
  caches, and ignored thesis working docs out of commits.
