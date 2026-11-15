"""Write Payyo's "Up the Green Steps" tracker module.

    compose_terraces.py TOOLS_DIR OUT.txt
"""
import sys
from pathlib import Path

sys.path.insert(0, sys.argv[1])
from famitext import Song, transpose  # noqa: E402

BAR = 16
song = Song("Payyo - Up the Green Steps", frames=10, speed=8, comments=(
    "Original music for Payyo, the green terraces.",
    "D major, 138 BPM, 8:5 sixteenth swing. A A' B Break/Lift A''.",
    "2A03 drums and pulses, VRC7 bass, chord stabs, reeds, and short gangsa accents.",
))
song.swing(8, 5)

LEAD = song.inst_vrc7("Terrace reed", patch=5)
BRASS = song.inst_vrc7("Hilltop trumpet", patch=7)
KEYS = song.inst_vrc7("Soft comp keys", patch=3)
BASS = song.inst_vrc7("Finger bass", patch=13)
GONG = song.inst_vrc7("Short gangsa", patch=0, regs=(0x03, 0x01, 0x1E, 0x04, 0xF6, 0xF5, 0x37, 0x6A))
PLUCK = song.inst_2a03("Answer pluck", volume=[7, 7, 6, 5, 4, 3, 2, 1, 0], duty=[2])
ECHO = song.inst_2a03("Reed shadow", volume=[5, 5, 4, 3, 3, 2, 1, 0], duty=[2])
KICK = song.inst_2a03("Kick", volume=[15, 15, 15, 12, 10, 0],
                      arpeggio=[0, -3, -6, -8, -10, -12])
HAT = song.inst_2a03("Closed hat", volume=[4, 3, 2, 1, 0], duty=[0])
OPEN_HAT = song.inst_2a03("Loose hat", volume=[5, 4, 3, 3, 2, 2, 1, 0], duty=[0])
SNARE = song.inst_2a03("Backbeat", volume=[11, 9, 8, 7, 5, 4, 3, 2, 1, 0], duty=[0])
GHOST = song.inst_2a03("Ghost snare", volume=[5, 4, 3, 2, 1, 0], duty=[0])

# Root and three upper voices. The upper voices stay close as the bass moves.
CHORDS = {
    "Dmaj9":    ("D2",  ("F#4", "C#5", "E5")),
    "D6/9":     ("D2",  ("F#4", "B4",  "E5")),
    "F#m7":     ("F#2", ("A4",  "C#5", "E5")),
    "B7b13":    ("B2",  ("G4",  "A4",  "D#5")),
    "Bm9":      ("B2",  ("F#4", "A4",  "C#5")),
    "Em9":      ("E2",  ("G4",  "B4",  "D5")),
    "A13":      ("A2",  ("G4",  "B4",  "C#5")),
    "A7sus":    ("A2",  ("G4",  "A4",  "D5")),
    "Gmaj9":    ("G2",  ("F#4", "A4",  "B4")),
    "Gm6":      ("G2",  ("E4",  "A#4", "D5")),
    "C13":      ("C2",  ("G4",  "A#4", "E5")),
    "Fmaj9#11": ("F2",  ("A4",  "B4",  "E5")),
    "Dm9":      ("D2",  ("F4",  "C5",  "E5")),
    "G13":      ("G2",  ("F4",  "B4",  "E5")),
    "Cmaj9":    ("C2",  ("G4",  "B4",  "D5")),
    "E7b13":    ("E2",  ("G#4", "C5",  "D5")),
}

# Each tuple gives the chord changes within a bar. A second chord enters on beat three.
CHANGES = (
    # A: the hook climbs, answers down, and turns through the minor subdominant.
    ("Dmaj9",), ("F#m7", "B7b13"), ("Em9",), ("A13",),
    ("Gmaj9",), ("Gm6", "C13"), ("D6/9", "Bm9"), ("Em9", "A13"),
    # A': a second pass with a different cadence and a bass answer.
    ("Dmaj9",), ("F#m7", "B7b13"), ("Em9",), ("A7sus", "A13"),
    ("Gmaj9",), ("Gm6", "C13"), ("F#m7", "B7b13"), ("Em9", "A13"),
    # B: a side step into F Lydian and a chain of dominants back toward D.
    ("Fmaj9#11",), ("G13",), ("Cmaj9",), ("E7b13",),
    ("Dm9",), ("G13",), ("Em9", "Gm6"), ("A7sus", "A13"),
    # The gong and bass get space before the trumpet lift.
    ("Bm9",), ("Gmaj9",), ("Dmaj9",), ("A7sus",),
    ("Gmaj9",), ("F#m7", "B7b13"), ("Em9",), ("A7sus", "A13"),
    # A'': the hook returns with a higher answer and a short turnaround.
    ("Dmaj9",), ("F#m7", "B7b13"), ("Em9",), ("A13",),
    ("Gmaj9",), ("Gm6", "C13"), ("D6/9", "Bm9"), ("Em9", "A13"),
)

# Lead, written as (sixteenth, pitch, duration). The silences leave room for the answer pluck.
MELODY = (
    ((2, "F#5", 1), (3, "A5", 2), (6, "B5", 1), (7, "A5", 1), (8, "F#5", 4), (14, "E5", 1)),
    ((0, "C#5", 3), (4, "E5", 1), (6, "F#5", 2), (9, "G5", 2), (12, "D#5", 2), (15, "F#5", 1)),
    ((0, "G5", 3), (5, "F#5", 1), (6, "E5", 2), (10, "B4", 3), (14, "D5", 2)),
    ((1, "E5", 2), (4, "F#5", 1), (5, "E5", 1), (7, "C#5", 4), (13, "A4", 1), (14, "C#5", 2)),
    ((0, "D5", 2), (3, "F#5", 2), (6, "A5", 3), (10, "B5", 1), (11, "A5", 3)),
    ((0, "G5", 2), (3, "E5", 2), (6, "D5", 1), (8, "E5", 3), (12, "A#4", 1), (14, "D5", 2)),
    ((0, "C#5", 2), (2, "F#5", 2), (5, "E5", 3), (10, "D5", 2), (14, "C#5", 2)),
    ((0, "B4", 3), (5, "D5", 2), (8, "E5", 1), (9, "F#5", 1), (10, "E5", 4)),
    ((2, "F#5", 1), (3, "A5", 2), (6, "B5", 1), (7, "A5", 1), (8, "F#5", 4), (14, "E5", 1)),
    ((0, "C#5", 2), (3, "E5", 2), (6, "F#5", 2), (9, "A5", 2), (12, "G5", 2), (15, "D#5", 1)),
    ((0, "E5", 3), (4, "F#5", 1), (6, "G5", 2), (9, "B5", 4), (14, "A5", 2)),
    ((0, "G5", 3), (5, "E5", 2), (9, "F#5", 1), (10, "E5", 1), (11, "C#5", 3)),
    ((0, "D5", 2), (3, "F#5", 2), (6, "A5", 3), (10, "B5", 1), (11, "D6", 3)),
    ((0, "A#5", 3), (4, "A5", 1), (6, "G5", 2), (9, "E5", 2), (12, "D5", 2), (15, "C5", 1)),
    ((0, "C#5", 2), (3, "E5", 2), (6, "F#5", 2), (8, "D#5", 3), (13, "G5", 2)),
    ((0, "F#5", 2), (3, "G5", 2), (6, "B5", 2), (8, "A5", 4), (14, "G5", 1)),
    ((0, "E5", 4), (6, "A5", 2), (9, "B5", 1), (10, "C6", 3)),
    ((0, "B5", 3), (5, "G5", 2), (8, "E5", 2), (11, "F5", 2), (14, "D5", 2)),
    ((0, "E5", 3), (4, "G5", 2), (7, "B5", 4), (13, "D6", 2)),
    ((0, "C6", 2), (3, "B5", 2), (6, "G#5", 2), (9, "F#5", 1), (10, "E5", 4)),
    ((0, "F5", 4), (6, "A5", 1), (7, "C6", 2), (11, "E6", 3)),
    ((0, "D6", 3), (5, "B5", 1), (6, "G5", 2), (9, "E5", 3), (14, "F5", 2)),
    ((0, "F#5", 1), (2, "G5", 3), (7, "B5", 1), (8, "A#5", 3), (13, "G5", 2)),
    ((0, "E5", 3), (5, "D5", 2), (8, "C#5", 4)),
    (),
    ((6, "B4", 2), (10, "D5", 3)),
    (),
    ((4, "E5", 3), (10, "D5", 2), (14, "E5", 2)),
    ((0, "F#5", 3), (4, "A5", 2), (7, "B5", 3), (12, "D6", 3)),
    ((0, "C#6", 3), (4, "A5", 2), (8, "G5", 2), (11, "D#5", 2), (14, "F#5", 2)),
    ((0, "G5", 3), (4, "B5", 2), (7, "E6", 3), (12, "D6", 2), (14, "B5", 2)),
    ((0, "A5", 3), (4, "G5", 2), (8, "F#5", 2), (11, "E5", 3)),
    ((2, "F#5", 1), (3, "A5", 2), (6, "B5", 1), (7, "A5", 1), (8, "F#5", 4), (14, "E5", 1)),
    ((0, "C#5", 2), (3, "E5", 2), (6, "F#5", 2), (9, "A5", 2), (12, "G5", 2), (15, "D#5", 1)),
    ((0, "E5", 3), (5, "G5", 2), (8, "B5", 2), (11, "D6", 3)),
    ((0, "C#6", 3), (5, "B5", 1), (6, "A5", 2), (10, "F#5", 2), (13, "E5", 2)),
    ((0, "D5", 2), (3, "F#5", 2), (6, "A5", 3), (10, "B5", 1), (11, "D6", 3)),
    ((0, "A#5", 3), (4, "A5", 1), (6, "G5", 2), (9, "E5", 3), (14, "C5", 2)),
    ((0, "D5", 5), (7, "E5", 1), (8, "F#5", 3), (12, "D5", 2), (15, "C#5", 1)),
    ((0, "B4", 3), (4, "G5", 2), (8, "E5", 3), (12, "C#5", 2), (15, "E5", 1)),
)

# The pluck answers between phrases. The shadow doubles selected lead accents a third or sixth below.
ANSWERS = {
    2: ((8, "F#4"), (12, "G4")), 3: ((10, "A4"), (12, "B4")),
    5: ((10, "G4"), (13, "E4")), 7: ((11, "B4"), (13, "C#5"), (15, "E5")),
    10: ((7, "B4"), (12, "D5")), 11: ((2, "D5"), (6, "C#5")),
    13: ((7, "A#4"), (11, "G4")), 15: ((11, "C#5"), (13, "E5")),
    17: ((4, "E5"), (12, "B4")), 19: ((7, "D5"), (14, "G#4")),
    21: ((7, "B4"), (11, "D5")), 23: ((12, "F#5"), (14, "E5")),
    24: ((2, "F#4"), (6, "A4"), (11, "C#5")), 25: ((2, "D5"), (14, "A4")),
    26: ((2, "F#4"), (6, "A4"), (10, "E5"), (13, "C#5")),
    27: ((2, "B4"), (7, "E4"), (12, "A4")),
    35: ((4, "E5"), (9, "C#5")), 37: ((7, "D5"), (12, "G4")),
    38: ((4, "A4"), (10, "B4")), 39: ((6, "B4"), (11, "A4")),
}
HARMONY = {
    4: ((6, "F#5"), (11, "F#5")), 6: ((0, "A4"), (5, "C#5")),
    12: ((6, "F#5"), (11, "B5")), 14: ((6, "C#5"), (8, "B4")),
    16: ((0, "A4"), (10, "E5")), 18: ((7, "G5"), (13, "G5")),
    20: ((0, "D5"), (11, "C6")), 22: ((2, "E5"), (8, "G5")),
    28: ((0, "D5"), (7, "G5"), (12, "B5")), 29: ((0, "A5"), (8, "D#5")),
    30: ((0, "E5"), (7, "B5"), (12, "G5")), 31: ((0, "E5"), (8, "C#5")),
    34: ((8, "G5"), (11, "B5")), 36: ((6, "F#5"), (11, "B5")),
    38: ((0, "F#4"), (8, "D5")), 39: ((8, "C#5"),),
}
# Local percussion, exposed in the breakdown and used sparingly under the band.
GONG_HITS = {
    0: ((0, "D4"), (11, "A4")), 3: ((14, "E4"),),
    7: ((0, "E4"), (14, "A4")), 8: ((0, "D4"),), 12: ((8, "G4"),),
    15: ((0, "E4"), (14, "A4")), 19: ((12, "E4"),), 23: ((14, "A4"),),
    24: ((0, "B3"), (8, "F#4"), (14, "B4")), 25: ((0, "G3"), (7, "D4"), (12, "A4")),
    26: ((0, "D4"), (8, "A4"), (14, "E4")), 27: ((0, "A3"), (8, "E4"), (13, "A4")),
    28: ((0, "G4"),), 31: ((14, "A4"),), 32: ((0, "D4"), (11, "A4")),
    36: ((8, "G4"),), 39: ((14, "A4"),),
}


def write_lead(bar, frame, start):
    instrument = BRASS if 28 <= bar < 32 else LEAD
    for step, pitch, length in MELODY[bar]:
        volume = 14 if length > 1 else 12
        scoop = length >= 3 and (bar, step) in {(4, 6), (12, 11), (16, 0), (28, 7), (38, 0)}
        song.put("fm1", frame, start + step, pitch, instrument, volume, "P79" if scoop else None)
        if scoop:
            song.put("fm1", frame, start + step + 1, fx="P80")
        if step + length <= BAR:
            song.put("fm1", frame, start + step + length, "===")
    for step, pitch in ANSWERS.get(bar, ()):
        song.put("pulse1", frame, start + step, pitch, PLUCK, 12)
    for step, pitch in HARMONY.get(bar, ()):
        song.put("pulse2", frame, start + step, pitch, ECHO, 12)


def write_comp(bar, frame, start, changes):
    sparse = 24 <= bar < 28
    for section, chord in enumerate(changes):
        row = start + 8 * section
        _, voicing = CHORDS[chord]
        if sparse:
            hits = ((0, 4, 9), (10, 3, 8))
        elif len(changes) == 2:
            hits = ((0, 3, 11), (5, 2, 10))
        elif bar % 4 == 2:
            hits = ((0, 2, 11), (5, 2, 10), (11, 3, 11))
        else:
            hits = ((0, 3, 11), (6, 2, 10), (10, 3, 11))
        for step, length, volume in hits:
            for channel, pitch in zip(("fm3", "fm4", "fm5"), voicing):
                song.put(channel, frame, row + step, pitch, KEYS, volume)
                song.put(channel, frame, row + step + length, "===")
    for step, pitch in GONG_HITS.get(bar, ()):
        song.put("fm2", frame, start + step, pitch, GONG, 12 if sparse else 10)
        if step < 14:
            song.put("fm2", frame, start + step + 2, "===")


def write_bass(bar, frame, start, changes, next_chord):
    sparse = 24 <= bar < 28
    root, _ = CHORDS[changes[0]]
    fifth = transpose(root, 7)
    octave = transpose(root, 12)
    next_root, _ = CHORDS[next_chord]
    pickup = transpose(next_root, 1 if bar % 4 == 1 else -1)
    if sparse:
        notes = ((0, root, 6), (8, fifth, 3), (13, octave, 2))
    elif len(changes) == 2:
        second_root, _ = CHORDS[changes[1]]
        notes = ((0, root, 3), (4, fifth, 2), (7, octave, 1), (8, second_root, 3),
                 (12, transpose(second_root, 7), 2), (15, pickup, 1))
    elif bar % 4 in (0, 2):
        notes = ((0, root, 3), (3, octave, 2), (6, fifth, 2), (8, root, 2),
                 (11, octave, 2), (14, fifth, 1), (15, pickup, 1))
    else:
        notes = ((0, root, 3), (5, fifth, 2), (7, octave, 1), (8, root, 3),
                 (12, fifth, 2), (15, pickup, 1))
    for step, pitch, length in notes:
        song.put("fm6", frame, start + step, pitch, BASS, 13 if step % 8 == 0 else 11)
        if step + length < BAR:
            song.put("fm6", frame, start + step + length, "===")


def write_drums(bar, frame, start):
    if 24 <= bar < 27:
        kick_steps = (0, 8)
        hits = ((4, "5-#", GHOST), (10, "7-#", HAT), (12, "5-#", GHOST))
    elif bar == 23:
        kick_steps = (0, 5, 10)
        hits = ((0, "7-#", HAT), (3, "7-#", HAT), (4, "5-#", SNARE),
                (8, "7-#", HAT), (12, "4-#", SNARE))
    else:
        kick_steps = (0, 6, 8, 11) if bar % 2 == 0 else (0, 5, 10, 14)
        hits = [(step, "7-#", HAT) for step in (0, 2, 5, 8, 10, 13)]
        hits.extend(((4, "5-#", SNARE), (12, "4-#", SNARE)))
        hits.append((14, "6-#", OPEN_HAT))
        if bar % 4 == 3:
            hits.extend(((11, "4-#", GHOST), (15, "5-#", GHOST)))
    for step in kick_steps:
        song.put("triangle", frame, start + step, "F2", KICK)
    for step, pitch, instrument in hits:
        song.put("noise", frame, start + step, pitch, instrument, 15)


def main():
    for bar, changes in enumerate(CHANGES):
        frame, start = song.at(0, bar * BAR)
        next_chord = CHANGES[(bar + 1) % len(CHANGES)][0]
        write_bass(bar, frame, start, changes, next_chord)
        write_comp(bar, frame, start, changes)
        write_drums(bar, frame, start)
        write_lead(bar, frame, start)
    # FamiStudio's importer requires the standard FamiTracker version header.
    _, _, module = song.text().partition("\n")
    Path(sys.argv[2]).write_text("# FamiTracker text export 0.4.2\n" + module, encoding="utf-8")


if __name__ == "__main__":
    main()
