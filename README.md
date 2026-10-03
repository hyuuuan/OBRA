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

## Getting it running: install two things, then just press Play

Install, once per computer:

1. **Godot 4.7** (the standard build, not .NET). It has to be 4.7: the project is saved by
   4.7, and an older Godot cannot run it.
2. **Python 3.10 or newer**. On Windows, from python.org, with **"Add python.exe to PATH"**
   ticked; the Microsoft Store's `python3` is not Python. On a Mac, `brew install python` or
   python.org.

Then clone or pull, open `game/` in Godot and press Play (or run `godot --path game`). **Nothing
else is needed; the game sets the rest up itself:**

- **Godot's import cache.** If it is missing or out of date, the game imports and starts
  again by itself (`ImportGuard`). The game opens on `ui/boot.tscn`, a scene that loads with
  nothing imported, so this works on a fresh clone too.
- **The drawing recogniser.** It is started with the title screen. On a computer that has
  never run the game, it finds Python, makes `.venv`, installs the packages and then starts
  (`backend/serve.py`). That first time takes a few minutes and needs the internet; a note
  at the top of the screen says what it is doing. After that it is quick, and it updates
  itself when `backend/requirements.txt` changes. A drawing sent while it is still getting
  ready waits and goes through by itself.

The launchers below still work and do the same steps before the game opens, so the waiting
happens in their window rather than in the game.

## On Windows

1. Install **Godot 4.7** for Windows (the standard build, not .NET). It has to be 4.7: the
   project is saved by 4.7, and an older Godot cannot run it.
2. Install **Python 3.10 or newer** from python.org, and tick **"Add python.exe to PATH"** in
   the installer. The `python3` that Windows offers from the Microsoft Store is not Python;
   it opens the Store.
3. After cloning, and **after every `git pull`**, double-click **`play_windows.bat`** in the
   repository root. It makes `.venv` and installs the recogniser's packages when they are
   missing or have changed, brings Godot's import up to date, and starts the game. It
   looks for Godot on PATH and in Downloads, Desktop and Documents; if it cannot find it,
   drag `Godot_v4.7-stable_win64.exe` onto `play_windows.bat` once -- it remembers.

Running from the Godot editor works too, with or without `play_windows.bat` first: the game
sets up `.venv` itself if it is not there.

If it still will not start, send Godot's log:
`%APPDATA%\Godot\app_userdata\O.B.R.A\logs\godot.log`.

## On macOS and Linux

The same steps, as **`./play.sh`** (on a Mac, double-clicking **`play_mac.command`** runs it in
Terminal). Run it after cloning and after every `git pull`. It needs Python 3.10 or newer
(`brew install python`, or python.org). It finds Godot on PATH or in `/Applications`; if not,
run `./play.sh /path/to/Godot` once and it remembers.

## The drawing recogniser

The game starts it (`backend/serve.py`, with `.venv`'s Python) **when the title screen
opens**, so it is ready by the time anyone draws. Both launchers also load it once before the
game opens: its first start on a computer is the slow one (on Windows, Defender reads every
file numpy and onnxruntime are made of), and the launcher's window is the place for that wait.

If a drawing is sent while the recogniser is still starting, the panel says it is waking up,
and the drawing goes through by itself once it answers; there is no need to press Transform
again. If the recogniser cannot start at all, the game says why: no Python, missing packages
or the model missing. It also writes everything to `backend.log` in the game's user folder
(`%APPDATA%\Godot\app_userdata\O.B.R.A\` on Windows, `~/Library/Application Support/Godot/app_userdata/O.B.R.A/`
on a Mac). Port 8000 is used unless something else holds it, and then 8765-8774. On Windows
some machines reserve 8000 for Hyper-V or WSL. The recogniser exits when the game does, on
every platform, even after a crash.

To check it by hand: `.venv/bin/python backend/serve.py --check` (Windows:
`.venv\Scripts\python.exe backend\serve.py --check`) loads everything and says
`OBRA_BACKEND_READY`, or one `OBRA_BACKEND_FAILED:` line saying why not.

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
`confidence`, `margin`, `runner_up`, `probabilities`, `timing`
(decode/preprocess/infer/total ms), `rig_profile`, `rig_type`, `runtime_role`,
`utility_behavior`, `required_medium`, and the legacy `creature` alias.

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

## Running it the first time, and after a fetch that brings new art

**Import once before you run the game.**

```bash
godot --headless --path game --import
```

`game/.godot/` is generated and gitignored, so a fresh clone has none — and neither does
anyone who has just pulled a commit that changed the assets. Everything Godot needs at
startup lives in there: the imported textures, the imported font, and
`global_script_class_cache.cfg`, which is the file that makes every `class_name` in this
project resolvable.

**If you skip it, the symptom does not look like a missing cache.** Without the class
cache no script that names a `class_name` type can parse, so none of their `_ready()`
methods run — and the game comes up with a full-screen dialog reading **ARE YOU SURE?**
that nothing dismisses, because the script that would close it is one of the scripts that
did not load. The fix is the command above; then run the game again.

Opening the project in the Godot editor once does the same job, with a progress bar.

**And the game now does it for you if you forget.** `ImportGuard` (`game/scripts/import_guard.gd`,
the first autoload) checks at launch whether this machine's cache matches the checkout: every
imported file present, every source still the one that was imported, every `class_name` in
the class table. If not, the window says "Getting O.B.R.A. ready for this computer", runs the
import above, and starts the game again by itself, once per update. It never runs during a
test suite (`--script`) or in an exported build. The command above is still the quickest way,
and `play_windows.bat` still runs it before every launch.

```bash
python -m unittest -v tests.test_manifest_contract
python -m unittest -v tests.test_backend_telemetry
python -m unittest -v tests.test_preprocess_paper
python -m unittest -v tests.test_backend_lifecycle
godot --headless --path game --script res://tests/run_tests.gd
godot --headless --path game --script res://tests/run_level_ready.gd
godot --headless --path game --script res://tests/test_player_profile.gd
```

## Telemetry and Player Profile

Progression persists in a single JSON player profile at `user://profile.json`
(atomic temp-then-rename write, schema-versioned, no database). Anonymous, local
gameplay telemetry is written per session to `user://telemetry/session_<UTC>.jsonl`.
On macOS `user://` resolves to
`~/Library/Application Support/Godot/app_userdata/O.B.R.A/`.

Test runs (anything started with `--script`) never touch either: they keep their own profile
and telemetry under `user://test_runs/`, emptied at the start of each run, so running the
suites neither changes a player's save nor adds bot sessions to the telemetry.

A backend the game starts exits when the game does, however the game ends. One started by
hand keeps running and is reused by the game as long as it answers on port 8000, so restart
it after changing anything in `backend/`.

The backend additionally logs one anonymous record per prediction when enabled:

```bash
OBRA_TELEMETRY=1 uvicorn main:app --port 8000          # writes telemetry/backend_<date>.jsonl
OBRA_TELEMETRY_DIR=/path OBRA_TELEMETRY=1 uvicorn ...  # optional directory override
```

`/predict` also returns a `timing` breakdown so end-to-end latency can be decomposed
across the game and the backend. Summarize the logs (redraw rate, latency, per-class
precision/recall, confusion matrix) with:

```bash
python3 tools/aggregate_telemetry.py <telemetry-dir-or-file>
```

## Cross-Dataset Evaluation

Use `model/evaluate_folder.py` with folders named after the external dataset labels.
For TU-Berlin, `bird` folds `flying bird` and `standing bird` into the O.B.R.A.
`bird` entity. `humanoid` is trained from Quick Draw `yoga` and is intentionally
excluded from TU-Berlin headline scoring because TU-Berlin has no exact `yoga` label.
