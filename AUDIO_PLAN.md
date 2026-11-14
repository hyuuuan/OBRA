# Audio plan: music for every place, sound for every action

The build order for the rest of the game's audio, written on 2026-11-14 so the next session can
start cold. **Read [audio/README.md](audio/README.md) first**; it is the pipeline. This file is
what to build with it, and in what order.

## Where it stands

- **Branch `famitracker-audio`**, not pushed. Slice 1 is built:
  - the renderer (`tools/famirender.py`, emu2413 vendored and pinned) and the sandboxed builder
    (`tools/build_music.py`, `tools/famirender.sb`);
  - `music.menu`, which the main menu plays and stops;
  - `run_audio_probe`, `tests/test_famirender.py` and `tests/test_build_music.py`, every check
    mutation-tested.
- **Not yet done on it:**
  - Kent has not listened to `music.menu`.
  - The branch has no PR. Ask Kent before pushing.
- **Helper:** `music/menu.txt` was written with a throwaway helper (grid / put / line /
  transpose, about 150 lines). A copy is in the side-session notes folder as
  `compose_menu.py`. PR 3 turns it into `tools/famitext.py`, so every module is written the
  same way. The `.txt` stays the source.

## Settled (Kent, 2026-11-14): do not re-ask

| Topic | Decision |
|---|---|
| Who composes | **Claude composes every module**: a unique loop for each place, a sound for each action. |
| Style | **NES**, on the **2A03 + VRC7**. Original pieces in the NES idiom, never a recreation of an existing game's music. |
| Route | FamiTracker text modules → `famirender` → WAV with a `smpl` loop. No OGG, no NSF at runtime. |
| Safety | Render only through `build_music.py`, inside the sandbox. Any new dependency or download: ask first, naming it, its source and its size. |
| Mayon | **Silent.** Its ids stay without files; `run_level5_audit` asserts it, and `level_5.gd` stops any music on entry. |
| Visual twin | **Every sound cue has a visual equivalent** (Dilim's rule): each sound below plays beside something the screen already shows. Music carries no information and needs none. |

## Ask Kent once, at the start of the next session

Each question has a default. Build from the default if Kent has no preference.

1. **The menu track: keep, adjust, or redo?** He has the render, but has not heard it yet.
2. **Does the house have music of its own?** Default: yes, a quiet `music.house`.
3. **Does a level's music change inside the level** (a finale, the dawn)? Default: one loop per
   level, through checkpoints and respawns. Dilim's music stops at the dawn, and `sfx.dawn`
   plays.
4. **Footsteps?** Default: none in the first pass. They are constant, and walking already shows.

## Build order

One PR per row, each green on its own, branched off `main` with a short kebab-case name.
Riskiest first: the shared hook, then the music, then the sounds.

| # | Branch | What | Suites |
|---|---|---|---|
| 1 | `famitracker-audio` | Kent listens to `music.menu`; adjust; push and open the PR on his OK. | done (see below) |
| 2 | `audio-volume-and-hook` | Bring back the **Master / Music / SFX sliders** in `ui/settings_overlay.tscn` (taken out while nothing could be heard; the profile and buses already work). Add a **LevelBase hook `_level_music() -> StringName`**, default `&""` (off). A level that returns an id plays it on entry. The **house** (`levels/hub/hub.gd`) plays `music.house`. | **full** (shared LevelBase plumbing) |
| 3 | `music-payyo` | Turn the helper into `tools/famitext.py`. Write `music.level_1`; `game_level.gd` opts in. | python, run_audio_probe, run_level1_audit, run_walk_level1, run_level_ready |
| 4 | `music-piyesta` | `music.level_2`; `level_2.gd` opts in. ⚠ The dance minigame (`dance_minigame.gd`, `cue_judged`) keeps its own beat: check that the loop does not fight it, and pause the loop for the dance if it does. | python, run_audio_probe, run_level2_audit, run_dance_probe, run_play_level2 |
| 5 | `music-dagat` | `music.level_3`; `level_3.gd` opts in. | python, run_audio_probe, run_level3_audit, run_level3_play_probe, run_water_audit |
| 6 | `music-dilim` | `music.level_4`; `level_4.gd` opts in. Sparse and low, so the tik-tik's call and the tiyanak's cry (gameplay information) read over it. It stops at the dawn. | python, run_audio_probe, run_level4_sound_probe, run_darkness_probe, run_makiling_probe |
| 7 | `sfx-core` | The one-shot path end to end. The existing ids get files, and the ones not yet called get call sites (table A). | python, run_audio_probe, run_button_feedback_probe, run_diary_probe, the checkpoint and inventory probes |
| 8 | `sfx-drawing` | Drawing, recognition, morphing and placing (table B). Adds per-id throttling to `AudioDirector.play_sfx` (see traps). | python, run_audio_probe, run_morph_gate_probe, run_placement_probe, run_revert_probe, run_ink_economy_probe |
| 9 | `sfx-moves` | The apo's body: jump, land, swim, splash, ladder, hurt (table C). | python, run_audio_probe, run_locomotion_probe, run_water_audit, run_swim_reach_probe, run_ladder_angle_probe |
| 10 | `sfx-combat` | Weapons and foes (table D). | python, run_audio_probe, run_weapon_probe, run_combat_probe, run_enemy_probe |
| 11 | `sfx-places` | Dilim's four (files only; already called) and each level's props (table E). | python, run_audio_probe, each level's own probes |

**Every PR** also runs these, and greps the output for `SCRIPT ERROR`, `Parse Error`,
`^ERROR` and `Error calling`:

- `.venv/bin/python tools/build_music.py --check`
- `godot --headless --path game --import`
- `run_audio_probe`

**Every new check** is mutation-tested. **Every new sound** gets a probe line that it is asked
for where its visual shows, as `run_level4_sound_probe` does.

## The music, place by place

Each is a loop: 8–40 s, 32 kHz mono, about 4 MB a minute. Keep the five loops under ~25 MB
together. Same chip set and loudness as the menu (the renderer's master gain is fixed, so
relative levels hold).

| Id | Place | Brief |
|---|---|---|
| `music.menu` | Title card | **Done** (provisional): E minor, 112 BPM, flute lead over chorus pads; arpeggio with echo. |
| `music.house` | Lola's house (hub) | Warm, small, still. The menu's motif slowed, solo VRC7 piano or vibraphone over one pad. 80–90 BPM. No drums. |
| `music.level_1` | Payyo, the terraces | Morning in the mountains: pentatonic, open fifths, a bamboo-flute-like VRC7 flute, bell-like gong figures on the soft bell. Gentle walking pulse, 100–110 BPM. Original; not a borrowed melody. |
| `music.level_2` | Piyesta, the fiesta plaza | Festive and bright: a brass-band feel (VRC7 trumpet and brass, guitar strums as arpeggios), a 2/4 march or a 6/8 lilt, 120–130 BPM, busy noise percussion. |
| `music.level_3` | Dagat, the sea | Flowing 3/4, broken-chord arpeggios like waves (pulse with echo), VRC7 chorus and vibraphone, a long-breathed clarinet line. 90–100 BPM. |
| `music.level_4` | Dilim, the forest at night | Sparse and low: a drone on the bass, a few soft bell notes far apart, a minor second that does not resolve. No snare. **Leaves the mid and high band to the creatures' calls.** Stops at the dawn. |
| `music.mayon_ending` | Mayon | **Stays silent** (settled). |

## The sounds, by what makes them

Every row names its trigger and its visual twin. Each sound is one module in
`audio/sfx/<id>.txt`, ending with `Cxx`, about 0.1–1.5 s long. **New ids** are added to
`audio.json` together with their call site, in the same PR.

**A. Core** (ids exist)

| Id | Trigger | Visual twin |
|---|---|---|
| `ui_click` | every `BaseButton.pressed` (`AudioDirector._on_node_added`) | the button's press animation |
| `ui_open` / `ui_close` | `modal_overlay.gd` open / close | the overlay's fade |
| `page_turn` | `DiaryBook.turn` | the page-turn animation |
| `checkpoint` | `CheckpointManager.checkpoint_written` (not on Mayon's silent saves) | the lantern lighting, the letterbox |
| `item_acquired` | `InventoryManager.item_added` | the item flying into its slot |
| `level_complete` | the level-complete overlay opening | the overlay |

**B. Drawing and morphing** (new ids)

| Id | Trigger | Visual twin |
|---|---|---|
| `draw_submit` | `DrawPanel.drawing_ready` | the canvas closing |
| `recognised` | `SketchClient.prediction_received`, accepted | the morph card |
| `declined` | `DrawPanel.recognition_declined` / `SketchClient.entity_declined` | the decline feedback. ⚠ Not the brush's refusal on Mayon, which must reuse no decline feedback. |
| `morph` | `MorphLife.form_changed` into a drawn form | `morph_flash.gd` |
| `revert` | `ActionPromptHud.revert_requested` | the flash back |
| `place` / `place_refused` | `PlacementController.placement_confirmed` / `placement_rejected` | the utility settling / the ghost's refusal tint |
| `ink_low` / `ink_empty` | `InkDrain.low_ink` / `ink_emptied`; `DrawingCanvas.ink_blocked` | the gauge |

**C. The apo's body** (new ids; throttled)

| Id | Trigger | Visual twin |
|---|---|---|
| `jump` | `wanderer.gd _jump` | the jump pose |
| `land` | `wanderer.gd _leave_a_mark`, over a fall speed | the landing mark |
| `swim` | `wanderer.gd _swim`, once per stroke | the swim stroke pose |
| `splash` | entering water | the splash |
| `ladder` | climbing a rung (`begin_ladder` and stepping), throttled | the climb |
| `hurt` | `PlayerHealth.hit_taken` | the hit flash, the hearts |

**D. Combat** (new ids)

| Id | Trigger | Visual twin |
|---|---|---|
| `swing` | `utility_object.gd _swing_blade`, `wanderer.show_swing` | the swing arc |
| `cannon` | `utility_object.gd _fire_cannon` | the shot |
| `throw` | `_throw_boomerang`, `StoneThrow2D.thrown`, Dilim's salt and ash throws | the thrown thing |
| `whip` | `level_4.gd _lash_the_whip` | the lash |
| `foe_hit` / `foe_down` | `Enemy2D` damaged / `died`; `Bakunawa2D.hit_taken`; `SeaCreature2D.struck` | the hit flash / the fall |

**E. Places** (Dilim's ids exist and are called; the rest are new)

| Id | Trigger | Visual twin |
|---|---|---|
| `tiktik_call`, `tiyanak_cry` | `level_4.gd`, at the strength passed | the edge ripples (`EdgeRipple.cue`) |
| `lantern_hit`, `dawn` | `level_4.gd` | the lantern's flicker; the dawn |
| `door` / `unlock` | `PiyestaDoor2D`, `Lockable2D.unlocked`, `WardLock2D.opened`, `Baul2D.opened` | the door or lid opening |
| `candle` | `ChurchInterior2D.kandila_placed` | the flame |
| `scatter` | `DancerGroup2D.scattered` | the dancers running |
| `dance_cue` | `DanceMinigame.cue_judged` (by verdict) | the cue's judgement |
| `reel` / `cast` | `FishingLine2D.splashed` / `reeled_in` | the line |
| `gift` | `Bakunawa2D.gift_offered` | the gift |
| `painting` | `NextPainting2D.taken` / `BrushStand2D.taken` | the painting lifting |

## Traps to plan around

- **Eight SFX voices.** `AudioDirector` reuses the oldest past eight. Constant sounds (swim,
  ladder, landings) need a per-id minimum interval in `play_sfx` (PR 8), or they evict the
  sounds that carry information: Dilim's calls.
- **Dilim's sounds are gameplay.** The music under them stays out of their band, and their
  loudness is the strength passed. The edge ripples stay.
- **Pause.** `AudioDirector` runs while paused, so music plays on under menus. Keep that unless
  Kent says otherwise.
- **The renderer refuses what it cannot play faithfully**, DPCM included, and a mix that clips.
  Write within the subset (audio/README.md), and lower volumes rather than fight it.
- **No sound reuses another's meaning.** Mayon's brush refusals must not sound like a decline.
  Mayon is silent anyway, but keep the ids distinct.
- **Look before saying done.** Headless cannot listen. Send Kent each render to listen to, and
  mark it provisional in `audio/README.md` until he has.

## Slice 1 verification (2026-11-14)

Recorded below when the run finished.
