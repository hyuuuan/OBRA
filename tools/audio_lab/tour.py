"""Read a recording of the game (game/tests/run_audio_tour.gd) the way a listener would notice it:
around every mark, the level before and after, the deepest dip, the steepest step, and any silence;
and across the whole run, every hard cut and every sudden onset, each named by its nearest mark.

    tour.py build/capture/tour.wav            (reads tour.json beside it; plain numpy)

What it flags, in 20 ms windows of the mono mix:
  CUT    the level falls more than 18 dB inside 60 ms (a track stopped dead, not faded)
  JUMP   the level rises more than 15 dB inside 40 ms (a track or a sound starting at full)
  GAP    more than 0.25 s under -50 dBFS between two sounding stretches (music dropped out)
A one-shot (a click, the jingle) is a JUMP by nature; the mark names it, and the level it reaches
over the music is what to read."""
import json
import sys
import warnings
from pathlib import Path

import numpy as np
from scipy.io import wavfile

warnings.filterwarnings("ignore", category=wavfile.WavFileWarning)
WIN = 0.02

path = Path(sys.argv[1])
rate, x = wavfile.read(path)
x = x.astype(np.float64) / 32768.0
mono = x.mean(axis=1) if x.ndim > 1 else x
n = int(WIN * rate)
k = len(mono) // n
env = 20 * np.log10(np.sqrt((mono[: k * n].reshape(k, n) ** 2).mean(axis=1)) + 1e-9)
marks = json.loads(path.with_suffix(".json").read_text())["marks"]
# The marks are on the capture's own clock (frames taken), so they line up with the file; an "end"
# mark closes the tour, and any slack against it is reported.
end = next((m["t"] for m in marks if m["label"] == "end"), k * WIN)
scale = (k * WIN) / end if end else 1.0


def at(t: float) -> int:
    return int(np.clip(t * scale / WIN, 0, k - 1))


def tour_time(i: int) -> float:
    return i * WIN / scale


def near(i: int) -> tuple[str, float]:
    t = tour_time(i)
    best = min(marks, key=lambda m: abs(m["t"] - t)) if marks else {"t": 0, "label": "-"}
    return best["label"], t - best["t"]


print(f"{path.name}: {k * WIN:.1f} s, mean {env.mean():.1f} dB, clock scale {scale:.4f}\n")
print(f"{'t':>7}  {'mark':38s} {'before':>7} {'after':>6} {'dip':>6} {'step':>5}  music")
for m in marks:
    i = at(m["t"])
    before = np.median(env[max(0, i - 50):i]) if i > 0 else float("nan")
    after = np.median(env[i + 50:i + 150])
    dip = env[i:i + 150].min()
    step = np.abs(np.diff(env[max(0, i - 25):i + 150])).max()
    print(f"{m['t']:7.2f}  {m['label'][:38]:38s} {before:7.1f} {after:6.1f} {dip:6.1f} {step:5.1f}  {m['music']}/{m['ambience']}")

print()
flags = []
for i in range(3, k):
    if env[i - 3] - env[i] > 18 and env[i - 3] > -45:
        flags.append(("CUT", i))
    if env[i] - env[i - 2] > 15 and env[i] > -45:
        flags.append(("JUMP", i))
quiet = env < -50
i = 0
while i < k:
    if quiet[i]:
        j = i
        while j < k and quiet[j]:
            j += 1
        if (j - i) * WIN > 0.25 and i > 0 and j < k:
            label, off = near(i)
            print(f"GAP  {tour_time(i):7.2f} s for {(j - i) * WIN:.2f} s   near {label} ({off:+.2f} s)")
        i = j
    else:
        i += 1
# Only near a mark: inside a piece, a drum after a rest is a JUMP too, and that is the music.
last = {}
for kind, i in flags:
    label, off = near(i)
    if abs(off) > 2.5 or i - last.get(kind, -99) < 10:
        continue
    last[kind] = i
    print(f"{kind:4s} {tour_time(i):7.2f} s  {env[i - 3]:6.1f} -> {env[i]:6.1f} dB   near {label} ({off:+.2f} s)")
