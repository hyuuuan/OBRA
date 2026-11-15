"""tools/build_dagat_props.py: the bakunawa's cave is a painted arch with a dark opening."""

from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import build_dagat_props as props  # noqa: E402
import pixelart  # noqa: E402


def _luma(pix: np.ndarray) -> np.ndarray:
    return 0.299 * pix[..., 0] + 0.587 * pix[..., 1] + 0.114 * pix[..., 2]


class CaveMouthTest(unittest.TestCase):
    def setUp(self) -> None:
        self.cave = np.asarray(props.draw_cave_mouth()).astype(float)

    def test_its_opening_is_dark(self) -> None:
        # Flat shapes read as a hole cut in the screen; the far rock left in the arch read as sky.
        x, y = props.CAVE_OPENING_AT
        heart = self.cave[y - 40:y + 40, x - 20:x + 20]
        self.assertTrue((heart[..., 3] == 255).all(), "the opening has holes in it")
        self.assertLess(float(_luma(heart).mean()), 12.0, "the opening is not dark")

    def test_the_rock_round_it_is_the_painted_arch(self) -> None:
        x0, y0, x1, y1 = props.CAVE_BOX
        source = np.asarray(Image.open(props.RUINS).convert("RGBA"))[y0:y1, x0:x1]
        scale = props.CAVE_SCALE
        drawn = self.cave[::scale, ::scale].astype(np.uint8)
        # The plate is exported at alpha 253, not 255: every visible rock pixel is compared.
        kept = (drawn[..., 3] > 0) & ~props.cave_opening(x1 - x0, y1 - y0)
        self.assertGreater(int(kept.sum()), 20000)
        self.assertTrue(np.array_equal(drawn[kept], source[kept]),
                        "the rock round the opening is not the painting's own")

    def test_no_ruled_edge_where_it_was_cut(self) -> None:
        alpha = self.cave[..., 3]
        for name, edge in (("top", alpha[0]), ("bottom", alpha[-1]),
                           ("left", alpha[:, 0]), ("right", alpha[:, -1])):
            self.assertFalse((edge > 0).any(), f"the {name} edge is cut straight")

    def test_the_level_places_it_by_the_same_opening(self) -> None:
        level = (ROOT / "game" / "scripts" / "level_3.gd").read_text(encoding="utf-8")
        found = re.search(r"const CAVE_OPENING_AT := Vector2\(([\d.]+), ([\d.]+)\)", level)
        self.assertIsNotNone(found, "level_3.gd no longer says where the opening is")
        self.assertEqual((float(found.group(1)), float(found.group(2))),
                         tuple(float(v) for v in props.CAVE_OPENING_AT),
                         "level_3.gd places the cave by an opening the picture no longer has")

    def test_the_committed_picture_is_current(self) -> None:
        path = props.OUT / "cave_mouth.png"
        self.assertTrue(pixelart.same_pixels(props.draw_cave_mouth(), path),
                        f"{path.name} is stale: regenerate it from draw_cave_mouth")


if __name__ == "__main__":
    unittest.main()
