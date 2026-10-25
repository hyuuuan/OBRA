"""tools/build_mayon.py: the two passes Makiling did not need, on plates made here so the answer
is known, and the delivery kept current."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import build_mayon as mayon  # noqa: E402

LO, HI = 243, 254
PITCH = 28


def checker(width: int = 560, height: int = 280, offset: int = 9) -> np.ndarray:
    ys, xs = np.mgrid[0:height, 0:width]
    light = (((xs + offset) // PITCH + (ys + offset) // PITCH) % 2) == 0
    plate = np.where(light[..., None], HI, LO).astype(np.int16)
    return np.repeat(plate[..., :1], 3, axis=2)


def tower_on(plate: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """A brown block with a small window sealed in it, its checker cut by the window's edge into
    pieces of both greys: no clean cell in there for the grid flood to start from."""
    tower = np.zeros(plate.shape[:2], bool)
    tower[60:240, 180:380] = True
    window = np.zeros_like(tower)
    # Straddles a cell edge (x 271/ y 103 are cell lines at this offset), smaller than a cell.
    window[96:112, 262:280] = True
    plate[tower & ~window] = (96, 70, 44)
    return tower, window


class PocketTest(unittest.TestCase):
    def test_checker_sealed_in_a_window_is_keyed(self) -> None:
        plate = checker()
        tower, window = tower_on(plate)
        background = mayon.checker_background(plate)
        self.assertGreater(background[window].mean(), 0.95, "the window's checker stayed")
        self.assertLess(background[tower & ~window].mean(), 0.01, "the tower itself was keyed")

    def test_the_grid_key_alone_leaves_that_window(self) -> None:
        # The pocket pass is not decoration: without it the window stays.
        plate = checker()
        _, window = tower_on(plate)
        alone = mayon.checker_key(plate, [])
        self.assertLess(alone[window].mean(), 0.5)

    def test_white_petals_in_the_art_are_kept(self) -> None:
        plate = checker()
        tower, _ = tower_on(plate)
        petals = np.zeros_like(tower)
        petals[180:184, 220:224] = True
        petals[180:184, 228:232] = True
        petals[184:188, 224:228] = True
        plate[petals] = HI
        background = mayon.checker_background(plate)
        self.assertFalse(background[petals].any(), "pure-white petals read as a pocket")


class SpeckTest(unittest.TestCase):
    def test_a_pale_speck_in_a_notch_goes(self) -> None:
        plate = checker()
        plate[60:240, 180:380] = (230, 120, 40)
        # A notch cut into the plume's edge, too narrow for the grid flood, holding checker the
        # export blended pale -- too far off either grey for the grid to call it checker, and
        # deeper than the fringe pass reaches.
        plate[60:70, 300:303] = LO - 9
        background = mayon.checker_background(plate)
        self.assertTrue(background[64:68, 300:303].all(), "the speck at the notch's back stayed")
        self.assertLess(background[90:230, 190:370].mean(), 0.01, "the plume was keyed")


class DeliveryTest(unittest.TestCase):
    def test_every_delivered_file_is_claimed(self) -> None:
        claimed = {source for source, _ in mayon.PLATES.values()} \
            | {source for source, _ in mayon.KEYED_PROPS.values()} \
            | mayon.REFERENCE_ONLY | {mayon.TILESET}
        self.assertEqual(sorted(mayon.delivered() - claimed), [])

    def test_the_committed_pictures_are_current(self) -> None:
        same = mayon.pixelart.same_pixels
        for plate, (source, method) in mayon.PLATES.items():
            path = mayon.OUT / "backdrop" / f"{plate}.png"
            self.assertTrue(same(mayon.keyed(source, method), path), f"{path.name} is stale")
        for prop, (source, factor) in mayon.KEYED_PROPS.items():
            path = mayon.OUT / "props" / f"{prop}.png"
            self.assertTrue(same(mayon.keyed_prop(source, factor), path), f"{path.name} is stale")
        for name in mayon.TILES:
            path = mayon.OUT / "tiles" / f"{name}.png"
            self.assertTrue(same(mayon.tile(name), path), f"{path.name} is stale")
        self.assertTrue(same(mayon.grass(), mayon.OUT / "tiles" / "grass.png"), "grass is stale")
        for name in mayon.SHEET_PROPS:
            path = mayon.OUT / "props" / f"{name}.png"
            self.assertTrue(same(mayon.sheet_prop(name), path), f"{path.name} is stale")


class SheetTest(unittest.TestCase):
    def test_each_tile_is_cut_inside_its_outline(self) -> None:
        _, page = mayon.sheet()
        for name in mayon.TILES:
            picture = np.asarray(mayon.tile(name).convert("RGB")).astype(int)
            near_page = np.abs(picture - page).max(axis=-1) <= 12
            for edge in (near_page[0], near_page[-1], near_page[:, 0], near_page[:, -1]):
                self.assertLess(edge.mean(), 0.3, f"{name} still has page along an edge")

    def test_each_sheet_prop_is_one_thing(self) -> None:
        # A box with room round it catches a neighbour's leaf; only the prop itself is kept.
        from scipy import ndimage
        for name in mayon.SHEET_PROPS:
            alpha = np.asarray(mayon.sheet_prop(name))[..., 3] > 0
            _, count = ndimage.label(alpha, structure=np.ones((3, 3), bool))
            self.assertEqual(count, 1, f"{name} is {count} pieces")


if __name__ == "__main__":
    unittest.main()
