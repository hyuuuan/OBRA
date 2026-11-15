"""Write Dilim's forest theme, race music, and forest ambience.

    compose_dilim.py TOOLS_DIR FOREST.txt RACE.txt AMBIENCE.txt

The forest theme pairs 2A03 square and triangle with VRC7 keys. The race
keeps the original Phrygian gallop and the ambience supplies low frog calls.
tests/test_dilim_calls_read.py checks that the music and ambience leave room
for the tik-tik's call and tiyanak's cry.
"""
import random
import sys
from pathlib import Path

sys.path.insert(0, sys.argv[1])
from famitext import Song, transpose  # noqa: E402

# ⚠ The VRC7 has ONE custom patch; the race's is the tambol, as in Piyesta and the Bakunawa.
TAMBOL = (0x01, 0x01, 0x18, 0x04, 0xF8, 0xF5, 0xF8, 0x36)

# The motif, the forest's and the night's hook: E, F (a minor second up), E, and down to B.
MOTIF = [("E3", 1), ("F3", 3), ("E3", 1), ("B2", 1)]


# --- the forest --------------------------------------------------------------------------------

def forest() -> Song:
    bar = 16
    s = Song("Dilim - Under Makiling's Moon", frames=6, rows=4 * bar, speed=11, comments=(
        "Original night exploration theme for Dilim, E minor, around 90 BPM.",
        "2A03 square lead and triangle bass with soft VRC7 keys and vibraphone.",
    ))
    s.swing(11, 9)
    lead = s.inst_2a03("Square lead", volume=[13, 12, 11, 10, 9, 8, 8, 7, 7, 6, 6, 5],
                        duty=[2])
    bass = s.inst_2a03("Triangle bass", volume=[15] * 13 + [0])
    keys = s.inst_vrc7("FM keys", patch=3)
    bell = s.inst_vrc7("FM vibraphone", patch=11)

    # Bass root and fifth, then three closely voiced FM notes.
    chords = {
        "Em9":     ("E3",  "B3", ("G3",  "D4", "F#4")),
        "Cmaj7":   ("C3",  "G3", ("G3",  "B3", "E4")),
        "Gmaj7/B": ("B3",  "G3", ("F#3", "D4", "G4")),
        "Gmaj7":   ("G3",  "D4", ("F#3", "B3", "D4")),
        "D6/A":    ("A3",  "D3", ("F#3", "B3", "D4")),
        "Am9":     ("A3",  "E3", ("C3",  "G3", "B3")),
        "Dadd9":   ("D3",  "A3", ("F#3", "A3", "E4")),
        "Bm7":     ("B3",  "F#3", ("F#3", "A3", "D4")),
    }
    verse = ("Em9", "Cmaj7", "Gmaj7/B", "D6/A", "Em9", "Am9", "Cmaj7")
    clearing = ("Gmaj7", "Cmaj7", "D6/A", "Em9", "Am9", "Cmaj7", "Dadd9", "Bm7")
    progression = (*verse, "Dadd9", *clearing, *verse, "Em9")

    # (sixteenth, pitch, duration). The phrase is a quiet pickup, a held note, then an answer.
    hook = (
        ((2, "B3", 2), (4, "E4", 3), (7, "G4", 6), (14, "F#4", 2)),
        ((0, "E4", 4), (6, "G4", 2), (9, "E4", 4)),
        ((1, "D4", 2), (3, "E4", 3), (6, "G4", 6), (14, "A4", 2)),
        ((0, "F#4", 5), (8, "E4", 3), (12, "D4", 2)),
        ((2, "E4", 2), (4, "G4", 3), (7, "B4", 6), (14, "A4", 2)),
        ((0, "G4", 5), (7, "E4", 3), (12, "A4", 3)),
        ((0, "B4", 4), (6, "G4", 3), (10, "E4", 3)),
    )
    answer = (
        ((0, "B4", 6), (10, "D5", 3)),
        ((0, "B4", 3), (6, "G4", 6)),
        ((1, "A4", 2), (4, "F#4", 3), (9, "D4", 4)),
        ((0, "E4", 6), (9, "G4", 4)),
        ((1, "E4", 2), (4, "G4", 3), (8, "A4", 5)),
        ((0, "G4", 6), (9, "E4", 3)),
        ((0, "F#4", 4), (6, "A4", 3), (12, "F#4", 3)),
        ((0, "D4", 6), (9, "F#4", 4)),
    )
    melody = (
        *hook, ((0, "F#4", 5), (8, "E4", 2), (12, "D4", 3)),
        *answer,
        *hook, ((1, "F#4", 3), (6, "E4", 7)),
    )
    bell_answers = {1: (14, "B3"), 3: (14, "A3"), 7: (11, "A3"), 11: (14, "B3"),
                    13: (13, "B3"), 15: (14, "A3"), 23: (14, "B3")}

    for index, (chord, phrase) in enumerate(zip(progression, melody, strict=True)):
        frame, start = s.at(0, index * bar)
        root, fifth, upper = chords[chord]
        s.put("triangle", frame, start, root, bass)
        if index % 4 == 3 or 8 <= index < 12:
            s.put("triangle", frame, start + 10, fifth, bass)
        else:
            s.put("triangle", frame, start + (7 if index % 2 == 0 else 6), fifth, bass)
            s.put("triangle", frame, start + (12 if index % 2 == 0 else 11), root, bass)

        hits = ((0, 8, 10),) if 8 <= index < 12 else ((0, 6, 10), (9, 5, 9))
        for step, duration, volume in hits:
            for channel, pitch in zip(("fm1", "fm2", "fm3"), upper, strict=True):
                s.put(channel, frame, start + step, pitch, keys, volume)
                s.put(channel, frame, start + step + duration, "===")

        if index in bell_answers:
            step, pitch = bell_answers[index]
            s.put("fm4", frame, start + step, pitch, bell, 10)
            s.put("fm4", frame, start + step + 2, "===")

        for step, pitch, duration in phrase:
            volume = 9 if pitch in ("E4", "D5") else 12
            s.put("pulse1", frame, start + step, pitch, lead, volume)
            s.put("pulse1", frame, start + step + duration, "---")
    return s


def race() -> Song:
    bar = 12                                  # triplet eighths: three to a beat
    speeds = (8, 7, 8)                        # 23 ticks a beat, ~157 BPM
    s = Song("Dilim race", frames=4, rows=4 * bar, speed=speeds[0], loop_to=0, comments=(
        "The tikbalang's race: Dilim's motif galloping in triplets, the tambol's hooves, a driving",
        "bass, low brass, climbing a whole tone every four bars. Under 500 Hz. Original. ~157 BPM.",
    ))
    for frame in range(4):
        for row in range(4 * bar):
            s._set(frame, row, "dpcm", 3, f"F{speeds[row % 3]:02X}")
    boom = s.inst_vrc7("tambol", patch=0, regs=TAMBOL)
    bass = s.inst_vrc7("bass", patch=13)
    # ⚠ The motif is on the clarinet, not the trumpet: the trumpet's upper partials filled the
    # tiyanak's band (500 Hz-1 kHz) to within 4 dB of her cry.
    brass = s.inst_vrc7("low reed", patch=5)
    horn = s.inst_vrc7("low horn", patch=5)
    gong = s.inst_vrc7("gong", patch=9)

    # Every four bars a whole tone higher -- E, F#, G#, A# -- and the top never arrives.
    for index in range(16):
        frame, row = index // 4, (index % 4) * bar
        lift = 2 * (index // 4)
        root = transpose("E2", lift)
        # The hooves: "da . da" on every beat, all three on the fourth.
        for beat in range(4):
            for step in ((0, 2) if beat < 3 else (0, 1, 2)):
                s.put("fm6", frame, row + 3 * beat + step, "A2" if step == 0 else "G2", boom,
                      15 if step == 0 else 12, "S03" if step else None)
        # The bass: the drone driven, E E (octave) | E F E | ... the flat second pulling at it.
        for step, semis in ((0, 0), (1, 0), (2, 7), (3, 0), (4, 1), (5, 0), (6, 0), (7, 0), (8, 7),
                            (9, 1), (10, 0), (11, -1)):
            s.put("fm5", frame, row + step, transpose(root, semis), bass, 12 if step % 3 == 0 else 10)
        # A gong on every bar's top, damped on the beat.
        s.put("fm4", frame, row, root, gong, 9)
        s.put("fm4", frame, row + 3, "===")
        # Low brass stabs on the offbeats (the style's syncopation), the minor second in them.
        for step in (4, 10):
            s.put("fm2", frame, row + step, transpose("B2", lift), horn, 11)
            s.put("fm3", frame, row + step, transpose("C3", lift), horn, 11)
            s.put("fm2", frame, row + step + 1, "===")
            s.put("fm3", frame, row + step + 1, "===")
        # The motif on low brass, galloping, then a bend up into the next bar.
        motif = [("E3", 1), ("F3", 2), ("E3", 1), ("B2", 2), ("E3", 1), ("F3", 1), ("G3", 1),
                 ("F3", 3, "Q21")] if index % 2 == 0 else \
                [("E3", 2), ("F3", 1), ("A3", 3), ("G3", 1), ("F3", 1), ("E3", 1), ("r", 3)]
        assert sum(n[1] for n in motif) == bar
        r = row
        for item in motif:
            note, length = item[0], item[1]
            if note == "r":
                s.put("fm1", frame, r, "===")
            else:
                s.put("fm1", frame, r, transpose(note, lift), brass, 12, item[2] if len(item) > 2 else None)
            r += length
    return s


# --- the night bed -----------------------------------------------------------------------------

def night_bed() -> Song:
    rng = random.Random(20261115)
    rows = 128
    s = Song("Dilim night", frames=1, rows=rows, speed=6, loop_to=0, comments=(
        "Dilim's night: frogs croaking low at uneven gaps over the slowest, darkest breath. Under",
        "the creatures' band.",
    ))
    frog = s.inst_vrc7("frog", patch=13)
    breath = s.inst_2a03("breath", volume=[1] * 40 + [2] * 60 + [1] * 60, duty=[0])
    s.put("noise", 0, 0, "0-#", breath, 15)
    s.put("noise", 0, 64, "1-#", breath, 15)
    # A croak: struck, sliding down a semitone, released two rows on, so the frogs never drone.
    # Two frogs, near and far, at uneven gaps.
    row = 3
    while row < rows - 4:
        channel = "fm1" if rng.random() < 0.6 else "fm2"
        s.put(channel, 0, row, rng.choice(["C3", "D3", "A2", "B2"]), frog,
              rng.choice([10, 11, 12]) if channel == "fm1" else 9, "R51")
        s.put(channel, 0, row + 2, "===")
        row += rng.choice([7, 9, 11, 14, 19])
    return s


# FamiStudio requires the standard text header when importing the forest score.
_, _, forest_module = forest().text().partition("\n")
Path(sys.argv[2]).write_text("# FamiTracker text export 0.4.2\n" + forest_module, encoding="utf-8")
Path(sys.argv[3]).write_text(race().text())
Path(sys.argv[4]).write_text(night_bed().text())
print("wrote", *sys.argv[2:5])
