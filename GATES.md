# Level 1 — what stops the player, and what opens it

**Why this file exists.** The premise of OBRA is that you draw to get past things. For most
of this level's life you could walk, jump and wade from the spawn to the goal without
drawing anything, and every obstacle was scenery. This is the list of what actually stops
you now, what opens each one, and which test proves it — so nobody has to take it on faith.

**Everything here has an id.** Say "G4 is too hard" or "X3 is back" and it is unambiguous.

**Read with** `LEVEL_1.md` (how the level works), `ART_PLACEHOLDERS.md` (what still needs
art), `CONTENT_NEEDED.md` (writing, audio, cutscenes).

---

## How to check it is still true

```bash
godot --headless --path game --script res://tests/run_nodraw_level1.gd
```
```bash
godot --headless --path game --script res://tests/run_walk_level1.gd
```

`T1` and `T2` are the two that matter for this file. The first tries to beat the level in
the player's own body and fails if it ever reaches the end. The second proves each gate
**opens** with the right drawing — a gate that cannot be opened is not a puzzle, it is a
wall, so both halves are always tested.

| id | suite | what it proves |
|---|---|---|
| **T1** | `run_nodraw_level1.gd` | The level cannot be finished without drawing. Prints how far a determined player gets from five points. |
| **T2** | `run_walk_level1.gd` | Each gate below opens: the drawing is placed and the character walks or climbs through. Also that a placement can be undone (R8) and that the object lands where the ghost was (X11, X12). |
| **T3** | `run_level1_audit.gd` | Level data, the three routes of each node, and the exit condition. ~40 checks. |
| **T4** | `run_click_ui.gd` | Every button answers a real mouse click. **Needs a real viewport — no `--headless`.** |
| **T5** | `run_tests.gd` | Everything else. Takes over ten minutes. |

---

## The gates

West to east, in the order a player meets them. "Reaches" is where T1's bot stops.

| id | where | x | what stops you | what opens it | reaches |
|---|---|---|---|---|---|
| **G1** | The paddy | 340–640 | **300 px of water, 100 px deep.** Wider than a running jump (228 px) and deeper than the apo can climb out of. Going under for a second puts you back on the bank. | **Span** — something laid across it — or something that floats or swims | 537 |
| **G2** | Ang Hagdan | 640–920 | **136 px of rise** from the bank to the lowest surviving stone, against a 94.3 px jump. Three treads are missing. | **Span** for the step, then **Roll** for the tread that floated off | — (G1 stops the bot first) |
| **G3** | Terrace 1 → 2 | ~1160 | A **140 px terrace face**. No dialogue, no strip — just a wall that is too tall. | **Span** or **Climb** | 1145 |
| **G4** | The gorge — Artist | 2400–2960 | A post mid-gorge splits it into **two 250 px spans** | **Span**, twice | 2635 |
| **G5** | The gorge — Pragmatist | 2400–2960 | Ledges take you down; the way out is a **bare 320 px wall** | **Span** or **Climb** | 2945 |
| **G6** | The gorge — Protector | 2400–2960 | A **standing dead tree** blocks the lip until it is felled across | **Cut** | 2320 |
| **G7** | The Overlook | 3320 | A **160 px cliff** between Terrace5 and the house | **Climb** | 3305 |
| **G8** | Ang Bale | 3500–3740 | **The level will not end until the bale is answered.** Choosing one of Lolo's three lines is free and is not an answer. | **Climb**, **Unlock** or **Cut** | 3485 |

G4, G5 and G6 are the same chasm seen three ways: the route chosen at the dialogue node
physically rebuilds it, so they are separate gates and T1 tests each on its own level.

---

## Rules that must stay true

Break one of these and gates start opening for free. They are the reasons behind the
numbers above, and they are worth checking before retuning anything.

| id | rule | why |
|---|---|---|
| **R1** | **The jump lifts 94.3 px** (`JUMP_VELOCITY -430`, gravity 980) | Every gate is measured against it. `run_level1_audit` reads the constant, not a copy, so raising it fails the build. |
| **R2** | **A running jump covers ~228 px** | Any gap meant to stop the player has to beat that with margin, and so does any stepping stone left near one. |
| **R3** | **A gate must open** | Test both halves. An impassable gate is worse than a skippable one, and it looks the same in a report that only checks the first half. |
| **R4** | **A drawn primitive must be climbable** — 80 px, under the 94.3 px jump | They were 116 px, so no square, circle or triangle could be got on top of, anywhere in the game. |
| **R5** | **No jump in water lifts you out** | Not even off the bottom. Every exception hands the player a way across; see X3. |
| **R6** | **Never gate progress on a route commit** | Answering Lolo costs no ink. What counts is a drawing being accepted. |
| **R7** | **A gate must have floor to build on** — at least 180 px of clear ground on the approach side, and never less than twice the width of the widest thing that opens it | A rise and a gap can both be right while the level is unplayable. This is the one that was never measured, and both places it was wrong passed every suite in the repo. `run_level1_audit` measures five of them off the nodes. |
| **R8** | **What is placed can be taken back** — E within reach, right-click at any range | A placement spends ink, empties a slot and leaves a solid body behind. If it cannot be undone, one misjudged click is permanent, and four drawings on the critical path against a budget of 12 does not leave room for that. |

---

## What was closed

Kept so the same hole is recognised if it comes back.

| id | the hole | how it was closed |
|---|---|---|
| **X1** | **You could walk on water.** The wading jump was −193 px/s against a sink capped at 120, so holding jump made you rise — and holding jump while walking right carried you over 300 px of open water as if it were a floor. Both paddies were free. | A jump in water is a kick far weaker than the sink. No exceptions. |
| **X2** | The paddy was **160 px** of ankle-deep water against a 228 px jump. A hop. | 300 px wide, 100 px deep, with a rescue instead of a trap. |
| **X3** | The **floating tread was a bridge**. Mid-crossing it halves the gap into two hops; and while a "push off the bottom" jump existed, standing on it launched the player clean over the far bank. | It is on its own collision layer: it still floats, still settles under a rolling weight, still carries drawn props — the player passes through it. |
| **X4** | **Ladders had no top.** Release was measured horizontally only, so holding up raised the player forever: place one anywhere, climb into the sky, walk over every gate. | Release past the ladder's own reach, measured from its collision. |
| **X5** | **A ladder was a wall.** A placed utility freezes solid, so you climbed beside it and could never step off onto what it leaned against. | Holding one excepts it from the player's collision. |
| **X6** | **Drawn primitives were 116 px** against a 94.3 px jump — nothing you drew could ever be climbed onto. | 80 × 80, authored in `config/object_sizes.json`, which is what the runtime actually reads. |
| **X7** | The stair **overhung the bank**: a 28 px ledge under a 74 px ceiling, for an 80 px character. You could not reach the foot of it, let alone repair it. | The surviving stones moved right and up; the pocket in front of them is 102 px. |
| **X8** | The **inventory bar ate placement clicks** — 756 × 52 across the bottom of the screen, and placement confirms from input the GUI did not consume. Setting a step down near the ground did nothing. | The bar stands out of the mouse's way while a placement is live. |
| **X9** | The exit **unlocked on choosing a route**, not on answering it. | The obstacle the unlock checkpoint sits at must be solved. |
| **X10** | **A placed drawing could not be taken back.** Pick-up lived on `UtilityObject`, and circle, square and triangle are not utilities — they were in no group, had no `interact()`, and E walked past them. Those three are what Beat 0's Span resolves to, so the most-placed object in the game was the one that was permanent. | The contract moved down to `PhysicsShapeObject`. E for what is in reach, right-click for anything you can point at. |
| **X11** | **The object did not land where the ghost was.** Freeing a preview from solid ground travels up to a body height and a quarter UP and stops; nothing brought it back down, and confirming let it fall from there. Aiming at your own feet put it 121 px over your head. | The drop budget is the climb's budget, so any lift is undone onto the first surface below. A deliberate placement into open air draws its own fall line. |
| **X12** | **Your own body vetoed the ground you were standing on.** The player is on collision layer 1 like the terrain, and the overlap test excluded only the preview's own bodies — so the one spot a player building a step actually wants came back red. | The actor is excluded. It is the only obstacle in the world that can walk away. |
| **X13** | **`trigger_size` on an obstacle volume was decoration.** `LevelObstacle2D` builds a shape from it only when the scene authors none, and all four author one. B0's was widened to 560 when the paddy grew and stayed 360 in the shape that is used. | Both are set together now, and the audit reads the geometry rather than the export. |

---

## Where it is still soft

Honest list. None of these lets you finish the level without drawing.

- **G3 has no requirement strip.** It is a bare terrace face with no obstacle volume, so
  the player gets no hint about what to draw. It is the one gate the level never explains.
- **The stretch between G2 and G3** (x 920–1160) and **between G6 and G7** (x 2960–3320)
  are walks. That is deliberate breathing room, but they are the longest stretches left.
- **Node 2, the straw, does not gate passage.** Searching it is a reward — the sketchbook
  page and the chest — not a wall. If the level ever needs another beat, that is where it
  would go.
- **Combed and tunnelled straw look the same.** A tunnel should read as a hole.
- The **ink budget is 12** and the level now asks for four drawings on the critical path.
  Nobody has measured a whole run against that. Worth doing before the next playtest.

---

## When to update this

Whenever a gate is added, moved or retuned, or an X comes back. The numbers in the
**reaches** column are printed by T1 on every run — if one of them climbs, something opened
that should not have.
