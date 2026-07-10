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

The enabled roster currently trains nineteen classes: `fish`, `frog`, `spider`,
`bird`, `humanoid` from Quick Draw `yoga`, `cat`, `dog`, `rabbit`, `butterfly`,
`snake`, plus the physics objects `circle`, `square`, `triangle`, `axe`,
`ladder`, `key`, `umbrella`, `flashlight`, and `sailboat`.
Whenever this list changes, retrain before starting the backend; stale
`model.onnx`/`labels.json` files will fail manifest validation by design.

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
`rig_type`, `runtime_role`, `utility_behavior`, `required_medium`, and the
legacy `creature` alias.

## Runtime Physics, Utilities, and Ink

The backend only classifies. Godot turns submitted stroke vectors into bounded
physics graphs: a dynamic body cluster plus capsule/polygon limb bodies joined by
motorized, angular-limited `PinJoint2D`s. Visible vector sections are children of
their owning bodies, so rendered ink and collision always share a transform. Rigs
are capped at 24 bodies and 23 joints and fall back to one compound body when a
drawing does not contain an articulatable structure.

Animals and the humanoid are force-driven active ragdolls with species-specific
gaits. Circle, square, and triangle remain controllable physics morphs. Axe,
ladder, key, umbrella, flashlight, and sailboat are placeable utilities that keep
their exact image, strokes, and state through a six-slot inventory.

Each level starts with twelve canvas diagonals of ink. The canvas charges geometric
polyline length, clips the exact final segment at the limit, and reserves ink until
a morph succeeds or a utility is placed/stored. Clearing, cancellation, backend
failure, and low-confidence rejection refund the current reservation.

```bash
python -m unittest -v tests.test_manifest_contract
godot --headless --path game --script res://tests/run_tests.gd
godot --headless --path game --script res://tests/run_level_ready.gd
```

## Cross-Dataset Evaluation

Use `model/evaluate_folder.py` with folders named after the external dataset labels.
For TU-Berlin, `bird` folds `flying bird` and `standing bird` into the O.B.R.A.
`bird` entity. `humanoid` is trained from Quick Draw `yoga` and is intentionally
excluded from TU-Berlin headline scoring because TU-Berlin has no exact `yoga` label.
