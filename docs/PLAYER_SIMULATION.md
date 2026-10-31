# Simulated players: does learning from corrections help in play?

2026-10-31. Code: `model/player_simulation.py`. Raw results: `model/player_simulation.json`.
This follows [CORRECTION_EXPERIMENT.md](CORRECTION_EXPERIMENT.md). Nothing in the game changed.

## The answer, in short

- **No. Learning from corrections makes play worse, at every skill level.** Offline, a memory
  of the player's corrections added 2.3 points of top-1 accuracy. In a session played through
  the real 0.60 / 0.15 gate, it lowers how often a drawing is accepted correctly on the first
  try:
  - the plain memory by **33–42 points**;
  - a repaired memory by **12–24 points**.
- **The memory's one benefit is better had from the gate.** The memory cuts wrong accepts, the
  wrong thing appearing, by 30–70%. Simply raising the confidence bar buys the same reduction
  for far less: for an expert, a 0.70 bar gives 0.798 right first try with 8.9% wrong accepts,
  against the repaired memory's 0.702 and 8.8%.
- **Even the shipped game accepts a wrong class on about 1 attempt in 8**, for players of
  every skill. This is the real finding, and it's what the per-level bars (#142) address. The
  table below gives the first measured evidence of what each bar costs and buys.

**Recommendation: don't build the correction feature.** Keep the per-level bars, and use this
simulation's numbers when reporting them.

## How the players were simulated

**A player has a personal style and a skill level.** The style is fixed for the whole session:
a slant, a shear, a squash, and a heavier or lighter hand, drawn at random within the skill's
range. The skill adds per-drawing noise: wobble (an elastic warp), unfinished strokes (an
erased patch), and stray marks. It also sets a chance of answering "which did you mean?"
wrongly.

| Skill | Style range | Wobble | Unfinished | Stray mark | Wrong answer when asked |
|---|---|---|---|---|---|
| Expert | ±8°, light | none | never | never | 0% |
| Average | ±15° | some | 30% | 10% | 2% |
| Beginner | ±25°, strong | heavy | 50% | 30% | 5% |
| Careless | ±15° | some | 70% | 40% | 15% |
| Control: no personal style | ±15°, re-drawn **every drawing** | some | 30% | 10% | 2% |

**The drawings** are Quick, Draw! drawings that training never read: 200 per class from row
40,000 on, for all 50 classes, fetched by HTTP byte range. Each is rendered at 112 px, styled
and noised there, and then framed exactly as training framed it.

**A session** is 300 drawings: 6 of each class, in random order, with up to 3 attempts each.
Every attempt goes through the gate (confidence ≥ 0.60, margin ≥ 0.15) and has one of three
outcomes:
- **accepted and right**: a success;
- **accepted and wrong**: the wrong thing appears;
- **declined**: with the memory on, if the right class is among the model's top two, the
  player is asked "which did you mean?" Their answer teaches the memory but **never passes the
  drawing**; they still redraw.

There are 20 players per skill. Figures are means over players ± a 95% interval.

**Three conditions, each run on the identical drawings:**

| Condition | What it is |
|---|---|
| **Frozen** | The shipped model. |
| **Memory** | The prototype memory from the correction experiment, at λ 0.5 and T 0.1. These settings were fixed before this experiment, not tuned on it. |
| **Gated memory** | Added **after** Memory's first run showed it breaking the gate. The memory gets an "I don't know this one" option, which hands its share back to the model when a drawing resembles no correction. Its one setting, a similarity of 0.9, was chosen on 10 separate dev players. The reported players never took part. |

## Results

### Right first time

| Skill | Frozen | Memory | Gated memory | Gated − frozen (paired) |
|---|---|---|---|---|
| Expert | **0.819 ± 0.011** | 0.417 ± 0.016 | 0.702 ± 0.018 | −0.117 ± 0.010 |
| Average | **0.714 ± 0.024** | 0.298 ± 0.018 | 0.498 ± 0.037 | −0.216 ± 0.017 |
| Beginner | **0.494 ± 0.071** | 0.160 ± 0.036 | 0.274 ± 0.048 | −0.219 ± 0.026 |
| Careless | **0.618 ± 0.029** | 0.204 ± 0.018 | 0.410 ± 0.022 | −0.208 ± 0.014 |
| No personal style | **0.699 ± 0.015** | 0.275 ± 0.012 | 0.458 ± 0.020 | −0.241 ± 0.015 |

### The rest of the session (frozen → gated memory)

| Skill | Success within 3 tries | Attempts per drawing | Wrong accepts per attempt | Corrections made | Right first time, last third of session |
|---|---|---|---|---|---|
| Expert | 0.819 → 0.801 | 1.36 → 1.53 | 0.128 → 0.088 | 125 | 0.828 → 0.642 |
| Average | 0.801 → 0.683 | 1.51 → 1.89 | 0.128 → 0.052 | 245 | 0.704 → 0.362 |
| Beginner | 0.645 → 0.450 | 1.90 → 2.35 | 0.141 → 0.041 | 326 | 0.501 → 0.221 |
| Careless | 0.772 → 0.596 | 1.66 → 2.07 | 0.116 → 0.042 | 274 | 0.628 → 0.477 |

### Why the memory fails in play

**The plain memory breaks the gate.** It gives its share of probability only to classes the
player has corrected. So a drawing of any other class can reach at most about 0.5 confidence,
under the 0.60 gate, and is declined. That decline produces another correction, which pulls
harder. Offline, the experiment scored only the top answer and ran no gate, so this never
showed. **An offline accuracy gain is not evidence of a gain in play.** That lesson carries
over to any recogniser behind a confidence gate.

**The repaired memory still loses.** Every time the memory and the model disagree, the blend
lowers the top confidence, and the gate declines it. Sessions get *worse* as the memory fills:
an average player falls from 0.704 to 0.362 in the last third. The control without a personal
style fails in the same way, so this is not a failure to learn a style. Blending probabilities
in front of a confidence gate trades away acceptances.

### The gate itself (frozen model; this evaluates the shipped design and chooses nothing)

Each cell is right first time / wrong accepts per attempt:

| Bar | Expert | Average | Beginner | Careless |
|---|---|---|---|---|
| 0.50 | 0.834 / 0.168 | 0.738 / 0.168 | 0.526 / 0.199 | 0.648 / 0.161 |
| **0.60** (floor; Payyo, Piyesta) | 0.819 / 0.128 | 0.714 / 0.128 | 0.494 / 0.141 | 0.618 / 0.116 |
| **0.65** (Dagat) | 0.807 / 0.108 | 0.697 / 0.108 | 0.473 / 0.116 | 0.597 / 0.099 |
| **0.70** (Dilim) | 0.798 / 0.089 | 0.679 / 0.088 | 0.451 / 0.094 | 0.575 / 0.081 |
| **0.75** (Mayon) | 0.782 / 0.075 | 0.661 / 0.071 | 0.428 / 0.076 | 0.548 / 0.063 |
| 0.80 | 0.765 / 0.057 | 0.637 / 0.055 | 0.405 / 0.058 | 0.518 / 0.048 |
| 0.90 | 0.712 / 0.029 | 0.563 / 0.027 | 0.328 / 0.026 | 0.441 / 0.021 |

**What each bar costs and buys.**
- Each 0.05 step costs about 1–3 points of right-first-time and removes about 1.4–2.5 points of
  wrong accepts.
- Mayon's 0.75 bar halves wrong accepts against the floor (12.8% to 7.1% for an average
  player), for 5 points of first-try success.
- Beginners pay the most.
- The sweep holds each bar fixed. In the game the bar eases after two misses, so the real cost
  is lower than shown.

## Limits

- **The players are synthetic.** Their styles and noise are transforms of real drawings, not
  real people. The skill levels are plausible, not calibrated against anyone.
- **An expert has no per-drawing noise**, so their three attempts are the same drawing. Their
  "within 3 tries" equals their first try for that reason.
- **One base drawing per intent** is re-rendered for each attempt. A real redraw would vary
  more.
- **The gated memory was a second design, added after the first failed.** It was then held to
  the same protocol: dev-chosen, never tuned on the reported players. I stopped after it,
  rather than trying variants until one won.

## What it means for the paper

**Two findings are worth reporting.**
1. **The negative result**, with its mechanism. Per-player memory that improves offline
   accuracy reduces correct acceptances in closed-loop play behind a confidence gate. The
   only benefit, fewer wrong accepts, is dominated by simply raising the gate. A short, honest,
   reproducible result like this is a real contribution.
2. **The gate's measured trade-off by skill.** It's the first quantitative support for the
   per-level acceptance threshold (§4.5.4.2). It also flags that the floor alone lets about 1
   in 8 attempts produce the wrong thing.

## Reproducing it

```
python model/player_simulation.py --out model/player_simulation.json   # about 4 minutes on CPU
python -m unittest -v tests.test_player_simulation
```

The simulation needs `onnx`, `onnxruntime`, `numpy`, `scipy` and `pillow`. It also needs the
unseen Quick, Draw! rows in `model/data/quickdraw_unseen/`, which
`python model/fetch_unseen_quickdraw.py` fetches (about 8 MB). Every player is seeded, and a rerun reproduces the tables exactly.
