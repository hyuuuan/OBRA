"""A listening edit of a game WAV: the file, its loop once more, faded out -- what the game plays
-- with an optional ambience bed looped under it, as the game layers the two players.
    listen.py MUSIC.wav OUT.wav [BED.wav]      (plain numpy; no need to run it fenced)"""
import struct
import sys

import numpy as np
from scipy.io import wavfile
import warnings
warnings.filterwarnings("ignore", category=wavfile.WavFileWarning)   # the smpl chunk: read past it


def loop_of(path):
    data = open(path, "rb").read()
    at = data.index(b"smpl") + 8
    rate, x = wavfile.read(path)
    return rate, x.astype(np.float64), struct.unpack("<I", data[at + 44:at + 48])[0]


rate, x, start = loop_of(sys.argv[1])
again = x[start:].copy()
fade = min(int(12 * rate), len(again))
again[-fade:] *= np.linspace(1.0, 0.0, fade) ** 2
y = np.concatenate([x, again])
if len(sys.argv) > 3:
    _, w, wstart = loop_of(sys.argv[3])
    under = w.copy()
    while len(under) < len(y):
        under = np.concatenate([under, w[wstart:]])
    under = under[:len(y)]
    under[-fade:] *= np.linspace(1.0, 0.0, fade) ** 2
    y = y + under
wavfile.write(sys.argv[2], rate, np.round(np.clip(y, -32767, 32767)).astype(np.int16))
print(f"{sys.argv[2]}: {len(y) / rate:.1f} s, loop from {start / rate:.1f} s")
