"""Scaffolding: surviving the night, Dilim's finale (Kent, 2026-11-15: "as thrilling as possible
(make use of fearofdark still)").

The most energetic piece in the game, in the style Kent approved (compose_style_sketch.py) at its
fullest: ~164 BPM on lightly swung sixteenths, altered jazz changes in E minor (m9, maj7#11, 7b9,
7#9, m7b5, and an F7#11 tritone turn back home), a syncopated FM bass, chip-chord arpeggios,
offbeat stabs, slides and bends into the lead, a tom fill into every phrase. The hook is the
forest's motif (compose_dilim.py MOTIF: E, F, E, down to B) at speed. The tambol is the drum, as
everywhere in the game, and a gong opens each phrase of the last wave.

Three arrangements of the one piece, one per wave of the night (DilimFinale2D.WAVES), each fuller:
1. the drums, the bass and the motif;
2. and the clarinet's counter-line, the arpeggios and the stabs;
3. everything: the lead's echo, a gong opening each phrase, the stabs doubled.
⚠ NOT the lead an octave up, as first planned: there it filled the tik-tik's band (2.7 dB clear,
against 9.5 at pitch), in the wave the tik-tik flies in. And the lead is the bamboo flute, the
game's own voice since the title: the trumpet's partials filled that band even at pitch.
⚠ THE SAME LENGTH TO THE ROW (frames, rows, speeds), because a new wave trades them mid-bar
(AudioDirector.play_music keep_position). The night breaks off at dawn in a single frame.

⚠ The tik-tik is this night's creature, and its call is gameplay: nothing here may fill 4-8 kHz,
where it is strongest. tests/test_dilim_calls_read.py holds every arrangement to it.

Original.

    compose_dilim_night.py TOOLS_DIR WAVE1.txt WAVE2.txt WAVE3.txt
"""
import sys
from pathlib import Path

sys.path.insert(0, sys.argv[1])
from famitext import Song, transpose  # noqa: E402

BAR = 16                    # sixteenths
FRAME_BARS = 4
ROWS = BAR * FRAME_BARS
FRAMES = 5                  # 0 the night coming on, 1-4 the loop's sixteen bars
SWING = (6, 5)              # 22 ticks a beat: ~164 BPM, the sixteenths a little long-short
# ⚠ The VRC7 has ONE custom patch: the tambol.
TAMBOL = (0x01, 0x01, 0x18, 0x04, 0xF8, 0xF5, 0xF8, 0x36)

NOTES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def midi(note: str) -> int:
    return NOTES.index(note[:-1]) + 12 * (int(note[-1]) + 1)


def name(m: int) -> str:
    return f"{NOTES[m % 12]}{m // 12 - 1}"


# chord -> bass root (octave 2), the arpeggio's steps, the stab's shell (third and seventh, octave
# 4) and the counter-line's two guide tones.
CHORDS = {
    "Em9": ("E2", (0, 3, 7, 10, 14), ("G4", "D5"), ("G4", "F#4")),
    "Fmaj7#11": ("F2", (0, 4, 7, 11, 18), ("A4", "E5"), ("A4", "B4")),
    "B7b9": ("B1", (0, 4, 7, 10, 13), ("D#4", "A4"), ("A4", "C5")),
    "Cmaj7": ("C2", (0, 4, 7, 11, 14), ("E4", "B4"), ("B4", "G4")),
    "F#m7b5": ("F#2", (0, 3, 6, 10), ("A4", "E5"), ("A4", "C5")),
    "B7#9": ("B1", (0, 4, 7, 10, 15), ("D#4", "A4"), ("D5", "A4")),
    "Am9": ("A1", (0, 3, 7, 10, 14), ("C5", "G4"), ("C5", "B4")),
    "D9": ("D2", (0, 4, 7, 10, 14), ("F#4", "C5"), ("C5", "A4")),
    "Gmaj7": ("G1", (0, 4, 7, 11, 14), ("B4", "F#4"), ("B4", "F#4")),
    "C#m7b5": ("C#2", (0, 3, 6, 10), ("E4", "B4"), ("G4", "E4")),
    "F7#11": ("F2", (0, 4, 7, 10, 18), ("A4", "D#5"), ("A4", "B4")),
}
INTRO = ["Em9", "Em9", "Em9", "F7#11"]
LOOP = ["Em9", "Fmaj7#11", "Em9", "B7b9",
        "Cmaj7", "F#m7b5", "B7#9", "Em9",
        "Am9", "D9", "Gmaj7", "C#m7b5",
        "Cmaj7", "B7b9", "Em9", "F7#11"]

# The lead, bar by bar in sixteenths: (note, rows[, effect]). Qxy scoops up, Rxy falls off (a 0-row
# marker on the note before). The motif -- E F E, down to B -- opens bars 1, 3 and 15.
TUNE = [
    [("E5", 2), ("F5", 2), ("E5", 2), ("B4", 4), ("D5", 2), ("E5", 2), ("G5", 2)],
    [("G5", 6, "Q32"), ("G5", 2), ("F5", 2), ("E5", 2), ("C5", 4)],
    [("E5", 2), ("F5", 2), ("E5", 2), ("B4", 4), ("D5", 2), ("G5", 2), ("B5", 2)],
    [("G5", 4, "Q32"), ("F#5", 2), ("D#5", 2), ("C5", 4), ("B4", 4), ("B4", 0, "R83")],
    [("E5", 2), ("G5", 2), ("A5", 4, "Q32"), ("A5", 2), ("G5", 2), ("E5", 4)],
    [("F#5", 2), ("A5", 2), ("C6", 6), ("A5", 2), ("F#5", 4)],
    [("D6", 4), ("B5", 2), ("A5", 2), ("F#5", 4), ("D#5", 4)],
    [("E5", 8), ("r", 4), ("B4", 2), ("D5", 2)],
    [("A5", 2), ("C6", 2), ("A5", 4, "Q32"), ("G5", 2), ("E5", 2), ("A5", 4)],
    [("F#5", 2), ("A5", 2), ("C6", 4), ("A5", 2), ("F#5", 2), ("E5", 4)],
    [("D5", 2), ("G5", 2), ("B5", 4), ("A5", 2), ("F#5", 2), ("D5", 4)],
    [("E5", 2), ("G5", 2), ("B5", 6), ("A5", 2), ("G5", 4)],
    [("G5", 2), ("E5", 2), ("B5", 4), ("C6", 4), ("B5", 2), ("G5", 2)],
    [("A5", 4), ("F#5", 2), ("D#5", 2), ("C6", 4), ("B5", 4)],
    [("E5", 2), ("F5", 2), ("E5", 2), ("B4", 4), ("E5", 2), ("F5", 2), ("G5", 2)],
    [("A5", 8), ("F5", 2), ("D#5", 2), ("C5", 2), ("B4", 2)],
]
# The night coming on: the motif low and alone, then answered.
TEASER = [[("r", 16)], [("E4", 2), ("F4", 2), ("E4", 2), ("B3", 6), ("r", 4)],
          [("r", 16)], [("E4", 2), ("F4", 2), ("E4", 2), ("B3", 2), ("D4", 2), ("E4", 2), ("F4", 4)]]
for bar in TUNE + TEASER:
    assert sum(n[1] for n in bar) == BAR, f"a bar of the tune is not {BAR} rows: {bar}"

# The bass's syncopation across a bar: (row, semitones over the root). The flat second (1) pulls.
BASS = [(0, 0), (3, 0), (6, 12), (8, 0), (10, 0), (11, 1), (14, 7)]
KICK = (0, 6, 10)
SNARE = (4, 12)
GHOST = (7, 15)
FILL = ["D3", "D3", "C3", "C3", "A2", "A2", "G2", "E2"]
STABS = (3, 6, 11)
STABS_FULL = (3, 6, 9, 11, 14)


def arrangement(wave: int) -> str:
    s = Song(f"Dilim night {wave}", frames=FRAMES, rows=ROWS, speed=SWING[0], loop_to=1, comments=(
        f"Surviving Dilim's night, wave {wave} of 3: the forest's motif at speed over altered changes,",
        "a syncopated bass and the tambol; each wave fuller. Original. E minor, ~164 BPM.",
    ))
    s.swing(*SWING)
    boom = s.inst_vrc7("tambol", patch=0, regs=TAMBOL)
    bass = s.inst_vrc7("bass", patch=13)
    lead = s.inst_vrc7("bamboo flute", patch=4)
    counter = s.inst_vrc7("clarinet", patch=5)
    stab = s.inst_vrc7("stab", patch=3)
    gong = s.inst_vrc7("gong", patch=9)
    arps = {steps: s.inst_2a03(f"arp {i}", volume=[4, 4, 3, 3, 3, 2, 2, 2], arpeggio=list(steps), duty=[2])
            for i, steps in enumerate(sorted({c[1] for c in CHORDS.values()}))}
    echo = s.inst_2a03("echo", volume=[2, 2, 2, 2, 2, 1, 1, 1, 0], duty=[2])
    snare = s.inst_2a03("snare", volume=[12, 9, 7, 5, 3, 2, 1, 0], duty=[0])
    ghost = s.inst_2a03("ghost", volume=[5, 3, 2, 1, 0], duty=[0])

    def bars(sequence, first: int):
        for index, chord in enumerate(sequence):
            yield index, first + index // FRAME_BARS, (index % FRAME_BARS) * BAR, chord

    def drums(frame: int, row: int, *, filled: bool) -> None:
        for step in KICK:
            s.put("fm6", frame, row + step, "A2", boom, 15 if step == 0 else 13)
        for step in SNARE:
            s.put("noise", frame, row + step, "5-#", snare, 9)
        for step in GHOST:
            s.put("noise", frame, row + step, "6-#", ghost, 7)
        if filled:
            # The tambol walking down into the next phrase, from beat three.
            for i, note in enumerate(FILL):
                s.put("fm6", frame, row + 8 + i, note, boom, 12 + i // 3)

    def bassline(frame: int, row: int, chord: str, vol: int = 12) -> None:
        root = midi(CHORDS[chord][0])
        for step, semis in BASS:
            s.put("fm5", frame, row + step, name(root + semis), bass, vol if step % 4 == 0 else vol - 1,
                  "S04" if step in (3, 6) else None)

    def line(channel: str, inst: int, vol: int, bars_of, first: int, *, shift: int = 0,
             echo_too: bool = False) -> None:
        vib = False
        for index, notes in enumerate(bars_of):
            frame, row = first + index // FRAME_BARS, (index % FRAME_BARS) * BAR
            for item in notes:
                note, length = item[0], item[1]
                fx = item[2] if len(item) > 2 else None
                if length == 0:
                    s.put(channel, frame, row - 1, fx=fx)
                    continue
                if note == "r":
                    s.put(channel, frame, row, "===", fx="400" if vib else None)
                    vib = False
                else:
                    if fx is None and vib:
                        fx, vib = "400", False
                    vib = vib or fx == "4A4"
                    s.put(channel, frame, row, transpose(note, shift), inst, vol, fx)
                    if echo_too:
                        s.put("pulse2", frame, row + 2, transpose(note, shift), echo, 15)
                    # ⚠ NO LATE VIBRATO on the long notes. famirender applies 4xy in pulse-period units, which on a
                    # VRC7 note near A5 swings about half a semitone: Kent heard it in Mayon's take 1 as "a voice
                    # crack". The scoops and fall-offs stay: they are the style he approved.
                row += length

    # Frame 0: the night coming on. A pedal on E in the bass, the kick on the beats, the motif low.
    for index, frame, row, chord in bars(INTRO, 0):
        for step in range(0, BAR, 2 if index < 2 else 1):
            s.put("fm5", frame, row + step, "E2" if chord == "Em9" else "F2", bass, 9 + index)
        for beat in range(4):
            s.put("fm6", frame, row + 4 * beat, "A2", boom, 12 + index)
        if index == 3:
            drums(frame, row, filled=True)
    line("fm1", lead, 14, TEASER, 0)

    # Frames 1-4: the night.
    for index, frame, row, chord in bars(LOOP, 1):
        drums(frame, row, filled=index % 4 == 3)
        bassline(frame, row, chord)
        _, steps, shell, guides = CHORDS[chord]
        if wave >= 2:
            s.put("pulse1", frame, row, name(midi(CHORDS[chord][0]) + 24), arps[steps], 15, "V02")
            for step in (STABS_FULL if wave >= 3 else STABS):
                for channel, note in zip(("fm3", "fm4"), shell):
                    s.put(channel, frame, row + step, note, stab, 9)
                    s.put(channel, frame, row + step + 1, "===")
            for half, guide in enumerate(guides):
                s.put("fm2", frame, row + 8 * half, guide, counter, 11, "302" if half else "300")
        if wave >= 3 and index % 4 == 0:
            s.put("fm3", frame, row, CHORDS[chord][0][:-1] + "3", gong, 12)
            s.put("fm3", frame, row + 3, "===")
    line("fm1", lead, 14, TUNE, 1, echo_too=wave >= 3)

    text = s.text()
    lines = []
    for text_line in text.splitlines():
        parts = text_line.split()
        if text_line.startswith("MACRO 1 ") and int(parts[2]) < len(arps):   # the chords cycle
            parts[3] = "0"
            text_line = " ".join(parts)
        lines.append(text_line)
    return "\n".join(lines)


for wave, path in enumerate(sys.argv[2:5], start=1):
    Path(path).write_text(arrangement(wave))
print("wrote", *sys.argv[2:5])
