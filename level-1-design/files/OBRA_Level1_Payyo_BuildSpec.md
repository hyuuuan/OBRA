# Level 1 — Payyo · Build Specification

**Consolidates:** the Ifugao historical design, the three-nodes-per-level decision, and
the ability-tag hint system. This replaces the two earlier Level 1 drafts. Everything
needed to start building is here. Anything not yet decided is in §12, not hidden in prose.

Companion file: `level_01.json` — drop-in level data.

---

## 1. At a glance

| | |
|---|---|
| **ID** | `L1_PAYYO` |
| **Setting** | Ifugao rice terrace landscape, Cordillera Central |
| **Mechanic focus** | vertical traversal; first contact with the canvas |
| **Structure** | 1 tutorial beat + 3 dialogue nodes |
| **Ability tags unlocked** | 9 of 15 |
| **Classes with a use here** | 20 of 50 |
| **Checkpoints** | 6 |
| **Dialogue lines** | 70 |
| **Reward** | second canvas → unlocks Pista |
| **Target playtime** | 8–14 min Artist · 5–8 min Pragmatist · 10–16 min Protector |

**Level name.** REQ-4.11-1 currently says *Bahay Kubo*. That is the lowland nipa hut, not
the Ifugao *bale*. This spec uses **Payyo**. If you keep the old name, everything else in
this document still builds; you will just have a cultural-accuracy defect that DASH
catches. See §12.1.

---

## 2. Two structural rules this level establishes

Both apply to every later level. Write them into the SRS once, here.

### 2.1 A node teaches all three of its routes' tags before presenting the choice

You cannot choose a route whose verb you do not know. So each dialogue node unlocks the
tags for all three of its routes *in the dialogue itself*, then presents the choice.

This is why Level 1 unlocks 9 tags — a tutorial level has to show the breadth of the
system so the book makes sense. Levels 2–5 unlock the remaining 6 and spend their time
adding **classes** underneath tags already known. Tags broaden fast and early; classes
accumulate throughout. That is the two-axis design working as intended.

### 2.2 Route lock applies to the obstacle, not the level

Three nodes per level × 4 levels = 12 nodes. The route commits per obstacle and adds one
to a running tally. Ending threshold is **7 of 12**. See §8.

---

## 3. Ability tags

### 3.1 Unlocked in Level 1

| Tag | Unlocked at | Satisfying classes | Count |
|---|---|---|---|
| **Span** | Beat 0.1 | bridge, ladder, square, triangle | 4 |
| **Roll** | Beat 0.2 | circle, wheel | 2 ⚠ |
| **Climb** | Node 1 dialogue | spider, bat, monkey, crab, ladder, stairs, tree, snake | 8 |
| **Leap** | Node 1 dialogue | frog, horse, penguin, mushroom | 4 |
| **Cut** | Node 1 dialogue | axe, sword, scissors, elephant | 4 |
| **Forage** | Node 2 dialogue | rake, pig | 2 ⚠ |
| **Carry** | Node 2 dialogue | ant, horse, elephant, octopus, bucket, monkey | 6 |
| **Weather** | Node 2 dialogue | fan, butterfly, cloud, sun, bucket | 5 |
| **Unlock** | Node 3 dialogue | key, door | 2 ⚠ |

⚠ = at the two-class floor. If the BR-7 audit drops any of these classes below 0.70
recall, the obstacle requiring that tag becomes solvable by exactly one drawing. Watch
`rake`, `pig`, `key`, `wheel`.

**Held for later levels:** Fly, Swim, Crush, Strike, Light, Shield.

### 3.2 Classes are never gated — tags are

All 50 classes are drawable from the first canvas. What is gated is the **ability**. Draw a
`flashlight` before **Light** is unlocked and it spawns as an inert prop that lights
nothing.

This is simpler to build than a class whitelist, it makes Hidden Flower 1 consistent
(the cave stays dark because you do not know Illuminate, not because the game refused
your drawing), and it rewards experimentation instead of punishing it.

Presentation: the tag's page in the book is a blind deboss. REQ-4.10-4's refusal message
is replaced by the locked page.

### 3.3 Obstacles declare tags, never classes

Per REQ-4.22-2. The loader resolves satisfying classes from `entities.json` at load time.

**Consequence worth noticing:** at Node 2 the Artist route requires **Forage**, and
Forage resolves to `{rake, pig}`. `pig` therefore becomes a valid Artist solution
automatically, with nothing authored. The anti-stuck fallback falls out of the data model
rather than being special-cased.

`exclude` exists for classes that satisfy a tag but make no physical sense at that
obstacle. **Exclusions run before the ≥2 check.** If an exclusion drops an obstacle below
two solutions, that is a build error, not a design choice.

---

## 4. Beat sheet

```
BEAT 0   Ang Hagdan     tutorial · no node · no fail state       CP0
NODE 1   Ang Tulay      the crossing                             CP1 (+CP1b Protector)
NODE 2   Ang Dayami     the box in the straw                     CP2
NODE 3   Ang Bale       the key and the box                      CP3
EXIT     Ang Batong Palatandaan                                  CP4
```

### Checkpoint rule

**A checkpoint is written the instant a route is committed**, immediately after the
dialogue choice. This does two jobs at once: it satisfies REQ-4.9-1 for every morph on
that route, and it stops a death from replaying the choice. One extra mid-obstacle
checkpoint exists at CP1b for the Protector collapsing-log sequence.

Checkpoints restore ink, toolbelt, placed entities, and obstacle state (REQ-4.9-2).

---

## BEAT 0 — Ang Hagdan

**No dialogue node. No fail state.** Dawn, ankle-deep water, a stone stair between two
paddies with three treads gone.

| Sub-beat | Teaches | Tag unlocked | Solution |
|---|---|---|---|
| 0.1 | the canvas, placement | **Span** | `square` (Platform) or `triangle` (Wedge) into a gap |
| 0.2 | physics objects behave | **Roll** | `circle` (Roll) to weigh down a floating tread |
| 0.3 | the refusal is not a failure | — | fires on first declined recognition |

### The refusal beat

The first time recognition declines — confidence < 0.60 **or** margin < 0.15 — Lolo
speaks over it and **no ink is spent**. Scripted as dialogue, never as a forced rejection;
the model is not rigged to fail. If the player never trips the gate in Beat 0, the line
fires on their first decline anywhere in the level, then never again.

**CP0** at the top of the flight.

---

## NODE 1 — Ang Tulay

A *wangwang* has cut a gorge between two terrace flights. The log footbridge is gone; the
near abutment is mossed and obviously hand-cut. Above the far terraces: the **muyong**.

### The dating exchange

Fires on arrival, before the choice. This is the emotional spine of the level and the one
place the historical research is doing narrative work rather than set dressing.

The node dialogue then teaches **Climb**, **Leap**, and **Cut** before the choice appears.

### Routes

| Route | Tag | Excluded | Resolves to | Sequence |
|---|---|---|---|---|
| **Artist** | Span | — | bridge, ladder, square, triangle | Place a span across the gorge. Then climb the far abutment (Climb) |
| **Pragmatist** | Leap, Climb | — | frog, horse, penguin, mushroom, spider, monkey, bat, tree, ladder, stairs | Follow the *tuping* — the dry-stone terrace walls are a continuous walkable network. Two gaps: one leap, one traverse |
| **Protector** | Cut | scissors | axe, sword, elephant | Fell a tree at the muyong edge. Collapsing-log traversal (**CP1b**) |

**Artist reward.** Memory cutscene: Lola at an easel on the far bank, a six-hour study of
this bridge pinned around her, and between two canvases a photograph of a much younger
Lolo standing on the intact bridge.

**Protector cost, and it is mechanical.** The muyong is privately owned, inherited whole,
and is the water recharge zone for every terrace below. The terrace under the stump runs
visibly dry for the rest of the level and stays dry on replay of this route. Lolo does not
stop the player and does not forgive them either.

**`axe` is a tool.** Paid once, retained in the toolbelt, carries into Node 3.

**Pragmatist** passes the cave mouth (§9) and cannot enter it.

**CP1** written on route commit. All routes converge on the far lip.

---

## NODE 2 — Ang Dayami

A harvested terrace. Cut cogon and rice straw heaped shoulder-high for re-thatching.
Lola's folding stool and a jar of brushes at the edge of the pile.

In the straw: a **baul** — small, banded, padlocked. Hers.

> **The pile is cut straw, not harvested grain.** Deliberate. Scattering a *tinawon*
> harvest is not a neutral thing to stage, and the Protector route below would be
> genuinely offensive if it were. Straw keeps the image and removes the problem.

Teaches **Forage**, **Carry**, **Weather**.

| Route | Tag | Excluded | Resolves to | Sequence |
|---|---|---|---|---|
| **Artist** | Forage | — | rake, pig | Comb the piles section by section. Slowest. Pile left standing |
| **Pragmatist** | Carry | horse, elephant | ant, octopus, monkey, bucket | Tunnel under, find by touch, drag out |
| **Protector** | Weather | cloud, sun, bucket | fan, butterfly | Blow the piles apart. Seconds |

**Artist reward, and it is load-bearing.** Three combing passes surface things before the
box: a dried brush, a palette knife, and a folded sketchbook page — the bale drawn from
this exact angle, dated, with a margin note about a key.

**That page is the Node 3 foreshadow.** A player who rakes knows to look for a key. A
player who took ant or fan does not, and searches longer at Node 3. This is the clearest
case in the level of a route's reward paying out in a later obstacle rather than in
cutscene length.

**Protector cost.** The straw scatters and does not reassemble. Lolo says nothing at the
time and mentions it at the exit.

**CP2** written on route commit. Serves every morph here.

---

## NODE 3 — Ang Bale

The bale on its four posts, *halipan* on each. The ladder is gone — taken in, as it is
every night, by someone who is not here. No windows. One door, above head height, shut.

The architecture is the puzzle. Every route answers a documented feature.

Teaches **Unlock**. Climb and Cut are already known.

| Route | Tag | Excluded | Resolves to | Sequence |
|---|---|---|---|---|
| **Artist** | Climb | crab, snake | spider, bat, monkey, ladder, stairs, tree | The *halipan* defeat a straight post climb — that is what they are for. Go up the thatch slope and in under the eaves, into the attic granary. The key is on a nail |
| **Pragmatist** | Unlock | — | key, door | Draw a key → **ward-matching sequence**. Or draw a door onto the lid of the baul and open it |
| **Protector** | Cut | elephant | axe, sword, scissors | Through the hasp. One action |

### Artist — the attic

The key hangs on a nail beside a photograph: Lola, young, on the bale steps, holding an
unfinished canvas, standing beside a woman in her sixties the player has never seen and
Lolo does not name.

**Two bulul sit two metres away.** Lit, the most carefully rendered assets in the level,
and with **no collision, no interaction prompt, and no puzzle function.** Lolo speaks if
the player lingers. See §10.

### Pragmatist — the ward sequence

**Classification is not the puzzle.** The recognizer only gates the attempt. Once `key` is
accepted at threshold, the player's own **stroke geometry** is tested against the
padlock's ward slot — bit height, bit count, blade length. Wrong profile and the key turns
partway and stops, with the ward now drawn faintly on the canvas as a guide.

Three attempts, each revealing more of the ward. Nobody fails permanently.

> **Engineering note.** This is a geometric test on the Line2D vector data, not a CNN
> function. Do not describe it in any chapter as the model recognising a *specific* key —
> it recognises the class; the geometry check is separate code. It is also the level's
> best demonstration of the thesis's own claim that the player's strokes *are* the entity.
> Blocker: §12.3.

The `door` alternative — drawing a door onto a wooden box and opening it — is the level's
one absurdist solution and should be played straight. `door -ReceivesAction(4.00)->
opened`.

### Protector — the cost reaches into Level 2

The canvas inside is creased along the break. In Pista the crease is a visible seam
through the painted street, and **Hidden Flower 2 sits on the damaged side of the seam
and is unreachable for this playthrough.** The player finds out in Level 2, not here.

Requires persistent cross-level state. Blocker: §12.4.

**CP3** written on route commit.

---

## 5. Exit — Ang Batong Palatandaan

The marker stone at the foot of the terrace flight. **Golden hour lands here** — moved to
the end so it reads as arrival rather than wallpaper.

**The second canvas:** night, *banderitas* strung over a street, neon on wet asphalt, a
crowd. At the left edge, half out of frame, a figure in a shawl.

**Pista unlocks at CP3, not at the exit** — a player who abandons after Node 3 keeps the
progress.

---

## 6. Hint escalation

| Tier | Trigger | Behaviour |
|---|---|---|
| T0 | on approach | Flavor only. No tag |
| T1 | canvas opens, or 30 s idle | Names the tag(s). Requirement strip appears |
| T2 | 2 declines/wrong solves, or 90 s | Ability Book opens, required tags lit, player's own qualifying classes shown. Game still names no class |
| T3 | 4 attempts or 3 min | **Accept-set expands to the union of all three routes' tags.** Logged as assisted |

**T3 replaces per-obstacle fallback authoring.** One rule, no special cases: a stuck
Protector at Node 2 can solve with a rake. The **tally records the choice made at the
dialogue, not the solution used**, so route identity survives.

Solves after T3 are excluded from unassisted statistics in Chapter 5.

---

## 7. Scene tree

```
L1_Payyo (Node2D)
├── World (Node2D)
│   ├── Terrain (TileMapLayer ×3: paddy, tuping, thatch)
│   ├── Parallax (muyong canopy, far terraces, mist)
│   ├── B0_Hagdan     (Area2D trigger + 3 GapSlot markers)
│   ├── N1_Tulay      (Area2D + AbutmentNear/Far + MuyongTree + GorgeFloor)
│   ├── N2_Dayami     (Area2D + StrawPile ×3 + BaulSpawn)
│   ├── N3_Bale       (Area2D + Post ×4 + ThatchSlope + AtticVolume + Baul + Bulul ×2)
│   ├── HiddenFlower1 (Area2D, gate = Light)
│   └── ExitMarker    (Area2D)
├── Player (CharacterBody2D)
│   └── RuntimeRig2D            # rebuilt from strokes on morph
├── Spawned (Node2D)            # every drawn entity parents here; cleared on respawn
├── Checkpoints (Node2D)        # CP0 CP1 CP1b CP2 CP3 CP4
├── LoloSpirit (Node2D)         # follows player, drives dialogue
├── HUD (CanvasLayer)
│   ├── InkCounter
│   ├── CheckpointIndicator
│   ├── Toolbelt
│   ├── RequirementStrip
│   ├── DrawPanel
│   │   ├── SubViewport → Line2D
│   │   └── CompactStrip        # required tags + your qualifying classes
│   └── AbilityBook
└── LevelDirector (Node)        # state machine, hint timers, telemetry
```

### Signals

```gdscript
signal obstacle_entered(obstacle_id)
signal route_committed(obstacle_id, route)        # → write checkpoint, += tally
signal draw_submitted(obstacle_id, stroke_count, ms_since_open)
signal prediction_returned(label, confidence, margin, ms_end_to_end)
signal prediction_declined(reason)                # "confidence" | "margin"
signal entity_spawned(label, tag, spawn_type)
signal obstacle_solved(obstacle_id, route, label, attempts, hint_tier)
signal checkpoint_written(cp_id)
signal tag_unlocked(tag)
signal class_first_drawn(label)                   # → Class Diversity Score
```

### Spawn types

| Group | Spawns as | Node 1 uses | Node 2 | Node 3 |
|---|---|---|---|---|
| Creature | `CharacterBody2D` + `RuntimeRig2D` | frog, monkey, spider, bat | ant, pig, octopus, monkey, butterfly | spider, bat, monkey |
| Object / Primitive | `RigidBody2D`, collision rebuilt from class | bridge, ladder, square, triangle, axe | rake, fan, bucket | key, door, axe, sword, scissors |

---

## 8. Telemetry

Per attempt:

| Field | Notes |
|---|---|
| `obstacle_id`, `route` | route is the committed choice, not the solution used |
| `required_tags` | resolved set at that obstacle |
| `hint_tier` | 0–3 at time of attempt |
| `accepted_label`, `confidence`, `margin` | |
| `tag_match` | bool — **the first-intent metric** |
| `declined`, `decline_reason` | |
| `ms_end_to_end` | canvas submit → entity spawned. **Not** model inference time |
| `attempts_to_solve`, `assisted` | |

Per level: route tally, Class Diversity Score, time per obstacle, checkpoint restores,
tags unlocked.

**First-intent match rate** — of first attempts after a T1 hint, the proportion whose
accepted class carries the required tag — is the behavioral measure of ability–intuition
alignment that sits alongside QUESI. Report it with that session's per-class recall so a
reader can see how much room misclassification had.

---

## 9. Hidden Flower 1

Gorge floor, past the dry riverbed. A cave mouth full of a dark that does not behave like
dark. Gate: **Light**, not unlocked until Level 4.

Reachable in Level 1 — trivially on the Node 1 Pragmatist route. The canvas opens
normally; anything drawn spawns inert. The **Light** page in the book is a blind deboss.
That is the whole message.

**This must not read as a fail state.** It is where the player learns that some things are
gated by knowledge, not skill.

> **Not a burial cave.** Cordillera burial caves with ancestral remains are real and are
> not collectible-hunting locations. Natural cave, no interments, no artefacts. Flag this
> to DASH proactively.

---

## 10. Cultural guardrails

Non-negotiable in the build.

| | |
|---|---|
| **Bulul** | Present, lit, carefully rendered. Zero collision, zero interaction, zero puzzle function. Lolo's line fires on approach |
| **Hudhud** | No recording. No Lolo chant. Used as *structure* only — call-and-response phrasing carried by instruments |
| **Instrumentation** | Gangsa, nose flute, bamboo. **Not bandurria** — that is lowland rondalla |
| **The straw pile** | Cut straw, never harvested grain |
| **The cave** | No burials |
| **Muyong felling** | Has a stated cost and a persistent visual consequence. Never neutral scenery destruction |
| **Naming** | No named village, no named clan. Avoids attributing invented events to a real community |

### Declared creative liberties

| Liberty | Justification |
|---|---|
| Padlocked *baul* — Ifugao houses had no locks | Diegetic. It is **Lola's**, brought from the lowlands. Lolo says so aloud |
| Empty bale, ladder stored, landscape unpeopled | The level is inside a painting. Absence is the subject |
| Compressed geography | A real Ifugao landscape has all these components, at larger scale |
| Lolo's dating correction is IAP's position, not settled consensus | Stated in-fiction as one voice, not as narration |

---

## 11. Assets

### Art

| | Count | Notes |
|---|---|---|
| Terrain tilesets | 3 | paddy water, *tuping* dry-stone, cogon thatch |
| Parallax layers | 4 | muyong canopy, mid terraces, far ridge, mist |
| Lighting states | 3 | dawn (B0–N1), overcast (N2–N3), golden hour (exit) |
| Bale | 1 | four posts, halipan ×4, thatch slope, attic volume, eave gap |
| Bulul | 2 | male/female pair. Highest-fidelity assets in the level |
| Props | ~14 | baul, easel, folding stool, brush jar, palette knife, sketchbook page, photograph, nail, abutment ×2, muyong tree, straw pile ×3, marker stone |
| Cutscene | 1 | Node 1 Artist memory |
| Canvas art | 2 | Lola's first canvas (carried in), Pista canvas (reward) |

Player-drawn entities need no art — the strokes are the sprite.

### Audio

Gangsa pattern (3 intensities), water ambience, wind through cogon, thatch creak, ink
stroke, recognition accept, recognition decline, checkpoint, tag unlock, collapsing log,
straw scatter, padlock turn, padlock stop.

---

## 12. Blockers and open items

Ordered by how much they cost if found late.

### 12.1 Level name — decide before the manuscript freezes
REQ-4.11-1 says *Bahay Kubo*; the environmental reference is Banaue. A bahay kubo is the
lowland nipa hut. The Ifugao house is the *bale*: windowless, four posts, halipan,
pyramidal roof, attic granary. Not the same building tradition. **Recommend renaming to
Payyo** — Ifugao for the pond field, parallel to Pista / Dagat / Dilim.

### 12.2 `clock` and `snail` are unhintable
Neither has an ability carrying a tag, so nothing can ever ask for them. Both are classes
the model must learn and the manifest must carry, for content nothing can request. Add a
tag, retag, or forbid them on critical paths.

### 12.3 Stroke geometry access — Node 3 Pragmatist depends on it
Confirm with Rusk that Line2D stroke data is available to gameplay code *after*
classification returns. If not, the ward sequence does not exist and Node 3 Pragmatist
needs redesign. **Do not promise it in any chapter until confirmed.**

### 12.4 Cross-level canvas damage
Node 3 Protector's cost reaches into Level 2. Confirm the save schema carries per-canvas
damage state before this is written up.

### 12.5 Synchronous POST
`SketchClient` issues a synchronous POST. Verify whether it blocks the main thread — a
60 fps game has ~16 ms per frame. Until confirmed, do not describe recognition as
asynchronous anywhere.

### 12.6 Ink economy is unfixed
`level_01.json` carries placeholder values so the level is buildable. **Those numbers are
tuning placeholders and must not enter the manuscript.** The Pragmatist route's speed
advantage is an economy question as much as a layout one.

### 12.7 BR-7 audit pending
Every class on a critical path here is provisional until final per-class recall exists.
Highest risk: `rake`, `pig`, `key`, `wheel`, `fan`, `butterfly`, `ladder`/`stairs`.
Anything under 0.70 moves off the critical path.

### 12.8 Ifugao language review
Tuwali and Ayangan differ. Every term here is from published sources, but a native speaker
should review before the Cultural Content Questionnaire goes out.

---

## 13. Build order

Vertical slice first — one route end to end before any breadth.

| # | Task | Unblocks |
|---|---|---|
| 1 | Terrain, collision, player traversal, camera | everything |
| 2 | Beat 0 with `square` only — canvas → POST → spawn | the whole recognition loop |
| 3 | Checkpoint write/restore | every morph |
| 4 | Requirement strip + Ability Book compact strip | hints |
| 5 | Node 1 **Artist only**, end to end | first playable slice |
| 6 | Node 1 Pragmatist + Protector | route system proven |
| 7 | Node 2 all routes | tag resolution at scale |
| 8 | Node 3 Artist + Protector | — |
| 9 | Node 3 Pragmatist ward sequence | gated on §12.3 |
| 10 | Full Ability Book panel | — |
| 11 | Hint escalation T0–T3 | — |
| 12 | Telemetry | Chapter 5 |
| 13 | Cutscene, Hidden Flower 1, audio, lighting states | — |

### Test checklist

- [ ] Every obstacle resolves ≥2 classes **after** exclusions
- [ ] Every morph is preceded by a checkpoint
- [ ] Declined recognition costs no ink
- [ ] Checkpoint restore returns ink, toolbelt, placed entities, obstacle state
- [ ] T3 expands the accept-set without altering the tally
- [ ] Tag unlock fires before the choice that needs it, at all three nodes
- [ ] Bulul have no collider and no interaction prompt
- [ ] Hidden Flower 1 spawns inert entities and does not read as an error
- [ ] `axe` bought at Node 1 is present at Node 3
- [ ] Muyong stump's dry terrace persists across checkpoint restore
- [ ] Pista unlocks at CP3, not at the exit
- [ ] No hint text anywhere names a class
