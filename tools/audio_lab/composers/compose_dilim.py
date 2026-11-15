"""Write Dilim's forest theme, race music, and forest ambience.

    compose_dilim.py TOOLS_DIR FOREST.txt RACE.txt AMBIENCE.txt

The forest theme layers two low FM swells and occasional noise. The race
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
    song = Song("Dilim - The Dark Between Trees", frames=4, rows=64, speed=11, comments=(
        "Original horror ambience for Dilim.",
        "Low A and E swells on FM1 and FM2, with occasional noise.",
    ))

    DRONE = song.inst_vrc7("Slow FM swell", patch=0,
                           regs=(0x21, 0x21, 0x1C, 0x02, 0x73, 0x83, 0x47, 0x37))
    HUSH = song.inst_2a03("Noise swell", volume=[1] * 12 + [2] * 18 + [1] * 16 + [0], duty=[0])


    # Leave gaps in all of the pitched voices before the second and final orders.
    floor = (
        ((0, "A2", 21, 13), (31, "E2", 19, 11)),
        ((4, "A2", 25, 12), (36, "A2", 18, 13)),
        ((0, "A2", 35, 14), (44, "E2", 13, 12)),
        ((5, "A2", 29, 13), (39, "A2", 12, 11)),
    )
    # Stagger the second voice within each swell while keeping the gaps between orders.
    # The two brief B-flats are the tension already in the drone.
    under = (
        ((5, "E3", 14, 11), (35, "A2", 13, 10)),
        ((9, "E3", 16, 11), (40, "A#2", 9, 8)),
        ((3, "E3", 8, 9), (12, "A#2", 21, 10), (46, "A2", 10, 10)),
        ((9, "E3", 22, 11), (42, "E3", 8, 9)),
    )
    for frame, (low, layer) in enumerate(zip(floor, under, strict=True)):
        for channel, events in (("fm1", low), ("fm2", layer)):
            for row, note, length, volume in events:
                song.put(channel, frame, row, note, DRONE, volume)
                song.put(channel, frame, row + length, "===")

    song.put("noise", 1, 30, "0-#", HUSH, 10)
    song.put("noise", 2, 8, "1-#", HUSH, 11)
    song.put("noise", 3, 41, "0-#", HUSH, 9)
    return song


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
