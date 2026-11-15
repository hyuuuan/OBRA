"""Scaffolding: Terraces (Level 1) after Ifugao music (Kent, 2026-11-15: "like how Ifugao music
cultural sounds like"). Written from what the sources describe -- a gangsa ensemble of five or six
flat gongs, one player each, interlocking in syncopated parts (palook, struck with sticks while
dancing); bangibang, wooden bars struck with sticks; hudhud, chanted epic poetry, which
instruments do not accompany. Original: no real chant or gong piece is reproduced.

    compose_terraces.py TOOLS_DIR OUT.txt
"""
import sys
from pathlib import Path

sys.path.insert(0, sys.argv[1])
from famitext import Song  # noqa: E402

BAR = 16                          # 4/4 in sixteenths, straight: gong music does not swing
song = Song("Terraces", frames=5, rows=64, speed=8, loop_to=1, comments=(
    "Terraces, after Ifugao music: four short gangsa gongs in a hocket, wooden bangibang in the gaps,",
    "and a hudhud-like call and response over one gong. Original; ~112 BPM, straight sixteenths.",
))

# ⚠ THE GONG IS SHORT. The VRC7's soft bell rang 3.9 s a strike, and with ten strikes a bar the
# whole ensemble ran together into one wash (Kent: "everything is overlapping"). This custom patch
# is percussive -- modulator x3 over carrier x1, a little feedback, a fast decay to a low sustain
# level and a quick release -- and rings about a third of a second, dark (~1.4 kHz). Measured
# against the soft bell and three others before choosing it.
GONG = song.inst_vrc7("gangsa", patch=0, regs=(0x03, 0x01, 0x1E, 0x04, 0xF6, 0xF5, 0x37, 0x6A))
WOOD = song.inst_vrc7("bangibang", patch=10)      # wooden bars
CHANTER = song.inst_vrc7("chanter", patch=5)
CHORUS = song.inst_vrc7("chorus", patch=15)
DRUM = song.inst_2a03("low drum", volume=[15, 15, 12, 0], arpeggio=[26, 23, 21, 19], fixed=True)

# The gong set, low to high: four gongs a fifth and octaves apart, so nothing rubs. Not tuned to a
# Western scale: each is pitched a little off (Pxx). (A bend as it rings was tried and dropped:
# 2xx's smallest step, held through a low gong's ring, falls two semitones.)
# ⚠ A HOCKET: no two gongs ever strike on the same step. Each part has its own steps, and together
# they make one line of strokes with gaps in it, which the wood fills -- not a pile.
GONGS = [  # channel, note, fine pitch, the steps of the bar it strikes (its part in the interlock)
    ("fm2", "D4", "P7D", (0, 8)),
    ("fm3", "A4", "P83", (4, 12, 14)),
    ("fm4", "D5", "P7E", (2, 6, 10)),
    ("fm5", "E5", "P84", (7, 11, 15)),
]
WOOD_STEPS = (1, 5, 9, 13)                         # the steps no gong takes
WOOD_NOTES = ("A5", "C6")


def gongs(frame: int, bar: int, which: range, vol: int = 14) -> None:
    row = bar * BAR
    for index in which:
        channel, note, fine, steps = GONGS[index]
        for n, step in enumerate(steps):
            # The low gong, struck least, is struck hardest, so the time it keeps is heard.
            song.put(channel, frame, row + step, note, GONG, min(15, vol + (1 if index == 0 else 0)),
                     fine if n == 0 else None)
            # Damped two sixteenths on, as a hand stops a gangsa, unless the gong strikes again first.
            if step + 2 < BAR and step + 1 not in steps and step + 2 not in steps:
                song.put(channel, frame, row + step + 2, "===")


def wood_and_drum(frame: int, bar: int, vol: int) -> None:
    row = bar * BAR
    for n, step in enumerate(WOOD_STEPS):
        song.put("fm1", frame, row + step, WOOD_NOTES[n % 2], WOOD, vol)
    song.put("triangle", frame, row, "C4", DRUM)
    song.put("triangle", frame, row + 8, "C4", DRUM)


# Intro: the gongs come in one at a time, lowest first, as an ensemble gathers.
for bar in range(4):
    gongs(0, bar, range(min(bar + 1, 4)))
    if bar >= 2:
        wood_and_drum(0, bar, 7)

# Frames 1-2: the full ensemble, eight bars of the dance.
for frame in (1, 2):
    for bar in range(4):
        gongs(frame, bar, range(4))
        wood_and_drum(frame, bar, 9)

# Frames 3-4: the chant. The ensemble drops out but for the lowest gong, keeping time softly; a
# lead voice calls, gliding between its few notes, and a chorus answers.
CALLS = [
    [("A4", 4), ("A4", 2), ("G4", 2), ("A4", 6, "Q12"), ("B4", 2)],
    [("A4", 8, "303"), ("G4", 4), ("E4", 4, "300")],
    None, None,
    [("B4", 4), ("A4", 4), ("B4", 6, "303"), ("D5", 2)],
    [("B4", 8), ("A4", 4, "300"), ("G4", 4)],
    None, None,
]
ANSWERS = [
    None, None,
    [("G4", 4), ("A4", 4), ("G4", 4), ("E4", 4)],
    [("D4", 8), ("E4", 6), ("r", 2)],
    None, None,
    [("A4", 4), ("G4", 4), ("E4", 8)],
    [("D4", 8), ("E4", 6), ("r", 2)],
]


def sing(channel: str, inst: int, vol: int, frame: int, bar: int, notes) -> None:
    row = bar * BAR
    for item in notes:
        note, length = item[0], item[1]
        fx = item[2] if len(item) > 2 else None
        song.put(channel, frame, row, "===" if note == "r" else note,
                 None if note == "r" else inst, None if note == "r" else vol, fx)
        row += length
    # A breath at the end of the phrase.
    song.put(channel, frame, row - 1 if row % BAR == 0 else row, "===")


for index in range(8):
    frame, bar = 3 + index // 4, index % 4
    gongs(frame, bar, range(1), vol=11)
    song.put("triangle", frame, bar * BAR, "C4", DRUM)
    if CALLS[index]:
        sing("fm1", CHANTER, 13, frame, bar, CALLS[index])
    if ANSWERS[index]:
        sing("fm3", CHORUS, 11, frame, bar, ANSWERS[index])
        sing("fm4", CHORUS, 10, frame, bar, [(n[0] if n[0] == "r" else n[0][:-1] + str(int(n[0][-1]) - 1), n[1]) for n in ANSWERS[index]])

Path(sys.argv[2]).write_text(song.text())
print("wrote", sys.argv[2])
