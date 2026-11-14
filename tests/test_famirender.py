"""tools/famirender.py: FamiTracker text modules played on known notes, so the answer is known.

Every module here is written in the test, a few rows long, so a failure names one rule of the
tracker -- a pitch, a row's length, where a loop begins -- and not "the menu sounds wrong".
"""

from __future__ import annotations

import struct
import sys
import unittest
from pathlib import Path
from unittest import mock

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import famirender as fr  # noqa: E402

EMPTY = "... .. . ..."
# A custom VRC7 patch that is a plain sine: modulator silenced (TL 63), carrier at multiple 1,
# sustained. Its spectrum is one line at the note's own pitch.
SINE_PATCH = "21 21 3F 00 F0 F0 0F 0F"


def module(rows: dict[int, dict[int, str]], *, length: int = 16, speed: int = 6,
           tempo: int = 150, order: list[list[int]] | None = None,
           patterns: dict[int, dict[int, dict[int, str]]] | None = None,
           header: str = "") -> str:
    """A 2A03 + VRC7 module. `rows` fills pattern 00: {row: {channel index: cell}}."""
    lines = ["EXPANSION 2", "VIBRATO 1", "SPLIT 32", header,
             'INST2A03 0 -1 -1 -1 -1 -1 "plain"',
             'MACRO 0 0 -1 -1 0 : 15 10 5 0',
             'INST2A03 2 0 -1 -1 -1 -1 "decay"',
             f'INSTVRC7 1 0 {SINE_PATCH} "sine"',
             'INSTVRC7 3 4 00 00 00 00 00 00 00 00 "flute"',
             f'TRACK {length} {speed} {tempo} "t"',
             "COLUMNS : " + " ".join(["1"] * 11)]
    for frame, entry in enumerate(order or [[0] * 11]):
        lines.append(f"ORDER {frame:02X} : " + " ".join(f"{p:02X}" for p in entry))
    for number, content in (patterns or {0: rows}).items():
        lines.append(f"PATTERN {number:02X}")
        for row in range(length):
            cells = [EMPTY] * 11
            for channel, text in content.get(row, {}).items():
                cells[channel] = text
            lines.append(f"ROW {row:02X} : " + " : ".join(cells))
    return "\n".join(lines)


def render(text: str, **kwargs) -> fr.Render:
    return fr.render(fr.parse_module(text), **kwargs)


def pitch(samples: np.ndarray, rate: int) -> float:
    """The strongest spectral line, refined by parabolic interpolation."""
    window = samples * np.hanning(len(samples))
    spectrum = np.abs(np.fft.rfft(window, n=len(samples) * 4))
    peak = int(np.argmax(spectrum[8:])) + 8
    a, b, c = np.log(spectrum[peak - 1:peak + 2] + 1e-12)
    offset = 0.5 * (a - c) / (a - 2 * b + c)
    return (peak + offset) * rate / (len(samples) * 4)


def steady(result: fr.Render) -> np.ndarray:
    return result.samples[result.loop_start:]


TICK = fr.RATE / fr.FRAME_HZ


class PitchTest(unittest.TestCase):
    def test_pulse_a4_is_440(self) -> None:
        result = render(module({0: {0: "A-4 00 F V02"}}))
        self.assertAlmostEqual(pitch(steady(result), result.rate), 440.0, delta=1.5)

    def test_triangle_sounds_an_octave_below_the_pulse(self) -> None:
        # FamiTracker gives the triangle the pulses' period table; its 32-step sequencer makes
        # the same note sound an octave lower. A module written for the tracker expects that.
        result = render(module({0: {2: "A-4 00 F ..."}}))
        self.assertAlmostEqual(pitch(steady(result), result.rate), 220.0, delta=1.0)

    def test_vrc7_a4_is_440(self) -> None:
        result = render(module({0: {5: "A-4 01 F ..."}}))
        self.assertAlmostEqual(pitch(steady(result), result.rate), 440.0, delta=1.5)

    def test_vrc7_top_octave_is_its_own_fnumber_not_the_pulse_period(self) -> None:
        # At block 7 the VRC7 steps in 12.1 Hz F-numbers: C-7 is F-number 172, 2087.7 Hz, as
        # in the tracker. Taken from the 2A03's rounded integer period it would be 2110.6 Hz.
        result = render(module({0: {5: "C-7 01 F ..."}}))
        expected = 172 * fr.OPLL_RATE / 2 ** 12
        self.assertAlmostEqual(pitch(steady(result), result.rate), expected, delta=1.0)

    def test_arpeggio_steps_root_third_fifth_each_tick(self) -> None:
        result = render(module({0: {0: "C-4 00 F 047"}}))
        heard = []
        for tick in range(6):
            a, b = int(tick * TICK) + 24, int((tick + 1) * TICK) - 24
            window = result.samples[a:b] - result.samples[a:b].mean()
            # The lag of the first autocorrelation peak past half a C-4 cycle is the period.
            corr = np.correlate(window, window, "full")[len(window) - 1:]
            lag = int(np.argmax(corr[60:200])) + 60
            heard.append(result.rate / lag)
        for hz, expected in zip(heard, [261.6, 329.6, 392.0] * 2):
            self.assertAlmostEqual(hz, expected, delta=expected * 0.03)


    def test_a_fixed_arpeggio_counts_from_c0(self) -> None:
        # Value 57 is A-4 in the tracker (4 * 12 + 9), whatever note the row asks for.
        text = module({0: {0: "C-2 04 F ..."}}).replace(
            '"sine"', '"sine"\nMACRO 1 9 0 -1 1 : 57\nINST2A03 4 -1 9 -1 -1 -1 "fixed"')
        result = render(text)
        self.assertAlmostEqual(pitch(steady(result), result.rate), 440.0, delta=1.5)


class TimingTest(unittest.TestCase):
    def test_a_row_at_speed_6_tempo_150_is_six_ticks(self) -> None:
        result = render(module({0: {0: "A-4 00 F ..."}, 15: {0: "... .. . B00"}}))
        period = len(result.samples) - result.loop_start
        self.assertAlmostEqual(period, 16 * 6 * TICK, delta=1.0)

    def test_fxx_changes_the_speed(self) -> None:
        result = render(module({0: {0: "A-4 00 F F03"}, 15: {0: "... .. . B00"}}))
        period = len(result.samples) - result.loop_start
        self.assertAlmostEqual(period, 16 * 3 * TICK, delta=1.0)

    def test_dxx_ends_the_pattern_early(self) -> None:
        result = render(module({0: {0: "A-4 00 F ..."}, 7: {0: "... .. . D00"}}))
        period = len(result.samples) - result.loop_start
        self.assertAlmostEqual(period, 8 * 6 * TICK, delta=1.0)


class LoopTest(unittest.TestCase):
    def test_a_loop_plays_twice_and_loops_the_second_pass(self) -> None:
        # Frame 00 is the intro; frame 01 jumps back to itself. Intro + pass 1 + pass 2.
        intro = {0: {0: "C-4 00 F ..."}}
        body = {0: {0: "G-4 00 F ..."}, 15: {0: "... .. . B01"}}
        text = module({}, order=[[0] * 11, [1] * 11], patterns={0: intro, 1: body})
        result = render(text)
        frame = 16 * 6 * TICK
        self.assertAlmostEqual(result.loop_start, 2 * frame, delta=1.0)
        self.assertAlmostEqual(len(result.samples), 3 * frame, delta=1.0)

    def test_the_seam_is_no_bigger_than_a_step_inside_the_loop(self) -> None:
        # A held triangle note: smooth, and its phase is not the same in both passes, so an
        # unclosed seam is a jump of up to its full height -- a click.
        result = render(module({0: {2: "A-3 00 F ..."}, 15: {2: "... .. . B00"}}))
        x, start = result.samples, result.loop_start
        inside = np.abs(np.diff(x[start:]))
        seam = abs(x[start] - x[-1])
        self.assertLessEqual(seam, 1.5 * float(np.percentile(inside, 99.9)))

    def test_a_wav_carries_its_loop_where_godot_reads_it(self) -> None:
        result = render(module({0: {0: "A-4 00 F ..."}, 15: {0: "... .. . B00"}}))
        data = fr.wav_bytes(result)
        self.assertEqual(data[:4], b"RIFF")
        at = data.index(b"smpl") + 8
        loop_type, start, end = struct.unpack("<3I", data[at + 40:at + 52])
        self.assertEqual((loop_type, start, end), (0, result.loop_start, len(result.samples)))


class OneShotTest(unittest.TestCase):
    def test_a_one_shot_ends_at_cxx_and_rings_out(self) -> None:
        result = render(module({0: {5: "C-5 03 F ..."}, 3: {5: "... .. . C00"}}), loop=False)
        self.assertIsNone(result.loop_start)
        rows = 4 * 6 * TICK
        self.assertGreater(len(result.samples), rows)   # the release rang past the halt
        self.assertLess(len(result.samples), rows + 2.1 * fr.RATE)
        self.assertLess(abs(result.samples[-1]), 1e-3)  # and it ends at silence

    def test_a_one_shot_without_cxx_is_refused(self) -> None:
        with self.assertRaisesRegex(fr.ModuleError, "one-shot ends with Cxx"):
            render(module({0: {0: "A-4 00 F ..."}}), loop=False)

    def test_a_loop_with_cxx_is_refused(self) -> None:
        with self.assertRaisesRegex(fr.ModuleError, "halts"):
            render(module({0: {0: "A-4 00 F ..."}, 3: {0: "... .. . C00"}}))

    def test_a_volume_macro_shapes_the_note(self) -> None:
        result = render(module({0: {0: "A-4 02 F ..."}, 3: {0: "... .. . C00"}}), loop=False)
        # 15, 10, 5, 0: the fourth tick is silent.
        x = result.samples
        first = np.abs(x[:int(TICK)]).max()
        fourth = np.abs(x[int(3 * TICK) + 40:int(4 * TICK) - 40]).max()
        self.assertGreater(first, 0.05)
        self.assertLess(fourth, 0.02)


class RefusalTest(unittest.TestCase):
    """Anything famirender would play differently from the tracker is refused, by line."""

    def assertRefused(self, text: str, message: str) -> None:
        with self.assertRaisesRegex(fr.ModuleError, message):
            fr.parse_module(text)

    def test_an_unsupported_effect(self) -> None:
        self.assertRefused(module({0: {0: "A-4 00 F Q12"}}), r"line \d+: effect 'Q12'")

    def test_dpcm(self) -> None:
        self.assertRefused(module({0: {4: "C-4 00 F ..."}}), "DPCM")

    def test_pal(self) -> None:
        self.assertRefused(module({}, header="MACHINE 1"), "NTSC")

    def test_another_expansion(self) -> None:
        self.assertRefused(module({}, header="EXPANSION 1").replace("EXPANSION 2\n", ""),
                           "only the 2A03 and the VRC7")

    def test_an_instrument_on_the_wrong_chip(self) -> None:
        self.assertRefused(module({0: {0: "A-4 01 F ..."}}), "wrong chip")

    def test_an_unknown_command(self) -> None:
        self.assertRefused(module({}, header="GROOVE 0 2 : 6 6"), "GROOVE is not rendered")

    def test_a_clipping_mix(self) -> None:
        result = fr.Render(np.array([0.0, 1.5]), fr.RATE, None, 1.5)
        with self.assertRaisesRegex(fr.ModuleError, "clips"):
            fr.wav_bytes(result)


class VendorTest(unittest.TestCase):
    def test_a_changed_vendored_file_is_never_compiled(self) -> None:
        tampered = dict(fr.VENDOR_SHA256, **{"emu2413.c": "0" * 64})
        with mock.patch.object(fr, "VENDOR_SHA256", tampered), \
                mock.patch.object(fr.subprocess, "run") as compiler:
            with self.assertRaisesRegex(RuntimeError, "not the reviewed file"):
                fr.compile_opll()
            compiler.assert_not_called()


if __name__ == "__main__":
    unittest.main()
