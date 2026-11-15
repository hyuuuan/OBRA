# Audio plan: music for every place, sound for every action

What is left of the game's audio, and how to build it. It is written so that a session with no
memory of the earlier work can start cold (Kent, 2026-11-15: another Claude account, on this Mac,
carries on from here).

## Start here

1. **Read three files, in order:**
   - **this one**;
   - [audio/README.md](audio/README.md), the pipeline: modules, the renderer's subset, the
     effects it plays, `build_music.py`;
   - [tools/audio_lab/README.md](tools/audio_lab/README.md), the workbench: compose, render
     fenced, measure, and make Kent an MP3.

   Then read the root `CLAUDE.md` and `AGENTS.md` for the team's git and testing rules.
2. **Take the next row** of the build order below. One row is one PR, branched off `main`.
3. **The open questions are answered** (below). Compose, render, measure, and send Kent the
   MP3s as they render.
4. **Wire it in and test it** (Kent, 2026-11-15: build rows 6–12 in one go, MP3s as they come,
   so he can redirect). Every piece stays provisional until he has heard it. He decides when to
   push and merge, so ask; do not assume.

## Where it stands (2026-11-15)

Everything in this list is on `main` except the lab, which was written with this version of the
plan and lands with it.

- **The pipeline and the plumbing:**
  - PR #217: `tools/famirender.py`, `tools/build_music.py` and the sandbox.
  - PR #224: the volume sliders, the crossfade, the ambience player, sfx spacing, and the
    LevelBase hooks `_level_music()` and `_level_ambience()`.
- **Music and ambience:**
  - the menu and the loading screen (PRs #217, #226);
  - Lola's house, a kundiman (#226);
  - Terraces, Ifugao gangsa, with wind (#226);
  - Piyesta (#227): the plaza as a Sinulog drum corps, the dance minigame on its cues, the
    church hymn, and the street's hum.
- **Every sound effect group:** PRs #219–#223 and #225. They are tables A–E below.
- **The lab:** every shipped piece was written by a script in `tools/audio_lab/composers/`, and
  each script reproduces its module byte for byte. Read the nearest one before writing.
- **Left:** Dagat, Dilim, Mayon and the ending, rows 6–12. Each has Kent's own words for what
  he wants (2026-11-15).

## Settled (Kent): do not re-ask

| Topic | Decision |
|---|---|
| Who composes | **Claude composes every module.** |
| Style | **NES**, on the **2A03 + VRC7**. Original pieces in the NES idiom, never a recreation of an existing game's music. |
| Route | FamiTracker text modules → `famirender` → WAV with a `smpl` loop. No OGG, no NSF at runtime. |
| Safety | Render only through `build_music.py`, inside the sandbox. Any new dependency or download: ask first, naming it, its source and its size. |
| Music, where | **Every place.** The menu, the loading screen, Lola's house, Levels 1–4, **Mayon** (this reverses the 1 Nov "Mayon is silent"; see row 11), and the ending screen. |
| Boss and finale music | **Yes.** Dagat's Bakunawa and Dilim's finale get their own loop, then the level's loop returns. |
| Ambience | **Yes.** A quiet bed under each level's music, on its own player. |
| Sound effects | **All four groups**: drawing and morphing, the apo's moves (**with footsteps**), combat, and level props. Plus a **level-complete jingle**. |
| Style (2026-11-15) | **After a Fearofdark track Kent likes: jazzy chords, swing, slides and bends, energy.** Every piece still to write; the title theme stays. **But the house and Terraces follow Philippine traditions instead** (Kent, 2026-11-15): the house is a kundiman for rondalla, Terraces is after Ifugao gangsa music, each with only a touch of the new style. Still no thin high pulses or bright noise. **And a level whose place has a famous music of its own sounds like that music**: Piyesta is a Sinulog drum corps, because a Fearofdark-style take was rejected as "nothing similar". Ground each level in its own tradition first, and let the style be the energy and the harmony on top. |
| Visual twin | **Every sound cue has a visual equivalent** (Dilim's rule): each sound below plays beside something the screen already shows. Music and ambience carry no information and need none. |
| Dagat (2026-11-15) | **Three pieces.** One for the start of the level and rowing the ocean, which is also all a player hears if they never go into the water. A different one for swimming below the surface. A water-vibe boss fight for facing the Bakunawa. |
| Dilim (2026-11-15) | **A scary, unknown-sounding level theme.** A **thrilling version of it for the tikbalang's race.** The last challenge, **surviving the night, "as thrilling as possible", in the Fearofdark style.** |
| Mayon (2026-11-15) | **Different music in the memory lane** (Act Two's journey through the earlier levels), and **a peaceful piece when Lola is found** (the summit). This answers the old question 2: the summit is no longer silent. |
| Menu, revision 2 | **Kept.** Kent liked it and asked for an MP3 to share. (Old question 1, answered.) |
| A real song as the model (2026-11-15) | **Original music only.** A recording Kent supplies is measured for rhythm, band balance and form, and its melody is never taken. It is never committed: the repo is public. Kent chose this over shipping the Sinulog recording. |
| Loudness | **Every music loop at −18 dBFS RMS (±2), peak under −1 dBFS; an ambience bed around −33.** The pieces already shipped sit there, so a crossfade between places does not jump. |

## The open questions, answered (Kent, 2026-11-15): do not re-ask

Kent took every default, and chose to have rows 6–12 built in one go, each MP3 sent to him as it
renders so he can redirect, with nothing pushed until he says.

| Row | Question | Answer |
|---|---|---|
| 8 | **Does the Bakunawa's music play on all three routes?** The routes are fighting it (protector), slipping past it in the dark (pragmatist) and leading it home with a light (artist). | **Yes.** It plays from the moment the creature is met until its beat is solved, whatever the route. |
| 9 | **Does Dilim's theme play in the daytime stretches, or only at night?** | **The whole level.** It is the forest, which is always dark under the canopy; the race and the night replace it. |
| 10 | **Does the night's music build wave by wave, or play one loop?** | **It builds:** three arrangements of one piece, each fuller, switched at each wave without losing the bar (row 6). |
| 11 | **What does the ascent (Act One) get?** Kent named only the memory lane and Lola. | **`music.level_5`**: Lola's motif from the menu, worn thin under the ash and the wind, fewer voices as the climb goes on. |
| 11 | **When is Lola "found"?** | **When the summit opens** (`_summit` becomes `"quiet"`: the world goes white and she is seen painting with her back turned). |
| 11 | **What happens to the music when Lolo vanishes?** | **It stops in that same frame**, with no fade: he goes mid-sentence and so does the music. Nothing plays until Lola is found. |
| 12 | **What plays in the house epilogue and on the ending screen?** | **`mayon_ending` carries on into both.** It is the motif whole again, warm. |

## Build order

One PR per row, each green on its own, branched off `main` with a short kebab-case name.
Riskiest first: the shared plumbing, then the music, then the sounds.

| # | Branch | What | Suites |
|---|---|---|---|
| 1 | `famitracker-audio` | **Merged, #217.** The renderer, the sandboxed builder, `music.menu`. | done |
| 2 | `audio-plumbing` (**merged, #224**) | **Volume sliders** back in `ui/settings_overlay.tscn` (taken out while nothing could be heard; the profile and buses already work). **LevelBase hook `_level_music() -> StringName`**, default `&""` (off); a level that returns an id plays it on entry. **`_level_ambience()`** likewise, played by a new `AudioDirector.play_ambience` on a second looping player (`audio.json` → `ambience`, `audio/ambience/<id>.txt`, `build_music.py` learns the section). **Crossfade in `play_music`** (~0.6 s, `Tween.TWEEN_PAUSE_PROCESS`), so a boss loop or a new place does not cut. **Per-id minimum interval in `play_sfx`** (see traps). | **full** (an autoload and shared LevelBase plumbing) |
| 3 | `music-house` (**merged, #226**) | Turn the helper into `tools/famitext.py`. Write `music.house`; `hub.gd` opts in. **Loading screen**: the menu's loop starts on the boot loading screen (the same title card) and carries into the menu; a level load keeps the outgoing music until the next place's begins. | python, run_audio_probe, run_hub_audit, run_new_game_probe, run_journey_probe |
| 4 | `music-terraces` (**merged, #226**) | `music.level_1` and `ambience.level_1` (wind); `game_level.gd` opts in. | python, run_audio_probe, run_level1_audit, run_walk_level1, run_level_ready |
| 5 | `music-piyesta` (**merged, #227**) | `music.level_2`, `music.dance`, `music.church`, `ambience.level_2`. `level_2.gd _refresh_the_place_audio` switches them by room, and is **the model for rows 7–11**. `DanceOverlay.music_id` restarts the dance music on every attempt, and `tests/test_piyesta_dance_music.py` holds its strikes to the cues: **the model for any music that has to line up with gameplay timing.** | python, run_audio_probe, run_level2_audit, run_dance_probe, run_play_level2 |
| 6 | `audio-keep-position` (**built**) | **`AudioDirector.play_music(id, fade, keep_position := false)`**: the incoming track starts at the outgoing one's playback position, not at its top. It exists so two **arrangements of one piece** can trade places mid-bar: Dagat's surface and deep music (row 7) and the night's three waves (row 10). They only line up if both are written to the **same length, to the row** (the same `frames`, `rows` and per-row speeds in famitext), so say so in the doc comment. The default stays false, so every current call is unchanged. **Test:** a probe check that the incoming player's `get_playback_position()` is within 50 ms of the outgoing's, and that `keep_position = false` still starts at 0. Mutation-test both. | **full** (an autoload) |
| 7 | `music-dagat` (**built**, provisional until Kent has listened) | **`music.level_3`** (the surface: the level's start, rowing, the shore; all a player hears if they never dive), **`music.level_3_deep`** (below the surface), **`ambience.level_3`** (waves, at the surface only). Add all three ids to `audio.json`. **Hook:** model it on `level_2.gd _refresh_the_place_audio`. Call `_refresh_the_place_audio(anchor_position)` from `level_3.gd _level_physics`, which already has `anchor_position` and `_waterline_y`. Work out the state, and act only when it changes (keep a memo like `_music_for`). The state is `"deep"` once `anchor_position.y > _waterline_y + DEEP_IN`, and `"surface"` again once `< _waterline_y + SURFACE_OUT`. **Use hysteresis** (e.g. 60 and 20 px; `AIR_DEPTH` is 30): a swimmer bobbing at the waterline must not flip the music every frame. In the boat (`_boat_carrying_player()`) it is always surface. Switch with `keep_position = true`, so a dive does not restart the tune. The waves bed stops under water (`stop_ambience`) and comes back at the surface. The music's piece is in "The music, place by place". **Tests** in `run_audio_probe`: entering Dagat plays `level_3` and the waves; a player placed deep gets `level_3_deep` with no waves, at the same position; back up restores both; one frame at the waterline does not switch; leaving the level stops the deep track too (an `_exit_tree` like `level_2.gd`'s). | python, run_audio_probe, run_level3_audit, run_level3_play_probe, run_level3_boat_probe, run_level3_sea_probe, run_water_audit, run_swim_reach_probe, run_nodraw_level3 |
| 8 | `music-bakunawa` (**built**, provisional until Kent has listened) | **`music.bakunawa`**, the water-vibe boss fight. **When:** from the moment the creature is met until `director.is_solved("L3_N2")`. It is met in `level_3.gd _on_obstacle_entered("L3_N2")`, where its arrival is said; set a flag there. `_on_bakunawa_approached`, which opens the choice, can come later for a swimmer. That one test covers all three ways it ends: `_on_gift_offered` (led home), `_on_bakunawa_quiet("FOUGHT")` (subdued), and the dark route's `solve_with_item("L3_N2", "the dark")`. Put it in row 7's `_refresh_the_place_audio` as a third state that wins over surface and deep. A lost stretch (`_lose_the_stretch`, three knocks) keeps it playing, since the fight is not over. When it is solved, crossfade back to the surface or deep music by where the player is. Check whether a checkpoint restore can put the player back before the meeting; if it can, clear the flag in the restore. Open question at the top: does it play on all three routes. **Tests:** meeting it plays `bakunawa`; solving by each route hands back; a lost stretch does not. | python, run_audio_probe, run_bakunawa_probe, run_level3_finish_probe, run_level3_trouble_probe, run_level3_play_probe |
| 9 | `music-dilim` (**built**, provisional until Kent has listened) | **`music.level_4`**, scary and unknown. **`music.level_4_race`**, the same material made thrilling, for the tikbalang's race. **`ambience.level_4`**, the night forest. **Race hook:** the race is live while `_tikbalang.is_racing()` (it starts in `level_4.gd _line_up_for_the_race`, via `Tikbalang2D.start_race`, and ends in `_on_race_finished(she_won)`). Poll it from `_level_physics` with a memo, as row 7 does, so a checkpoint restore mid-race cannot leave the race music on. Crossfade in at the start and back out at the end. ⚠ **Dilim's creature sounds are gameplay information** (Dilim's rule: every cue has a visual twin, but the sound still has to read). `tiktik_call` and `tiyanak_cry` must stay clearly audible over this music and the bed. **Test it in Python**, like `tests/test_piyesta_dance_music.py`: render the music and the bed, and render the two calls. Then assert that in the calls' strongest octave band, each call is at least 6 dB over the music plus bed. Measure that band first with `tools/audio_lab/ref/bands.py` on the calls' WAVs, and mutation-test it. ⚠ The old brief for the bed was "high pulse chirps"; Kent dislikes thin high pulses, so make it dark and low (soft FM, low noise swells). It must also stay out of the calls' band. Open question 9. | python, run_audio_probe, run_level4_sound_probe, run_level4_audit, run_level4_seg2_probe, run_level4_seg3_probe, run_darkness_probe, run_makiling_probe |
| 10 | `music-dilim-night` (**built**, provisional until Kent has listened) | **`music.dilim_night`**: the last challenge, surviving the night, as thrilling as possible, in the Fearofdark style (see below). Default (question 10): **three arrangements**, `dilim_night_1`, `_2` and `_3`, the same length to the row, each fuller. **Hooks**, all in `level_4.gd`, on `DilimFinale2D`'s signals (connected around line 445): `_on_night_began` starts `dilim_night_1`. `_on_wave_opened(index)` switches to `dilim_night_<index+1>` with `keep_position = true` (row 6). `_on_dawn` **cuts it** (`stop_music(0.0)` or a fade under 0.3 s) in the same moment the `dawn` sfx plays. A retried night (`DilimFinale2D.reset_for_restore`) returns to `level_4` until `began` fires again. Row 9's audibility test applies to every arrangement, and most to the fullest: the tik-tik's call is this night's (the finale's page is the tik-tik's). **Tests:** began → 1; each wave → the next, with the position kept; dawn → silence in that frame, with the `dawn` sfx; a restore → `level_4`. | python, run_audio_probe, run_level4_finale_probe, run_level4_sound_probe, run_level4_tiktik_probe, run_visual_level4_dawn (look at it) |
| 11 | `music-mayon` | **Reverses "Mayon is silent"** (Kent, 2026-11-14 and 2026-11-15). The pieces: **`music.level_5`**, the ascent (question 11); **four memory-lane pieces**, `music.memory_terraces`, `memory_piyesta`, `memory_dagat` and `memory_dilim`; **`music.lola`**, peaceful, when Lola is found; and **`mayon_ending`**, already in `audio.json` with an empty path and already called by `_bloom_the_places`. **The memory lane** is `_phase == "memories"`. Its twelve vignettes come in four groups of three: `payyo_*` (Terraces: say "Terraces", not "Payyo"), `piyesta_*`, `dagat_*` and `dilim_*`, in `level_05.json` `journey.vignettes`. `level_5.gd _tend_clusters` already computes the current vignette's id every frame. Map the id's prefix to its piece and crossfade over about 2 s (pass a `fade`), so walking from one memory into the next feels like remembering. **Lolo:** at `_vanish_lolo()`, `stop_music(0.0)`, in the same frame (question 11). **The summit:** in `_tend_summit`, where `_summit` becomes `"quiet"`, play `lola` (question 11). `_bloom_the_places` then plays `mayon_ending`, and `_reset_summit` must restart cleanly. `_play_own_ending` already calls `stop_music()` on the way home; row 12 decides what carries on. **The rules this reverses, all changed in this PR:** `run_level5_audit._audit_mayon_is_silent` asserts no players in the scene and no `mayon_*` id with a file. Keep "no AudioStreamPlayer in the scene", since everything goes through AudioDirector, and replace the rest with the new rule. Also update `CLAUDE.md` §4 ("Mayon is silent …" under "Still open on Mayon"), `LEVEL_5.md` and `LEVEL5_Mayon/authored/README.md`, citing Kent's words. Also give `mayon_brush` (the brush sfx) its file here. **Tests:** the ascent plays `level_5`; each memory group plays its piece; the music stops in the frame Lolo vanishes; the summit plays `lola`; the bloom plays `mayon_ending`. | python, run_audio_probe, run_level5_audit, run_level5_act_one_probe, run_level5_act_two_probe, run_level5_memory_walk, run_level5_summit_probe, run_level5_frame_probe, run_level5_endings_probe, run_walk_level5, run_level5_finish_walk, run_journey_probe |
| 12 | `music-ending` | The house epilogue and the ending screen (question 12: `mayon_ending` carries on). Make the **level-complete jingle** (`sfx.level_complete`, built in `sfx-core`) **duck the level's loop** for its 2.3 s, then bring it back. | python, run_audio_probe, run_level5_endings_probe, run_hub_audit, run_journey_probe, the level finish probes (run_level1_finish_probe, run_level2_finish_probe, run_level3_finish_probe) |
| S1 | `sfx-core` (merged) | **Built (provisional until Kent has listened).** The one-shot path end to end: table A's eight ids have modules and files, `item_acquired` and `level_complete` have call sites, and `unlock` (already called) is in `audio.json`. `run_sfx_core_probe` checks each is asked for beside its visual. | python, run_audio_probe, run_sfx_core_probe, run_button_feedback_probe, run_diary_probe, run_key_probe, run_level1_finish_probe |
| S2 | `sfx-drawing` (merged) | **Built (provisional until Kent has listened).** Drawing, recognition, morphing and placing (table B): nine new ids, each with its call site and file. `run_sfx_drawing_probe` checks each is asked for beside its visual, and that the brush's refusal is silent. | python, run_audio_probe, run_sfx_drawing_probe, run_brush_refusal_probe, run_morph_gate_probe, run_placement_probe, run_revert_probe, run_ink_economy_probe, run_draw_again_probe, run_level3_play_probe |
| S3 | `sfx-moves` (merged) | **Built (provisional until Kent has listened).** The apo's body, footsteps included (table C): six new ids with call sites, files and `spacing` entries (step 0.12 s, land 0.15, swim 0.25, ladder 0.12, splash 0.3, jump 0.1). `run_sfx_moves_probe` checks each is asked for beside its visual and that the spacing holds a repeat back. | python, run_audio_probe, run_sfx_moves_probe, run_locomotion_probe, run_water_audit, run_swim_reach_probe, run_ladder_angle_probe |
| S4 | `sfx-combat` (merged) | **Built (provisional until Kent has listened).** Weapons and foes (table D): six new ids, each with its call sites and file. `run_sfx_combat_probe` checks each is asked for beside its visual. | python, run_audio_probe, run_sfx_combat_probe, run_weapon_probe, run_combat_probe, run_enemy_probe, run_bakunawa_probe, run_level4_sound_probe, run_level4_whip_probe, run_satchel_probe, run_level2_alley_probe, run_level3_sea_probe, run_foe_health_probe, run_level4_tiktik_probe |
| S5 | `sfx-places` (merged) | **Built (provisional until Kent has listened).** Dilim's four get files (already called), and each level's props get ids, call sites and files (table E); Mayon's `mayon_brush` is left to `music-mayon`. `run_sfx_places_probe` checks each is asked for beside its visual. | python, run_audio_probe, run_sfx_places_probe, run_level4_sound_probe, run_level2_audit, run_dance_probe, run_level2_scene_probe, run_level2_chain_probe, run_level2_finish_probe, run_play_level2, run_level3_audit, run_bakunawa_probe, run_level3_finish_probe, run_level3_play_probe, run_key_probe, run_hub_audit, run_painting_entry_probe, run_level1_finish_probe |

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
| `music.menu` | Title card, and the boot loading screen | **Done**, revision 2 (Kent heard the first): D major pentatonic, ~129 BPM, a bamboo-flute theme over kulintang, agung, rondalla, babendil and dabakan, with the painting's sparkle. |
| `music.house` | Lola's house (hub) | **Done** (provisional): a kundiman for rondalla, bandurria tremolo over octavina, laud and guitar, E minor turning to E major, ~90 BPM. ⚠ After the run the house is the epilogue's: rows 11 and 12 decide whether `mayon_ending` carries on there instead (default: it does). |
| `music.level_1` | Terraces (Level 1) | **Done** (provisional), after Ifugao music, with `ambience.level_1` (wind): four short gangsa gongs in a hocket (redone after Kent heard them run together), bangibang-like wood in the gaps, a low drum, and a hudhud-like call and response over one gong; ~112 BPM straight. |
| `music.level_2` | Piyesta, the fiesta plaza | **Done** (provisional), the fourth take after Kent supplied the Sinulog theme recording and asked for its "tribal and upbeat" feel: a drum corps on its measured groove (deep tambol, snares, toms, the beat-two stop), agong and kulintang gongs, two trumpets, the crowd's Pit Senyor. Original; the recording itself is not used (copyrighted, and the repo is public). With `music.dance` (the minigame's own, on its cues), `music.church` (a solemn organ hymn inside the church) and `ambience.level_2` (a soft hum of a street, silent in the church). |
| `music.level_3` | Dagat, the surface: the level's start, rowing the bangka, the shore | Kent: "one audio for starting the level / rowing the ocean, in case the player just wants to not go to the ocean". It is a rowing song, so give it an unhurried stroke in every bar, the paddle's pull: a 6/8 or 3/4 swell around 90–100 BPM. Broken-chord arpeggios like waves (a 50% pulse with a soft echo, or the VRC7 vibraphone, patch 11), and a long-breathed lead on the VRC7 flute (patch 4) or clarinet (5). Fearofdark harmony (major 7ths and 9ths, a slide into the long notes) on a Visayan sea-song feel. Bright and open, not tense: this is the safe water. **Write it to share a skeleton with `level_3_deep`**: the same frames, rows and speeds, so row 6's `keep_position` can trade them mid-bar. |
| `music.level_3_deep` | Dagat, below the surface | Kent: "different audio for when the player is swimming, below the ocean". **The same piece, heard from under the water**: the same key, chords and length to the row. The drums and the bright lead go; low sustained FM (flute or soft bell, low), the arpeggios an octave down and slower, the bass held. It should feel muffled, enclosed and a little wondrous. No noise. It meets the surface piece mid-bar (row 6), so a dive sounds like the world closing over the apo, not like a new song. |
| `music.bakunawa` | Dagat, facing the Bakunawa | Kent: "an appropriate water-vibe boss fight music". The sea theme's motif turned minor and driving, 140–150 BPM. A rolling 12/8 or 6/8 so it still moves like water, a low FM bass ostinato, tom fills, and the storm the encounter brings. **The culture is right there:** in the Visayan tale the Bakunawa swallows the moon, and the people drive it off by beating gongs and pots. So agong strikes and clangs belong in this fight, as the fiesta's gongs belonged in Piyesta. Fearofdark energy: syncopation, slides, a brass-like lead. It ends where the creature is answered (row 8). |
| `music.level_4` | Dilim, the forest at night | Kent: "scary / unknown vibe type of music". Sparse and low: a bass drone, a few soft bell notes far apart (soft bell 9, damped), an unresolved minor second, a Phrygian or whole-tone colour, and long silences that make the player listen. No snare. ⚠ **It leaves the band where `tiktik_call` and `tiyanak_cry` sit.** They are gameplay, and row 9 has a test for it. A touch of the Philippine night: a distant bamboo or gong figure that seems to come from somewhere in the trees. |
| `music.level_4_race` | Dilim, the tikbalang's race | Kent: "a thrilling version for that music". **`level_4`'s material, made thrilling:** the same key and motif, the drone turned into a driving ostinato, a galloping figure for the tikbalang's hooves (a triplet gallop on the toms or FM bass), 150–170 BPM, a rising line that does not resolve until the race is won. It still leaves the calls' band. |
| `music.dilim_night` (`_1`, `_2`, `_3`) | Dilim, surviving the night (the finale's three waves until dawn) | Kent: "as thrilling as possible (make use of fearofdark still)". **The most energetic piece in the game.** About 160–176 BPM, a syncopated FM bass, fast arpeggios, jazzy altered chords (m9, dim7, ♭9), slides and bends into the lead, tom fills into every phrase, `level_4`'s motif as the hook. **Three arrangements of one piece, the same length to the row:** wave 1 has the drums, bass and motif; wave 2 adds the counter-line and the arpeggios; wave 3 is everything, with the lead an octave up. It **breaks off at the dawn** in a single frame, and the `dawn` sfx and the light are what follow. The tik-tik's call must still read over the fullest arrangement (row 9's test). |
| `music.level_5` | Mayon, the ascent (Act One) | Lola's motif (the menu's) worn thin under the ash and the wind: fewer voices as the climb goes on, the harmony thinning out. Quiet enough that the brush's refusal and Lolo's lines carry. |
| `music.memory_terraces`, `memory_piyesta`, `memory_dagat`, `memory_dilim` | Mayon, the memory lane (Act Two: three vignettes for each earlier level) | Kent: "different type of music when we are in memory lane". **Each is that level's own music, remembered:** Terraces' gangsa, Piyesta's corps, Dagat's sea and Dilim's night. Fewer voices, slower, softer, a little out of focus (a slow vibrato, a note left out), as if heard from far off. Lola's motif is threaded through each, because these are her memories. Remake each from its own composer in `tools/audio_lab/composers/`, which keeps them related. Crossfade between them over about 2 s. |
| `music.lola` | Mayon, Lola found (the summit) | Kent: "a peaceful [one] when Lola is found". Slow, warm and sparse: the kundiman's warmth (`music.house`) with Lola's motif, rondalla tremolo or soft FM, no drums. It holds while she paints with her back turned and the brush refuses twice, so make it patient. It gives way to `mayon_ending` at the bloom. |
| `mayon_ending` | Lola's easel, the bloom, the house epilogue | The motif whole again, warm: "Lolo. Let's go home." Already called by `level_5._bloom_the_places`; its path is empty until row 11 writes it. |
| `music.ending` | The ending screen | `mayon_ending` carried on, or a short coda of it (row 12). |
| `ambience.level_1..4` | Under each level | Terraces wind (noise swells); Piyesta a soft hum of a street (low gliding FM voices, no noise); Dagat waves, at the surface only (long dark noise swells, low pitch, never bright); Dilim's night: dark and low, under the creatures' band (soft FM frogs, slow low noise). **Not** high pulse chirps: Kent dislikes thin high pulses. |

## The sounds, by what makes them

Every row names its trigger and its visual twin. Each sound is one module in
`audio/sfx/<id>.txt`, ending with `Cxx`, about 0.1–1.5 s long. **New ids** are added to
`audio.json` together with their call site, in the same PR.

**A. Core** (built in `sfx-core`; `run_sfx_core_probe`)

| Id | Trigger | Visual twin |
|---|---|---|
| `ui_click` | every `BaseButton.pressed` (`AudioDirector._on_node_added`) | the button's press animation |
| `ui_open` / `ui_close` | `ModalOverlay.open` / `close`, through `_open_sound()` / `_close_sound()`, which an overlay with a sound of its own overrides (the found-thing card and the level-complete panel) | the overlay's fade |
| `page_turn` | `DiaryBook.turn` | the page-turn animation |
| `checkpoint` | `LevelBase._say_checkpoint` (not on Mayon's silent saves) | the "Checkpoint" line, the lantern lighting, the letterbox |
| `item_acquired` | `AcquiredOverlay._play`, once per card as it rises. ⚠ Not `InventoryManager.item_added`: that also fires when a cancelled placement puts a drawing back. | the found-thing card |
| `unlock` | `game_level.gd`: the brass key turning in Ang Bale's door, and a tool opening the chest | the door's glint (`PickupFlourish2D`), the chest opening |
| `level_complete` | `LevelBase._complete_level` and Payyo's `_go_home_with_the_canvas`, with "Level complete!" and the bars (not Mayon, which ends in its own scene). The panel then arrives without `ui_open`. A jingle, 2.3 s. | the bars with the level's name |

**B. Drawing and morphing** (built in `sfx-drawing`; `run_sfx_drawing_probe`)

| Id | Trigger | Visual twin |
|---|---|---|
| `draw_submit` | `DrawPanel._on_transform_pressed`, as the page goes to the recogniser. Never on the brush's quiet refusal, which sends nothing. | "Recognizing..." |
| `recognised` | `LevelBase._begin_new_utility`, as an accepted drawing flies into the bag. A creature's acceptance is heard as `morph` instead, so an answer is heard once, as what it became. | the drawing flying into its slot (`InventoryHud.arrive`) |
| `declined` | `DrawPanel._on_entity_declined` | the page's "not sure what that is" / "the brush wants a surer line". ⚠ Mayon's brush refusal reuses none of it: it is silent, and the probe checks so. |
| `morph` | `LevelBase._adopt_player` with the flash, into a drawn form | `MorphFlash` |
| `revert` | `LevelBase._adopt_player` with the flash, back to the apo: Q, a life run out, or a level's zero case. Not when she is already herself. | the flash back |
| `place` / `place_refused` | `LevelBase._on_placement_confirmed` (once it is paid for) / `_on_placement_rejected` | "placed" and the drawing in the world / "Can't build that into solid ground" and the ghost's refusal tint |
| `ink_low` / `ink_empty` | `ink_low`: a drawn form's "is fading" (`LevelBase._on_life_changed`) and Dagat's "nearly gone" (`level_3._on_low_ink`). `ink_empty`: the out-of-ink screen opening (`OutOfInkOverlay._open_sound`) and Dagat's "Out of ink". ⚠ Not `DrawingCanvas.ink_blocked`: that is the PAGE being full ("Page full. Paint, undo, or clear."), not the ink. Dilim's and Mayon's drains end in the flash back, heard as `revert`. | the line, the card's bar, the screen |

**C. The apo's body** (built in `sfx-moves`; `run_sfx_moves_probe`; each spaced in `audio.json`)

| Id | Trigger | Visual twin |
|---|---|---|
| `step` | `Wanderer._leave_a_mark`, with each footfall's dust (by distance, `STEP_DUST_STRIDE`), at the stride's force, never under 0.4 | the dust off her heel |
| `jump` | `Wanderer._jump` | the jump pose, her rising |
| `land` | `Wanderer._leave_a_mark`, with the landing cloud over `LAND_DUST_FLOOR`, at the fall's force | the landing cloud |
| `swim` | `Wanderer._advance_stride`, as the swim stroke's cycle comes round (once per `SWIM_STROKE` travelled) | the swim stroke pose |
| `splash` | `WaterArea2D._splash_for`, at how hard it went in | the splash's rings |
| `ladder` | `Wanderer.begin_ladder` (taking hold), then one per `RUNG_STRIDE` (34 px) climbed: the climb is one drawing, not a cycle | the climb |
| `hurt` | **Not built: it is Dilim's `lantern_hit`.** Dilim is the only level with player health, and `level_4._arm_player_health` already plays `lantern_hit` on every `hit_taken`; a second sound would double it. | the hit flash, the hearts |

**D. Combat** (built in `sfx-combat`; `run_sfx_combat_probe`)

| Id | Trigger | Visual twin |
|---|---|---|
| `swing` | `UtilityObject._swing_blade`, hit or miss (`show_swing` is only called from there) | the swing arc, the apo's pose |
| `cannon` | `UtilityObject._fire_cannon` | the shot and the muzzle burst |
| `throw` | `UtilityObject._throw_boomerang`, `StoneThrow2D.throw`, `level_4._throw_salt` / `_throw_ash` | the thrown thing |
| `whip` | `level_4.gd _lash_the_whip` | the lash |
| `foe_hit` / `foe_down` | `Enemy2D._flash` (a blade, the whip, a weight, a salt burn) unless the blow is its last / `Enemy2D._die` and `ManananggalUpper2D._die`; the sea creatures' `apply_tool_hit` / `_die`; `Bakunawa2D.apply_tool_hit` (every blow a hit: it is subdued, never felled) | the hit flash, the red, the knock back / the fall, the flight away |

**E. Places** (built in `sfx-places`; `run_sfx_places_probe`. Dilim's four were already called, and `run_level4_sound_probe` checks them with their ripples)

| Id | Trigger | Visual twin |
|---|---|---|
| `tiktik_call`, `tiyanak_cry` | `level_4.gd`, at the strength passed | the edge ripples (`EdgeRipple.cue`) |
| `lantern_hit`, `dawn` | `level_4.gd` | the lantern's flicker; the dawn |
| `mayon_brush` | `level_5.gd` (already called) | the brush stroke. ⚠ Not built here: Mayon's sounds are `music-mayon`'s (row 11). |
| `door` / `unlock` | `door`: `level_2.gd`, where Piyesta's church and lit-house doors are SEEN to open (not `PiyestaDoor2D.set_open`, which a checkpoint restore also calls), and Payyo's chest lid (`game_level._level_uses_the_tool`). `unlock`: a drawn key in a `Lockable2D`. Not `WardLock2D.opened`: Payyo's key turn already plays `unlock` (`game_level._turn_the_key`). | the door or lid opening |
| `candle` | `ChurchInterior2D.place_the_kandila` | the flame on the rack |
| `scatter` | `DancerGroup2D.scatter`, as they start to run (not `scattered`, which is when the last is gone) | the dancers running |
| `dance_cue` | `DanceOverlay._hit_cue`, at the verdict's loudness: 1.0 perfect, 0.6 early or late. A stroke is only judged against a cue within the hit window, so it is never a miss; a cue let pass is judged unheard. | the verdict's flash |
| `cast` / `reel` | `FishingLine2D`, as the hook goes in the water / comes home | the line |
| `gift` | `level_3._on_gift_offered`, as the treasure is uncovered | the treasure and its sparkle |
| `painting` | `NextPainting2D.take` / `BrushStand2D.take` | the painting or brush lifting |

## Kent's ear: what he liked, what he turned down

Kent judges by ear, quickly and plainly. These are his verdicts so far, and what each one taught.

| Piece | Verdict | What it taught |
|---|---|---|
| Menu, take 1 | "nice, but it lacks the cultural / painting, adventure-game vibe in the Philippines" | **Ground every piece in a Philippine tradition** (kulintang, agung, rondalla, a bamboo flute). Generic NES adventure music is not enough. |
| Menu, take 2 | Liked; "have me a .mp3 … so that I can let my friend hear it" | |
| House, the kundiman | Liked | A Philippine form (kundiman, rondalla), not a style exercise. |
| Terraces, take 1 | "it sounds like it overlaps, like everything is overlapping" | The soft bell rings 3.9 s, and about five gongs rang at once. **Damp what rings** (a custom short patch, or `===` after a row or two), and measure how many notes sound at once. |
| Piyesta, takes 1–3 | "nothing similar nor give a vibe about sinulog"; "it sounds nothing to sinulog" | **A named tradition must sound like it.** Research it. If Kent names a song, ask for the recording early and measure it (`tools/audio_lab/README.md`). A Fearofdark-style tune with a drum pattern on top was not it. |
| Piyesta crowd, the syllable babble | "a distorted hazy type, it sounds so bad" | The noise bed under it was the haze. **No noise beds;** a crowd is a soft, low, gliding hum. |
| Piyesta, take 4 | "yes i like it but refine the two … the vibe still of a fiesta" | A deep tambol (60–120 Hz carries a drum corps), gongs, two trumpets, the beat-two stop. |
| Piyesta, take 5 | "i like it, land it" | The crowd's "Pit Senyor!" shout, a brass shake at the end, a drum lift, and a tom run-up into each dance cue. |

**His standing taste** (memory and every session so far):

- **No thin high pulses and no bright noise screech.** Use 50% duty or 25%, never 12.5%, for
  leads. Use low noise pitches (`5-#`, `6-#` long mode) for drums.
- **Favour the darker VRC7 voices:** soft bell 9 (2.3 kHz at A4), flute 4, clarinet 5, bass 13,
  trumpet 7 at moderate volume, and the custom tambol. The bright ones are bell 1, rattling bell
  6, xylophone 10, brass 12 (~5 kHz) and synth 14. Measure with `stems.py` and `patches.py`.
- **The Fearofdark traits** (2026-11-15) are jazzy chords, swing, slides and bends, and energy.
  They go on top of each level's own tradition, never in place of it.
- **Send every render as an MP3** with one or two lines on what to listen for, and offer two
  variants when you are unsure. Nothing is final until he has heard it.

## Traps to plan around

- **Eight SFX voices.** `AudioDirector` reuses the oldest past eight. Footsteps, swim strokes,
  ladder rungs and landings come constantly, so PR 2 gives `play_sfx` a per-id minimum
  interval. Otherwise they evict the sounds that carry information: Dilim's calls.
- **Dilim's sounds are gameplay.** The music and the insects under them stay out of their band,
  and their loudness is the strength passed. The edge ripples stay.
- **Footsteps tire.** Keep them soft (far under the music) and short, one per footfall, never
  per frame.
- **Mayon's reversal touches settled text.** "Mayon is silent" is in `CLAUDE.md` §4,
  `LEVEL_5.md` and the authored README, and `run_level5_audit` asserts it. Row 11 changes all
  of them together, citing Kent's 2026-11-14 and 2026-11-15 answers. The summit is no longer
  quiet: it has peaceful music once Lola is found. Lolo's vanishing is the silent beat now.
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
- **No autoload name in a class a probe compiles.** A `--script` probe compiles every class it
  names before the autoloads exist, so `AudioDirector.play_sfx` in `Enemy2D` or `UtilityObject`
  failed to compile them, and every probe that uses them. Those classes look the director up
  (`get_node_or_null(^"/root/AudioDirector")`), as LevelBase does. A level script loaded at run
  time (`level_4.gd`) may name it.
- **No triangle in a one-shot, for now.** A triangle silenced mid-wave freezes on a step (the
  hardware does this), and `famirender` resamples the 2A03 with the file's end padded with
  silence, so the frozen step rings at the very end. `_trim_tail` then keeps the whole two-second
  tail, and the file holds a voice for two seconds of nothing (seen in `unlock`, 2026-11-14:
  0.7 s of sound in a 2.5 s file). Loops are not affected. Until the renderer holds the last
  sample instead of padding with zeros, a sound effect's thuds are noise or a falling pulse.

- **The VRC7 has one custom patch, shared by every channel.** The last custom instrument struck
  wins, so a piece can have one custom voice: Piyesta's is the tambol. Everything else must be
  one of the fifteen presets.
- **The triangle sounds an octave under its note name** (FamiTracker's table): `A3` is 110 Hz.
  **A stopped triangle freezes on its step and pops**, so a triangle bass is held to the next
  note, never cut. It has no volume either, so it cannot be balanced; Piyesta moved its bass to
  the VRC7 (patch 13) to sit at −18 dBFS.
- **A release rings into a rest.** A VRC7 note keyed off still sounds for its release, and a
  ringing bell or gong can fill a deliberate gap. Cut a note early with `S0x` (cut after x
  ticks), as Piyesta's beat-two stop does, and measure the gap with `ref/stepbands.py`.
- **Vibrato (`4xy`) stays on until `400`.** Put a `400` on the next phrase's first note on that
  channel.
- **A re-struck VRC7 note speaks about 20 ms late** (the chip damps the old one first). Allow
  for it in anything that must land on a cue.
- **Tempo by the row.** One speed per row in the dpcm column's first effect (`Fxx`) lets a beat
  be any number of ticks. For example, 6, 6, 6, 7 makes 25 ticks a beat, about 144 BPM at
  60.0988 frames a second. The fixed arpeggio counts from C-0 (MIDI 12), and `3xx` glides
  without re-striking a VRC7 note.
- **Music that must line up with gameplay is tested against the game's own numbers.** Do as
  `tests/test_piyesta_dance_music.py` does: read the cue times from the scripts, render, and
  find the strikes. The dance's tick arithmetic (a 0.6 s pickup of four 9-tick rows, then
  30-tick beats) lives in its composer.
- **A place that switches music by where the player is** acts only when the answer changes
  (a memo, as `level_2.gd _music_for` does). It uses hysteresis at any boundary the player can
  sit on, a waterline above all. It also stops its extra tracks in `_exit_tree`.

## Slice 1 verification (2026-11-14)

`tools/run_suites.sh only python run_audio_probe run_level5_audit run_level4_sound_probe
run_new_game_probe run_dev_mode_probe run_import_guard_probe run_screens_fit_probe
run_motion_probe run_journey_probe run_tests`: **all 11 passed.**

The log has no `SCRIPT ERROR`, `Parse Error` or `Error calling`. Its only `^ERROR` lines are
Godot's exit-time leak reports, which the same probes print on main.

`build_music.py --check` passes: the render is deterministic, byte for byte.
