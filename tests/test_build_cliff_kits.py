"""tools/build_cliff_kits.py: a kit tiles where the runtime tiles it, stands her on a whole lip,
breaks its underside along the painted stones rather than a ruled line, registers its cap with
its strip, and the committed kits are what the builder draws."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import build_cliff_kits as kits  # noqa: E402
import pixelart  # noqa: E402


def rgba(image) -> np.ndarray:
    return np.asarray(image.convert("RGBA")).astype(np.int16)


def jump(a: np.ndarray, b: np.ndarray) -> float:
    return float(np.abs(a[..., :3] - b[..., :3]).mean())


class KitTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.built = {r.name: (rgba(kits.build_face(r)), rgba(kits.build_edge(r))) for r in kits.RECIPES}

    def test_the_strip_tiles_across(self) -> None:
        # A seam is a step in colour the strip has nowhere else. Compared across SCALE
        # boundaries: inside one tileset pixel the output repeats itself exactly.
        for recipe in kits.RECIPES:
            face = self.built[recipe.name][0]
            body = face[kits.lip(recipe):kits.lip(recipe) + 120]
            s = kits.SCALE
            steps = [jump(body[:, k * s + s - 1], body[:, (k + 1) * s]) for k in range(body.shape[1] // s - 1)]
            self.assertLess(jump(body[:, -1], body[:, 0]), np.mean(steps) * 1.6, f"{recipe.name}: seam")

    def test_she_stands_on_a_whole_lip(self) -> None:
        for recipe in kits.RECIPES:
            face = self.built[recipe.name][0]
            under = face[kits.lip(recipe) + 2, :, 3]
            self.assertGreater((under > 0).mean(), 0.97, f"{recipe.name}: a gap under her feet")
            self.assertGreater((face[:kits.lip(recipe), :, 3] > 0).mean(), 0.03,
                               f"{recipe.name}: nothing stands above the walk line")

    def test_the_underside_is_broken_not_ruled(self) -> None:
        for recipe in kits.RECIPES:
            face = self.built[recipe.name][0]
            solid = face[..., 3] > 0
            bottom = np.array([np.nonzero(col)[0].max() for col in solid.T])
            self.assertGreater(bottom.std(), 12.0, f"{recipe.name}: the underside is a ruled line")
            # Deep enough everywhere that the first darker repeat's top (150 px down) is behind it.
            self.assertGreater(bottom.min(), 150, f"{recipe.name}: a chunk ends above the repeat")

    def test_the_cap_shares_the_strips_walk_line(self) -> None:
        for recipe in kits.RECIPES:
            face, edge = self.built[recipe.name]
            self.assertEqual(face.shape[0] > 0 and edge.shape[1] > 0, True)
            walk = kits.lip(recipe)
            # Lip at the walk line just inside the edge, and air above the blades over it.
            inside = edge[walk + 2, kits.SCALE * 8:kits.SCALE * 30, 3]
            self.assertTrue((inside > 0).all(), f"{recipe.name}: the cap's lip is not at the walk line")
            self.assertTrue((edge[:walk - 12, :kits.SCALE * 3, 3] == 0).all(),
                            f"{recipe.name}: something stands over the cap's outer corner")

    def test_the_committed_kits_are_current(self) -> None:
        for recipe in kits.RECIPES:
            for name, built in zip(("face", "edge"), (kits.build_face(recipe), kits.build_edge(recipe))):
                self.assertTrue(pixelart.same_pixels(built, ROOT / recipe.out / f"{name}.png"),
                                f"{recipe.out}/{name}.png is stale: run tools/build_cliff_kits.py")


if __name__ == "__main__":
    unittest.main()
