# Task: Scale and de-risk the active-ragdoll animation, and complete the ConceptNet ability layer, across the full 50-class roster

## Context (read first)

OBRA morphs a player's freehand drawing into a controllable entity. Animation is **not**
sprite/frame based and **not** kinematic vector-deformation. The real pipeline is an
**active ragdoll built from the player's actual ink**:

- `game/scripts/runtime_rig_2d.gd` (`RuntimeRig2D`, ~2.8k lines) resamples the drawn
  strokes, segments them into limb chunks, spawns an `ActiveRigBody2D` (RigidBody2D +
  collision) per chunk, links adjacent chunks with `PinJoint2D`, and drives the joints with
  PD-"muscle" torque toward a gait. No template limbs — the skeleton comes from the ink.
- Per-entity tuning lives in `game/config/rigs/*.json` (see `bird.json`: `rig_type`,
  `move_speed`, `joint_spring`, `joint_torque_limit`, `target_size`, gait params, etc.).
- `game/config/entities.json` is the source of truth: each entity has an `id`,
  `quickdraw_label`, `rig_profile`, and `runtime_role`
  (`active_ragdoll_morph` | `physics_morph` | `utility`).
- There is already a **tiered fallback**: species-specific gait → **generic gait keyed on
  `rig_type` only** (`runtime_rig_2d.gd` ~line 1092, `match _rig_type`) → compound body
  (ink diverged) → bitmap fallback. The spider has a bespoke stance solver
  (`spider_rig_analyzer.gd`, ~1.3k lines).

## The problem to fix

1. **The manifest is stale and tiny.** `entities.json` enables only **19** entities, and they
   are the OLD roster: `humanoid (yoga)`, `cat`, `dog`, `rabbit` are present but are **not**
   in the finalized 50-class vocabulary, while ~40 real classes are **missing** entirely.
2. **The animation does not scale as built.** Each creature currently leans on a hand-tuned
   rig profile, and the one fully "hero" creature (spider) needed a 1.3k-line bespoke solver.
   Reaching the thesis's **20 creatures** this way is not feasible in the time available.
3. **No coverage guarantee.** There is no test proving that every enabled entity spawns,
   rigs, and moves without flailing or erroring.
4. **The ability layer is missing entirely.** The manifest has no `ability` field and there is
   no ability table anywhere in the repo — only `movement_type` / `rig_type`, which describe
   *locomotion*, not the gameplay *ability*. The ConceptNet-grounded ability attribution that
   the thesis (Sections 3.2.5 and 4.2.7) treats as its core contribution — e.g. bird → flight,
   key → unlock — is not represented in the code at all.

The goal is **not** to remove the active-ragdoll system — it is the thesis contribution and it
works. The goal is to make it **cover the whole roster reliably** by leaning on the existing
generic `rig_type` gait as the default tier, reserving bespoke solvers for a few hero classes.

## Target roster (from the thesis, 50 classes)

- **Creatures (20, `active_ragdoll_morph`):** bird, bat, butterfly, spider, monkey, frog,
  fish, shark, octopus, crab, horse, elephant, snake, sea turtle, snail, ant, bee, pig,
  penguin, scorpion.
- **Primitives (3, `physics_morph`):** circle, square, triangle.
- **Objects (27):** axe, sword, cannon, boomerang, flashlight, campfire, cloud, sun, fan,
  ladder, stairs, parachute, hot air balloon, bridge, sailboat, submarine, key, door, rake,
  scissors, clock, anvil, bucket, umbrella, tree, mushroom, wheel.

## Tasks

1. **Confirm the archetype set.** In `runtime_rig_2d.gd`, read the `match _rig_type` generic
   gait block (~line 1097) and list every supported `rig_type` (e.g. `flier`, `walker`,
   `biped`, `hopper`, `arachnid`, `none`, and any others actually implemented). Do not invent
   `rig_type`s that have no gait code.

2. **Reconcile `entities.json` to the 50-class roster.** Remove `humanoid`, `cat`, `dog`,
   `rabbit`. Add every missing class with a correct `id`, `quickdraw_label` (verify the exact
   Quick, Draw! category string), `runtime_role`, and `rig_profile`. Keep the manifest schema
   and validation (`shared/entities.py`, `game/scripts/entity_registry.gd`) passing.

3. **Assign each creature to an existing archetype `rig_type`,** so it animates through the
   generic gait **without** a bespoke solver. Propose a mapping (creature → rig_type) and put
   it in the PR description; prefer reusing `flier` / `walker` / `hopper` / `arachnid` etc.
   Only keep/add a bespoke solver for at most **two hero creatures** (spider already exists;
   pick one more only if the generic gait is clearly inadequate).

4. **Create rig profiles for the new creatures** in `game/config/rigs/` by copying the nearest
   existing profile and tuning only the essentials (`target_size`, `move_speed`, joint
   stiffness/torque, gait amplitudes). Do not duplicate the full spider solver.

5. **Decide object runtime roles with a human.** `AGENTS.md` currently says only *six* utility
   classes exist, but the roster has 27 objects. Do **not** guess. Add a
   `# DECISION NEEDED` comment listing each object and a proposed `runtime_role`
   (`utility` vs `physics_morph`) for the team to confirm before finalizing.

6. **Attribute a ConceptNet-grounded ability to every class (the thesis's core contribution —
   currently absent from the code).** For each of the 50 classes, resolve and record a
   documented ability, matching the in-game function already specified in the design docs
   (`50 Classes.pdf` / `Game Design.pdf`):
   - **Creatures (20):** take the ability from the highest-weight **CapableOf** assertion for
     that concept in ConceptNet (English subset) — e.g. bird → fly, frog → leap.
   - **Objects (27):** from the highest-weight **UsedFor** assertion — e.g. key → unlock,
     ladder → climb, axe → chop.
   - **Primitives (3):** hand-authored abilities (roll, weight, wedge), explicitly flagged as
     hand-authored, since no commonsense relation supplies them.
   For each entity store four things so the grounding is inspectable and traceable — this
   provenance *is* the thesis claim: the ability term, the source relation
   (`CapableOf` / `UsedFor` / `hand_authored`), the exact ConceptNet assertion, and its edge
   weight. Resolution must be **offline and static**: build the table once from ConceptNet
   dumps or the REST API and commit it; do **not** query ConceptNet at runtime — the game
   consults the static table only.
   - `# DECISION NEEDED`: choose where the table lives — either new fields on each entity in
     `entities.json` (`ability`, `ability_relation`, `ability_assertion`, `ability_weight`) or a
     separate `game/config/abilities.json` keyed by entity `id`. Then extend the manifest
     validation (`shared/entities.py`, `game/scripts/entity_registry.gd`) to require and check
     the ability fields, and wire whichever form the backend/registry already consumes.

7. **Add a per-archetype coverage test.** Extend the headless physics test
   (`godot --headless --path game --script res://tests/run_tests.gd`) so that, for every
   enabled entity, it: builds the rig from a representative stroke fixture, steps physics for
   N frames, and asserts (a) no error/warning, (b) the ink-integrity audit passes, (c) the
   body stays within world bounds and does not exceed a max angular velocity (a flailing
   guard). Report results **grouped by `rig_type` archetype**, not per entity, matching the
   thesis's per-archetype evaluation plan.

## Hard constraints (do not break)

- **Ink integrity contract:** every rendered polyline must remain an exact contiguous slice of
  the player's strokes; keep the diverged-rig → compound-body demotion.
- **No template limbs:** keep deriving the skeleton from the ink.
- **Do not modify** the working spider solver except to fit the archetype interface.
- **Model contract:** after changing enabled entities or `quickdraw_label`s, `model/labels.json`
  must match the manifest order exactly — note in the PR that the model must be
  retrained/exported (`python3 model/train_quickdraw.py`) and flag if labels drift.
- Keep behavior **data-driven** (rig profiles/JSON), per the existing convention in `AGENTS.md`.

## Acceptance criteria

- `entities.json` lists exactly the 50 roster classes with valid roles and profiles; the four
  old-roster creatures are gone.
- Every creature maps to an implemented `rig_type`; at most two bespoke solvers exist.
- Every enabled entity carries an ability with its source relation, ConceptNet assertion, and
  edge weight recorded (hand-authored + flagged for the three primitives); the ability layer is
  populated for all 50 classes and validated on load.
- The headless test passes for **all** enabled entities and prints a per-archetype summary.
- `python3 -m unittest -v tests.test_manifest_contract` passes (update the expected 20/3/27
  counts if that test hard-codes the old numbers).
- No change to the ink-integrity or no-template-limb behavior.

## Out of scope

- Do not rewrite the ragdoll as kinematic animation.
- Do not build art/levels or touch the backend model architecture.
- Do not finalize object `runtime_role`s, or the ability-table location, without the
  `# DECISION NEEDED` sign-off.
- Do not add runtime ConceptNet calls — the ability table is resolved offline and committed.
