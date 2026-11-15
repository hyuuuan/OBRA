"""tools/build_dagat_props.py: the beached bangka is the boat afloat, set down on the sand."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import build_dagat_props as props  # noqa: E402
import pixelart  # noqa: E402


def _boat() -> props.Canvas:
    """The afloat bangka without its katig, drawn as the beached one draws it."""
    boat = props.Canvas(props.BANGKA_W, props.BANGKA_H, seed=2401)
    props._mast_and_sail(boat)
    props._hull(boat, False)
    boat.speckle(props.STERN + 4, props.BANGKA_WATERLINE - 5, props.BOW - props.STERN - 8, 8,
                 props.HULL[1], 0.05)
    return boat


SAND = props.BANGKA_WATERLINE + 9
DROP = SAND - (props.BANGKA_WATERLINE + 3)


class BeachedBangkaTest(unittest.TestCase):
    def test_it_is_the_same_boat_upright_on_the_sand(self) -> None:
        # Turned keel-up it read as a mound of earth, and players did not see a boat to move.
        boat = _boat().buf[: props.BANGKA_H - DROP]
        beached = props.draw_bangka_beached().buf[DROP:]
        # The katig's bamboo booms and rope lashings are drawn over the hull where they leave
        # it; every other pixel of the boat is exactly the afloat one, set down.
        lashing = np.zeros(beached.shape[:2], bool)
        for colour in list(props.BAMBOO) + list(props.ROPE):
            lashing |= np.all(beached[..., :3] == np.asarray(colour)[:3], axis=-1)
        seen = (boat[..., 3] > 0) & ~lashing
        self.assertGreater(int(seen.sum()), 500)
        self.assertTrue(np.array_equal(beached[seen], boat[seen]),
                        "the beached boat is not the afloat boat set down")

    def test_its_keel_meets_the_sand(self) -> None:
        rows = np.nonzero((_boat().buf[..., 3] > 0).any(axis=1))[0]
        self.assertEqual(int(rows.max()) + DROP, SAND, "the keel floats over the sand or sinks into it")

    def test_the_committed_picture_is_current(self) -> None:
        path = props.OUT / "bangka_beached.png"
        self.assertTrue(pixelart.same_pixels(props.draw_bangka_beached().image(), path),
                        f"{path.name} is stale: regenerate it from draw_bangka_beached")


if __name__ == "__main__":
    unittest.main()
