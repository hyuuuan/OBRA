# Audio plan: music for every place, sound for every action

The build order for the rest of the game's audio, written on 2026-11-14 so the next session can
start cold. **Read [audio/README.md](audio/README.md) first**; it is the pipeline. This file is
what to build with it, and in what order.

## Where it stands

- **Branch `famitracker-audio`**, not pushed. Slice 1 is built and green (see the end of this
  file):
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
| Who composes | **Claude composes every module.** |
| Style | **NES**, on the **2A03 + VRC7**. Original pieces in the NES idiom, never a recreation of an existing game's music. |
| Route | FamiTracker text modules → `famirender` → WAV with a `smpl` loop. No OGG, no NSF at runtime. |
| Safety | Render only through `build_music.py`, inside the sandbox. Any new dependency or download: ask first, naming it, its source and its size. |
| Music, where | **Every place.** The menu, the loading screen, Lola's house, Levels 1–4, **Mayon** (this reverses the 1 Nov "Mayon is silent"; see PR 9), and the ending screen. |
| Boss and finale music | **Yes.** Dagat's Bakunawa and Dilim's finale get their own loop, then the level's loop returns. |
| Ambience | **Yes.** A quiet bed under each level's music, on its own player. |
| Sound effects | **All four groups**: drawing and morphing, the apo's moves (**with footsteps**), combat, and level props. Plus a **level-complete jingle**. |
| Visual twin | **Every sound cue has a visual equivalent** (Dilim's rule): each sound below plays beside something the screen already shows. Music and ambience carry no information and need none. |

## Ask Kent once, at the start of the next session

Each question has a default. Build from the default if Kent has no preference.

1. **The menu track: keep, adjust, or redo?** He has the render, but has not heard it yet.
2. **Mayon's summit.** The design has it "quiet: no ash, no tremor, no sound" while Lola
   paints. Default: **keep the summit silent**. The ascent and the heart have music, it stops as
   the summit begins, and `mayon_ending` plays from the ending on.

## Build order

One PR per row, each green on its own, branched off `main` with a short kebab-case name.
Riskiest first: the shared plumbing, then the music, then the sounds.

| # | Branch | What | Suites |
|---|---|---|---|
| 1 | `famitracker-audio` | Kent listens to `music.menu`; adjust; push and open the PR on his OK. | done (see the end) |
| 2 | `audio-plumbing` | **Volume sliders** back in `ui/settings_overlay.tscn` (taken out while nothing could be heard; the profile and buses already work). **LevelBase hook `_level_music() -> StringName`**, default `&""` (off); a level that returns an id plays it on entry. **`_level_ambience()`** likewise, played by a new `AudioDirector.play_ambience` on a second looping player (`audio.json` → `ambience`, `audio/ambience/<id>.txt`, `build_music.py` learns the section). **Crossfade in `play_music`** (~0.6 s, `Tween.TWEEN_PAUSE_PROCESS`), so a boss loop or a new place does not cut. **Per-id minimum interval in `play_sfx`** (see traps). | **full** (an autoload and shared LevelBase plumbing) |
| 3 | `music-house` | Turn the helper into `tools/famitext.py`. Write `music.house`; `hub.gd` opts in. **Loading screen**: the menu's loop starts on the boot loading screen (the same title card) and carries into the menu; a level load keeps the outgoing music until the next place's begins. | python, run_audio_probe, run_hub_audit, run_new_game_probe, run_journey_probe |
| 4 | `music-payyo` | `music.level_1` and `ambience.level_1` (wind); `game_level.gd` opts in. | python, run_audio_probe, run_level1_audit, run_walk_level1, run_level_ready |
| 5 | `music-piyesta` | `music.level_2` and `ambience.level_2` (a crowd's murmur in noise); `level_2.gd` opts in. ⚠ The dance minigame (`dance_minigame.gd`, `cue_judged`) keeps its own beat: check that the loop does not fight it, and pause the loop for the dance if it does. | python, run_audio_probe, run_level2_audit, run_dance_probe, run_play_level2 |
| 6 | `music-dagat` | `music.level_3` and `ambience.level_3` (waves); `level_3.gd` opts in. | python, run_audio_probe, run_level3_audit, run_level3_play_probe, run_water_audit |
| 7 | `music-dilim` | `music.level_4` and `ambience.level_4` (night insects); `level_4.gd` opts in. Sparse and low, so the tik-tik's call and the tiyanak's cry (gameplay information) read over it. It stops at the dawn. | python, run_audio_probe, run_level4_sound_probe, run_darkness_probe, run_makiling_probe |
| 8 | `music-bosses` | `music.bakunawa` (Dagat) and `music.dilim_finale`, crossfaded in by the level when the fight or finale opens and back out when it ends. | python, run_audio_probe, run_bakunawa_probe, run_level3_finish_probe, run_level4_sound_probe |
| 9 | `music-mayon` | **Reverses the 1 Nov decision**, at Kent's word (2026-11-14). `music.level_5` for the ascent and the heart; the summit silent (question 2); `mayon_ending` is already called by `level_5.gd` on the ending, and `mayon_brush` by the brush. Replace `level_5.gd`'s `stop_music()` on entry with the hook. Change `run_level5_audit._audit_mayon_is_silent` to assert the new rule (music in the ascent, none at the summit). Update `LEVEL_5.md`, `CLAUDE.md` §4 and `LEVEL5_Mayon/authored/README.md`. | python, run_audio_probe, run_level5_audit, run_level5_summit_probe, run_level5_frame_probe, run_walk_level5 |
| 10 | `music-ending` | The ending screen's music (`music.ending`, or `mayon_ending` carried on if it flows straight in), and the **level-complete jingle** (`sfx.level_complete`, beside the overlay). The jingle ducks the level's loop for its length. | python, run_audio_probe, run_level5_endings_probe, the level finish probes |
| 11 | `sfx-core` | The one-shot path end to end. The existing ids get files, and the ones not yet called get call sites (table A). | python, run_audio_probe, run_button_feedback_probe, run_diary_probe, the checkpoint and inventory probes |
| 12 | `sfx-drawing` | Drawing, recognition, morphing and placing (table B). | python, run_audio_probe, run_morph_gate_probe, run_placement_probe, run_revert_probe, run_ink_economy_probe |
| 13 | `sfx-moves` | The apo's body, footsteps included (table C). | python, run_audio_probe, run_locomotion_probe, run_water_audit, run_swim_reach_probe, run_ladder_angle_probe |
| 14 | `sfx-combat` | Weapons and foes (table D). | python, run_audio_probe, run_weapon_probe, run_combat_probe, run_enemy_probe |
| 15 | `sfx-places` | Dilim's four (files only; already called) and each level's props (table E). | python, run_audio_probe, each level's own probes |

**Every PR** also runs these, and greps the output for `SCRIPT ERROR`, `Parse Error`,
`^ERROR` and `Error calling`. Godot's exit-time "resources still in use" lines are the baseline
on main.

- `.venv/bin/python tools/build_music.py --check`
- `godot --headless --path game --import`
- `run_audio_probe`

**Every new check** is mutation-tested. **Every new sound** gets a probe line that it is asked
for where its visual shows, as `run_level4_sound_probe` does. Every render is sent to Kent to
listen to, and stays provisional in `audio/README.md` until he has.

## The music, place by place

Every piece is the same chip set at the same fixed loudness, so their levels relate. Lengths:

- a music loop, 20–40 s;
- an ambience bed, 8–15 s, mixed well under the music;
- a jingle, under 4 s.

| Id | Place | Brief |
|---|---|---|
| `music.menu` | Title card, and the boot loading screen | **Done** (provisional): E minor, 112 BPM, flute lead over chorus pads; arpeggio with echo. |
| `music.house` | Lola's house (hub) | Warm, small, still. The menu's motif slowed, solo VRC7 piano or vibraphone over one pad. 80–90 BPM. No drums. |
| `music.level_1` | Payyo, the terraces | Morning in the mountains: pentatonic, open fifths, a bamboo-flute-like VRC7 flute, gong-like figures on the soft bell. A gentle walking pulse, 100–110 BPM. |
| `music.level_2` | Piyesta, the fiesta plaza | Festive and bright: a brass-band feel (VRC7 trumpet and brass, guitar strums as arpeggios), a 2/4 march or a 6/8 lilt, 120–130 BPM, busy noise percussion. |
| `music.level_3` | Dagat, the sea | A flowing 3/4: broken-chord arpeggios like waves (pulse with echo), VRC7 chorus and vibraphone, a long-breathed clarinet line. 90–100 BPM. |
| `music.bakunawa` | Dagat, the Bakunawa | The sea theme's motif in a minor key, driving 140 BPM, a low FM bass ostinato and noise tom fills. |
| `music.level_4` | Dilim, the forest at night | Sparse and low: a drone on the bass, a few soft bell notes far apart, a minor second that does not resolve. No snare. **Leaves the mid and high band to the creatures.** Stops at the dawn. |
| `music.dilim_finale` | Dilim, the last waves before dawn | The drone with a pulse under it, rising; it breaks off at the dawn. |
| `music.level_5` | Mayon, the ascent and the heart | Lola's motif (the menu's) worn thin: fewer voices with each act, ending on a single line. Stops as the summit begins. |
| `mayon_ending` | Lola's easel, the house epilogue | The motif whole again, warm: "Lolo. Let's go home." |
| `music.ending` | The ending screen | `mayon_ending` carried on, or a short coda of it. |
| `ambience.level_1..4` | Under each level | Payyo wind (noise swells); Piyesta crowd murmur (noise with a slow volume walk); Dagat waves (long noise swells); Dilim insects (high pulse chirps, sparse). |

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
| `level_complete` | the level-complete overlay opening (PR 10) | the overlay |

**B. Drawing and morphing** (new ids)

| Id | Trigger | Visual twin |
|---|---|---|
| `draw_submit` | `DrawPanel.drawing_ready` | the canvas closing |
| `recognised` | `SketchClient.prediction_received`, accepted | the morph card |
| `declined` | `DrawPanel.recognition_declined` / `SketchClient.entity_declined` | the decline feedback. ⚠ Not Mayon's brush refusal, which must reuse no decline feedback. |
| `morph` | `MorphLife.form_changed` into a drawn form | `morph_flash.gd` |
| `revert` | `ActionPromptHud.revert_requested` | the flash back |
| `place` / `place_refused` | `PlacementController.placement_confirmed` / `placement_rejected` | the utility settling / the ghost's refusal tint |
| `ink_low` / `ink_empty` | `InkDrain.low_ink` / `ink_emptied`; `DrawingCanvas.ink_blocked` | the gauge |

**C. The apo's body** (new ids; throttled)

| Id | Trigger | Visual twin |
|---|---|---|
| `step` | `wanderer.gd _advance_stride`, once per footfall, soft | the walk cycle's footfall |
| `jump` | `wanderer.gd _jump` | the jump pose |
| `land` | `wanderer.gd _leave_a_mark`, over a fall speed | the landing mark |
| `swim` | `wanderer.gd _swim`, once per stroke | the swim stroke pose |
| `splash` | entering water | the splash |
| `ladder` | each rung climbed (`begin_ladder` and stepping) | the climb |
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
| `mayon_brush` | `level_5.gd` (already called) | the brush stroke |
| `door` / `unlock` | `PiyestaDoor2D`, `Lockable2D.unlocked`, `WardLock2D.opened`, `Baul2D.opened` | the door or lid opening |
| `candle` | `ChurchInterior2D.kandila_placed` | the flame |
| `scatter` | `DancerGroup2D.scattered` | the dancers running |
| `dance_cue` | `DanceMinigame.cue_judged` (by verdict) | the cue's judgement |
| `cast` / `reel` | `FishingLine2D.splashed` / `reeled_in` | the line |
| `gift` | `Bakunawa2D.gift_offered` | the gift |
| `painting` | `NextPainting2D.taken` / `BrushStand2D.taken` | the painting lifting |

## Traps to plan around

- **Eight SFX voices.** `AudioDirector` reuses the oldest past eight. Footsteps, swim strokes,
  ladder rungs and landings come constantly, so PR 2 gives `play_sfx` a per-id minimum
  interval. Otherwise they evict the sounds that carry information: Dilim's calls.
- **Dilim's sounds are gameplay.** The music and the insects under them stay out of their band,
  and their loudness is the strength passed. The edge ripples stay.
- **Footsteps tire.** Keep them soft (far under the music) and short, one per footfall, never
  per frame.
- **Mayon's reversal touches settled text.** "Mayon is silent" is in `CLAUDE.md` §4,
  `LEVEL_5.md` and the authored README, and `run_level5_audit` asserts it. PR 9 changes all of
  them together, citing Kent's 2026-11-14 answer. The summit's quiet is a design beat; keep it
  unless Kent says otherwise (question 2).
- **Pause.** `AudioDirector` runs while paused, so music plays on under menus. Keep that unless
  Kent says otherwise.
- **Repo size.** About 4 MB per minute of loop. Thirteen loops at 20–40 s plus four short beds
  come to about 35–45 MB. If that is too much, OGG is the fallback; it needs `oggenc`, a new dev
  tool, so ask first.
- **The renderer refuses what it cannot play faithfully**, DPCM included, and a mix that clips.
  Write within the subset (audio/README.md), and lower volumes rather than fight it.
- **No sound reuses another's meaning.** `declined`, `place_refused` and Mayon's refusals each
  sound distinct.
- **Look before saying done.** Headless cannot listen. Send Kent each render.

## Slice 1 verification (2026-11-14)

`tools/run_suites.sh only python run_audio_probe run_level5_audit run_level4_sound_probe
run_new_game_probe run_dev_mode_probe run_import_guard_probe run_screens_fit_probe
run_motion_probe run_journey_probe run_tests`: **all 11 passed.**

The log has no `SCRIPT ERROR`, `Parse Error` or `Error calling`. Its only `^ERROR` lines are
Godot's exit-time leak reports, which the same probes print on main.

`build_music.py --check` passes: the render is deterministic, byte for byte.
