"""Write the forest, Tikbalang race, and ambience FamiTracker modules.

    compose_dilim.py TOOLS_DIR FOREST.txt RACE.txt AMBIENCE.txt
"""
import sys
from pathlib import Path

sys.path.insert(0, sys.argv[1])
from famitext import Song, transpose  # noqa: E402

# A struck, damped wooden sound. The modulator decays faster than the carrier.
# Use a single custom VRC7 patch per module.
KNOCK = (0x03, 0x01, 0x2A, 0x00, 0xF6, 0xF4, 0x76, 0x47)
MOTIF = ("E", "F", "E", "B")


def strike(song, channel, frame, row, note, instrument, volume, gate):
    song.put(channel, frame, row, note, instrument, volume)
    song.put(channel, frame, row + gate, "===")


# The four strikes of each bar. The cadence keeps turning away from E. The
# deeper registers answer only after the first statement of the ostinato.
FOREST_BARS = (
    ("E2", "B2", "F2", "E2"), ("E2", "G2", "F2", "D2"),
    ("E2", "B2", "F2", "E2"), ("C2", "G2", "F#2", None),
    ("E2", "B2", "F2", "E2"), ("E2", "G2", "F2", "D2"),
    ("E2", "B2", "F2", "E2"), ("C2", "G2", "F#2", None),
    ("A2", "C3", "G2", "A2"), ("A#2", "F2", "A2", "E2"),
    ("A2", "C3", "G2", "A2"), ("B1", "F#2", "C3", None),
    ("E2", "B2", "F2", "E2"), ("E2", "G2", "F2", "D2"),
    ("E2", "B2", "F2", "E2"), ("C2", "G2", "F#2", "B1"),
    ("C2", "G2", "C3", "F#2"), ("A2", "E2", "A#2", "F2"),
    ("C2", "G2", "C3", "F#2"), ("B1", "F#2", "C3", None),
    ("E2", "B2", "F2", "E2"), ("E2", "G2", "F2", "D2"),
    ("F2", "B2", "E2", "F2"), ("B1", "C3", None, None),
)
FOREST_BASS = ("E", "E", "E", "C", "E", "E", "E", "C",
               "A", "A#", "A", "B", "E", "E", "E", "C",
               "C", "A", "C", "B", "E", "E", "F", "B")

# Row, pitch, gate in sixteenths, volume. Long tones frame the short calls.
FOREST_LEAD = {
    2: ((10, "B3", 4, 6),),
    4: ((2, "E4", 3, 9), (7, "F4", 1, 8), (9, "E4", 3, 9), (14, "B3", 5, 7)),
    6: ((5, "G4", 4, 9), (11, "F4", 2, 8), (14, "D4", 5, 7)),
    8: ((2, "A3", 5, 8), (9, "C4", 2, 9), (13, "B3", 4, 8)),
    10: ((4, "E4", 4, 8), (10, "D4", 2, 8), (13, "C4", 5, 7)),
    12: ((2, "E4", 3, 9), (7, "F4", 1, 9), (9, "E4", 3, 8), (14, "B3", 5, 7)),
    14: ((3, "E4", 2, 8), (8, "G4", 3, 9), (13, "F#4", 4, 8)),
    16: ((2, "G4", 4, 8), (8, "C5", 3, 9), (13, "B4", 4, 8)),
    18: ((1, "F#4", 4, 8), (9, "G4", 2, 9), (12, "C5", 4, 9)),
    19: ((4, "B4", 3, 9), (8, "F4", 2, 8), (11, "D#4", 3, 7)),
    20: ((3, "E4", 3, 9), (8, "F4", 1, 9), (10, "E4", 3, 8), (15, "B3", 4, 7)),
    22: ((4, "F4", 4, 8), (10, "E4", 4, 7)),
    23: ((4, "C4", 4, 7), (11, "B3", 2, 6)),
}


def forest() -> Song:
    song = Song("Dilim - The Unseen Path", frames=6, rows=64, speed=8, loop_to=1, comments=(
        "A low wooden ostinato, an uneven answer on the square, and soft agung accents.",
        "Four bars alone, then twenty bars with a bass pedal. 109 BPM.",
    ))
    wood = song.inst_vrc7("damped wood", patch=0, regs=KNOCK)
    bass = song.inst_vrc7("low pedal", patch=13)
    agung = song.inst_vrc7("distant agung", patch=9)
    answer = song.inst_vrc7("bamboo flute", patch=4)
    square = song.inst_2a03("lantern motif",
                            volume=[11, 11, 10, 10, 9, 9, 7, 7, 6, 6, 5, 5, 4, 4, 2, 2, 1], duty=[1])
    echo = song.inst_2a03("short square echo", volume=[4, 4, 3, 3, 2, 2, 1, 0], duty=[1])

    for index, knocks in enumerate(FOREST_BARS):
        frame, row = index // 4, (index % 4) * 16
        for step in (3, 7, 11, 15):
            song.put("dpcm", frame, row + step, fx="F09")
            song.put("dpcm", frame, row + step + 1, fx="F08")
        for beat, (note, volume) in enumerate(zip(knocks, (15, 11, 14, 12), strict=True)):
            if note is not None:
                strike(song, "fm1", frame, row + beat * 4, note, wood, volume, 3)

        root = FOREST_BASS[index]
        if index >= 4:
            strike(song, "fm2", frame, row, root + "1", bass, 14 if index in (4, 12, 20) else 13, 9)
            if index % 4 < 3:
                strike(song, "fm2", frame, row + 11, root + "1", bass, 11, 4)
        if index in (4, 8, 12, 16, 18, 20, 23):
            strike(song, "fm3", frame, row + 2, root + "3", agung, 10, 6)
        for step, pitch, gate, volume in FOREST_LEAD.get(index, ()):
            if 16 <= index <= 19:
                strike(song, "fm4", frame, row + step, pitch, answer, volume + 2, gate)
            else:
                strike(song, "pulse1", frame, row + step, pitch, square, volume, gate)
                if gate >= 3 and index in (4, 6, 12, 20):
                    strike(song, "pulse2", frame, row + step + 3, pitch, echo, 9, 2)
    return song


RACE_BARS = (
    ("E", "B2", "F2"), ("E", "G2", "D2"), ("E", "B2", "F2"), ("C", "G2", "F#2"),
    ("A", "E2", "A#2"), ("A", "C3", "G2"), ("B", "F#2", "C3"), ("B", "F2", "D#2"),
    ("E", "B2", "F2"), ("E", "G2", "D2"), ("C", "G2", "F#2"), ("B", "F#2", "C3"),
    ("F", "C3", "B2"), ("F", "A2", "E2"), ("B", "F#2", "C3"), ("B", "F2", "D#2"),
)

RACE_CALLS = (
    ((0, "E4", 2), (3, "F4", 1), (5, "E4", 2), (9, "B3", 4)),
    ((4, "G4", 2), (7, "F4", 1), (9, "D4", 2)),
    ((0, "E4", 2), (3, "F4", 1), (5, "E4", 2), (9, "B3", 4)),
    ((3, "C4", 2), (6, "F#4", 2), (10, "E4", 1)),
    ((0, "A3", 2), (3, "C4", 2), (8, "A#3", 1), (10, "A3", 2)),
    ((4, "E4", 2), (7, "C4", 4)),
    ((0, "B3", 2), (3, "C4", 1), (5, "B3", 2), (9, "F#4", 2)),
    ((6, "F4", 1), (8, "D#4", 2)),
    ((0, "E4", 2), (3, "F4", 1), (5, "E4", 2), (9, "B3", 4)),
    ((4, "G4", 2), (7, "F4", 1), (9, "D4", 2)),
    ((2, "C4", 2), (5, "G4", 2), (9, "F#4", 2)),
    ((0, "F#4", 2), (3, "C5", 2), (7, "B4", 1), (9, "F4", 2)),
    ((0, "F4", 2), (3, "G4", 1), (5, "F4", 2), (9, "B3", 3)),
    ((2, "A4", 2), (6, "G4", 1), (9, "E4", 2)),
    ((0, "F#4", 2), (3, "F4", 1), (5, "D#4", 2), (9, "C4", 2)),
    ((0, "B3", 4), (8, "D#4", 2)),
)


def race() -> Song:
    bar = 12
    song = Song("Dilim - Hooves in the Dark", frames=4, rows=4 * bar, speed=8, comments=(
        "The forest's wood becomes a gallop. The reed shortens the lantern motif.",
        "Triplet eighths at 150 BPM.",
    ))
    wood = song.inst_vrc7("hoof", patch=0, regs=KNOCK)
    bass = song.inst_vrc7("low pedal", patch=13)
    reed = song.inst_vrc7("low reed", patch=5)
    agung = song.inst_vrc7("distant agung", patch=9)
    thud = song.inst_2a03("low dust", volume=[9, 7, 5, 3, 1, 0], duty=[0])

    for index, ((root, answer, tension), calls) in enumerate(zip(RACE_BARS, RACE_CALLS, strict=True)):
        frame, row = index // 4, (index % 4) * bar
        for step in (0, 2, 3, 5, 6, 8, 9, 11):
            if index in (7, 15) and step in (6, 8):
                continue
            pitch = root + "2" if step % 3 == 0 else (tension if step >= 8 else answer)
            song.put("fm1", frame, row + step, pitch, wood, 15 if step % 3 == 0 else 10, "S05")
        for step, volume in ((0, 15), (5, 11), (9, 13)):
            strike(song, "fm2", frame, row + step, root + "1", bass, volume, 2)
        if index % 4 == 0:
            strike(song, "fm3", frame, row, root + "2", agung, 10, 5)
        for step in ((3, 9) if index % 4 != 3 else (3, 8, 10)):
            song.put("noise", frame, row + step, "2-#", thud, 10)
        for step, pitch, gate in calls:
            # Keep the reed's strongest overtones below the tiyanak's cry.
            strike(song, "fm4", frame, row + step, transpose(pitch, -12), reed, 12 if step % 3 == 0 else 10, gate)
    return song


def night_bed() -> Song:
    song = Song("Dilim - Forest Air", frames=2, rows=128, speed=6, comments=(
        "Two frogs answer at irregular intervals. Low noise moves in separate gusts.",
    ))
    frog = song.inst_vrc7("frog", patch=13)
    breath = song.inst_2a03("wind", volume=[1] * 16 + [2] * 24 + [1] * 44 + [0], duty=[0])
    for frame, (gusts, calls) in enumerate((
        ((0, 74), ((11, "A2", 9), (27, "E2", 11), (31, "E2", 9),
                   (65, "G2", 8), (90, "A2", 10), (115, "E2", 11))),
        ((29, 94), ((6, "E2", 9), (39, "A2", 10), (43, "A2", 8),
                    (78, "G2", 8), (105, "E2", 11), (123, "A2", 8))),
    )):
        for row in gusts:
            song.put("noise", frame, row, "0-#", breath, 15)
        for row, pitch, volume in calls:
            song.put("fm1", frame, row, pitch, frog, volume, "R51")
            song.put("fm1", frame, row + 2, "===")
    return song


def write_module(song: Song, path: str) -> None:
    # FamiStudio's importer recognizes the standard text export header.
    _, _, module = song.text().partition("\n")
    Path(path).write_text("# FamiTracker text export 0.4.2\n" + module, encoding="utf-8")


if __name__ == "__main__":
    for score, output in zip((forest(), race(), night_bed()), sys.argv[2:], strict=True):
        write_module(score, output)
