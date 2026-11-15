"""Scaffolding: Lola's house as a kundiman for rondalla (Kent, 2026-11-15: "more on the Philippine
cultural side"). From what the sources describe: the bandurria carries the tune in a sustained,
sparkling tremolo, cantabile and stepwise; the octavina and laud add counter-melodies and inner
harmony; the guitar holds the chords; a kundiman is in 3/4 and turns from a minor verse to its
parallel major. Original throughout; a scoop at the peaks keeps a touch of the new style.

    compose_house.py TOOLS_DIR OUT.txt
"""
import sys
from pathlib import Path

sys.path.insert(0, sys.argv[1])
from famitext import Song, transpose  # noqa: E402

BEAT = 8                          # thirty-seconds: the tremolo's strokes
BAR = 3 * BEAT                    # 3/4
song = Song("Lola's house", frames=5, rows=96, speed=5, loop_to=1, comments=(
    "Lola's house: a kundiman for rondalla. Bandurria tremolo over octavina, laud and guitar;",
    "E minor turning to E major. Original; ~90 BPM. No drums, no thin pulses, no bright noise.",
))

BANDURRIA = song.inst_vrc7("bandurria", patch=2)
OCTAVINA = song.inst_vrc7("octavina", patch=2)
LAUD = song.inst_vrc7("laud", patch=2)
GUITAR = song.inst_vrc7("guitar", patch=2)
BASS = song.inst_2a03("bass", volume=[15] * 14 + [0])
ARP = {kind: song.inst_2a03(f"{kind} sparkle", volume=[3, 3, 3, 2, 2, 2, 1], arpeggio=steps, duty=[2])
       for kind, steps in {"m": [0, 3, 7, 12], "M": [0, 4, 7, 12], "7": [0, 4, 7, 10]}.items()}

# chord -> (arp kind, arp root, guitar pair, laud broken chord, bass)
CHORDS = {
    "Em": ("m", "E4", ("G4", "B4"), ("E3", "B3", "G4"), "E3"),
    "Am": ("m", "A4", ("C5", "E5"), ("A2", "E3", "C4"), "A3"),
    "B7": ("7", "B3", ("D#4", "A4"), ("B2", "F#3", "D#4"), "B2"),
    "C": ("M", "C4", ("E4", "G4"), ("C3", "G3", "E4"), "C3"),
    "E": ("M", "E4", ("G#4", "B4"), ("E3", "B3", "G#4"), "E3"),
    "A": ("M", "A4", ("C#5", "E5"), ("A2", "E3", "C#4"), "A3"),
    "C#m": ("m", "C#4", ("E4", "G#4"), ("C#3", "G#3", "E4"), "C#3"),
    "F#m": ("m", "F#4", ("A4", "C#5"), ("F#2", "C#3", "A3"), "F#3"),
}
INTRO = ["Em", "Am", "B7", "Em"]
LOOP = ["Em", "Am", "B7", "Em", "C", "Am", "B7", "B7",       # the minor verse
        "E", "A", "B7", "E", "C#m", "F#m", "B7", "E"]         # ...and its parallel major

# The tune, in beats: (note, beats[, effect]). Stepwise, arching; a scoop (a step below, Q22)
# at each phrase's peak.
TUNE = [
    [("B4", 1), ("E5", 1), ("F#5", 1)], [("G5", 2), ("A5", 1)], [("F#5", 2), ("D#5", 1)], [("E5", 3)],
    [("G5", 1), ("A5", 1), ("B5", 1)], [("A5", 2, "Q22"), ("B5", 1)], [("A5", 1), ("G5", 1), ("F#5", 1)], [("D#5", 2), ("B4", 1)],
    [("B4", 1), ("E5", 1), ("G#5", 1)], [("A5", 2), ("C#6", 1)], [("B5", 2), ("A5", 1)], [("G#5", 3)],
    [("E5", 1), ("G#5", 1), ("C#6", 1)], [("A5", 2, "Q22"), ("A5", 1)], [("F#5", 1), ("A5", 1), ("D#5", 1)], [("E5", 3)],
]
# The octavina, a third or sixth under the tune, in the second half of each verse.
COUNTER = {
    4: [("E5", 1), ("F#5", 1), ("G5", 1)], 5: [("E5", 2), ("G5", 1)], 6: [("F#5", 1), ("E5", 1), ("D#5", 1)], 7: [("B4", 3)],
    12: [("C#5", 1), ("E5", 1), ("A5", 1)], 13: [("F#5", 3)], 14: [("D#5", 1), ("F#5", 1), ("B4", 1)], 15: [("G#4", 3)],
}


def bar_at(first: int, index: int) -> tuple[int, int]:
    return first + index // 4, (index % 4) * BAR


def tremolo(channel: str, inst: int, vol: int, frame: int, row: int, bars) -> None:
    """Each note as the bandurria plays it held: a stroke on every thirty-second."""
    for item in bars:
        note, beats = item[0], item[1]
        fx = item[2] if len(item) > 2 else None
        # ⚠ Every stroke strikes its note again, which ends a slide: so after a scoop the strokes
        # play the note it arrives at, or the scoop would snap back on the second stroke.
        arrival = transpose(note, int(fx[2], 16)) if fx and fx[0] == "Q" else note
        for stroke in range(beats * BEAT):
            # Strokes alternate a shade in weight, as down- and up-strokes do.
            song.put(channel, frame, row + stroke, note if stroke == 0 else arrival, inst,
                     vol if stroke % 2 == 0 else vol - 1, fx if stroke == 0 else None)
        row += beats * BEAT


def accompany(chords, first: int) -> None:
    for index, chord in enumerate(chords):
        frame, row = bar_at(first, index)
        kind, arp_root, pair, laud, bass = CHORDS[chord]
        song.put("pulse1", frame, row, arp_root, ARP[kind], 15, "V02" if index == 0 else None)
        song.put("triangle", frame, row, bass, BASS)
        # The laud: a broken chord in eighths, as the harana guitar would.
        for step, note in enumerate([laud[0], laud[1], laud[2], laud[1], laud[2], laud[1]]):
            song.put("fm5", frame, row + step * (BEAT // 2) * 1, note, LAUD, 11 if step == 0 else 10)
        # The guitar: the chord on two and three, short.
        for beat in (1, 2):
            for channel, note in zip(("fm3", "fm4"), pair):
                song.put(channel, frame, row + beat * BEAT, note, GUITAR, 11)
                song.put(channel, frame, row + beat * BEAT + 3, "===")


accompany(INTRO, 0)
accompany(LOOP, 1)
for index, bar in enumerate(TUNE):
    frame, row = bar_at(1, index)
    tremolo("fm1", BANDURRIA, 13, frame, row, bar)
for index, bar in COUNTER.items():
    frame, row = bar_at(1, index)
    tremolo("fm2", OCTAVINA, 11, frame, row, [(n[0][:-1] + str(int(n[0][-1]) - 1),) + n[1:] for n in bar])
# A breath before the loop comes round to the minor verse again.
song.put("fm1", 4, 95, "===")

text = song.text()
lines = []
for line in text.splitlines():
    parts = line.split()
    if line.startswith("MACRO 1 ") and int(parts[2]) < len(ARP):   # the sparkle cycles
        parts[3] = "0"
        line = " ".join(parts)
    lines.append(line)
Path(sys.argv[2]).write_text("\n".join(lines))
print("wrote", sys.argv[2])
