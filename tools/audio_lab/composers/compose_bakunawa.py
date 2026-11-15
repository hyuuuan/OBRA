"""Scaffolding: the Bakunawa (Kent, 2026-11-15: "an appropriate water-vibe boss fight music").

Dagat's own tune turned minor and driving: its opening (compose_dagat.py TUNE, bars 1-2: up the
chord to a scooped seventh, then down the scale) in G minor, over a rolling 12/8 so it still moves
like water, ~139 BPM to the dotted quarter. In the Visayan tale the Bakunawa rises to swallow the
moon and the people drive it back by beating gongs and pots, so the agong and the pots' clang are
in the band, as Piyesta's gongs were in its: a gong on every downbeat, the pots on the offbeats,
and a break of drums and gongs alone before the turnaround. A low FM bass ostinato rolls under it
all, the tambol (Piyesta's custom patch) kicks and fills, and the storm is dark noise.

The style Kent approved on top (compose_style_sketch.py): altered changes (m9, maj7, m7b5, 7#9,
7b9), syncopated trumpet stabs that answer the gongs, scoops into the long notes and a fall off
the phrase ends, a second trumpet a third under, an echo pulse, and a brass shake into the loop.

Original. It plays from the moment the creature is met until it is answered, on every route.

    compose_bakunawa.py TOOLS_DIR OUT.txt
"""
import sys
from pathlib import Path

sys.path.insert(0, sys.argv[1])
from famitext import Song  # noqa: E402

BAR = 12                    # 12/8 in eighths
FRAME_BARS = 4
ROWS = BAR * FRAME_BARS
FRAMES = 5                  # 0 the rising, 1-4 the loop's sixteen bars
# Three eighths in 9 + 8 + 9 = 26 ticks: ~139 BPM to the dotted quarter.
BEAT_SPEEDS = (9, 8, 9)
# ⚠ The VRC7 has ONE custom patch: the tambol, as in Piyesta. Nothing else may use one.
TAMBOL = (0x01, 0x01, 0x18, 0x04, 0xF8, 0xF5, 0xF8, 0x36)

NOTES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def midi(note: str) -> int:
    return NOTES.index(note[:-1]) + 12 * (int(note[-1]) + 1)


def name(m: int) -> str:
    return f"{NOTES[m % 12]}{m // 12 - 1}"


# chord -> root (octave 2, the bass), its third (3 minor, 4 major), its fifth, and the scale the
# second trumpet counts its third in.
G_MINOR = (7, 9, 10, 0, 2, 3, 5)
G_HARMONIC = (7, 9, 10, 0, 2, 3, 6)
CHORDS = {
    "Gm9": ("G2", 3, 7, G_MINOR, "m7"), "Ebmaj7": ("D#2", 4, 7, G_MINOR, "maj7"),
    "Cm9": ("C3", 3, 7, G_MINOR, "m7"), "D7#9": ("D2", 4, 7, G_HARMONIC, "7"),
    "Am7b5": ("A2", 3, 6, G_MINOR, "m7b5"), "D7b9": ("D2", 4, 7, G_HARMONIC, "7"),
    "F7": ("F2", 4, 7, (5, 7, 9, 10, 0, 2, 3), "7"), "Bbmaj7": ("A#2", 4, 7, G_MINOR, "maj7"),
}
INTRO = ["Gm9", "Gm9", "Gm9", "D7#9"]
LOOP = ["Gm9", "Ebmaj7", "Cm9", "D7#9",
        "Gm9", "Ebmaj7", "Am7b5", "D7b9",
        "Cm9", "F7", "Bbmaj7", "Ebmaj7",
        "Am7b5", "D7b9", "Gm9", "D7#9"]
GONG_BREAK = 14             # the loop's bar 15: drums and gongs alone, driving it back
HARMONISED = {4, 5, 6, 7, 12, 13, 15}

# The trumpet, bar by bar in eighths: (note, rows[, effect]); a 0-row marker puts its effect on the
# previous note's last row. Qxy scoops up y semitones; Rxy falls off; 4xy is the shake.
TUNE = [
    [("A#4", 2), ("D5", 1), ("D#5", 3, "Q32"), ("G5", 2), ("F5", 1), ("D5", 3)],
    [("D#5", 2), ("D5", 1), ("A#4", 3), ("G4", 2), ("A#4", 1), ("C5", 3, "Q32")],
    [("F5", 3, "Q32"), ("A#5", 2), ("A5", 1), ("G5", 3), ("D#5", 2), ("D5", 1)],
    [("F#5", 2), ("A5", 1), ("C6", 3), ("F5", 2), ("F#5", 1), ("D5", 3), ("D5", 0, "R43")],
    [("A#4", 2), ("D5", 1), ("D#5", 3, "Q32"), ("A#5", 2), ("A5", 1), ("G5", 3)],
    [("A#5", 2), ("G5", 1), ("D#5", 3), ("D5", 2), ("D#5", 1), ("F5", 3)],
    [("G5", 2), ("A5", 1), ("C6", 3), ("A#5", 2), ("A5", 1), ("G5", 3)],
    [("F#5", 2), ("G5", 1), ("A5", 3), ("D#5", 2), ("D5", 1), ("C5", 2), ("D5", 1)],
    # The storm: the trumpets call in the first half of the bar, the gongs and pots answer.
    [("G5", 1), ("A#5", 1), ("C6", 2), ("A#5", 1), ("G5", 1), ("r", 6)],
    [("F5", 1), ("A5", 1), ("C6", 2), ("A5", 1), ("F5", 1), ("r", 6)],
    [("D5", 1), ("F5", 1), ("A5", 2), ("A#5", 2), ("r", 6)],
    [("F5", 6, "Q32"), ("D5", 3), ("D#5", 3)],
    [("C6", 3), ("A5", 1), ("G5", 2), ("D#5", 3), ("D5", 3)],
    [("F#5", 2), ("A5", 1), ("C6", 3), ("A5", 3), ("A5", 0, "R83"), ("r", 3)],
    [("r", 12)],
    [("D5", 1), ("F#5", 1), ("A5", 1), ("C6", 9, "4A4")],
]
PICKUP = [("r", 6), ("D4", 2), ("G4", 1), ("C5", 3, "Q32")]
for bar in TUNE + [PICKUP]:
    assert sum(n[1] for n in bar) == BAR, f"a bar of the tune is not {BAR} rows: {bar}"


def third_below(note: str, scale) -> str:
    m, found = midi(note), 0
    while found < 2:
        m -= 1
        found += (m % 12) in scale
    return name(m)


song = Song("Bakunawa", frames=FRAMES, rows=ROWS, speed=BEAT_SPEEDS[0], loop_to=1, comments=(
    "The Bakunawa: Dagat's tune turned minor over a rolling 12/8, agong and pots beaten to drive",
    "it back, a low bass ostinato, the tambol, two trumpets. Original. G minor, ~139 BPM.",
))
for frame in range(FRAMES):
    for row in range(ROWS):
        song._set(frame, row, "dpcm", 3, f"F{BEAT_SPEEDS[row % 3]:02X}")

TRUMPET = song.inst_vrc7("trumpet", patch=7)
SECOND = song.inst_vrc7("second trumpet", patch=7)
BASS = song.inst_vrc7("bass", patch=13)
# The soft bell: the darkest of the bells, struck low it is the agong; high and cut at once, a pot.
AGONG = song.inst_vrc7("agong", patch=9)
POT = song.inst_vrc7("pot", patch=9)
BOOM = song.inst_vrc7("tambol", patch=0, regs=TAMBOL)
SHIMMER = {kind: song.inst_2a03(f"{kind} arp", volume=[5, 5, 4, 4, 4, 3, 3, 3, 3, 2], arpeggio=steps,
                                duty=[1])
           for kind, steps in {"m7": [0, 3, 7, 10], "maj7": [0, 4, 7, 11], "7": [0, 4, 7, 10],
                               "m7b5": [0, 3, 6, 10]}.items()}
ECHO = song.inst_2a03("echo", volume=[5, 5, 4, 4, 3, 3, 2, 2, 1, 1, 0], duty=[2])
SNARE = song.inst_2a03("snare", volume=[13, 10, 8, 6, 4, 3, 2, 1, 0], duty=[0])
GHOST = song.inst_2a03("ghost", volume=[6, 4, 3, 2, 1, 0], duty=[0])
RAIN = song.inst_2a03("rain", volume=[3, 2, 1, 1, 0], duty=[0])
THUNDER = song.inst_2a03("thunder", volume=[9, 10, 11, 11, 10, 10, 9, 9, 9, 8, 8, 8, 7, 7, 7, 7, 6, 6, 6,
                                            6, 5, 5, 5, 5, 5, 4, 4, 4, 4, 4, 3, 3, 3, 3, 3, 3, 2, 2, 2,
                                            2, 2, 2, 1, 1, 1, 1, 1, 1, 0], duty=[0])
ARP_COUNT = len(SHIMMER)


def bars(sequence, first: int):
    for index, chord in enumerate(sequence):
        yield index, first + index // FRAME_BARS, (index % FRAME_BARS) * BAR, chord


# The bass's roll across the bar: root, root, fifth | root . root | octave, fifth, third.
def ostinato(frame: int, row: int, chord: str, vol: int = 12) -> None:
    root, third, fifth, _, _ = CHORDS[chord]
    r = midi(root)
    for step, interval in ((0, 0), (2, 0), (3, fifth), (5, 0), (6, 0), (8, 0), (9, 12), (10, fifth),
                           (11, third)):
        song.put("fm5", frame, row + step, name(r + interval), BASS, vol if step % 3 == 0 else vol - 1)


def kicks(frame: int, row: int) -> None:
    for step in (0, 5, 6):
        song.put("fm6", frame, row + step, "A2", BOOM, 15 if step != 5 else 12,
                 "S03" if step == 5 else None)


# The tambol walking down into the next phrase, the snare climbing under it.
FILL = ["D3", "D3", "C3", "A2", "A2", "G2"]


def fill(frame: int, row: int) -> None:
    for i, note in enumerate(FILL):
        song.put("fm6", frame, row + 6 + i, note, BOOM, 12 + i // 2)
        song.put("noise", frame, row + 6 + i, "5-#", SNARE, 7 + i)


def storm(frame: int, row: int, *, rain: bool = True) -> None:
    for step in range(BAR):
        if step in (3, 9):
            song.put("noise", frame, row + step, "5-#", SNARE, 12)
        elif step in (8, 11):
            song.put("noise", frame, row + step, "6-#", GHOST, 10)
        elif rain:
            song.put("noise", frame, row + step, "7-#", RAIN, 6 if step % 3 == 0 else 4)


def agong(frame: int, row: int, chord: str, vol: int = 12, ring: int = 6) -> None:
    song.put("fm3", frame, row, CHORDS[chord][0], AGONG, vol)
    song.put("fm3", frame, row + ring, "===")


# The pots: beaten on the offbeats, cut at once so they clank rather than ring.
def pots(frame: int, row: int, steps=(4, 10), vol: int = 9) -> None:
    for step in steps:
        song.put("fm4", frame, row + step, "A5" if step % 2 == 0 else "D#5", POT, vol)
        song.put("fm4", frame, row + step + 1, "===")


def shimmer(frame: int, row: int, chord: str) -> None:
    root = name(midi(CHORDS[chord][0]) + 24)
    song.put("pulse1", frame, row, root, SHIMMER[CHORDS[chord][4]], 15, "V01")


def trumpets(bars_of, first: int, start_bar: int = 0) -> None:
    vib_on = False
    for offset, notes in enumerate(bars_of):
        index = start_bar + offset
        frame, row = first + index // FRAME_BARS, (index % FRAME_BARS) * BAR
        chord = (LOOP if first else INTRO)[index]
        for item in notes:
            note, length = item[0], item[1]
            fx = item[2] if len(item) > 2 else None
            if length == 0:
                song.put("fm1", frame, row - 1, fx=fx)
                continue
            if note == "r":
                song.put("fm1", frame, row, "===", fx="400" if vib_on else None)
                if first and index in HARMONISED:
                    song.put("fm2", frame, row, "===")
                vib_on = False
            else:
                if fx is None and vib_on:
                    fx, vib_on = "400", False
                if fx == "4A4":
                    vib_on = True
                song.put("fm1", frame, row, note, TRUMPET, 13, fx)
                song.put("pulse2", frame, row + 1, note, ECHO, 15)
                if first and index in HARMONISED:
                    song.put("fm2", frame, row, third_below(note, CHORDS[chord][3]), SECOND, 11,
                             fx if fx and fx[0] in "QR" else None)
                # ⚠ NO LATE VIBRATO on the long notes. famirender applies 4xy in pulse-period units, which on a
                # VRC7 note near A5 swings about half a semitone: Kent heard it in Mayon's take 1 as "a voice
                # crack". The scoops, fall-offs and the brass shake (Piyesta's) stay: they are the style he approved.
            row += length


# Frame 0, the creature rising: a gong and thunder, the bass rolling in, then the drums, the storm
# and a roll into the tune.
for index, frame, row, chord in bars(INTRO, 0):
    ostinato(frame, row, chord, 10 + index)
    if index == 0:
        agong(frame, row, chord, 14, ring=12)
        song.put("noise", frame, row, "1-#", THUNDER, 15)
        continue
    agong(frame, row, chord, 11)
    kicks(frame, row)
    if index >= 2:
        storm(frame, row)
        shimmer(frame, row, chord)
    if index == 3:
        fill(frame, row)
trumpets([PICKUP], 0, 3)

# Frames 1-4: the fight.
for index, frame, row, chord in bars(LOOP, 1):
    ostinato(frame, row, chord)
    if index == GONG_BREAK:
        # Drums and gongs alone: a gong on every dotted quarter, the pots on every offbeat.
        song.put("noise", frame, row, "1-#", THUNDER, 13)
        for step in (0, 3, 6, 9):
            agong(frame, row + step, chord, 13 if step % 6 == 0 else 11, ring=2)
        pots(frame, row, (1, 2, 4, 5, 7, 8, 10, 11), 8)
        for step, note in ((0, "A2"), (2, "D3"), (3, "C3"), (5, "A2"), (6, "A2"), (8, "D3"), (9, "C3"),
                           (11, "G2")):
            song.put("fm6", frame, row + step, note, BOOM, 14 if step % 3 == 0 else 12)
        continue
    agong(frame, row, chord)
    kicks(frame, row)
    storm(frame, row)
    if 8 <= index < 12:
        pots(frame, row, (6, 7, 9, 10), 9)        # the answer to each call
    else:
        pots(frame, row)
    shimmer(frame, row, chord)
    if index % 4 == 3:
        fill(frame, row)
trumpets(TUNE, 1)

text = song.text()
lines = []
for line in text.splitlines():
    parts = line.split()
    if line.startswith("MACRO 1 ") and int(parts[2]) < ARP_COUNT:   # the chords cycle while held
        parts[3] = "0"
        line = " ".join(parts)
    lines.append(line)
Path(sys.argv[2]).write_text("\n".join(lines))
print("wrote", sys.argv[2])
