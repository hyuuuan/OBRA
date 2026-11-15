"""Peak level in each sixteenth of a few bars, in dB: where a stem actually strikes.
    steps.py WAV START_S BPM BARS"""
import sys
import numpy as np
from scipy.io import wavfile
import warnings
warnings.filterwarnings("ignore", category=wavfile.WavFileWarning)   # the smpl chunk: read past it
rate, x = wavfile.read(sys.argv[1]); x = x.astype(float) / 32768
start, bpm, bars = float(sys.argv[2]), float(sys.argv[3]), int(sys.argv[4])
six = 60 / bpm / 4
for b in range(bars):
    cells = []
    for s in range(16):
        a = int((start + (b * 16 + s) * six) * rate)
        seg = x[a: a + int(0.03 * rate)]                      # the first 30 ms of the sixteenth
        cells.append(f"{20*np.log10(np.abs(seg).max()+1e-9):4.0f}")
    print(f"bar {b}: " + " ".join(cells))
