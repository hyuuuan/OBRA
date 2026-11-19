# Expert review feedback (November 2026)

Four game developers evaluated O.B.R.A. with the PLAY heuristic form between 11 and 17 November
2026. This file keeps what they found and suggested, so it can be worked through later. Status is
as of **19 November 2026**.

The reviewers' names and contact details stay in the form's response sheet
(`PLAY review responses.xlsx`), outside the repo.

**How to read the ratings:** M is met, P is partly met, N is not met, CA is cannot assess.
Severity runs from 0 to 4, where higher is worse.

---

## The reviewers

| | Role | Experience | Reviewed | Materials reviewed |
|---|---|---|---|---|
| R1 | Head programmer, studio founder | 5 years | 11 Nov | All five* |
| R2 | Game developer, IT instructor | 5 years | 12 Nov | Video, demo build, concept art |
| R3 | Game developer | 4 years | 13 Nov | All five* |
| R4 | Freelancer | 5 years | 17 Nov | All five* |

\* Design plan, flowchart, video of the drawing-to-entity mechanic, playable demo, concept art.
All four played the demo.

⚠ **R1–R3 played a build from before 13 November.** That build predates these changes:
- the Terraces tutorial rework (13 Nov);
- the minimap room fix (13 Nov);
- the music and sound pass (14–15 Nov);
- the Dagat route fixes (12 and 16 Nov).

The build R4 played is not recorded. Re-check any item below on a current build before working on
it.

## Overall verdicts

| | Verdict | The first change they would make |
|---|---|---|
| R1 | Professional and complete. The bugs are easy to overlook, and the game is ready to publish. | More humorous and emotional, casual dialogue, not only poetic lines |
| R2 | The design is good. | Make all the art consistent in style and scale |
| R3 | Up to standard, and comparable to popular games. | Improve the audio |
| R4 | The design complements every detail. | None |

## Items rated below Met

R4 rated every item M. Items rated P by two reviewers are in **bold**.

| Item | Heuristic, in short | R1 | R2 | R3 |
|---|---|---|---|---|
| I-A1 | Fun, with no repetitive tasks | P (1) | | |
| I-A4 | Gameplay is long and keeps interest | P (1) | | |
| I-A5 | Varied pacing keeps fatigue down | | P (1) | |
| **I-B2** | **Pressure without frustration; difficulty grows with mastery** | **P (2)** | **P (1)** | |
| I-B3 | Easy to learn, harder to master | | | P (2) |
| I-B6 | AI is tough enough to need new tactics | P (2) | | |
| **I-D3** | **Rewards deepen immersion** | **P (1)** | **P (1)** | |
| I-E1 | Supports a variety of play styles | | P (1) | |
| I-E2 | Several ways to win | P (1) | | |
| I-E4 | AI settings for every skill level | P (1) | CA | |
| **II-A1** | **Emotional connection to the world and the avatar** | **P (1)** | **P (1)** | |
| II-B1 | Offers something different | | P (1) | |
| II-C1 | Uses humour well | P (1) | | |
| **II-D1** | **Audio and visuals add to immersion** | **P (3)** | | **P (2)** |
| III-A1 | No manual needed | | P (1) | |
| III-A2 | No tutorial needed | | P (1) | |
| **III-C2** | **Audio and visual feedback** | **N (3)** | | **P (2)** |
| III-D3 | Rewards deepen immersion (repeats I-D3) | P (1) | | |
| III-F1 | Screen layout is efficient and pleasing | | P (1) | |
| III-F2 | The UI is consistent | | P (1) | |
| III-F3 | The HUD feels part of the game | | P (1) | |
| III-F4 | Art is recognisable and speaks to its function | | P (1) | |

R1 also gave severity 1 to five items it rated M:
- III-A1 and III-A2: no manual or tutorial needed;
- III-G1: navigation (the minimap bug, B3);
- III-H4: context help (getting stuck, S8);
- III-I1: the story draws you in (the poetic tone, S5).

---

## Bugs logged

All five were logged by R1.

### B1. Level 2 put her at the birds instead of the dancers (severity 4)
- **Status: not reproduced.** R1 wrote that they could not be sure it was a bug.
- **Most likely cause:** going back into a level resumes it at its last saved checkpoint
  (`LevelBase._resume_saved_checkpoint`, [level_base.gd](../game/scripts/level_base.gd)). In
  Piyesta that is the bird alley once the player has reached it. Restart and New Game clear the
  checkpoint.
- **Shared saves:** until 11 November, exported builds kept their saves in a folder shared
  between builds ([user_data.gd](../game/scripts/user_data.gd)). Progress from an earlier session
  could therefore carry over.
- **No other route found:** in [level_2.gd](../game/scripts/level_2.gd), only the doors move her
  between places (church, then alley 1, then alley 2).
- **Next:** ask R1 what they did just before it happened. If it is real, write a probe that
  reproduces it before fixing anything.

### B2. A level could not be finished even when every condition was met (severity 3)
- R1 logged it under "end game". In I-E2 they added that one of the ways to win could not
  finish the level.
- **Status: probably fixed after the review, if it was Dagat.**
  - 12 Nov: the boat route could not lead, fight or land.
  - 16 Nov: reaching the island before the bakunawa was answered meant the level could never end
    ([PR #247](https://github.com/hyuuuan/OBRA/pull/247)).
  - `run_level3_island_arrival_probe` passes on 19 Nov.
- **Next:** ask R1 which level and which way they had chosen. If it was Mayon, nothing matching
  has been found yet; `run_level5_finish_walk` is the place to start.

### B3. The haystack's minimap overlapped the background, in Terraces (severity 2)
- **Status: fixed** on 13 Nov, after the review: inside a room the minimap shows only the room
  ([level_minimap.gd](../game/scripts/level_minimap.gd)).
- `run_minimap_probe` and `run_room_probe` pass on 19 Nov.

### B4. Settings: the letter "n" disappears when a setting is hovered or toggled (severity 1)
- **Status: fixed on 19 Nov for the likely cause.** It never reproduced on a Retina Mac: at four
  window sizes, normal, hovered and toggled on, the "n" always showed.
- **Likely cause:**
  - Both switches end in "n": "Fullscreen" and "Reduce motion"
    ([settings_overlay.tscn](../game/ui/settings_overlay.tscn)).
  - Each button was exactly as wide as its text, a 4 px gap and the 48 px switch, with nothing
    to spare (Fullscreen: 148 + 4 + 48 = 200).
  - UIFeedback lifts a hovered or focused button to 1.02, and a switch keeps focus after it is
    toggled. Those are the two states the reviewer named.
  - At that size the pixel font is drawn again, and on a screen that draws it a little wider the
    last letter could land under the opaque switch.
- **Fix:** the gap is 16 px, via the CheckButton `h_separation` set in
  [build_theme.gd](../game/tools/build_theme.gd).
  [run_screens_fit_probe](../game/tests/run_screens_fit_probe.gd) needs at least 12 px; it fails
  at the old 4.
- **Still to confirm:** R1's screen, to be sure this was the cause.

### B5. The game has no logo as its icon (severity 1)
- **Status: fixed on 19 Nov.** Before that, [project.godot](../game/project.godot) set no
  `config/icon` and both presets in [export_presets.cfg](../game/export_presets.cfg) had
  `application/icon=""`, so builds showed Godot's default icon.
- **The icon** is the framed painting that opens the wordmark
  ([obra_logo.png](../game/assets/ui/obra_logo.png)), cut out and enlarged by whole pixels to a
  1024 × 1024 square ([obra_icon.png](../game/assets/ui/obra_icon.png)). The project and both
  presets now name it.
- **Checked:** in a macOS and a Windows export, the `.app`'s `icon.icns` and all six of the
  `.exe`'s icon sizes show it.
- **It is a stand-in** until a purpose-drawn square icon exists (`ART_PLACEHOLDERS.md`, "The
  game's icon").

---

## Suggestions to consider

Each suggestion gives who raised it, what they said, where it stands now, and a possible next
step. The next steps are proposals, not decisions.

### S1. Audio (R1, R3; R3's first change)
- **What they said:**
  - R1: there is no background music or sound effects (II-D1 P3, III-C2 N3).
  - R3: some parts have no music, and some things that respond visually make no sound (II-D1 P2,
    III-C2 P2).
- **Where it stands:** the build they played had almost no sound. Music for every place and the
  sound effects landed on 14–15 Nov (`AUDIO_PLAN.md`, `audio/README.md`), and the volume sliders
  came back to Settings. Mayon's music is still marked provisional.
- **Next:** ask R3 to play a current build. List any visual response that is still silent.

### S2. First-time play in Terraces (R1, R2)
- **What they said:**
  - R1 found the first level confusing and had to guess more than intended, and would have been
    lost without the demo video (I-A1, I-A4, I-B2).
  - R2: "Can add actual tutorials" (III-A1, III-A2 P1).
  - R3, by contrast, found onboarding easy.
- **Where it stands:** the Terraces tutorial was reworked on 13 Nov, after both reviews. The
  cards at the door now play back to back, and every card waits for the player to do what it shows
  (`LEVEL_1.md`, `TutorialDirector.teach_the_door`).
- **Next:** watch a first-time player go through Terraces without the video.

### S3. The difficulty curve (R1, R2, R3)
- **What they said:**
  - R1: the first level was confusing, but the next ones were easier than they looked (I-B2 P2).
  - R2: "The difficulty is great just need a little tweaking" (I-B2 P1).
  - R3: not hard to master, which they saw as a deliberate choice to suit a wide audience
    (I-B3 P2).
- **Next:** decide whether Levels 2–4 should ask more of the player as they go. This is a design
  call.

### S4. Art consistency (R2; R2's first change)
- **What they said:** make all the art consistent in style and scale (III-F1 to III-F4, P1
  each). R2 also suggested more art style (I-E1).
- **Where it stands:** stand-in art is listed in `ART_PLACEHOLDERS.md`. Mayon's generated art
  still needs art-direction review.
- **Next:** audit character, prop and drawing scale across the five levels, then the style.

### S5. Dialogue tone and humour (R1, R2; R1's first change)
- **What they said:**
  - R1: the story reads as riddles and poetry, which suits readers of literature but is hard for
    a casual player (III-I1). There is very little humour (II-C1 P1).
  - R1 wants more humorous or emotional exchanges between the characters. The few casual lines
    that exist are easy to overlook and need polish to stand out.
  - R2: give the avatar a deeper purpose (II-A1 P1).
  - R3, by contrast, related to the apo and felt Lola's caring personality.
- **Next:** add a few plain, warm or funny exchanges (Lolo is the natural voice for them), and make
  the casual lines stand out.
- ⚠ Every line still obeys the rule that no dialogue names a drawable class. The audits enforce
  it.

### S6. Rewards (R1, R2)
- **What they said:**
  - R1: the reward is the player's own growing drawing skill, which is internal and optional
    (I-D3, III-D3 P1).
  - R2: add rewards that make the player want to play more (I-D3 P1).
- **Where it stands:** the game already has collectibles: the bag's cards, the five flowers and
  the diary pages.
- **Next:** decide whether to make the existing rewards more visible or to add explicit ones. This
  is a design call.

### S7. AI and challenge (R1, R2)
- **What they said:**
  - R1: the challenge is discovering what to draw, not trying new tactics (I-B6 P2).
  - R1: the AI's behaviour does not change across the game (I-E4 P1).
  - R2 could not assess I-E4.
- **Where it stands:** there are no difficulty settings. Escalating hints do part of that job
  (`hint_escalation` in `level_01.json` and `level_02.json`), and R3 praised them.
- **Next:** either let Dilim's creatures ramp up or state in the manuscript why difficulty
  settings are out of scope. This is a design call.

### S8. Getting stuck (R1)
- **What they said:** at times the player cannot go on even with the context hints, because of
  physics or a confusing situation. R1 thought a normal player was unlikely to hit it (III-H4,
  severity 1).
- **Where it stands:** since 16 Nov, falling below Terraces or Piyesta no longer leaves her stuck
  up in the sky (`run_fall_rescue_probe`).
- **Next:** ask R1 for the spots where they got stuck.

### S9. Engagement and appeal (R2)
- **What they said:**
  - "Some parts needs to improve so that the user will keep engaged" (I-A5 P1).
  - "Can improve overall attraction" (II-B1 P1).
- **Next:** ask R2 which parts they meant.

### S10. The review materials (R4)
- **What they said:** the documents were understandable but plain text. R4 suggested a video
  presentation, or images, for the materials too.
- R1 and R3 praised the materials: R1 called them impressive and well documented, and R3 found the
  landing page clear and creative.
- **Next:** add visuals for the defence and the manuscript's appendix.

---

## What they liked (keep these)

- **Several ways to solve each problem.** It suits different players and makes choices matter
  (R3). R1 agreed there are several ways to win.
- **Every painting plays differently,** for example fighting folklore creatures in Dilim (R3).
- **Hints that grow when a player struggles** (R3).
- **Changes stay put when backtracking** (R3).
- **Easy to start, with depth underneath** (R3).
- **Lola and the apo:** R3 related to the apo and felt Lola's caring personality.
- **The Filipino folklore** (R3).
- **Navigation** was excellent (R1).
- **The documentation** was impressive and worth reading (R1, R3).

## Questions to send back

- **R1:**
  - Which level could not be finished, and which way had you chosen? (B2)
  - What did you do just before Level 2 put you at the birds? Did you leave and come back, or
    continue a save? (B1)
  - Which system and screen did you play on? (B4)
  - Where did you get stuck? (S8)
- **R2:** Which parts lost your interest (S9)? Which pieces of art looked out of style or scale
  (S4)?
- **R3:** On a current build, which interactions still have no sound? (S1)
