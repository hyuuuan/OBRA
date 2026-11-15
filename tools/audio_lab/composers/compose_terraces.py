"""Write Payyo's "Up the Green Steps" tracker module.

    compose_terraces.py TOOLS_DIR OUT.txt
"""
import sys
from pathlib import Path

sys.path.insert(0, sys.argv[1])
from famitext import Song  # noqa: E402

BAR = 8
BARS_PER_PATTERN = 4
song = Song("Payyo - Up the Green Steps", frames=8, rows=BAR * BARS_PER_PATTERN,
            speed=18, comments=(
                "Original music for Payyo, the green terraces.",
                "D major, 112 BPM, lightly swung eighths. A A' B A''.",
                "A VRC7 flute hook, soft keys, and a sparse 2A03 drum groove.",
            ))
song.swing(18, 14)

FLUTE = song.inst_vrc7("Terrace flute", patch=4)
KEYS = song.inst_vrc7("Soft keys", patch=3)
BASS = song.inst_vrc7("Finger bass", patch=13)
GONG = song.inst_vrc7("Short gangsa", patch=0, regs=(0x03, 0x01, 0x1E, 0x04, 0xF6, 0xF5, 0x37, 0x6A))
KICK = song.inst_2a03("Soft kick", volume=[15, 15, 12, 9, 0], arpeggio=[0, -4, -8, -12])
HAT = song.inst_2a03("Soft hat", volume=[4, 3, 2, 1, 0], duty=[0])
SNARE = song.inst_2a03("Brush snare", volume=[8, 7, 6, 5, 4, 3, 2, 1, 0], duty=[0])

# Root, bass answer, and close upper voicing. Every chord shares the D major scale.
CHORDS = {
    "Dmaj9":  ("D2",  "A2",  ("F#3", "C#4", "E4")),
    "A/C#":   ("C#2", "A2",  ("A3",  "C#4", "E4")),
    "Bm7":    ("B1",  "F#2", ("A3",  "D4",  "F#4")),
    "Gmaj7":  ("G2",  "D3",  ("B3",  "D4",  "F#4")),
    "Em7":    ("E2",  "B2",  ("G3",  "B3",  "D4")),
    "A7sus4": ("A2",  "E3",  ("G3",  "D4",  "E4")),
    "A13":    ("A2",  "E3",  ("G3",  "C#4", "F#4")),
}

VERSE_HARMONY = ("Dmaj9", "A/C#", "Bm7", "Bm7", "Gmaj7", "Gmaj7", "Em7")

# (eighth, pitch, duration in eighths). Three ascending notes and their falling answer
# carry all three A sections. The second half starts the same figure a fourth higher.
HOOK = (
    ((1, "F#4", 1), (2, "A4", 1), (3, "B4", 3), (7, "A4", 1)),
    ((0, "E4", 4), (5, "F#4", 1), (6, "E4", 1)),
    ((0, "F#4", 3), (3, "A4", 3), (7, "B4", 1)),
    ((0, "C#5", 2), (2, "B4", 4)),
    ((1, "B4", 1), (2, "D5", 1), (3, "E5", 3), (7, "D5", 1)),
    ((0, "B4", 4), (5, "A4", 1), (6, "G4", 2)),
)

VERSE_ENDING = (
    ((0, "G4", 2), (3, "B4", 3), (7, "A4", 1)),
    ((0, "E4", 5),),
)
SECOND_ENDING = (
    ((0, "G4", 2), (3, "B4", 2), (6, "D5", 2)),
    ((0, "C#5", 3), (4, "B4", 1), (5, "A4", 2)),
)
LAST_ENDING = (
    ((0, "G4", 2), (3, "B4", 2), (6, "A4", 2)),
    ((0, "F#4", 2), (3, "E4", 3)),
)

BRIDGE_HARMONY = ("Gmaj7", "Gmaj7", "Dmaj9", "Dmaj9", "Em7", "Em7", "A7sus4", "A7sus4")
BRIDGE = (
    ((0, "D5", 6),),
    ((1, "B4", 3), (5, "A4", 2)),
    ((0, "F#4", 6),),
    ((1, "A4", 2), (4, "B4", 3)),
    ((0, "G4", 4), (5, "B4", 2)),
    ((0, "D5", 5), (6, "B4", 2)),
    ((0, "A4", 3), (4, "G4", 2)),
    ((0, "E4", 6),),
)

HARMONY = (
    *VERSE_HARMONY, "A7sus4", *VERSE_HARMONY, "A13", *BRIDGE_HARMONY, *VERSE_HARMONY, "A13",
)
MELODY = HOOK + VERSE_ENDING + HOOK + SECOND_ENDING + BRIDGE + HOOK + LAST_ENDING
GONG_ANSWERS = {3: (6, "F#4"), 7: (6, "A4"), 11: (6, "F#4"),
                16: (6, "G4"), 18: (6, "D4"), 23: (6, "A4"), 27: (6, "F#4")}


def write_flute(frame, start, notes):
    for step, pitch, duration in notes:
        song.put("fm1", frame, start + step, pitch, FLUTE, 15 if duration >= 2 else 13)
        song.put("fm1", frame, start + step + duration, "===")


def write_harmony(bar, frame, start, chord):
    root, answer, voicing = CHORDS[chord]
    # The short second stab is syncopated, with no chord changes within the bar.
    chord_hits = ((0, 5, 11),)
    if bar % 2 == 0 and not 16 <= bar < 24:
        chord_hits = ((0, 3, 11), (5, 2, 10))
    for step, duration, volume in chord_hits:
        for channel, pitch in zip(("fm3", "fm4", "fm5"), voicing):
            song.put(channel, frame, start + step, pitch, KEYS, volume)
            song.put(channel, frame, start + step + duration, "===")

    song.put("fm6", frame, start, root, BASS, 13)
    song.put("fm6", frame, start + 4, "===")
    if not 16 <= bar < 20:
        song.put("fm6", frame, start + 5, answer if bar % 2 == 0 else root, BASS, 11)
        song.put("fm6", frame, start + 7, "===")

    if bar in GONG_ANSWERS:
        step, pitch = GONG_ANSWERS[bar]
        song.put("fm2", frame, start + step, pitch, GONG, 11)
        song.put("fm2", frame, start + 7, "===")


def write_drums(bar, frame, start):
    # Back out for four bars so the bridge begins with the flute and keys in the foreground.
    if 16 <= bar < 20:
        song.put("noise", frame, start + 5, "7-#", HAT, 12)
        return

    song.put("triangle", frame, start, "F2", KICK)
    song.put("triangle", frame, start + (4 if bar % 2 == 0 else 5), "F2", KICK)
    for step in (2, 6):
        song.put("noise", frame, start + step, "4-#", SNARE, 13)
    song.put("noise", frame, start + 3, "7-#", HAT, 12)
    if bar % 2 == 0:
        song.put("noise", frame, start + 7, "7-#", HAT, 11)


def main():
    for bar, (chord, notes) in enumerate(zip(HARMONY, MELODY, strict=True)):
        frame, start = song.at(0, bar * BAR)
        write_flute(frame, start, notes)
        write_harmony(bar, frame, start, chord)
        write_drums(bar, frame, start)
    # FamiStudio's importer requires the standard FamiTracker version header.
    _, _, module = song.text().partition("\n")
    Path(sys.argv[2]).write_text("# FamiTracker text export 0.4.2\n" + module, encoding="utf-8")


if __name__ == "__main__":
    main()
