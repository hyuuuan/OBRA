"""Scaffolding: Mayon, the last painting, and the run's ending (Kent, 2026-11-14 and 2026-11-15: Mayon
has music now; "different type of music when we are in memory lane"; "a peaceful [one] when Lola is
found").

Every piece carries LOLA'S MOTIF, the title theme's opening (audio/music/menu.txt, the bamboo
flute's first phrase): up a fourth, two steps up to a long note, and back down the pentatonic --
A D E F#, E D B A in D. These are her memories, and the game is hers.

- `music.level_5`, the ascent: the motif worn thin under the ash. Its intro is the motif nearly
  whole on the title's band; the loop that follows has lost voices -- a note left out, the
  harmony gone to a bass and one guitar, a minor iv where the major was, a fragment an octave
  down, a single held line in the wind. Quiet, so Lolo's lines carry.
- The memory lane, four pieces remade from each level's own composer, heard from far off: fewer
  voices, slower, softer, a slow vibrato, and the motif threaded through in that level's key.
  `memory_terraces` (two gangsa gongs in a hocket, the hudhud's answer), `memory_piyesta` (the
  drum corps at a distance, the beat-two stop, the agong), `memory_dagat` (the rowing song half
  remembered; the motif is Dagat's own opening shape), `memory_dilim` (the forest's drone and
  motif, warmed by her tune on a clarinet).
- `music.lola`, Lola found at the summit: a kundiman for rondalla like her house's (compose_house.py,
  the bandurria's tremolo), in E major, slower, patient, no drums: it holds while she paints with
  her back turned and the brush refuses twice.
- `mayon_ending`, from the bloom on, through the house: the motif whole again, warm, on the
  title's own band in its own key -- "Lolo. Let's go home."
- `sfx.mayon_brush`, a memory saved: two slow strokes of a brush (dark noise, no tone, as paint
  sounds must) and a warm low fifth under them. Not the page's stroke (draw_submit), which is one
  and short.

The style Kent approved is in all of them, lightly: maj7 and 9th chords, scoops into long notes,
a slow vibrato, a soft echo. Original.

    compose_mayon.py TOOLS_DIR OUT_DIR
writes level_5, memory_terraces, memory_piyesta, memory_dagat, memory_dilim, lola, mayon_ending
and mayon_brush (.txt) into OUT_DIR.
"""
import sys
from pathlib import Path

sys.path.insert(0, sys.argv[1])
from famitext import Song, transpose  # noqa: E402

OUT = Path(sys.argv[2])

NOTES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def midi(note: str) -> int:
    return NOTES.index(note[:-1]) + 12 * (int(note[-1]) + 1)


# Lola's motif in D, in eighths (the title plays it in sixteenths at twice the tempo).
LOLA_D = [("A4", 1), ("D5", 1), ("E5", 2), ("F#5", 3), ("E5", 1), ("D5", 2), ("B4", 2), ("A4", 4)]


def lola_in(key_shift: int, minor: bool = False):
    """The motif moved to another key. Minor: its third and sixth (F# and B, in D) a semitone
    down, so it is the natural minor's."""
    return [(transpose(note, key_shift - (1 if minor and note in ("F#5", "B4") else 0)), length)
            for note, length in LOLA_D]


def line(song: Song, channel: str, inst: int, vol: int, frame: int, row: int, notes, *,
         echo: tuple[int, int] | None = None) -> int:
    """Notes one after another: (note, rows); "r" a rest. `echo`: (inst, rows behind) on pulse2.

    ⚠ STRAIGHT TONES: NO VIBRATO, NO SCOOPS. Kent heard take 1 as "a voice crack": famirender
    applies 4xy in pulse-period units, which on a VRC7 note near A5 swings about half a semitone,
    and with the 2-semitone scoops every long note wobbled like a breaking voice. The title theme
    he likes plays its flute straight (400 on every note), and so does all of Mayon."""
    for note, length in notes:
        if note == "r":
            song.put(channel, frame, row, "===")
        else:
            song.put(channel, frame, row, note, inst, vol)
            if echo is not None:
                song.put("pulse2", frame, row + echo[1], note, echo[0], 15)
        row += length
    return row


def chord(song: Song, channels, frame: int, row: int, notes, inst: int, vol: int, hold: int | None = None):
    for channel, note in zip(channels, notes):
        song.put(channel, frame, row, note, inst, vol)
        if hold is not None:
            song.put(channel, frame, row + hold, "===")


def loop_arpeggios(text: str, count: int) -> str:
    lines = []
    for text_line in text.splitlines():
        parts = text_line.split()
        if text_line.startswith("MACRO 1 ") and int(parts[2]) < count:
            parts[3] = "0"
            text_line = " ".join(parts)
        lines.append(text_line)
    return "\n".join(lines)


def louder(text: str, steps: int, apu: float) -> str:
    """Bring a whole piece up to the game's level without re-voicing it: every FM volume up `steps`
    (3 dB each, capped at F), every pulse and noise volume times `apu` (capped at F). The voices
    keep their balance but for the ones already near the top."""
    out = []
    for text_line in text.splitlines():
        if text_line.startswith("ROW "):
            head, *cells = text_line.split(" : ")
            for i, cell in enumerate(cells):
                parts = cell.split()
                if parts[2] == "." or i in (2, 4):
                    continue
                vol = int(parts[2], 16)
                vol = min(15, vol + steps) if i >= 5 else min(15, max(1, round(vol * apu)))
                parts[2] = f"{vol:X}"
                cells[i] = " ".join(parts)
            text_line = " : ".join([head] + cells)
        out.append(text_line)
    return "\n".join(out)


# --- the ascent --------------------------------------------------------------------------------

def ascent() -> str:
    bar = 8                                            # eighths, 4/4
    s = Song("Mayon", frames=3, rows=4 * bar, speed=24, loop_to=1, comments=(
        "Mayon, the ascent: Lola's motif (the title's) worn thin under the ash: nearly whole at the",
        "start, then losing its voices. Original. D major, ~75 BPM.",
    ))
    flute = s.inst_vrc7("bamboo flute", patch=4)
    guitar = s.inst_vrc7("rondalla", patch=2)
    agung = s.inst_vrc7("agung", patch=9)
    bass = s.inst_vrc7("bass", patch=13)
    wind = s.inst_2a03("wind", volume=[1] * 8 + [2] * 16 + [3] * 24 + [2] * 24 + [1] * 30, duty=[0])
    echo = s.inst_2a03("echo", volume=[2, 2, 2, 2, 1, 1, 1, 1, 0], duty=[2])

    def at(index: int, row: int = 0):
        return index // 4, (index % 4) * bar + row

    # The intro: the motif nearly whole, on the title's band -- flute, rondalla, agung, bass.
    for index, (root, voicing) in enumerate([("D2", ("F#3", "A3", "C#4")), ("B1", ("D3", "F#3", "A3")),
                                             ("G1", ("B2", "D3", "F#3")), ("A1", ("C#3", "E3", "G3"))]):
        s.put("fm5", *at(index), root, bass, 12)
        s.put("fm4", *at(index), root[:-1] + "3", agung, 8)
        s.put("fm4", *at(index, 4), "===")
        for step, tone in enumerate([voicing[0], voicing[1], voicing[2], voicing[1]] * 2):
            s.put("fm2", *at(index, step), tone, guitar, 10 if step % 4 == 0 else 8)
    line(s, "fm1", flute, 13, *at(0), LOLA_D, echo=(echo, 1))
    line(s, "fm1", flute, 12, *at(2), [("D5", 1), ("E5", 1), ("F#5", 2), ("E5", 2), ("D5", 2),
                                       ("B4", 2), ("A4", 2), ("r", 4)])
    # The loop: worn. Bars 1-2 the motif with its long note left out; 3-4 the major iv gone minor;
    # 5-6 a fragment, softer, with its middle gone; 7-8 one note held in the wind.
    for index, root in ((4, "D2"), (5, "B1"), (6, "G1"), (7, "G1"), (8, "D2"), (10, "D2")):
        s.put("fm5", *at(index), root, bass, 12)
    for index, tones in ((4, ("F#3", "A3")), (5, ("D3", "F#3")), (6, ("B2", "D3")), (7, ("A#2", "D3"))):
        for step, tone in enumerate([tones[0], tones[1]] * 2):
            s.put("fm2", *at(index, 2 * step), tone, guitar, 10 if step == 0 else 8)
    s.put("fm2", *at(8), "===")
    line(s, "fm1", flute, 12, *at(4), [("A4", 1), ("D5", 1), ("E5", 2), ("r", 3), ("E5", 1), ("D5", 2),
                                       ("B4", 2), ("A4", 4)])
    line(s, "fm1", flute, 11, *at(6), [("r", 4), ("B4", 2), ("A#4", 2), ("A4", 8)])
    line(s, "fm1", flute, 10, *at(8), [("A4", 1), ("D5", 1), ("r", 4), ("E5", 2), ("r", 2), ("A4", 6)])
    line(s, "fm1", flute, 9, *at(10), [("E5", 6), ("D5", 8), ("r", 2)])
    s.put("fm4", *at(4), "D3", agung, 8)
    s.put("fm4", *at(4, 4), "===")
    for index in (0, 4, 8, 10):
        s.put("noise", *at(index), "2-#", wind, 12 if index >= 8 else 9)
    return s.text()


# --- the memory lane ---------------------------------------------------------------------------

# Terraces' gangsa patch (compose_terraces.py GONG): short and dark, damped by hand.
GANGSA = (0x03, 0x01, 0x1E, 0x04, 0xF6, 0xF5, 0x37, 0x6A)
TAMBOL = (0x01, 0x01, 0x18, 0x04, 0xF8, 0xF5, 0xF8, 0x36)


def memory_terraces() -> str:
    bar = 16
    s = Song("Mayon, the terraces remembered", frames=2, rows=4 * bar, speed=10, loop_to=0, comments=(
        "The memory lane, the terraces: two gangsa gongs in a slow hocket, far off; Lola's motif on",
        "the flute and the hudhud's answer. Original. ~90 BPM.",
    ))
    gong = s.inst_vrc7("gangsa", patch=0, regs=GANGSA)
    flute = s.inst_vrc7("far flute", patch=4)
    answer = s.inst_vrc7("far bell", patch=9)
    bass = s.inst_vrc7("drone", patch=13)
    for index in range(8):
        frame, row = index // 4, (index % 4) * bar
        # Two of the four gongs, in their hocket: the low on 0 and 8, the fifth on 4, 12 and 14.
        # In tune here, unlike Terraces' own: off-scale gongs against her in-tune flute sounded sour.
        for channel, note, steps in (("fm2", "D4", (0, 8)), ("fm3", "A4", (4, 12, 14))):
            for step in steps:
                s.put(channel, frame, row + step, note, gong, 12)
                if step + 2 < bar and step + 1 not in steps and step + 2 not in steps:
                    s.put(channel, frame, row + step + 2, "===")
        if index % 2 == 0:
            s.put("fm6", frame, row, "D2", bass, 11)
    # The motif in sixteenths here (it is the title's own rhythm), on the far flute.
    motif = [(n, 2 * length) for n, length in LOLA_D]
    line(s, "fm1", flute, 12, 0, 0, motif)
    line(s, "fm1", flute, 11, 1, 0, [(transpose(n, 0), length) for n, length in motif[:4]] + [("r", 18)])
    # The hudhud's answer, on a far bell rather than the chorus patch (its "voices" were what
    # cracked), each note damped before the next.
    for frame, notes in ((0, [("D5", 8), ("E5", 4), ("D5", 4), ("B4", 8), ("A4", 8)]),
                         (1, [("A4", 4), ("B4", 4), ("D5", 8), ("E5", 12), ("r", 4)])):
        row = 2 * bar
        for note, length in notes:
            if note != "r":
                s.put("fm4", frame, row, note, answer, 10)
                s.put("fm4", frame, row + min(length, 4), "===")
            row += length
    return s.text()


def memory_piyesta() -> str:
    bar = 16
    s = Song("Mayon, the fiesta remembered", frames=2, rows=4 * bar, speed=8, loop_to=0, comments=(
        "The memory lane, the fiesta: the drum corps far off, slower, the beat-two stop, the agong;",
        "Lola's motif on a soft trumpet in A minor. Original. ~120 BPM.",
    ))
    for frame in range(2):
        for row in range(4 * bar):
            s._set(frame, row, "dpcm", 3, "F08" if row % 2 == 0 else "F07")
    boom = s.inst_vrc7("tambol, far", patch=0, regs=TAMBOL)
    trumpet = s.inst_vrc7("trumpet, far", patch=7)
    agong = s.inst_vrc7("agong", patch=9)
    bass = s.inst_vrc7("bass", patch=13)
    ghost = s.inst_2a03("snare, far", volume=[5, 3, 2, 1, 0], duty=[0])
    chords = ["Am", "G", "Dm", "E", "Am", "G", "Dm", "E"]
    roots = {"Am": "A2", "G": "G2", "Dm": "D3", "E": "E2"}
    for index, name in enumerate(chords):
        frame, row = index // 4, (index % 4) * bar
        for step in (0, 8, 15):
            s.put("fm6", frame, row + step, "A2", boom, 12 if step != 15 else 10, "S03" if step == 15 else None)
        for step in (7, 11, 13):
            s.put("noise", frame, row + step, "5-#", ghost, 9)
        s.put("fm4", frame, row, roots[name], agong, 10)
        s.put("fm4", frame, row + 4, "===")                # beat two: the stop
        s.put("fm5", frame, row, roots[name], bass, 10)
        s.put("fm5", frame, row + 3, "===")
        s.put("fm5", frame, row + 8, roots[name], bass, 9)
    motif = [(n, 2 * length) for n, length in lola_in(7, minor=True)]       # E A B C, B A G E
    line(s, "fm1", trumpet, 11, 0, 0, motif)
    line(s, "fm1", trumpet, 10, 1, 0, motif[:5] + [("r", 2), ("G5", 4), ("E5", 8), ("r", 2)])
    return s.text()


def memory_dagat() -> str:
    bar = 6                                            # 3/4 in eighths
    s = Song("Mayon, the sea remembered", frames=2, rows=4 * bar, speed=24, loop_to=0, comments=(
        "The memory lane, the sea: Dagat's rowing song half remembered, slower; Lola's motif, which",
        "is the shape of Dagat's own opening, on the flute. Original. G major, ~80 BPM.",
    ))
    s.swing(24, 21)
    flute = s.inst_vrc7("flute", patch=4)
    guitar = s.inst_vrc7("guitar, soft", patch=2)
    bass = s.inst_vrc7("bass", patch=13)
    vibes = s.inst_vrc7("vibraphone", patch=11)
    wave = s.inst_2a03("wave", volume=[4, 4, 3, 3, 3, 2, 2, 2, 1], duty=[2])
    chords = [("G2", ("B3", "F#4"), ("G3", "B3", "D4", "F#4")), ("E2", ("G3", "D4"), ("E3", "G3", "B3", "D4")),
              ("C2", ("B3", "E4"), ("C4", "E4", "G4", "B4")), ("D2", ("C4", "E4"), ("D3", "G3", "A3", "C4")),
              ("G2", ("B3", "F#4"), ("G3", "B3", "D4", "F#4")), ("B1", ("A3", "D4"), ("B2", "D3", "F#3", "A3")),
              ("C2", ("B3", "E4"), ("C4", "E4", "G4", "B4")), ("D2", ("C4", "F#4"), ("D3", "F#3", "A3", "C4"))]
    for index, (root, pair, tones) in enumerate(chords):
        frame, row = index // 4, (index % 4) * bar
        s.put("fm5", frame, row, root, bass, 11)
        for hit in (2, 4):
            chord(s, ("fm2", "fm3"), frame, row + hit, pair, guitar, 9, hold=1)
        for step, tone in enumerate([tones[0], tones[1], tones[2], tones[3], tones[2], tones[1]]):
            s.put("pulse1", frame, row + step, tone, wave, 15, "V02" if step == 0 else None)
        if index % 2 == 0:
            s.put("fm6", frame, row + 3, tones[3], vibes, 8)
            s.put("fm6", frame, row + 5, "===")
    # The motif in 3/4, then the rowing song's own first phrase, softer.
    line(s, "fm1", flute, 12, 0, 0, [("D5", 2), ("G5", 1), ("A5", 3), ("B5", 5), ("A5", 1), ("G5", 2),
                                      ("E5", 2), ("D5", 2), ("D5", 6)])
    line(s, "fm1", flute, 11, 1, 0, [("B4", 2), ("D5", 1), ("F#5", 3), ("A5", 2), ("F#5", 1),
                                      ("D5", 1), ("B4", 2), ("C5", 1), ("E5", 1), ("G5", 1), ("B5", 3),
                                      ("A5", 6)])
    return s.text()


def memory_dilim() -> str:
    bar = 8
    s = Song("Mayon, the forest remembered", frames=2, rows=4 * bar, speed=25, loop_to=0, comments=(
        "The memory lane, the forest: Dilim's drone and its motif, softer, warmed by Lola's tune on a",
        "clarinet. Original. E minor, ~72 BPM.",
    ))
    drone = s.inst_vrc7("drone", patch=13)
    flute = s.inst_vrc7("flute", patch=4)
    clarinet = s.inst_vrc7("clarinet", patch=5)
    bell = s.inst_vrc7("far bell", patch=9)
    for index, note in ((0, "E2"), (2, "E2"), (4, "C2"), (6, "B1")):
        s.put("fm5", index // 4, (index % 4) * bar, note, drone, 13)
    line(s, "fm1", flute, 12, 0, 0, [("r", 2), ("E4", 1), ("F4", 3), ("E4", 1), ("B3", 1), ("r", 8)])
    # Her tune in E minor answers the forest's: B E F# G, F# E D B.
    motif = lola_in(-10, minor=True)
    line(s, "fm2", clarinet, 11, 0, 2 * bar, motif)
    line(s, "fm1", flute, 11, 1, 0, [("r", 2), ("E4", 1), ("F#4", 3), ("G4", 1), ("B3", 1), ("r", 8)])
    line(s, "fm2", clarinet, 10, 1, 2 * bar, motif[:4] + [("D4", 2), ("E4", 5), ("r", 2)])
    for frame, row, note in ((0, 4, "B3"), (0, 20, "G3"), (1, 4, "B3"), (1, 28, "E3")):
        s.put("fm3", frame, row, note, bell, 9)
        s.put("fm3", frame, row + 3, "===")
    return s.text()


# --- Lola, found -------------------------------------------------------------------------------

def lola() -> str:
    beat = 8                                           # thirty-seconds: the tremolo's strokes
    bar = 3 * beat
    s = Song("Lola", frames=3, rows=4 * bar, speed=6, loop_to=0, comments=(
        "Lola, found: a kundiman for rondalla like her house's, slower and patient; her motif on the",
        "bandurria's tremolo. No drums. Original. E major, ~75 BPM.",
    ))
    bandurria = s.inst_vrc7("bandurria", patch=2)
    laud = s.inst_vrc7("laud", patch=2)
    guitar = s.inst_vrc7("guitar", patch=2)
    bass = s.inst_vrc7("bass", patch=13)
    sparkle = {kind: s.inst_2a03(f"{kind} sparkle", volume=[3, 3, 2, 2, 2, 1], arpeggio=steps, duty=[2])
               for kind, steps in {"M": [0, 4, 7, 12], "m": [0, 3, 7, 12], "7": [0, 4, 7, 10]}.items()}
    chords = [("E", "M", "E2", ("G#3", "B3"), ("E3", "B3", "G#4")), ("C#m", "m", "C#2", ("E3", "G#3"), ("C#3", "G#3", "E4")),
              ("A", "M", "A1", ("C#4", "E4"), ("A2", "E3", "C#4")), ("B7", "7", "B1", ("D#4", "A4"), ("B2", "F#3", "D#4")),
              ("E", "M", "E2", ("G#3", "B3"), ("E3", "B3", "G#4")), ("G#m", "m", "G#1", ("B3", "D#4"), ("G#2", "D#3", "B3")),
              ("A", "M", "A1", ("C#4", "E4"), ("A2", "E3", "C#4")), ("B7", "7", "B1", ("D#4", "A4"), ("B2", "F#3", "D#4")),
              ("C#m", "m", "C#2", ("E3", "G#3"), ("C#3", "G#3", "E4")), ("A", "M", "A1", ("C#4", "E4"), ("A2", "E3", "C#4")),
              ("F#m", "m", "F#1", ("A3", "C#4"), ("F#2", "C#3", "A3")), ("B7", "7", "B1", ("D#4", "A4"), ("B2", "F#3", "D#4"))]
    for index, (_, kind, root, pair, broken) in enumerate(chords):
        frame, row = index // 4, (index % 4) * bar
        s.put("pulse1", frame, row, transpose(root, 36), sparkle[kind], 15, "V02" if index == 0 else None)
        s.put("fm6", frame, row, root, bass, 11)
        for step, note in enumerate([broken[0], broken[1], broken[2], broken[1], broken[2], broken[1]]):
            s.put("fm5", frame, row + step * (beat // 2), note, laud, 10 if step == 0 else 9)
        for b in (1, 2):
            chord(s, ("fm3", "fm4"), frame, row + b * beat, pair, guitar, 10, hold=3)

    def tremolo(frame: int, row: int, bars_of) -> None:
        for item in bars_of:
            note, beats = item[0], item[1]
            if note == "r":
                s.put("fm1", frame, row, "===")
            else:
                # ⚠ A stroke on every row, as the house's bandurria: take 1 struck every other row,
                # five times a second, and the tremolo stuttered.
                for stroke in range(beats * beat):
                    s.put("fm1", frame, row + stroke, note, bandurria, 12 if stroke % 2 == 0 else 11)
            row += beats * beat

    # Her motif in E major, in beats over 3/4: B E F# | G# . F# | E C# | B . . ; then onward.
    tune = [("B4", 1), ("E5", 1), ("F#5", 1), ("G#5", 2), ("F#5", 1), ("E5", 1), ("C#5", 2), ("B4", 3),
            ("C#5", 1), ("E5", 1), ("B5", 1), ("A5", 2), ("B5", 1), ("G#5", 1), ("F#5", 1), ("D#5", 1),
            ("E5", 3), ("C#5", 1), ("E5", 1), ("G#5", 1), ("A5", 2), ("C#6", 1), ("B5", 2), ("A5", 1),
            ("F#5", 2), ("D#5", 1)]
    assert sum(n[1] for n in tune) == 36
    tremolo(0, 0, tune)
    return loop_arpeggios(s.text(), len(sparkle))


# --- the ending --------------------------------------------------------------------------------

def ending() -> str:
    bar = 8                                            # eighths, 4/4
    s = Song("Let's go home", frames=3, rows=4 * bar, speed=20, loop_to=0, comments=(
        "Mayon's ending, and the house after: Lola's motif whole again, warm, on the title's band --",
        "bamboo flute, kulintang, rondalla, agung. Original. D major, ~90 BPM.",
    ))
    flute = s.inst_vrc7("bamboo flute", patch=4)
    kulintang = s.inst_vrc7("kulintang", patch=9)
    rondalla = s.inst_vrc7("rondalla", patch=2)
    agung = s.inst_vrc7("agung", patch=9)
    bass = s.inst_vrc7("bass", patch=13)
    dabakan = s.inst_2a03("dabakan", volume=[8, 6, 4, 3, 2, 1, 0], duty=[0])
    echo = s.inst_2a03("echo", volume=[3, 3, 3, 2, 2, 2, 1, 1, 0], duty=[2])
    # D | Bm | G | A, then home again, then the turn to B minor and back, as the title does.
    chords = [("D2", ("F#3", "A3")), ("B1", ("D3", "F#3")), ("G1", ("B2", "D3")), ("A1", ("C#3", "E3")),
              ("D2", ("F#3", "A3")), ("B1", ("D3", "F#3")), ("G1", ("B2", "D3")), ("A1", ("C#3", "G3")),
              ("B1", ("D3", "F#3")), ("G1", ("B2", "D3")), ("A1", ("C#3", "E3")), ("D2", ("F#3", "A3"))]
    for index, (root, pair) in enumerate(chords):
        frame, row = index // 4, (index % 4) * bar
        s.put("fm5", frame, row, root, bass, 12)
        s.put("fm5", frame, row + 4, transpose(root, 7), bass, 11)
        s.put("fm4", frame, row, root[:-1] + "3", agung, 10)
        s.put("fm4", frame, row + 4, "===")
        # The rondalla: a harana's broken chord in eighths, and the two notes together on two and four.
        for step, note in enumerate([root[:-1] + "3", pair[0], pair[1], pair[0], transpose(pair[0], 12),
                                     pair[1], pair[0], pair[1]]):
            s.put("fm2", frame, row + step, note, rondalla, 10 if step % 4 == 0 else 9)
        for step in (2, 6):
            chord(s, ("fm3", "fm6"), frame, row + step, (pair[1], transpose(pair[0], 12)), rondalla, 8, hold=1)
        for step in (0, 4):
            s.put("noise", frame, row + step, "5-#", dabakan, 9 if step == 0 else 7)
        # The kulintang: one damped strike in the bar's last beat, answering the flute.
        s.put("fm3", frame, row + 7, transpose(pair[1], 24), kulintang, 8)
        s.put("fm3", frame, row + 8, "===")
    tune = LOLA_D + [("F#5", 1), ("A5", 1), ("B5", 2), ("A5", 3), ("F#5", 1), ("E5", 4), ("D5", 4)] \
        + LOLA_D + [("D5", 1), ("E5", 1), ("F#5", 2), ("A5", 3), ("B5", 1), ("A5", 8)] \
        + [("B4", 1), ("D5", 1), ("F#5", 2), ("E5", 4), ("D5", 1), ("E5", 1), ("F#5", 2), ("A5", 4),
           ("G5", 2), ("F#5", 2), ("E5", 2), ("D5", 2), ("D5", 6), ("r", 2)]
    assert sum(n[1] for n in tune) == 12 * bar, sum(n[1] for n in tune)
    line(s, "fm1", flute, 13, 0, 0, tune, echo=(echo, 1))
    return s.text()


# --- the brush ---------------------------------------------------------------------------------

def brush() -> str:
    s = Song("Mayon brush", frames=1, rows=24, speed=2, loop_to=None, comments=(
        "A memory saved: two slow strokes of a brush, and a warm low fifth under them. No tone in the",
        "strokes: paint sounds like paint.",
    ))
    stroke = s.inst_2a03("stroke", volume=[1, 2, 3, 4, 5, 6, 6, 6, 5, 5, 4, 4, 3, 3, 2, 2, 1, 1, 0], duty=[0])
    fuller = s.inst_2a03("second stroke", volume=[1, 2, 3, 4, 5, 6, 7, 7, 7, 6, 6, 5, 5, 4, 4, 3, 3, 2, 2,
                                                  1, 1, 1, 0], duty=[0])
    warm = s.inst_vrc7("warm", patch=4)
    s.put("noise", 0, 0, "4-#", stroke, 11)
    s.put("noise", 0, 7, "3-#", fuller, 12)
    s.put("fm1", 0, 2, "D4", warm, 9)
    s.put("fm2", 0, 4, "A4", warm, 8)
    s.put("fm1", 0, 16, "===")
    s.put("fm2", 0, 16, "===")
    s._set(0, 23, "dpcm", 3, "C00")
    return s.text()


# Each piece's gain to the game's level (-18 dBFS RMS +-2; the ascent and the memories at the
# soft end of it, far off), measured with tools/audio_lab/render.py.
for name, text in (("level_5", louder(ascent(), 3, 1.0)),
                   ("memory_terraces", louder(memory_terraces(), 2, 1.0)),
                   ("memory_piyesta", louder(memory_piyesta(), 3, 1.3)),
                   ("memory_dagat", louder(memory_dagat(), 2, 1.3)),
                   ("memory_dilim", louder(memory_dilim(), 3, 1.0)),
                   ("lola", louder(lola(), 2, 1.3)), ("mayon_ending", louder(ending(), 1, 1.2)),
                   ("mayon_brush", brush())):
    (OUT / f"{name}.txt").write_text(text)
print("wrote", OUT)
