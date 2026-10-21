# Level 4 — Dilim

**Status: BUILT, on the hub, and the level the run ends on** (until Mayon is built). Shipped in
PRs #79–#97, merged 2026-10-18/19. This file was the design record and the build order; it is the
build record now -- the design as decided, then [where it lives](#where-it-lives) and
[how the build differs from the design](#as-built-against-the-design). Read `LEVEL_TEMPLATE.md`
first; this file holds only what is specific to Dilim.

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
| Choosing a route | **By what you do — no popup.** Drawing a light at the sigbin *is* the artist choice; backing against the rock *is* pragmatic; landing a hit *is* protector. A popup would freeze a fight. **And it stays open until one is answered** (as built): a blade swung first and then a light is the light (`LevelDirector.routes_stay_open`). |
| The tally | Every encounter's route is logged for the thesis telemetry, but the ending gets **one point from Dilim**: its majority route. Six forks must not decide the ending alone. |
| "Absurd" | The bungisngis laughs itself helpless at **sea things in a forest**: fish, shark, octopus, sailboat, submarine. The game can only see a class, so the joke had to be a set of classes. |
| Quick slots | Four, on **Z X C V**. Z/X rotate a drawing only while placing, and quick slots are off while placing. |
| Creature art | **Sculpted pixel strips**, in the delivered art's idiom: chibi like the apo, cel-lit from the upper left, each part edged in a darker tone of its own colour (`tools/creature_sculpt.py`). Replaceable by name when the art team delivers -- and three are now theirs: the kapre, the manananggal and a white lady as the lean aswang (`Creatures.zip`, cut by `tools/build_dilim_delivered.py`). |
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
→ the ending (Dilim carries `ends_run` until Mayon is built)
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

## Build order, as shipped (each a PR that shipped green; every new behaviour is a LevelBase hook that defaults off)

| | PR | |
|---|---|---|
| 01 | #80 | this file |
| 02 | #81 | swim polish |
| 03 | #79 | weapons hit once, where they point (also fixes Dagat) |
| 04–06 | #82 #83 #84 | combat core: the apo can be hurt · weapons in a fight · enemies |
| 07 | #85 | darkness, light, lantern HUD, edge ripple |
| 08 | #87 | Makiling art pipeline |
| 09 | #86 | generic enablers (no companion, speaker, majority tally, tags, flower) |
| — | #88 | overlap-safe test runs (not in the plan) |
| 10 | #89 | level shell + audits |
| 11 | #90 | **playable slice** (Segment 1, rest clearing, finale wave 1 to dawn) |
| 12 | #91 | collectibles: the satchel and quick slots |
| 13 | #92 | Segment 2: sigbin, tikbalang, kapre |
| — | #93 | the aswang dark, not black (a follow-up the design asked for) |
| 14 | #94 | Segment 3: tiyanak, bungisngis, manananggal |
| 16a | #95 | on the hub: `scene_path`, and `ends_run` moved from Dagat to Dilim in one commit with every test that assumed the old ending |
| 16b | #96 | Dilim behind the home screen |
| 15 | #97 | the finale complete: three waves, the tik-tik, the dead tree, the buntot pagi |
| 16 | — | shipping: this file, the other docs, the full suite run |

The full plan, with files, hooks, tuning numbers and tests per PR, is kept by the developer
alongside this file; the numbers below are its starting points.

## Starting numbers (measured against R1 jump 94.3 px, R2 running jump 228 px)

- Lantern light radius 230 / 190 / 150 / 110 px (it was 380 / 290 / 200 / 130 and lit most of
  the screen) -- smaller than a drawn campfire's 300, so a light she makes opens the dark wider ·
  1.0 s invulnerability after a hit (2.0 after respawn) · knockback (±300, −220) with a 0.22 s
  input lock-out.
- The dark, by zone: edge of the woods 0.95, deep woods 0.97, far side 0.96, last clearing 0.96
  (Kent, 2026-10-19: "truly dark"). She comes in with the lamp at its second stage, and the first
  clearing's light fills it; a Continue starts full, at a clearing.
- Weapons (uses / damage / reach px / arc°): sword 14/1/88/120 · axe 9/2/96/150 · boomerang
  8/1 per target/320 · cannon 5/3/640 · anvil 3/4/56 below.
- Every enemy is slower than the apo's 260 px/s, and every attack is telegraphed (≥0.4 s).
- Geometry: the nuno's mound 150 wide (jumpable) · the tiyanak's drop and the bungisngis's
  ravine 300 wide (not jumpable; under the bridge's 340) · canopy 440 up (over the tree's 362).

## Where it lives

| | |
|---|---|
| The level | `game/level_4.tscn` · `game/scripts/level_4.gd` (every Dilim behaviour, as LevelBase hooks) · `game/levels/level_4/level_4_environment.tscn` (ground, branches, the encounters placed) |
| Data | `config/level_04.json` (beats, routes, `"tally": "majority"`) · `config/dialogue_l4.json` (every line hers) · `config/enemies.json` · `config/weapons.json` (Dilim's rows) · `config/satchel.json` |
| The dark | `LightField` (what is lit, the gameplay truth) · `DarknessLayer` + `darkness.gdshader` · `HeldLantern2D` (the lantern is her health) · `LanternHud` · `EdgeRipple` (sounds shown) |
| Combat | `PlayerHealth` · `PlayerHurtbox2D` · `Telegraph2D` (every windup ≥ 0.4 s) · `WeaponTable` · `Enemy2D` → `GroundEnemy2D` / `FlyingEnemy2D` (group `dilim_encounters` for restores, `dilim_foes` for ash and salt) |
| Segment 1 | `Santelmo2D` · `NunoMound2D` |
| Segment 2 | `Sigbin2D` · `Tikbalang2D` · `Kapre2D` · `InkJar2D` |
| Segment 3 | `Tiyanak2D` · `Bungisngis2D` · `ManananggalUpper2D` / `ManananggalLower2D` |
| The finale | `DilimFinale2D` (the clock, the three waves, the dead tree) · `DawnClockHud` · `Wakwak2D` · `Tiktik2D` · `DeadTree2D` (`art_kind = "dead_tree"`, Dilim's own, drawn; `stands_solid` off) |
| Lola's things | `Satchel` · `SatchelPickup2D` · `QuickSlotBar` · `AsinThrow2D` · `AboDust2D` · `BawangWard2D` · `CandleFlame2D` · `WhipLash2D` |
| Art | `MakilingBackdrop2D` · `MakilingTerrain2D` · `PixelStripAnimator` · `tools/build_dilim.py` (plates, tiles) · `tools/build_dilim_creatures.py` (the sculpted creatures, the kapre's balete, smoke and cigar) · `tools/build_dilim_delivered.py` (the art team's: the kapre, the manananggal, the white lady) · `tools/build_dilim_props.py` (satchel icons) |
| Tests | `run_level4_audit` · `run_level4_enablers_probe` · `run_level4_seg1/seg2/seg3_probe` · `run_level4_finale_probe` · `run_level4_tiktik_probe` · `run_level4_whip_probe` · `run_satchel_probe` · `run_combat_probe` · `run_enemy_probe` · `run_weapon_probe` · `run_darkness_probe` · `run_makiling_probe` · `run_journey_probe` (Dagat → house → Dilim → dawn → ending) · windowed looks `run_visual_dilim_light`, `run_visual_makiling`, `run_visual_dilim_creatures` |

## As built, against the design

What the build does that the design above does not say, and what it does not do yet:

- **Creature art.** Three are the art team's (`Creatures.zip`, 2026-10-20, kept as delivered in
  `LEVEL4_Creatures/`, cut by `tools/build_dilim_delivered.py`): the kapre, the manananggal (both
  halves) and a white lady, who is the lean aswang (Kent, 2026-10-21). Every other is a sculpted
  strip a developer drew -- the old aswang, santelmo, nuno's mound, sigbin, tikbalang, the kapre's
  balete (standing and felled), tiyanak, bungisngis, wakwak and tik-tik -- standing in for an
  artist's (`ART_PLACEHOLDERS.md` names every strip; `run_visual_dilim_creatures` lays them side by
  side in her light). Each script's own code-drawn body is the fallback while a strip is missing. Her hurt
  and attack poses are placeholders made from the delivered sheet (the jump and wave frames,
  leaned).
- **The aswang is the thing itself, not a dog or a pig** (Kent, 2026-10-20: an aswang "if you search
  the internet is not like that"). The two kinds the waves send keep their names and settings:
  `aswang_dog` is now the art team's white lady -- long black hair, a pale face, a bloodied white
  kimono, gliding at her -- and `aswang_pig` an old, hulking, humped crawler, its hair streaked grey.
- **The kapre in its tree** (Kent, 2026-10-20: "more detailed and make more sense"; the art team's
  kapre since 2026-10-22). It stands on a branch of the balete 170 px up -- its sheet calls it "small
  in form, but still strangely imposing", and it stands half again her height (Kent, 2026-10-22:
  "make the kapre bigger") -- facing her. Its cigar's hit area is where the
  cigar is drawn, seen end on in its teeth. Its light is two: the ember's own, a few px round it,
  and a short cone from its lips up over its face. A light shows whatever is behind it, and up
  there that is the backdrop's sky, so the air round its head stays dark. Its smoke is a drawn bank of puffs pouring off the cigar. Each
  answer is seen:
  - fanned, the smoke blows away east and up;
  - knocked, the cigar tumbles down, lit by its ember alone, then lights the ground round it
    until it goes out; the kapre climbs up into its crown;
  - felled, the kapre drops with the cigar still in its teeth, its ember lighting it down, and
    walks off east on its walk cycle. Gone, its cigar is out of reach.

  A boomerang or a shot thrown by a click reaches the cigar from anywhere in the smoke's west
  half (13300-13480), short of the middle that turns her round.
- **The finale's numbers.** The night is 150 s: waves at 0 / 45 / 100 s, dawn at 150. A drawn sun
  brings dawn 15 s nearer, once a wave. The manananggal is driven off at 8 in its wave.
- **The dead tree** is the woods' own, drawn in the balete's bark (Level 1's was standing in). It
  stands at the clearing's middle and falls east into a 64-px log that shuts the east side; a felled tree stays down through a knockout, so a retried night starts with it shut.
- **The tik-tik** is shown by ash for the dust's 6 s and blinded for 1.5 s; inside 220 px of her
  lantern the HUD leans and gutters and the light drops 18%.
- **The buntot pagi** drops only in waves 2 and 3 (2%), lashes 10 times, and reaches fliers. Its
  lashes left are saved with the run, and every lash flashes its quick slot and is logged.
- **What to do is said where it is done** (Kent, 2026-10-19: "the game's instructions are all
  unclear"). Inside an encounter not yet answered the banner names Lola's three ways past it, no
  class named ("Show it light, put my back to a rock, or fight it."), each at the banner's full
  size; the first of each of Lola's things says what it does and its key ("Kandila -- a candle. X
  sets it down: light that costs no ink."); the santelmo's walk is taught ~3 s before it can see
  her, and the first salt lies past it so nothing takes the hint bar from that.
- **No "?" boards.** They promised Lolo's help, and stood on the creature; every beat keeps its
  story board at its approach (`LevelObstacle2D.plants_hint_sign`).
- **A clearing is saved as she walks in**; its lantern stands where the light is made and her light
  lights it (`CheckpointArea2D.lights_on_entry`), with the lamp filled and a curse lifted.
- **The mound is asked from its foot** (56 px), where a jump from standing clears it.
- **The sigbin keeps to its ground** (a 700 px leash); it gave chase into the tikbalang's.
- **The kapre's camera hold** was replaced: its smoke turns her round instead of stopping the camera.
  Anything the artist route takes as moving air clears it -- a fan, a cloud, a sun, her as a
  butterfly -- not a fan alone.
- **A throw goes where it is clicked.** A boomerang flies out along the click, a shot is fired at
  it (aimed over by its fall); F throws straight ahead as before. Thrown level, nothing reached the
  kapre's cigar. And the use that chooses a "draw it, then do it" route is used: the first blow at
  the sigbin lands and the first throw at the cigar is thrown (they had only chosen). A cannon shot
  is put at the muzzle before it is in the world -- added first, every shot began inside the canopy.
- **Falls are knockouts.** The wanderer wraps to the sky at the world's bottom, so Dilim knocks her
  out 300 px under the forest floor instead.
- **No drawing-free run.** The kapre has no route without a drawing, so Dilim cannot be finished
  without one -- by design -- and there is no `run_nodraw_level4`.
- **The Makiling tileset** is used in part: the six plates and four seamless tiles; no slopes, root
  or log platforms, waterfall or props. The vine frame plate stands only behind her (in front of
  play it hid her).

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
