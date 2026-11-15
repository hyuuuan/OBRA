"""Scaffolding: THE STYLE TEST Kent approved (2026-11-15: "yes, go with it") -- jazzy chords, swing,
slides, energy, after a Fearofdark track he likes. A first sketch of Piyesta's fiesta music, which
Piyesta later outgrew (it is a Sinulog drum corps now), kept as the recipe for the style itself:

- swing: `song.swing(16, 8)`, long-short eighths, a 24-tick beat (~150 BPM);
- jazz changes (maj7, m7, dominant 7, m6) as four-note pulse arpeggios whose macros loop;
- a VRC7 trumpet lead that scoops into long notes (Qxy), falls off their ends (Rxy) and glides
  (3xx), with a soft pulse echo an eighth behind;
- piano comping on the Charleston (the downbeat and the and-of-two), short;
- a walking triangle bass with a kick thump on one and three, the ride's "ding, ding-da ding",
  dark noise only;
- xylophone fills at the ends of phrases.

Each remaining level puts these on top of its own tradition (AUDIO_PLAN.md, "Style").

    compose_style_sketch.py TOOLS_DIR OUT.txt
"""
import sys
from pathlib import Path

sys.path.insert(0, sys.argv[1])
from famitext import Song, transpose  # noqa: E402

BAR = 8                          # 2 rows a beat: each row a swung eighth
song = Song("Piyesta (sketch)", frames=5, rows=32, speed=12, loop_to=1, comments=(
    "Piyesta, a sketch in the new style: swing, jazz changes, a banda trumpet that slides.",
    "Original; no borrowed melody. F major, ~150 BPM, swung 2:1.",
))
song.swing(16, 8)                # long-short eighths: a triplet swing, a beat of 24 ticks

TRUMPET = song.inst_vrc7("banda trumpet", patch=7)
HORN2 = song.inst_vrc7("second trumpet", patch=7)
PIANO = song.inst_vrc7("comping piano", patch=3)
XYLO = song.inst_vrc7("kulintang fill", patch=10)
ARP = {kind: song.inst_2a03(f"{kind} arp", volume=[7, 6, 6, 5, 5, 5, 4], arpeggio=steps,
                            duty=[1])
       for kind, steps in {"maj7": [0, 4, 7, 11], "m7": [0, 3, 7, 10], "7": [0, 4, 7, 10],
                           "m6": [0, 3, 7, 9], "6": [0, 4, 7, 9]}.items()}
# Arpeggios loop: rebuild their macros with a loop point (famitext writes none by default).
# The triangle cannot be turned down, so the bass is short: a plucked walk, not a held one.
WALK = song.inst_2a03("walking bass", volume=[15] * 6 + [0])
KICK = song.inst_2a03("bass and kick", volume=[15] * 6 + [0], arpeggio=[24, 12, 0])
RIDE = song.inst_2a03("ride", volume=[6, 4, 3, 2, 1, 0], duty=[0])
SNARE = song.inst_2a03("snare", volume=[13, 10, 8, 6, 4, 3, 2, 1, 0], duty=[0])
ECHO = song.inst_2a03("echo", volume=[4, 4, 3, 3, 2, 2, 1, 0], duty=[2])

# chord -> (arp kind, arp root, piano voicing, bass walk for the bar's four beats)
CHORDS = {
    "Fmaj7": ("maj7", "F4", ("A4", "E5", "G5"), ("F3", "A3", "C4", "D4")),
    "Dm7": ("m7", "D4", ("F4", "C5", "E5"), ("D3", "F3", "A3", "F#3")),
    "Gm7": ("m7", "G4", ("A#3", "F4", "A4"), ("G3", "A#3", "D4", "B3")),
    "C7": ("7", "C4", ("E4", "A#4", "D5"), ("C3", "E3", "G3", "E3")),
    "Bbmaj7": ("maj7", "A#3", ("D4", "A4", "C5"), ("A#2", "D3", "F3", "A3")),
    "Bbm6": ("m6", "A#3", ("C#4", "G4", "C5"), ("A#2", "C#3", "F3", "G#3")),
    "Am7": ("m7", "A3", ("C4", "G4", "B4"), ("A2", "C3", "E3", "D#3")),
    "D7": ("7", "D4", ("F#4", "C5", "E5"), ("D3", "F#3", "A3", "C#3")),
    "F6": ("6", "F4", ("A4", "D5", "G5"), ("F3", "A3", "D4", "G3")),
}
INTRO = ["Gm7", "C7", "Gm7", "C7"]
LOOP = ["Fmaj7", "Dm7", "Gm7", "C7",  "Fmaj7", "Dm7", ("Gm7", "C7"), "Fmaj7",
        "Bbmaj7", "Bbm6", "Am7", "D7",  "Gm7", "C7", "F6", "C7"]

# The lead, in eighths: (note, rows[, effect]). Effects: Q/R slides (a scoop is the note below
# with Qxy; a fall-off is Rxy on the note's last eighth, given as a 0-row marker), 3xx glides.
LEAD = [
    [("C5", 1), ("E5", 1), ("G5", 2, "305"), ("G5", 3, "Q22"), ("G5", 1, "300")],
    [("F5", 2), ("E5", 1), ("D5", 1), ("C5", 3), ("C5", 0, "R83"), ("r", 1)],
    [("D5", 1), ("F5", 1), ("A5", 2), ("A#5", 3, "Q22"), ("A#5", 1)],
    [("A5", 2), ("G5", 2), ("E5", 3), ("E5", 0, "R63"), ("r", 1)],
    [("C5", 1), ("E5", 1), ("G5", 2), ("G5", 3, "Q22"), ("C6", 1)],
    [("D6", 2, "305"), ("C6", 1), ("A5", 1, "300"), ("F5", 3), ("F5", 0, "R83"), ("r", 1)],
    [("G5", 1), ("A5", 1), ("A#5", 2), ("E5", 1), ("G5", 1), ("A#5", 2, "Q12")],
    [("A5", 6), ("A5", 0, "R44"), ("r", 2)],
    [("D5", 1), ("F5", 1), ("A5", 2), ("A#5", 4, "Q22")],
    [("C#6", 2), ("C6", 1), ("A#5", 1), ("G5", 3), ("G5", 0, "R83"), ("r", 1)],
    [("E5", 1), ("G5", 1), ("C6", 2), ("A5", 2), ("G5", 2)],
    [("F#5", 2), ("A5", 2), ("C6", 3, "305"), ("A5", 1, "300")],
    [("A#5", 2), ("A5", 1), ("G5", 1), ("F5", 2), ("D5", 2)],
    [("E5", 1), ("G5", 1), ("A#5", 2), ("C6", 3, "Q22"), ("C6", 1)],
    [("A5", 4), ("F5", 2), ("D5", 2)],
    [("E5", 2), ("G5", 2), ("C5", 2), ("C5", 0, "R83"), ("r", 2)],
]
# The last phrase, harmonised a third or sixth under, as a banda's second trumpet would.
HARMONY = {
    12: [("G5", 2), ("F5", 1), ("E5", 1), ("D5", 2), ("A#4", 2)],
    13: [("C5", 1), ("E5", 1), ("G5", 2), ("A5", 3), ("A5", 1)],
    14: [("F5", 4), ("C5", 2), ("A4", 2)],
    15: [("C5", 2), ("E5", 2), ("G4", 2), ("r", 2)],
}
FILLS = {3: ["C6", "A5", "G5", "F5"], 7: ["D6", "C6", "A5", "G5"], 11: ["A5", "G5", "F5", "D5"]}


def bar_at(first: int, index: int) -> tuple[int, int]:
    return first + index // 4, (index % 4) * BAR


def lead_line(channel: str, inst: int, vol: int, bars, first: int, start_bar: int = 0) -> None:
    for offset, notes in enumerate(bars):
        frame, row = bar_at(first, start_bar + offset)
        for item in notes:
            note, length = item[0], item[1]
            fx = item[2] if len(item) > 2 else None
            if length == 0:          # a marker: the effect on the previous note's last eighth
                song.put(channel, frame, row - 1, fx=fx)
                continue
            if note == "r":
                song.put(channel, frame, row, "===")
            else:
                song.put(channel, frame, row, note, inst, vol, fx)
                # The echo: a soft round pulse an eighth behind.
                if channel == "fm1":
                    song.put("pulse2", frame, row + 1, note, ECHO, 15)
            row += length


def comp(chords, first: int) -> None:
    for index, entry in enumerate(chords):
        frame, row = bar_at(first, index)
        halves = list(entry) if isinstance(entry, tuple) else [entry]
        for half, chord in enumerate(halves):
            kind, arp_root, voicing, walk = CHORDS[chord]
            start = row + half * (BAR // len(halves))
            # Arpeggio, held through the chord.
            song.put("pulse1", frame, start, arp_root, ARP[kind], 15, "V01" if index == 0 and half == 0 else None)
            # Comping on the Charleston: the downbeat and the and-of-two, short.
            hits = (0, 3) if len(halves) == 1 else (0,)
            for hit in hits:
                for channel, note in zip(("fm3", "fm4", "fm5"), voicing):
                    song.put(channel, frame, start + hit, note, PIANO, 11)
                    song.put(channel, frame, start + hit + 1, "===")
            beats = range(4) if len(halves) == 1 else range(2)
            for beat in beats:
                note = walk[beat] if len(halves) == 1 else walk[beat * 2]
                song.put("triangle", frame, start + 2 * beat, note, KICK if beat % 2 == 0 else WALK)
        # Drums: the ride's "ding, ding-da ding", the snare on two and four.
        for r in (0, 2, 3, 4, 6, 7):
            song.put("noise", frame, row + r, "7-#", RIDE, 15)
        for r in (2, 6):
            song.put("noise", frame, row + r, "4-#", SNARE, 15)


comp(INTRO, 0)
comp(LOOP, 1)
# A chromatic pickup into the tune, gliding.
for r, note in zip((4, 5, 6, 7), ("G4", "A4", "A#4", "B4")):
    song.put("fm1", 0, 3 * BAR + r, note, TRUMPET, 12, "302" if r == 4 else None)
song.put("fm1", 1, 0, fx="300")
lead_line("fm1", TRUMPET, 14, LEAD, 1)
for index, notes in HARMONY.items():
    lead_line("fm2", HORN2, 12, [notes], 1, index)
for index, notes in FILLS.items():
    frame, row = bar_at(1, index)
    for step, note in enumerate(notes):
        song.put("fm6", frame, row + 4 + step, note, XYLO, 12)
    song.put("fm6", frame, row + 8, "===")

text = song.text()
# Loop each arpeggio macro back to its first step, so the chord cycles for as long as it is held.
lines = []
for line in text.splitlines():
    parts = line.split()
    if line.startswith("MACRO 1 ") and int(parts[2]) < len(ARP):   # the chords, not the kick
        parts[3] = "0"
        line = " ".join(parts)
    lines.append(line)
Path(sys.argv[2]).write_text("\n".join(lines))
print("wrote", sys.argv[2])
