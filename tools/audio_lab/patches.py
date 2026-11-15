"""Audition voices before writing with them: one struck note each, measured for how long it rings
(to -20 dB), how bright it is, and its band balance. Edit CASES. This is how the Piyesta tambol
(a custom VRC7 patch) and its gongs (the soft bell, damped) were chosen.
Run fenced:  tools/audio_lab/sb.sh .venv/bin/python tools/audio_lab/patches.py"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import numpy as np  # noqa: E402
import famirender as fr  # noqa: E402
from famitext import Song  # noqa: E402

# (label, VRC7 patch 0..15 -- 0 is the custom one, its 8 registers -- note, rows before a key-off
# or None to let it ring, effect or None)
TAMBOL = (0x01, 0x01, 0x18, 0x04, 0xF8, 0xF5, 0xF8, 0x36)
CASES = [
    ("tambol A2", 0, TAMBOL, "A2", None, None),
    ("soft bell A4, damped", 9, None, "A4", 3, None),
    ("soft bell A2, held", 9, None, "A2", None, None),
    ("vibraphone A4", 11, None, "A4", 3, None),
    ("flute C5", 4, None, "C5", 8, None),
]
BANDS = [(30, 60), (60, 120), (120, 250), (250, 500), (500, 1000), (1000, 4000)]
print("label                    peak dB  -20dB after  bright   " + " ".join(f"{a:>6d}" for a, _ in BANDS))
for label, patch, regs, note, damp, fx in CASES:
    s = Song("t", frames=1, rows=32, speed=6, loop_to=None)
    inst = s.inst_vrc7("v", patch=patch, regs=regs or (0,) * 8)
    s.put("fm1", 0, 0, note, inst, 15, fx)
    if damp:
        s.put("fm1", 0, damp, "===")
    s._set(0, 31, "dpcm", 3, "C00")
    r = fr.render(fr.parse_module(s.text()), loop=False)
    x = r.samples
    env = np.sqrt(np.convolve(x ** 2, np.ones(320) / 320, "same"))
    top, t0 = env.max(), env.argmax()
    below = np.nonzero(env[t0:] < top * 0.1)[0]
    ring = below[0] / r.rate * 1000 if len(below) else float("nan")
    seg = x[: int(0.4 * r.rate)]
    sp = np.abs(np.fft.rfft(seg)) ** 2
    f = np.fft.rfftfreq(len(seg), 1 / r.rate)
    tot = sp.sum()
    bright = float((np.sqrt(sp) * f).sum() / np.sqrt(sp).sum())
    bands = " ".join(f"{10 * np.log10(sp[(f >= a) & (f < z)].sum() / tot + 1e-12):6.1f}" for a, z in BANDS)
    print(f"{label:24s} {20 * np.log10(top):6.1f}  {ring:8.0f} ms  {bright:5.0f} Hz  {bands}")
