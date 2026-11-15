#!/usr/bin/env python3
"""Write a FamiTracker text module from Python: the helper every module in audio/ is written with.

The `.txt` it writes is the source (a tracker imports it; tools/build_music.py renders it). A
song script that uses this is scaffolding: run it once, commit the `.txt`, and edit that from
then on -- by hand or in Dn-FamiTracker -- so a module never has two sources.

    from famitext import Song
    song = Song("menu", frames=5, loop_to=1, speed=7)
    flute = song.inst_vrc7("bamboo flute", patch=4)
    song.line("fm1", frame=1, row=0, notes=[("A4", 2), ("D5", 2), ("r", 4)], inst=flute, vol=14)
    Path("audio/music/menu.txt").write_text(song.text())

Notes are written "C4", "F#5", "A#3" (sharps only), "r" for a rest in `line`, "---" (halt) and
"===" (release) as themselves, and noise pitches as the tracker writes them ("5-#").
A row past the end of a frame lands in the next; past the last frame, in `loop_to`, which is
where the song goes next when it loops -- so an echo or a pickup crosses the seam as it plays.
"""

from __future__ import annotations

from dataclasses import dataclass, field

CHANNELS = ("pulse1", "pulse2", "triangle", "noise", "dpcm", "fm1", "fm2", "fm3", "fm4", "fm5", "fm6")
NOTES = ("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")
MACRO_KINDS = {"volume": 0, "arpeggio": 1, "pitch": 2, "duty": 4}
EMPTY = "... .. . ..."


def transpose(note: str, semitones: int) -> str:
    name, octave = note[:-1], int(note[-1])
    n = NOTES.index(name) + 12 * octave + semitones
    if not 0 <= n < 96:
        raise ValueError(f"{note} + {semitones} is outside C0..B7")
    return f"{NOTES[n % 12]}{n // 12}"


def tracker_note(note: str, channel: str) -> str:
    """'E5' -> 'E-5', 'F#5' -> 'F#5'; halts, releases and noise pitches pass as written."""
    if note in ("---", "===") or channel == "noise":
        return note
    name, octave = note[:-1], note[-1]
    if name not in NOTES or not octave.isdigit():
        raise ValueError(f"{note!r} is not a note")
    return (name + "-" if len(name) == 1 else name) + octave


@dataclass
class Song:
    title: str
    frames: int
    rows: int = 64
    speed: int = 6
    tempo: int = 150
    loop_to: int | None = 0         # None: a one-shot, which must end with Cxx
    comments: tuple[str, ...] = ()
    _macros: list[str] = field(default_factory=list)
    _insts: list[str] = field(default_factory=list)
    _grid: list[list[list[str]]] = field(default_factory=list)

    def __post_init__(self) -> None:
        self._grid = [[[EMPTY for _ in CHANNELS] for _ in range(self.rows)]
                      for _ in range(self.frames)]

    # --- instruments ---------------------------------------------------------------------

    def macro(self, kind: str, values: list[int], loop: int = -1, release: int = -1,
              setting: int = 0) -> int:
        index = sum(1 for m in self._macros if m.split()[1] == str(MACRO_KINDS[kind]))
        self._macros.append(f"MACRO {MACRO_KINDS[kind]} {index} {loop} {release} {setting} : "
                            + " ".join(str(v) for v in values))
        return index

    def inst_2a03(self, name: str, *, volume: list[int] | None = None, arpeggio: list[int] | None = None,
            fixed: bool = False, pitch: list[int] | None = None, duty: list[int] | None = None) -> int:
        seq = [self.macro("volume", volume) if volume else -1,
               self.macro("arpeggio", arpeggio, setting=1 if fixed else 0) if arpeggio else -1,
               self.macro("pitch", pitch) if pitch else -1,
               -1,
               self.macro("duty", duty) if duty else -1]
        return self._inst(f'INST2A03 {{i}} {" ".join(str(s) for s in seq)} "{name}"')

    def inst_vrc7(self, name: str, *, patch: int, regs: tuple[int, ...] = (0,) * 8) -> int:
        if not 0 <= patch <= 15 or len(regs) != 8:
            raise ValueError("a VRC7 instrument is a patch 0..15 and eight registers")
        return self._inst(f'INSTVRC7 {{i}} {patch} {" ".join(f"{r:02X}" for r in regs)} "{name}"')

    def _inst(self, template: str) -> int:
        index = len(self._insts)
        self._insts.append(template.format(i=index))
        return index

    # --- notes ---------------------------------------------------------------------------

    def at(self, frame: int, row: int) -> tuple[int, int]:
        frame += row // self.rows
        row %= self.rows
        if frame >= self.frames:
            if self.loop_to is None:
                raise ValueError(f"row past the end of a one-shot (frame {frame})")
            frame = self.loop_to + (frame - self.frames) % (self.frames - self.loop_to)
        return frame, row

    def put(self, channel: str, frame: int, row: int, note: str | None = None,
            inst: int | None = None, vol: int | None = None, fx: str | None = None) -> None:
        if channel not in CHANNELS:
            raise ValueError(f"no channel {channel!r}")
        if fx is not None and len(fx) != 3:
            raise ValueError(f"an effect is three characters, not {fx!r}")
        frame, row = self.at(frame, row)
        cell = self._grid[frame][row][CHANNELS.index(channel)].split()
        if note is not None:
            cell[0] = tracker_note(note, channel)
        if inst is not None:
            cell[1] = f"{inst:02X}"
        if vol is not None:
            cell[2] = f"{vol:X}"
        if fx is not None:
            cell[3] = fx
        self._grid[frame][row][CHANNELS.index(channel)] = " ".join(cell)

    def line(self, channel: str, frame: int, row: int, notes: list[tuple[str, int]], inst: int,
             vol: int, *, rest: str = "===", held_fx: tuple[int, str, str] | None = None) -> int:
        """Notes one after another from (frame, row): (note, rows), "r" a rest. `held_fx` is
        (after, effect, cancel): on notes held that long, `effect` lands `after` rows in and
        `cancel` on the next note -- a late vibrato. Returns the row it ended on."""
        for note, length in notes:
            if note == "r":
                self.put(channel, frame, row, rest, fx=held_fx[2] if held_fx else None)
            else:
                self.put(channel, frame, row, note, inst, vol, held_fx[2] if held_fx else None)
                if held_fx and length > held_fx[0]:
                    self.put(channel, frame, row + held_fx[0], fx=held_fx[1])
            row += length
        return row

    # --- the module ----------------------------------------------------------------------

    def text(self) -> str:
        if self.loop_to is not None:
            # The loop's jump rides pulse 1's last cell, which must have no effect of its own.
            last = self._grid[self.frames - 1][self.rows - 1][0].split()[3]
            if last not in ("...", f"B{self.loop_to:02X}"):
                raise ValueError(f"pulse 1's last cell already holds {last}; the loop needs it")
            self.put("pulse1", self.frames - 1, self.rows - 1, fx=f"B{self.loop_to:02X}")
        out = ["# FamiTracker text export (written for O.B.R.A.; import with File > Import Text)",
               "", f'TITLE           "O.B.R.A. - {self.title}"', 'AUTHOR          "O.B.R.A. team"',
               'COPYRIGHT       "2026"', ""]
        out += [f'COMMENT "{c}"' for c in self.comments]
        out += ["", "MACHINE         0", "FRAMERATE       0", "EXPANSION       2",
                "VIBRATO         1", "SPLIT           32", "", *self._macros, "", *self._insts, "",
                f'TRACK  {self.rows}   {self.speed} {self.tempo} "{self.title}"',
                "COLUMNS : " + " ".join(["1"] * len(CHANNELS)), ""]
        out += [f"ORDER {f:02X} : " + " ".join([f"{f:02X}"] * len(CHANNELS)) for f in range(self.frames)]
        out.append("")
        for f in range(self.frames):
            out.append(f"PATTERN {f:02X}")
            out += [f"ROW {r:02X} : " + " : ".join(self._grid[f][r]) for r in range(self.rows)]
            out.append("")
        return "\n".join(out)
