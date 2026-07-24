# DECISION NEEDED — object runtime roles & ability grounding

This file records two decisions the roster expansion made **provisionally**. They are
reversible and need team sign-off before being treated as final (per
`ANIMATION_ROSTER_FIX.md`, Tasks 5 & 6). Nothing below blocks the game from running or
the tests from passing — they are curation calls.

## 1. Object `runtime_role` split (provisional: all 27 objects → `utility`)

Per the session decision to **expand the utility set**, every one of the 27 objects is
currently assigned `runtime_role: "utility"` in `game/config/entities.json`. This gives
the clean 20 / 3 / 27 runtime-role split the thesis targets (20 creatures →
`active_ragdoll_morph`, 3 primitives → `physics_morph`, 27 objects → `utility`).

Key facts behind the call:
- The six-slot inventory holds up to six *instances*, not six *types* — so growing the
  set of distinct `utility_behavior` types beyond six needs no inventory changes.
- `utility_object.gd` / `physics_shape_object.gd` already have safe `_:` default branches,
  so the 21 new behaviors get **generic placement/pickup** behavior. The bespoke per-object
  gameplay from `50 Classes.pdf` (chop, unlock, freeze time, …) is **out of scope** here.

**Sign-off question:** keep all 27 as `utility`, or reclassify some as `physics_morph`
(a controllable physics body the player *becomes*, like the primitives)? Reasonable
candidates to flip, by In-Game Function:

| id | In-Game Function | provisional role | flip to physics_morph? |
|----|------------------|------------------|------------------------|
| wheel | Roll/Fix (rolls like a boulder) | utility | **strong candidate** — behaves like `circle` |
| anvil | Crush (drops straight down, heavy) | utility | candidate — a heavy falling body |
| mushroom | Bounce (trampoline) | utility | candidate — a springy body |
| cannon, boomerang, axe, sword, scissors, rake, key, door, clock, bucket, umbrella, flashlight, lantern-like (campfire/sun/cloud/fan), ladder, stairs, bridge, parachute, hot_air_balloon, sailboat, submarine, tree | tool / placed prop / vehicle | utility | keep utility |

To flip K objects, change their `runtime_role` to `physics_morph` (and drop
`utility_behavior`) in `entities.json`; the contract test counts by role, so update
`EXPECTED_ROLE_COUNTS` in `tests/test_manifest_contract.py` to `20 / (3+K) / (27-K)` and
the Godot `_test_manifest_roles` counters to match. `ALLOWED_UTILITY_BEHAVIORS` in
`shared/entities.py` can then drop the flipped ids.

## 2. Ability grounding vs. design In-Game Function

Abilities live in `game/config/abilities.json`, built by `tools/build_abilities.py`.
Creatures take the top **CapableOf** edge, objects the top **UsedFor** edge, primitives
are **hand_authored** (roll / weight / wedge). Each entry records the term, relation,
exact assertion, and edge weight.

**Provenance status:** `api.conceptnet.io` returned HTTP 502 for every request at build
time, so the committed table is currently `conceptnet_curated` — documented ConceptNet
assertions with **approximate** weights (hand_authored primitives excepted). Re-running
`python3 tools/build_abilities.py` when the API is healthy upgrades each entry to
`conceptnet_api` with live weights and assertion URIs. **This refresh should be run before
the thesis cites specific edge weights.**

Where ConceptNet's top edge is a plainer term than the design doc's flavor ability, the
committed table records the **ConceptNet grounding** (that *is* the thesis claim); the
design flavor is a game-layer embellishment:

| id | ConceptNet ability (committed) | design In-Game Function |
|----|-------------------------------|--------------------------|
| bat | fly (CapableOf) | Echolocation |
| butterfly | fly | Shrink/Flutter |
| monkey | climb | Swing |
| sea_turtle | swim | Armor |
| snail | crawl | Adhere |
| bee | pollinate | Hover/Pollinate |
| penguin | slide | Slide |
| clock | tell time (UsedFor) | Freeze Time |
| anvil | forge | Crush |
| tree | shade | Grow |
| mushroom | eat | Bounce |
| door | enter | Teleport |

**Sign-off question:** accept the ConceptNet grounding as-is (recommended — it is the
inspectable commonsense provenance), or override specific terms to the design flavor
(losing the ConceptNet weight for those)?
