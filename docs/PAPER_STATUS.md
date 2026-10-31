# O.B.R.A.: status for the paper

As of 2026-10-31, `main` at `d2fdd4b`. Every figure below was read from the repository or
re-run today. Where something could not be checked, this says so. The places where the
manuscript and the build disagree are listed separately in
[MANUSCRIPT_CONFLICTS.md](MANUSCRIPT_CONFLICTS.md).

## 1. Model

`model/metrics.json` exists. It was last regenerated in commit `0ca55f3` (2026-08-29),
when mushroom was replaced by bread, and it describes the shipped `model/model.onnx`.

- **Held-out Quick, Draw! test accuracy: 0.8658** (200,000 drawings, about 4,000 per
  class). Macro precision and recall are both 0.866.
- **Classes below 0.70 recall: frog (R 0.576, P 0.650) and bird (R 0.669, P 0.828).**
  The next lowest are monkey 0.720, bat 0.753 and crab 0.770. Per-class figures for all 50
  are in `metrics.json`.
- Largest confusions: shark→fish 5.6%, crab→spider 5.3%, fan→wheel 5.2%, cloud→bread 4.3%.
  `model/confusion_matrix.png` is the figure.
- **TU-Berlin (run 2026-10-31):** 3,280 sketches covering **40 of 50 classes** (80 per
  class; bird is "flying" plus "standing bird", 160). All three splits of the
  `sdiaeyu6n/tu-berlin` mirror were used. The uncovered ten are circle, square, triangle,
  bat, campfire, stairs, rake, clock, anvil and bucket.
  - **With the game's own preprocessing (the manuscript's protocol): accuracy 0.212.** This
    is an artefact. Shrinking 1111 px pen lines about 40× by averaging leaves them at 0.2–0.3
    of full ink, and a third of the set is called "bread".
  - **With stroke-preserving shrinking (block-max; fixed before its result was seen):
    accuracy 0.677, macro recall 0.681.** Strongest: boomerang 0.94, umbrella 0.93,
    penguin and ladder 0.91. Weakest: monkey 0.26, flashlight 0.41, scorpion 0.45,
    butterfly 0.48.
  - Results: `model/metrics_tu_berlin*.json`. Report both runs; the game's 8 px brush keeps
    0.5–1.0 strength, so the artefact is TU-Berlin's.

## 2. Training

Source: `model/train_quickdraw.py` and `model/model_metadata.json`.

- **Architecture (`SketchCNN`):** Conv 3×3 (1→32), ReLU, MaxPool → Conv 3×3 (32→64), ReLU,
  MaxPool → Conv 3×3 (64→128), ReLU → Flatten → Dropout 0.3 → FC 6272→128, ReLU → FC
  128→50. That is **902,066 parameters**, confirmed from the ONNX file itself.
- **Input:** 1×28×28 grayscale in [0,1], white ink on black.
- **Preprocessing** is one function shared by training, evaluation and serving
  (`canonicalize_ink`): crop to ink (threshold 32/255), scale the longest side to 26 px
  (bilinear), and centre on a 28×28 canvas. Serving and evaluation also convert to
  grayscale, invert if the mean is above 127, and zero everything below the ink threshold.
- **Data:** Quick, Draw! `numpy_bitmap`, capped at **40,000 per class**: 2,000,000
  drawings in total.
- **Split:** 80/10/10 (1.6M / 200k / 200k), shuffled with `numpy` seed 42. The shipped
  model seeded only the split. From the next retrain, `--seed` also seeds weights, shuffling
  and augmentation (`train-seed`).
- **Augmentation (training only):** RandomAffine (±12°, ±8% shift, scale 0.85–1.15),
  Gaussian blur (σ 0.4–1.4, p=0.8), and a down-then-up resample through 20/22/24 px (p=0.5),
  simulating the game's 512 px canvas.
- **Optimisation:** Adam, lr 1e-3, batch 256, cross-entropy, **8 epochs**, no scheduler;
  validation accuracy rose from 0.814 to 0.866. Trained on Apple silicon (`mps`).
- **Framework versions: not recorded for the shipped model.** The next retrain writes them
  into `model_metadata.json`; the requirements files are still unpinned.
- **ONNX export:** `dynamo=False`, **opset 18** (confirmed from the file), input `input`,
  output `logits`, dynamic batch axis.

## 3. Rejection gate

As implemented in `game/scripts/sketch_client.gd`, a prediction is accepted only if
**confidence ≥ 0.60 and margin (top-1 minus top-2 probability) ≥ 0.15**. Otherwise it is
declined as a redraw, which costs no ink. The backend only computes confidence and margin;
it rejects nothing itself.

These values match `AGENTS.md` and the manuscript's FR-3 and Eq. 4. Each level's
`recognition` block now sets them, and `SketchClient.passes_gate` is the only place the rule
is written (`gate-from-config`).

**Per-level threshold (§4.5.4.2), built 2026-10-31 (`brush-asks-more`):**
- Each level has its own confidence bar above the floor: Payyo 0.60, Piyesta 0.60, Dagat
  0.65, Dilim 0.70, Mayon 0.75.
- It applies only once the new brush from Dagat is in hand.
- After two declines in a row it eases by 0.05 per decline to the floor.
- A drawing only the bar refused is logged as a `brush` decline, with `floor_accepted`, so
  recognition is still reported at the floor.

## 4. Attribution

The table is `game/config/abilities.json`, built offline by `tools/build_abilities.py`. The
game and the backend only read it; nothing queries ConceptNet at runtime.

- **Relations used: CapableOf (20 creatures) and UsedFor (27 objects).** That is one ability
  per class, 50 in total.
- **Hand-authored: 3**, the primitives, because no commonsense relation describes a shape
  acting: circle → roll, square → weight, triangle → wedge.
- **The other 47 are all `conceptnet_curated`; none is `conceptnet_api`.** The builder tries
  the ConceptNet REST API and falls back to a hand-written table of documented assertions
  with approximate weights, and every shipped entry came from that fallback. **Their weights
  have not been checked against ConceptNet.** A rerun against a working API would fix this.
- **Gates use a separate tag layer** (`tags.json`): of 91 memberships, 17 reuse the class's
  ConceptNet verb and 74 are design groupings, so it isn't ConceptNet-derived.

The manuscript describes something quite different (conflicts B1–B5).

## 5. Architecture

- **Client:** Godot 4.7 runs drawing, stroke rigs, physics, levels, the profile and telemetry.
- **Recogniser:** a local Python process, FastAPI + ONNX Runtime on `127.0.0.1:8000`. The
  game starts it through `backend/serve.py` (which installs packages on first run), and it
  exits when the game does.
- **Path:** a base64 PNG goes to `POST /predict`, which returns the entity, confidence,
  margin, runner-up, probabilities, ability and `timing`. The client applies the gate, then
  morphs the player or places a utility built from the strokes. Requests are asynchronous;
  the world is paused while the drawing panel is open.
- **Latency instrumentation:** the backend returns `decode/preprocess/infer/total_ms`. The
  game logs `latency_ms` (from the Paint press to the response) and a `spawn` event (from the
  Paint press to the entity's first frame, which is the manuscript's Eq. 12), and
  `tools/aggregate_telemetry.py` summarises both. **No figures exist yet:** no telemetry from
  real play is in the repository. Frame rate, CPU, GPU and memory are not instrumented.

## 6. Built vs. not

**All five levels are built and offered from the hub:** Payyo, Piyesta, Dagat, Dilim and
Mayon, and Mayon ends the run. Each level's own probes are written to show it can be
finished, but today's whole-run probe fails at the house (§7).

**Placeholder** (per `ART_PLACEHOLDERS.md` and `CONTENT_NEEDED.md`):

- Payyo's props (drawn in code), and Piyesta's interiors and alleys.
- Six Dagat props, and most of Dilim's creatures (three are delivered).
- Lola, the real room, the fragments and the summit in Mayon.
- Most of the dialogue, written by developers.
- **There is no audio** (the ids exist; the file paths are empty).

**Still open:**

- Payyo's memory cutscene and Ability Book; `WardLock2D` is not wired in.
- Lolo's praying and laughing poses, and the apo's failed-draw pose.
- The dialogue shuffle bag and replay path nudges (proposed as future work in the appeal).
- The gameplay audits of Levels 1–4 (`GAME_AUDIT.md`).

## 7. Tests

**Coverage:**

- **Python (93 tests):** the manifest/label/model contract, preprocessing, backend
  telemetry, lifecycle and self-setup, and the art build scripts.
- **Godot (about 120 suites in `tools/run_suites.sh`):** the physics and rig regression
  (`run_tests`, including ink integrity), per-level audits (including the BR-7 recall floor,
  read from `metrics.json`), play and finish probes, economy, combat and UI, and
  `run_journey_probe` (the whole run).

**Run today (Windows 11, Godot 4.7.1):**

- **Python, run twice:** the first run had 2 backend-launch failures, which passed on the
  second run (environment, not code). `test_onnx_output_has_fifty_classes` needs `onnx`; with
  it installed, it passes.
- **Godot, passed:** the five level audits, `run_roster_sweep` (all 50 entities) and
  `run_behaviour_audit`. Level 5's two `ERROR` lines are engine shutdown leak warnings.
- **Godot, failed: `run_journey_probe`, 9 checks.** The probe gets through Payyo and Piyesta,
  then pressing E at Dagat's painting leaves it in the house, and every later level fails.
  The likely (unverified) cause is PR #138, merged today, which makes painting selection wait
  for the unlock reveal.
- **Not run:** the full suite and `run_tests`. `tools/run_suites.sh` needs zsh and macOS
  paths, so it can't run here. There is no CI.

**Known failures:** the journey probe above. No earlier full-suite result is stored anywhere.

## 8. Gaps a reviewer will ask about

1. **The TU-Berlin result depends on preprocessing** (0.21 against 0.68). The manuscript
   promises identical preprocessing, so the paper must explain the difference.
2. **No user study data:** no SUS, UEQ-S, IEQ-SF, GEQ, Godspeed or QUESI result, and no
   participant telemetry.
3. **No latency or frame-rate numbers** for the 250 ms / 500 ms / 55 fps targets; latency is
   instrumented, frame rate is not.
4. **Live-play recall is not measurable:** no code sets `intended_class`.
5. **Attribution weights are unverified** (all curated), and the manuscript's six-relation
   account doesn't describe the shipped table.
6. **No baselines or ablations:** no other architecture, and no number for the
   render-simulation augmentation or the gate thresholds (accuracy against coverage).
7. **No calibration analysis** (reliability diagram or ECE), though the gate relies on raw
   softmax confidence.
8. **Reproducibility:** the shipped model predates seeded training and recorded versions.
9. **Two classes below 0.70 recall** (frog, bird). The level audits show that no gate depends
   on either alone; the paper should say so.
