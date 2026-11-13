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
remembers, so every line is the apo talking to herself. What lola taught her about the things
that live here is **in lola's own hand**: her bestiary, a page of her diary found a few steps in,
which opens at each creature's page the first time she reaches it (2026-11-01, `DIARY.md`; Kent:
"instead of the apo saying 'lola said this' lola said that"). So no line says "Lola said" any
more; the apo says what she sees. The forest is dark, sight is short, and light is something she
draws.
Three segments with a rest clearing between each, then a final clearing where the aswangs come
in three waves until dawn.

## Decisions (Kent, 2026-10-15/16) — do not re-litigate

| | |
|---|---|
| Who fights | The apo, **in her own body**, with drawn weapons. Transforming is a tool (the tikbalang's pragmatic counter), not the combat mode. |
| Health | **The lantern is health.** Four stages: full, dim, low, guttering. A hit knocks the flame down a stage and the light circle around her shrinks with it. A hit while guttering sends her back to the last checkpoint. |
| Death | The game's first. Back to the last checkpoint; **ink and drawings roll back** to what they were there; **collectibles are kept**. The line is hers: "The woods take the ones who stop paying attention." (it was "Lola said…" until her bestiary, 2026-11-01) |
| Finale | **Survive until dawn** — a clock, not a kill count. Folklore-accurate and forgiving of retries. |
| Weapons | A drawn weapon lasts a **set number of swings per class** (a wear bar), then you draw again. Dilim only; every other level keeps one-use tools. |
| Ink | **Every weapon or light drawn costs ink** in Dilim (the usual "a class is paid once, ever" does not apply here). Rest clearings refill it. Ink is the real difficulty curve. |
| Choosing a route | **By what you do — no popup.** Drawing a light at the sigbin *is* the artist choice; backing against the rock *is* pragmatic; landing a hit *is* protector. A popup would freeze a fight. **And it stays open until one is answered** (as built): a blade swung first and then a light is the light (`LevelDirector.routes_stay_open`). |
| The tally | Every encounter's route is logged for the thesis telemetry, but the ending gets **one point from Dilim**: its majority route. Six forks must not decide the ending alone. |
| "Absurd" | The bungisngis laughs itself helpless at **sea things in a forest**: fish, shark, octopus, sailboat, submarine. The game can only see a class, so the joke had to be a set of classes. |
| Quick slots | Five, on **Z X C V B** (four until 2026-11-06, when Kent added B: the lamp oil, found last, had no key in any run that saved everything). Z/X rotate a drawing only while placing, and quick slots are off while placing. |
| Creature art | **Sculpted pixel strips**, in the delivered art's idiom: chibi like the apo, cel-lit from the upper left, each part edged in a darker tone of its own colour (`tools/creature_sculpt.py`). Replaceable by name when the art team delivers -- the kapre, the manananggal and a white lady as the lean aswang came in `Creatures.zip`; the crawling aswang, tikbalang and tiyanak sheets were supplied on 2026-11-01, and the repaired-arm bungisngis, wakwak, sigbin and nuno on 2026-11-04. All ten are cut by `tools/build_dilim_delivered.py`. |
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
- **The canopy blocks flight physically** with an invisible ceiling 440 px up. The forest
  backdrop supplies the visible trees.
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
| Abo (ash) | A cloud that reveals what hides in shadow, there or flying in while it hangs. The only counter to the tik-tik. |
| Kandila (candle) | Portable light that costs no ink; burns down. A light like any other: it answers what a drawn light answers. |
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
| Combat | `PlayerHealth` · `PlayerHurtbox2D` · `Telegraph2D` (every windup ≥ 0.4 s) · `WeaponTable` · `Enemy2D` → `GroundEnemy2D` / `FlyingEnemy2D` (group `dilim_encounters` for restores, `dilim_foes` for ash and salt) · `FoeHealthBars` (a pip a blow over each foe, `Enemy2D.shows_health`) |
| Segment 1 | `Santelmo2D` · `NunoMound2D` |
| Segment 2 | `Sigbin2D` · `Tikbalang2D` · `Kapre2D` · `InkJar2D` |
| Segment 3 | `Tiyanak2D` · `Bungisngis2D` · `ManananggalUpper2D` / `ManananggalLower2D` |
| The finale | `DilimFinale2D` (the clock, the three waves, the dead tree) · `DawnClockHud` · `Wakwak2D` · `Tiktik2D` · `DeadTree2D` (`art_kind = "dead_tree"`, Dilim's own, drawn; `stands_solid` off) |
| Lola's things | `Satchel` · `SatchelPickup2D` · `QuickSlotBar` · `AsinThrow2D` · `AboDust2D` · `BawangWard2D` · `CandleFlame2D` · `WhipLash2D` |
| Art | `MakilingBackdrop2D` · `MakilingTerrain2D` · `PixelStripAnimator` · `tools/build_dilim.py` (plates, tiles) · `tools/build_dilim_creatures.py` (the sculpted creatures, the kapre's balete, smoke and cigar) · `tools/build_dilim_delivered.py` (the art team's: the kapre, the manananggal, the white lady) · `tools/build_dilim_props.py` (satchel icons) |
| Tests | `run_level4_audit` · `run_level4_enablers_probe` · `run_level4_seg1/seg2/seg3_probe` · `run_level4_finale_probe` · `run_level4_tiktik_probe` · `run_level4_whip_probe` · `run_satchel_probe` · `run_combat_probe` · `run_enemy_probe` · `run_weapon_probe` · `run_darkness_probe` · `run_makiling_probe` · `run_journey_probe` (Dagat → house → Dilim → dawn → ending) · windowed looks `run_visual_dilim_light`, `run_visual_makiling`, `run_visual_dilim_creatures`, `run_visual_level4_clock` |

## As built, against the design

What the build does that the design above does not say, and what it does not do yet:

- **Creature art.** Three are the art team's (`Creatures.zip`, 2026-10-20, kept as delivered in
  `LEVEL4_Creatures/`, cut by `tools/build_dilim_delivered.py`): the kapre, the manananggal (both
  halves) and a white lady, who is the lean aswang (Kent, 2026-10-21). A fourth supplied sheet,
  `LEVEL4_Creatures/ASWANG/aswang.png` (2026-11-01), replaces the old/hulking aswang with a pale,
  black-haired crawler with a long red tongue. The supplied `tikbalang.png` followed the same day,
  with four breathing and four race-running poses at its existing scale; its dark mane is kept
  opaque with source matte landmarks. `tiyanak.png` supplies the crying baby, six transformation
  poses and the monster's crawl, snarl, leap, attack and hurt poses. `bungisngis.png`
  (2026-11-04, repaired-arm sheet) replaces the giant's eight strips: breathing, walking,
  raised-club windup, slam, hurt, fading death, laughing and crouching aside. Its green skin,
  dark outline and mouth stay opaque; explicit masks remove labels and impact marks without
  deleting character colours. The real gap between its thighs stays transparent. Its walk
  cycle matches its standing height and the green feet anchor it, so the grounded club does
  not pull the body sideways. `wakwak.png` (2026-11-04) supplies four front-hover poses,
  five rightward flight poses, a raised-wing windup, two talon strikes and two hurt poses;
  death fades and drops a hurt pose. Gold beak/talons and every blue feather pixel are kept,
  the dark upper-wing pocket is restored from source RGB, and black feather tips are not
  trimmed as floor shadows. Real gaps between feathers and talons stay clear. `sigbin.png` (2026-11-04) supplies
  breathing, five walk frames, bite windup, lunge, hurt and fading death. Brown body pixels,
  long ears and the curled tail are preserved; only the floor shadow and hurt marks go.
  Its existing shadow visibility, behind-the-player attacks and three resolutions stay the same.
  Every other is a sculpted
  strip a developer drew -- santelmo, the kapre's
  balete (standing and felled) and tik-tik -- standing in for an
  artist's (`ART_PLACEHOLDERS.md` names every strip; `run_visual_dilim_creatures` lays them side by
  side in her light). Each script's own code-drawn body is the fallback while a strip is missing. Her hurt
  and attack poses are placeholders made from the delivered sheet (the jump and wave frames,
  leaned).
- **The nuno (4 November)** uses `nuno.png`: an orange hat, beard, earthen mound and rice
  offering. He emerges as she approaches, greets tabi-tabi po, blesses a clean respectful
  crossing and folds his arms angrily when the crown is touched. All are visual responses: the
  150 x 34 collision, curse, three crossing outcomes and flower reward stay unchanged. Restore
  hides him again. Explicit extraction preserves his hat, face and beard without body holes.
- **The aswang is the thing itself, not a dog or a pig** (Kent, 2026-10-20: an aswang "if you search
  the internet is not like that"). The two kinds the waves send keep their names and settings:
  `aswang_dog` is now the art team's white lady -- long black hair, a pale face, a bloodied white
  kimono, gliding at her -- and `aswang_pig` uses the supplied crawling aswang sheet: pale skin,
  long black hair, red eyes and a long red tongue. Its breathing and walk cycles, claw windup
  and strike, and hurt poses come from that sheet; death fades a hurt pose. The internal kind
  and combat settings stay the same. Only the `aswang_pig` artwork changed on 2026-11-01.
  Its darkest hair matches the sheet's panel: source matte landmarks restore those pixels,
  including the open-ended front lock, while the gaps between the limbs stay transparent.
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
- **The tiyanak is a visible lure, then an ambush** (2026-11-01). It waits as the supplied crying
  infant, drawn in front of the bush instead of being covered by it. The baby uses 0.4 of the
  supplied sheet's size (about 50 px tall), reduced from 0.55 after the first in-game look.
  The transformation and monster poses match its visible body area: the smaller crawl drawings
  on the sheet no longer shrink it when it changes form or starts moving.
  Approaching within 120 px
  on the ground plays the six transformation poses over 0.75 s, then the monster physically
  jumps toward her. The jump parts the bush and stays by its lure; it does not deal an instant
  surprise hit. Later attacks keep their normal windup. The high path never triggers the
  ambush, a light exposes it and sends it away, and a checkpoint restore resets the disguise.
  A fight leaves no drops, as before.
- **The finale's numbers (updated 2026-11-04).** The night is 90 s: waves at 0 / 27 / 60 s,
  dawn at 90. The first 45 s stay dark; from halfway the darkness and background night tint
  gradually lift together, reaching a fully visible, warm morning at the end. Retries restore
  the night look. Morning is held for 2 s after her closing line before leaving the level.
  A drawn sun still brings dawn 15 s nearer, once a wave. The manananggal is driven off at 8.
  `run_visual_level4_dawn.gd` samples the real lighting controller at 0 / 60 / 75 / 90 s;
  the reviewed contact sheet is `docs/screenshots/dilim_dawn_progression.png`.
- **Diary defeats survive a checkpoint retry.** Salt on the Manananggal's lower half
  prevents her from returning. Driving off her upper half with a weapon lets her return
  in wave two, with the same lower half reachable west of the dead tree. Defeating the
  Tik-Tik after revealing it with ash keeps it out of later attempts. Its windup and dive
  are visible, and ash still opens it to weapon hits.
- **The dead tree** is the woods' own, drawn in the balete's bark (Level 1's was standing in). It
  stands at the clearing's middle and falls east into a 64-px log that shuts the east side; a felled tree stays down through a knockout, so a retried night starts with it shut.
- **The tik-tik** is shown by ash for the dust's 6 s and blinded for 1.5 s, at the throw or flying into
  the cloud while it hangs (1.6 s); inside 220 px of her lantern the HUD leans and gutters and the
  light drops 18%, which is her signal to throw.
- **The buntot pagi** drops only in waves 2 and 3 (2%), lashes 10 times, and reaches fliers. Its
  lashes left are saved with the run, and every lash flashes its quick slot and is logged.
- **What to do is said where it is done** (Kent, 2026-10-19: "the game's instructions are all
  unclear"). Inside an encounter not yet answered the banner names Lola's three ways past it, no
  class named ("Show it light, put my back to a rock, or fight it."), each at the banner's full
  size; the first of each of Lola's things says what it does, its key and when ("Kandila, a candle.
  X sets it at my feet: a light like any other, and it costs no ink."); the santelmo's walk is taught ~3 s before it can see
  her, and the first salt lies past it so nothing takes the hint bar from that.
- **No "?" boards.** They promised Lolo's help, and stood on the creature; every beat keeps its
  story board at its approach (`LevelObstacle2D.plants_hint_sign`).
- **A beat speaks as its subject comes into the lamp**, within about 400 px of it (`announce_offset`,
  with the board beside it). The volumes are as wide as the encounters and the lines fired at their
  leading edge: "A mound on the path" 600 px out in the dark, and the bestiary page with it.
- **"This is the same rock. I have passed it three times now" is said when she has**, the second
  time she is led back (`_arrival_hook`, `LED_BACK_TO_NOTICE`). It was the tikbalang's arrival, so
  it played on the first approach.
- **A clearing is saved as she walks in**; its lantern stands where the light is made and her light
  lights it (`CheckpointArea2D.lights_on_entry`), with the lamp filled and a curse lifted.
- **The mound is asked from its foot** (56 px), where a jump from standing clears it.
- **The sigbin keeps to its ground** (a 700 px leash); it gave chase into the tikbalang's.
- **The kapre's camera hold** was replaced: its smoke turns her round instead of stopping the camera.
  Anything the artist route takes as moving air clears it -- a fan, a cloud, a sun, her as a
  butterfly -- not a fan alone. Reach is measured from the smoke bank, not the tree: she
  can press F at the west edge, see the smoke move immediately, and walk through while it
  clears over 1.5 seconds. F off interrupts an unfinished clearing; a switched-off fan does
  not count as moving air. The segment probe presses the physical F key from that reachable
  approach, rather than teleporting beyond the smoke's turn-back line.
- **A fan blows where it points** (2026-11-04). A switched-on fan shows its wind (`FanWind2D`)
  and turns its blades, so it counts at the kapre only pointed at the smoke: facing east, the
  way the smoke is blown, with the bank still ahead of it. While it blows the smoke from past
  its own 220 px, its wind is drawn reaching into the bank (`_carry_the_wind_to_the_smoke`),
  so the smoke never moves with the wind visibly stopping short of it.
- **F BLOW does what it says** (2026-11-05). The prompt offers BLOW anywhere within FAN_REACH of
  the smoke, further out than the kapre's own ground, where F is judged as an answer; out there F
  only switched the fan on and chose nothing, so the smoke never moved. Pressed there now, it
  chooses the artist route as it would at the tree (`_fan_offered_at_the_smoke` answers both).
- **A throw goes where it is clicked.** A boomerang flies out along the click, a shot is fired at
  it (aimed over by its fall); F throws straight ahead as before. Thrown level, nothing reached the
  kapre's cigar. And the use that chooses a "draw it, then do it" route is used: the first blow at
  the sigbin lands and the first throw at the cigar is thrown (they had only chosen). A cannon shot
  is put at the muzzle before it is in the world -- added first, every shot began inside the canopy.
- **Falls are knockouts.** The wanderer wraps to the sky at the world's bottom, so Dilim knocks her
  out 300 px under the forest floor instead.
- **Exhausted supplies offer a checkpoint retry.** When she cannot afford another drawing and
  has no usable counter left for her current encounter, the existing recovery popup explains
  the situation and offers **Retry Checkpoint**. The final attack gets four seconds to land and
  finish burning before the check; usable drawings in hand, in the bag or on the ground still
  count. Missing ash also prompts when the tik-tik is hidden, even if ink or weapons remain.
  The finale explains that evading until dawn remains possible. Retries restore ink,
  lantern health and the supply allowance from the checkpoint plus pickups found since it;
  flowers and discoveries stay kept, and repeated retries do not add duplicate stacks.
- **No drawing-free run.** The kapre has no route without a drawing, so Dilim cannot be finished
  without one -- by design -- and there is no `run_nodraw_level4`.
- **The Makiling tileset** is used in part: the six plates, its seamless tiles and (below) its
  mud, stone, leaf cover, grassy edge, ferns and mushrooms; no slopes, root or log platforms,
  waterfall or flowers. The vine frame plate stands only behind her (in front of play it hid her).

## Lola's things and the morning clock (2026-11-06)

Kent: "not that clear to use and when to use"; "start off as a moon and then slowly transform into a sun".

- **Each thing says what, which key and when.** On finding it (`found`), on its slot for as long as
  she carries it (`does`), and at its moment: `level_4.gd` `_wanted_now` asks every tick what would
  help now, and that slot wears a Now chip. Advice only; no press changes. The words wait for what
  is up to be read and speak as an aside, so advice standing through a beat comes back after them.
- **Everything lying in the woods has a slot.** Only the whip, which drops late in the night, can find
  all five held: it then says so, stands on the bar with no key and takes the next slot spent.
- **A press that does nothing says why**: oil on a full lamp, a slot with none left, ash with nothing
  in reach, a candle where only a drawn light answers.
- **Garlic's ring** stands over the dark and closes as it runs out. It is room to breathe, not "room
  to draw" as the design table has it: drawing stops the world, so the words say ten seconds, stay in.
- **`DawnClockHud`** is a window on the sky: a crescent among stars, full by halfway, silver warming
  to gold, rays by morning, with the time in words and the two waves marked on its path. It pictures
  a sun at Kent's request; no line names one.
- **The night's words:** one line on arriving, the wave's line and her keys on the hint bar, the quest
  card by what is after her (`_night_objective`). A retried night repeats what is happening, and the
  list of her things only for the wave that knocked her out.

`run_visual_level4_clock` writes the clock through the night to `/tmp/obra_dawn_clock.png`; the reviewed
sheet is `docs/screenshots/dilim_morning_clock.png`.

**Two of Kent's decisions came with this (2026-11-06):**

- **A candle is a light like any other.** It fills a clearing's lamp (`solve_with_item`, with the
  clearing's line) and is the artist's way past the sigbin and the tiyanak, at once and from anywhere in
  the beat, as a drawn light is. Set beside the manananggal's lower half it answers in the same two
  seconds, with no route chosen first, so salt stays open until then. It counts as the artist's route in
  the tally. The Now chip stays off at a clearing, since arriving always fills her ink.
- **Ash shows what flies in while it hangs.** Asked only at the throw, ash thrown as the lamp leaned at
  220 px reached nothing, since the cloud reaches 160. It goes on looking for its 1.6 s, and the tik-tik
  comes in at 110 px/s, so "when the lamp leans, throw" is always in time. That lean is the slot's Now.
  Walkers are still blinded only at the throw. An empty cloud says so once it has gone.

## The ground is built the way Mayon's is, in Makiling's mud (2026-11-02)

`CliffDressing` and `CliffDressingStone` (`CliffDressing2D`, under `GameplayPlane/Terrain`) draw
every platform of the `MakilingTerrain2D` bodies, by kind: the mud wall with roots through its
deeper courses, and the mossy stone for the sigbin's rock, the landmark, the ravine's steps and the
hollow, both under a thick lip of the leaf cover -- whole leaves standing up past its top and hanging
over the earth -- darker going down into broken layers, with straight shaded ends the leaves round
over and ferns and mushrooms on the lips, all graded to the ground's night tint. Kits are cut by
`tools/build_cliff_kits.py` (recipes `dilim`, `dilim_stone`); see LEVEL_1.md for the construction
and the looks Kent rejected on the way. The bodies keep their collision, their **branches** (still
logs, drawn by the terrain) and their **moonlight rims**, which mark the ground in the dark whoever
draws it. ⚠ Each dressing reads the other kind's ground through `ground_rects()` only, to close its
ends against it; `dressed_ground()` would stand that ground's art down. ⚠ No long hanging vines or
roots on a riser: the high path is a Climb gate. `run_cliff_dressing_probe` holds the contract.

**The ground artwork was simplified on 2026-11-04.** Both dressings now use
`assets/Level4/ground_mossy`: chunky shaded brown earth/stone blocks beneath a hanging moss cap,
based on Kent's two supplied tile references. The first flat-earth version was too simple; this
keeps readable block faces without the delivered tileset's tiny stones, roots and dense leaves.
The generated source, references and exact prompt are kept in `LEVEL4_Mt.Makiling/authored/`;
the game-sized repeat is 384 x 256. The kit disables extra edge foliage and plant stamps.
`CliffDressing2D` still owns the world-anchored repeats, shaded ends and deeper layers, and
`MakilingTerrain2D` still owns collision, branches and moonlight rims. The older `cliff` and
`cliff_stone` build outputs remain available but are no longer the scene's ground artwork.

**The darker reference-matched kit followed on 2026-11-04.** Both dressings now use
`assets/Level4/ground_forest`: shaded brown blocks under deep forest-green moss, with
matching bushes, a fern, mossy rocks and two short vine clusters. Sources, the supplied
reference, exact built-in generation prompts and a three-repeat preview are in
`LEVEL4_Mt.Makiling/authored/forest_ground_v2/`. Rebuild with
`godot --headless --path game --script res://tools/build_forest_ground.gd`, then import.
The 384 x 256 strip uses a minimum-error pixel seam for a continuous horizontal repeat;
`ground_tileset.tres` also exposes its 24 cells at 64 x 64. Short vines are decorative,
inset from ends, and never form a climbable riser. The prior `ground_mossy` kit stays separate.

**The supplied moonlit artwork supersedes that kit (2026-11-04).** Both dressings now use
`assets/Level4/ground_moonlit`. `tools/build_moonlit_ground.gd` cuts the user's moonlit
reference directly: original pixel sizes, leaf silhouettes, stone facets and cool highlights,
without resampling or a five-color reduction. Four clear wall sections are joined with pixel
cuts into a 1216 x 448 horizontal repeat; four plants and two short vines are separate assets.
The source, crop recipe, rebuild notes and repeat preview live in
`LEVEL4_Mt.Makiling/authored/moonlit_ground/`. The 64 x 64 TileSet exposes 19 x 7 atlas cells.
These already moonlit dressings use white tint, avoiding a second night grade; the darkness
layer still controls visibility. Kit-specific plant spacing accommodates native-size bushes;
other kits keep their old spacing. Vines remain inset face growth rather than climbable risers.

**Ground and decoration are now separate (2026-11-04).** The ground kit has no plant/vine
stamps; those assets live in `assets/Level4/foliage_moonlit`, painted by separate
`BackgroundBushes` and `GroundVines` scene layers (`moonlit_foliage_2d.gd`). Their full
bounds avoid the existing encounter trigger volumes, hazards and supplies. They draw below
Nuno's emerging spirit and all creatures, including spawned aswang. This prevents both
occlusion and a bush appearing to be part of an encounter. The cutout's old global navy key
punched holes in leaf shadows: the cutter now closes the silhouette and fills interior holes
from the source pixels, while keeping the outside transparent and the ground strip separate.
`run_moonlit_foliage_probe` covers intact fern shadows, opaque ground, real decoration
placement outside mechanic areas, and draw order against Nuno, placed foes and spawned aswang.

The delivered forest frame and both terrace backdrop plates also had opaque white matte
pockets between their leaves and pale resampling fringes. `build_dilim.py` now removes
enclosed white matte on those three vegetation plates and unmattes nearby edge pixels before
snapping alpha to opaque/clear. The cloud plates keep their grid-aware extraction; their
white highlights are real art. Plate dimensions and parallax registration remain unchanged.
`tests/test_build_dilim.py` covers closed matte pockets, real dark leaf shadows, white-composited
edges and known problem pixels on the supplied plates.

The tikbalang fork's three floating shelves now use `ground_moonlit/platform.png`, a
native-pixel moss lip and stone course cut from the same ground texture by
`build_moonlit_ground.gd`. `MakilingTerrain2D.branch_texture` is an optional visual override;
the Fork keeps its three positions, widths and 18 px one-way bodies.
All raised paths now use that same artwork with white tint: the three Tikbalang shelves,
the Tiyanak's two shelves and the long high path over the ravine. The floating solid shelf
above the manananggal's hollow also uses it, through the ground kit's `shelf` setting.
Both terrain renderers share `moonlit_shelf_art.gd` so the corner shape and native pixel
scale stay identical. Grounded rocks such as the Tikbalang landmark keep their deeper art.
The original solid/one-way collisions and all route geometry are retained.
Its upper corners are clipped in two small pixel steps for a gently rounded moss lip.
Collision stays rectangular.

**The dotted moonlight overlay was removed (2026-11-04, requested).** The white flecks
across ground and floating shelves were drawn above the darkness by `MakilingTerrain2D`,
not missing pixels in the artwork. Those extra rim layers are gone; the moonlit moss texture
now supplies the continuous visible edge. Earlier build notes describing rims are historical.

**The supplied trees replace the standing tree art (2026-11-05).** The first reference is
the Kapre's buttressed trunk, its branch aligned to his existing feet. The second is the
clearing's hollow dead tree and the repeating forest trees, replacing the old vine-tree
frame. Both felled trunks use the supplied bark. Sources and rebuild notes live in
`LEVEL4_Mt.Makiling/authored/trees/`; `game/tools/build_dilim_trees.gd` exports to the separate
`assets/Level4/trees/` folder. `ForestBand.plate_texture` replaces the scenery while keeping
its parallax and dawn tint. Chopping, smoke, cigar targets, collision and encounter geometry
keep their existing rules. The older sculpted tree outputs remain historical build outputs.
`run_visual_dilim_trees.gd` captures all three replacements and both felled states.

**Dilim's outdoor backdrop uses the supplied vista behind the existing trees (2026-11-07).**
Three ImageGen edits under `assets/Level4/backdrop_reference/` form the sky, single Makiling
peak, and forest canopy. Their horizontal camera rates are 0.02, 0.044, and 0.29. The sky
and canopy mirror at the joins. The supplied `forest_plate.png` repeats in front of the
canopy at 0.62, with its original scale and top edge. All four bands draw behind the
play plane and share the finale's night-to-dawn grade.
`run_makiling_probe` checks the live bands and `run_visual_makiling` shows the joins and
ravine. The [generation prompts](LEVEL4_Mt.Makiling/authored/backdrop_reference_prompts.md)
record the artwork edits.

## The old way over the ravine fades (2026-11-01)

A fallen log lay across the bungisngis's ravine: `GameplayPlane/OldLog`, Makiling's own mossy log
platform cut off the tileset by `tools/build_dilim_log.py` (no scipy; `--check` verifies it). It is
in the fading old ways (`_fades_the_old_way`, as Payyo's are; see LEVEL_1.md): no collision, gone
from x 18600 by 18912, before its near end at 19125, so the crossing reads as hers to make.

- **It comes up out of the dark as it goes, and only then** (`Drainable.reveals_in_dark`, given by
  LevelBase in any level with darkness): a soft hole of `DarknessLayer.REVEAL_GROUP`, the same
  strength as a set-down drawing's, easing in over the first 0.15 of the drain and dissolving
  with the log. Never light: LightField does not count it.
- ⚠ **Not before.** A reveal open round the log from the start kept a patch of the woods lit
  half a screen ahead and showed the bungisngis standing in the ravine under it.
- It dissolves into the night woods' moss (`_fade_paper` 0.13, 0.18, 0.15), not to white.

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
