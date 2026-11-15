"""Octave-band balance of recordings (dB relative to each one's total), and the beat-one boom's
strength against the pickup, measured with the bar start fixed by the best rotation."""
import sys
import numpy as np
from scipy.io import wavfile
import warnings
warnings.filterwarnings("ignore", category=wavfile.WavFileWarning)   # the smpl chunk: read past it
def load(path, start, dur):
    rate, x = wavfile.read(path); x = x.astype(float) / 32768
    if x.ndim > 1: x = x.mean(axis=1)
    return rate, x[int(start * rate): int((start + dur) * rate)]
edges = [30, 60, 120, 250, 500, 1000, 2000, 4000, 8000, 16000]
print("band Hz      " + " ".join(f"{a:>5d}" for a in edges[:-1]))
for arg in sys.argv[1:]:
    path, start, dur = arg.split(":")
    rate, x = load(path, float(start), float(dur))
    sp = np.abs(np.fft.rfft(x)) ** 2; f = np.fft.rfftfreq(len(x), 1 / rate)
    tot = sp.sum()
    row = [10 * np.log10(sp[(f >= a) & (f < b)].sum() / tot + 1e-12) for a, b in zip(edges, edges[1:])]
    print(f"{path.split('/')[-1][:12]:12s} " + " ".join(f"{v:5.1f}" for v in row))
