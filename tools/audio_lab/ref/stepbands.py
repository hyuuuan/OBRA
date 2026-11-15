"""Average level per sixteenth (first 40 ms of each), per band, over many bars, in dB under the top.
    stepbands.py WAV DOWNBEAT_S BPM BARS"""
import sys
import numpy as np
from scipy.io import wavfile
import warnings
warnings.filterwarnings("ignore", category=wavfile.WavFileWarning)   # the smpl chunk: read past it
from scipy.signal import butter, sosfilt
rate, x = wavfile.read(sys.argv[1]); x = x.astype(float) / 32768
if x.ndim > 1: x = x.mean(axis=1)
start, bpm, bars = float(sys.argv[2]), float(sys.argv[3]), int(sys.argv[4])
six = 60 / bpm / 4
bands = {"low <150": butter(4, 150, "low", fs=rate, output="sos"),
         "mid 150-1.5k": butter(4, [150, 1500], "band", fs=rate, output="sos"),
         "high >1.5k": butter(4, 1500, "high", fs=rate, output="sos")}
print("step          " + " ".join(f"{s:>4d}" for s in range(16)))
for name, sos in bands.items():
    y = sosfilt(sos, x)
    lv = np.zeros(16)
    for b in range(bars):
        for s in range(16):
            a = int((start + (b * 16 + s) * six) * rate)
            lv[s] += np.sqrt(np.mean(y[a: a + int(0.04 * rate)] ** 2))
    db = 20 * np.log10(lv / lv.max())
    print(f"{name:13s} " + " ".join(f"{v:4.0f}" for v in db))
