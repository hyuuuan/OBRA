"""Scaffolding: Piyesta's church music (Kent, 2026-11-15: "the church should be just a solemn
background, peaceful"). Original. (Its first version also wrote a syllable-babble crowd; Kent heard
that as "distorted, hazy", and the street is compose_street.py now.)

    compose_church.py TOOLS_DIR CHURCH.txt
"""
import sys
from pathlib import Path

sys.path.insert(0, sys.argv[1])
from famitext import Song  # noqa: E402

# --- the church: a slow hymn for reed organ ---------------------------------------------------------
HALF = 4                           # rows: 2 a beat, so a half note is 4
church = Song("Simbahan", frames=2, rows=64, speed=27, loop_to=0, comments=(
    "Piyesta's church: a slow four-voice hymn on the reed organ, a far bell. Original. F, ~67 BPM.",
))
ORGAN = church.inst_vrc7("reed organ", patch=8)
BELL = church.inst_vrc7("far bell", patch=9)
# Sixteen bars, two chords a bar: (soprano, alto, tenor, bass).
HYMN = [
    [("A4", "F4", "C4", "F3"), ("A#4", "F4", "D4", "A#2")],
    [("C5", "F4", "A3", "F3"), ("C5", "E4", "G3", "C3")],
    [("D5", "F4", "A3", "D3"), ("A#4", "F4", "D4", "A#2")],
    [("G4", "E4", "C4", "C3"), ("G4", "E4", "C4", "C3")],
    [("A4", "F4", "C4", "F3"), ("D5", "F4", "A#3", "A#2")],
    [("C5", "F4", "A3", "A2"), ("A#4", "G4", "D4", "G2")],
    [("G4", "E4", "C4", "C3"), ("G4", "E4", "A#3", "C3")],
    [("F4", "C4", "A3", "F2"), ("F4", "C4", "A3", "F2")],
    [("D5", "F4", "A#3", "A#2"), ("C5", "F4", "A3", "A2")],
    [("A#4", "G4", "D4", "G2"), ("C5", "E4", "G3", "C3")],
    [("A4", "F4", "C4", "F3"), ("A4", "F4", "D4", "D3")],
    [("G4", "D4", "A#3", "G2"), ("G4", "E4", "C4", "C3")],
    [("A4", "F4", "C4", "F3"), ("A#4", "F4", "D4", "A#2")],
    [("C5", "F4", "A3", "A2"), ("D5", "F4", "A3", "D3")],
    [("A#4", "F4", "D4", "A#2"), ("G4", "E4", "C4", "C3")],
    [("F4", "C4", "A3", "F2"), ("F4", "C4", "A3", "F2")],
]
held = [None] * 4
for bar, halves in enumerate(HYMN):
    for half, chord in enumerate(halves):
        frame, row = church.at(0, bar * 2 * HALF + half * HALF)
        for voice, (channel, note) in enumerate(zip(("fm1", "fm2", "fm3", "fm4"), chord)):
            if note != held[voice]:          # a held note is held, not struck again
                church.put(channel, frame, row, note, ORGAN, 14 if voice == 0 else 12)
                held[voice] = note
    if bar % 4 == 0:
        frame, row = church.at(0, bar * 2 * HALF)
        church.put("fm6", frame, row, "F4", BELL, 8)
# A breath before the hymn comes round again.
for channel in ("fm1", "fm2", "fm3", "fm4"):
    church.put(channel, 1, 63, "===")
Path(sys.argv[2]).write_text(church.text())
print("wrote", sys.argv[2])
