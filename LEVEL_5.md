# Level 5 — Mayon

**Status: BUILT, on the hub, and the level the run ends on.** Shipped in PRs #120-#132 (2026-10-25
to 10-29). The design as decided is below, then [where it lives](#where-it-lives) and
[how the build differs from the design](#as-built-against-the-design). Read `LEVEL_TEMPLATE.md` first; this file holds only what is
specific to Mayon.

**Sources.** `Level 5 Mayon Design.docx` (the proposed design, with three items marked for a
decision) and its flowchart (`docs/level5_mayon_flow.mermaid`, BPMN shapes like Levels 2–4), the
delivered art `Mayon Assets.zip` (a sky, the volcano, a meadow band, a ground strip, the Cagsawa
bell tower, a labelled tileset and the completed look; **no art for Lola, the summit, the ash or
the real-world room**), and four decisions Kent made on 2026-10-25.

---

## The level in one paragraph

Mayon is the last painting, and it is coming apart while the apo stands in it. The volcano is not
an enemy: it is the forgetting, and the ash is what takes the world — anything it settles on goes
white, then blank. **For four levels she drew to overcome; here she draws to preserve.** Same verb,
opposite meaning. The ink is finite and nothing on the mountain refills it. Halfway up, fragments
of every earlier painting break loose and start going white, and there is ink for about four of
twelve. Lolo climbs with her, losing words, because he is lola's memory of him and the painting
coming apart is him coming apart. Near the top the apo tries to draw him and the brush will not do
it — it never could; there is no person in the fifty classes. At the summit lola is painting with
her back turned. The brush refuses her too. So the apo draws the places instead, everything she
saved blooms into the white, and lola turns around.

## Decisions — do not re-litigate

| | |
|---|---|
| The ending (Kent, 2026-10-25) | **The summit is the ending.** The frame return ends on the apo picking up an ordinary brush, then cut to black, then the house. Endings A–D are still computed by `EndingResolver` and logged to telemetry for the thesis; they are never shown, and the stats screen leaves play. |
| Confrontation (Kent) | **None at all.** No boss, no combat, no health. The ash is weather; the antagonist is the clock and the ink. |
| Lola, the room, Lolo fading (Kent) | **Placeholders sculpted in the delivered art's idiom**, like Dilim's creatures, each named in `ART_PLACEHOLDERS.md` so the art team can replace it by name. Lolo's fading is a shader over his existing sheet. |
| Drawing the places (Kent) | **One drawing blooms them.** After the third refusal the canvas opens once more; whatever she draws, the fragments she saved bloom into the white one by one. No recognition, no ink: the climax cannot fail. |
| Running out of ink (the doc's recommendation) | **A hidden reserve.** The two drawings the climb cannot be finished without may draw on two units nobody sees, and only when the gauge cannot pay. Fragments and transformations never touch it. The summit costs nothing. |
| Recall discipline (the doc's recommendation) | **Every gate is a tag, not a class**, with ≥2 classes at ≥0.70 recall after exclusions — asserted by the audit, not promised here. |
| Saving a fragment (the doc) | **Draw something that belongs in it** — each fragment accepts a few of its own level's classes, never named on screen. A fit costs one unit and her lines are inked into it; a drawing that does not belong is handed back free. |
| Ink | Six units (FR-7), **no refills anywhere**, every drawing costs one, a creature form drains it while held. The gauge is visible at all times, even during a line. |
| Saves | **Silent.** No lantern, no letterbox, no line, no counter. The climb is one continuous ascent. |
| Her drawings | The ash never takes what she draws. |
| The tally | Mayon's only fork is the flower: spending ink on it is **artist** (one point). Her summit monologue is voiced by the route the whole run leaned toward. |

## Flow

```
Painting → the foot of Mayon: LOLO is waiting, and he should not be → the ink, told plainly → CP0
ACT ONE    THE ASCENT — the verb inverts
           ash falls; what it settles on goes white, then blank
           SPAN   the bridge she came up by is gone       → draw a way across
           CLIMB  the path thins out to a wall             → draw a way up
           (an optional dim stretch: a light lifts it, and costs ink)
           Lolo loses words; asks a question he asked in Piyesta
CP1        the mid slope (silent)
ACT TWO    WHAT YOU CARRY — the heart
           twelve fragments of every earlier painting drift loose and go white
           save one = draw something that belongs in it (1 ink) · let it go = it is gone
           three hold Lolo (terraces, church, bangka): saving one steadies him for a while
           one holds a flower lola painted for no reason, down a path nobody needed → flower 5 of 5
           LOLO GOES: she tries to draw him; the stroke does not become anything (the first refusal)
           "the brush was never for that" — and mid-sentence he is not there
CP2        below the summit (silent)
ACT THREE  THE SUMMIT — quiet: no ash, no tremor, no sound
           white in every direction except what she saved · lola painting, back turned
           the apo speaks; lola does not turn · the brush refuses her, twice
           the third time the apo lowers it herself · she draws the places · they bloom
           her monologue, voiced by her run's route · lola turns
           five flowers → for a moment lola says her name, and lolo's; then it passes
           fewer → warm to a child she does not know; pleased with the painting; the apo stays
THE FRAME RETURNS  the real room · the apo tells lola the stories she saved · lolo, last
           she picks up an ordinary brush → cut to black → the house
```

## Rules this level adds

- **The brush refuses twice, and both times look the same.** Drawing at Lolo, and at Lola, the
  canvas takes no guess, shows no words, spends no ink and records nothing; when she paints, her
  lines fade to paper and the page closes. This must not reuse any decline feedback from another
  level. These are the only moments in the game where the recogniser is deliberately given
  nothing to answer.
- **No refills.** No jars, no clearings, no `refilled_at`. The audit asserts it.
- **Nothing is marked important.** A fragment shows no value, no cost comparison, no count.
- **No story line mid-climb that names a class** (as everywhere) — and no line about Lolo's going
  that explains it. One line too many and it becomes a lecture.
- **Every sound has a visual twin** (Dilim's rule): the eruption's rumble is a tremor and an ash
  pulse.

## Build order (each a PR that ships green; every new behaviour is a LevelBase hook that defaults off)

| | PR | |
|---|---|---|
| 00 | | this file |
| 01 | | the Mayon art pipeline: `tools/build_mayon.py`, the delivered originals in `LEVEL5_Mayon/` |
| 02 | | the drain (white, then blank), the ash, the tremor |
| 03 | | the brush refuses (a quiet mode in `DrawPanel`) |
| 04 | | generic enablers: the hidden reserve, silent saves, the gauge always shown, a level that ends with its own scene, Lolo's thinness, the fifth flower, the run's leaning |
| 05 | | the shell: data, dialogue, scenes, `level_5.gd`, the audit |
| 06 | | **Act Two playable** — the corridor, the fragments, Lolo's thread, Lolo goes |
| 07 | | Act One — the ascent |
| 08 | | Act Three — the summit |
| 09 | | the frame returns, and the quiet end |
| 10 | | shipping: on the hub, `ends_run` moved from Dilim, the stats screen retired, docs, the full run |

The doc's own order: the drain first (the only thing that could fail technically), then Act Two
(the heart), then Lolo's thread, then the summit. **If scope gets tight, shorten the climb; never
Act Two.**

## Starting numbers (measured against R1 jump 94.3 px, R2 running jump 228 px)

- **Ink:** 6, no refills, one per drawing, a form drains 0.25/s. The climb costs two, so a careful
  player reaches the corridor with four — four of twelve.
- **Gates:** the span 300 px across (a bridge is 340, a running jump 228); the wall 220 px (stairs
  reach 270, a ladder 338, a tree 362); ≥180 px of floor before each (R7). Everywhere else the
  mountain rises ≤ 90 px a step.
- **Fragments:** twelve, ~520 px apart. Each goes white 45 s after she first sees it, and in 4 s
  once she is 600 px past it — there is no going back down.
- **Lolo:** thinner by the act (0.25 / 0.45 / 0.7 of the way gone); a fragment with him in it
  steadies him for 60 s. He goes either way.
- **Refusals:** if she does not raise the brush herself, the apo does after 8 s; a refused stroke
  fades over 1.2 s.

## Gate classes clear BR-7 (held-out recall, `model/metrics.json`)

span: bridge .856 · ladder .961 — climb: stairs .915 · ladder .961 · tree .883. Fragment accept
sets are drawn from: door .936 · key .875 · cloud .852 · sun .894 · fan .789 · campfire .853 ·
flashlight .888 · tree .883 and the sea creatures. No Mayon gate or fragment depends on frog (.576)
or bird (.669).

## Manuscript note (for the team, not the code)

- **The endings.** Mayon replaces Endings A–D as what the player sees: collectibles (the five
  flowers) choose between the standard and the perfect ending, and route history chooses the apo's
  voice at the summit. Class diversity stays telemetry. §4.5.4's ending rules and §4.2.1B's
  sentence on what selects the ending need a line each.
- **The two refusals** are the only deliberate non-recognition in the game, and they are worth a
  sentence as a design decision rather than a failure case. They also make the fifty-class
  vocabulary's lack of a person class load-bearing: adding one would break the ending.

## Where it lives

| | |
|---|---|
| The level | `game/level_5.tscn` · `game/scripts/level_5.gd` · `game/levels/level_5/level_5_environment.tscn` |
| Data | `config/level_05.json` (gates, silent checkpoints, ink economy and reserve) · `config/dialogue_l5.json` |
| The ash | `drain.gdshader` · `Drainable` · `AshFall2D` · `ScreenTremor` |
| Act Two | `MemoryFragment2D` (twelve, placed in the environment) · `tools/build_mayon_fragments.py` |
| Lolo | `Lolo.set_thinness` / `vanish` · `lolo_fade.gdshader` |
| The summit, the frame | `Lola2D` · `FrameReturn` · `tools/build_mayon_lola.py` |
| The refusal | `DrawPanel.set_refusing` / `quietly_refused` · LevelBase `_brush_refuses_here` / `_brush_refused` |
| Art | `tools/build_mayon.py` (plates, tiles, props from `LEVEL5_Mayon/`) |
| Tests | `run_level5_audit` · `run_level5_act_one_probe` · `run_level5_act_two_probe` · `run_level5_summit_probe` · `run_level5_frame_probe` · `run_level5_enablers_probe` · `run_brush_refusal_probe` · `run_drain_probe` · `run_mayon_probe` · `test_build_mayon(_fragments)` · `run_journey_probe` (Dilim → Mayon → the frame → home) |

## As built, against the design

- **Placeholders** for everything the delivery lacked -- Lola, the real room, the fragments, the
  summit -- each named in `ART_PLACEHOLDERS.md`.
- **The optional dim stretch** ("the light is going, draw one") is not built; it is off the
  critical path.
- **Updated 31 October:** a rim highlights the nearby memory, and opening the page locks its ID; the chosen picture appears outside the captured ink.
- **Updated 31 October:** the apo has dedicated raise, painting, failed, lowering, seated, offering, and brush-pickup poses. The refusal remains wordless.
- **The stats ending screen stays in the repository** but nothing reaches it; Endings A-D are
  logged to telemetry when the run ends.


## Experience overhaul 31 October 2026

The three acts and ending were already mechanically present. This pass replaces the long
single-file memory corridor with three simultaneous four-memory areas and integrates dedicated
character performances and a painted ordinary room. The first-play tuning target is **10–15
minutes**, with no timer holding the player merely to meet that target. Automated runners do not
establish a first-time player's reading, drawing, or decision time.

### The choices and their drawing context

`level_05.json` now owns `memory_clusters`, `memories`, and `layout_version: 3`. Scene fragments
carry stable IDs and positions; acceptance, Lolo membership, reach, and summit art come from the
configuration. The groups are kubo/terraces/bandaritas/dancers, church/storm/bangka/coral, and
bakunawa/forest/waterfall/flower. Each camera region shows its four pictures together above the
characters. Two shallow rises carry each cluster along the climb; the stacked memory walls have
been removed. Only the flower has a separate detour, on one-way rocks above the main path.

Whitening starts for the whole cluster on entry, takes 90 seconds to reach paper, holds during
every paused modal, and heads to
blank over four seconds on departure past the cluster's far edge; stepping back below its entry is
not departure, and its clock simply runs on. A subtle rim selects the nearby memory. Opening the page
locks that ID until the response arrives, even if the player or camera moves. The reference is a
sibling of the capture SubViewport: its pixels never reach the recognizer.

Checkpoints retain outcome, partial drain, raw polylines, save order, visited/departed clusters,
Lolo's state, and flower credit. Cluster departures replace CP1 silently. Legacy CP1/CP2 positions
and version-2 shelf saves are mapped above the rebuilt ground; existing progress and flowers
remain intact. A flower
reward's durable obstacle record prevents repeated Artist tally credit after a fall or reload.

### What the ending actually does

`DrawPanel` has normal, quiet-refusal, and free-paint modes. The two latter modes hide the frame,
buttons, reference, and gauge, take a real stroke, and complete after the hand rests. Empty pages
and cancellation never count. Free paint returns the vectors through its own signal rather than
pretending to be another refusal. Both modes bypass live and submitted recognition entirely.

The apo raises the brush, paints, sees it fail, and lowers it through registered performance
poses. `DialogueBox.line_progress` lets Lolo vanish as his interrupted sentence is revealed,
including when a reader reveals the text with a click; dismissal does not control his going.
At the summit, weather audio stops, the camera frames the pair, ordinary prompts disappear,
and the last free drawing remains alongside the larger saved landscapes and their saved ink.
Lola turns, receives flowers when earned, and turns back after the recognition passes. The room
shows both seated actors and a distinct pickup/ordinary-brush pose before the cut to black.

### Artwork and audio provenance

Original generated atlas and room sources, exact prompts, and replacement contracts are in
`LEVEL5_Mayon/authored/README.md`. `build_mayon_performance.py` produces the registered actor
poses, Lola's full-resolution portrait, and the room. The landscape and restoration builders own
the scenery. The old
`build_mayon_lola.py` delegates to it; it no longer recolours the apo. `build_mayon_audio.py`
synthesizes the original eruption, wind, brush contact, and ending cue. No third-party recordings
or existing musical melody are used. See the authored README for the complete provisional list:
generated art awaiting art-direction review, procedural memory targets, reused restoration
scenery, synthetic audio rather than recordings, and the absent recorded Lola voice.

### Checks added

`run_level5_overhaul_probe` checks clustered activation, paused clocks, target locking, exact
checkpoint ink and ordering, irreversible departures, duplicate flower credit, reserve isolation,
empty/cancelled attempts, quiet/free mouse strokes without model calls, and a mid-line Lolo cut.
`run_walk_level5` drives movement: neither bare gate opens, a bridge and a resized/rotated ladder
cross the gap, and stairs and a ladder reach the wall. The walking probe caught a genuine fall
wrap bypass: the rescue threshold now fires before Wanderer wraps from the world's bottom to its
top. `run_visual_level5` captures the actual scene at 1600x900, including all clusters, quiet
canvas, summit, restored places, flowers, room, and ordinary brush. It fails if injected mouse
input never reaches the canvas. `run_level5_frame_probe` also checks the visible brush action.

The audit frees its scene before exit. Godot 4.7 still reports retained static GDScript resources
at shutdown in that audit; explicit scene cleanup and `@static_unload` did not remove those
engine diagnostics. The latter workaround was reverted. They must be distinguished from parse,
script, or signal-call failures, rather than hidden from the log. The unrelated ability audit
currently lacks `TAG_NEEDS` definitions for `absurd`, `beast`, and `hoof`.

The old crossing now begins draining at x1800 over 1.2 seconds, inside the camera view and
before the earliest running arrival; its arrival line has a separate narrow volume. The summit
stows a pending placement/tool, stops an active tremor, stages a returning wanderer beside Lola,
and blocks ordinary input through the performance while preserving Escape and the intended
quiet/free drawing attempts. `run_level5_endings_probe` covers all three voices in both endings,
zero ink/no saved memories, selected memory order, sealed performance input, and a legacy CP2.

### Landscape revision after visual review

The first overhaul's mechanical checks passed while its scenery still exposed the prototype:
separate background bands floated apart vertically, fine soil tiles covered every surface, and
memory shelves were thin floating bars. The runtime now uses `MayonVista2D`: the measured foot
composition flattened once, then a transition to an original upper-slope plate. The generated
cliff atlas provides three broad materials. The later flat polygon fills and straight grass
outline were reverted to match the user's preferred opening screenshot. The cliff silhouette
remains decorative beneath the walk surface. The original crossing and steps now have dedicated sprites from the ruin
atlas. The target highlight follows torn artwork instead of a rounded UI-card frame.

Travel and memory dialogue keep the wide camera composition: a push-in must not crop the four
choices or pull the walk line upward. Lolo's last sentence alone holds the world figures above
the dialogue box at the same landscape scale, then releases that framing when dismissed.
`run_level5_memory_walk` drives the three shallow climbs, checks
target access and framing, takes the optional flower path, and checks old shelf-save landings.

The summit restores transparent scenery from the earlier levels rather than magnifying torn
rectangular pictures. Each memory owns its width, elevation and optional tint in the JSON.
**`Motion.fade_in` calls `_show`, which resets Node2D scale to one.** A landscape's measured scale
must be reapplied after that call; otherwise the church and terraces expand to their full source
pixel dimensions and engulf the pair. The ending probe now measures the rendered widths. Summit
narration keeps the wide composition, and the ordinary room fits pictures into its canvas while
preserving their aspect ratios. Sources, exact generation prompts and replacement contracts are
in the authored README. All newly generated landscape and prop art remains explicitly subject
to art-direction review; the runtime contains the assets now.

### Dedicated cliff edge textures

Mayon's meadow, basalt and ash now have purpose-made transparent edge artwork. The generated
three-column `LEVEL5_Mayon/authored/cliff_edges.png` uses the existing cliff atlas as a style and
material reference. `build_mayon_landscape.py` cuts `terrain/edge_meadow.png`, `edge_basalt.png`
and `edge_ash.png`, with nearest filtering and preserved alpha/aspect ratio.

`MayonTerrain2D` places these caps on exposed risers and gap edges, mirroring them for right-hand
ends. The 220px wall receives a uniform enlargement; ordinary steps keep the art's natural size.
The earlier warped UV join mesh and procedural cap outline have been removed. Contacts are
still discovered across Slopes and Cone. Real gaps and detached flower rocks stay separate.
All caps inherit the owning terrain's tint/drain material and add no collision.

`run_visual_mayon_edges` photographs meadow steps, the ascent, span, climb wall, memory steps,
ash, and the whitening transition at 1600x900. This artwork pass was inspected in those frames;
the full gameplay suite was not rerun for a drawing-only change. The generated source, exact
prompt and replacement contract are recorded in the authored README and placeholder inventory.

### Finishing pass

The rebuilt ground was checked as one continuous journey, from the spawn to the room return.
`run_level5_finish_walk` walks the actual terrain, places the span/climb answers, saves terraces,
church, bangka and flower, takes the flower detour, draws the three quiet attempts and the free
painting through viewport input, and reaches the seated room and ordinary brush. Normal model
results are supplied as fixtures; this validates layout and story flow, not CNN accuracy or a
first-time player's 10–15 minute reading/drawing pace. The route spent all six visible units and
the quiet/free pages added no recognition statistics.

This pass corrects the old room bounds left behind by checkpoint restoration, restores stopped
weather audio on an earlier landing, removes transient free-paint scenery on reset, seats the
last ruin on its actual ground, and removes the empty checkpoint flag from silent-save HUDs.
The apo faces Lola and approaches within reach for the flower handoff; unobstructed beats show
her turn, receipt and return to painting. Lolo's portrait vanishes with his world sprite, while
his unfinished sentence remains. Portrait fade cancellation also prevents an outgoing portrait
from hiding the next speaker. The room and its seated actors now share one aspect-preserving
composition on taller windows. Summit whitening finishes during dialogue; memory clocks still
pause with gameplay.

Focused validation: continuous finish walk, memory traversal and camera reload, both flower
endings across all three voices, and the dialogue portrait transition probe. The visual tour
includes disappearance, handoff, brush pickup, and a 1600x1000 room frame. It finishes the staged
narration before freeing the scene, avoiding retained story coroutines at shutdown. No full-suite rerun was
used for this finishing pass; generated/provisional artwork and synthesized audio remain listed
in the authored README and `ART_PLACEHOLDERS.md`.
