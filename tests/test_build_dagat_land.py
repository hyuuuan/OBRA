"""tools/build_dagat_props.py: the beaches' lip over the stones -- the sand's shadow and the sea moss
hanging in clumps -- changes nothing about where the land is, which run_level3_audit holds to the
collision, and it does hang."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest import mock

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import build_dagat_props as props  # noqa: E402

FACE_TOP = props.SURFACE_Y - props.LAND_TOP + props.SAND_ROWS


class LandLipTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.with_lip = {name: np.asarray(props.draw_land(name)).astype(int) for name in props.LANDS}
        with mock.patch.object(props, "_lip_over_the_stones", lambda *args: None):
            cls.without = {name: np.asarray(props.draw_land(name)).astype(int) for name in props.LANDS}

    def test_the_land_is_where_it_was(self) -> None:
        for name in props.LANDS:
            self.assertTrue(np.array_equal(self.with_lip[name][..., 3], self.without[name][..., 3]),
                            f"{name}: the lip moved the land's silhouette")

    def test_the_moss_hangs_in_clumps(self) -> None:
        for name in props.LANDS:
            rows = slice(FACE_TOP + props.MOSS_FROM + 2, FACE_TOP + props.MOSS_FROM + props.MOSS_HANG)
            ours, theirs = self.with_lip[name][rows], self.without[name][rows]
            green = lambda land: (land[..., 1] > land[..., 0] + 6) & (land[..., 3] > 0)  # noqa: E731
            new = green(ours) & ~green(theirs)
            # Clumps along the beach: in a good share of its columns, and not in all of them.
            hanging = new.any(0).mean()
            self.assertGreater(hanging, 0.2, f"{name}: no moss hangs")
            self.assertLess(hanging, 0.85, f"{name}: the moss is a band, not clumps")

    def test_the_sand_shades_the_stone_under_it(self) -> None:
        for name in props.LANDS:
            rows = slice(FACE_TOP + props.MOSS_FROM, FACE_TOP + props.MOSS_FROM + 4)
            ours, theirs = self.with_lip[name][rows], self.without[name][rows]
            green = lambda land: (land[..., 1] > land[..., 0] + 6) & (land[..., 3] > 0)  # noqa: E731
            rock = (theirs[..., 3] > 0) & ~green(theirs) & ~green(ours)
            self.assertLess(ours[rock][:, :3].mean(), theirs[rock][:, :3].mean() * 0.85,
                            f"{name}: no shadow under the sand")


if __name__ == "__main__":
    unittest.main()
