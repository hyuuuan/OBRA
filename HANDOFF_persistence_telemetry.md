# Handoff — Persistence, Telemetry & Backtracking

Written for whoever picks this up next. Everything here is on branch
`rig-and-recognition-fixes` and pushed. Two commits:

- `9e4c834` — player profile persistence, telemetry, cross-session progression
- `1d65934` — acquired objects, route tallies, ending resolver, backtracking gate

Context: the thesis describes a save file, automatic telemetry, and progression that
the code did not have. These commits add that infrastructure. **There is no database
and none is needed** — everything is the JSON player profile (thesis §4.5.2). If the
flowchart still says "Global Profile DB", rename it to "Global Profile (Save File)".

---

## 1. What now exists

### Player profile — `game/scripts/player_profile.gd` (autoload `PlayerProfile`)

One JSON file at `user://profile.json`. Atomic write (temp-then-rename), schema **v2**.
A v1 profile migrates forward and keeps its progress; anything unreadable or newer
falls back to a fresh profile rather than crashing.

```gdscript
# progression
PlayerProfile.mark_level_completed(level_id)      # also unlocks the next level
PlayerProfile.is_level_unlocked(level_id)
PlayerProfile.is_level_completed(level_id)

# objects / concepts — global and permanent, this is what makes backtracking work
PlayerProfile.record_object_acquired(entity_id)
PlayerProfile.has_object(entity_id)               # alias: is_concept_unlocked()
PlayerProfile.acquired_objects()

# routes — tallies, does NOT overwrite on replay (FR-12.5)
PlayerProfile.record_route(level_id, route)       # route in {artist, pragmatist, protector}
PlayerProfile.route_count(route)
PlayerProfile.route_counts()

# collectibles
PlayerProfile.record_collectible(id)
PlayerProfile.is_collectible_found(id)
PlayerProfile.collectible_count()

# derived (drive the endings)
PlayerProfile.class_diversity()                   # distinct classes accepted, of 50
PlayerProfile.redraw_rate()                       # declines / submissions
```

**If you add a field:** bump `SCHEMA_VERSION` and add the old version to
`MIGRATABLE_SCHEMAS`, or you will wipe everyone's save.

### Telemetry — `game/scripts/telemetry.gd` (autoload `Telemetry`)

Anonymous, local, per-session JSONL at `user://telemetry/session_<UTC>.jsonl`: session
and level lifecycle, plus one record per submission (class, confidence, margin,
runner-up, accept/decline, end-to-end latency). Nothing is uploaded.

Backend side: `backend/telemetry.py` logs one record per prediction to
`telemetry/backend_<date>.jsonl`, **only** when `OBRA_TELEMETRY=1`
(`OBRA_TELEMETRY_DIR` overrides the directory). `/predict` also returns a `timing`
split so end-to-end latency decomposes across game and backend.
Summarise with `python3 tools/aggregate_telemetry.py <dir>` — redraw rate, latency,
per-class precision/recall, confusion matrix.

On macOS `user://` is `~/Library/Application Support/Godot/app_userdata/O.B.R.A/`.

### Endings — `game/scripts/ending_resolver.gd` (`EndingResolver`)

Total and deterministic. Fixed precedence **A → B → C → D**, D as the default, so every
profile resolves to exactly one ending. Thresholds are named constants at the top of the
file — tune there. `resolve_values(...)` is a pure function, so test it directly.

```gdscript
var ending := EndingResolver.resolve(PlayerProfile)   # -> "A_masterpiece" etc.
var detail := EndingResolver.explain(PlayerProfile)   # ending + the inputs that produced it
```

### Backtracking gate — `game/scripts/concept_gate_2d.gd` (`ConceptGate2D`)

Drop it in a level scene, set `required_concept_id` (e.g. `"torch"`) and `hint_text`.

```gdscript
var result := gate.try_pass()    # {passed, concept, hint}
# signals: passage_allowed(concept_id) / passage_blocked(concept_id, hint)
```

It reads `PlayerProfile.has_object()`, so acquiring the concept in a *later* level
retroactively opens every gate that needs it, in any level and any later session
(FR-13.3). No per-level bookkeeping.

### Progression & ink

- Level completion: `game_level.gd::_complete_level()` fires when the player's morph
  reaches the `GoalMarker` in `game_level.tscn` (Level 1 summit, x≈3450).
- Acquisition is recorded on first successful recognition of a utility.
- **An object you already own costs no ink to summon again** (FR-8.3/8.4).

---

## 2. What I did NOT do, and why

Four items are **blocked on gameplay content that does not exist yet**. The data layer
and logic for each is finished and tested — only the call site is missing. Wiring them
would have meant inventing the gameplay, so I stopped at the seam.

| Blocked | Needs | Call site to add |
|---|---|---|
| Route recording | The dialogue-node choice UI (Empathy / Pragmatist / Protector) | `PlayerProfile.record_route(level_id, route)` at the choice |
| Collectibles | Hidden Flowers actually placed in levels | `PlayerProfile.record_collectible(flower_id)` on pickup |
| Ending display | The Mayon (Level 5) climax scene | `EndingResolver.resolve(PlayerProfile)` at the climax |
| Concept gate in play | A real obstacle in a level (e.g. Torch→vines) | Place a `ConceptGate2D`, connect its two signals |

Also **not** done: toolbelt rehydration — see the decision below.

Out of scope by agreement, untouched: playstyle branching itself, the
telemetry-generated Level 5 layout, and new level content. Levels 2–5 unlock and
persist correctly but have no scene, so opening them safely no-ops.

---

## 3. Rehydration decision (read this before starting)

**The question:** should acquired tools reappear in the six-slot toolbelt on level load?
`InventoryManager.begin_level()` wipes the belt every level. The profile stores entity
*ids*, but `DrawnItemData` carries the player's actual `Image` and stroke vectors — so
"put the torch back in the belt" means persisting the drawing itself.

### My recommendation, in priority order

**a) Treat it as convenience, not correctness — do the blocked call sites first.**

Backtracking already *works*: `has_object("torch")` is true forever once acquired, and
re-summoning an owned object is free. The Torch→vines loop is functional today — the
player redraws the torch at no ink cost and the gate opens. Rehydration only saves them
that redraw. The four blocked items in §2 are missing *functionality*; this is polish.
Do them first.

**b) When you do build it: sidecar files, NOT blobs inside profile.json.**

This one is not taste, it is a real constraint. `note_submission()` calls `_commit()`,
which rewrites the whole profile **on every single drawing submission**. If the profile
carries base64 PNGs and stroke arrays for up to 27 utilities, every submission rewrites
megabytes, and `profile.json` stops being the small, human-readable artifact that is
easy to inspect for the thesis.

Instead:

- Keep `profile.json` holding ids only (as now).
- Add `game/scripts/drawn_item_store.gd`: `save_item(item)` / `load_item(entity_id)`,
  writing `user://objects/<entity_id>.json` (strokes + display name + ink cost) and
  `user://objects/<entity_id>.png` (`Image.save_png()`).
- **Reuse the stroke JSON shape the repo already has**:
  `{"points": [[x, y], ...], "width": 8.0}` — exactly what `game/tests/fixtures/*.json`
  use and what `_messy_strokes()` in `game/tests/run_tests.gd` parses. Do not invent a
  second format.
- Call `save_item(item)` next to the existing `record_object_acquired()` in
  `game_level.gd::_on_drawing_ready()`.

**c) Do not silently auto-fill the belt.**

There are 27 utility classes and 6 slots. Auto-filling with "the first six owned" is
arbitrary and will crowd out what the player actually wants. Either add an explicit
loadout picker at level start, or leave the belt empty and keep relying on free
re-summon. **This is a design call, not a technical one — decide it with the group
before writing the rehydration code.** My lean: leave it empty and keep free re-summon,
because it costs no new UI and the player's fresh drawing is usually what they want.

---

## 4. Verifying your changes

```bash
python -m unittest -v tests.test_manifest_contract          # 50-class contract
python -m unittest -v tests.test_backend_telemetry          # backend telemetry
godot --headless --path game --script res://tests/run_tests.gd            # -> OBRA_HEADLESS_TESTS_OK
godot --headless --path game --script res://tests/test_player_profile.gd  # -> OBRA_PROFILE_TESTS_OK
```

Two gotchas that cost me time:

1. **A new `class_name` script is invisible to tests until the project is re-imported.**
   Run `godot --headless --path game --editor --quit` first, or you get
   `Identifier "X" not declared` — with a misleading `EXIT=0`. **Check for the
   `..._OK` marker, not the exit code.**
2. `godot --check-only --script <file>` compiles a file in isolation and falsely
   reports `Identifier not found: Telemetry / LevelManager / PlayerProfile` for anything
   using autoloads. Use the editor-import check above instead.

The corrupt-JSON `Parse JSON failed` lines during the profile test are **expected** —
that test deliberately writes a broken file to prove the fallback works.

---

## 5. Suggested order of work

1. Place a `ConceptGate2D` in Level 1 with a real obstacle — smallest change that
   demonstrates the whole backtracking loop end to end, and good for the defense demo.
2. Hidden Flowers → `record_collectible()`; show remaining flowers per level in
   `main_menu.gd::_refresh_cards()`.
3. Dialogue-node choices → `record_route()`.
4. Level 5 climax → `EndingResolver.resolve()` on an ending screen.
5. Rehydration, only if §3 still looks worth it by then.

Status of the flowchart's specific "Global Profile" arrows is tracked in
`PERSISTENCE_BACKTRACKING_TODO.md`. Architecture contracts are in `AGENTS.md`.

---

## 6. One thing worth a human pass

I verified every component automatically, but not one continuous playthrough. When
convenient: start the backend, draw a creature, climb the Level 1 terraces to the summit
→ level completes → the Level 2 card unlocks → relaunch and confirm it is still
unlocked. Then check `user://` for `profile.json` and `telemetry/session_*.jsonl`.
