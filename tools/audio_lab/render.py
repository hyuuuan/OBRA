"""Render one module to a WAV (with its smpl loop) and print its length, loop, RMS and peak.
Run fenced:  tools/audio_lab/sb.sh .venv/bin/python tools/audio_lab/render.py IN.txt OUT.wav [--oneshot]
(--oneshot for a sound effect: it plays to its Cxx and rings out, as build_music renders sfx)

The game's music sits at -18 dBFS RMS (+-2) over its loop, peak under -1 dBFS; an ambience bed
around -33. The renderer refuses a mix that clips: lower the module's volumes."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import numpy as np  # noqa: E402
import famirender as fr  # noqa: E402

src, out = sys.argv[1], sys.argv[2]
r = fr.render(fr.parse_module(Path(src).read_text()), loop="--oneshot" not in sys.argv[3:])
Path(out).write_bytes(fr.wav_bytes(r))
x = r.samples if r.loop_start is None else r.samples[r.loop_start:]      # a loop: measured over it
rms = 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)
loop = "one-shot" if r.loop_start is None else f"loop from {r.loop_start / r.rate:.1f} s"
print(f"{Path(src).name}: {len(r.samples) / r.rate:.1f} s, {loop}, rms {rms:.1f} dBFS, "
      f"peak {20 * np.log10(r.peak):.1f} dBFS")
