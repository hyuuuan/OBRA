"""tools/build_dilim_props.py: the satchel's icons, and what they must keep true."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import build_dilim_props as props  # noqa: E402


class SatchelIconsTest(unittest.TestCase):
    def test_every_thing_in_the_satchel_has_an_icon(self) -> None:
        # The quick slots and the pickups load <id>.png; a kind with no icon is a blank slot.
        kinds = json.loads((ROOT / "game" / "config" / "satchel.json").read_text())["items"]
        self.assertEqual(sorted(kinds), sorted(props.ITEMS))

    def test_every_icon_is_32_px_on_clear_ground(self) -> None:
        for item in props.ITEMS:
            image = np.asarray(props.icon(item))
            self.assertEqual(image.shape[:2], (props.ICON, props.ICON), item)
            for corner in (image[0, 0], image[0, -1]):
                self.assertEqual(int(corner[3]), 0, f"{item} has a filled top corner")

    def test_each_is_told_apart_by_its_colour(self) -> None:
        # A player in the dark tells them apart by colour before shape: the brightest thing
        # on each icon, off the leaf, must not be another's.
        leaf = {tuple(colour[:3]) for colour in props.LEAF}
        brightest = {}
        for item in props.ITEMS:
            image = np.asarray(props.icon(item)).reshape(-1, 4)
            own = [tuple(px[:3]) for px in image if px[3] > 0 and tuple(px[:3]) not in leaf]
            brightest[item] = max(own, key=lambda rgb: (int(rgb[0]) + int(rgb[1]) + int(rgb[2]), rgb))
        self.assertEqual(len(set(brightest.values())), len(props.ITEMS), brightest)

    def test_the_committed_icons_are_current(self) -> None:
        for item in props.ITEMS:
            path = props.OUT / f"{item}.png"
            self.assertTrue(props.pixelart.same_pixels(props.icon(item), path),
                            f"{path.name} is stale: run tools/build_dilim_props.py")


if __name__ == "__main__":
    unittest.main()
