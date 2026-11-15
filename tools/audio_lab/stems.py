"""Each channel of a module alone, over its loop: RMS and brightness (spectral centroid). Use it
to balance a mix by numbers: the lead must lead, nothing bright (Kent dislikes brightness; a stem
over ~4 kHz is a warning), the bass must not outweigh the tune.
Run fenced:  tools/audio_lab/sb.sh .venv/bin/python tools/audio_lab/stems.py IN.txt"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import numpy as np  # noqa: E402
import famirender as fr  # noqa: E402

NAMES = ["pulse1", "pulse2", "triangle", "noise", "dpcm", "fm1", "fm2", "fm3", "fm4", "fm5", "fm6"]
text = Path(sys.argv[1]).read_text().splitlines()


def solo(keep: int) -> str:
    out = []
    for line in text:
        if line.startswith("ROW "):
            head, *cells = line.split(" : ")
            # The dpcm column (4) carries the speed (Fxx) and the loop's jump: always kept.
            line = " : ".join([head] + [c if i in (keep, 4) else
                                        "... .. . " + " ".join(["..."] * (len(c.split()) - 3))
                                        for i, c in enumerate(cells)])
        out.append(line)
    return "\n".join(out)


def rms(a) -> float:
    return 20 * np.log10(np.sqrt(np.mean(a ** 2)) + 1e-12)


full = fr.render(fr.parse_module("\n".join(text)))
print(f"full mix: rms {rms(full.samples[full.loop_start:]):.1f} dBFS, peak {20 * np.log10(full.peak):.1f} dBFS")
for i, name in enumerate(NAMES):
    if i == 4:
        continue
    r = fr.render(fr.parse_module(solo(i)))
    x = r.samples[r.loop_start:]
    if np.abs(x).max() < 1e-5:
        continue
    sp = np.abs(np.fft.rfft(x))
    f = np.fft.rfftfreq(len(x), 1 / fr.RATE)
    print(f"  {name:9s} rms {rms(x):6.1f} dBFS   brightness ~{float((sp * f).sum() / sp.sum()):5.0f} Hz")
