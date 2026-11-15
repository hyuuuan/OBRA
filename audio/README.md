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
- **Settings has three sliders:** Master, Music (which carries the ambience too) and Sound
  effects. The profile keeps them.

## The rule every sound keeps

**Every audio cue has a visual equivalent** (Dilim's rule): a player who cannot hear plays the
same game. A sound effect plays beside something the screen already shows. Music carries no
information, so it needs none.

**Mayon is silent**, by the team's decision (1 November 2026). Its ids stay without files, and
`run_level5_audit` asserts it.

## The pieces

| Id | Module | Notes |
|---|---|---|
| `music.menu` | `music/menu.txt` | The title card (and the boot loading screen, which is the same card), revised at Kent's word (2026-11-14: "nice, but it lacks the cultural, painting, adventure-game vibe in the Philippines"). D major pentatonic, ~129 BPM, a 7.5 s intro (agung, then kulintang, then a bamboo-flute call) and a 30 s loop: an adventure march under a bamboo-flute theme (VRC7 flute), a kulintang ostinato (VRC7 xylophone), agung gongs (VRC7 soft bell, low), rondalla tremolo in thirds (VRC7 guitar), a babendil tick and dabakan drum (short and long noise), an agung thump (triangle), and the painting's sparkle (pulse arpeggio and echo). The B section turns from B minor to D major, as a kundiman does. **Provisional until Kent has listened.** |
| `music.house` | `music/house.txt` | Lola's house, the hub: a kundiman for rondalla (Kent, 2026-11-15: "more on the Philippine cultural side"). The bandurria (VRC7 guitar) carries a cantabile tune in tremolo, a stroke every thirty-second; the octavina answers an octave under; the laud plays a harana-like broken chord; the guitar holds the chord on two and three; a triangle bass and a soft chord sparkle. 3/4, E minor turning to E major as a kundiman does, ~90 BPM, a 32 s loop; a scoop at each phrase's peak. **Provisional until Kent has listened.** |
| `music.level_1` | `music/level_1.txt` | Terraces (Level 1), after Ifugao music (Kent, 2026-11-15): four gangsa gongs in a hocket (no two strike on the same step), each a custom VRC7 patch that rings about a third of a second and is damped after, pitched D-A-D-E and a little off a Western scale; bangibang-like wood (VRC7 xylophone) in the gaps; a low drum. ~112 BPM straight. The gongs enter one by one; in the middle the ensemble drops to one gong under a hudhud-like call and response (a gliding lead voice, a chorus in octaves). Original. A 34 s loop. ⚠ The first version used the VRC7 soft bell, which rang 3.9 s a strike: the gongs ran together (Kent: "everything is overlapping"). **Provisional until Kent has listened.** |
| `music.level_2` | `music/level_2.txt` | Piyesta (Level 2): a fiesta after the Sinulog of Cebu, in the Fearofdark-inspired style (Kent, 2026-11-15). The tambol (triangle) strikes two forward and one back, as the Sinulog dance steps, under a parade snare and a low agong; the trumpet hook climbs the same way, scooping and falling off; in the break a short-short-long "Pit Senyor" call is answered by the band. 7th-chord arpeggios, a pulse bass, brass stabs on the off-beats, a second trumpet in the return. F, ~129 BPM straight, a 30 s loop. Original. Fades out for the dance minigame, which keeps its own beat. **Provisional until Kent has listened.** |
| `ambience.level_1` | `ambience/level_1.txt` | Terraces' wind: low noise in uneven swells over a faint hiss, a 13 s loop about 13 dB under the music. Dark on purpose. **Provisional.** |
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
