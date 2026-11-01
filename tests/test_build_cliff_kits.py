"""tools/build_cliff_kits.py: a kit tiles where the runtime tiles it, stands her on a thick, whole
lip of the level's own grass, breaks its underside along the painted stones rather than a ruled
line, keeps its corner grass short, and the committed kits are what the builder draws."""

from __future__ import annotations

import json
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
        # A seam is a step in colour the strip has nowhere else.
        for recipe in kits.RECIPES:
            face = self.built[recipe.name][0]
            body = face[kits.kit(recipe)["skip"]:kits.kit(recipe)["skip"] + 120]
            steps = [jump(body[:, x], body[:, x + 1]) for x in range(body.shape[1] - 1)]
            self.assertLess(jump(body[:, -1], body[:, 0]), np.mean(steps) * 1.6, f"{recipe.name}: seam")

    def test_she_stands_on_a_thick_whole_lip_of_grass(self) -> None:
        for recipe in kits.RECIPES:
            face = self.built[recipe.name][0]
            numbers = kits.kit(recipe)
            band = face[numbers["lip"]:numbers["band"]]
            self.assertTrue((band[..., 3] == 255).all(), f"{recipe.name}: a gap in the lip")
            self.assertGreaterEqual(numbers["band"] - numbers["lip"], 16, f"{recipe.name}: a thin lip")
            green = band[..., 1] > band[..., 0] + 8
            self.assertGreater(green.mean(), 0.85, f"{recipe.name}: the lip is not grass")
            self.assertGreater((face[:numbers["lip"], :, 3] > 0).mean(), 0.03,
                               f"{recipe.name}: nothing stands above the walk line")

    def test_the_underside_is_broken_not_ruled(self) -> None:
        for recipe in kits.RECIPES:
            face = self.built[recipe.name][0]
            solid = face[..., 3] == 255
            bottom = np.array([np.nonzero(col)[0].max() for col in solid.T])
            self.assertGreater(bottom.std(), 12.0, f"{recipe.name}: the underside is a ruled line")
            # Deep enough everywhere that the first darker repeat's top (150 px down) is behind it.
            self.assertGreater(bottom.min(), 150, f"{recipe.name}: a chunk ends above the repeat")

    def test_the_corner_grass_hangs_from_the_overhang_and_stays_short(self) -> None:
        # ⚠ Short: a long run of growth down a riser looks climbable, a hint Ang Hagdan must not give.
        for recipe in kits.RECIPES:
            edge = self.built[recipe.name][1]
            self.assertLessEqual(edge.shape[0], 60 * kits.SCALE, f"{recipe.name}: the spill is long")
            self.assertTrue((edge[:6, 0, 3] > 0).any(), f"{recipe.name}: it does not reach the overhang")

    def test_the_committed_kits_are_current(self) -> None:
        for recipe in kits.RECIPES:
            out = ROOT / recipe.out
            pictures = [("face", kits.build_face(recipe)), ("edge", kits.build_edge(recipe))]
            pictures += [(f"plant_{i}", p) for i, p in enumerate(kits.build_plants(recipe))]
            for name, built in pictures:
                self.assertTrue(pixelart.same_pixels(built, out / f"{name}.png"),
                                f"{recipe.out}/{name}.png is stale: run tools/build_cliff_kits.py")
            self.assertEqual(json.loads((out / "kit.json").read_text()), kits.kit(recipe),
                             f"{recipe.out}/kit.json is stale")


if __name__ == "__main__":
    unittest.main()
