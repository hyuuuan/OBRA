"""tools/build_dilim.py: the Makiling key, on plates made here so the answer is known."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import build_dilim as dilim  # noqa: E402

LO, HI = 241, 254
PITCH = 30


def checker(width: int = 600, height: int = 300, offset: int = 11) -> np.ndarray:
    ys, xs = np.mgrid[0:height, 0:width]
    light = (((xs + offset) // PITCH + (ys + offset) // PITCH) % 2) == 0
    plate = np.where(light[..., None], HI, LO).astype(np.int16)
    return np.repeat(plate[..., :1], 3, axis=2)


def cloud_on(plate: np.ndarray, cx: int, cy: int, r: int) -> np.ndarray:
    """A white cloud with a blue underside and a pale blue rim -- open along its top, where the
    delivered ones show bare white against the checker."""
    ys, xs = np.mgrid[0:plate.shape[0], 0:plate.shape[1]]
    reach = np.sqrt((xs - cx) ** 2 + ((ys - cy) * 1.6) ** 2)
    inside = reach <= r
    plate[inside] = 255
    plate[inside & (ys > cy + r // 5)] = (150, 190, 235)
    plate[inside & (reach > r - 2) & (ys > cy - r // 3)] = (214, 230, 248)
    return inside


class CheckerKeyTest(unittest.TestCase):
    def test_a_white_cloud_on_the_checker_survives_where_a_threshold_eats_it(self) -> None:
        plate = checker()
        cloud = cloud_on(plate, 300, 150, 80)
        background = dilim.checker_key(plate, [(200, 90, 400, 210)])
        kept = (~background & cloud).sum() / cloud.sum()
        threshold = (plate.min(axis=-1) >= 240)
        threshold_kept = (~threshold & cloud).sum() / cloud.sum()
        self.assertGreater(kept, 0.85, "the cloud lost more than the cells along its bare edge")
        self.assertLess(threshold_kept, 0.7, "the test cloud is not white enough to matter")
        self.assertGreater(background[~cloud].mean(), 0.95, "the checker round it stayed")

    def test_a_pocket_closed_off_by_art_is_still_keyed(self) -> None:
        plate = checker()
        ys, xs = np.mgrid[0:300, 0:600]
        ring = (np.abs(np.hypot(xs - 300, ys - 150) - 100) <= 6)
        plate[ring] = (40, 90, 30)
        pocket = np.hypot(xs - 300, ys - 150) <= 80
        background = dilim.checker_key(plate)
        self.assertGreater(background[pocket].mean(), 0.95, "the pocket inside the vine ring stayed")
        self.assertLess(background[ring].mean(), 0.02, "the ring itself was keyed")


class FlatKeyTest(unittest.TestCase):
    def test_a_strip_on_a_flat_page_keeps_the_strip_and_loses_the_page(self) -> None:
        page = np.full((200, 400, 3), 249, np.int16)
        page[80:120, 50:350] = (110, 80, 40)
        background = dilim.flat_key(page)
        self.assertTrue(background[:60].all() and background[140:].all())
        self.assertFalse(background[85:115, 60:340].any())


class DeliveryTest(unittest.TestCase):
    def test_every_delivered_file_is_claimed(self) -> None:
        claimed = {source for source, _ in dilim.PLATES.values()} | dilim.REFERENCE_ONLY \
            | dilim.NOT_YET_CUT
        self.assertEqual(sorted(dilim.delivered() - claimed), [])

    def test_the_committed_plates_are_current(self) -> None:
        for plate, (source, method) in dilim.PLATES.items():
            path = dilim.OUT / f"{plate}.png"
            self.assertTrue(dilim.pixelart.same_pixels(dilim.keyed(source, method), path),
                            f"{path.name} is stale: run tools/build_dilim.py")


if __name__ == "__main__":
    unittest.main()
