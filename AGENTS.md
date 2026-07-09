# O.B.R.A. Agent Notes

O.B.R.A. is a Godot 4 thesis game prototype: the player draws a sketch, a
FastAPI/ONNX backend classifies the raster image, and Godot spawns a controllable
entity skinned and animated from the player's actual stroke vectors.

## Project Map

- `game/`: Godot client. Main scene is `game/game_level.tscn`; project config is
  `game/project.godot`.
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
  `game/scripts/playable_entity.gd`; simple physics objects use
  `game/scripts/physics_shape_object.gd`.
- `RuntimeRig2D` builds rigs from the drawn strokes. Prefer preserving that
  heuristic pipeline over adding template limbs or backend-generated animation.
- `game/config/rigs/*.json` tunes target size, alignment, and motion parameters;
  use those files for per-entity feel before hardcoding behavior.

## Gameplay Shape

- Flow: open draw panel, sketch, click Transform, backend predicts, Godot spawns
  or replaces the active entity under `EnvironmentBaseplate/GameplayPlane/EntityRoot`.
- Controls are defined in `game/project.godot`: WASD/arrows for movement, Space
  for jump/flap/hop, and R for redraw.
- Creature movement controllers are intentionally small and state-driven. They
  feed motion state into `set_rig_state`; the rig advances from actual movement
  speed and eases back to the drawn rest pose when idle.
- The environment is asset-light on purpose. Keep `GameplayPlane`, `EntityRoot`,
  `SpawnPoint`, camera, floor, and walls intact when replacing placeholder art.

## Common Commands

- Backend setup: `python3 -m venv .venv && . .venv/bin/activate && pip install -r backend/requirements.txt`
- Serve backend: `cd backend && uvicorn main:app --reload --port 8000`
- Download enabled Quick Draw data: `python3 model/download_data.py`
- Train/export model: `python3 model/train_quickdraw.py`
- Cross-dataset eval: `python3 model/evaluate_folder.py --dir <dataset-root>`

## Working Notes

- Prefer Python 3.11 or 3.12 for ONNX Runtime/PyTorch compatibility; local Python
  3.14 may be too new for wheels.
- `model/data/`, `.venv/`, `.godot/`, and thesis working docs are intentionally
  ignored. Do not commit re-downloadable datasets or local runtime caches.
- Keep this file compact. Update it only when the architecture, core flow,
  commands, or stable contracts change.
