"""Scaffolding: Piyesta's street, as a soft chip hubbub (Kent, 2026-11-15: the syllable babble was
"distorted hazy", and he chose "a quiet, smooth murmur texture with no syllables").

No struck notes: four VRC7 chorus voices hum low and glide slowly between nearby pitches (3xx),
never re-struck, so nothing chops; under them a dark noise breathes in slow swells. Quiet.

    compose_street.py TOOLS_DIR OUT.txt
"""
import random
import sys
from pathlib import Path

sys.path.insert(0, sys.argv[1])
from famitext import Song  # noqa: E402

rng = random.Random(20261115)
ROWS = 128
hub = Song("Plaza street", frames=2, rows=ROWS, speed=8, loop_to=0, comments=(
    "Piyesta's street: a smooth hubbub -- four low humming voices, gliding, never struck again.",
))
# The low flute: a soft "oo". The chorus patch was the brighter (~3.2 kHz with the noise).
HUM = hub.inst_vrc7("hum", patch=4)
# ⚠ NO NOISE. A noise bed under the hum -- struck each bar, then once and swelling -- was the
# "distorted, hazy" Kent heard: it set the level (-34 dBFS against the hum's -48), the brightness
# (2.8 kHz against 1.5) and the jumps. The hum alone is the murmur.
NOTES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def name(midi: int) -> str:
    return f"{NOTES[midi % 12]}{midi // 12 - 1}"


TOTAL = 2 * ROWS
for channel, base, start in (("fm1", 48, 0), ("fm2", 51, 9), ("fm3", 55, 17), ("fm4", 43, 25)):
    # One long breath of humming, gliding a step or two now and then: struck once, never again.
    frame, row = hub.at(0, start)
    hub.put(channel, frame, row, name(base), HUM, 9, "302")
    row_at = start
    while row_at < TOTAL - 16:
        row_at += rng.randrange(10, 22)
        if row_at >= TOTAL - 4:
            break
        frame, row = hub.at(0, row_at)
        # Pitch only: a change of volume is a step the ear hears as a jump.
        hub.put(channel, frame, row, name(base + rng.choice((-2, -1, 0, 1, 2, 3))))
Path(sys.argv[2]).write_text(hub.text())
print("wrote", sys.argv[2])
