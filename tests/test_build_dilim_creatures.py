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

    def test_the_body_is_dark_but_reads_in_her_light(self) -> None:
        # Dilim's dark layer hides them beyond her lantern; inside it, the body has to read
        # against the night forest. A near-black fill (luminance ~13) showed only an eye.
        for kind in creatures.KINDS:
            body = _luminance(_body_pixels(kind))
            self.assertGreaterEqual(float(np.median(body)), 25.0, f"{kind}: the body is near-black")
            self.assertLessEqual(float(np.median(body)), 60.0, f"{kind}: the body is no longer dark")

    def test_the_eye_is_still_the_brightest_thing_on_it(self) -> None:
        # A lighter body must not outshine the eye: the eye is what a player learns to watch.
        eye = {tuple(colour[:3]) for colour in creatures.EYE}
        for kind in creatures.KINDS:
            pixels = np.asarray(creatures.strip(kind, "idle")).reshape(-1, 4)
            lit = np.array([px for px in pixels if px[3] > 0 and tuple(px[:3]) in eye])
            self.assertGreater(float(_luminance(lit).min()), float(_luminance(_body_pixels(kind)).max()),
                               f"{kind}: some of the body is brighter than its eye")

    def test_the_committed_strips_are_current(self) -> None:
        for kind in creatures.KINDS:
            for anim in creatures.ANIMS:
                path = creatures.OUT / f"{kind}_{anim}.png"
                self.assertTrue(creatures.pixelart.same_pixels(creatures.strip(kind, anim), path),
                                f"{path.name} is stale: run tools/build_dilim_creatures.py")


## Every opaque pixel of a kind's idle strip that is its hide: not eye, mouth, tusk or hurt.
def _body_pixels(kind: str) -> np.ndarray:
    others = {tuple(colour[:3]) for ramp in (creatures.EYE, creatures.MOUTH, creatures.TUSK, creatures.HURT)
              for colour in ramp}
    pixels = np.asarray(creatures.strip(kind, "idle")).reshape(-1, 4)
    return np.array([px for px in pixels if px[3] > 0 and tuple(px[:3]) not in others])


def _luminance(pixels: np.ndarray) -> np.ndarray:
    rgb = pixels[:, :3].astype(float)
    return rgb @ np.array([0.2126, 0.7152, 0.0722])


if __name__ == "__main__":
    unittest.main()
