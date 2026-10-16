"""tools/build_dilim_creatures.py: the strips Enemy2D plays, and what they must keep true."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import build_dilim_creatures as creatures  # noqa: E402


class CreatureStripsTest(unittest.TestCase):
    def test_every_strip_is_a_row_of_48_px_frames(self) -> None:
        for kind in creatures.KINDS:
            for anim, count in creatures.ANIMS.items():
                sheet = creatures.strip(kind, anim)
                self.assertEqual(sheet.size, (creatures.FRAME * count, creatures.FRAME), f"{kind} {anim}")

    def test_standing_poses_put_their_feet_on_the_ground_row(self) -> None:
        # The animator anchors the frame's bottom edge on the creature's feet; a pose that floats
        # off that row would hover over the ground in play.
        bottom = (creatures.GROUND + 1) * creatures.FRAME // creatures.GRID - 1
        for kind in creatures.KINDS:
            for anim in ("idle", "run", "windup", "hurt"):
                sheet = np.asarray(creatures.strip(kind, anim))
                for index in range(creatures.ANIMS[anim]):
                    cell = sheet[:, index * creatures.FRAME:(index + 1) * creatures.FRAME, 3]
                    rows = np.nonzero(cell.any(axis=1))[0]
                    self.assertEqual(int(rows.max()), bottom, f"{kind} {anim} frame {index}")

    def test_the_eyes_are_lit_while_it_is_alive(self) -> None:
        # The eyes are what a player watches in the dark, and the windup brightens them.
        warm = {tuple(colour[:3]) for colour in creatures.EYE}
        for kind in creatures.KINDS:
            for anim in ("idle", "run", "windup", "attack"):
                sheet = np.asarray(creatures.strip(kind, anim))
                for index in range(creatures.ANIMS[anim]):
                    cell = sheet[:, index * creatures.FRAME:(index + 1) * creatures.FRAME]
                    lit = {tuple(px[:3]) for px in cell.reshape(-1, 4) if px[3] > 0}
                    self.assertTrue(lit & warm, f"{kind} {anim} frame {index} has no lit eye")

    def test_the_committed_strips_are_current(self) -> None:
        for kind in creatures.KINDS:
            for anim in creatures.ANIMS:
                path = creatures.OUT / f"{kind}_{anim}.png"
                self.assertTrue(creatures.pixelart.same_pixels(creatures.strip(kind, anim), path),
                                f"{path.name} is stale: run tools/build_dilim_creatures.py")


if __name__ == "__main__":
    unittest.main()
