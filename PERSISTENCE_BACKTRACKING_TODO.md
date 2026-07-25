# Persistence & Backtracking — Status

Status: **data layer and logic implemented; the remaining gaps are gameplay content
that does not exist yet.** Everything below lives in the existing JSON player profile —
no database, per thesis §4.5.2.

## Done

Profile schema is now **v2**. A v1 profile migrates forward (keeps its progress) instead
of being discarded; anything unreadable or newer still falls back to a fresh profile.

| Flow arrow | State |
|---|---|
| Save Unlock (acquire concept/object) | **Done** — `record_object_acquired()`, field `acquired_objects` |
| Read Save → "Concept Unlocked?" gate | **Done** — `has_object()` / `is_concept_unlocked()`, consumed by `ConceptGate2D` |
| Object survives across levels | **Partial** — ownership is global and permanent, and an owned object costs no ink to summon again (FR-8.3/8.4). Toolbelt *rehydration* is still open (see below) |
| Route choice → profile | **Done (data)** — `record_route()` now tallies `route_counts` and no longer overwrites on replay (FR-12.5). No caller yet — no dialogue system exists |
| Hidden Flower → profile | **Done (data)** — `record_collectible()` / `is_collectible_found()` / `collectible_count()`. No caller yet — no flowers placed in any level |
| Read Telemetry → Endings A–D | **Done** — `game/scripts/ending_resolver.gd`. No caller yet — no Level 5 climax exists |

Implementation notes:

- `game/scripts/player_profile.gd` — added `acquired_objects`, `route_counts`,
  object/collectible/route queries, and v1→v2 migration.
- `game/scripts/ending_resolver.gd` — `EndingResolver.resolve(profile)` is **total and
  deterministic**. Fixed precedence, documented in the file: **A → B → C → D**, with D as
  the default so every profile resolves to exactly one ending. `resolve_values(...)` is a
  pure function for testing. Thresholds are named constants (`ROUTE_COMMITMENT`,
  `HIGH_DIVERSITY`, `LOW_DIVERSITY`, `HIGH_REDRAW_RATE`, `TOTAL_FLOWERS`) — tune in one place.
- `game/scripts/concept_gate_2d.gd` — `ConceptGate2D.try_pass()` checks
  `PlayerProfile.has_object(required_concept_id)` and emits `passage_allowed` /
  `passage_blocked(concept_id, hint)`. Because ownership is global, acquiring a concept in
  a later level retroactively opens every gate that needs it (FR-13.3).
- `game/scripts/game_level.gd` — records acquisition on first successful recognition of a
  utility, and refunds/skips the ink charge when the object is already owned.
- `game/tests/test_player_profile.gd` — covers acquisition round-trip, gate query,
  route tallies (including replay), collectibles, resolver precedence/totality, and migration.

## Still open

1. **Toolbelt rehydration.** Ownership persists, but the *drawn instance* does not: the
   profile stores entity ids, while `DrawnItemData` carries the player's actual image and
   stroke vectors. Re-summoning is currently free rather than automatic. To have tools
   reappear in the belt on level load, first decide whether to persist stroke/image data
   in the profile (it is the player's own ink, and the thesis's "objects survive" arrow
   implies the *object*, not necessarily the exact drawing). Then rehydrate in
   `inventory_manager.gd::begin_level()` after `_reset_slots()`.
2. **Callers blocked on content that does not exist:**
   - `record_route()` needs the dialogue-node choice UI (Empathy / Pragmatist / Protector).
   - `record_collectible()` needs Hidden Flowers placed in levels.
   - `EndingResolver.resolve()` needs the Mayon (Level 5) climax to display an ending.
   - `ConceptGate2D` needs to be placed in a level scene with a real obstacle (e.g. the
     Torch→vines gate). The component and its persistence contract are ready.

## Note for the SRS / thesis

Rename the flowchart node **"Global Profile DB" → "Global Profile (Save File)"** so the
diagram matches the no-database design (§4.5.2). None of the above needs a DBMS.
