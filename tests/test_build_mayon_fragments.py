"""tools/build_mayon_fragments.py: twelve torn fragments, current, each torn and papered."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import build_mayon_fragments as fragments  # noqa: E402


class FragmentTest(unittest.TestCase):
    def test_twelve_fragments_one_of_them_the_flower(self) -> None:
        self.assertEqual(len(fragments.ids()), 12)
        self.assertIn(fragments.FLOWER, fragments.ids())

    def test_each_is_torn_with_the_paper_showing(self) -> None:
        for fragment_id in fragments.ids():
            pix = np.asarray(fragments.fragment(fragment_id)).astype(int)
            alpha = pix[..., 3]
            h, w = alpha.shape
            self.assertEqual(int(alpha[0, 0]) + int(alpha[-1, -1]), 0, f"{fragment_id} has square corners")
            self.assertEqual(int(alpha[h // 2, w // 2]), 255, f"{fragment_id} has a hole in its middle")
            paper = (np.abs(pix[..., :3] - fragments.PAPER).max(axis=-1) == 0) & (alpha == 255)
            self.assertGreater(paper.sum(), w, f"{fragment_id} shows no paper at its tear")

    def test_the_tear_is_its_own_and_the_same_every_build(self) -> None:
        a = np.asarray(fragments.fragment("kubo"))[..., 3]
        again = np.asarray(fragments.fragment("kubo"))[..., 3]
        self.assertTrue(np.array_equal(a, again), "the tear is not seeded")

    def test_the_committed_fragments_are_current(self) -> None:
        for fragment_id in fragments.ids():
            path = fragments.OUT / f"{fragment_id}.png"
            self.assertTrue(fragments.pixelart.same_pixels(fragments.fragment(fragment_id), path),
                            f"{path.name} is stale: run tools/build_mayon_fragments.py")


if __name__ == "__main__":
    unittest.main()
