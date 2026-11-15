"""Scaffolding: Dilim, the forest at night (Kent, 2026-11-15: "scary / unknown vibe type of music",
and "for racing, there should be thrilling version for that music").

⚠ DILIM'S CREATURES ARE GAMEPLAY. The tik-tik's call is strongest at 2-8 kHz and the tiyanak's cry
at 500 Hz-2 kHz (tools/audio_lab/ref/bands.py on their WAVs). Everything here lives UNDER 500 Hz:
low voices, no noise, no pulse, so a call always reads over the music.
tests/test_dilim_calls_read.py holds every Dilim piece to it.

- **The forest** (`music.level_4`), take 2: E Phrygian, ~72 BPM. A heartbeat on the tambol, slow
  then quickening; a drone on E struck every bar so it never dies, a low flute a minor second above
  it, beating; a figure stalking chromatically (E, F, E, D#); the motif -- E, F, E, down to B --
  then climbing whole tones to an A# it cannot leave; a drop to silence in the last half bar and a
  stinger (the heart, a low gong, the drone) as it comes round. Take 1 was sparse and decayed to
  near-silence between strikes: Kent heard it as "not that suspenseful".
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
    """Take 2 (Kent, 2026-11-15: "not that suspenseful"). Take 1 was sparse and its drone decayed
    to -40 dB between strikes, so it read as empty rather than tense. Suspense needs something that
    keeps going and something that does not resolve: a heartbeat, a drone that never dies, a figure
    stalking chromatically, the motif climbing to a note it cannot leave, then a drop to silence and
    a stinger as it comes round."""
    bar = 16                                  # sixteenths
    s = Song("Dilim", frames=2, rows=4 * bar, speed=13, loop_to=0, comments=(
        "Dilim, the forest at night: a heartbeat, a drone that never dies, a stalking figure, a",
        "motif that climbs and will not resolve, a drop and a stinger. Under 500 Hz. Original.",
    ))
    for frame in range(2):
        for row in range(4 * bar):
            s._set(frame, row, "dpcm", 3, "F0D" if row % 2 == 0 else "F0C")   # 25 ticks an eighth: ~72 BPM
    heart = s.inst_vrc7("heartbeat", patch=0, regs=TAMBOL)
    drone = s.inst_vrc7("drone", patch=13)
    shadow = s.inst_vrc7("minor second", patch=4)
    stalker = s.inst_vrc7("stalker", patch=5)
    flute = s.inst_vrc7("low flute", patch=4)
    bell = s.inst_vrc7("far bell", patch=9)
    DROP = 7 * bar + 8                        # the last half bar: everything gone

    def at(index: int, row: int = 0) -> tuple[int, int]:
        return index // 4, (index % 4) * bar + row

    # The drone, struck every bar so it never dies away; F under the seventh bar (Phrygian's flat
    # second), and cut for the drop.
    for index in range(8):
        s.put("fm5", *at(index), "F2" if index == 6 else "E2", drone, 14 if index != 0 else 15)
    s.put("fm5", *divmod(DROP, 4 * bar), "===")
    # The minor second above it, beating, held from the second bar to the drop.
    s.put("fm6", *at(1), "F2", shadow, 12)
    s.put("fm6", *at(4), "F2", shadow, 13)
    s.put("fm6", *divmod(DROP, 4 * bar), "===")

    # The heartbeat: lub-dub every other beat, then every beat from the fifth bar, a little harder;
    # none in the drop. ⚠ The tambol is the piece's one custom patch.
    for index in range(8):
        beats = (0, 8) if index < 4 else (0, 4, 8, 12)
        for beat in beats:
            if index == 7 and beat >= 8:
                continue
            hard = 13 if index < 4 else 14
            s.put("fm3", *at(index, beat), "E2", heart, hard, "S03")
            s.put("fm3", *at(index, beat + 1), "E2", heart, hard - 3, "S03")
    # The stinger as the loop comes round: the heart, a low gong and the drone all at once.
    s.put("fm3", *at(0), "A2", heart, 15)
    s.put("fm4", *at(0), "E2", bell, 13)
    s.put("fm4", *at(0, 6), "===")

    # The stalking figure, from the fifth bar: E, F, E, D#, an eighth each, cut short.
    for index in range(4, 8):
        for step, note in enumerate(("E2", "F2", "E2", "D#2")):
            row = step * 4
            if index == 7 and row >= 8:
                break
            s.put("fm2", *at(index, row), note, stalker, 12)
            s.put("fm2", *at(index, row + 2), "===")

    # The motif, then the climb that will not resolve: E F E B; E F G A#, and A# held into the drop.
    def phrase(index: int, notes) -> None:
        frame, row = at(index)
        for note, length in notes:
            if note == "r":
                s.put("fm1", frame, row, "===")
            else:
                s.put("fm1", frame, row, note, flute, 13)
            row += length

    phrase(1, [("r", 4), ("E3", 2), ("F3", 6), ("E3", 2), ("B2", 2)])
    phrase(3, [("r", 4), ("E3", 2), ("F3", 4), ("G3", 2), ("F3", 2), ("E3", 2)])
    phrase(5, [("r", 4), ("E3", 2), ("F3", 2), ("G3", 2), ("A3", 2), ("A#3", 4)])
    phrase(6, [("A#3", 16)])
    s.put("fm1", *divmod(DROP, 4 * bar), "===")
    # Two far bells, a minor second apart, where the heart is slow.
    for index, note in ((2, "B3"), (3, "C4")):
        s.put("fm4", *at(index, 6), note, bell, 9)
        s.put("fm4", *at(index, 9), "===")
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
