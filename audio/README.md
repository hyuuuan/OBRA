# Music and sound: FamiTracker modules

Kent's direction (2026-11-14): the game's music and sound are **NES audio on the VRC7**, written
in FamiTracker. Every piece here is a **FamiTracker text module**, the format Dn-FamiTracker
writes with *File → Export Text* and reads with *File → Import Text*. The `.txt` is the source;
the WAV in `game/assets/audio/` is only its render.

| Module | Becomes | Plays as |
|---|---|---|
| `music/<id>.txt` | `game/assets/audio/music/<id>.wav` | `audio.json` → `music.<id>`, a loop |
| `ambience/<id>.txt` | `game/assets/audio/ambience/<id>.wav` | `audio.json` → `ambience.<id>`, a loop under the music |
| `sfx/<id>.txt` | `game/assets/audio/sfx/<id>.wav` | `audio.json` → `sfx.<id>`, a one-shot |

Each module's first `TRACK` is rendered. The id must already be in `game/config/audio.json`,
with the code that plays it, and `run_audio_probe` fails a file nothing plays.

Writing a new piece: the workbench (compose by script, render fenced, measure, make Kent an MP3)
is [tools/audio_lab/README.md](../tools/audio_lab/README.md). What is left to write is
[AUDIO_PLAN.md](../AUDIO_PLAN.md).

## Rendering, on this Mac

```bash
.venv/bin/python tools/build_music.py            # every module; points audio.json at the files
.venv/bin/python tools/build_music.py menu       # just one
.venv/bin/python tools/build_music.py --check    # exit 1 if a committed WAV is out of date
godot --headless --path game --import            # then import, and run run_audio_probe
```

FamiTracker runs only on Windows, and Homebrew's Wine was disabled on 2026-09-01, so
`tools/famirender.py` plays the modules here:

- the **VRC7** through emu2413 (`tools/vendor/emu2413`, MIT, pinned by hash), the FM core family
  FamiTracker itself uses;
- the **2A03** modelled from the nesdev wiki;
- a sequencer that follows the tracker's rules.

The result is close to the tracker but not bit-identical.

**It runs in a sandbox.** `build_music.py` relaunches itself under `sandbox-exec` with
`tools/famirender.sb`. Inside it there is no network, no access to the credential stores, and it
can write only the rendered audio, `audio.json`, `build/famirender` and the temp folder. It
proves the fence is up before it renders anything. Off macOS it refuses to run unless
`--unsandboxed` is passed on purpose.

## What a module may use

A module using anything else is **refused, by line**, never rendered approximately.

- `EXPANSION 0` (2A03) or `2` (2A03 + VRC7), NTSC, the default engine speed, new-style vibrato.
- Channels, in the tracker's order: Pulse 1, Pulse 2, Triangle, Noise, DPCM, then FM 1–6.
  **DPCM is not rendered**, so the drums are triangle and noise.
- Effects: `Fxx` speed/tempo, `Bxx` jump, `Cxx` halt, `Dxx` skip, `Gxx` delay, `Sxx` cut,
  `Vxx` duty or noise mode, `0xy` arpeggio, `4xy` vibrato, `Pxx` fine pitch, and the slides:
  `1xx` / `2xx` bend up / down, `3xx` glide into each new note (on the VRC7 a glided note is not
  struck again), `Qxy` / `Rxy` slide up / down `y` semitones at speed `x`, the arrival becoming the
  note. An arpeggio still plays its notes outright.
- Swing: `tools/famitext.py`'s `Song.swing(long, short)` alternates the speed row by row. The
  speed and the loop's jump ride the DPCM channel's two effect columns, which carry nothing else.
- 2A03 macros: volume, arpeggio (absolute, fixed or relative), pitch, duty. A fixed arpeggio
  counts from the tracker's C-0.
- VRC7 instruments: one of the fifteen built-in patches, or patch 0 with its eight registers.
  ⚠ The VRC7 has **one** custom patch, so channels that strike different custom instruments
  take it from each other, as on the cartridge.

Things the tracker does that a module should expect:

- **The triangle sounds an octave below** the note written, as it does in the tracker.
- **A loop is the song's own `Bxx`** (or the order wrapping). The render plays the loop twice and
  loops the second pass, so the seam carries the ring-out of the loop's own end. Its last 16 ms
  is faded into the audio before the loop's start, because the pulses, triangle, noise and
  VRC7 LFO run free and the two passes are never the same samples.
- **A sound effect ends with `Cxx`.** After it, the 2A03 stops and the VRC7 rings out its
  release, up to 2 s, cut at −60 dB.
- **A mix that would clip is refused.** Turn the module's volumes down instead.
- ⚠ **Vibrato (`4xy`) on the VRC7 is deep up high.** famirender applies it in pulse-period units,
  so on a note near A5 a `433` swings about half a semitone. Kent heard Mayon's first take, with a
  late vibrato on every long note and 2-semitone scoops, as "a voice crack". Hold long notes
  straight; keep a shake (`4A4`) for one brass note at a phrase's end, as Piyesta does.

## Editing a module by ear

On a Windows PC with Dn-FamiTracker, import the `.txt`, edit it, and export the text back
over the same file. Then render it here with `build_music.py`. Keep to the subset above.

## How the game plays them

`AudioDirector` (an autoload) plays every sound by id:

- **Music and ambience** each loop on a pair of players. A change of track **crossfades** over
  0.6 s, and `stop_music` / `stop_ambience` fade out. The fades run while the tree is paused.
- **A place names its own.** A level overrides LevelBase `_level_music()` and
  `_level_ambience()` (both `&""`, none, by default). It plays them when it opens and fades them
  out when it leaves, if they are still its own. The main menu plays `music.menu` itself.
- **Sound effects** share eight voices. An id made constantly, such as a footstep, gets an
  entry in `audio.json` → `spacing` (id → least seconds between plays). Inside that spacing it is
  announced on `sfx_requested` but not played, so it cannot take the voices from the sounds that
  carry information.
- **The level-complete jingle ducks the music.** An id in `audio.json` → `duck` lowers the music
  and ambience 12 dB for its own length (its WAV's), then brings them back, through an Amplify
  effect on the Music bus: the slider and any crossfade are left alone.
- **Mayon's ending goes home.** `mayon_ending` plays from the bloom, carries on unrestarted into
  the house (which after the run takes it as its own music) and is the ending screen's.
- **Settings has three sliders:** Master, Music (which carries the ambience too) and Sound
  effects. The profile keeps them.

## The rule every sound keeps

**Every audio cue has a visual equivalent** (Dilim's rule): a player who cannot hear plays the
same game. A sound effect plays beside something the screen already shows. Music carries no
information, so it needs none.

**Mayon has music now** (Kent, 2026-11-14 and 2026-11-15), which reverses the team's 1 November
"Mayon is silent". The scene still plays nothing itself: everything goes through AudioDirector, and
`run_level5_audit` asserts that and that every Mayon id has a file.

## The pieces

| Id | Module | Notes |
|---|---|---|
| `music.menu` | `music/menu.txt` | The title card (and the boot loading screen, which is the same card), revised at Kent's word (2026-11-14: "nice, but it lacks the cultural, painting, adventure-game vibe in the Philippines"). D major pentatonic, ~129 BPM, a 7.5 s intro (agung, then kulintang, then a bamboo-flute call) and a 30 s loop: an adventure march under a bamboo-flute theme (VRC7 flute), a kulintang ostinato (VRC7 xylophone), agung gongs (VRC7 soft bell, low), rondalla tremolo in thirds (VRC7 guitar), a babendil tick and dabakan drum (short and long noise), an agung thump (triangle), and the painting's sparkle (pulse arpeggio and echo). The B section turns from B minor to D major, as a kundiman does. **Provisional until Kent has listened.** |
| `music.house` | `music/house.txt` | Lola's house, the hub: a kundiman for rondalla (Kent, 2026-11-15: "more on the Philippine cultural side"). The bandurria (VRC7 guitar) carries a cantabile tune in tremolo, a stroke every thirty-second; the octavina answers an octave under; the laud plays a harana-like broken chord; the guitar holds the chord on two and three; a triangle bass and a soft chord sparkle. 3/4, E minor turning to E major as a kundiman does, ~90 BPM, a 32 s loop; a scoop at each phrase's peak. **Provisional until Kent has listened.** |
| `music.level_1` | `music/level_1.txt` | Terraces (Level 1), after Ifugao music (Kent, 2026-11-15): four gangsa gongs in a hocket (no two strike on the same step), each a custom VRC7 patch that rings about a third of a second and is damped after, pitched D-A-D-E and a little off a Western scale; bangibang-like wood (VRC7 xylophone) in the gaps; a low drum. ~112 BPM straight. The gongs enter one by one; in the middle the ensemble drops to one gong under a hudhud-like call and response (a gliding lead voice, a chorus in octaves). Original. A 34 s loop. ⚠ The first version used the VRC7 soft bell, which rang 3.9 s a strike: the gongs ran together (Kent: "everything is overlapping"). **Provisional until Kent has listened.** |
| `music.level_2` | `music/level_2.txt` | Piyesta's plaza: a Sinulog drum corps (Kent, 2026-11-15: "tribal and upbeat -- drums, trumpets, gongs"). Written on what was measured from the Sinulog theme recording he supplied -- rhythm, band balance and form, no melody taken: ~144 BPM, a deep VRC7 tambol on one, three and the sixteenth before the bar, snare and hats on the off-sixteenths, nearly everything stopping on beat two. Over it an agong on the downbeats, a kulintang figure on the offbeats, two trumpets in thirds, tom rolls into every phrase, a call-and-answer with the crowd shouting back "Pit Senyor!", a drums-and-gongs section and a lift that ends on a brass shake. A minor, with G, D minor and E. Original. Provisional until Kent has heard this version. |
| `music.dance` | `music/dance.txt` | Piyesta's dance minigame: the plaza's corps and gongs at 120 BPM, so each cue (every 1.0 s) lands on the big drum with the trumpets and the agong. A count-in, then three tom strokes leading into each cue so a player hears it coming. Restarted with every attempt by `DanceOverlay.music_id`; `test_piyesta_dance_music` reads the cues from the game and fails if a strike drifts more than 40 ms (they land within 8). Provisional. |
| `music.church` | `music/church.txt` | Inside Piyesta's church: a slow four-voice hymn on the VRC7 reed organ, F major, ~67 BPM, a far bell every four bars, no drums. Original. **Provisional.** |
| `music.level_3` | `music/level_3.txt` | Dagat, the surface: the level's start, the bangka, the shores, and all a player hears who never dives (Kent, 2026-11-15). A Visayan rowing song in 3/4 after the balitaw: a VRC7 bass on one, the rondalla guitar strumming two and three, the paddle's pull on every downbeat (a short triangle thump and a dark noise swell), waves of broken chords on a soft 50% pulse with a vibraphone on each crest, and the bamboo flute's long-breathed tune, scooping into its long notes and falling off its phrase ends, a soft pulse echo behind it, its long notes held straight (no vibrato: the renderer swings a high VRC7 note about half a semitone, which Kent heard as a voice cracking). The style Kent approved on top: a light swing (22/16), maj7 and 9th changes, a chip-chord shimmer in the B section, a clarinet answering in the last phrase. G major, ~95 BPM, a 30 s loop. ⚠ The bass is on the VRC7: the triangle measured -17 dBFS alone and buried the flute. **Provisional until Kent has listened.** |
| `music.level_3_deep` | `music/level_3_deep.txt` | Dagat, below the surface: the same piece heard from under the water, written to the surface's length **to the row**, so a dive trades the two mid-bar (`keep_position`). The drums, strum and flute go: the chords held on low flutes that glide into each other and are never struck again, a slow vibrato on them, the waves an octave down at half speed, the bass held, the tune a quiet clarinet an octave down, a soft bell now and then. No noise. About 1 dB under the surface's level, as if muffled. **Provisional.** |
| `music.bakunawa` | `music/bakunawa.txt` | Dagat, facing the Bakunawa (Kent, 2026-11-15: "an appropriate water-vibe boss fight music"), from the moment it is met until it is answered, on every route. Dagat's own tune turned minor over a rolling 12/8 (~139 BPM to the dotted quarter, three eighths in 9+8+9 ticks): in the Visayan tale the people drive the Bakunawa back by beating gongs and pots, so an agong (VRC7 soft bell, low, damped) strikes every downbeat and pots (the soft bell high, cut at once) clank on the offbeats, with a break of drums and gongs alone before the turnaround. A low VRC7 bass ostinato, Piyesta's tambol kicking and filling, dark noise for the storm and the snare, chip-chord arpeggios, two trumpets a third apart with scoops, fall-offs and one brass shake, an echo pulse. Altered changes in G minor (m9, maj7, m7b5, 7#9, 7b9). Original. A 28 s loop. **Provisional until Kent has listened.** |
| `music.level_4` | `music/level_4.txt` | Dilim, the forest at night, the whole level (Kent, 2026-11-15: "scary / unknown vibe type of music"). E Phrygian, ~72 BPM in eighths: a VRC7 bass drone on E with a low flute a minor second above it, beating and never resolved, a low clarinet fifth under it; the motif -- E, F, E, down to B -- on a low flute, then climbing whole tones and sagging (R81); a few soft bells far apart, damped; a knock from somewhere in the trees (the soft bell low, cut at once). Long rests. ⚠ **Everything under 500 Hz, no noise and no pulse**, so the tik-tik's call (strongest at 4-8 kHz) and the tiyanak's cry (500 Hz-1 kHz) read over it: `tests/test_dilim_calls_read.py` holds each call at full strength 6 dB over the music and bed in its own band (23.9 and 8.0 dB). A 27 s loop. **Provisional until Kent has listened.** |
| `music.level_4_race` | `music/level_4_race.txt` | Dilim, the tikbalang's race (Kent: "a thrilling version for that music"), while `Tikbalang2D.is_racing()`. The forest's motif galloping in triplets at ~157 BPM: the hooves on the tambol ("da . da", all three on the fourth beat), the drone driven into a bass with the flat second pulling at it, low reed stabs on the offbeats with the minor second in them, a gong on every bar, and the motif on a low clarinet climbing a whole tone every four bars (E, F#, G#, A#) and never arriving. ⚠ The motif is on the clarinet, not the trumpet, whose partials filled the tiyanak's band to within 4 dB. Clears the calls by 23.3 and 7.9 dB. A 24.5 s loop. **Provisional.** |
| `music.dilim_night_1`, `_2`, `_3` | `music/dilim_night_1.txt` … | Surviving Dilim's night (Kent, 2026-11-15: "as thrilling as possible (make use of fearofdark still)"): the most energetic piece in the game, one piece in three arrangements, one per wave of `DilimFinale2D.WAVES`, **the same length to the row**, so each wave trades them mid-bar (`keep_position`) and the night builds. ~164 BPM on lightly swung sixteenths (6/5), altered changes in E minor (m9, maj7#11, 7b9, 7#9, m7b5, an F7#11 tritone turn home), a syncopated VRC7 bass with the flat second pulling, the tambol kicking with a fill into every phrase, a dark noise snare, and the forest's motif at speed as the hook on the bamboo flute. Wave 1: drums, bass, the motif. Wave 2: and a clarinet counter-line, chip-chord arpeggios (50% duty) and offbeat stabs. Wave 3: and the lead's echo, a gong opening each phrase, doubled stabs. It **breaks off at dawn** in the frame the `dawn` sound plays. ⚠ The lead stays at pitch in wave 3, not an octave up as first planned: there it buried the tik-tik's call (2.7 dB clear), in the wave the tik-tik flies in; and it is the flute because the trumpet's partials filled that band even at pitch. Clears the tik-tik by 9.0 / 7.7 / 7.5 dB. A 23 s loop after a 6 s intro. **Provisional until Kent has listened.** |
| `music.level_5` | `music/level_5.txt` | Mayon, the ascent: Lola's motif (the title's opening, A D E F#, E D B A) worn thin under the ash. A 13 s intro with it nearly whole on the title's band -- bamboo flute, rondalla broken chords, agung, bass -- then a 26 s loop that has lost voices: the motif with its long note left out, the harmony down to a bass and one guitar, the major iv gone minor, a fragment with its middle gone, one held line over a breath of wind. D major, ~75 BPM. Take 2: straight tones (take 1's vibrato and scoops were "a voice crack", and one scoop slid to G#, out of the key). **Provisional until Kent has listened.** |
| `music.memory_terraces` | `music/memory_terraces.txt` | Mayon's memory lane, the Terraces vignettes (`payyo_*`): two of Terraces' gangsa gongs (its custom patch) in their hocket, slower (~90 BPM) and in tune here, a drone, Lola's motif on a far flute, and the hudhud's answer on a far bell (not the chorus patch, whose "voices" cracked). A 21 s loop. **Provisional.** |
| `music.memory_piyesta` | `music/memory_piyesta.txt` | The fiesta vignettes: the drum corps far off, slower (~120 BPM), the beat-two stop, the agong; Lola's motif in A minor on a soft trumpet. A 16 s loop. **Provisional.** |
| `music.memory_dagat` | `music/memory_dagat.txt` | The sea vignettes: Dagat's rowing song half remembered (~80 BPM, 3/4), soft strum, waves an octave down; Lola's motif, which is the shape of Dagat's own opening, on the flute, then the song's first phrase. A 18 s loop. **Provisional.** |
| `music.memory_dilim` | `music/memory_dilim.txt` | The forest vignettes: Dilim's drone and its motif, warmer and an octave up, answered by Lola's motif in E minor on a clarinet, a far bell. A 27 s loop. **Provisional.** |
| `music.lola` | `music/lola.txt` | Mayon's summit, from the moment it opens (Lola found): a kundiman for rondalla like her house's, slower (~75 BPM, 3/4, E major) and patient, no drums -- her motif on the bandurria's tremolo (a stroke on every row, as the house's), the laud's broken chord, the guitar on two and three, a soft sparkle. It holds while she paints and the brush refuses twice. A 29 s loop. **Provisional.** |
| `mayon_ending` | `music/mayon_ending.txt` | From the bloom on: Lola's motif whole again, warm, on the title's band in its key (D major, ~90 BPM) -- bamboo flute with its echo, rondalla broken chords, kulintang, agung, a soft dabakan. "Lolo. Let's go home." It carries on into the house, which after the run plays it as its own, and is the ending screen's music (Kent's answer, 2026-11-15). A 32 s loop. **Provisional.** |
| `ambience.level_1` | `ambience/level_1.txt` | Terraces' wind: low noise in uneven swells over a faint hiss, a 13 s loop about 13 dB under the music. Dark on purpose. **Provisional.** |
| `ambience.level_2` | `ambience/level_2.txt` | Piyesta's street: a soft chip hubbub (Kent chose it over the syllable babble, which he heard as "distorted, hazy"). Four low VRC7 flute hums, each struck once and gliding between nearby pitches, never re-struck; no noise. Quiet (-33 dBFS) and dark. Silent in the church. Provisional. |
| `ambience.level_3` | `ambience/level_3.txt` | Dagat's waves, at the surface only: long dark swells of low noise at uneven gaps (3.7, 3.3, 3.1, 2.7 s), each rising for a second and running back for two, a faint wash between. -33 dBFS. Silent under the water. **Provisional.** |
| `ambience.level_4` | `ambience/level_4.txt` | Dilim's night: two frogs, near and far, croaking low (the VRC7 bass on A2-D3, struck and sliding down a semitone, released two rows on) at uneven gaps over the slowest, darkest breath of noise. Not the old brief's high chirps: Kent dislikes thin high pulses, and they would sit in the tik-tik's band. -33 dBFS. **Provisional.** |
| `sfx.ui_click` | `sfx/ui_click.txt` | Every button. A soft babendil tick: a 25% pulse on B5 that falls a hair, and a glint of short-mode noise. 0.08 s, about −26 dBFS RMS. |
| `sfx.ui_open` | `sfx/ui_open.txt` | An overlay coming up: two soft 50% pulses, D5 then A5, with a quieter echo three ticks behind. 0.26 s. |
| `sfx.ui_close` | `sfx/ui_close.txt` | And going: the same two notes down, A5 to D5, a shade softer. 0.25 s. |
| `sfx.page_turn` | `sfx/page_turn.txt` | Her diary's page: a long-mode noise swish that rises and falls, and the page landing. 0.38 s. |
| `sfx.checkpoint` | `sfx/checkpoint.txt` | A lantern catching: a breath of noise (the flame), the agung low on D3 (VRC7 soft bell), kulintang A5 then D6 (VRC7 xylophone), and a 12.5% pulse glow arpeggiating the D chord. 0.94 s. |
| `sfx.item_acquired` | `sfx/item_acquired.txt` | A found thing's card: a kulintang pickup (F#5 A5 B5) into a struck bell chord on D with the agung under it, a babendil tick on each end, and a pulse shimmer with its echo while the card holds. 1.0 s. |
| `sfx.unlock` | `sfx/unlock.txt` | A lock giving: the key's metal click (short-mode noise), the bolt's thud (noise and a falling pulse), then two small kulintang notes, F#5 to B5. 0.72 s. |
| `sfx.level_complete` | `sfx/level_complete.txt` | The level-complete jingle, I–IV–V–I in D: a bamboo-flute phrase (A D F# A, B, A C#, D) over a swung kulintang run, rondalla tremolo in thirds (VRC7 guitar), an FM bass, the agung opening and landing it, babendil on every eighth and the dabakan on the changes, and the painting's sparkle up the D chord at the arrival. 2.3 s. |

| `sfx.draw_submit` | `sfx/draw_submit.txt` | The page going to be read: one soft brush stroke on paper, dark long-mode noise swelling in and easing out, and no tone (Kent, 2026-11-15: the first version's pulse glide "screeches my ear ... it should just sound like a paint"). 0.26 s. |
| `sfx.recognised` | `sfx/recognised.txt` | The painting knows what she drew: VRC7 vibraphone E5 then A5, and a pulse sparkle that follows the drawing into the bag. 0.7 s. |
| `sfx.declined` | `sfx/declined.txt` | It cannot tell: a soft 25% pulse falling B4 to G#4, wavering and sagging, with an echo. Kind rather than wrong. 0.39 s. |
| `sfx.place_refused` | `sfx/place_refused.txt` | The ghost cannot go there: two low, flat bumps (50% pulse on D3 over a noise thud). A wall, not a question. 0.17 s. |
| `sfx.morph` | `sfx/morph.txt` | She becomes the drawing: a 12.5% pulse gliding up through the D chord with its echo, a rising breath of noise, the VRC7 chorus swelling on D and A, and a bell on D6 as the ring opens. 0.86 s. |
| `sfx.revert` | `sfx/revert.txt` | Back to herself: the glide turned round from A5, shorter and softer, settling on the chorus's D. 0.47 s. |
| `sfx.place` | `sfx/place.txt` | A drawing set down: a wooden tok of noise, a low VRC7 bass thunk on D3, and a tick as it settles. 0.33 s. |
| `sfx.ink_low` | `sfx/ink_low.txt` | The ink nearly gone: a soft high ti-tu (E6, B5), twice, the second fainter. 0.39 s. |
| `sfx.step` | `sfx/step.txt` | A footfall: one soft, dark tap of noise, at the stride's force. Far under the music (about −32 dBFS). 0.06 s. |
| `sfx.jump` | `sfx/jump.txt` | A jump: a short, low hup on a 50% pulse gliding up a little, and a breath of noise. 0.12 s. |
| `sfx.land` | `sfx/land.txt` | A landing: a low thud of noise and a soft 50% pulse knocked down, at the fall's force. 0.1 s. |
| `sfx.swim` | `sfx/swim.txt` | A swim stroke: a soft push of dark noise and a low bubble on the pulse. 0.15 s. |
| `sfx.splash` | `sfx/splash.txt` | Something breaks the surface: a splash of noise falling away, darker than the line's cast, at how hard it went in. 0.23 s. |
| `sfx.ladder` | `sfx/ladder.txt` | A rung: a small wooden tok, quieter than a drawing set down. 0.06 s. |
| `sfx.tiktik_call` | `sfx/tiktik_call.txt` | The tik-tik: two dry, high ticks (short-mode noise and a 12.5% pulse on E7), tik... tik. Played at its call's strength, so it starts loud. 0.22 s. |
| `sfx.tiyanak_cry` | `sfx/tiyanak_cry.txt` | The tiyanak: a thin 25% pulse wail on A5 that rises and sags, wavering, over a fainter one a tritone down. 0.51 s. |
| `sfx.lantern_hit` | `sfx/lantern_hit.txt` | Her lantern struck: a glassy clang on a tritone (E6 and A#5) and a flicker of short-mode noise. 0.17 s. |
| `sfx.dawn` | `sfx/dawn.txt` | The night ends: the VRC7 chorus swelling on D, the bamboo flute rising A5 to D6, and a kulintang glint. 1.77 s. |
| `sfx.door` | `sfx/door.txt` | A door or a lid: a short wooden creak of noise and a soft knock as it comes to rest. 0.33 s. |
| `sfx.candle` | `sfx/candle.txt` | A kandila on its rack: a small breath of flame and one soft high bell on D6. 0.45 s. |
| `sfx.scatter` | `sfx/scatter.txt` | The dancers run: a scurry of quick noise feet falling away and a little pulse trill tumbling down. 0.5 s. |
| `sfx.dance_cue` | `sfx/dance_cue.txt` | A cue danced: one bright kulintang strike on A5 and a babendil tick; played at 1.0 for perfect, 0.6 for early or late. 0.39 s. |
| `sfx.cast` | `sfx/cast.txt` | The line goes in: a splash of noise falling away and a small plip. 0.18 s. |
| `sfx.reel` | `sfx/reel.txt` | The line comes home: a ratchet of short-mode clicks and a small rising glide. 0.32 s. |
| `sfx.gift` | `sfx/gift.txt` | The bakunawa's gift: a low, watery chorus swell on D and A, and a vibraphone climbing D F# A. 1.26 s. |
| `sfx.painting` | `sfx/painting.txt` | A painting or the brush lifting: a soft rising breath and the bamboo flute up a fifth, D to A, over the chorus. 0.92 s. |
| `sfx.swing` | `sfx/swing.txt` | A blade or club through the air: a short-mode glint, then a fast falling noise swish. 0.2 s. |
| `sfx.cannon` | `sfx/cannon.txt` | The drawn cannon: a boom of low noise, a 50% pulse dropping from A2, and the VRC7 bass on D2 for its body. 0.38 s. |
| `sfx.throw` | `sfx/throw.txt` | Something light thrown: a quick noise arc and a 25% pulse flick falling from E6. The boomerang, a stone, Dilim's salt and ash. 0.13 s. |
| `sfx.whip` | `sfx/whip.txt` | Lola's buntot pagi: a short rising swish, the crack (the noise at its highest), and a thin ring. 0.16 s. |
| `sfx.foe_hit` | `sfx/foe_hit.txt` | A blow landing: a punch of noise and a 25% pulse knocked down from E4. 0.1 s. |
| `sfx.foe_down` | `sfx/foe_down.txt` | A foe falling: a long 12.5% slide down from E5 with its echo, the noise giving out under it, and a last low thud. 0.51 s. |
| `sfx.ink_empty` | `sfx/ink_empty.txt` | The ink gone: a hollow 50% pulse falling A4 F#4 D4, the last note sagging, over a breath that fades. 0.56 s. |
| `sfx.mayon_brush` | `sfx/mayon_brush.txt` | A memory saved in Mayon, beside its saved line: two slow strokes of a brush (dark long-mode noise, no tone, as paint must sound) and a warm low fifth on the VRC7 flute under them. Not the page's single short stroke (`draw_submit`). 0.7 s. **Provisional.** |

**The sound effects keep one rule between them:** the interface speaks in the 2A03 (soft pulses,
a tick of noise) and the painting, what the world hands her, speaks in the VRC7's kulintang,
agung and bamboo flute, the title theme's band. Every one sits under the music's loudness, and
every one is **provisional until Kent has listened** (rendered 2026-11-14). The drawing's own
moments, the answer and the change, are the painting's (VRC7); the page, the bag and the gauge
are the interface's (2A03). `declined`, `place_refused` and Mayon's brush refusal never sound
alike: a wavering question, a flat bump, and silence. Combat is bodies and blows, all 2A03
and short (the cannon's body is the one VRC7 voice): in Dilim they share the air with the
tik-tik's call and the tiyanak's cry, which are gameplay and must never be masked.

⚠ **No triangle in a sound effect, for now.** A triangle silenced mid-wave freezes on a step, and
the renderer's resampler rings on that step at the very end of a one-shot, so the file keeps two
seconds of silence. The thuds are noise or a falling pulse instead (AUDIO_PLAN.md, traps).
