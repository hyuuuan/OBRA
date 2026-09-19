# Level 3 — Dagat

**Status: SYSTEMS BUILT, LEVEL NOT BUILT.** The three things Dagat needs before any of its
content can exist are in and measured — the ink drain, swimming, and the underwater
restriction — and the tag layer now answers both of its forks. There is still no scene, no
`level_03.json`, no dialogue file and no art, and `levels.json` still carries `level_3` as
**Coming Soon** with an empty `scene_path`, which is what five tests assert and what keeps the
hub from offering a card with nothing behind it.

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

## What is built, and what it measured

Systems first, per the build plan. Each landed with its own commit; the reasoning is in the
commit bodies rather than repeated here.

| Built | Where | Note |
|---|---|---|
| **The ink drain** | `InkManager.drain()` + an emptied latch · `InkDrain` (rules only, no view) · `MorphCard.set_meter_caption()` | The latch matters: both existing charges announced exhaustion unlatched, which is harmless by the event and fires sixty times a second by the frame |
| **Three `LevelBase` virtuals** | `_morph_has_a_life()` · `_on_ink_emptied()` · `_rescues_a_swimming_apo()` | All default to today's behaviour, so Payyo and Piyesta are untouched. **The answer is the LEVEL's, not the brush's** |
| **Swimming for seven classes** | `can_swim` on `crab`/`penguin`/`frog` · `_drive_fish` reads seven numbers from the rig profile | Every fallback is the literal that was hard-coded, so a class naming no keys swims exactly as before |
| **The underwater restriction** | `LevelRestrictions.aquatic_only` — `flounders()`, `check_medium()`, `flounder_note()` | A **consequence**, not a ban: the design wants a land creature to flounder and be reverted, not to be refused at the canvas |
| **`swim` and `light`** | `tools/build_tags.py` → `LEVEL_3_TAGS` | Unhintable drops 11 → 7. `light` moved 4 → 3, which brings Payyo's flower forward |
| **Four profile fields** | `new_brush` · `lolo_present` · `l3_bakunawa` · `L3_HF` in `FLOWER_IDS` and in the bag | Additive, no schema bump |
| **The data layer** | `level_03.json` · `dialogue_l3.json` (27 lines, none naming a class) · `tutorial.json` level_3 (6 lessons) | `levels.json` deliberately untouched — `scene_path` goes last |
| **The scene** | `level_3.tscn` · `level_3_environment.tscn` · `level_3.gd` | Shore, ~2,400 px of open water, the encounter, the island. Code-drawn placeholders |
| **The shore** | The new brush as a pickup · the practice beat at the waterline · CP1 | The brush is not an obstacle: a sub-beat resolves a tag, and picking something up is not a drawing |
| **The fork** | Beached bangka → a real `sailboat` · `swim` on the dive · three seabed refills | The boat is **found**, closed with `solve_with_item`, and it sails — a found boat that could not be sailed would answer the fork and strand the player |
| **T3 and T1** | `run_level3_audit.gd` (24 checks) · `run_nodraw_level3.gd` | Both green |

### Three things the tests caught that reasoning had not

1. **Switching the drowning rescue off stranded the apo.** The plan added a
   `_rescues_a_swimming_apo()` opt-out on the argument that rescuing in a level that *is* the
   sea would loop. It cannot loop — the rescue tests `player is Wanderer` and a morph is not
   one — so it only ever fires when the player has no body, which is exactly when they need
   it. With it off, walking off the shore sank the apo toward a seabed a thousand pixels
   down, inside the world bounds, so the fall limit never caught it either. Replaced by
   `_drowning_words()`: a sea level needs its own words, not an exemption.
2. **Dagat could be crossed with nothing drawn, and T1 was green throughout.** Two routes are
   `answered_by` and an obstacle volume is a trigger rather than a wall, so a player could
   walk past the practice beat, take the boat and sail. The walking bot never lingered near
   the hull long enough to press E — a pass by luck. Fixed where the design already put it:
   `LevelBase._dialogue_node_is_ready()` and `DialogueNode2D.rearm()`, so **the shore beat
   gates the fork.**
3. **The boat was parented to `EntityRoot`.** `_nearest_interactable_utility` skips anything
   whose parent is not `world_item_root`, so it floated, looked right, and could not be
   boarded.

### Measured (`run_swim_reach_probe.gd`, `run_behaviour_audit.gd`)

- **All seven swim.** Four of them carry land rigs and reach the water only through
  `can_swim`, so this was the thing in doubt. All four keep their land drive too.
- **All seven swim the same.** 685–762 px per unit of ink, a **1.11× spread**, against the
  3.8× spread the land probe found. `swim_speed` falls back to the same 260 for everybody —
  correct for a change that must not retune Payyo, but it means the design's "a fish costs
  less to hold than a shark" is currently **not true**, and the only lever that can make it
  true today is `InkDrain`'s per-class rate table.
- **The working number for `level_03.json`: ≈3,600 px of crossing** on the usable budget at
  the default 0.2 units/s, for any of the seven.
- **R10 does not survive this level** and `LEVEL_TEMPLATE.md` now carries **R10a**: where
  there is no clock, reach is measured in ink, and the slowest answer stops being the same
  class as the most expensive one.

---

## Decisions — settled, and still open

Four of the design's five red items are now decided (Kent, this pass). The reasoning that
produced each is in the build plan; what it means for the build is here.

### Settled

**1. The two-option fork scores as one integer point. Boat = `artist`, dive = `pragmatist`.**
The design wanted the dive split 0.5 pragmatic / 0.5 protector. It cannot be: `route_counts`
is an integer dictionary, `EndingResolver` compares it against `ROUTE_COMMITMENT = 3`, and
`LevelDirector.commit_route` increments **once per fork**. Making it a float would touch
`_merge_defaults`' int coercion, the resolver, the ending screen and the profile suite — for a
half-point that an integer threshold has to round anyway. **Protector's expression in Dagat is
the fight**, which is where the design says it should cost something.

**2. `light` unlocks at 3, with three members** — `flashlight` (the only one ConceptNet
grounds as `light`), `sun` and `campfire`. A tag cannot be declared in the level that uses it
and unlocked in the one after. This brings Payyo's gorge-cave flower forward a level, which
the design wants anyway. `level_01.json`'s `gate_unlocked_at_level` now reads 3 — nothing
reads that field, the real gate is `ConceptGate2D` asking whether the player owns one, but it
was documentation that had gone stale.

**3. `swim` takes the seven the design names.** Measured, not assumed — see above. `frog` is
in at 0.576 recall, which is under BR-7's floor and is safe **only** because six other bodies
answer the same gate. **No obstacle may ever ask for it by name.**

**4. The fight is in-world, with the real drawn weapons.** The five `strike` classes already
have differentiated behaviour and reach in `UtilityObject` — swing 96 px, boomerang 320,
cannon 640, anvil drop — which is exactly the differentiation the design asks for, and
`Destructible2D` already has health and a `damaged` signal. **No apo health system is
invented**: contact costs a strike, three strikes restarts from the mid-encounter checkpoint,
consistent with a game that has no death state.

### Still open

**5. The bakunawa, the coral field and the island are not built.** `L3_N2` has its volume,
its fork and its three routes in data, and nothing behind them: no creature, no light cones,
no fun-fact interactables, no flower in the world, no exit. The level currently ends in open
water. This is the largest remaining piece and it is what "the dive route playable end to
end" still needs.

**6. Level 2 currently ends the run.** `levels.json` has `ends_run: true` on `level_2`. It
moves to `level_3` **in the shipping commit**, and five tests turn over with it:
`run_level2_audit.gd:459`, `run_level2_finish_probe.gd:175`, `run_tests.gd:695` and `:760`,
`test_player_profile.gd:106`, `run_hub_audit.gd:78`. The dead card moves to `level_4`.

**7. Payyo's Protector debt.** `LEVEL_TEMPLATE.md` records it: Level 1's Node 3 Protector
route creases the canvas and the crease costs nothing mechanical, "to be paid back when Level
3 is designed". Dagat is the first level since where a crease could reach something real.

**8. The numbers.** Drain rate per class, starting capacity, refill size and count per route.
The design is right that these come out of playtesting — but the probe now says the seven are
indistinguishable at 685–762 px/ink, so **the per-class rate table is the only lever that can
make a shark cost more to hold than a fish**. The dive route needs more refills than the boat
route because it is transformed from start to finish.

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
