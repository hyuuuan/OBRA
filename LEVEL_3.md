# Level 3 — Dagat

**Status: CONTENT COMPLETE AND PAINTED.** The delivered art is in — three parallax bands,
animated coral, kelp, bubbles and fish, and the bakunawa in 23 poses. `tools/build_dagat.py`
cuts the delivery and **fails if any of the 79 files is unused**; `tools/build_dagat_props.py`
authors the one prop the delivery has in the picture but not as a file (the seabed ink jar).
Six things are still a developer's rectangles and they are listed in `ART_PLACEHOLDERS.md`.

*(Previous status, kept for the record: content complete with placeholder art.)* The shore, the fork, both crossings **and
both of their lore scenes**, the encounter in all three resolutions **in both stagings**, the
coral field, the island and the farewell are in.
`levels.json` carries `scene_path` and `ends_run`, so Dagat is the level the run now ends on
and the hub opens it. **Nothing on the design's asset list exists** — every prop, the creature
and the sea are code-drawn, and `ART_PLACEHOLDERS.md` is where each contract goes.

**Green:** `run_level3_audit.gd` (T3, 27 checks) · `run_nodraw_level3.gd` (T1) ·
`run_bakunawa_probe.gd` (all three resolutions) · `run_level3_finish_probe.gd` (both
crossings, to completion) · `run_swim_reach_probe.gd` · **`run_level3_boat_probe.gd` (the
bangka, actually sailed)**. All six are in `tools/run_suites.sh`. See "The playable pass"
below for what the 2026-09-22 pass changed and why.

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
| **The encounter** | `bakunawa_2d.gd` — `apply_tool_hit`, a drawn sweep, a channel body | Three resolutions, one creature. Subdued never killed; losing costs the stretch, not the run |
| **The coral field** | Ten facts on proximity, all non-drawable creatures, two about lola | No counter, no gate, no ink |
| **The island** | Scripted arrival, the painting, then the farewell, `lolo_present` false | The half of the lore they have not heard lands here |
| **Shipped** | `levels.json` `scene_path` + `ends_run`, and five assertions turned over | The dead card is `level_4`'s now |
| **The crossings** | Boat: 5 beats through the DialogueBox, then the shadow · Dive: 4 through the HintBar | The boat stops the world; the dive does not. That contrast is what the fork is for |
| **Both stagings** | `Bakunawa2D.stage_at()` — surface for the boat, depth for the dive | One creature moved, not two kept in step |

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
4. **The lore was in neither crossing, and the flags covered for it.**
   `heard_how_he_died` / `heard_about_lola` were set the moment the fork was answered, and
   the island skips whichever half is flagged — so the heart of the level was missing on both
   routes with every suite green, because the probe accepted the flag as evidence. **A flag
   is not evidence that a line landed.**
5. **Every pickup tested `is_in_group` on the colliding body.** `player_character` is on the
   morph's *root*, and what enters an `Area2D` is a rig segment. The seabed refills sit where
   the player is always a morph, so they could never have been taken — and the only symptom
   would have been a crossing that ran out of ink for no visible reason. Walk the parent
   chain, as `DialogueNode2D` has since Level 1.
6. **`DialogueNode2D` anchors its box upward from its position**, unlike `LevelObstacle2D`
   and `CheckpointArea2D`, which centre theirs. The encounter's fork covered −190…1060 and a
   diver swam under it without being asked anything.

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

**5. Art — six props, not a level.** The bands, the creature, the coral field and the
ambience are painted. What is left is the brush, the beached and launched bangka, the
treasure the creature uncovers, the next painting, and Lolo's farewell pose — all listed with
their sizes and what each has to say in `ART_PLACEHOLDERS.md`.

⚠ **Six things about the backdrops that will bite whoever touches them next** — every one of
them was a bug first, and `dagat_backdrop_2d.gd` carries the reasoning beside each:

- **Each band is pinned by a derived edge**, read off the art: the shore by its sand line at
  plate-y 790; **the storm by its FRONT wave at 664, not its horizon** (at 421 the boat sailed
  along the skyline); the deep by **two** edges — its water at the surface, its floor layers
  dropped by `floor_drop` 360 so the seabed lands at **1709**.
- **Parallax is horizontal only, and measured from a fixed point in the world**, never from
  "where the camera was at the last transformation" — `set_target` resyncs every layer on
  each morph, and the sky used to jump.
- **Edge scenery is placed once, not tiled.** Palms, the jetty headland and the far island are
  single clumps drawn at a plate's edge; tiled and mirrored they stood on every screen, which
  is most of what made the world look crammed. Rows are `pieces` (a crop at a landmark) or
  `ground` (sand, only where there is land).
- **`z` is absolute across all three bands** (table above `BANDS`). Numbered per band, the
  deep's ruins drew over the storm and the frame read as three paintings shuffled together.
- **Animation groups carry an `origin` on the plate** and must be drawn there; the waves were
  48 px high until they were.
- **A band's alpha is per child**, so two children that overlap by even one row draw that row
  darker — a hairline across the whole crossing. Butt them edge to edge.

---

## The playable pass (2026-09-22)

Kent: *"the world is too close to each other, it's so weird"* — and make it playable, no bugs.
Both turned out to be several separate faults. In the order they were found:

**The world, spread out.**
- **The camera anchored to the seabed.** A level's camera pins itself near the bottom of its
  world; Dagat's bottom is 800 px under the beach, so the level opened on the ruins with the
  apo off the top of the screen. `LevelBase._camera_follows_height()` — Dagat answers true.
- **The sea is 360 px deeper** (seabed 1709) so the surface, the open water and the ruins are
  three places, not one picture. `level_3.gd`'s `BED_Y`, the Seabed collision and the painted
  floor must agree; `run_level3_audit` "one seabed" fails if they do not, and checks the
  refills and the treasure are ON the bed (they floated 60–200 px up; the treasure was inside
  the rock).
- **The land goes down to the seabed.** The shore was a 240-deep slab over an air pocket a
  diver could fall into and not leave. Solid to the bottom now, drawn with authored rock
  (`build_dagat_props.py`: `shelf_fill`, `shelf_face`, palette read off the plates).
- **The island is painted** (the shore band's second ground, mirrored), not a tan box.
- **The storm breaks when the encounter is resolved**, and the deep and the island take a
  night tint while it is up. `DagatBackdrop2D.clear_the_sky()`.

**The boat route, which no probe had ever sailed.** Every probe crossed by teleporting the apo
along the sea; `run_level3_boat_probe.gd` now sails it. Four faults, all green before:
1. **It crawled** — 240 px/s reported, 14 moved. `DepthLayer2D.update_for_camera` re-set the
   gameplay plane's (unchanged) position every camera move, which snaps every rigid body under
   it back to its node's stale transform. **A global fix**: assign only on change.
2. **It sank** ~12 px/s until the passenger drowned and the rescue's checkpoint restore took
   the boat away. A sailboat now rides a spring at `HULL_DRAFT` under `WaterArea2D.surface_y()`.
3. **It could not reach the island** — it kept the physics script's 3760 px world and was
   clamped at x 3940. The launched boat gets the level's bounds.
4. **Arrival could not see it** (the volume started at the waterline; a passenger sits 40 px
   above it), and **landing lasted one frame** (the hull re-seats its passenger).

**And:** the bakunawa's coils were a fixed 1200 tall around the creature, so deepening the sea
reopened a 350 px gap over them — the exact bug the 1200 was chosen to close. `seal_span`
fits them to the column wherever it is staged. The encounter's signposts hung in open water
(and one inside the seabed); `sign_reach` / `sign_offset` stand them on the bed.
`tools/run_suites.sh` did not run any Level 3 suite; it runs all six now.

**6. Payyo's Protector debt.** `LEVEL_TEMPLATE.md` records it: Level 1's Node 3 Protector
route creases the canvas and the crease costs nothing mechanical, "to be paid back when Level
3 is designed". Dagat is the first level since where a crease could reach something real.

**7. The numbers — tuned, and now a playtesting question rather than an open one.** The seven
differ on two axes that pull against each other: `swim_speed` in the rig profiles and the
per-class rate in `ink_economy`. **589–956 px/ink, a 1.62× spread** (was 1.11×), with the
inversion the design wanted — the sea turtle is slowest and goes furthest on a tank, the shark
fastest and nearly shortest. `fish` keeps the 260 baseline so nothing else had to be re-read
against a moved reference.

**The level charges on two axes**: distance up to the encounter, **time inside it** (a sweep
of the creature's cone is 7.6 s and has to be waited out). Three of the six refills sit in the
arena for that reason. `run_swim_reach_probe.gd` reads the level's own economy and fails on
either axis — both guards verified by breaking them on purpose. What is left is playtest feel,
not arithmetic.

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
