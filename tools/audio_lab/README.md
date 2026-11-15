# The audio lab: compose, listen, measure

Tools for writing a piece **before** it goes into the game. The game's pipeline itself is
`tools/build_music.py` ([audio/README.md](../../audio/README.md)). This folder is the workbench
that came before every shipped piece, and the plan for the rest is [AUDIO_PLAN.md](../../AUDIO_PLAN.md).

Everything here writes to `build/listen/`, which git ignores. Open the MP3s from there.

## The loop that works

Claude cannot hear. Every judgement is either a number from these tools or Kent's ear, and
Kent's ear wins. So each piece goes round this loop until he says yes.

1. **Compose with a script**, never by hand. Write `composers/compose_<place>.py` on
   `tools/famitext.py` and output the module to `build/listen/`. The script is scaffolding. The
   module it writes (`audio/music/<id>.txt`) is the source of truth that ships.
   ```bash
   .venv/bin/python tools/audio_lab/composers/compose_dagat.py tools build/listen/dagat.txt
   ```
2. **Render it fenced.** Anything that loads the renderer's native code runs inside
   `tools/famirender.sb`: Kent asked for that, and `sb.sh` does it.
   ```bash
   tools/audio_lab/sb.sh .venv/bin/python tools/audio_lab/render.py build/listen/dagat.txt build/listen/dagat.wav
   ```
   Aim for **−18 dBFS RMS (±2)** over the loop, like every other piece, with the peak under
   −1 dBFS. An ambience bed sits around −33. The renderer refuses a mix that clips.
3. **Measure the parts.** `stems.py` prints each channel alone, with its RMS and brightness. The
   lead must lead, and nothing should be bright: over ~4 kHz is a warning. `solo.py` renders
   chosen channels, and `steps.py` prints the peak in every sixteenth, which shows where a part
   actually strikes.
   ```bash
   tools/audio_lab/sb.sh .venv/bin/python tools/audio_lab/stems.py build/listen/dagat.txt
   ```
4. **Make Kent an MP3 and send it** (SendUserFile). Make it with the ambience under it, if the
   place has one, since that is how the game plays it.
   ```bash
   .venv/bin/python tools/audio_lab/listen.py build/listen/dagat.wav build/listen/dagat_listen.wav game/assets/audio/ambience/level_3.wav
   tools/audio_lab/mp3.sh build/listen/dagat_listen.wav build/listen/obra-dagat-1.mp3 "Dagat, take 1"
   ```
5. **On his yes:** copy the module to `audio/music/<id>.txt` and add the id to
   `game/config/audio.json` with its call site. Then run `tools/build_music.py <id>`,
   `godot --headless --path game --import`, and the PR's suites.

## The tools

| File | What it does | Fenced? |
|---|---|---|
| `sb.sh` | Runs one command inside `tools/famirender.sb`, from the repo root. It may write only the game's audio, `audio.json`, `build/famirender`, the temp folder and `build/listen`. | is the fence |
| `render.py IN.txt OUT.wav [--oneshot]` | Module → WAV, with its `smpl` loop; prints length, loop, RMS and peak. `--oneshot` is for a sound effect. | yes |
| `listen.py MUSIC.wav OUT.wav [BED.wav]` | The listening edit: the file, its loop once more, faded out, with the ambience bed looped under it. | no |
| `mp3.sh IN.wav OUT.mp3 "Title"` | A 192 kbps MP3, using the Homebrew `ffmpeg` already on this Mac. | yes, by itself |
| `stems.py IN.txt` | Each channel alone: RMS and brightness. | yes |
| `solo.py IN.txt OUT.wav 9,10` | Only those channels. Numbering: 0 pulse1, 1 pulse2, 2 triangle, 3 noise, 5–10 fm1–fm6. Column 4, dpcm, carries the speed and the loop and is always kept. | yes |
| `steps.py WAV DOWNBEAT_S BPM BARS` | The peak in the first 30 ms of every sixteenth, bar by bar. Use it to check a strike lands where it was written, or that a cue is the loudest thing near it. | no |
| `patches.py` | Audition voices: one note each, measured for ring time, brightness and band balance. Edit `CASES`. This is how the tambol and the gongs were chosen. | yes |
| `ref/analyse_beat.py REF.wav START_S` | From a reference recording: tempo, beat grid, drum pattern per sixteenth and per band, and key colour. | no |
| `ref/bands.py WAV:START:DUR …` | Octave-band balance of several recordings side by side. | no |
| `ref/stepbands.py WAV DOWNBEAT_S BPM BARS` | Level per sixteenth in three bands. This found the Sinulog's stop on beat two. | no |
| `composers/` | The scripts that wrote every shipped module, each reproducing its file byte for byte: `compose_house.py` (kundiman), `compose_terraces.py` (gangsa), `compose_piyesta.py` (plaza and dance), `compose_church.py` (hymn), `compose_street.py` (hum), `compose_dagat.py` (the rowing song, its deep twin and the waves), `compose_bakunawa.py` (the fight), `compose_dilim.py` (the forest, the race and the night bed, all under the creatures' bands). And `compose_style_sketch.py`, the style test Kent approved (swing, jazz changes, a sliding trumpet: the Fearofdark traits), which ships nowhere and is the recipe for the style. Read one before writing the next. | no |

`.venv/bin/python` is the project's venv, which has numpy and scipy.

## A reference recording, when Kent gives one

When a style has to sound like a real tradition, ask Kent for a recording early. Piyesta took
three rejected takes before he sent the Sinulog theme, and the fourth, built on its measurements,
was the one he liked.

1. **Decode it into `build/listen/`, and never anywhere git tracks.**
   ```bash
   tools/audio_lab/sb.sh /opt/homebrew/bin/ffmpeg -i "<his mp3>" -ac 1 -ar 22050 build/listen/ref.wav
   ```
2. **Measure only rhythm, band balance and form,** with `analyse_beat.py`, `bands.py` and
   `stepbands.py`. **Never take its melody.**
3. **Write original music on those numbers,** then compare it the same way.
4. **Never commit the recording or anything derived from it.** The repo is public, and these are
   copyrighted. Kent chose this route over shipping the recording (2026-11-15).
