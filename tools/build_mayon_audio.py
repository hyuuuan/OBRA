#!/usr/bin/env python3
"""Original synthesized Mayon soundscape. No sampled or third-party recordings.

Seeded filtered noise for the weather, a dry brush gesture, and a sparse original
pentatonic melody over changing open fifths. These are authored synthetic sounds,
not recordings of Mayon or traditional Bicol music.
"""
from pathlib import Path
import wave
import numpy as np

OUT = Path(__file__).resolve().parent.parent / 'game/assets/Level5/audio'
RATE = 22050


def write(name, data):
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / (name + '.wav')), 'wb') as wav:
        wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(RATE)
        wav.writeframes((np.clip(data, -1, 1) * 32700).astype('<i2').tobytes())


def main():
    rng = np.random.default_rng(20261031)
    t = np.arange(RATE * 12) / RATE
    noise = rng.normal(size=t.size)
    low = np.convolve(noise, np.ones(160) / 160, mode='same')
    rumble = low * .9 + .07 * np.sin(2*np.pi*39*t) + .035 * np.sin(2*np.pi*57*t)
    # Periodic envelopes meet at the same level so the weather loops without a thump.
    write('eruption', rumble * (.65 + .35 * np.sin(np.pi*t/12)**2))
    wind = np.convolve(noise, np.ones(18)/18, mode='same')
    write('wind', wind * (.2 + .12*np.sin(np.pi*t/12)**2))
    bt = np.arange(int(RATE*.65))/RATE
    brush = rng.normal(size=bt.size) * np.sin(np.pi*bt/.65)**2 * .10
    write('brush', brush)
    length = 80
    music = np.zeros(RATE * length)
    # Written for this ending: F, D minor, B-flat, C; no existing melody is quoted.
    melody = [69,72,76,74,72,69,67,65, 69,72,77,76,74,72,69,67]
    for index, note in enumerate(melody):
        at = 2.0 + index * 4.0
        tt = np.arange(RATE*8)/RATE
        hz = 440 * 2**((note-69)/12)
        tone = (np.sin(2*np.pi*hz*tt) + .22*np.sin(2*np.pi*hz*2*tt))
        tone *= (1-np.exp(-tt*24))*np.exp(-tt/2.1)*.13
        start = int(at*RATE); music[start:start+len(tone)] += tone
    for index, root in enumerate([41,38,34,36]*2):
        tt = np.arange(RATE*12)/RATE; at = index*8
        hz = 440*2**((root-69)/12)
        chord = sum(np.sin(2*np.pi*hz*ratio*tt) for ratio in [1,1.5,2])
        chord *= (1-np.exp(-tt))*np.exp(-tt/4)*.025
        music[at*RATE:at*RATE+len(chord)] += chord
    music *= np.minimum(np.arange(music.size)/(RATE*2), 1)
    music *= np.minimum(np.arange(music.size)[::-1]/(RATE*8), 1)
    write('ending', music)


if __name__ == '__main__':
    main()
