# Level 4 — Dilim

**Status: DESIGNED, NOT BUILT.** This file is the design record and the build order. It turns
into the build record as the PRs below land. Read `LEVEL_TEMPLATE.md` first; this file holds
only what is specific to Dilim.

**Sources.** `Level 4 Dilim Design.docx` (first refined pass) and its flowchart
(`Level4_Dilim_Flow.mermaid`, BPMN shapes like Levels 2 and 3), the delivered art
`Mt Makiling Level 4.zip` (forest plates + a labelled tileset; **no creature art**), and twelve
decisions Kent made on 2026-10-15/16 when the doc's open questions were put to him.

---

## The level in one paragraph

Cross a dark forest on Mt. Makiling to the far side. Levels 1–3 solved problems by drawing;
**Dilim fights by drawing.** Lolo left at the end of Dagat because this forest is past what he
remembers, so every line is the apo talking to herself — remembering what lola taught her about
the things that live here. The forest is dark, sight is short, and light is something she draws.
Three segments with a rest clearing between each, then a final clearing where the aswangs come
in three waves until dawn.

## Decisions (Kent, 2026-10-15/16) — do not re-litigate

| | |
|---|---|
| Who fights | The apo, **in her own body**, with drawn weapons. Transforming is a tool (the tikbalang's pragmatic counter), not the combat mode. |
| Health | **The lantern is health.** Four stages: full, dim, low, guttering. A hit knocks the flame down a stage and the light circle around her shrinks with it. A hit while guttering sends her back to the last checkpoint. |
| Death | The game's first. Back to the last checkpoint; **ink and drawings roll back** to what they were there; **collectibles are kept**. The line is lola's voice: "Lola said the woods take people who stop paying attention." |
| Finale | **Survive until dawn** — a clock, not a kill count. Folklore-accurate and forgiving of retries. |
| Weapons | A drawn weapon lasts a **set number of swings per class** (a wear bar), then you draw again. Dilim only; every other level keeps one-use tools. |
| Ink | **Every weapon or light drawn costs ink** in Dilim (the usual "a class is paid once, ever" does not apply here). Rest clearings refill it. Ink is the real difficulty curve. |
| Choosing a route | **By what you do — no popup.** Drawing a light at the sigbin *is* the artist choice; backing against the rock *is* pragmatic; landing a hit *is* protector. A popup would freeze a fight. |
| The tally | Every encounter's route is logged for the thesis telemetry, but the ending gets **one point from Dilim**: its majority route. Six forks must not decide the ending alone. |
| "Absurd" | The bungisngis laughs itself helpless at **sea things in a forest**: fish, shark, octopus, sailboat, submarine. The game can only see a class, so the joke had to be a set of classes. |
| Quick slots | Four, on **Z X C V**. Z/X rotate a drawing only while placing, and quick slots are off while placing. |
| Creature art | **Code-drawn animated pixel strips** (2-px grain, 48-px frames), the way the lanterns, signs and Dagat's sea creatures were made. Replaceable when the art team delivers. |
| Defaults taken | Shift = walk (the santelmo's rule needs one). The opening is design Draft A, naming the manananggal and the tikbalang, played as the level's intro. |

## Flow

```
Painting → intro (Draft A) → rule: dark, short sight, light costs ink → CP0
SEGMENT 1  edge of the woods — hazards, no combat
           SANTELMO  a flame follows; running makes it faster, walking loses it
           NUNO SA PUNSO  stop + "tabi-tabi po" + go around = ARTIST → flower 4 of 5
                          walk around = PRAGMATIC · step on it = cursed (slowed, lantern drains)
REST 1     draw a light (campfire) → lantern + ink refill → CP1
SEGMENT 2  deep forest — movement and orientation
           SIGBIN      light = ARTIST · back to a wall = PRAGMATIC · strike the shadow = PROTECTOR
           TIKBALANG   draw a horse = ARTIST · become any animal = PRAGMATIC · race it = PROTECTOR
           KAPRE       a fan clears the smoke = ARTIST · fell its tree = PRAGMATIC · knock the cigar = PROTECTOR
REST 2     → CP2
SEGMENT 3  the far side — real combat
           TIYANAK     light = ARTIST · stay on the path = PRAGMATIC · fight it (allowed, never rewarded) = PROTECTOR
           BUNGISNGIS  something absurd = ARTIST · a bridge/way over = PRAGMATIC · fight it = PROTECTOR
           MANANANGGAL a sun = ARTIST · salt the lower half = PRAGMATIC · drive off the upper half = PROTECTOR
CP3        FINAL CLEARING — aswang waves until dawn
           W1 two aswang (dog / pig) · W2 + manananggal and wakwak (fliers) · W3 the TIK-TIK
→ on to Mayon
```

**Every encounter has a non-combat resolution.** Combat is survivable without combat skill.

## Rules this level adds

- **No story line mid-encounter.** A dialogue line pauses the whole tree; during a fight the
  apo speaks through the hint bar only. The level audit enforces this.
- **Every audio cue has a visual equivalent.** The tik-tik's call (gets quieter as it closes) is
  an edge ripple that shrinks as it nears, then the lantern leans and gutters when it is nearly on
  her — a positive tell, never an absence. The tiyanak's cry is an amber ripple plus a rustle in
  the undergrowth.
- **The canopy blocks flight physically** (a ceiling ~440 px up), not by a rule.
- **No damage numbers.** Hit flashes and knockback.
- **Cultural guardrails:** the nuno's mound gets nothing — no hurtbox, no protector route. The
  tiyanak fight earns nothing — no drops. The aswangs are authored encounters, not drawable
  classes (the same framing as Dagat's bakunawa).

## Collectibles (lola's, not the brush's — none is drawable)

| | |
|---|---|
| Asin (salt) | Thrown, burns over time. The only thing that kills a manananggal's lower half. |
| Bawang (garlic) | Area repellent; anything that hunts by smell will not cross it. Buys room to draw. |
| Langis (lamp oil) | Refills the lantern. The only healing; never drops during the finale. |
| Abo (ash) | A cloud that reveals what hides in shadow. The only counter to the tik-tik. |
| Kandila (candle) | Portable light that costs no ink; burns down. |
| Buntot pagi (stingray tail) | A whip. High damage, limited uses, rare. |

## Build order (each a PR that ships green; every new behaviour is a LevelBase hook that defaults off)

00 merge the open work · 01 this file · 02 swim polish · 03 weapons hit once, where they point
(also fixes Dagat) · 04–06 combat core (the apo can be hurt; weapons in a fight; enemies) ·
07 darkness, light, lantern HUD, edge ripple · 08 Makiling art pipeline · 09 generic enablers
(no companion, speaker, majority tally, tags, flower) · 10 level shell + audits ·
**11 playable slice (Segment 1, rest clearing, finale wave 1 to dawn) — Kent plays here** ·
12 collectibles · 13 Segment 2 · 14 Segment 3 · 15 finale complete · 16 shipping
(`scene_path` last; `ends_run` moves from Dagat to Dilim in one commit with every test that
assumes the old ending).

The full plan, with files, hooks, tuning numbers and tests per PR, is kept by the developer
alongside this file; the numbers below are its starting points.

## Starting numbers (measured against R1 jump 94.3 px, R2 running jump 228 px)

- Lantern light radius 380 / 290 / 200 / 130 px · 1.0 s invulnerability after a hit (2.0 after
  respawn) · knockback (±300, −220) with a 0.22 s input lock-out.
- Weapons (uses / damage / reach px / arc°): sword 14/1/88/120 · axe 9/2/96/150 · boomerang
  8/1 per target/320 · cannon 5/3/640 · anvil 3/4/56 below.
- Every enemy is slower than the apo's 260 px/s, and every attack is telegraphed (≥0.4 s).
- Geometry: the nuno's mound 150 wide (jumpable) · the tiyanak's drop and the bungisngis's
  ravine 300 wide (not jumpable; under the bridge's 340) · canopy 440 up (over the tree's 362).

## Gate classes clear BR-7 (held-out recall, `model/metrics.json`)

sun .894 · fan .789 · horse .870 · bridge .856 · campfire .853 · flashlight .888 · sword .922 ·
axe .916 · boomerang .919 · cannon .793 · anvil .885 · tree .883 · ladder .962. No fallback
class is needed. (Only frog .576 and bird .669 sit under the 0.70 floor, and no Dilim gate
depends on either.)

## Manuscript note (for the team, not the code)

The thesis holds that the draw-to-ability mechanic is culturally neutral and that Philippine
content sits in the setting and story. Six folkloric creatures with folklore-specific counters
move mythology into encounter design. The design doc recommends narrowing the neutrality claim
to the recognition and ability pipeline — which stays neutral, since the 50 classes are ordinary
objects and animals — and acknowledging that one level's encounters are culturally specific.
The Cultural Content Questionnaire then has the six creatures to assess, not one aswang.
