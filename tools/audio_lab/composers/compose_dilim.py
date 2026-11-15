"""Scaffolding: Dilim, the forest at night (Kent, 2026-11-15: "scary / unknown vibe type of music",
and "for racing, there should be thrilling version for that music").

⚠ DILIM'S CREATURES ARE GAMEPLAY. The tik-tik's call is strongest at 2-8 kHz and the tiyanak's cry
at 500 Hz-2 kHz (tools/audio_lab/ref/bands.py on their WAVs). Everything here lives UNDER 500 Hz:
low voices, no noise, no pulse, so a call always reads over the music.
tests/test_dilim_calls_read.py holds every Dilim piece to it.

- **The forest** (`music.level_4`): E Phrygian, slow (~72 BPM). A drone on E with a low flute a
  minor second above it, beating, never resolved; the motif -- E, F, E, down to B -- on a low
  flute, bending; a few soft bells far apart; a knock from somewhere in the trees, like a bamboo
  tongatong or a far gong. Long rests that make a player listen. The style's touch is in the
  harmony (a whole-tone climb, the Phrygian F major 7 #11, a tritone at the turn) and the bends.
- **The race** (`music.level_4_race`): the same motif made thrilling for the tikbalang's race,
  ~157 BPM in triplets: the hooves galloping on the tambol, the drone turned into a driving bass,
  low brass stabs on the offbeats, and the motif climbing a whole tone every four bars, never
  arriving -- until the race is won and the forest's music comes back.
- **The night** (`ambience.level_4`): frogs (a low FM croak, two notes sliding down) at uneven
  gaps over the slowest, darkest breath of noise. Not the old brief's high chirps: Kent dislikes
  thin high pulses, and they would sit in the tik-tik's band.

Original.

    compose_dilim.py TOOLS_DIR FOREST.txt RACE.txt NIGHT_BED.txt
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
    bar = 8                                   # eighths
    s = Song("Dilim", frames=2, rows=4 * bar, speed=25, loop_to=0, comments=(
        "Dilim, the forest at night: a beating drone, a low flute's motif that never resolves, far",
        "bells and a knock in the trees. All under 500 Hz, so the creatures read. Original. E Phrygian.",
    ))
    drone = s.inst_vrc7("drone", patch=13)
    shadow = s.inst_vrc7("minor second", patch=4)
    fifth = s.inst_vrc7("held fifth", patch=5)
    flute = s.inst_vrc7("low flute", patch=4)
    bell = s.inst_vrc7("far bell", patch=9)
    knock = s.inst_vrc7("tree knock", patch=9)

    def at(index: int, row: int = 0) -> tuple[int, int]:
        return index // 4, (index % 4) * bar + row

    # The drone: E held, F at the seventh bar (Phrygian's flat second), B flat at the eighth (the
    # tritone), back to E at the top. Struck every two bars so it never dies away.
    for index, note in ((0, "E2"), (2, "E2"), (4, "E2"), (6, "F2"), (7, "A#1")):
        s.put("fm5", *at(index), note, drone, 15)
    # The minor second above it, a low flute, beating against it for three bars, slowly wavering.
    s.put("fm6", *at(1), "F2", shadow, 14, "412")
    s.put("fm6", *at(4), "===", fx="400")
    s.put("fm6", *at(5), "F2", shadow, 13, "412")
    s.put("fm6", *at(7), "===", fx="400")

    # A fifth under it all on the clarinet, low, held where the minor second rests: the drone
    # opens, and closes again.
    s.put("fm4", *at(0), "B1", fifth, 14)
    s.put("fm4", *at(1), "===")
    s.put("fm4", *at(4), "B1", fifth, 14)
    s.put("fm4", *at(5), "===")
    s.put("fm4", *at(7), "E2", fifth, 13)

    # The motif and its answers, each after a rest.
    phrases = {
        1: [("r", 2)] + MOTIF + [("r", 0)],
        3: [("r", 2), ("E3", 1), ("F#3", 1), ("G#3", 1), ("A#3", 3, "R81")],     # whole tones, sagging
        5: [("r", 2), ("G3", 1), ("F3", 3), ("E3", 1), ("D#3", 1)],
        7: [("r", 2), ("E3", 1), ("F3", 5)],                                    # F, held: unresolved
    }
    for index, notes in phrases.items():
        frame, row = at(index)
        for item in notes:
            note, length = item[0], item[1]
            if length == 0:
                continue
            if note == "r":
                s.put("fm1", frame, row, "===", fx="400")
            else:
                s.put("fm1", frame, row, note, flute, 13, item[2] if len(item) > 2 else None)
            row += length
        s.put("fm1", *at(index + 1 if index < 7 else 0), "===", fx="400")

    # A few soft bells, far apart, damped before they pile up (the Terraces lesson).
    for index, row, note in ((0, 4, "B3"), (2, 2, "C4"), (2, 6, "B3"), (4, 0, "G3"), (6, 4, "A#3")):
        s.put("fm2", *at(index, row), note, bell, 10)
        s.put("fm2", *at(index, row + 3), "===")
    # The knock: three strokes from somewhere in the trees, every four bars, cut at once.
    for index in (1, 5):
        for row, note in ((5, "A2"), (6, "A2"), (7, "D3")):
            s.put("fm3", *at(index, row), note, knock, 10 if row < 7 else 8)
            s.put("fm3", *at(index, row + 1), "===")
    return s


# --- the race ----------------------------------------------------------------------------------

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


Path(sys.argv[2]).write_text(forest().text())
Path(sys.argv[3]).write_text(race().text())
Path(sys.argv[4]).write_text(night_bed().text())
print("wrote", *sys.argv[2:5])
