"""tools/famitext.py: a module it writes is one famirender reads, renders and loops as written."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import famirender as fr  # noqa: E402
from famitext import Song, tracker_note, transpose  # noqa: E402

TICK = fr.RATE / fr.FRAME_HZ


def small_song(**kwargs) -> Song:
    song = Song("t", frames=2, rows=16, **kwargs)
    lead = song.inst_vrc7("flute", patch=4)
    pluck = song.inst_2a03("pluck", volume=[12, 8, 4, 0], duty=[2])
    song.line("fm1", 0, 0, [("A4", 8), ("r", 8), ("D5", 16)], lead, 12)
    song.put("pulse1", 1, 0, "E4", pluck, 10)
    return song


class NoteTest(unittest.TestCase):
    def test_notes_are_written_as_the_tracker_writes_them(self) -> None:
        self.assertEqual(tracker_note("E5", "fm1"), "E-5")
        self.assertEqual(tracker_note("F#5", "pulse1"), "F#5")
        self.assertEqual(tracker_note("5-#", "noise"), "5-#")
        self.assertEqual(tracker_note("===", "fm1"), "===")

    def test_transpose_crosses_octaves(self) -> None:
        self.assertEqual(transpose("B3", 1), "C4")
        self.assertEqual(transpose("D3", -12), "D2")
        with self.assertRaises(ValueError):
            transpose("C0", -1)


class ModuleTest(unittest.TestCase):
    def test_what_it_writes_renders_and_loops_from_loop_to(self) -> None:
        song = small_song(loop_to=1)
        result = fr.render(fr.parse_module(song.text()))
        # Frame 0 is the intro; frame 1 loops: intro + two passes of one frame.
        self.assertAlmostEqual(result.loop_start, 2 * 16 * 6 * TICK, delta=1.0)
        self.assertAlmostEqual(len(result.samples), 3 * 16 * 6 * TICK, delta=1.0)

    def test_a_row_past_the_last_frame_lands_in_the_loop(self) -> None:
        song = Song("t", frames=3, rows=16, loop_to=1)
        self.assertEqual(song.at(2, 17), (1, 1))
        self.assertEqual(song.at(0, 20), (1, 4))

    def test_a_one_shot_has_no_seam_to_cross(self) -> None:
        song = Song("t", frames=1, rows=16, loop_to=None)
        with self.assertRaisesRegex(ValueError, "one-shot"):
            song.put("fm1", 0, 16, "C4")

    def test_instruments_name_their_macros(self) -> None:
        text = small_song().text()
        self.assertIn("MACRO 0 0 -1 -1 0 : 12 8 4 0", text)
        self.assertIn("MACRO 4 0 -1 -1 0 : 2", text)
        self.assertIn('INST2A03 1 0 -1 -1 -1 0 "pluck"', text)
        self.assertIn('INSTVRC7 0 4 00 00 00 00 00 00 00 00 "flute"', text)

    def test_a_held_note_gets_its_late_effect_and_the_next_cancels_it(self) -> None:
        song = Song("t", frames=1, rows=16)
        lead = song.inst_vrc7("flute", patch=4)
        song.line("fm1", 0, 0, [("A4", 8), ("B4", 2), ("C5", 6)], lead, 12, held_fx=(3, "443", "400"))
        text = song.text()
        rows = [line for line in text.splitlines() if line.startswith("ROW ")]
        fm1 = [row.split(" : ")[6] for row in rows]
        self.assertTrue(fm1[0].startswith("A-4") and fm1[0].endswith("400"))
        self.assertTrue(fm1[3].endswith("443"))        # 3 rows into the held A
        self.assertTrue(fm1[8].endswith("400"))        # B cancels it
        self.assertFalse(fm1[11].endswith("443"))      # B is short: no vibrato
        self.assertTrue(fm1[13].endswith("443"))       # C is held: it gets one

    def test_the_loop_will_not_overwrite_an_effect(self) -> None:
        song = Song("t", frames=1, rows=16)
        song.put("pulse1", 0, 15, fx="V02")
        with self.assertRaisesRegex(ValueError, "last cell"):
            song.text()

    def test_mistakes_are_refused(self) -> None:
        song = Song("t", frames=1, rows=16)
        with self.assertRaises(ValueError):
            song.put("fm7", 0, 0, "C4")
        with self.assertRaises(ValueError):
            song.put("fm1", 0, 0, "C4", fx="4433")
        with self.assertRaises(ValueError):
            song.inst_vrc7("x", patch=16)


if __name__ == "__main__":
    unittest.main()
