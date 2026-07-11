# O.B.R.A. Agent Notes

O.B.R.A. is a Godot 4 thesis game prototype: the player draws a sketch, a
FastAPI/ONNX backend classifies the raster image, and Godot either morphs the
player or creates a placeable utility from the player's actual stroke vectors.

## Code Discovery and Reading

- Use `codebase-memory-mcp` as the default for code discovery and reading to
  conserve context: locate symbols with `search_graph`, inspect their source
  with `get_code_snippet`, and trace relationships with `trace_path`.
- Read files directly only when graph output is insufficient or for non-code
  artifacts such as configuration, scenes, manifests, and documentation.

## Project Map

- `game/`: Godot client. Startup scene is `game/ui/main_menu.tscn`, Level 1
  gameplay is `game/game_level.tscn`, and project config is `game/project.godot`.
- `backend/`: FastAPI inference server. `POST /predict` receives base64 image data
  and returns the recognized manifest entity plus confidence/margin metadata.
- `model/`: Quick Draw download, training, ONNX export, labels, metrics, and
  cross-dataset evaluation scripts.
- `shared/`: Python manifest loading/validation shared by backend and model tools.

## Stable Contracts

- `game/config/entities.json` is the source of truth for enabled entities, scene
  paths, Quick Draw labels, rig profiles, and model output order. After changing
  enabled entities or their `quickdraw_label`s, retrain/export the model so
  `model/labels.json` matches the manifest exactly.
- The backend classifies only. Runtime animation belongs in Godot and should use
  the raw stroke data passed through `drawing_canvas.gd` -> `draw_panel.gd` ->
  `game_level.gd` -> `apply_drawing(drawing, strokes)`.
- Spawnable scenes should support `configure_entity(entry)` and
  `apply_drawing(drawing, strokes)`. Playable creatures inherit
  `game/scripts/playable_entity.gd`; simple physics morphs use
  `game/scripts/physics_shape_object.gd`; utilities use `utility_object.gd`.
- Manifest `runtime_role` is authoritative: living forms are active-ragdoll
  morphs, basic shapes are physics morphs, and six utility classes are placed or
  stored without replacing the current player.
- `RuntimeRig2D` builds bounded rigidbody/joint graphs from drawn strokes. Preserve
  that no-template-limb pipeline and tune motors/contacts through rig profiles.

## Gameplay Shape

- Flow: a successful morph replaces the active player; a utility enters placement
  and then lives under `WorldItemRoot` or in the six-slot inventory.
- Controls are defined in `game/project.godot`: WASD/arrows for movement, Space
  for jump/flap/hop, R for redraw, 1–6 for inventory, E to interact, and F to use.
- Ink is level-scoped: twelve normalized canvas diagonals, transactionally reserved
  while drawing and committed only by a successful morph or stored/placed utility.
- The environment is asset-light on purpose. Keep `GameplayPlane`, `EntityRoot`,
  `SpawnPoint`, camera, floor, and walls intact when replacing placeholder art.

## Common Commands

- Backend setup: `python3 -m venv .venv && . .venv/bin/activate && pip install -r backend/requirements.txt`
- Serve backend: `cd backend && uvicorn main:app --reload --port 8000`
- Download enabled Quick Draw data: `python3 model/download_data.py`
- Train/export model: `python3 model/train_quickdraw.py`
- Cross-dataset eval: `python3 model/evaluate_folder.py --dir <dataset-root>`
- Contracts: `python3 -m unittest -v tests.test_manifest_contract`
- Godot physics: `godot --headless --path game --script res://tests/run_tests.gd`

## Finding the Actual Godot Game Window on macOS

- For Computer Use or screenshot QA, do **not** launch with `godot --path game`.
  That CLI process may render the game but does not reliably register a macOS
  application target, causing Computer Use to find or launch the Godot Project
  Manager instead.
- From the repository root, launch through LaunchServices so the debug game is
  discoverable:
  `open -n -a /Applications/Godot.app --args --path "$(git rev-parse --show-toplevel)/game"`
- Only request Computer Use state after that command succeeds, targeting bundle
  id `org.godotengine.godot`. The correct window title is `O.B.R.A. (DEBUG)`.
- If Computer Use reports `Godot Engine - Project Manager`, stop immediately:
  do not share that screenshot and do not waste time cycling windows. Refresh
  its state, close the Project Manager with Cmd+Q, rerun the LaunchServices
  command above, then query `org.godotengine.godot` again.
- After visual QA, close the debug preview with Cmd+Q so a stale Godot window
  cannot be mistaken for the next run.

## Working Notes

- Prefer Python 3.11 or 3.12 for ONNX Runtime/PyTorch compatibility; local Python
  3.14 may be too new for wheels.
- `model/data/`, `.venv/`, `.godot/`, and thesis working docs are intentionally
  ignored. Do not commit re-downloadable datasets or local runtime caches.
- Keep this file compact. Update it only when the architecture, core flow,
  commands, or stable contracts change.
