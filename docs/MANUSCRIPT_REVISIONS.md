# Manuscript revisions: what to change, and where

For the authors of `OBRA_THESIS1.pdf`, as of 2026-10-31 (`main` after #152). Page numbers are
the printed ones (the appendices carry none, so they are given as PDF pages). Each entry gives the location, what the manuscript says now, what to write
instead, and the evidence. The evidence lives in the repository, so every number can be
checked.

**Priority:**
- **Must**: the manuscript is now wrong about the system.
- **Should**: it is incomplete, or promises something it never delivers.
- **Decide**: the team has to choose before the text can be written. Each "Decide" item gives
  the options.

**What does not need changing.** Several things the manuscript says were made true in the
game on 2026-10-31, so the text can stay:
- the ConceptNet attribution account (§3.2.6–3.2.7, §4.2.8, Appendix C; the game now *is*
  Appendix C, #152);
- the per-level acceptance threshold (§4.5.4.2, #142);
- the ending precedence C → A → B → D (§4.5.4.5, #140);
- end-to-end latency measured to the entity's appearance (Eq. 12, #145);
- request-size and timeout verification (§4.10.2, #144);
- seeded training (§4.7.5, #143).

The three items the team chose to appeal are marked **[appeal]**. They should not be edited
until the panel answers: the TU-Berlin protocol, the game design as built, and deferring
audio and dialogue.

---

## Front matter

### Abstract (p. ii) — Must
- **Now:** "…six affordance-bearing relations… forty-eight of fifty classes are grounded this
  way, and the remaining two are hand-authored and marked as such."
- **Write:** "…**forty-nine** of fifty classes are grounded this way, and the remaining **one
  is** hand-authored and marked as such."
- **Why:** mushroom was replaced by bread, and bread is grounded through
  `bread -UsedFor-> feeding_to_birds` (ConceptNet 5.7.0, weight 1.0). Only penguin remains
  hand-authored. See `tools/build_abilities.py`.

### Abstract (p. ii) and §1.2.1, §1.2.2, §1.4 (pp. 4–8) — Must: participant count
- **Now:** "around 45 participants" (§1.2.1), "at least forty-five participants" (§1.2.2,
  objective 5), "a minimum of thirty participants" (§1.4), and "at least thirty
  participants" (Abstract).
- **Write:** one number everywhere, the one §4.1.2's sampling justifies. If players,
  developers and cultural evaluators are counted together, say so: for example, "at least
  thirty play testers, with game developer practitioners and cultural evaluators recruited
  separately."

### Table of contents and appendix titles — Must
- **Now:** the TOC lists "Appendix C: ConceptNet Ability Attribution Table", but the table's
  own page is headed "**Appendix D**: ConceptNet Ability Attribution Table". A different page
  is also headed "Appendix C: Transmittal Letter, Instrument Permission and Licensing". The
  text cites "Appendix C" for the attribution table (pp. 27, 97, 179).
- **Write:** one numbering, used consistently by the TOC, the page headings and the in-text
  references.

---

## Chapter 1

### §1.1 Rationale (p. 4) — Should: cultural neutrality claim
- **Now:** "its draw-to-ability mechanic is culturally neutral and portable, while its
  Filipino character lives in its setting, story, characters, and art direction."
- **Write:** "Its **recognition and ability pipeline** is culturally neutral and portable — the
  fifty classes are everyday objects and animals — while its Filipino character lives in
  its setting, story and art direction, **and in Level 4, in its encounters**, where folkloric
  creatures (the aswang, kapre, tikbalang, manananggal and others) are answered by
  folklore-specific counters."
- **Why:** Dilim puts mythology into the encounter design (`LEVEL_4.md`, "Manuscript note").
  The Cultural Content Questionnaire should then assess those creatures too.

### §1.4 Scope and Limitations (p. 8) — Must
- **Now:** "served locally for high-speed inference via the ONNX runtime **within the Godot
  engine**."
- **Write:** "served locally by a **co-located Python recognition service** running the model
  under ONNX Runtime, which the game starts and stops itself."
- **Why:** this is what §3.2.9 and §4.5.1 already say; §1.4 contradicts them.

### §1.4 (p. 8) — [appeal]
Move dynamic audio and the shuffle-bag dialogue system into the limitations, as future work.

---

## Chapter 3

### §3.2.5 Generalization (p. 24) — Should: augmentation
- **Now:** "mild rotations, shifts, and rescalings are applied to training images on the
  fly."
- **Write:** "…mild rotations, shifts and rescalings, **together with a light Gaussian blur and
  a down-then-up resampling that reproduce how the game's 512-pixel canvas is reduced to 28
  pixels**, are applied to training images on the fly."
- **Why:** `model/train_quickdraw.py`, `QuickDrawDataset._render_sim`.

### §3.2.7, Table 1 (p. 27) — Must
- **Now:** the Objects row lists "mushroom".
- **Write:** "**bread**".

### §3.2.7 (p. 28) — Must
- **Now:** "Forty-eight of the fifty classes are grounded in this way; two, penguin and
  mushroom, are hand-authored."
- **Write:** "**Forty-nine** of the fifty classes are grounded in this way; **one, penguin, is**
  hand-authored."

### §3.3.2 or §3.3.3 (pp. 37–39) — Should: the network is never described
- **Now:** no architecture is given anywhere, and §3.3.3 says "the specific optimizer settings,
  dropout rate, and augmentation parameters are reported in Chapter 4". Chapter 4 never reports
  them.
- **Write** (in §3.3.2, or a table in §4.3.2):

  > Three convolutional blocks — 3×3 convolutions of 32, 64 and 128 filters, each followed
  > by ReLU, the first two by 2×2 max-pooling — feed a fully connected layer of 128 units with
  > dropout 0.3 and a 50-way output: 902,066 parameters over a 28×28×1 input. It is trained
  > with Adam (learning rate 0.001, batch 256) for 8 epochs under cross-entropy. Augmentation
  > is a random affine transform (rotation ±12°, translation ±8%, scale 0.85–1.15), Gaussian
  > blur (σ 0.4–1.4, p = 0.8) and a bilinear down-then-up resample through 20, 22 or 24 pixels
  > (p = 0.5). It is exported to ONNX at opset 18 with a dynamic batch axis.

- **Why:** `model/train_quickdraw.py`. The parameter count and opset were confirmed from
  `model/model.onnx` itself.

---

## Chapter 4

### §4.2.3, Table 4 (pp. 85–86) — Must
- **Now:** "6,982,163 drawings across the 50 enabled classes."
- **Write:** "**6,960,566**". With bread replacing mushroom, the total is 6,982,163 − 142,167 +
  120,570. The range is unchanged: butterfly 117,999 to penguin 253,791.
- **Also:** the same figure appears in the "Basis for the Selection" paragraph (p. 86) and in
  §4.2.4 (p. 87).

### §4.2.4, Table 5 (p. 88) — Must
- **Now:** a mushroom row.
- **Write:** a **bread** row with **120,570** raw drawings (about 94.5 MB), and the total updated
  as above.

### §4.2.6 (p. 93) and §4.7.5 (p. 148) — Should: seeding
- **Now:** "Training uses a fixed random seed."
- **Write:** "The 80/10/10 split is shuffled with a fixed seed (42), and the same seed fixes
  weight initialisation, data-loader shuffling and augmentation. Framework versions are
  recorded alongside the model."
- **Decided (2026-10-31): no retrain**, so every reported figure stands. Use this wording
  instead: "The 80/10/10 split is shuffled with a fixed seed (42). The training pipeline seeds
  weight initialisation, data-loader shuffling and augmentation with the same seed, and records
  framework versions, for any retraining (#143); the reported model predates this and seeded
  its split only."

### §4.2.7, Table 6 (pp. 93–95) — Must and [appeal]
- **Now:** TU-Berlin has "markedly thicker strokes; normalized to the model's 28 × 28
  grayscale input" through "exactly the same preprocessing as the live game".
- **Must:** "markedly thicker" is wrong relative to the frame. The strokes are a few pixels
  wide on a 1111-pixel image, so after the 40-fold reduction they fall to 20–30% of full ink.
  Write "**thin relative to their 1111-pixel frame**".
- **[appeal]:** report TU-Berlin under both protocols:

  | Protocol | Accuracy | Macro recall (40 classes) |
  |---|---|---|
  | Game's own preprocessing | 0.212 | 0.213 |
  | Stroke-preserving (block-max) reduction | 0.677 | 0.681 |

  The stroke-preserving variant was fixed before its result was seen. Results:
  `model/metrics_tu_berlin*.json`, from #139.
- **Also:** coverage is unchanged at 40 classes. TU-Berlin has a "bread" category, just as it
  had "mushroom".

### §4.2.8, Tables 7–9 and the paragraph between them (pp. 96–99) — Must
Only the counts change, because of bread:

| Where | Now | Write |
|---|---|---|
| Table 8, classes with a ConceptNet-derived ability | 48 of 50 | **49 of 50** |
| Table 8, classes hand-authored | 2 (penguin, mushroom) | **1 (penguin)** |
| Table 8, total abilities attributed | 117 | **119** |
| Table 8, mean abilities per grounded class | 2.4 | **2.4** (119 / 49 = 2.43) |
| Table 9, Direct | 84 | **86** (bread's Feed and Eat) |
| Text (p. 98) | "as for penguin and mushroom" | "as for penguin" |

**Add a sentence.** It is the strongest evidence for the provenance claim, and the manuscript
should state it plainly: "**Every one of the 119 attributions was verified against the
ConceptNet 5.7.0 assertions dump: all exist, with the weights reported.**" The evidence is
`tools/build_abilities.py --dump`, which reports 124 of 124 edges verified, counting each
inherited row's two links.

### §4.5.1, FR-7 (p. 110) — [appeal]
- **Now:** a six-unit budget throughout; transforming at a checkpoint is free; a tool is
  reusable after its first purchase.
- **Write** the as-built economy:
  - six units (seven in Level 1);
  - a tool's class costs one unit the first time it is recognised, but each drawn tool is used
    once;
  - a placeable costs one unit per placement;
  - Levels 1–2: transforming is free, and a form lasts ten seconds;
  - from Level 3: a held form drains ink, and ink refills within the level;
  - Level 4: each weapon or light costs ink, and rest clearings refill it;
  - Level 5: every drawing costs one unit, there is no refill, and a hidden reserve of two
    units covers only the two gates;
  - a declined drawing costs nothing at any level.
- **Source:** `AGENTS.md` ("A level has two clocks"), `LEVEL_3.md`, `LEVEL_4.md`, `LEVEL_5.md`.

### §4.5.1, FR-8 (p. 111) — [appeal]
- **Now:** transformation happens at a checkpoint.
- **Write:** "The player may transform anywhere. Checkpoints save and restore state." The
  checkpoint gate was removed after playtesting.

### §4.5.1, NFR-2 (p. 111) — Should
- **Now:** "no remote server, external network, or second device is required at runtime."
- **Write:** add "**once installed**". On first launch the recogniser sets up its Python
  environment and installs its packages, which needs internet access. Alternatively, ship a
  pre-built environment with the game.

### §4.5.4.2 Adaptive Difficulty (pp. 121–122) — Should: add what was built
The text is now true. Add the specifics, so it can be checked:

> The floor of 0.60 confidence and 0.15 margin never changes. The per-level confidence bar is
> 0.60 in Levels 1–2, 0.65 in Level 3, 0.70 in Level 4 and 0.75 in Level 5. After two
> consecutive declines it falls by 0.05 per further decline until it reaches the floor, and an
> accepted drawing restores it. In the story, the higher bar belongs to the new brush the
> player finds in Level 3, which asks for a surer line; it applies only once that brush is in
> hand. A drawing the floor accepts but the bar declines is logged as such, so recognition
> metrics remain reported at the floor.

**Optional:** add the measured trade-off from `docs/PLAYER_SIMULATION.md`, a simulation of
players at four skill levels. For an average player, raising the bar from 0.60 to 0.75 lowers
right-first-time from 0.714 to 0.661 and halves wrong accepts, from 12.8% to 7.1% of attempts.

### §4.5.4.4 Priority Queue Dialogue (p. 125) — [appeal]
Move to future work. Each beat currently plays one line.

### §4.5.4.5 Playstyle Profiles & Multiple Endings (pp. 126–127) — Must and [appeal]
- **Must:** delete "Because there are four nodes in total, no two routes can each be taken three
  or more times, so Endings A, B, and C are mutually exclusive by construction." It is not true
  of the game: the route tally counts every fork, Dilim adds one point for its majority route,
  replays add more, and Mayon's flower fragment counts as artist. Write instead: "**Several
  ending conditions can hold at once; precedence C → A → B → D resolves them, so every profile
  yields exactly one ending.**" The C → A → B → D order already matches the code (#140).
- **[appeal]:**
  - Endings A–D are computed and logged for the telemetry analysis, but **not shown**. The run
    ends at Mayon's summit, where saving all five flowers gives the perfect version and fewer
    gives the standard one, voiced by the player's dominant route.
  - Hidden Flower 5 is saved from a memory fragment in Level 5, not found beside the easel.

### §4.5.4.6 Expanded Branching Level Design (pp. 127–133) — [appeal]
- **Fix now** (factual, independent of the appeal): "Level 1: Bahay Kubo" → "Payyo"; "Level
  2: Pista" → "Piyesta".
- **Replace each level's design with the as-built summary.** Sources are the first paragraph
  of `LEVEL_1.md` to `LEVEL_5.md`:
  - **Payyo:** three beats gated by ability tags.
  - **Piyesta:** recover seven scraps; flight is a restriction, not an ability.
  - **Dagat:** one boat-or-dive fork, the bakunawa with three resolutions, and the game's first
    fight.
  - **Dilim:** fighting by drawing, with the lantern as health; six folkloric creatures; survive
    until dawn.
  - **Mayon:** no combat, finite ink, memory fragments, Lolo's vanishing, and the summit as the
    ending.
- **Also on p. 128:** "The ink budget of six units is unchanged throughout" should follow FR-7
  above. "Mayon's layout is determined by the paths chosen" becomes "one layout; the dominant
  route voices the summit monologue".

### §4.5.4.7 Audio & Visuals (p. 133) — [appeal]
Dynamic audio moves to future work. The game's sound system is in place, with every sound
identified, but no recordings exist yet.

### Figure 15 (p. 134) — Must
The flowchart's lower half selects among Endings A–D for display. Redraw it so the endings
are computed and logged, and the summit is the ending (see §4.5.4.5).

### §4.7.5 Security and Quality Approaches (p. 148) — Must
- **Now:** the contract tests enforce "twenty playable creatures and thirty drawable objects".
- **Write:** "twenty playable creatures, three primitives and twenty-seven objects".
- **Why:** `tests/test_manifest_contract.py` counts by runtime role.

### Table 10, Software Development Tools (pp. 149–150) — Should
- **Now:** exact versions are given, but the repository had no record of them.
- **Write:** the versions written to `model_metadata.json` by the next training run (#143), or
  the versions actually installed on the training machine. Do not use guessed values.

### §4.10.2 Verification (pp. 169–171) — Should
The integration claims are now true. Make them concrete:
- the recogniser refuses requests over 8 MB of encoded image (HTTP 413) before decoding;
- a submission times out after 20 s and a live guess after 5 s, and a timed-out submission
  frees the panel (#144).

### §4.10.3 Validation (pp. 172–175) — Must (decided 2026-10-31 and built, #154)
1. **Live-play recall (p. 174).**
   - **Now:** "restricted to those obstacles that solicit a class by name".
   - **Write:** "Obstacles declare ability tags, not classes, so live play is measured two ways.
     **Every drawing made at an obstacle** is scored by whether it satisfied the tag the
     obstacle asked for; a declined drawing satisfies nothing. **Once the third hint names a
     class**, the obstacle solicits that class by name, and the drawings made from then on
     carry it as their intended label. Per-class recall at the gate (a decline counts as a
     miss) is reported on that subset, with its support."
   - **Why:** each recognition record now carries the obstacle, its tags, the hint tier and,
     from the third hint, `intended_class`. `obstacle_attempt` events record whether each
     accepted drawing met the tag. `tools/aggregate_telemetry.py` reports both.
2. **Table 14 (p. 175).**
   - **Now:** frame rate, CPU, GPU and memory.
   - **Write:** frame rate across each submission's own recognition window (the 55 fps floor),
     plus frame rate and memory sampled at 1 Hz for the session. CPU and resident memory of
     **both** the game and the recogniser are sampled at 1 Hz by the recogniser, as a percentage
     of one core. **Remove GPU utilisation**: the engine does not expose it. Video-memory use is
     reported in its place.
   - **Why:** `telemetry.gd` writes the `perf` samples; `backend/telemetry.py` writes the `cpu`
     samples; the game now turns the recogniser's log on and puts it beside its own.
3. **Recognition speed (p. 174).** No change needed. Eq. 12's "to appearance" is now logged as
   a `spawn` event, and `tools/aggregate_telemetry.py` reports its median and 95th percentile.
4. **TU-Berlin (p. 174):** [appeal]. Report both protocols, as under §4.2.7.

---

## Appendix (ConceptNet Ability Attribution Table; unnumbered, PDF pages 263–269) — Must
- **Replace row 49** (mushroom, "Bounce", hand-authored) with bread:

  | # | Class | Group | Ability | Mode | ConceptNet derivation |
  |---|---|---|---|---|---|
  | 49 | bread | Object | **Feed** | Direct | bread -UsedFor(1.00)-> feeding_to_birds |
  | | | | Eat | Direct | bread -UsedFor(5.66)-> eating |

- **In the note under the table:** change "Two classes have no usable assertion…" to "**One**
  class has no usable assertion…". Remove the mushroom paragraph, the one citing Super Mario,
  and keep the penguin paragraph.
- **Rake** (row 42): the derivation prints no weight. Write `rake -MannerOf(2.00)-> gather`.
  This is the verb sense, "to rake is a way to gather", in ConceptNet 5.7.0.
- **Optional:** add to the note, "Every derivation in this table was verified against the
  ConceptNet 5.7.0 assertions dump on 2026-10-31."

---

## New material the manuscript can now report

Add these to the results chapter when it is written, or to §4.10.3 as preliminary results.
Each is reproducible from the repository.

| Result | Where it is |
|---|---|
| Held-out Quick, Draw! test accuracy 0.866, with per-class precision and recall. Frog (0.576) and bird (0.669) fall below 0.70, and no gate depends on either alone. | `model/metrics.json` |
| TU-Berlin under both protocols (0.212 and 0.677) | `model/metrics_tu_berlin*.json`, #139 |
| All 117 Appendix C attributions verified in ConceptNet 5.7.0 (119 with bread) | `tools/build_abilities.py --dump`, #152 |
| The confidence gate's trade-off by player skill: the floor alone accepts the wrong class on about 1 attempt in 8 | `docs/PLAYER_SIMULATION.md`, #149 |
| A negative result: per-player correction memory helps offline but hurts in play behind a confidence gate | `docs/CORRECTION_EXPERIMENT.md`, `docs/PLAYER_SIMULATION.md` |
