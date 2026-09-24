# Level 3 — Dagat

**Status: CONTENT COMPLETE AND PAINTED.** The delivered art is in — three parallax bands,
animated coral, kelp, bubbles and fish, and the bakunawa in 23 poses. `tools/build_dagat.py`
cuts the delivery and **fails if any of the 79 files is unused**; `tools/build_dagat_props.py`
authors what the delivery has in the picture but not as a file -- the seabed ink jar, the rock
the land stands on under the water, the small lives, and the bangka. **Three** things are still
a developer's rectangles and they are listed in `ART_PLACEHOLDERS.md`.

*(Previous status, kept for the record: content complete with placeholder art.)* The shore, the fork, both crossings **and
both of their lore scenes**, the encounter in all three resolutions **in both stagings**, the
coral field, the island and the farewell are in.
`levels.json` carries `scene_path` and `ends_run`, so Dagat is the level the run now ends on
and the hub opens it. **Nothing on the design's asset list exists** — every prop, the creature
and the sea are code-drawn, and `ART_PLACEHOLDERS.md` is where each contract goes.

**Green:** `run_level3_audit.gd` (T3, 27 checks) · `run_nodraw_level3.gd` (T1) ·
`run_bakunawa_probe.gd` (all three resolutions) · `run_level3_finish_probe.gd` (both
crossings, to completion) · `run_swim_reach_probe.gd` · **`run_level3_boat_probe.gd` (the
bangka, actually sailed)** · **`run_level3_trouble_probe.gd` (the three ways to lose)**. All
seven are in `tools/run_suites.sh`. See "The playable pass" and "The rendering pass" below for
what the 2026-09-22 and 2026-09-23 passes changed and why.

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

### Second pass (2026-09-22, later): life, an opening, and what breaks when things go wrong

**The sea moves.** `DagatLife2D` owns everything that moves and is not the player, because it
all asks the same two questions — where is the camera, and is it day or storm there
(`DagatBackdrop2D.weather_at`): gulls cross the daylight sky (and come back when the storm
breaks); jellyfish drift in the deep; surf breaks on both shores; in the storm, rain splashes
the sea and lightning flashes with the storm band flaring behind it; the bangka leaves a wake;
a swimmer breathes bubbles; the water churns where the bakunawa surfaces; glints mark what it
finds and where the painting waits. Palms lean in the wind (`shaders/wind_sway.gdshader`, a
whole-texel shear, harder in the storm) and the clouds drift. The coral field's four facts
about a jellyfish, a starfish, a clam and an urchin now have the animal there, and the fish
schools patrol. All the new art is authored in `build_dagat_props.py` (35 frames, `--check`).

**The opening.** Letterbox with the level's name, the camera out over the open sea, gulls
heading for the beach, then easing back to the apo. Nothing waits for it and nothing pauses:
any key ends it and still does what it was pressed for.

**What goes wrong on the way, found by doing it on purpose:**
- A restore to before the boat freed the launched bangka and never re-planted the beached
  one — a **soft lock** on the boat route. `_put_back_what_the_restore_undid()` fixes it, and
  also puts back ink jars the restore rolled back (it took their ink and left them gone).
- **E in open water stepped off the boat**, into deep water, into that restore. The bangka now
  keeps its passenger more than a hull's length from either shore
  (`UtilityObject.holds_passenger`), and the prompt stops offering GET OFF there.
- The rescue said "Back to CP2" in every level. `LevelBase._checkpoint_place()` names it;
  Dagat's are the beach, the edge of its waters, the middle of them, the island. And every
  stealth or fight reset raised a string-formatting error — only formatted now when there is
  a `%s` to fill.

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

## The rendering pass (2026-09-23)

Kent: *"the islands are cut off and then not properly rendering"* — and make the animations
smooth, and keep hunting bugs. Four separate things, and the first is the one anybody sees.

**The land was guillotined at the water.** `palms_left` tapers to nothing by its column 478
and is CUT at its column 0; `palms_right` starts from nothing at 690 and is CUT at 1672. Both
cuts were set down against open water, so each shore ended in a ruled vertical line from the
palm tops to the sand — the whole landmass chopped with a straight edge, which is exactly what
it looked like. **But the plate tiles: its column 1672 and its column 0 are the same rock.**
The head of one laid against the tail of the other rebuilds the clump and lets it taper into
the shallows the way the picture was painted to. The two rows now share one gust, because two
halves of one clump that sway at their own rates split apart at the join.

Three things follow from it, each its own commit:
- **The sand runs 64 past the land at the water end** (a NEGATIVE `seaward_trim`). What stands
  there is a rock at the point of the beach, and sand stopping on the collision edge left it
  over open sea.
- **The shelf face begins where the sand does** (`top_row` 790, not 941) and carries 51 rows
  of **lip** in the sand plate's own colours. It used to start 151 px under the walking
  surface, so the sand above it was still a ruled cut — under water and dark, but ruled. The
  lip is an EDGE, not a slab: opaque for fifteen columns behind its own ragged edge and
  dithered away inland, because at the face's full width it was a second, flatter sand laid
  over the plate's and the join was a straighter line than the one it was hiding.
- **The shelf goes BEHIND the palms** (−163/−162, not −150/−149). In front, the new sand lip
  was drawn over the rocks the clump ends the beach with, as a pale smear across them.

**Every band lands on the world's pixel grid.** Ten layers at ten parallax rates sit at ten
different sub-pixel offsets, and with nearest filtering a sub-pixel offset is not a soft half
pixel: it is a column of texels that jumps a whole pixel when the offset crosses a half. Each
layer crossing on its own schedule is the crawl in the sky over a sea that is holding still.

**The things that move.** The surf was two flat strips end to end at a fixed y — a dashed line
ruled along the waterline, and the eye finds the repeat before it finds the foam. Three now,
each lower and fainter than the one inshore of it, each on its own bob and sway, and reaching
as far as the rocks do. Gulls climb out of weather they were not sent into: the check that
keeps them off the storm is made where they are SENT, which is right and not enough, because a
bird flies for ten seconds across a world whose weather moves. And the sweep is a beam rather
than a grey triangle laid over the ruins — brightest at the head, falling off down its length,
on a slow swell — **with its edge unmoved**: same half angle, same reach, and a rim along both
sides, because a cone whose edge a player has to guess at is a rule learned by being put back.

**The bangka is painted**, and it is the one object in the game that is found rather than
drawn, so it is the one that could not get its picture from the player's ink. See
`ART_PLACEHOLDERS.md` — including the trap, which is that the outline is **not** under
`DrawingSkin`.

**The bug this pass found: a checkpoint you can be caught standing on.** A checkpoint records
where the PLAYER was, not where its node is. CP3b's volume is 220 wide and the snapshot is
taken wherever the apo crossed it, so on the stealth route the place a reset returns to is
regularly inside the creature's cone — measured at **384 px from a thing that sees 460**, with
two further resets in the ten seconds after, the player having done nothing at all. Not a soft
lock; they can swim out inside the 1.4 s grace. Still wrong, because the reason for a
mid-encounter checkpoint is that losing the stretch costs it ONCE. `_stand_them_clear_of_it`
answers the REACH rather than the geometry: moving the volume would not fix a player coming
back from the east and crossing at its far edge.

**And a probe that plays the level badly on purpose** — `run_level3_trouble_probe.gd`, in
`tools/run_suites.sh`. Every other probe here plays it correctly, which is the wrong half of
the work: a game with no death state can only fail by leaving the player somewhere they cannot
get out of, and none of those places are on the happy path. Three ways to lose, and the same
question about all three — afterwards, can they still play?

1. **The ink runs out on the seabed.** Reverting at the bottom of a thousand-pixel column
   leaves a body that cannot swim where it cannot leave, and the ink that would buy another is
   the ink that just ran out. The way back is the restore handing the spend back: measured at
   6.00 of 6 returned. If that ever stops, it is this level's first unwinnable state and
   nothing else in the suite would notice.
2. **Being seen.** Costs the stretch, leaves ink to swim back with, and does not quietly
   resolve the encounter by losing it.
3. **Three knocks.** Warned twice, thrown on the third, and the fight comes back fresh — a
   knock count that survived the restart would make the third loss permanent.

### The horizon, and what the bands were doing wrong (same day)

Kent again: *"the islands, the platforms are not rendering properly as well as the ocean and
the sky since its so weird like the horizon"*. Two more faults, both in how the bands were
being composited rather than in the art.

**There were two horizons, and they were 73 pixels apart.** The shore band's far layers are a
beach **seen from the front** — a horizon, a band of sea receding to it, breakers running up
sand. The storm band is the same sea **seen from the side**. The two plates do not even agree
on how far the horizon sits above the waterline: 157 rows on the shore's, 84 on the storm's.
The storm was cross-faded in over 1600..3000 and the shore band **never left at all**, so for
the whole first third of the crossing both were drawn: two horizons, two rows of distant land
(world 403 and 476), two sets of waves, and beach breakers running over three thousand pixels
of open sea.

It cannot be fixed with `fade_span`, because the island the crossing arrives at is the shore
band's own sand and palms, four thousand pixels into the storm. So the split is by LAYER, and
then the two things that were sharing one ramp get their own:

| | Stretch | What it is |
|---|---|---|
| `far_fade_span` (shore) / `fade_span` (storm) | **1000..1560** | A change of **viewpoint**. The side view replaces the front view where the player leaves the sand. Short, because a long cross-fade between two incompatible pictures IS the double horizon |
| `night_span` (all three) | **1600..3000** | The **light** going — the buildup the design asks for. `weather_at()` reads this one, so the rain, the lightning and the no-gulls rule keep the timing they were tuned with |

Three consequences, each its own commit: the storm band gains a **`day_tint`** so its sea —
painted for the end of the crossing — brightens back toward the light it now arrives in; its
**clouds, rain and flat sky lid** follow the night rather than the band, because drawn with the
band it poured on a bright sea one screen out from a sunny beach; and the shore's **sky** is
not part of its sea, so it stays over the open water and leaves as the thunderheads come in.

**And the bands were mirroring plates that were authored to tile.** Every second copy was
flipped, on the reasoning that a straight repeat would cut through the ruins. Nobody measured
it. The mean difference between a plate's last column and its first is **under 21 of 255
across all eleven tiled plates, and under 11 for the ruins and the ridges** — they repeat.
What mirroring actually did was pair each plate's most distinctive edge with its own
reflection, so the seabed carried a symmetrical butterfly of ruin arches every 3344 pixels,
which is what "the platforms are not rendering properly" was. `mirrored_tiles` now defaults
off and the measurement is written beside it.

### The land, and what was hanging off it (2026-09-24)

Kent: *"the islands below the ocean, the platform, how it is shown is so weird since there are
parts where they are not connected, like i can see that it is cropped and its not functioning
well. The platforms in islands are not that visible and weird to look at"*. The session that
took this dropped mid-pass, after five commits (the sweep drawn as added light, mirroring
chosen per plate by looking rather than measuring, the seabed at world rate, the headland
rebuilt as one island behind the waves, the storm's underwater fading into the deep) and with
a brighter beam uncommitted. This picks it up. A contact sheet of the level at play framing --
fourteen points along the surface, six on the seabed, three at mid-depth -- found seven things,
and four of them were pictures of land where the level has none.

**Palms and rock over open water at both ends of the crossing.** The last answer to the palm
plates' cut edges rebuilt the clump across the plate's border and set the rebuilt half out
past the collision edge -- 360 px at 1000..1360 and again at 4140..4500 -- cut flat along the
plate's last row with the sea under it. It is exactly what a player walks onto and falls
through. Each plate is now set down whole at the LANDWARD end of one beach (`palms_left` at the
home beach's west end, `palms_right` at the island's east end), cut sides past the camera's
limits (116, 5380), tapers toward the water. The sand stops on the collision edge instead of 64
px past it, so both beaches end on sand, which is where the edge of the land is drawn.

**The land under the water was a slab with spots on it, with five platforms floating beside
it.** The shelf was a smooth dither with round boulders and ruled strata; its face had five thin
lit ledges sticking out with weed hanging off them -- at game scale, five small platforms not
connected to anything. `build_dagat_props.py` now draws both the way the painted terraces are
built: blocks in irregular courses, a near-black crevice between every two, lit on the upper-left
rim, moss on the tops nearest the light, darker with depth, in colours sampled off the terraces'
cliff. The earth under the sand gives way to rock along block edges, not along a row. The face
keeps its ragged line and its sand lip; what stands out of it now is its own bulges, mossed on
top, and it feathers into the fill over its landward six columns so the two have no seam.

**A slab of the headland under the waves.** The waves hide what is behind them only down to
their front crest, whose lowest edge is plate row 652 in the shallowest frame. The headland's
rocks go down to 777, and lifted 70 their last 55 rows came out beneath the sea -- a detached
slab with the island standing above it, plainest in the opening shot. `storm/shores` carries
`sunk_row` 650 now: every piece is cut there before its lift. The headland's tail crop moves
from 1400 to 1470, past the ink buoy, half of which it had been carrying.

**The storm's underwater picture ended on a line.** Its last row still has kelp in it --
luminance up to 76 against a fill of about 15 -- so no fill colour could meet it. The fill's own
colour now comes in over the plate's last 140 rows, one z above the plate and under the deep's
floor.

**And the surf** was three strips running 430 px out from each shore, because the rocks used
to stand that far out. Against a sandy edge it read as a rope lying on the sea. One strip laps
the foot of the sand's slope.

**And both skies were tiling with a cut in them.** The day sky and the storm's clouds were left
straight on the reasoning that their joins could not be seen. Measured: 127 of the day sky's
rows differ by more than 30 of 255 across the join (a cloud runs off the plate's right edge and
is not waiting at its left -- on the first screen of the level), and the storm's bank is opaque
on one side of its join and empty on the other for 29 rows. Both drift, so the cut slid across
the sky. Both are mirrored now; the islands (0), the mountains (2) and the rain (0) stay
straight.

Checked and NOT a fault: on the tour's open-water frames the boat sits at the top of the screen
with the horizon cut off. That is the dialogue framing -- the camera on Lolo with the standard
240 lift (455 + 240 / 1.15 = 663) -- held because the tour hides lines rather than finishing the
conversation, so `conversation_finished` never releases it. Aboard and at rest the camera is
where it should be, 180 above the apo.

**What the waves hide showed through them whenever the storm was half there.** The band fades
as a whole and every child draws with that alpha on its own, so half-faded waves are
half-transparent waves: the buoy's post and sign ghosted into the farewell shot as the sky
cleared (the overhanging rock had been covering it by accident), and the headland hung
half-drawn over the cross-fade. The shores and the distant islands are `late` now -- the band's
alpha again on top of its own -- so they are faint while the waves are and whole once they are.

Left as it is, on purpose: the 1000..1560 cross-fade still double-exposes the two SEAS for the
two seconds a boat takes to cross it. That is what cross-fading two paintings does, and with the
islands arriving late it is only water over water.

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
