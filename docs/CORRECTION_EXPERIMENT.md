# Learning from a player's corrections: an offline experiment

2026-10-31. Code: `model/correction_experiment.py`. Raw results: `model/correction_experiment.json`.
Nothing in the game changed; this asks whether a change would be worth making.

> **Superseded for the game question by [PLAYER_SIMULATION.md](PLAYER_SIMULATION.md).** Played
> through the real confidence gate by simulated players of four skills, the memory measured here
> *lowers* first-try success at every skill: the offline gain does not survive the gate. The
> recommendation below to build it no longer stands. The offline measurements themselves do.

## The question

Can a handful of drawings the player has labelled, called **corrections**, improve recognition
for that player without retraining the network? And what does it cost on ordinary drawings?

## The answer, in short

- **Yes, a little, and safely, at the right setting.** With five corrections per class, a
  memory of the player's own drawings lifts accuracy on an unseen drawing style from **0.676
  to 0.699**. Accuracy on ordinary drawings stays where it was (0.868 against 0.870).
- **Pushed harder, it pays for its gains with forgetting.** The setting tuned only for the new
  style reaches 0.711, but ordinary drawings fall to 0.832. **Any per-player learning has to be
  tuned against a check of what it forgets**, and that is itself a finding.
- **A prototype memory survives wrong corrections; retraining the last layer does not.** With
  40% of corrections mislabelled, the memory loses 1.7 points, while retraining loses
  13.9.
- **Corrections cannot fix preprocessing.** Where the game's preprocessing erases the strokes
  (the 0.212 condition), corrections recover a great deal, up to 0.501. But they never reach
  what simply preserving the strokes gives (0.676), and they cost ordinary drawings heavily.

## Setup

**The model** is the shipped CNN, kept **frozen**, as the thesis requires (§3.2.10). Each
drawing's 128-number penultimate-layer embedding is read from the ONNX file itself.
Recomputing the final layer from that embedding reproduces the model's own logits, which the
script asserts on every batch.

**Three ways of reading a drawing:**

| Method | How it works |
|---|---|
| **Frozen** | The shipped model, unchanged. |
| **Prototype memory** | Each corrected class keeps the mean direction of its corrections' embeddings. The model's probabilities are blended with a softmax over a drawing's cosine similarity to those prototypes, by a weight λ. A class nobody corrected gets nothing from the memory. There is no training, it is reversible, and it costs milliseconds. |
| **Last-layer retrain** | Only the final 50×128 layer is retrained on the corrections (100 steps), with an L2 anchor pulling it back toward the shipped weights. |

**The stand-in player is TU-Berlin.** These are 3,280 sketches over the 40 covered classes,
drawn by other people under another protocol, and the model never saw them. It is a
*population* of drawers, not one person, so a gain here is adaptation to a drawing style,
which is what one player's corrections would carry. It is not a user study.

**The protocol was fixed before any result was seen:**

- **Splits.** Each class is split at random, per trial, into a **test** half that is only ever
  scored and a **pool** that corrections come from.
- **Corrections.** k corrections per class, with k = 0, 1, 3, 5 or 10.
- **Tuning.** Each method's settings were chosen **once**, as one setting for every k, on
  separate dev trials with their own seeds, scored on the pool left after the corrections. The
  test halves chose nothing.
- **Repetition.** 10 test trials. Figures are mean ± 95% interval.
- **Forgetting check.** 3,000 Quick, Draw! drawings: 200 each from the 15 roster classes on
  disk, taken from past index 40,000. Training read only the first 40,000 of each class, so
  the model has never seen these. The frozen model scores 0.870 on them.
- **Wrong corrections.** At k = 5, 0%, 20% or 40% of corrections carry a wrong label.

## Results: the realistic condition (TU-Berlin, strokes preserved)

Dev-chosen settings: memory λ = 0.7, T = 0.1; retrain anchor 0.1, learning rate 0.05.

| k | Frozen | Memory | Retrain | Ordinary: memory | Ordinary: retrain |
|---|---|---|---|---|---|
| 0 | 0.676 ± 0.003 | — | — | 0.870 | 0.870 |
| 1 | 0.676 | 0.671 ± 0.008 | 0.675 ± 0.007 | 0.798 ± 0.012 | 0.848 ± 0.011 |
| 3 | 0.676 | 0.702 ± 0.006 | 0.696 ± 0.007 | 0.829 ± 0.012 | 0.845 ± 0.011 |
| 5 | 0.676 | 0.711 ± 0.005 | 0.706 ± 0.005 | 0.832 ± 0.012 | 0.843 ± 0.012 |
| 10 | 0.676 | 0.714 ± 0.005 | 0.724 ± 0.004 | 0.838 ± 0.005 | 0.847 ± 0.007 |

One correction per class does not help. From three per class it does, by up to 4.8 points.
**At these settings, both methods cost ordinary drawings 2–7 points.**

### The trade-off (post hoc, labelled so: it chose nothing)

Memory at k = 5 and T = 0.1, sweeping the blend weight λ:

| λ | 0 | 0.1 | 0.2 | 0.3 | **0.5** | 0.7 | 0.9 |
|---|---|---|---|---|---|---|---|
| TU-Berlin | 0.676 | 0.678 | 0.682 | 0.687 | **0.699** | 0.711 | 0.678 |
| Ordinary drawings | 0.870 | 0.871 | 0.871 | 0.872 | **0.868** | 0.832 | 0.638 |

Up to λ ≈ 0.5, the memory improves the new style at **no measurable cost** to ordinary
drawings. Past that, forgetting sets in fast. Tuning on the new style alone landed at 0.7,
because nothing in that objective could see the cost.

### Wrong corrections (k = 5)

| Wrong labels | Memory | Retrain |
|---|---|---|
| 0% | 0.711 ± 0.005 | 0.706 ± 0.005 |
| 20% | 0.703 ± 0.005 | 0.626 ± 0.008 |
| 40% | 0.694 ± 0.004 | 0.567 ± 0.015 |

The memory degrades gently. Averaging embeddings dilutes a wrong one, and the model's own
probabilities still vote. A retrained layer learns the wrong labels outright.

## Results: when preprocessing erases the strokes (TU-Berlin through the game's own preprocessing)

| k | Frozen | Memory | Retrain | Ordinary: memory | Ordinary: retrain |
|---|---|---|---|---|---|
| 0 | 0.212 | — | — | 0.870 | 0.870 |
| 1 | 0.212 | 0.289 ± 0.016 | 0.415 ± 0.012 | 0.593 ± 0.031 | 0.711 ± 0.018 |
| 5 | 0.212 | 0.447 ± 0.009 | 0.488 ± 0.008 | 0.668 ± 0.015 | 0.720 ± 0.016 |
| 10 | 0.212 | 0.485 ± 0.007 | 0.501 ± 0.005 | 0.675 ± 0.010 | 0.713 ± 0.013 |

The relative gains are large, but every adapted figure stays below simply preserving the
strokes (0.676), and the forgetting is severe. In this condition the right fix is in the
preprocessing, not in learning. The trade-off curve says the same: λ = 0.3 gives 0.372 at no
cost.

## What this means

**For the paper.** A defensible contribution is the *trade-off itself*: per-player adaptation
of a frozen sketch classifier from a few corrections, measured against what it forgets and how
it survives mislabelled corrections. Concretely, a non-parametric prototype memory gains
about 2.3 points at no cost to the base task with five corrections per class (λ = 0.5). It
also stays robust when 40% of corrections are wrong, where last-layer retraining does not.

The honest limits:
- the "player" is a population of drawers, not a person;
- the gains are modest;
- the λ that balances gain and forgetting was found post hoc. Choosing it properly needs a
  forgetting check inside the selection, which the experiment now shows is necessary.

**For the game, if it is built.**
- **Use the prototype memory, not retraining.** It is robust to wrong corrections, reversible,
  and per player.
- **Keep the blend modest.** λ ≈ 0.3–0.5.
- **Ask for corrections only when they can pay.** One per class does nothing. The memory
  starts helping at three.
- **A correction must teach, never pass a gate.** This also matters because players will
  sometimes be wrong; the experiment shows the memory tolerates that.
- **Use the corrections as ground truth.** They are the `intended_class` labels that would
  finally make live-play per-class recall measurable (MANUSCRIPT_CONFLICTS A7).
- **The manuscript holds the model fixed at export** (§3.2.10). Even a frozen network with a
  per-player memory changes what is recognised from session to session, so the panel would
  need to approve it.

## Reproducing it

The experiment needs `onnx`, `onnxruntime`, `numpy` and `pillow`, and TU-Berlin unpacked into
`model/data/tu_berlin/` (see PR #139). Quick, Draw! files must be in `model/data/` for the
forgetting check; the script uses whichever roster classes are present (15 here). It is
deterministic: every trial is seeded, and a rerun reproduces these tables exactly. It takes
about three minutes on a laptop CPU.

```
python model/correction_experiment.py --out model/correction_experiment.json
python -m unittest -v tests.test_correction_experiment
```
