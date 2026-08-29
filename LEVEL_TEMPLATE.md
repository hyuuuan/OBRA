# How to build a level — taken from Level 1

**What this is.** Level 1 (Payyo) is the only level in this project that has been built,
broken, re-measured and shipped. Everything it learned is spread across five documents and
a hundred scripts. This file is that knowledge with the Payyo taken out of it: **the shape
a level has, the files it owns, the rules it cannot break, and the order to build it in.**

**How to use it.** Read it before designing a level, and again before building one. Then
write your level's own `LEVEL_<N>.md` — the per-level document is where the *specifics* and
the *scars* go. This file holds only what is true for every level.

**Read with:** `LEVEL_1.md` (the worked example, and the traps), `GATES.md` (Level 1's gate
list and the rules behind its numbers), `ART_PLACEHOLDERS.md` (what a prop owes),
`CONTENT_NEEDED.md` (what is missing across the game), `AGENTS.md` (engine contracts).

> **Provenance.** Every claim below was read out of the repo on 2026-08-29, not remembered.
> Where a number comes from a constant, the constant is named so you can re-check it.

---

## The machine, in one paragraph

An obstacle declares an **ability tag** — Span, Climb, Fly — and **never a class**.
`AbilityTags` resolves the tag to the set of classes that satisfy it at load time, so a gap
asking to be spanned accepts a bridge, a ladder, a square or a triangle, and the player is
never told which. A level is a sequence of **beats**; a beat is either a tutorial with no
fail state or a **dialogue node** offering three routes — Artist, Pragmatist, Protector —
each of which asks for a different tag and rebuilds the obstacle to suit. Two clocks run
underneath: **ink** is level-scoped and finite, and **`MorphLife`** kills any drawing ten
seconds after you become it. Everything else is detail.

Two consequences fall out and both matter:

1. **The anti-stuck fallback is not authored anywhere.** Level 1's Node 2 Artist route asks
   for Forage; Forage happens to contain `pig`; so a pig is a valid Artist solution with
   nothing written down to allow it. You do not enumerate answers. You choose a tag and
   inherit its members.
2. **Adding a class to a tag makes it work at every obstacle needing that tag, at once** —
   in every level, including ones already shipped. Tag membership is the highest-leverage
   and least reversible edit in the project.

---

## What is generic, and what is Level 1 wearing a generic name

This is the first thing to know and the least obvious. **The systems are level-agnostic;
the level *host* is not.**

| | verdict | evidence |
|---|---|---|
| `ability_tags.gd`, `level_director.gd`, `level_obstacle_2d.gd`, `checkpoint_manager.gd`, `checkpoint_area_2d.gd`, `dialogue_script.gd`, `hint_bar.gd`, `requirement_strip.gd`, `signpost_2d.gd`, `inventory_screen.gd`, `morph_life.gd`, `acquired_overlay.gd` | **Generic.** Reusable as-is. | Level-1 strings in these files are **comments only**, plus two overridable defaults: `LevelDirector.LEVEL_PATH` and `ConceptGate2D.sign_hook` |
| `game/scripts/game_level.gd` | **Level 1.** 3046 lines with **41 hardcoded `L1_N*` / `B0_HAGDAN` references in live code** | `grep -n "L1_N[0-9]\|B0_HAGDAN" game/scripts/game_level.gd` |
| `game_level.tscn` | **Level 1**, despite the generic name. `levels.json` points `level_1` at it. | `game_level.gd:280` calls `director.load_level()` with no argument — the Level 1 default — and `:288` hardcodes `res://config/dialogue_l1.json` into a field named `script_lines_l1` |
| Props: `bale_2d.gd`, `straw_pile_2d.gd`, `baul_2d.gd`, `floating_tread_2d.gd`, `bulul_2d.gd`, `dead_tree_2d.gd`, … | **Level 1 furniture.** Copy the *pattern*, not the file. | — |

**So the first real task of Level 2 is not a puzzle — it is deciding what `game_level.gd`
becomes.** Two honest options:

- **Fork it.** Copy to `level_2.gd` / `level_2.tscn`, strip Level 1's beats, wire yours.
  Fast, ships, and guarantees the next level starts from a 3000-line copy of a copy.
- **Extract the spine.** Pull the generic half (adopt/morph/camera, ink, placement,
  checkpoint restore, dialogue plumbing, HUD) into a base the per-level script extends,
  leaving the beat dispatch in the subclass.

**Recommendation: extract, and do it while there is exactly one level to extract from.**
The cost is one refactor with a full green suite behind it; the cost of deferring is paying
it four more times. If the schedule says fork, fork — but write down that you forked, in
your `LEVEL_<N>.md`, so the second fork is a decision and not an accident.

> **DONE, 2026-08-29 — extracted.** `level_base.gd` + `game_level.gd`, eleven hooks, Level 1
> green throughout (audit 200/200, nodraw, walk, room probe, behaviour, profile). The table
> above is now history: read `AGENTS.md` for the hooks a level owes.
>
> **How it was done, because the method is the reusable part.** The file was parsed into 211
> contiguous top-level blocks covering every line, each block classified base-or-Level-1, and
> the two files emitted by *concatenating* those blocks — so no code was ever retyped and
> none could drift. Only then were ten mixed functions hand-patched to call hooks. The proof
> is a function-by-function diff against `HEAD`: 0 functions lost, 9 intended patches, 15
> differing only by the `script_lines_l1` rename. Do it that way again; do not do it by hand.

⚠ **Whatever you choose: `levels.json` gets its `scene_path` filled in LAST.** Three tests
assert an unbuilt level is not playable while `scene_path` is empty
(`test_player_profile.gd`, `run_tests.gd`), and they are right to. A path to a scene that
half-exists is a card the hub will happily offer.

---

## The files a level owns

| File | Shared or per-level | Notes |
|---|---|---|
| `game/config/level_<NN>.json` | **per-level** | The level. Schema below. |
| `game/config/dialogue_l<N>.json` | **per-level** | Every line, hooked to a beat. |
| `game/levels/level_<N>/level_<N>_environment.tscn` | **per-level** | Geometry. |
| the level script + scene | **per-level** | See the fork/extract decision above. |
| `game/assets/Level<N>/` | **per-level** | Cut from the artist's originals in `level-<n>-assets/`. |
| `game/config/tags.json` | **shared, GENERATED** | Never hand-edit. Edit the design table in `tools/build_tags.py` and regenerate. |
| `game/config/entities.json` | **shared** | The 50-class roster. Adding a class means retraining the model. |
| `game/config/object_sizes.json` | **shared** | How big a drawn object becomes. Your gate numbers are measured against these. |
| `game/config/levels.json` | **shared** | Hub cards. `scene_path` last. |
| `game/config/dialogue.json` | **shared, legacy** | The old per-level block. Level 1 still takes its opening line from here and it is out of voice. Prefer `dialogue_l<N>.json`. |

---

## `level_<NN>.json` — the schema, key by key

Read straight off `level_01.json`. Everything marked **enforced** is checked at load or by
the audit; everything marked *inert* is carried for the record and read by nobody.

```
schema_version         int
level_id               "level_2"      — runtime id. Profiles key on it. NEVER rename.
design_level_id        "L2_PISTA"     — the design's name for it.
display_name           what the player sees
order                  int
unlocks_on_complete    design id of the next level
unlocks_at_checkpoint  which checkpoint actually unlocks it   ← not "the end"
tags_unlocked          [ {tag, at} ]  — where each tag enters the player's vocabulary
checkpoints            [ {id, at, trigger} ]  trigger: "area" | "route_commit"
                       (+ optional `routes: []` to scope a checkpoint to one branch)
obstacles              [ … see below … ]
hidden_flowers         [ {id, at, gate_tag, gate_unlocked_at_level,
                          behaviour_when_locked, not_a_fail_state} ]
hint_escalation        t0..t3 — see the hint ladder
recognition            {confidence_threshold, margin_threshold,
                        decline_costs_ink, decline_message_source}
cultural_constraints   free-shape, per level — see the guardrail pattern
lighting_states        [ {id, from, to} ]
load_time_assertions   [ strings ]  — the level's own invariants, in prose
tuning                 INERT. Carried verbatim from the design doc; ink lives on
                       InkManager's own 12.0 scale. Do not wire it up.
```

**An obstacle:**

```
id, type            "tutorial" | "dialogue_node"
display_name        shown at the node
dialogue_node       bool
fail_state          bool
sub_beats           [ {id, teaches, required_tags, exclude} ]   — tutorials
teaches_before_choice [ tags ]                                  — dialogue nodes
checkpoint_on_commit  checkpoint id
routes              { artist: {...}, pragmatist: {...}, protector: {...} }
grants_item         item id
scripted            { on_first_decline: <dialogue line id> }
```

**A route:**

```
required_tags       [ tags ]
match               "any"   — default is ALL of required_tags
exclude             [ classes ]  ← applied BEFORE the ≥2-answers check
then                { required_tags, exclude }   — a second stage after the first
reward              cutscene / item id
grants_tool         a tool the player keeps
sets_flag           profile flag
search_time_modifier_if_flag  { flag: multiplier }
persistent_effect   a mark this route leaves on THIS level
cross_level_effect  "L<N>_<NAME>.<thing>.<state>" — a mark on a LATER level
special             { … } — bespoke, e.g. the ward sequence
```

---

## The three routes mean something

The ids `artist` / `pragmatist` / `protector` **must not change** — the ending resolver
counts them. What they mean is consistent across levels and is the reason the choice reads
as a character rather than as a difficulty setting:

| route | the stance | Level 1 |
|---|---|---|
| **Artist** | Restore her work. Do it the way it was made. | Rebuild the bridge · comb the straw · search the attic |
| **Pragmatist** | The plain physical way. Go around, go down, go through. | Climb down · carry the chest out · unlock the lid |
| **Protector** | Force it, and accept the mark it leaves. | Fell the tree · scatter the straw · cut the chest open |

**Protector is the route that costs something.** In Level 1 all three of its routes set a
`persistent_effect`, and one of them reaches into a later level. If your Protector route
costs nothing, you have written a second Pragmatist.

**The tally records the choice, not the solution.** What the player picked at the dialogue
is the data; how they got past it is not. Keep `tag_match` separate from `solves` so an
assisted pass counts as a solve and *not* as a first-intent match — collapsing those lets
assistance inflate the number the thesis reports.

---

## Dialogue — the shape, and the one rule

One file per level. `{ level_id, design_level_id, language, speaker_default, lines: [] }`,
and a line is:

```
id            stable; referenced by level_<NN>.json (e.g. scripted.on_first_decline)
at            the hook
text          what is said
speaker       overrides speaker_default ("lolo" by default; "apo" for the player)
once          true = spent forever, for anyone
condition     fires only when a flag/effect is set
choice_label  the button text at a dialogue node
```

**The hook vocabulary.** Level 1 uses 49 hooks and they fall into ten forms. Reuse them:

```
<OBSTACLE>.enter            arrival lore — fires ONCE, ever
<OBSTACLE>.teach            the tags taught before the choice
<OBSTACLE>.choice           the question
<OBSTACLE>.<route>.commit   what the apo says when the button is pressed
<OBSTACLE>.<route>.solved   what Lolo says when it works
<OBSTACLE>.sub<N>           a tutorial sub-beat's instruction
<OBSTACLE>.sub<N>.solved    …and its acknowledgement
<OBSTACLE>.solved           the beat closes
on_first_decline            the recogniser could not read it (once: true)
after_first_decline_solved  …and then it could (once: true)
EXIT_MARKER[.<thing>]       the level ends
```

Plus bespoke hooks for whatever your level has that no other level does.

⚠ **The button and the line are literally the same string.** A `.commit` line carries
`choice_label` *and* `text`, spoken by the `apo`. The player reads the button, presses it,
and hears themselves say it. Do not paraphrase between the two.

⚠ **Arrival speaks once, and that is not the same as `once`.** `<obstacle>.enter` fires the
first time and never again, tracked by `DialogueScript.has_heard`, because a trigger big
enough to catch a jumping player is a trigger the player crosses more than once — and
Level 1's straw heap sits *inside* its own obstacle volume, so leaving it replayed two
lines of Lolo with the world paused, every time. A narrower box does not fix it. The beat
needs a memory. A line's authored `once: true` is different: it means spent forever, and it
is right for the refusal beat, not for lore.

⚠ **`condition` has no `unless`.** A hook fires *every* matching line, so a conditional pair
("you combed the straw" / "you did not") needs either an `unless` key added to
`dialogue_script.gd` or a rewording that is true for both. Level 1 shipped the bug: its
attic line says *"On the nail. Just as she said"* to players who were never told about a
nail.

### The rule that outranks the writing

> **No dialogue line may name a drawable class.**

Enforced with word boundaries against all 50 ids and display names, on the dialogue file
*and* on the live HUD strip. The tag layer exists so an obstacle has several answers; a line
that says "draw a ladder" closes the puzzle from inside the script.

This is hardest in Filipino, and Level 1 nearly shipped eight violations: *tulay*, *hagdan*,
*susi*, *pinto*, *puno* are all classes in the roster. The fix is to phrase around them —
"a crossing", "the way up", "it", "one way in", "old growth". **Check your level's own
vocabulary before you write, not after.**

---

## The rules that carry to every level

Restated from `GATES.md` with the Payyo taken out. R1–R8 are Level 1's, proven; R9 is
proposed by `LEVEL_2.md` and is listed here because it generalises.

| id | rule |
|---|---|
| **R1** | **The jump lifts 94.3 px** (`JUMP_VELOCITY -430`, gravity 980). Every gate is measured against it, and the audit reads the constant rather than a copy. |
| **R2** | **A running jump covers ~228 px.** Any gap meant to stop the player beats that with margin — and so does any stepping stone left near one. |
| **R3** | **A gate must open.** Test both halves. An impassable gate is worse than a skippable one and looks identical in a report that only checks the first half. |
| **R4** | **A drawn primitive is 80 px** and must stay climbable under the 94.3 px jump. |
| **R5** | **No jump in water lifts you out.** Every exception hands the player a free crossing. |
| **R6** | **Never gate progress on a route commit.** Answering the dialogue costs no ink and is not an answer. What counts is a drawing being accepted. |
| **R7** | **A gate must have floor to build on** — ≥180 px of clear ground on the approach side, and never less than twice the width of the widest thing that opens it. A rise and a gap can both be right while the level is unplayable. |
| **R8** | **What is placed can be taken back** — E within reach, right-click at any range. A placement spends ink, empties a slot and leaves a solid body behind. |
| **R9** *(proposed)* | **A Fly gate is a gate with nothing under it to build on** — >362 px above the nearest buildable surface, or <180 px of floor beneath. Otherwise Climb or Span answers it. |

**Every gate number in your level is derived from `object_sizes.json`, not chosen.** The
reaches that matter:

| the tallest / longest answer | reach |
|---|---|
| drawn primitive 80 + jump | 174 px |
| `stairs` 232 × 176 + jump | 270 px |
| `ladder` 72 × 244 + jump | 338 px |
| `tree` 150 × 268 + jump | **362 px** |
| `bridge` | **340 px** across |

A vertical gate under 362 px has a placement answer whether you asked for one or not. A gap
under 340 px is a Span gate no matter which tag you wrote down.

### Invariants — assert these, do not merely document them

- **Every obstacle route resolves ≥2 classes AFTER exclusions.** Dropping to one is a build
  error. An obstacle with one answer is a spelling test.
- **Every `teaches_before_choice` tag is unlocked before its choice is presented.**
- **Every morph-capable route is preceded by a checkpoint.**
- **Every tag in `tags_unlocked` exists in `entities.json`.**
- **The level cannot be finished without drawing.** This is the premise of the game, and
  Level 1 failed it for most of its life. It needs its own bot (T1).

---

## The beat pattern

Level 1's shape, and the reasoning that makes it a shape rather than a habit:

**Beat 0 — a tutorial, with no dialogue node and no fail state.** Teaches the level's new
tag(s) in **sub-beats, in the order the player meets them**, and ends at a walk-in
checkpoint. No routes, no choice, nothing to get wrong permanently.

⚠ **Sub-beat order is load-bearing.** Level 1 shipped Beat 0 backwards and it could not be
finished: Span was asked at the water, but after its own exclusions Span is an 80 px square
and nothing 80 px wide crosses 300 px of it — the only class long enough was the class the
sub-beat excluded. The walk test had been proving the crossing opened *with the excluded
class* the whole time. **Check every sub-beat against its own exclusion list, with real
numbers, before anything else.**

⚠ **Use the exclusion list as the lesson.** Two sub-beats asking the same tag with different
exclusions teach the tag's *shape*, which is more than either teaches alone.

**Nodes 1..3 — dialogue nodes.** Each: arrival lore → teach the tags → the question → three
routes → a checkpoint on commit. The chosen route **physically rebuilds the obstacle**
(Level 1 frees the two unchosen branches outright), so one node is three gates and each
needs its own test.

**The last node is the exit condition.** The level does not end until it is *answered* —
and choosing one of the three lines is free and is not an answer (R6).

**Three nodes is Level 1's shape, not a law.** If a level is thin, cut a node rather than
padding one.

---

## Checkpoints, state, and what crosses levels

- **A checkpoint has a visible mark, and it stands on the GROUND.** `CheckpointArea2D`
  casts a ray down from the *top* of its box on its first physics frame and plants the flag
  on the first thing it meets — because a trigger is authored tall enough to catch a jumping
  player, so the foot of the box is not the floor. Level 1 buried a flag under a terrace
  doing it the obvious way.
- **`unlocks_at_checkpoint` is not "the end".** Level 1 unlocks Level 2 at CP3, one beat
  before the exit.
- **Two kinds of state, and the difference matters.** A `persistent_effect` is a mark on
  the level and rides the checkpoint. A **profile flag** — canvas damage, route records —
  is on `PlayerProfile`, because a mid-level death must not undo a decision made two levels
  ago.
- **`cross_level_effect` is a string with a target that does not exist yet.** Level 1 writes
  `L2_PISTA.hidden_flower_2.unreachable` and nothing reads it. When you build the level it
  names, you owe that string a behaviour.
- **Profile schema bumps migrate forward** through `_merge_defaults`, and
  `test_player_profile.gd` holds `EXPECTED_SCHEMA` as its own literal so a bump fails loudly
  until the migration is confirmed. Currently **v5**.

**Hidden flowers.** One per level. Gate it on a tag from a **later** level so it is visible,
inert and *not a fail state* — `behaviour_when_locked: canvas_opens_normally_entities_spawn_inert`.
It is the reason to come back.

---

## The hint ladder

Four tiers, and they are the level's difficulty curve — not the gate numbers.

| tier | trigger | reveals |
|---|---|---|
| **T0** | on approach | flavour. Says nothing useful. |
| **T1** | canvas open or 30 s idle | the required tags **and their glosses** |
| **T2** | 2 failed attempts or 90 s | the player's **own** qualifying drawings |
| **T3** | 4 failed attempts or 180 s | the accept-set widens to the **union of all three routes**; logs `assisted` |

⚠ **T1 prints what the tag means, not only its name.** "NEEDS SPAN" names the problem
without describing it, and these tags are this game's invention — nobody arrives knowing
them. Glosses live in `GLOSS` in `tools/build_tags.py`, and **every gloss describes a
property and names no class.** That constraint is the whole reason the tag layer exists.

⚠ **T3 replaces per-obstacle fallback authoring.** Do not hand-author escape hatches into
obstacles; the ladder is the escape hatch.

---

## The two clocks

- **Ink is level-scoped: 12 units.** Reserved transactionally while drawing, committed only
  by a successful morph or a stored/placed utility. A placement that cannot be undone costs
  a drawing *and* the ink that made it (hence R8).
- **`MorphLife` is 10 seconds**, exported on the node — balance, not architecture. A drawing
  is a **burst spent on one obstacle**, not a body you travel in. Its own comment states the
  design question it creates, and it is the right question for every level: *"where do I
  want to be standing when this one runs out?"*
- **Expiry reverts through `_revert_to_base_form()` — the same door Q uses.** Never write a
  second copy of it for the timed case; that is a second chance to strand the player in a
  wall.
- **Budget the level against 12 before playtesting.** Count the drawings on the critical
  path, add the ones a player will lose to a mistimed expiry, and compare. Level 1 has never
  had this done and `GATES.md` says so.

---

## Art contract

- **Terrain is top-left anchored; props are bottom-centre anchored.** `position` on a prop
  is where it meets the ground, and the art builds upward from y = 0.
- **Art that illustrates a gap must not fill it.** Level 1 was defeated twice by its own
  art — centre-anchored treads made every riser jumpable, and stubs drawn at five times
  their size showed a complete flight of steps that could not be climbed. If a thing is
  meant to be missing, it has to *look* missing.
- **Nothing may imply an affordance it does not have.** If it looks climbable, players will
  try, and the refusal reads as a bug rather than as a boundary.
- **A `Polygon2D` cannot be filled from an `AtlasTexture`** — it samples the whole atlas
  page using vertex coordinates as UVs. Use `atlas_tile.gd`. Every prop in two of Level 1's
  nodes shipped this way and none of them was on screen.
- **Atlas regions are slices, not materials.** A "roof" tile that includes a band of soil
  will grow a lawn on your roof. Take the band you mean.
- **Parallax convention:** 1920 × 1080 layers, `scroll_scale` bands 0.02 / 0.08 / 0.18 /
  0.38 / 0.72 / 1.08 (the last is the playable ground).
- **The artist's originals live in `level-<n>-assets/` at the repo root**, tracked;
  `game/assets/Level<N>/` holds the cut-down imports. Reduce offline (`Image.BOX`) so
  nothing is rescaled at runtime.

---

## Cultural guardrails — the pattern, not the list

Every level is set in a real place with real practices, and the guardrails are **asserted in
code**, not just written down. Level 1's shape:

1. **Name the sacred thing and give it nothing.** The bulul have zero collision, zero
   interaction, zero puzzle function — enforced in `bulul_2d.gd` (no collision shape is ever
   built) and asserted three ways. Every level needs its own version of this line.
2. **Distinguish the material from the meaning.** Cut straw may be scattered; a *tinawon*
   harvest may not. `straw_pile_is_grain: false` is in the level file because the difference
   is the whole point.
3. **Audio has a forbid list and a use list**, and they are specific to the region. What is
   right in one level is wrong in another.
4. **Say what the place is not.** `cave_contains_burials: false`.
5. **Commit to a specific place or stay generic — but decide.** Half-committing is the
   failure mode: it gets the details wrong *and* claims to be somewhere real.

---

## What a level owes the test suite

Level 1's runners, and what your level's ports of them prove:

| id | runner | proves |
|---|---|---|
| **T1** | `run_nodraw_level<N>.gd` | **The level cannot be finished without drawing.** Prints how far a determined player gets from several start points. The single most important test in the project. |
| **T2** | `run_walk_level<N>.gd` | Each gate **opens** — the drawing is placed and the character gets through. Also that a placement can be undone (R8) and that the object lands where the ghost was. |
| **T3** | `run_level<N>_audit.gd` | The data: routes, exclusions, checkpoints, the exit condition, and R7 measured off the scene nodes. ~40 checks, runs in seconds. |
| **T4** | `run_click_ui.gd` | Every button answers a real mouse click. **Needs a real viewport — no `--headless`.** |
| **T5** | `run_tests.gd` | Everything else. Takes over ten minutes. |
| — | `run_visual_*.gd` | **Frames a human looks at.** Also needs a real viewport. |

```bash
godot --headless --path game --script res://tests/run_level1_audit.gd
```

⚠ **Four defects in this project passed green suites and were caught only by screenshotting.**
A headless suite reports geometry as numbers, and the numbers were right in all four cases.
Budget for a visual pass; it is not optional polish.

---

## Traps that are not Level 1's — they are everyone's

1. **`class_name` and autoloads are not registered in a `--script` run.** Preload the script
   for constants; fetch autoloads with `root.get_node_or_null("Name")`, and inside another
   autoload use `get_node_or_null(^"/root/Name")`.
2. **Never round-trip a scene with instanced children through `instantiate()`/`pack()`.**
   Owning nodes recursively inlines every sub-scene (350 → 1283 lines); owning only what you
   create silently drops nodes. Edit properties in place, or at runtime. Check line count
   and `grep -c 'instance=ExtResource'` before and after.
3. **A test that reads through the API it is testing can be vacuous.** Level 1's tag-roster
   check asked `AbilityTags` for its class lists — but the loader already drops bad members,
   so it was testing the filter, not the data. **Read the raw file when auditing data.**
4. **Measure deltas, not absolutes, against anything persistent.** Two checks passed with
   the write removed, because `user://profile.json` survives between runs.
5. **A kinematic `CharacterBody2D` applies no weight to a `RigidBody2D`,** and a rigid body
   does not reliably report contacts with a kinematic one (measured: 60 frames). Use an
   `Area2D`.
6. **Do not write `global_position` on an active `RigidBody2D`** — the physics server
   overwrites it the same frame. Freeze first, then move.
7. **Setting `collision_layer` without `collision_mask` does nothing.** Godot pairs two
   bodies when *either* side matches. Level 1 spent a release thinking it had buoyancy.
8. **A stale path in a *test* can look like engine failure.** One wrong node path threw
   inside a test that aborted with an overlay open, leaving the tree paused — and twenty
   creatures were reported as "render frozen". **Read the first error, not the loudest.**
9. **A room re-reads the profile when it is ENTERED.** Rooms are built at level load and
   entered much later; a snapshot taken at build time goes stale in the worst direction.
10. **`body_entered` is a transition, so a trigger must sweep once when it arms.** A player
    put down *on top of* a pickup by a teleport never generates an entry.

---

## Build order

1. **Write `LEVEL_<N>.md` first**, even as a placeholder, and mark it provisional until it
   is built. The design goes stale silently otherwise.
2. **Measure the new mechanic before costing anything out.** If the level introduces a tag,
   find out what its classes actually *do* — how high, how far, how long — in the engine as
   it stands. Every number downstream depends on it and it is one afternoon.
3. **Populate the new tag** in `tools/build_tags.py`, regenerate, run
   `python3 tools/build_tags.py --check`. Confirm no obstacle drops below two answers after
   exclusions, and note which classes leave the unhintable list.
4. **Import the art**, cut from `level-<n>-assets/` into `game/assets/Level<N>/`.
5. **Write `level_<NN>.json`** against the schema above, and port the `load_time_assertions`.
6. **Write `dialogue_l<N>.json`**, then grep it against all 50 class ids and display names
   before anyone reads it aloud.
7. **Build the geometry**, measuring every gate against R1–R9 and `object_sizes.json`.
8. **Port T3 (the audit) and T1 (the nodraw bot) early** — they are cheap and they are the
   two that catch a level that is secretly not a level.
9. **Fill in `levels.json` `scene_path` last.**
10. **Look at the frames.**

---

## Where this template is still soft

Honest list, so nobody mistakes it for finished.

- **Only one level has ever been built.** Everything here is generalised from a sample of
  one, and some of it will turn out to be Payyo-shaped in ways nobody has noticed yet. The
  second level is the experiment that tests this document.
- **The fork-or-extract decision is unmade**, and it gets more expensive every level.
- **`dialogue.json` (the legacy per-level block) still supplies Level 1's opening line**,
  out of voice, alongside `dialogue_l1.json`. Two dialogue systems is one too many; decide
  which survives before a second level doubles it.
- **No level has been costed against the 12-unit ink budget.**
- **`condition` has no `unless`**, so conditional lines are still unwritable in one pass.
- **No per-class recall data exists** — the model is not trained — so "how many answers does
  this obstacle really have for a real player" cannot be answered for any level. The audit
  prints the obstacles sitting at exactly two solutions; that list is the best proxy there is.
