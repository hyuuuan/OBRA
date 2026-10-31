# Manuscript vs. the game: where they disagree

Checked 2026-10-31: `docs/OBRA_THESIS1.pdf` against `main` at `d2fdd4b` (PR #138).
Section and page numbers are the manuscript's own. "Game" means the code in this
repository, not the design documents.

Each item is marked:

- **Deliberate**: the team decided it and recorded the decision (a doc or commit is
  cited). Existing project notes say these are to be fixed in the manuscript, not the game.
- **Drift**: no decision is recorded; the two simply diverged. Decide which one moves.
- **Not done**: the manuscript describes work or a feature that does not exist yet.
- **Fixed in game**: changed in the game on 2026-10-31 to match the manuscript, one PR each.
  These no longer need a manuscript change.

The items left to the manuscript are argued in `docs/OBRA Appeal Letter.docx`.

---

## A. Recognition and the model

| # | Manuscript says | Game does | Status |
|---|---|---|---|
| A1 | The roster includes **mushroom** (§3.2.7 Table 1, p.27; Table 5; §4.2.8 Table 8; §4.10.3; Appendix C row 49). | **mushroom was replaced by bread** and the model was retrained (commit `0ca55f3`, 2026-08-29; `LEVEL_2.md` decision 3). `model/labels.json`, `model/metrics.json` and `entities.json` all have `bread`. | Deliberate |
| A2 | A second, **per-level acceptance threshold rises level by level** above the 0.60/0.15 floor and decays after repeated declines; it is "held in the level definition" (§4.5.4.2, pp.121–122; §4.5.4.6, p.128). | **Built, 2026-10-31** (branches `gate-from-config`, `brush-asks-more`). Each level's `recognition` block is now read. Above the fixed floor, each level has its own bar: Payyo 0.60, Piyesta 0.60, Dagat 0.65, Dilim 0.70, Mayon 0.75. After two declines in a row it eases by 0.05 per decline to the floor, and an accepted drawing resets it. **Story reason:** it applies only once the new brush from Dagat's shore is in hand. That brush is stronger and asks for a surer line, and the lines that say so name no class. Recognition is still logged at the floor (`floor_accepted`, `redraw_rate_at_floor`). | Fixed in game |
| A3 | Augmentation is "mild rotations, shifts, and rescalings" (§3.2.5, p.24). §3.3.3 (p.39) says the optimizer settings, dropout rate and augmentation parameters "are reported in Chapter 4"; a search of Chapter 4 finds none of them. | Affine (±12°, ±8% shift, 0.85–1.15 scale) **plus** Gaussian blur (σ 0.4–1.4, p=0.8) and a down-then-up resample to 20/22/24 px (p=0.5), simulating the game's own render path. Dropout 0.3, Adam, lr 1e-3, batch 256, 8 epochs. | Drift (omission) |
| A4 | "Training uses a fixed random seed", so results can be reproduced (§4.7.5, p.148). | **Fixed, 2026-10-31** (`train-seed`). `--seed` (default 42) now seeds Python, numpy, torch, the DataLoader shuffle and every worker. A rerun on the same machine and versions draws the same numbers. Weights are not guaranteed bit-identical across devices (mps/cuda). The shipped model predates this. | Fixed in game |
| A5 | Exact framework versions: Python 3.12.6, PyTorch 2.12.1, torchvision 0.27.1, ONNX 1.22.0, FastAPI 0.139.0, and so on (Table 10, pp.149–150). | From the next retrain, `model_metadata.json` records the framework versions and the seed (`train-seed`). The shipped model still has no record, and the requirements files are still unpinned. The manuscript's Table 10 should give the versions recorded at the retrain. | Partly fixed |
| A6 | **TU-Berlin**, 40 of 50 classes, is put through "exactly the same preprocessing as the live game" (§4.2.7, pp.94–95; §4.10.3, p.174). Table 6 says its strokes are "markedly thicker". | **Run 2026-10-31.** Coverage matches: the same 40 classes, the same 10 uncovered. **Under identical preprocessing, accuracy is 0.212.** TU-Berlin's lines are thin relative to its 1111 px images, and an averaging shrink erases them. **With stroke-preserving (block-max) shrinking, accuracy is 0.677, macro recall 0.681** (`model/metrics_tu_berlin*.json`). The manuscript needs both numbers, a description of the second protocol, and a correction to "thicker": the strokes are wider in pixels but far thinner relative to the frame. | Done; manuscript needs revision |
| A7 | Live-play recall is reported per class "for obstacles that solicit a class by name" (§4.10.3, p.174). | The telemetry aggregator supports an `intended_class` field, but **no game code ever sets it**. By design, obstacles declare ability tags rather than classes (see C1), so live per-class recall cannot be computed as described. | Not done |
| A8 | The recogniser is served "via the ONNX runtime **within the Godot engine**" (§1.4, p.8). | A separate local Python process (FastAPI + ONNX Runtime on 127.0.0.1:8000), which matches the manuscript's own §3.2.9 and §4.5.1. §1.4 contradicts the rest of the manuscript. | Manuscript internal |
| A9 | Latency is measured "from capture… **to the appearance of the spawned entity**" (§3.3.8 Eq.12; §4.10.3, p.174). | **Fixed, 2026-10-31** (`spawn-latency`). Each accepted drawing logs a `spawn` event, timed from the Paint press to the first frame after the entity is made (accurate to within a frame). The aggregator reports it as "to appearance", beside "to answer". | Fixed in game |
| A10 | Frame rate, CPU, GPU and memory are recorded during play (Table 14, p.175; 55 fps floor). | **No such instrumentation.** `telemetry.gd` records lifecycle and recognition events only. | Not done |
| A11 | "No frame waits on the recognition component" (§4.10.3). | True of rendering, since the request is asynchronous. But the game world is **paused** while the drawing panel is open (`DrawPanel` processes only while the tree is paused), so an fps figure "during submission" would measure a paused world. | Wording |
| A12 | Integration verification covers "request-size limits… and timeout behavior" (§4.10.2, p.171). | **Fixed, 2026-10-31** (`backend-limits`). The backend returns 413 for `image_data` over 8 MB of text, before decoding. The client gives a submission 20 s and a live guess 5 s; on a timeout it frees Paint and says why. | Fixed in game |
| A13 | No network is needed at runtime (NFR-2, p.111). | True once installed. On first launch with no `.venv`, `backend/serve.py` creates one and **pip-installs from the internet**. | Wording |
| A14 | The contract tests enforce "twenty playable creatures and thirty drawable objects" (§4.7.5, p.148). | `tests/test_manifest_contract.py` checks **20 / 3 / 27** by `runtime_role`. | Wording |

## B. Ability attribution (ConceptNet)

| # | Manuscript says | Game does | Status |
|---|---|---|---|
| B1 | **Six relations** (CapableOf, UsedFor, HasProperty, HasA, ReceivesAction, MannerOf) plus a guarded IsA traversal; **117 abilities**, 2.4 per class on average; attribution modes Direct 84 / Property 8 / Part 9 / Action 7 / Inherited 9 (§3.2.7, pp.27–28; §4.2.8 Tables 7–9, pp.96–98). | `game/config/abilities.json` has **exactly one ability per class (50)**, using **two relations only**: CapableOf (20 creatures) and UsedFor (27 objects). No HasProperty, HasA, ReceivesAction, MannerOf or IsA entry exists anywhere. | Drift (major) |
| B2 | Hand-authored: **penguin and mushroom**. The primitives "are not among the hand-authored cases"; they are grounded through HasProperty and HasA (p.98). | Hand-authored: **circle, square, triangle** (roll / weight / wedge). Penguin is CapableOf "slide" (curated). Mushroom is not in the roster. | Drift (major) |
| B3 | Attribution is resolved against the **ConceptNet 5.7.0 dump**, and every class's assertion and weight are reported so each can be audited (Table 7; p.98). | `tools/build_abilities.py` queries the **REST API**, falling back to a hand-written table. **All 47 non-primitive entries are `conceptnet_curated`**: "documented assertions with approximate weights because api.conceptnet.io was unreachable at build time". **None is `conceptnet_api`.** The weights have not been checked against ConceptNet. | Drift (major) |
| B4 | Selection is **requirement first, weight second**: only assertions a level needs are eligible (§3.2.6, p.25; §4.2.8, p.98). | The builder's API path takes the **highest-weight edge** (`fetch_top_edge`). The curated fallback that actually shipped was chosen by hand "to match the design-doc In-Game Function", which is closer to requirement-first but is not the procedure described. | Drift |
| B5 | Obstacles are authored **against classes** (§3.2.7, p.26; level designs §4.5.4.6 name classes). The manuscript has no tag layer. | Obstacles declare **ability tags**, never classes; `tags.json` resolves each tag to ≥2 classes. Of 91 tag memberships, **17 reuse a class's ConceptNet verb and 74 are design groupings**, and `tags.json` itself says "Do not describe the tag layer as ConceptNet-derived." The gates players meet are therefore mostly design-authored, not ConceptNet-grounded. | Deliberate (undocumented in manuscript) |

## C. Game design

| # | Manuscript says | Game does | Status |
|---|---|---|---|
| C1 | Level 1 **Bahay Kubo**, Level 2 **Pista**, with the designs on pp.128–133 (bridge/spider/axe; parade float; maelstrom; aswang at the cliff; telemetry-generated Mayon). | Level 1 is **Payyo** (three beats, tag-gated). Level 2 is **Piyesta** (recover seven scraps; flight is a restriction, not an ability). Level 3 **Dagat**: one boat/dive fork, a bakunawa with three resolutions, the game's first fight. Level 4 **Dilim**: fighting by drawing, the lantern as health, six folkloric creatures, survive until dawn. Level 5 **Mayon**: no combat, finite ink, memory fragments, Lolo's vanishing, and the summit as the ending. See `LEVEL_1.md` to `LEVEL_5.md`. | Deliberate |
| C2 | Mayon's layout is **generated from the dominant route** (pragmatist slope, artist frescoes, protector gauntlet) (pp.132–133). | One layout for every player. The dominant route only changes which voice gives the summit monologue (`PlayerProfile.dominant_route()`). | Deliberate (`LEVEL_5.md`) |
| C3 | Endings **A–D play as cinematics** at the crater; Hidden Flower 5 sits beside Lola's easel (pp.126, 133). | **The summit is the ending.** Five flowers gives the perfect version and fewer the standard one. Endings A–D are computed (`EndingResolver`) and **logged to telemetry only, never shown**. The 5th flower is saved from a memory fragment in Act Two. | Deliberate (Kent, 2026-10-25; `CONTENT_NEEDED.md` §1) |
| C4 | Ending precedence **C → A → B → D** (p.127). | **Fixed, 2026-10-31** (`ending-order`). `ending_resolver.gd` now checks C → A → B → D, and the profile test pins it. | Fixed in game |
| C5 | Four dialogue nodes, one per level in Levels 1–4, so "Endings A, B, and C are mutually exclusive by construction" (§4.5.4.5, p.126). | The tally is **cumulative and grows on every replay** (`player_profile.gd` `record_route`). Levels have more than one fork (Piyesta has three; Dilim contributes its majority route), and Mayon's flower fragment adds an artist point. Two routes can both reach 3, so the endings are **not** mutually exclusive, and precedence (C4) decides. | Drift |
| C6 | FR-7: **six units throughout**; transforming at a checkpoint is free; a tool is reusable after its first purchase (p.110; §4.5.4.6, p.128). | Payyo gives **7** units. Tools are **one-use** (Kent's call). From Dagat on, ink **drains while transformed** and refills from sources in the level. In Dilim every weapon or light costs ink and rest clearings refill it. In Mayon every drawing costs 1, a creature drains, there are no refills, and a hidden reserve of 2 covers only the two gates. | Deliberate (`AGENTS.md` Gameplay Shape; `LEVEL_3.md`; `LEVEL_4.md`; `LEVEL_5.md`) |
| C7 | FR-8 / FR-7: transformation happens **at a checkpoint** (p.110). | Allowed **anywhere**; the checkpoint gate was deleted (`3cb8798`, 2026-10-02). | Deliberate (`AGENTS.md`) |
| C8 | Not mentioned. | Payyo and Piyesta give a morph a **10-second life** (`MorphLife`), and Dagat removes it. | Undocumented in manuscript |
| C9 | A **shuffle-bag priority queue** for dialogue, and replay **path nudges** (§4.5.4.4, p.125). | **Not built.** `CONTENT_NEEDED.md` §1 marks both MISSING, waiting on the writing. | Not done |
| C10 | A **dynamic audio** engine with traditional instruments, and layers that change with the route (§4.5.4.7, p.133). | **No audio in the game.** `audio.json` ids are all empty paths. | Not done |
| C11 | The draw-to-ability mechanic is culturally neutral; Philippine content sits in setting and story. | Dilim's six folkloric creatures, each with a folklore-specific counter, put mythology into encounter design. `LEVEL_4.md` recommends narrowing the claim to the recognition and ability pipeline. | Wording |

## D. Inside the manuscript itself

These are not game conflicts, but a reviewer will find them.

- **Participant count:** "around 45" (§1.2.1) and "at least forty-five" (§1.2.2 obj. 5), against "a minimum of thirty" and "roughly thirty" (§1.4).
- **Where inference runs:** §1.4 says inside Godot; §3.2.9 and §4.5.1 say a separate process (A8).
- **Training settings:** promised in Chapter 4 (§3.3.3), not given there (A3).
- **No CNN architecture is stated anywhere.** The actual one is three conv blocks (32/64/128 filters, 3×3), then FC 128 and dropout 0.3: 902,066 parameters, 28×28×1 input.
