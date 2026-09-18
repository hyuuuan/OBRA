# Level 3 — Dagat

**Status: NOT BUILT.** Nothing of this level exists in the game yet: no scene, no
`level_03.json`, no dialogue file, no art. `levels.json` carries `level_3` as **Coming Soon**
with an empty `scene_path`, which is what three tests assert and what keeps the hub from
offering a card with nothing behind it.

**This document is the plan, written before the build** — `LEVEL_TEMPLATE.md` build order
step 1, *"write `LEVEL_<N>.md` first, even as a placeholder, and mark it provisional"*. It
records what the design asks for, what the engine already has, what has to be built, and the
decisions that are still open. It becomes the build record as the level is made.

**The design is `Level 3 Dagat Design.docx` (revision 2), at the repo root**, the same place
Level 2's design sits. Where this document and the design disagree, the design wins on
intent and this one wins on what the engine actually does — and the disagreement gets written
down here rather than resolved quietly.

**Read with:** `LEVEL_TEMPLATE.md` (the shape every level inherits, R1–R10), `AGENTS.md`
(the hooks a level owes), `LEVEL_2.md` (the closest worked example — scene-based, with
overlays), `LEVEL_1.md` (the tutorial level and its traps).

---

## The level in one paragraph

Cross the sea and reach the next painting. **One journey with one fork, not three problems
with three answers**: the shore, where the new brush is found and the ink rule it brings is
taught → the fork, boat or dive → the bakunawa, which both routes reach and which has three
resolutions → the island, the next painting, and Lolo's farewell. It is shorter in branch
count than Piyesta and longer in each branch, which is the change of rhythm after a
puzzle-dense level.

---

## What this level changes about the whole game

Four things, and none of them is level-local. This is why Level 3 is not simply the next
level.

| Change | Today | From Level 3 |
|---|---|---|
| **The transformation clock** | `MorphLife`, 10 s, "a drawing is a burst spent on one obstacle" | No timer at all. A transformation ends when the player reverts or the ink runs out |
| **Ink** | Six units, one per thing, spent at the moment of drawing (FR-7) | Six units, one per thing, **plus a continuous drain while transformed**, refilled from sources placed in the level |
| **Combat** | None anywhere in the game | The bakunawa's Protector resolution is the first fight |
| **The flowers** | One per level, counted for the Masterpiece ending, invisible to the player | A visible, diegetic count — the flowers are what the last two levels are collecting |

⚠ **The ink change contradicts the manuscript, deliberately, and the manuscript has to
move.** FR-7 prices ink per thing and says nothing about drain; §4.5.4 states the budget "is
unchanged throughout". The build has been here before — tools are one-use against FR-7's
"reusable", by Kent's decision — and the rule recorded then applies again: **fix the
documents, do not put the old rule back in the game.** Nothing is built here until that is
acknowledged, because the ink economy is the one system in the game that can strand a player.

⚠ **The drain must not reach Levels 1 and 2.** The new brush is found on this shore, and the
design says it governs the rules "from here to the end of the game" — so Payyo and Piyesta
keep the ten-second timer, and a player replaying them must not suddenly be draining. That is
a profile flag (`NEW_BRUSH`) read by the level, not a change to `InkManager`'s constants.

---

## What already exists

Measured off the repo, not remembered. This is the half of Level 3 that is not new work.

| The level needs | What exists | State |
|---|---|---|
| Aquatic actors | `fish`, `shark`, `octopus` (swimmer rigs), `crab`, `sea_turtle` (walker), `penguin` (biped), `frog` (hopper) | In the 50-class roster. **No retraining needed for any class this level uses** |
| Water | `water_area_2d.gd` — buoyancy 2.4, linear/angular drag, wading, a paddy variant; `fish_controller.gd` medium-aware propulsion; `required_medium` on every entity (`water` for fish/shark/octopus/sailboat/submarine) | Built and tested (`run_water_audit`, `run_underwater_appearance_probe`) — but for a **pool inside a land level**, not for a level that is water |
| The `swim` tag | Declared in `tools/build_tags.py`, **deliberately empty**, unlock level 3 | Populating it is the first data task |
| The `light` tag | Declared, **empty**, unlock level **4** | The flashlight resolution needs it at 3 — see decision 2 |
| The `strike` tag | `boomerang`, `axe`, `sword`, `anvil`, `cannon` | Already populated, by Level 2, *for* Level 3. The fight's weapons are exactly this list |
| A boat | `sailboat` and `submarine` are placeable classes with `required_medium: water` | The design says the boat is **found, not drawn**, so these are alternatives rather than the route |
| Beats, routes, checkpoints, hints, objective banner and marker | `level_base.gd` + `level_director.gd` + `level_0N.json` | Generic. Level 2 proved the base carries a second level |
| Screen-sized set pieces | `DanceOverlay`, `AssemblyOverlay`, `DialogueChoiceOverlay` | The pattern the stealth and fight HUDs follow |
| The flowers | `HiddenFlower2D`, `PlayerProfile.FLOWER_IDS`, `flower_count()`, both flowers listed in the bag | Fixed on the way into this level: the key used to count as a flower, and Level 2's flower was never shown |
| Per-class recall for every class here | `model/metrics.json` | Checked below |

### Recall, checked (BR-7: no critical-path obstacle may depend on a class under 0.70)

Held-out Quick, Draw! test split, 4,000 drawings per class:

| class | recall | | class | recall |
|---|---|---|---|---|
| `sailboat` | 0.954 | | `sword` | 0.922 |
| `boomerang` | 0.919 | | `axe` | 0.916 |
| `penguin` | 0.915 | | `octopus` | **0.914** |
| `fish` | 0.901 | | `flashlight` | **0.887** |
| `anvil` | 0.885 | | `submarine` | 0.850 |
| `shark` | 0.843 | | `sea_turtle` | 0.811 |
| `cannon` | 0.793 | | `crab` | 0.770 |
| `frog` | **0.576** | | | |

**`flashlight` (0.887) and `octopus` (0.914) both clear the bar** — the design's two named
worries are fine. **`frog` does not**, at 0.576, the worst class in the roster. The design
lists frog among the seven aquatic actors; that is safe *only* as one of seven, and the level
must never put frog anywhere that it is the answer. The dive gate resolves the whole `swim`
tag, so a player whose frog is misread has six other bodies.

---

## What has to be built

In dependency order. The first three are systems the rest of the level stands on, and the
design is right that they are easy to underestimate.

1. **The ink drain.** `InkManager` is already float-based with `add_ink()` for refills, so the
   drain is a per-frame charge while a morph is held, a 20 % pulse, and a zero case. The zero
   case is the design's own decision and is not optional: **revert, carry the apo to the
   surface or the nearest air pocket, lose the crossing, never die.** No death state exists
   anywhere in this game and none is being added.
2. **Swimming as a movement mode**, not a pool to fall into. Seven classes need buoyancy,
   drag and stroke tuning; `run_morph_reach_probe`'s land numbers say nothing about any of it,
   and the template's own rule is *measure the new mechanic before costing anything out*.
3. **The underwater restriction**, which is `required_medium` plus the refusal the design
   asks for: a land creature flounders for a beat, Lolo reacts, and it reverts — rather than
   a silent refusal at the canvas.
4. **The shore**: the new brush, and a practice moment that teaches the drain before the fork.
   A tutorial beat with no fail state, in Payyo's Beat 0 shape.
5. **The fork**, two routes, tracked like every other fork.
6. **The boat route**: traversal, the rowing scene, the lore that lands while the player
   cannot draw their way out of it.
7. **The dive route**: the coral field, eight to twelve one-line fun facts with no counter and
   no gate, and the refills that keep curiosity free.
8. **The bakunawa**, three resolutions in two stagings — the most expensive single item in the
   level:
   - **flashlight** → it follows the light, finds what it lost, gives the flower;
   - **avoid** → light cones and shadow, with a checkpoint partway through so a reset costs
     the stretch and not the approach;
   - **fight** → apo health, dodge timing, drawn weapons from `strike`, subdued and never
     killed, losing restarts the fight.
9. **The island**: the painting, then the farewell, in that order, and the level ends there.
10. **The flowers made visible** between levels, and `L3`'s flower id added to `FLOWER_IDS`.

---

## Open decisions

The design marks five things open (red). Two of them I have now answered from the repo; the
other three, and two more the repo raised, are Kent's.

**1. What the archetype tally drives, and how a two-option fork scores.** *(design, open)*
The build already answers the first half: `EndingResolver` gates on a **threshold count** —
`ROUTE_COMMITMENT = 3` on one route — and `LevelDirector.commit_route` increments the count
**once per fork**, not once per level. So the design's worry is real and is worse than it
looks: Level 1 has three forks and Level 2 has three, Level 3 as designed has two, and a
half-point cannot be added to an integer tally that is compared against 3.

**2. Level 1 already has a flower, and it is not an artist reward.** *(design, open —
answered)* `level_01.json` puts Hidden Flower 1 in the gorge cave behind a `light` gate, with
`gate_unlocked_at_level: 4`: it is a **backtracking** reward, deliberately not a fail state.
The design's rule is that each level's flower comes from its artist-tagged resolution. Both
cannot be true of Level 1. And if the flashlight arrives in Level 3, `light` should unlock at
3, which brings Payyo's flower forward a level.

**3. Tag membership for `swim`, and for `light`.** `swim` takes the seven aquatic classes.
`light` is the problem: the artist resolution is a flashlight, and a tag needs **two** answers
after exclusions or it is a spelling test. The candidates in the roster are `flashlight`,
`campfire` and `sun`, and two of those are strange underwater.

**4. Level 2 currently ends the run.** `levels.json` has `ends_run: true` on `level_2`,
because the last built level is the one that reaches the ending screen. That flag moves to
Level 3 when Level 3 ships, and Piyesta's exit stops being an ending.

**5. Payyo's Protector debt.** `LEVEL_TEMPLATE.md` records it: Level 1's Node 3 Protector
route creases the canvas and the crease now costs nothing mechanical, "to be paid back when
Level 3 is designed". Dagat is the first level since where a crease could reach something
real.

**6. The numbers.** Drain rate per class, starting capacity, refill size and count per route.
The design says these come out of playtesting, and that is right — but they need defaults to
play at all, and the dive route needs more refills than the boat route because it is
transformed from start to finish.

---

## Build order

Straight from `LEVEL_TEMPLATE.md`, with this level's specifics.

1. This document. ✔
2. **Measure the new mechanics** — swim speed and reach per class, and what a drain rate makes
   a crossing cost. Every number downstream depends on it.
3. Populate `swim` (and `light`, once decided) in `tools/build_tags.py`, regenerate,
   `--check`, and confirm no obstacle drops under two answers after exclusions.
4. Art: `level-3-assets/` → `game/assets/Level3/`. Level 3 shares almost nothing with Level
   2's set — sea, shore, coral field, the bakunawa in two stagings.
5. `level_03.json` against the schema, with `load_time_assertions`.
6. `dialogue_l3.json`, then grep it against all 50 class ids and display names. **This level's
   vocabulary is dangerous**: fish, shark, octopus, crab, key words like *bangka* are fine but
   *isda* is not, and the lore scenes are the longest writing in the game so far.
7. Geometry, measured against R1–R10 — and note that **R10 is about `MorphLife`'s window,
   which this level does not have**. Reach here is bounded by ink, not by seconds, so the rule
   needs restating for Dagat rather than copying.
8. Port the two tests that catch a level that is secretly not a level, early:
   `run_nodraw_level3.gd` (T1 — the level cannot be finished without drawing) and
   `run_level3_audit.gd` (T3 — the data).
9. `levels.json` `scene_path` **last**, and `ends_run` moves off Level 2 in the same commit.
10. Look at the frames.

---

## What this document does not cover

- **The bakunawa's fight design past the design document's own outline.** Health, dodge
  window, weapon behaviour and what "subdued" looks like are a design pass of their own.
- **Art.** The design's asset list is long and nothing on it exists. Until it does, the level
  is built with code-drawn placeholders the way Payyo's props were, and `ART_PLACEHOLDERS.md`
  is where each one's contract goes.
- **Levels 4 and 5.** The farewell removes Lolo, and the design is explicit that Level 4 has
  to carry its own signposting with nobody to explain anything. That is a Level 4 problem, but
  it is created here.
