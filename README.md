# O.B.R.A.

O.B.R.A. is a 2D thesis game prototype where a player draws a sketch, a trained
classifier recognizes it, and Godot spawns a controllable entity using the player's
drawing as the body texture.

## Architecture

- `game/config/entities.json` is the source of truth for the roster, scene paths,
  and optional runtime rig metadata.
- `model/` downloads Quick Draw data, trains a small CNN, exports ONNX, and writes
  `labels.json`, `model_metadata.json`, `metrics.json`, and `confusion_matrix.png`.
- `backend/` serves `POST /predict` with FastAPI + ONNX Runtime.
- `game/` is a Godot 4 project with manifest-backed entity spawning and
  class-guided procedural animation profiles in `game/config/rigs/`.

## Python Setup

This Mac currently has `python3` as Python 3.14, which may be too new for
`onnxruntime` and PyTorch wheels. Prefer Python 3.11 or 3.12 for the project venv.
Inside this Codex workspace, the bundled Python 3.12 is:

```bash
/Users/hyuuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3
```

Backend/runtime setup:

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r backend/requirements.txt
```

If local Python 3.14 cannot install runtime wheels, create the venv with Python 3.12
instead:

```bash
/Users/hyuuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 -m venv .venv
. .venv/bin/activate
pip install -r backend/requirements.txt
```

## Data, Training, and Serving

Download the enabled Quick Draw categories from the manifest:

```bash
python3 model/download_data.py
```

Train in Google Colab or a local Python 3.11/3.12 environment:

```bash
pip install -r model/requirements.txt
python3 model/train_quickdraw.py
```

Run the backend after `model/model.onnx` and `model/labels.json` exist:

```bash
cd backend
uvicorn main:app --reload --port 8000
```

The prediction response includes `entity`, `display_name`, `source_label`,
`confidence`, `margin`, `runner_up`, `probabilities`, `rig_profile`,
`rig_type`, and the legacy `creature` alias.

## Runtime Rigging

Phase 2 keeps animation local to Godot. The backend still classifies the drawing;
the game hands the drawn stroke polylines to the spawned entity, which resolves a
skeleton from the actual ink: the most connected stroke cluster becomes the body and
each stroke touching it becomes a limb pivoting where it meets the body (strokes
drawn across the body split into two limbs at the crossing). Movement drives all
animation — spiders and humanoids step with distance traveled, birds beat their
drawn wings on flap impulses and hold them while gliding, fish run a speed-scaled
traveling wave through their stroke vertices, frogs crouch/extend on hop events —
and every limb eases back to its drawn rest pose when movement stops.

## Cross-Dataset Evaluation

Use `model/evaluate_folder.py` with folders named after the external dataset labels.
For TU-Berlin, `bird` folds `flying bird` and `standing bird` into the O.B.R.A.
`bird` entity. `humanoid` is trained from Quick Draw `yoga` and is intentionally
excluded from TU-Berlin headline scoring because TU-Berlin has no exact `yoga` label.
