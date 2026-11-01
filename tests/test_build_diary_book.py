"""tools/build_diary_book.py: her diary's page turn, current, with the ribbon tabs keyed out."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import build_diary_book as book  # noqa: E402


class DiaryBookTest(unittest.TestCase):
    def test_the_committed_strip_is_what_the_script_makes(self) -> None:
        made = np.asarray(book.build())
        kept = np.asarray(Image.open(book.OUT).convert("RGBA"))
        self.assertTrue(np.array_equal(made, kept), "run tools/build_diary_book.py")

    def test_the_committed_loose_page_is_what_the_script_makes(self) -> None:
        made = np.asarray(book.loose_page())
        kept = np.asarray(Image.open(book.PAGE_OUT).convert("RGBA"))
        self.assertTrue(np.array_equal(made, kept), "run tools/build_diary_book.py")
        self.assertEqual(len({len(row) for row in book.PAGE}), 1, "the page's rows differ in length")

    def test_eight_frames_of_one_book(self) -> None:
        strip = book.build()
        self.assertEqual(strip.width % len(book.TURN), 0)
        self.assertEqual(len(book.TURN), 8)

    def test_no_ribbon_is_left(self) -> None:
        pix = np.asarray(book.build())
        for colour in book.RIBBON:
            hit = np.all(pix[..., :3] == colour, axis=-1) & (pix[..., 3] > 0)
            self.assertFalse(hit.any(), f"ribbon colour {colour} left in the book")

    def test_the_turning_page_is_not_cropped(self) -> None:
        # The page in flight rises over the cover's top edge: keyed by colour, not cut by row, so
        # the strip is taller than the cover is.
        frames = book.frames()
        cover = frames[-1].shape[0] - book.COVER_TOP
        self.assertGreater(book.build().height, cover - 40)
        top = np.asarray(book.build())[:4]
        self.assertTrue((top[..., 3] > 0).any(), "nothing rises over the cover: the page was cropped")


if __name__ == "__main__":
    unittest.main()
