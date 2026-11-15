"""Dilim's creature calls read over Dilim's music.

The tik-tik's call and the tiyanak's cry are gameplay (Dilim's rule: every cue has a visual twin,
the edge ripple, but the sound still has to read). So in each call's strongest octave band, the
call at full strength must stand at least MARGIN_DB over the music with the night bed under it --
over the music's loud moments, not its average: its 95th-percentile window.

Read from the committed WAVs (tools/build_music.py --check keeps them true to their modules).
"""

from __future__ import annotations

import json
import re
import struct
import unittest
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"

MARGIN_DB = 6.0
WINDOW_S = 0.1              # about a call's own length: the tik-tik's two ticks take 0.22 s
EDGES = [30, 60, 120, 250, 500, 1000, 2000, 4000, 8000, 16000]
CALLS = ("tiktik_call", "tiyanak_cry")
# Dilim's music, each with the calls that can be heard over it. The night is the tik-tik's (it flies
# in with the last wave); the tiyanak cannot be heard there, which test_the_tiyanak_is_out_of_earshot_
# of_the_night holds from the scene itself.
MUSIC = {
    "level_4": CALLS,
    "level_4_race": CALLS,
    "dilim_night_1": ("tiktik_call",),
    "dilim_night_2": ("tiktik_call",),
    "dilim_night_3": ("tiktik_call",),
}
BED = "level_4"


def _res(path: str) -> Path:
    return GAME / path.removeprefix("res://")


def _catalog() -> dict:
    return json.loads((GAME / "config/audio.json").read_text())


def _read(path: Path) -> tuple[int, np.ndarray, int | None]:
    with wave.open(str(path)) as w:
        rate = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float64) / 32768.0
    data = path.read_bytes()
    at = data.find(b"smpl")
    start = struct.unpack("<I", data[at + 52:at + 56])[0] if at >= 0 else None
    return rate, x, start


def _band(x: np.ndarray, rate: int, lo: float, hi: float) -> np.ndarray:
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / rate)
    spectrum[(freqs < lo) | (freqs >= hi)] = 0.0
    return np.fft.irfft(spectrum, len(x))


def _windows_db(x: np.ndarray, rate: int) -> np.ndarray:
    n = int(WINDOW_S * rate)
    k = len(x) // n
    return 20.0 * np.log10(np.sqrt((x[: k * n].reshape(k, n) ** 2).mean(axis=1)) + 1e-12)


def strongest_band(x: np.ndarray, rate: int) -> tuple[int, int]:
    power = np.abs(np.fft.rfft(x)) ** 2
    freqs = np.fft.rfftfreq(len(x), 1.0 / rate)
    energy = [power[(freqs >= a) & (freqs < b)].sum() for a, b in zip(EDGES, EDGES[1:])]
    i = int(np.argmax(energy))
    return EDGES[i], EDGES[i + 1]


def margin(call: str, music: str) -> tuple[float, tuple[int, int]]:
    """How far the call, at full strength, stands over the music and bed in its own band."""
    catalog = _catalog()
    rate, c, _ = _read(_res(catalog["sfx"][call]))
    lo, hi = strongest_band(c, rate)
    loud = _windows_db(_band(c, rate, lo, hi), rate).max()
    mrate, m, start = _read(_res(catalog["music"][music]))
    _, b, bstart = _read(_res(catalog["ambience"][BED]))
    assert mrate == rate, "every file is rendered at one rate"
    m = m[start:]
    under = np.tile(b[bstart:], len(m) // len(b[bstart:]) + 1)[: len(m)]
    level = np.percentile(_windows_db(_band(m + under, rate, lo, hi), rate), 95)
    return float(loud - level), (lo, hi)


def _position(scene: str, node: str) -> tuple[float, float]:
    match = re.search(r'\[node name="%s"[^\]]*\]\nposition = Vector2\(([-0-9.]+), ([-0-9.]+)\)' % node, scene)
    assert match, f"no {node} in the scene"
    return float(match.group(1)), float(match.group(2))


class DilimCallsRead(unittest.TestCase):
    def test_the_tiyanak_is_out_of_earshot_of_the_night(self) -> None:
        """The night's music need not leave the tiyanak's band: she cries only within CRY_HEARD_FROM
        of the apo (level_4.gd _on_tiyanak_cried), and the finale is further from her than that."""
        scene = (GAME / "levels/level_4/level_4_environment.tscn").read_text()
        heard_from = float(re.search(r"const CRY_HEARD_FROM := ([0-9.]+)",
                                     (GAME / "scripts/level_4.gd").read_text()).group(1))
        tiyanak, finale = _position(scene, "Tiyanak"), _position(scene, "Finale")
        self.assertGreater(abs(finale[0] - tiyanak[0]), heard_from)

    def test_every_dilim_piece_has_a_file(self) -> None:
        catalog = _catalog()
        for music in MUSIC:
            self.assertTrue(catalog["music"].get(music), f"music.{music} has no file")
        self.assertTrue(catalog["ambience"].get(BED), f"ambience.{BED} has no file")

    def test_each_call_stands_over_the_music_in_its_own_band(self) -> None:
        for music, calls in MUSIC.items():
            for call in calls:
                with self.subTest(music=music, call=call):
                    over, (lo, hi) = margin(call, music)
                    self.assertGreaterEqual(over, MARGIN_DB,
                        f"{call} is only {over:.1f} dB over music.{music} + the bed at {lo}-{hi} Hz")


if __name__ == "__main__":
    unittest.main()
