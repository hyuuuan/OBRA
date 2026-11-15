"""Render a module with only some channels (dpcm, the speed and loop column, always kept), to
listen to or measure one part.   channels: 0 pulse1, 1 pulse2, 2 triangle, 3 noise, 5..10 fm1..fm6
Run fenced:  tools/audio_lab/sb.sh .venv/bin/python tools/audio_lab/solo.py IN.txt OUT.wav 9,10"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import numpy as np  # noqa: E402
import famirender as fr  # noqa: E402
from scipy.io import wavfile  # noqa: E402

src, out = sys.argv[1], sys.argv[2]
keep = {int(c) for c in sys.argv[3].split(",")} | {4}
lines = []
for line in Path(src).read_text().splitlines():
    if line.startswith("ROW "):
        head, *cells = line.split(" : ")
        line = " : ".join([head] + [c if i in keep else "... .. . " + " ".join(["..."] * (len(c.split()) - 3))
                                    for i, c in enumerate(cells)])
    lines.append(line)
r = fr.render(fr.parse_module("\n".join(lines)))
wavfile.write(out, r.rate, (np.clip(r.samples, -1, 1) * 32767).astype(np.int16))
print(out, f"{len(r.samples) / r.rate:.1f} s")
