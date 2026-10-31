# OBRA — paper status, for choosing where to publish

*As of 2026-10-31 (repository `hyuuuan/OBRA`, `main` after PR #152). Written so it can be
handed to an assistant helping the authors pick conferences. Every number below is in the
repository and reproducible from it.*

## In one paragraph

OBRA is a 2D adventure game in which a player's freehand drawing becomes what it depicts.
A CNN classifies the sketch into one of 50 classes; a confidence-and-margin gate decides
whether to act on it or ask for a redraw; each class carries real-world abilities grounded
in the ConceptNet commonsense knowledge graph; and the player's own strokes are rigged into
a physics-driven, animated body or object, so the drawing itself is what moves. The game is
set in the Philippines: five levels inside a missing grandmother's paintings, from the
Ifugao rice terraces to Mayon Volcano, with Philippine folklore in its fourth level. It is
an undergraduate thesis (BS Computer Science) at the University of San Carlos, Cebu, the
Philippines. Its four authors are Rusk Rye Ioan C. Alarde, Erika Bianca E. Api, Kent Jester
P. Gatchalian and Lady Kaina V. Gutierrez, advised by Christine F. Peña, MMath.

## Status at a glance

| | Status |
|---|---|
| The game | **Complete and playable end to end.** Five levels plus a hub; an automated run covers title → all five levels → ending → home. Some art and dialogue are still placeholders, and there is **no audio** yet. |
| Recognition model | Trained, evaluated, shipped. |
| Knowledge grounding | Done and **verified**: every attribution checked against ConceptNet 5.7.0. |
| Offline experiments | Four complete (below). |
| **User study** | **Not yet run.** It is planned (≥30 players; SUS, UEQ-S, IEQ-SF, GEQ, Godspeed Animacy, QUESI Familiarity; in-game telemetry). **No human-participant data exists yet.** |
| Thesis manuscript | Written (proposal stage). A revision appeal to the panel is drafted. |

## What is new (candidate contributions)

1. **Recognition as a game verb, not a score.** Drawing games usually guess a sketch and
   discard it. Here the recognised class grants abilities, and the player's actual strokes
   become the rigged, physics-animated entity. That entity is an active ragdoll built from
   the drawing, with no template limbs.
2. **Commonsense-grounded abilities with full provenance.**
   - 119 abilities over 49 of 50 classes come from ConceptNet. They use six
     affordance-bearing relations (CapableOf, UsedFor, HasProperty, HasA, ReceivesAction,
     MannerOf) plus a guarded IsA traversal, so a penguin cannot inherit a bird's flight.
   - They were selected "requirement first, weight second". **Every edge was verified against
     the ConceptNet 5.7.0 dump with exact weights.** One class (penguin) is hand-authored and
     marked as such.
   - Gameplay gates use a separate, design-authored ability-tag layer. Its provenance is
     recorded per membership: 16 of 91 memberships coincide with ConceptNet.
3. **Abstention as a game mechanic, measured by player skill.** A dual gate (confidence ≥ 0.60
   *and* top-two margin ≥ 0.15) turns uncertain predictions into redraws. A per-level bar rises
   above that floor and eases back after repeated misses; in the story, it is a new brush that
   wants a surer line. **A simulation of players at four skill levels quantifies the
   trade-off** (below).
4. **A negative result with a mechanism.** Learning from player corrections (a per-player
   prototype memory over a frozen CNN) improves offline accuracy but **hurts acceptances in
   closed-loop play behind a confidence gate**. Its one benefit, fewer wrong acceptances, is
   had more cheaply by raising the gate.
5. **A preprocessing pitfall in cross-dataset sketch evaluation.** Evaluated "exactly as the
   game preprocesses", TU-Berlin scores 0.212, because averaging down 1111-pixel pen lines
   erases them. A stroke-preserving reduction gives 0.677. Both are reported.
6. **Cultural design.** A Filipino setting and folklore carried by a culturally neutral
   recognition pipeline. A Cultural Content Questionnaire is planned with
   anthropology, sociology and history students.

## Results available now

**Recognition** (`model/metrics.json`):
- Held-out Quick, Draw! test accuracy is **0.866**: 200,000 drawings, 50 classes, capped at
  40,000 per class, 80/10/10 split. Macro precision and recall are both 0.866.
- Two classes are below 0.70 recall: frog (0.576) and bird (0.669). The level audits confirm
  that no gate depends on either alone.

**Cross-dataset, TU-Berlin** (40 of 50 classes covered, 3,280 sketches):
- 0.212 with the game's own preprocessing;
- **0.677** with stroke-preserving reduction (macro recall 0.681). This variant was fixed
  before its result was seen.

**The model:**
- Three convolutional blocks (32/64/128 filters) → FC 128 → 50 classes, with dropout 0.3:
  902,066 parameters, input 28×28×1.
- Adam (learning rate 0.001), batch 256, 8 epochs.
- Augmentation: affine transforms, plus blur and resampling that simulate the game canvas.
- Exported to ONNX, served by a local FastAPI recogniser that the game starts and stops.

**The gate by player skill** (`docs/PLAYER_SIMULATION.md`; 20 simulated players per skill,
300 drawings each, real gate). Each cell is right first try / wrong class accepted per
attempt:

| Bar | Expert | Average | Beginner | Careless |
|---|---|---|---|---|
| 0.60 (floor) | 0.819 / 12.8% | 0.714 / 12.8% | 0.494 / 14.1% | 0.618 / 11.6% |
| 0.75 | 0.782 / 7.5% | 0.661 / 7.1% | 0.428 / 7.6% | 0.548 / 6.3% |

**Correction memory** (`docs/CORRECTION_EXPERIMENT.md`, `docs/PLAYER_SIMULATION.md`):
- Offline: +2.3 points on TU-Berlin with five corrections per class, at no cost to ordinary
  drawings. It is robust to 40% wrong corrections (−1.7 points), where last-layer retraining
  is not (−13.9).
- In play: first-try success **drops** by 12–42 points at every skill level.

**Engineering:** every response logs a latency split (decode, preprocess, inference), and
every accepted drawing logs the time from Paint to the entity's first frame.

## What is not done, and what cannot be claimed yet

- **No user study.** There are no usability, immersion or player-experience scores, no
  real-play latency or frame-rate figures, and no live-play recognition data. Any claim about
  players' experience waits on the playtest.
- **The simulated players are synthetic**: style and noise transforms of real drawings, not
  people.
- **Live-play per-class recall cannot be measured as the manuscript proposes**, because
  obstacles ask for ability tags, never classes. A tag-level measure or in-study labelling is
  needed.
- **Frame-rate, CPU, GPU and memory logging is not built.**
- **The shipped model predates full training seeding** (only its split was seeded), and its
  framework versions were not recorded. A retrain fixes both.
- **There is no audio**, and some art is placeholder.
- **No comparison with other architectures, no calibration analysis, no ablation of the gate
  thresholds** beyond the simulation.

## What this suggests about venues

The work spans **HCI and games** (drawing as interaction, abstention as a mechanic),
**sketch recognition**, **commonsense knowledge in interactive systems**, **procedural
animation**, and **serious or cultural games** (Philippine heritage).

- **Publishable before the playtest:**
  - demos, posters, late-breaking work and work-in-progress tracks;
  - short papers on the system and its verified ConceptNet grounding;
  - the gate-by-skill simulation;
  - the TU-Berlin preprocessing pitfall;
  - the negative result on correction learning.
- **Needs the playtest:** a full paper on player experience, usability or cultural reception.
- **Practical constraints:**
  - undergraduate authors in Cebu, so regional (Asia-Pacific or Philippine) conferences, and
    student or demo tracks with lower travel costs, may matter;
  - the thesis timeline: the playtest is planned but not yet scheduled.

**Useful keywords:** sketch recognition; drawing-based game mechanics; CNN; selective
classification / abstention; confidence thresholds; ConceptNet; commonsense knowledge;
affordances; procedural animation; active ragdoll; serious games; cultural heritage games;
Philippines; game AI; human-in-the-loop learning (negative result).

## Where everything is

| Document | What it covers |
|---|---|
| `docs/MANUSCRIPT_REVISIONS.md` | What to change in the thesis manuscript |
| `docs/CONCEPTNET_VERIFICATION.md` | The ConceptNet checks |
| `docs/CORRECTION_EXPERIMENT.md`, `docs/PLAYER_SIMULATION.md` | The two learning-from-corrections studies |
| `model/metrics*.json` | All recognition figures |
| `game/config/abilities.json` | The verified ability table |
| `LEVEL_1.md` to `LEVEL_5.md` | The levels as built |
