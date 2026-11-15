"""tools/build_house_lolo.py: Lolo, alive, painted into each of her five paintings."""

from __future__ import annotations

import sys
import unittest
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import build_house_lolo as house  # noqa: E402


class HouseLoloTest(unittest.TestCase):
    def test_the_committed_paintings_are_what_the_script_makes(self) -> None:
        for level_id in house.SPOTS:
            made = np.asarray(house.painted(level_id))
            kept = np.asarray(Image.open(house.PAINTINGS / ("%s_lolo.png" % level_id)).convert("RGBA"))
            self.assertTrue(np.array_equal(made, kept), "run tools/build_house_lolo.py (%s)" % level_id)

    def test_he_is_in_each_and_only_where_he_stands(self) -> None:
        for level_id, (x, y, _sheet) in house.SPOTS.items():
            base = np.asarray(Image.open(house.PAINTINGS / ("%s.png" % level_id)).convert("RGBA")).astype(int)
            painted = np.asarray(house.painted(level_id)).astype(int)
            changed = np.nonzero(np.abs(painted - base).max(axis=2))
            self.assertGreater(changed[0].size, 40, "%s: he is not in it" % level_id)
            self.assertLessEqual(changed[0].max(), y, "%s: below his feet" % level_id)
            self.assertGreaterEqual(changed[0].min(), y - house.HEIGHT, "%s: above his head" % level_id)
            self.assertLess(np.abs(changed[1] - x).max(), 10, "%s: wider than him" % level_id)

    def test_his_face_is_not_keyed_out(self) -> None:
        # His eyes and mouth are dark and neutral like the ground shadow, and keying every such
        # pixel took them out: a transparent pixel the panel's edge cannot reach is a hole in him.
        for sheet in ("LOLO1", "LOLO2", "LOLO3", "LOLO4", "LOLO5"):
            alpha = house.keyed(sheet)[..., 3] > 0
            height, width = alpha.shape
            outside = np.zeros_like(alpha)
            queue = deque((y, x) for y in range(height) for x in (0, width - 1) if not alpha[y, x])
            queue.extend((y, x) for x in range(width) for y in (0, height - 1) if not alpha[y, x])
            for y, x in queue:
                outside[y, x] = True
            while queue:
                y, x = queue.popleft()
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < height and 0 <= nx < width and not alpha[ny, nx] and not outside[ny, nx]:
                        outside[ny, nx] = True
                        queue.append((ny, nx))
            holes = int((~alpha & ~outside).sum())
            self.assertEqual(holes, 0, "%s: %d pixels keyed out inside him" % (sheet, holes))

    def test_the_ghost_is_not_used(self) -> None:
        self.assertNotIn("LOLOGHOST", [sheet for (_x, _y, sheet) in house.SPOTS.values()])


if __name__ == "__main__":
    unittest.main()
