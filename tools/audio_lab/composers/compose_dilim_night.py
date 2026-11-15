"""Write Dilim's three synchronized night waves and the one-shot dawn cue.

    compose_dilim_night.py TOOLS_DIR WAVE1.txt WAVE2.txt WAVE3.txt DAWN.txt
"""
import sys

from compose_dilim import KNOCK, MOTIF, Song, strike, write_module

BAR = 16
# Each arrangement shares the same order list, tempo and core parts so the game
# can crossfade at the current playhead when a new wave begins.
ROOTS = ("E", "E", "F", "B", "E", "E", "C", "B", "A", "A#", "A", "B",
         "E", "E", "F", "B", "C", "A#", "F", "B")
OSTINATO = (
    ("B2", "F2"), ("G2", "D2"), ("C3", "B2"), ("F#2", "C3"),
    ("B2", "F2"), ("G2", "D2"), ("G2", "F#2"), ("F#2", "C3"),
    ("C3", "E2"), ("F2", "A2"), ("C3", "G2"), ("F#2", "C3"),
    ("B2", "F2"), ("G2", "D2"), ("C3", "B2"), ("F2", "D#2"),
    ("G2", "F#2"), ("F2", "A2"), ("C3", "E2"), ("F#2", "C3"),
)

LANTERN_CALL = tuple(zip(
    (0, 3, 5, 10), (note + octave for note, octave in zip(MOTIF, "4443", strict=True)),
    (2, 1, 3, 4), strict=True,
))
# The little pauses between calls let the answering line come through.
CALLS = {
    1: ((8, "E4", 2), (13, "B3", 2)),
    3: ((3, "C4", 2), (6, "D#4", 3), (12, "F4", 2)),
    4: LANTERN_CALL,
    5: ((3, "G4", 3), (8, "F4", 2), (13, "D4", 4)),
    6: ((2, "E4", 2), (7, "C4", 3), (12, "F#4", 3)),
    7: ((2, "F4", 2), (6, "D#4", 3), (11, "C4", 2)),
    8: ((1, "A3", 3), (7, "C4", 2), (11, "E4", 4)),
    9: ((3, "F4", 2), (6, "E4", 3), (11, "A#3", 4)),
    10: ((4, "A3", 2), (7, "C4", 2), (11, "G4", 4)),
    11: ((2, "F#4", 3), (8, "C4", 2), (11, "D#4", 3)),
    12: LANTERN_CALL,
    13: ((1, "G4", 3), (7, "B4", 3), (12, "G4", 2)),
    14: ((1, "E4", 3), (6, "F4", 2), (9, "B4", 4)),
    15: ((1, "C5", 3), (6, "F#4", 3), (12, "D#4", 3)),
    16: ((0, "E4", 3), (5, "G4", 2), (8, "C5", 4), (13, "B4", 2)),
    17: ((1, "A#4", 3), (6, "A4", 2), (11, "F4", 4)),
    18: ((1, "F4", 3), (6, "E4", 2), (9, "B3", 3)),
    19: ((0, "C4", 3), (5, "D#4", 3), (11, "F4", 2)),
}
DESCANT = {
    4: (("B3", 4, 4), ("F3", 14, 2)), 5: (("E3", 9, 4),),
    6: (("G3", 4, 4), ("C4", 14, 3)), 7: (("F#3", 8, 4),),
    8: (("E4", 3, 4), ("C4", 13, 4)), 9: (("A#3", 5, 4),),
    10: (("G3", 6, 5),), 11: (("B3", 6, 4), ("F3", 13, 3)),
    12: (("B3", 4, 4), ("F3", 14, 2)), 13: (("E4", 4, 3), ("D4", 10, 5)),
    14: (("F3", 5, 5),), 15: (("B3", 6, 3), ("A3", 11, 3)),
    16: (("G3", 4, 4), ("F#3", 11, 3)), 17: (("E4", 4, 4), ("A#3", 14, 3)),
    18: (("C4", 4, 3), ("B3", 13, 3)), 19: (("F3", 6, 6),),
}


def night(wave: int) -> Song:
    song = Song(f"Dilim - Until Dawn ({wave})", frames=5, rows=4 * BAR, speed=7, loop_to=1, comments=(
        "Night waves share the same playhead: four bars of intro, sixteen in the loop.",
        "138 BPM; wood and bass, then a reed response, then a second pulse and low agung.",
    ))
    song.swing(7, 6)
    wood = song.inst_vrc7("damped wood", patch=0, regs=KNOCK)
    bass = song.inst_vrc7("undertow", patch=13)
    reed = song.inst_vrc7("low reed", patch=5)
    agung = song.inst_vrc7("distant agung", patch=9)
    square = song.inst_2a03("lantern motif", volume=[11, 10, 9, 8, 7, 7, 6, 6, 5, 4, 3, 2, 1], duty=[1])
    echo = song.inst_2a03("second pulse", volume=[6, 5, 4, 3, 2, 1, 0], duty=[1])
    drum = song.inst_2a03("low drum", volume=[10, 9, 7, 4, 3, 2, 1, 0], duty=[0])

    for index, (root, (answer, tension)) in enumerate(zip(ROOTS, OSTINATO, strict=True)):
        frame, row = index // 4, index % 4 * BAR
        knocks = ((0, root + "2", 15), (4, answer, 11), (8, tension, 14), (12, root + "2", 12))
        if index in (3, 7, 11, 15, 19):
            knocks = knocks[:3] + ((11, answer, 11), (13, tension, 14))
        for step, pitch, volume in knocks:
            strike(song, "fm1", frame, row + step, pitch, wood, volume, 2)
        if index > 0:
            for step, pitch, gate in ((0, root + "1", 5), (7, root + "1", 4), (12, root + "2", 3)):
                if index in (3, 11, 19) and step == 12:
                    continue
                strike(song, "fm2", frame, row + step, pitch, bass, 15 if step == 0 else 12, gate)
        if index >= 4:
            hits = (0, 8) if index % 4 != 3 else (0, 6, 10)
            if wave >= 2 and index % 4 == 2:
                hits = (0, 6, 8, 14)
            for step in hits:
                song.put("noise", frame, row + step, "3-#", drum, 11 if step == 0 else 8)
        for step, pitch, gate in CALLS.get(index, ()):
            strike(song, "pulse1", frame, row + step, pitch, square, 12 if step < 4 else 11, gate)
            if wave == 3 and gate >= 3:
                strike(song, "pulse2", frame, row + step + 2, pitch, echo, 10, 2)
        if wave >= 2:
            for pitch, step, gate in DESCANT.get(index, ()):
                strike(song, "fm3", frame, row + step, pitch, reed, 11 if wave == 2 else 13, gate)
        if wave == 3 and index in (0, 4, 8, 12, 15, 16, 19):
            strike(song, "fm4", frame, row, root + "3", agung, 12, 7)
            strike(song, "fm1", frame, row + 6, answer, wood, 11, 1)
    return song


def dawn() -> Song:
    song = Song("Dilim - First Light", frames=1, rows=114, speed=1, loop_to=None, comments=(
        "The lantern motif comes to rest on E major as the dawn breaks.",
    ))
    low = song.inst_vrc7("distant agung", patch=9)
    flute = song.inst_vrc7("bamboo flute", patch=4)
    bell = song.inst_vrc7("light on leaves", patch=10)
    light = song.inst_2a03("fading lantern", volume=[8, 8, 7, 6, 5, 4, 4, 3, 3, 2, 2, 1, 0], duty=[1])
    strike(song, "fm1", 0, 0, "E3", low, 13, 54)
    for row, pitch, gate, volume in ((0, "B4", 10, 12), (12, "E5", 10, 12),
                                      (25, "F#5", 9, 11), (36, "G#5", 34, 12)):
        strike(song, "fm2", 0, row, pitch, flute, volume, gate)
    strike(song, "pulse1", 0, 12, "E4", light, 10, 12)
    strike(song, "pulse1", 0, 36, "B4", light, 9, 14)
    strike(song, "fm3", 0, 36, "E5", bell, 8, 18)
    strike(song, "fm4", 0, 45, "B5", bell, 6, 18)
    song.put("dpcm", 0, 88, fx="C00")
    return song


if __name__ == "__main__":
    scores = (night(1), night(2), night(3), dawn())
    for score, output in zip(scores, sys.argv[2:], strict=True):
        write_module(score, output)
