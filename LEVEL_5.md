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
- **Nothing shows which fragment a drawing will go into**: the nearest one in reach takes it. A
  soft highlight on it is the obvious follow-up.
- **The apo has no failed-draw or lowering pose**; the page refuses, and the beat is silent.
- **The stats ending screen stays in the repository** but nothing reaches it; Endings A-D are
  logged to telemetry when the run ends.

