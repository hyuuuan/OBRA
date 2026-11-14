# Music and sound: FamiTracker modules

Kent's direction (2026-11-14): the game's music and sound are **NES audio on the VRC7**, written
in FamiTracker. Every piece here is a **FamiTracker text module**, the format Dn-FamiTracker
writes with *File → Export Text* and reads with *File → Import Text*. The `.txt` is the source;
the WAV in `game/assets/audio/` is only its render.

| Module | Becomes | Plays as |
|---|---|---|
| `music/<id>.txt` | `game/assets/audio/music/<id>.wav` | `audio.json` → `music.<id>`, a loop |
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
  `Vxx` duty or noise mode, `0xy` arpeggio, `4xy` vibrato, `Pxx` fine pitch.
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

## The rule every sound keeps

**Every audio cue has a visual equivalent** (Dilim's rule): a player who cannot hear plays the
same game. A sound effect plays beside something the screen already shows. Music carries no
information, so it needs none.

**Mayon is silent**, by the team's decision (1 November 2026). Its ids stay without files, and
`run_level5_audit` asserts it.

## The pieces

| Id | Module | Notes |
|---|---|---|
| `music.menu` | `music/menu.txt` | The title card, revised at Kent's word (2026-11-14: "nice, but it lacks the cultural, painting, adventure-game vibe in the Philippines"). D major pentatonic, ~129 BPM, a 7.5 s intro (agung, then kulintang, then a bamboo-flute call) and a 30 s loop: an adventure march under a bamboo-flute theme (VRC7 flute), a kulintang ostinato (VRC7 xylophone), agung gongs (VRC7 soft bell, low), rondalla tremolo in thirds (VRC7 guitar), a babendil tick and dabakan drum (short and long noise), an agung thump (triangle), and the painting's sparkle (pulse arpeggio and echo). The B section turns from B minor to D major, as a kundiman does. **Provisional until Kent has listened.** |
