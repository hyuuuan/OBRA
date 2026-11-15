"""Tempo, beat grid and the drum pattern of a reference recording, from a start time on.

Only rhythm and harmony are measured -- where the hits fall per sixteenth, in which band, and the
chord colour per bar. No melody is extracted.
    analyse_beat.py REF.wav START_SECONDS
"""
import sys

import numpy as np
from scipy.io import wavfile
import warnings
warnings.filterwarnings("ignore", category=wavfile.WavFileWarning)   # the smpl chunk: read past it
from scipy.signal import butter, sosfilt, stft

path, start = sys.argv[1], float(sys.argv[2])
rate, x = wavfile.read(path)
x = x.astype(np.float64) / 32768.0
x = x[int(start * rate):]
hop = 256
f, t, Z = stft(x, fs=rate, nperseg=1024, noverlap=1024 - hop)
mag = np.abs(Z)
frame_rate = rate / hop

# Onset strength: positive spectral flux.
flux = np.maximum(np.diff(np.log1p(mag), axis=1), 0).sum(axis=0)
flux = (flux - flux.mean()) / (flux.std() + 1e-9)

# Tempo: autocorrelation of the onset strength, 70-180 BPM.
ac = np.correlate(flux, flux, "full")[len(flux) - 1:]
lags = np.arange(len(ac))
bpm = 60.0 * frame_rate / np.maximum(lags, 1)
ok = (bpm > 70) & (bpm < 180)
best = lags[ok][np.argmax(ac[ok])]
tempo = 60.0 * frame_rate / best
print(f"tempo ~ {tempo:.1f} BPM (beat {60/tempo:.3f} s); runner-up lags:",
      ", ".join(f"{60*frame_rate/l:.1f}" for l in lags[ok][np.argsort(ac[ok])[-4:]]))

# Bands: low (tambol / kick), mid-low (toms, bass), snare-ish noise, high (sticks, hats).
def band(lo, hi):
    sel = (f >= lo) & (f < hi)
    e = mag[sel].sum(axis=0)
    d = np.maximum(np.diff(e), 0)
    return d / (d.max() + 1e-9)

bands = {"low <150": band(30, 150), "mid 150-500": band(150, 500), "snare 1.5-5k": band(1500, 5000),
         "high 6-11k": band(6000, 11000)}

# Refine the beat period and find the phase that puts the most low-band energy on beat one.
beat = 60.0 / tempo
sixteenth = beat / 4
steps = int(len(flux) / frame_rate / sixteenth) - 1

def grid(env, phase):
    idx = ((phase + np.arange(steps) * sixteenth) * frame_rate).astype(int)
    idx = idx[idx < len(env) - 2]
    return np.array([env[max(i - 1, 0):i + 2].max() for i in idx])

best_phase, best_score = 0.0, -1
for phase in np.linspace(0, beat, 48, endpoint=False):
    g = grid(flux, phase)
    score = g[0::4].sum()                      # onsets on the beats
    if score > best_score:
        best_phase, best_score = phase, score
low = grid(bands["low <150"], best_phase)
bar_offset = int(np.argmax([low[o::16].sum() for o in range(0, 16, 4)])) * 4   # which beat is "one"
print(f"beat grid starts {start + best_phase + bar_offset * sixteenth:.3f} s into the file")

print("\naverage strength per sixteenth of the bar (0 = beat one), each band scaled to its own max:")
print("step        " + " ".join(f"{s:>3d}" for s in range(16)))
for name, env in bands.items():
    g = grid(env, best_phase)[bar_offset:]
    n = len(g) // 16
    avg = g[: n * 16].reshape(n, 16).mean(axis=0)
    avg = avg / (avg.max() + 1e-9)
    print(f"{name:12s}" + " ".join(f"{int(round(v * 9)):>3d}" for v in avg))

# Chord colour per bar: chroma of the mid band, strongest three pitch classes.
names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
sel = (f > 100) & (f < 2000)
pitch = np.round(12 * np.log2(f[sel] / 440.0) + 69).astype(int) % 12
chroma_frames = np.zeros((12, mag.shape[1]))
for pc in range(12):
    chroma_frames[pc] = mag[sel][pitch == pc].sum(axis=0)
total = chroma_frames.sum(axis=1)
print("\nkey colour (whole stretch):", " ".join(f"{names[i]}" for i in np.argsort(total)[::-1][:7]))
bar_len = beat * 4
first = best_phase + bar_offset * sixteenth
print("strongest pitch classes per bar (first 16 bars):")
for b in range(16):
    a, z = int((first + b * bar_len) * frame_rate), int((first + (b + 1) * bar_len) * frame_rate)
    if z >= chroma_frames.shape[1]:
        break
    c = chroma_frames[:, a:z].sum(axis=1)
    print(f"  bar {b + 1:2d}: " + " ".join(names[i] for i in np.argsort(c)[::-1][:3]))
