#!/usr/bin/env python3
"""Render a FamiTracker text module (2A03 + VRC7) to audio, on a Mac, with no tracker.

The game's music is written as FamiTracker text modules: what Dn-FamiTracker writes with
File > Export Text and reads back with File > Import Text. FamiTracker runs only on Windows, and
Homebrew's Wine was disabled on 2026-09-01, so this plays the modules here instead:

- a sequencer that follows FamiTracker's playback rules (rows, speed and tempo, frames and
  jumps, instrument macros, and the effects in SUPPORTED_EFFECTS);
- the 2A03's pulses, triangle and noise, modelled from the nesdev wiki and integrated per sample
  so high notes do not alias;
- the VRC7 through emu2413 (tools/vendor/emu2413), the FM core family FamiTracker itself uses.

⚠ A module using anything outside that subset is REFUSED with the line it is on, never rendered
approximately: a module that sounds one way here and another in the tracker would be two songs.

The result is close to the tracker, not bit-identical: the 2A03 is mixed linearly (nesdev's
linear approximation) and vibrato's depth is FamiTracker's table in shape, not to the unit.
"""

from __future__ import annotations

import ctypes
import hashlib
import math
import shlex
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
from scipy.signal import lfilter, resample_poly

ROOT = Path(__file__).resolve().parent.parent
VENDOR = ROOT / "tools" / "vendor" / "emu2413"
HELPER = ROOT / "tools" / "famirender_opll.c"
BUILD = ROOT / "build" / "famirender"

# The vendored files as reviewed. A changed file is refused before it is ever compiled: see
# tools/vendor/emu2413/README.md for how to update them deliberately.
VENDOR_SHA256 = {
    "emu2413.c": "252462c355ab37afcd741093993dbe5d73a62895090c4ced979b80926687f440",
    "emu2413.h": "4c65875f5b6c1302e579c75984fa1657eb847e58c4e25f14c936e2ec81b3933d",
    "LICENSE": "8fb093f26ed0d78c8ca033bbec7063ac5b34c5d2475e6bd121d03ccfaaf2355f",
}
# -fwrapv: emu2413 shifts negative values left (lookup_exp_table's `~res << 1`), which C leaves
# undefined; UBSan caught it in the 2026-11-14 review. -fwrapv defines it as the two's-complement
# wrap the code assumes, so the optimiser can never take liberties with it.
CFLAGS = ["-O2", "-std=c99", "-fwrapv", "-Wall", "-Wextra", "-fPIC", "-shared",
          "-fstack-protector-strong", "-D_FORTIFY_SOURCE=2"]

CPU_HZ = 1789773              # the NTSC 2A03
OPLL_HZ = 3579545             # the VRC7's clock; emu2413 divides it by 72
OPLL_RATE = OPLL_HZ / 72.0    # 49716 Hz, the rate an F-number is defined against
FRAME_HZ = CPU_HZ / 29780.5   # one engine tick: an NTSC frame, 60.0988 Hz
RATE = 32000                  # output; the NES's own 14 kHz low-pass sits under its Nyquist
OVERSAMPLE = 4                # the 2A03 is integrated at 4x and decimated, so it does not alias

CHANNELS_2A03 = ("pulse1", "pulse2", "triangle", "noise", "dpcm")
CHANNELS_VRC7 = ("fm1", "fm2", "fm3", "fm4", "fm5", "fm6")
EXPANSION_VRC7 = 2

# Fxx speed/tempo, Bxx jump, Cxx halt, Dxx skip, Gxx delay, Sxx cut, Vxx duty, 0xy arpeggio,
# 4xy vibrato, Pxx fine pitch. Anything else is refused (see the module docstring).
SUPPORTED_EFFECTS = frozenset("FBCDGSV04P")

# nesdev's linear mixer approximation, per unit of channel level (0..15).
PULSE_GAIN = 0.00752
TRIANGLE_GAIN = 0.00851
NOISE_GAIN = 0.00494
# emu2413's int16 mix against the 2A03's: a full-volume FM note sits a little under a
# full-volume pulse (RMS 0.03-0.08 against 0.09, by patch), as the VRC7 does beside the 2A03.
FM_GAIN = 1.0 / 26000.0
MASTER_GAIN = 1.6
HIGHPASS_HZ = 30.0            # FamiTracker's default bass filter: DC out, the bass kept

PULSE_DUTY = (
    (0, 1, 0, 0, 0, 0, 0, 0),
    (0, 1, 1, 0, 0, 0, 0, 0),
    (0, 1, 1, 1, 1, 0, 0, 0),
    (1, 0, 0, 1, 1, 1, 1, 1),
)
TRIANGLE_STEPS = tuple(range(15, -1, -1)) + tuple(range(16))
NOISE_PERIODS = (4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068)

NOTE_NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
ACCIDENTALS = {"-": 0, ".": 0, "#": 1, "+": 1, "b": -1, "f": -1}
MACRO_KINDS = ("volume", "arpeggio", "pitch", "hipitch", "duty")

HALT = "halt"
RELEASE = "release"

# Commands that only describe the module, or that a Dn-FamiTracker export writes at their
# default. Any other command could change the sound, so it is refused.
IGNORED_COMMANDS = {"TITLE", "AUTHOR", "COPYRIGHT", "COMMENT", "N163CHANNELS", "BOOKMARK"}
MAX_SECONDS = 600.0


class ModuleError(ValueError):
    """The module cannot be rendered faithfully. The message names the line."""


# --- The module --------------------------------------------------------------------------------

@dataclass
class Macro:
    kind: str
    loop: int
    release: int
    setting: int
    values: list[int]


@dataclass
class Inst2A03:
    macros: dict[str, int]  # kind -> macro index


@dataclass
class InstVRC7:
    patch: int
    regs: tuple[int, ...]


@dataclass
class Cell:
    note: int | str | None = None   # MIDI number (C-4 = 60), noise pitch 0..15, HALT, RELEASE
    inst: int | None = None
    vol: int | None = None
    effects: list[tuple[str, int]] = field(default_factory=list)


@dataclass
class Track:
    rows: int
    speed: int
    tempo: int
    name: str
    columns: list[int] = field(default_factory=list)
    order: list[list[int]] = field(default_factory=list)
    patterns: dict[int, dict[int, list[Cell]]] = field(default_factory=dict)


@dataclass
class Module:
    channels: tuple[str, ...] = CHANNELS_2A03
    split: int = 32
    macros: dict[tuple[str, int], Macro] = field(default_factory=dict)
    instruments: dict[int, Inst2A03 | InstVRC7] = field(default_factory=dict)
    tracks: list[Track] = field(default_factory=list)

    def track(self, name: str | None = None) -> Track:
        if not self.tracks:
            raise ModuleError("the module has no TRACK")
        if name is None:
            return self.tracks[0]
        for track in self.tracks:
            if track.name == name:
                return track
        raise ModuleError(f"no TRACK named {name!r}")


def _int(token: str, where: str, lo: int, hi: int, base: int = 10) -> int:
    try:
        value = int(token, base)
    except ValueError:
        raise ModuleError(f"{where}: {token!r} is not a number") from None
    if not lo <= value <= hi:
        raise ModuleError(f"{where}: {value} is outside {lo}..{hi}")
    return value


def parse_note(token: str, channel: str, where: str) -> int | str | None:
    if token == "...":
        return None
    if token == "---":
        return HALT
    if token == "===":
        return RELEASE
    if len(token) != 3:
        raise ModuleError(f"{where}: {token!r} is not a note")
    if channel == "noise":
        if token[1:] != "-#":
            raise ModuleError(f"{where}: a noise note is written <hex>-#, not {token!r}")
        return _int(token[0], where, 0, 15, 16)
    name, accidental, octave = token[0].upper(), token[1], token[2]
    if name not in NOTE_NAMES or accidental not in ACCIDENTALS or not octave.isdigit():
        raise ModuleError(f"{where}: {token!r} is not a note")
    return 12 * (int(octave) + 1) + NOTE_NAMES[name] + ACCIDENTALS[accidental]


def parse_cell(text: str, channel: str, columns: int, where: str) -> Cell:
    tokens = text.split()
    if len(tokens) != 3 + columns:
        raise ModuleError(f"{where}: {channel} has {len(tokens)} fields, expected {3 + columns}")
    cell = Cell(note=parse_note(tokens[0], channel, where))
    if tokens[1] != "..":
        cell.inst = _int(tokens[1], where, 0, 63, 16)
    if tokens[2] not in (".", ".."):
        cell.vol = _int(tokens[2], where, 0, 15, 16)
    for token in tokens[3:]:
        if token == "...":
            continue
        letter = token[0].upper()
        if letter not in SUPPORTED_EFFECTS or len(token) != 3:
            raise ModuleError(f"{where}: effect {token!r} is not supported by famirender "
                              f"(supported: {''.join(sorted(SUPPORTED_EFFECTS))}xx)")
        cell.effects.append((letter, _int(token[1:], where, 0, 255, 16)))
    return cell


def parse_module(text: str) -> Module:
    module = Module()
    track: Track | None = None
    pattern: int | None = None
    external_opll = False
    for number, raw in enumerate(text.splitlines(), start=1):
        line = raw.strip()
        where = f"line {number}"
        if not line or line.startswith("#"):
            continue
        command = line.split(None, 1)[0].upper()
        if command in IGNORED_COMMANDS:
            continue
        if command == "ROW":
            if track is None or pattern is None:
                raise ModuleError(f"{where}: ROW before TRACK and PATTERN")
            head, *cells = line.split(":")
            row = _int(head.split()[1], where, 0, 255, 16)
            if row >= track.rows:
                raise ModuleError(f"{where}: row {row:02X} is past the pattern length")
            if len(cells) != len(module.channels):
                raise ModuleError(f"{where}: {len(cells)} channels, expected {len(module.channels)}")
            track.patterns.setdefault(pattern, {})[row] = [
                parse_cell(cell, channel, track.columns[index], where)
                for index, (cell, channel) in enumerate(zip(cells, module.channels))]
            continue
        tokens = shlex.split(line.replace(":", " : "))
        args = tokens[1:]
        if command == "MACHINE":
            if args != ["0"]:
                raise ModuleError(f"{where}: only NTSC (MACHINE 0) is rendered")
        elif command == "FRAMERATE":
            if args != ["0"]:
                raise ModuleError(f"{where}: only the default engine speed (FRAMERATE 0) is rendered")
        elif command == "PLAYBACKRATE":
            if args[:1] != ["0"]:
                raise ModuleError(f"{where}: only the default playback rate is rendered")
        elif command == "TUNING":
            if [int(a) for a in args] != [0, 0]:
                raise ModuleError(f"{where}: only standard tuning (TUNING 0 0) is rendered")
        elif command == "USEEXTERNALOPLL":
            external_opll = args != ["0"]
            if external_opll:
                raise ModuleError(f"{where}: an external OPLL patch set is not rendered")
        elif command == "OPLLPATCH":
            continue  # only meaningful with USEEXTERNALOPLL, refused above
        elif command == "VIBRATO":
            if args != ["1"]:
                raise ModuleError(f"{where}: only new-style vibrato (VIBRATO 1) is rendered")
        elif command == "SPLIT":
            module.split = _int(args[0], where, 0, 255)
        elif command == "EXPANSION":
            chips = _int(args[0], where, 0, 255)
            if chips not in (0, EXPANSION_VRC7):
                raise ModuleError(f"{where}: only the 2A03 and the VRC7 are rendered")
            module.channels = CHANNELS_2A03 + (CHANNELS_VRC7 if chips else ())
        elif command == "MACRO":
            kind = MACRO_KINDS[_int(args[0], where, 0, 4)]
            index = _int(args[1], where, 0, 127)
            loop, release = _int(args[2], where, -1, 253), _int(args[3], where, -1, 253)
            setting = _int(args[4], where, 0, 255)
            values = [_int(v, where, -128, 127) for v in args[6:]]
            if not values:
                raise ModuleError(f"{where}: an empty macro")
            if kind == "hipitch":
                raise ModuleError(f"{where}: hi-pitch macros are not rendered")
            module.macros[(kind, index)] = Macro(kind, loop, release, setting, values)
        elif command == "INST2A03":
            index = _int(args[0], where, 0, 63)
            seqs = [_int(v, where, -1, 127) for v in args[1:6]]
            module.instruments[index] = Inst2A03(
                {kind: seq for kind, seq in zip(MACRO_KINDS, seqs) if seq >= 0})
        elif command == "INSTVRC7":
            index = _int(args[0], where, 0, 63)
            patch = _int(args[1], where, 0, 15)
            regs = tuple(_int(v, where, 0, 255, 16) for v in args[2:10])
            module.instruments[index] = InstVRC7(patch, regs)
        elif command == "TRACK":
            track = Track(_int(args[0], where, 1, 256), _int(args[1], where, 1, 255),
                          _int(args[2], where, 1, 255), args[3] if len(args) > 3 else "")
            track.columns = [1] * len(module.channels)
            module.tracks.append(track)
            pattern = None
        elif command == "COLUMNS":
            if track is None:
                raise ModuleError(f"{where}: COLUMNS before TRACK")
            track.columns = [_int(v, where, 1, 4) for v in args[1:]]
            if len(track.columns) != len(module.channels):
                raise ModuleError(f"{where}: {len(track.columns)} columns for "
                                  f"{len(module.channels)} channels")
        elif command == "ORDER":
            if track is None:
                raise ModuleError(f"{where}: ORDER before TRACK")
            entry = [_int(v, where, 0, 255, 16) for v in args[2:]]
            if len(entry) != len(module.channels):
                raise ModuleError(f"{where}: an order of {len(entry)} for "
                                  f"{len(module.channels)} channels")
            track.order.append(entry)
        elif command == "PATTERN":
            if track is None:
                raise ModuleError(f"{where}: PATTERN before TRACK")
            pattern = _int(args[0], where, 0, 255, 16)
        else:
            raise ModuleError(f"{where}: {command} is not rendered by famirender")
    _validate(module)
    return module


def _validate(module: Module) -> None:
    for (kind, index), macro in module.macros.items():
        if kind == "arpeggio" and macro.setting not in (0, 1, 2):
            raise ModuleError(f"arpeggio macro {index}: unknown scheme {macro.setting}")
    for index, inst in module.instruments.items():
        if isinstance(inst, Inst2A03):
            for kind, seq in inst.macros.items():
                if (kind, seq) not in module.macros:
                    raise ModuleError(f"instrument {index:02X}: {kind} macro {seq} is not defined")
    for track in module.tracks:
        if not track.order:
            raise ModuleError(f"track {track.name!r} has no ORDER")
        for patterns in track.patterns.values():
            for cells in patterns.values():
                for channel, cell in zip(module.channels, cells):
                    if channel == "dpcm" and cell.note is not None:
                        raise ModuleError(f"track {track.name!r}: DPCM is not rendered")
                    if cell.inst is not None:
                        inst = module.instruments.get(cell.inst)
                        if inst is None:
                            raise ModuleError(f"track {track.name!r}: instrument "
                                              f"{cell.inst:02X} is not defined")
                        wants_fm = channel in CHANNELS_VRC7
                        if wants_fm != isinstance(inst, InstVRC7):
                            raise ModuleError(f"track {track.name!r}: instrument {cell.inst:02X} "
                                              f"is the wrong chip for {channel}")


# --- The VRC7 ----------------------------------------------------------------------------------

def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def compile_opll() -> Path:
    """Build emu2413 plus our render loop into build/famirender, once per source change."""
    for name, digest in VENDOR_SHA256.items():
        if _sha256(VENDOR / name) != digest:
            raise RuntimeError(f"tools/vendor/emu2413/{name} is not the reviewed file; "
                               "see tools/vendor/emu2413/README.md before building it")
    sources = [VENDOR / "emu2413.c", HELPER]
    key = hashlib.sha256(b"".join(p.read_bytes() for p in sources) + " ".join(CFLAGS).encode())
    suffix = ".dylib" if sys.platform == "darwin" else ".so"
    library = BUILD / f"libfamiopll-{key.hexdigest()[:12]}{suffix}"
    if not library.exists():
        BUILD.mkdir(parents=True, exist_ok=True)
        subprocess.run(["cc", *CFLAGS, "-I", str(VENDOR), *map(str, sources), "-o", str(library)],
                       check=True)
    return library


class Opll:
    """One VRC7, through emu2413, at the output rate."""

    _lib: ctypes.CDLL | None = None

    def __init__(self, rate: int) -> None:
        if Opll._lib is None:
            lib = ctypes.CDLL(str(compile_opll()))
            lib.OPLL_new.restype = ctypes.c_void_p
            lib.OPLL_new.argtypes = [ctypes.c_uint32, ctypes.c_uint32]
            lib.OPLL_delete.argtypes = [ctypes.c_void_p]
            lib.OPLL_setChipType.argtypes = [ctypes.c_void_p, ctypes.c_uint8]
            lib.OPLL_resetPatch.argtypes = [ctypes.c_void_p, ctypes.c_uint8]
            lib.OPLL_writeReg.argtypes = [ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint8]
            lib.famiopll_render.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int32]
            Opll._lib = lib
        self._chip = ctypes.c_void_p(Opll._lib.OPLL_new(OPLL_HZ, rate))
        if not self._chip:
            raise MemoryError("OPLL_new failed")
        Opll._lib.OPLL_setChipType(self._chip, 1)   # 1: VRC7 (no rhythm mode)
        Opll._lib.OPLL_resetPatch(self._chip, 1)    # the VRC7's own fifteen patches
        self._regs: dict[int, int] = {}

    def write(self, reg: int, value: int) -> None:
        if self._regs.get(reg) != value:
            self._regs[reg] = value
            Opll._lib.OPLL_writeReg(self._chip, reg, value & 0xFF)

    def force(self, reg: int, value: int) -> None:
        self._regs[reg] = value
        Opll._lib.OPLL_writeReg(self._chip, reg, value & 0xFF)

    def render(self, n: int) -> np.ndarray:
        out = np.zeros(n, dtype=np.int16)
        if n:
            Opll._lib.famiopll_render(self._chip, out.ctypes.data, n)
        return out

    def close(self) -> None:
        if self._chip:
            Opll._lib.OPLL_delete(self._chip)
            self._chip = ctypes.c_void_p()


# --- Playback state ----------------------------------------------------------------------------

def note_hz(note: float) -> float:
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def pulse_period(note: float) -> float:
    """FamiTracker's period for a note, unrounded (the triangle shares it, an octave down)."""
    return CPU_HZ / (16.0 * note_hz(note)) - 1.0


# FamiTracker's new-style vibrato depths, in period units at full swing.
VIBRATO_DEPTH = (1.0, 1.5, 2.5, 4.0, 5.0, 7.0, 10.0, 12.0, 14.0, 17.0, 22.0, 30.0, 44.0, 64.0,
                 96.0, 128.0)


class MacroPlayer:
    def __init__(self, macro: Macro) -> None:
        self.macro = macro
        self.pos = 0
        self.released = False

    def release(self) -> None:
        self.released = True
        if self.macro.release >= 0:
            self.pos = min(self.macro.release + 1, len(self.macro.values) - 1)

    def step(self) -> int:
        m = self.macro
        value = m.values[self.pos]
        nxt = self.pos + 1
        if m.release >= 0 and not self.released:
            if nxt > m.release:
                nxt = m.loop if 0 <= m.loop <= m.release else m.release
        elif nxt >= len(m.values):
            nxt = m.loop if m.loop >= 0 and (m.release < 0 or m.loop > m.release) \
                else len(m.values) - 1
        self.pos = min(nxt, len(m.values) - 1)
        return value


class Voice:
    """One channel's sequencer state: what FamiTracker's channel handler keeps."""

    def __init__(self, channel: str, module: Module) -> None:
        self.channel = channel
        self.module = module
        self.fm = channel in CHANNELS_VRC7
        self.note: int | None = None
        self.inst: int | None = None
        self.vol = 15
        self.on = False            # a note is sounding (2A03) or keyed (VRC7)
        self.triggered = False     # a new note this tick (VRC7 retrigger)
        self.macros: dict[str, MacroPlayer] = {}
        self.pitch_acc = 0
        self.arp_acc = 0           # a relative arpeggio macro's running offset
        self.arp = 0
        self.arp_state = 0
        self.vib_speed = 0
        self.vib_depth = 0
        self.vib_phase = 0
        self.fine = 0x80
        self.duty_col: int | None = None
        self.pending: Cell | None = None
        self.delay = 0
        self.cut = -1
        # Values the last tick produced.
        self.out_note = 0.0
        self.out_vol = 0
        self.out_duty = 0
        self.out_period = 0.0

    def row(self, cell: Cell) -> None:
        delay = next((v for e, v in cell.effects if e == "G"), 0)
        if delay:
            self.pending, self.delay = cell, delay
        else:
            self.apply(cell)

    def apply(self, cell: Cell) -> None:
        if cell.inst is not None:
            self.inst = cell.inst
        if cell.vol is not None:
            self.vol = cell.vol
        for effect, value in cell.effects:
            if effect == "0":
                self.arp = value
                if value == 0:
                    self.arp_state = 0
            elif effect == "4":
                self.vib_speed, self.vib_depth = value >> 4, value & 0x0F
                if self.vib_depth == 0:
                    self.vib_phase = 0
            elif effect == "P":
                self.fine = value
            elif effect == "V":
                self.duty_col = value & 0x03
            elif effect == "S":
                self.cut = value
        if cell.note == HALT:
            self.on = False
        elif cell.note == RELEASE:
            for player in self.macros.values():
                player.release()
            if self.fm:
                self.on = False
        elif cell.note is not None:
            self._trigger(int(cell.note))

    def _trigger(self, note: int) -> None:
        self.note = note
        self.on = True
        self.triggered = True
        self.pitch_acc = 0
        self.arp_acc = 0
        self.arp_state = 0
        inst = self.module.instruments.get(self.inst) if self.inst is not None else None
        self.macros = {}
        if isinstance(inst, Inst2A03):
            self.macros = {kind: MacroPlayer(self.module.macros[(kind, index)])
                           for kind, index in inst.macros.items()}

    def tick(self) -> None:
        """Advance one engine tick and leave the result in out_*."""
        if self.pending is not None:
            self.delay -= 1
            if self.delay <= 0:
                cell, self.pending = self.pending, None
                self.apply(cell)
        if self.cut >= 0:
            if self.cut == 0:
                self.on = False
            self.cut -= 1
        seq_vol, seq_arp, seq_duty = 15, 0, None
        fixed_note: int | None = None
        for kind, player in self.macros.items():
            value = player.step()
            if kind == "volume":
                seq_vol = max(0, min(15, value))
            elif kind == "arpeggio":
                if player.macro.setting == 1:
                    # ⚠ A fixed arpeggio counts from the tracker's C-0, which is MIDI 12.
                    fixed_note = value + 12
                elif player.macro.setting == 2:
                    self.arp_acc += value
                    seq_arp = self.arp_acc
                else:
                    seq_arp = value
            elif kind == "pitch":
                self.pitch_acc += value
            elif kind == "duty":
                seq_duty = value & 0x03
        arp_offset = 0
        if self.arp:
            arp_offset = (0, self.arp >> 4, self.arp & 0x0F)[self.arp_state]
            self.arp_state = (self.arp_state + 1) % 3
            if self.arp_state == 2 and self.arp & 0x0F == 0:
                self.arp_state = 0
        note = self.note if self.note is not None else 0
        base = fixed_note if fixed_note is not None else note + seq_arp
        self.out_note = float(base + arp_offset)
        vibrato = 0.0
        if self.vib_depth:
            self.vib_phase = (self.vib_phase + self.vib_speed) & 63
            vibrato = VIBRATO_DEPTH[self.vib_depth] * math.sin(2 * math.pi * self.vib_phase / 64)
        # Period units, as FamiTracker applies them: up in pitch is down in period.
        self.out_period = (pulse_period(self.out_note) + self.pitch_acc - vibrato
                           - (self.fine - 0x80))
        if self.fm:
            self.out_vol = self.vol
        else:
            volume = (seq_vol * self.vol) // 15
            if volume == 0 and seq_vol > 0 and self.vol > 0:
                volume = 1
            self.out_vol = volume if self.on else 0
        # A duty macro overrides Vxx on every tick it runs, as in the tracker.
        self.out_duty = seq_duty if seq_duty is not None else (self.duty_col or 0)


# --- The 2A03 ----------------------------------------------------------------------------------

def _noise_sequence(short: bool) -> np.ndarray:
    tap = 6 if short else 1
    state, out, seen = 1, [], set()
    while state not in seen:
        seen.add(state)
        out.append(0 if state & 1 else 1)   # the channel sounds while bit 0 is clear
        feedback = (state ^ (state >> tap)) & 1
        state = (state >> 1) | (feedback << 14)
    return np.array(out, dtype=np.float64)


class Stepper:
    """A periodic step waveform, averaged over each output sample (a box filter, exactly)."""

    def __init__(self, steps) -> None:
        self.set(steps)
        self.phase = 0.0

    def set(self, steps) -> None:
        self.seq = np.asarray(steps, dtype=np.float64)
        self.cum = np.concatenate(([0.0], np.cumsum(self.seq)))

    def run(self, rate: float, n: int) -> np.ndarray:
        length = len(self.seq)
        self.phase %= length
        if rate <= 0.0:
            return np.full(n, self.seq[int(self.phase)])
        x = self.phase + rate * np.arange(n + 1, dtype=np.float64)
        k = np.floor(x)
        full, index = np.divmod(k, length)
        index = index.astype(np.int64)
        cumulative = full * self.cum[length] + self.cum[index] + (x - k) * self.seq[index]
        self.phase = (self.phase + rate * n) % length
        return np.diff(cumulative) / rate


class Apu:
    """The four 2A03 tone channels, at RATE * OVERSAMPLE."""

    def __init__(self) -> None:
        self.rate = RATE * OVERSAMPLE
        self.pulses = [Stepper(PULSE_DUTY[2]), Stepper(PULSE_DUTY[2])]
        self.triangle = Stepper(TRIANGLE_STEPS)
        # Parked on a zero step, so an idle triangle is silence and a file does not open on a thump.
        self.triangle.phase = 16.0
        self.noise_long, self.noise_short = _noise_sequence(False), _noise_sequence(True)
        self.noise = Stepper(self.noise_long)
        self.noise_mode = 0

    def render(self, voices: dict[str, Voice], n: int) -> np.ndarray:
        out = np.zeros(n)
        for stepper, name in zip(self.pulses, ("pulse1", "pulse2")):
            voice = voices[name]
            period = int(round(voice.out_period))
            stepper.set(PULSE_DUTY[voice.out_duty])
            if voice.out_vol and 8 <= period <= 0x7FF:
                rate = CPU_HZ / (2.0 * (period + 1)) / self.rate
                out += stepper.run(rate, n) * (voice.out_vol * PULSE_GAIN)
            else:
                stepper.run(0.0, n)
        tri = voices["triangle"]
        period = int(round(tri.out_period))
        # ⚠ A silenced triangle FREEZES on its step rather than dropping to zero: that is the
        # hardware, and it is why stopping it does not click. The high-pass takes the DC away.
        playing = tri.on and tri.out_vol > 0 and 0 <= period <= 0x7FF
        rate = CPU_HZ / (period + 1) / self.rate if playing else 0.0
        out += self.triangle.run(rate, n) * TRIANGLE_GAIN   # its steps are its level
        noise = voices["noise"]
        mode = noise.out_duty & 1
        if mode != self.noise_mode:
            self.noise_mode = mode
            self.noise.set(self.noise_short if mode else self.noise_long)
        if noise.out_vol and noise.note is not None:
            index = 15 - max(0, min(15, int(noise.out_note)))
            rate = CPU_HZ / NOISE_PERIODS[index] / self.rate
            out += self.noise.run(rate, n) * (noise.out_vol * NOISE_GAIN)
        return out


# --- The VRC7 channels -------------------------------------------------------------------------

def fm_registers(note: float, period: float) -> tuple[int, int]:
    """F-number and block for the pitch `period` implies, in the note's own octave."""
    block = max(0, min(7, int(note) // 12 - 1))
    hz = CPU_HZ / (16.0 * (period + 1.0))
    fnum = int(round(hz * 2 ** (19 - block) / OPLL_RATE))
    while fnum > 511 and block < 7:
        block += 1
        fnum = int(round(hz * 2 ** (19 - block) / OPLL_RATE))
    return max(0, min(511, fnum)), block


class FmBank:
    def __init__(self, module: Module) -> None:
        self.module = module
        self.chip = Opll(RATE)
        self.custom: tuple[int, ...] | None = None

    def update(self, voices: dict[str, Voice]) -> None:
        for index, name in enumerate(CHANNELS_VRC7):
            voice = voices[name]
            inst = self.module.instruments.get(voice.inst) if voice.inst is not None else None
            if voice.triggered and isinstance(inst, InstVRC7):
                if inst.patch == 0 and inst.regs != self.custom:
                    # ⚠ The VRC7 has ONE custom patch, shared by every channel: the last
                    # custom instrument struck wins, exactly as on the cartridge.
                    self.custom = inst.regs
                    for reg, value in enumerate(inst.regs):
                        self.chip.write(reg, value)
                # Key off, then on: a struck note restarts its envelope.
                self.chip.force(0x20 + index, self.chip._regs.get(0x20 + index, 0) & ~0x10)
            patch = inst.patch if isinstance(inst, InstVRC7) else 0
            self.chip.write(0x30 + index, (patch << 4) | (15 - voice.out_vol))
            if voice.note is None:
                continue
            fnum, block = fm_registers(voice.out_note, voice.out_period)
            key = 0x10 if voice.on else 0
            self.chip.write(0x10 + index, fnum & 0xFF)
            value = key | (block << 1) | (fnum >> 8)
            if voice.triggered:
                self.chip.force(0x20 + index, value)
            else:
                self.chip.write(0x20 + index, value)
            voice.triggered = False


# --- The song ----------------------------------------------------------------------------------

@dataclass
class Render:
    samples: np.ndarray          # float, -1..1, at RATE
    rate: int
    loop_start: int | None       # loop region [loop_start, len(samples)) when it loops
    peak: float


def render(module: Module, track_name: str | None = None, *, loop: bool = True) -> Render:
    """Play the track. A looping track plays its loop twice and loops the second pass, so the
    seam carries the ring-out of the loop's own end and not of the intro. A one-shot track plays
    to its Cxx and then rings out until it is quiet."""
    track = module.track(track_name)
    voices = {name: Voice(name, module) for name in module.channels}
    apu = Apu()
    fm = FmBank(module) if any(c in CHANNELS_VRC7 for c in module.channels) else None
    speed, tempo = track.speed, track.tempo
    accum = 0.0
    frame, row = 0, 0
    entries: dict[tuple[int, int], list[int]] = {}
    entering = True
    halted = False
    silenced = False
    loop_key: tuple[int, int] | None = None
    loop_tick: int | None = None
    end_tick: int | None = None
    tail_ticks = 0
    chunks_apu: list[np.ndarray] = []
    chunks_fm: list[np.ndarray] = []
    tick = 0
    max_ticks = int(MAX_SECONDS * FRAME_HZ)
    while True:
        if tick >= max_ticks:
            raise ModuleError(f"track {track.name!r} runs past {MAX_SECONDS:.0f} s")
        if halted and accum <= 0.0 and not silenced:
            # The Cxx row has played out. The tracker stops every channel here; the VRC7's
            # key-off is a release, so its notes ring out as they would on the cartridge.
            for voice in voices.values():
                voice.on = False
            silenced = True
        elif not halted and accum <= 0.0:
            if entering:
                key = (frame, row)
                seen = entries.setdefault(key, [])
                if seen and not loop:
                    raise ModuleError(f"track {track.name!r} loops; a one-shot ends with Cxx")
                if seen:
                    if loop_key is None:
                        loop_key, loop_tick = key, tick
                    elif key == loop_key:
                        end_tick = tick
                        break
                seen.append(tick)
                entering = False
            jump: int | None = None
            skip: int | None = None
            for index, channel in enumerate(module.channels):
                cell = track.patterns.get(track.order[frame][index], {}).get(row)
                if cell is None:
                    continue
                cell = cell[index]
                for effect, value in cell.effects:
                    if effect == "F" and value:
                        if value < module.split:
                            speed = value
                        else:
                            tempo = value
                    elif effect == "B":
                        jump = value
                    elif effect == "D":
                        skip = value
                    elif effect == "C":
                        halted = True
                voices[channel].row(cell)
            if jump is not None:
                frame, row, entering = jump % len(track.order), 0, True
            elif skip is not None:
                frame, row, entering = (frame + 1) % len(track.order), skip, True
            else:
                row += 1
                if row >= track.rows:
                    frame, row, entering = (frame + 1) % len(track.order), 0, True
            if halted and loop:
                raise ModuleError(f"track {track.name!r} halts (Cxx) but is rendered as a loop")
            accum += 3600.0
        accum -= tempo * 24.0 / speed
        for voice in voices.values():
            voice.tick()
        start = round(tick * RATE / FRAME_HZ)
        n = round((tick + 1) * RATE / FRAME_HZ) - start
        chunks_apu.append(apu.render(voices, n * OVERSAMPLE))
        if fm is not None:
            fm.update(voices)
            chunks_fm.append(fm.chip.render(n))
        tick += 1
        if silenced:
            tail_ticks += 1
            if tail_ticks > int(2.0 * FRAME_HZ):
                break
    if fm is not None:
        fm.chip.close()
    apu_mix = resample_poly(np.concatenate(chunks_apu), 1, OVERSAMPLE)
    mix = apu_mix
    if fm is not None:
        fm_mix = np.concatenate(chunks_fm).astype(np.float64) * FM_GAIN
        mix = apu_mix[:len(fm_mix)] + fm_mix
    alpha = 1.0 / (1.0 + 2.0 * math.pi * HIGHPASS_HZ / RATE)
    mix = lfilter([alpha, -alpha], [1.0, -alpha], mix) * MASTER_GAIN
    loop_start = None
    if loop:
        assert loop_tick is not None and end_tick is not None
        loop_start = round(loop_tick * RATE / FRAME_HZ)
        mix = _close_the_seam(mix[:round(end_tick * RATE / FRAME_HZ)], loop_start)
    else:
        mix = _trim_tail(mix)
    return Render(mix, RATE, loop_start, float(np.max(np.abs(mix))) if len(mix) else 0.0)


SEAM = 512  # 16 ms at RATE


def _close_the_seam(mix: np.ndarray, loop_start: int) -> np.ndarray:
    """Fade the loop's last 16 ms into the 16 ms before its start, so the jump back is seamless.

    ⚠ The two passes are the same notes but NOT the same samples: the pulses, the triangle, the
    noise and the VRC7's vibrato LFO all run free, so their phases differ from pass to pass. A
    held triangle note jumped back to the loop's start clicks. What comes after the loop's start
    is, by construction, the continuation of the samples just before it -- so the loop's end is
    faded into those, and the seam becomes a step the music would have taken anyway."""
    if loop_start < SEAM:
        raise ModuleError("the loop starts too early to close its seam")
    mix = mix.copy()
    fade = np.arange(1, SEAM + 1, dtype=np.float64) / SEAM
    end = len(mix)
    mix[end - SEAM:end] = (mix[end - SEAM:end] * (1.0 - fade)
                           + mix[loop_start - SEAM:loop_start] * fade)
    return mix


def _trim_tail(mix: np.ndarray) -> np.ndarray:
    """Cut a one-shot where it falls below -60 dB, with a 5 ms fade so the cut cannot click."""
    loud = np.nonzero(np.abs(mix) > 1e-3)[0]
    if not len(loud):
        return mix[:0]
    mix = mix[:loud[-1] + 1].copy()
    fade = min(len(mix), RATE // 200)
    mix[len(mix) - fade:] *= np.linspace(1.0, 0.0, fade)
    return mix


# --- WAV ---------------------------------------------------------------------------------------

def wav_bytes(result: Render) -> bytes:
    """16-bit mono PCM. A loop is written as a `smpl` chunk, which Godot's importer reads by
    default (edit/loop_mode 0, "Detect From WAV"), so no .import file needs editing.

    ⚠ Godot treats the smpl end as EXCLUSIVE (it loops when the read position reaches it), so
    the end written is the sample count, one past the last sample -- run_audio_probe mixes
    across the seam to hold Godot to that."""
    import struct

    if result.peak > 1.0:
        raise ModuleError(f"the mix clips (peak {result.peak:.2f}); lower the module's volumes")
    pcm = np.round(np.clip(result.samples, -1.0, 1.0) * 32767.0).astype("<i2").tobytes()

    def chunk(tag: bytes, data: bytes) -> bytes:
        return tag + struct.pack("<I", len(data)) + data + (b"\0" if len(data) % 2 else b"")

    fmt = struct.pack("<HHIIHH", 1, 1, result.rate, result.rate * 2, 2, 16)
    body = b"WAVE" + chunk(b"fmt ", fmt) + chunk(b"data", pcm)
    if result.loop_start is not None:
        frames = len(result.samples)
        smpl = struct.pack("<9I", 0, 0, round(1e9 / result.rate), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, result.loop_start, frames, 0, 0)
        body += chunk(b"smpl", smpl)
    return b"RIFF" + struct.pack("<I", len(body)) + body


def main(argv: list[str]) -> int:
    if len(argv) not in (2, 3):
        print("usage: famirender.py MODULE.txt OUT.wav [--one-shot]", file=sys.stderr)
        return 2
    module = parse_module(Path(argv[0]).read_text())
    result = render(module, loop="--one-shot" not in argv)
    Path(argv[1]).write_bytes(wav_bytes(result))
    print(f"{argv[1]}: {len(result.samples) / RATE:.2f} s, peak {result.peak:.2f}"
          + (f", loops from {result.loop_start / RATE:.2f} s" if result.loop_start is not None
             else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
