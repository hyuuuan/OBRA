"""Scaffolding: Dagat's sea (Kent, 2026-11-15: "one audio for starting the level / rowing the
ocean, in case the player just wants to not go to the ocean, different audio for when the player
is swimming, below the ocean").

- **The surface** (`music.level_3`): a Visayan rowing song in 3/4, after the balitaw -- the bass on
  one, the rondalla guitar strumming two and three, a bamboo flute carrying a long-breathed tune
  -- with the paddle's pull on every downbeat (a dark swell of noise and a soft thump). Waves are
  broken chords rising and falling across the bar, a vibraphone catching each crest. On top, the
  style Kent approved (compose_style_sketch.py): a light swing, maj7 and 9th changes, the flute
  scooping into its long notes and falling off its phrase ends, a soft pulse echo behind it, a
  chip-chord shimmer in the B section, a clarinet answering in the last phrase. G major, ~95 BPM.
- **The deep** (`music.level_3_deep`): the same piece heard from under the water. ⚠ SAME
  SKELETON, TO THE ROW (frames, rows, speeds), because AudioDirector.play_music(keep_position)
  trades the two mid-bar on a dive. The drums, strum and flute go; the chords are held on low
  flutes that glide into each other and are never struck again, the waves an octave down at half
  speed, the bass held, the tune a quiet clarinet an octave down, and a soft bell now and then.
  No noise.
- **The waves** (`ambience.level_3`): long, dark noise swells at uneven gaps, at the surface only.

Original: no folk song's melody is used.

    compose_dagat.py TOOLS_DIR SURFACE.txt DEEP.txt WAVES.txt
"""
import sys
from pathlib import Path

sys.path.insert(0, sys.argv[1])
from famitext import Song, transpose  # noqa: E402

BAR = 6                     # 3/4 in eighths: one row an eighth
FRAME_BARS = 4
ROWS = BAR * FRAME_BARS
FRAMES = 5                  # 0 the intro, 1-4 the loop's sixteen bars
# Swung eighths, 22 + 16 = 38 ticks a beat: ~95 BPM at 60.0988 frames a second.
SWING = (22, 16)

NOTES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def midi(note: str) -> int:
    return NOTES.index(note[:-1]) + 12 * (int(note[-1]) + 1)


def name(m: int) -> str:
    return f"{NOTES[m % 12]}{m // 12 - 1}"


# chord -> its tones as pitch classes from the root (the arpeggio's wave climbs them), the guitar's
# three-note voicing, and the bass's root and fifth.
CHORDS = {
    "Gmaj7": ("G", (0, 4, 7, 11), ("B3", "D4", "F#4"), ("G3", "D3")),
    "Em9": ("E", (0, 3, 7, 10, 14), ("G3", "D4", "F#4"), ("E3", "B2")),
    "Cmaj7": ("C", (0, 4, 7, 11), ("G3", "B3", "E4"), ("C3", "G2")),
    "D9sus": ("D", (0, 5, 7, 10, 14), ("G3", "C4", "E4"), ("D3", "A2")),
    "Bm7": ("B", (0, 3, 7, 10), ("A3", "D4", "F#4"), ("B2", "F#2")),
    "Am7": ("A", (0, 3, 7, 10), ("G3", "C4", "E4"), ("A2", "E3")),
    "D7": ("D", (0, 4, 7, 10, 14), ("F#3", "C4", "E4"), ("D3", "A2")),
    "A7": ("A", (0, 4, 7, 10), ("G3", "C#4", "F#4"), ("A2", "E3")),
    "E7": ("E", (0, 4, 7, 10, 14), ("G#3", "D4", "F#4"), ("E3", "B2")),
    "D7b9": ("D", (0, 4, 7, 10, 13), ("F#3", "C4", "D#4"), ("D3", "A2")),
}
INTRO = ["Cmaj7", "D9sus", "Cmaj7", "D9sus"]
LOOP = ["Gmaj7", "Em9", "Cmaj7", "D9sus",
        "Gmaj7", "Bm7", "Cmaj7", ("Am7", "D7"),
        "Cmaj7", "Bm7", "Em9", "A7",
        "Cmaj7", ("Bm7", "E7"), "Am7", "D7b9"]

# The flute, bar by bar in eighths: (note, rows[, effect]). A scoop is the note under the target
# with Qxy (it slides up y semitones and arrives); a fall-off is Rxy given as a 0-row marker on the
# note before. "r" is a rest.
TUNE = [
    [("B4", 2), ("D5", 1), ("E5", 3, "Q32")],                       # Gmaj7: up to the maj7, F#
    [("G5", 2), ("F#5", 1), ("E5", 1), ("D5", 2)],                   # Em9
    [("E5", 1), ("G5", 1), ("A5", 4, "Q32")],                       # Cmaj7: up to its maj7, B
    [("A5", 3), ("G5", 1), ("E5", 2), ("E5", 0, "R42")],             # D9sus, falling off
    [("B4", 2), ("D5", 1), ("E5", 3, "Q32")],                       # Gmaj7
    [("A5", 2), ("F#5", 1), ("D5", 1), ("B4", 2)],                   # Bm7
    [("C5", 1), ("E5", 1), ("G5", 1), ("B5", 3)],                    # Cmaj7
    [("A5", 3), ("F#5", 1), ("A5", 1), ("C6", 1)],                   # Am7 | D7
    [("G5", 1), ("B5", 1), ("C6", 4, "Q32")],                       # Cmaj7: up to the 9th, D
    [("D6", 2), ("B5", 1), ("A5", 1), ("F#5", 2)],                   # Bm7
    [("B5", 2), ("A5", 1), ("G5", 1), ("F#5", 2)],                   # Em9
    [("E5", 1), ("G5", 1), ("C#6", 3), ("C#6", 0, "R52"), ("r", 1)],  # A7, falling off
    [("B5", 3), ("A5", 1), ("G5", 1), ("E5", 1)],                    # Cmaj7
    [("F#5", 2), ("D5", 1), ("G#5", 2), ("B5", 1)],                  # Bm7 | E7
    [("B5", 3, "Q31"), ("B5", 1), ("A5", 1), ("G5", 1)],             # Am7: a scoop to its third
    [("F#5", 2), ("E5", 1), ("D5", 3), ("D5", 0, "R83")],            # D7b9, falling off home
]
# A pickup into the tune at the intro's end.
PICKUP = [("r", 3), ("D4", 1), ("G4", 1), ("A4", 1)]
# The clarinet's answer in the last phrase, a third or sixth under the flute (bars 13-16).
ANSWER = {
    12: [("G5", 3), ("F#5", 1), ("E5", 1), ("C5", 1)],
    13: [("D5", 2), ("B4", 1), ("E5", 2), ("G#5", 1)],
    14: [("G5", 3), ("G5", 1), ("E5", 1), ("C5", 1)],
    15: [("D5", 2), ("C5", 1), ("A4", 3)],
}
# Where the fast chip-chord shimmer replaces the waves: the sun on the water in the B section.
SHIMMER_BARS = range(8, 12)

for bar in TUNE + list(ANSWER.values()):
    assert sum(n[1] for n in bar) == BAR, f"a bar of the tune is not {BAR} rows: {bar}"


def bars(sequence, first_frame: int):
    for index, entry in enumerate(sequence):
        halves = list(entry) if isinstance(entry, tuple) else [entry]
        yield index, first_frame + index // FRAME_BARS, (index % FRAME_BARS) * BAR, halves


def wave(chord: str, octave_down: bool = False) -> list[str]:
    """The chord's tones climbing from its root (D4..C#5), for a wave across the bar."""
    root, steps, _, _ = CHORDS[chord]
    base = midi(root + "4")
    while base < midi("D4"):
        base += 12
    while base > midi("C#5"):
        base -= 12
    if octave_down:
        base -= 12
    return [name(base + s) for s in steps[:4]]


def new_song(title: str, comments: tuple[str, ...]) -> Song:
    song = Song(title, frames=FRAMES, rows=ROWS, speed=SWING[0], loop_to=1, comments=comments)
    song.swing(*SWING)
    return song


def lead(song: Song, channel: str, inst: int, vol: int, bars_of, first: int, start_bar: int = 0, *,
         shift: int = 0, echo: int | None = None, vibrato: str = "443") -> None:
    """A line, bar by bar: scoops and fall-offs as written, a late vibrato on the long notes (on its
    third row), cleared on the next plain note (⚠ 4xy stays on until a 400)."""
    vib_on = False
    for offset, notes in enumerate(bars_of):
        index = start_bar + offset
        frame, row = first + index // FRAME_BARS, (index % FRAME_BARS) * BAR
        for item in notes:
            note, length = item[0], item[1]
            fx = item[2] if len(item) > 2 else None
            if length == 0:
                song.put(channel, frame, row - 1, fx=fx)
                continue
            if note == "r":
                song.put(channel, frame, row, "===", fx="400" if vib_on else None)
                vib_on = False
            else:
                if fx is None and vib_on:
                    fx, vib_on = "400", False
                song.put(channel, frame, row, transpose(note, shift), inst, vol, fx)
                if echo is not None:
                    song.put("pulse2", frame, row + 1, transpose(note, shift), echo, 15)
                if length >= 3 and not (fx or "").startswith(("Q", "R")):
                    song.put(channel, frame, row + 2, fx=vibrato)
                    vib_on = True
            row += length


# --- the surface ------------------------------------------------------------------------------

def surface() -> Song:
    s = new_song("Dagat", (
        "Dagat, the surface: a Visayan rowing song in 3/4 after the balitaw, a bamboo flute over",
        "rondalla guitar and waves, the paddle's pull on every downbeat. Original. G major, ~95 BPM.",
    ))
    flute = s.inst_vrc7("bamboo flute", patch=4)
    guitar = s.inst_vrc7("rondalla guitar", patch=2)
    vibes = s.inst_vrc7("vibraphone crest", patch=11)
    clarinet = s.inst_vrc7("clarinet answer", patch=5)
    # ⚠ THE BASS IS ON THE VRC7, NOT THE TRIANGLE. The triangle cannot be turned down, and held it
    # measured -17 dBFS alone, 8 dB over the flute: the tune sank under it (Piyesta's lesson too).
    bass = s.inst_vrc7("bass", patch=13)
    wave_pluck = s.inst_2a03("wave", volume=[7, 7, 6, 6, 5, 5, 4, 4, 4, 3, 3, 3, 2, 2, 2, 1], duty=[2])
    echo = s.inst_2a03("echo", volume=[5, 5, 4, 4, 4, 3, 3, 3, 2, 2, 2, 1, 1, 0], duty=[2])
    shimmer = {kind: s.inst_2a03(f"{kind} shimmer", volume=[4, 4, 4, 3, 3, 3, 3, 2], arpeggio=steps,
                                 duty=[1])
               for kind, steps in {"maj7": [0, 4, 7, 11], "m7": [0, 3, 7, 10],
                                   "7": [0, 4, 7, 10]}.items()}
    # The paddle: a soft, short thump (a falling triangle, cut after four ticks) and a swell of
    # water pulled past the blade.
    thump = s.inst_2a03("paddle thump", volume=[15, 15, 15, 15, 0], arpeggio=[24, 17, 12, 7], fixed=False)
    pull = s.inst_2a03("paddle pull", volume=[1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 6, 5, 5, 5, 4, 4, 4, 3,
                                              3, 3, 3, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 0], duty=[0])
    chick = s.inst_2a03("strum chick", volume=[4, 3, 2, 1, 0], duty=[0])

    def accompany(sequence, first: int, *, guitar_from: int = 0, crest: bool = True) -> None:
        for index, frame, row, halves in bars(sequence, first):
            span = BAR // len(halves)
            for half, chord in enumerate(halves):
                start = row + half * span
                _, steps, voicing, (root, fifth) = CHORDS[chord]
                kind = "maj7" if 11 in steps else ("m7" if 3 in steps else "7")
                tones = wave(chord)
                # The bass: the root on one, the fifth on three (on a split, the root alone).
                s.put("fm5", frame, start, root, bass, 12)
                if span == BAR:
                    s.put("fm5", frame, start + 4, fifth, bass, 11)
                if half == 0:
                    s.put("triangle", frame, start, "D3", thump)
                if first > 0 and index in SHIMMER_BARS:
                    s.put("pulse1", frame, start, tones[0], shimmer[kind], 15, "V01")
                else:
                    shape = [tones[0], tones[1], tones[2], tones[3], tones[2], tones[1]][:span]
                    for step, note in enumerate(shape):
                        s.put("pulse1", frame, start + step, note, wave_pluck, 15 if step == 0 else 13,
                              "V02" if step == 0 else None)
                # The vibraphone catches the crest -- on fm6, which the clarinet takes for the last
                # phrase.
                if crest and span == BAR and not (first > 0 and index in ANSWER):
                    s.put("fm6", frame, start + 3, tones[3] if midi(tones[3]) < midi("C6") else tones[2],
                          vibes, 9)
                    s.put("fm6", frame, start + 5, "===")
                if index >= guitar_from:
                    # The strum: two and three, and a light upstroke after three; one row each.
                    hits = ((2, 12), (4, 11), (5, 8)) if span == BAR else ((1, 11), (2, 8))
                    for hit, vol in hits:
                        for channel, note in zip(("fm2", "fm3", "fm4"), voicing):
                            s.put(channel, frame, start + hit, note, guitar, vol)
                            s.put(channel, frame, start + hit + 1, "===")
            # The paddle's pull across the downbeat, and the strum's chick on three.
            s.put("noise", frame, row, "4-#", pull, 15)
            if index >= guitar_from:
                s.put("noise", frame, row + 4, "6-#", chick, 6)

    accompany(INTRO, 0, guitar_from=2)
    accompany(LOOP, 1)
    lead(s, "fm1", flute, 14, [PICKUP], 0, 3)
    lead(s, "fm1", flute, 14, TUNE, 1, echo=echo)
    for index, notes in ANSWER.items():
        lead(s, "fm6", clarinet, 12, [notes], 1, index)
    return s


# --- the deep: the same piece from under the water --------------------------------------------

def deep() -> Song:
    s = new_song("Dagat, below", (
        "Dagat, below the surface: the rowing song heard from under the water. Held low flutes,",
        "slow waves an octave down, a far clarinet and a soft bell. No drums, no noise.",
    ))
    pad = s.inst_vrc7("low flute pad", patch=4)
    bell = s.inst_vrc7("far bell", patch=9)
    clarinet = s.inst_vrc7("far clarinet", patch=5)
    bass = s.inst_vrc7("held bass", patch=13)
    slow = s.inst_2a03("slow wave", volume=[5, 5, 5, 4, 4, 4, 4, 3, 3, 3, 3, 3, 2, 2, 2, 2, 2, 1],
                       duty=[2])
    under = s.inst_2a03("its echo", volume=[2, 2, 2, 2, 2, 1, 1, 1, 1, 0], duty=[2])
    struck = set()

    for sequence, first in ((INTRO, 0), (LOOP, 1)):
        for index, frame, row, halves in bars(sequence, first):
            span = BAR // len(halves)
            for half, chord in enumerate(halves):
                start = row + half * span
                _, _, voicing, (root, _) = CHORDS[chord]
                # The chord held, gliding from the last one: never struck again after the first.
                for channel, note in zip(("fm2", "fm3", "fm4"), voicing):
                    s.put(channel, frame, start, note, pad, 13, "304" if channel in struck else None)
                    struck.add(channel)
                s.put("fm6", frame, start, root, bass, 12)
                tones = wave(chord, octave_down=True)
                for step, note in enumerate([tones[0], tones[2], tones[1]][: span // 2]):
                    s.put("pulse1", frame, start + 2 * step, note, slow, 15, "V02" if step == 0 else None)
                    s.put("pulse2", frame, start + 2 * step + 1, note, under, 15, "V02" if step == 0 else None)
            # A soft bell far off on every other bar's downbeat, the chord's top, low.
            if index % 2 == 1:
                s.put("fm5", frame, row, transpose(voicing[-1], 0), bell, 10)
                s.put("fm5", frame, row + 4, "===")
    # A breath of the slow vibrato on the held chord, as if the water moved it.
    for frame in range(FRAMES):
        s.put("fm4", frame, 1, fx="423")
    clarinet_vol = 12
    lead(s, "fm1", clarinet, clarinet_vol, [PICKUP], 0, 3, shift=-12, vibrato="423")
    lead(s, "fm1", clarinet, clarinet_vol, TUNE, 1, shift=-12, vibrato="423")
    return s


# --- the waves --------------------------------------------------------------------------------

def waves() -> Song:
    s = Song("Dagat waves", frames=1, rows=128, speed=6, loop_to=0, comments=(
        "Dagat's waves: long dark swells of noise at uneven gaps, under the surface music.",
    ))
    # A wave: rising for a second and more, then running back for two; between, the faint wash.
    rise = [1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 6, 6, 6, 6, 6, 6, 6]
    fall = [6, 6, 6, 6, 5, 5, 5, 5, 5, 5, 4, 4, 4, 4, 4, 4, 4, 3, 3, 3, 3, 3, 3, 3, 3, 2, 2, 2, 2, 2,
            2, 2, 2, 2, 2, 2, 2, 1]
    swell = s.inst_2a03("wave", volume=[v for v in rise for _ in (0, 1)] + [v for v in fall for _ in (0, 1, 2)],
                        duty=[0])
    for row, pitch, vol in ((0, "2-#", 12), (37, "3-#", 10), (70, "1-#", 11), (101, "2-#", 9)):
        s.put("noise", 0, row, pitch, swell, vol)
    return s


def looped_arpeggios(text: str, count: int) -> str:
    """famitext writes macros without a loop; a chord's arpeggio must cycle for as long as it is
    held, so the first `count` arpeggio macros (the shimmer's) loop back to their first step."""
    lines = []
    for line in text.splitlines():
        parts = line.split()
        if line.startswith("MACRO 1 ") and int(parts[2]) < count:
            parts[3] = "0"
            line = " ".join(parts)
        lines.append(line)
    return "\n".join(lines)


Path(sys.argv[2]).write_text(looped_arpeggios(surface().text(), 3))
Path(sys.argv[3]).write_text(deep().text())
Path(sys.argv[4]).write_text(waves().text())
print("wrote", *sys.argv[2:5])
