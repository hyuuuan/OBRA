"""tools/build_dilim_creatures.py: Dilim's creature strips, and what they must keep true."""

from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import build_dilim_creatures as creatures  # noqa: E402


def _frames(sheet) -> list[np.ndarray]:
    pixels = np.asarray(sheet)
    h, w = pixels.shape[:2]
    if w % h:
        return [pixels]
    return [pixels[:, i * h:(i + 1) * h] for i in range(w // h)]


def _vector(script: str, name: str) -> tuple[float, float]:
    found = re.search(rf"const {name} := Vector2\(([-\d.]+), ([-\d.]+)\)", script)
    assert found, f"no const {name} in the script"
    return (float(found.group(1)), float(found.group(2)))


class CreatureStripsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.strips = creatures.strips()

    def test_every_creature_has_its_strips(self) -> None:
        # What the game asks for: every state's strip for the enemies, and each one's own extras.
        wanted = {
            "aswang_dog": ["idle", "run", "windup", "attack", "hurt", "death"],
            "aswang_pig": ["idle", "run", "windup", "attack", "hurt", "death"],
            "sigbin": ["idle", "run", "windup", "attack", "hurt", "death"],
            "manananggal_upper": ["idle", "run", "windup", "attack", "hurt", "death"],
            "wakwak": ["idle", "run", "windup", "attack", "hurt", "death"],
            "tiktik": ["idle", "run", "windup", "attack", "hurt", "death"],
            "bungisngis": ["idle", "run", "windup", "attack", "hurt", "death", "laugh", "aside"],
            "tiyanak": ["idle", "true", "run"],
            "manananggal_lower": ["idle", "death"],
            "tikbalang": ["idle", "run"],
            "kapre": ["idle", "knocked"],
            "kapre_tree": ["idle", "felled"],
            "santelmo": ["idle", "hot"],
            "nuno_mound": ["idle"],
        }
        for kind, anims in wanted.items():
            for anim in anims:
                self.assertIn(f"{kind}_{anim}", self.strips, f"{kind} has no {anim} strip")

    def test_every_animation_is_a_row_of_square_frames(self) -> None:
        # PixelStripAnimator cuts a strip into frames as wide as it is tall, so an animation of n
        # frames must be exactly n heights wide; only a single picture may be any width (the
        # mound, the tree).
        for kind, anims in creatures._sheets().items():
            for anim, frames in anims.items():
                w, h = self.strips[f"{kind}_{anim}"].size
                if len(frames) > 1:
                    self.assertEqual(w, len(frames) * h, f"{kind}_{anim}: {len(frames)} frames in {w} x {h}")

    def test_nothing_is_cut_off_at_a_frame_edge(self) -> None:
        # A pose that runs off its frame is a nose or a wing chopped flat in the game. Ground
        # creatures stand on the bottom row, so it alone may be touched.
        for name, sheet in self.strips.items():
            kind = name.rsplit("_", 1)[0]
            for index, frame in enumerate(_frames(sheet)):
                alpha = frame[..., 3] > 0
                edges = {"top": alpha[0].any(), "left": alpha[:, 0].any(), "right": alpha[:, -1].any()}
                if kind not in creatures.GROUND:
                    edges["bottom"] = alpha[-1].any()
                clipped = [edge for edge, hit in edges.items() if hit]
                self.assertEqual(clipped, [], f"{name} frame {index} runs off its {clipped}")

    def test_ground_creatures_stand_on_the_bottom_row(self) -> None:
        for name, sheet in self.strips.items():
            kind = name.rsplit("_", 1)[0]
            if kind not in creatures.GROUND or name.endswith("_death"):
                continue
            for index, frame in enumerate(_frames(sheet)):
                rows = np.nonzero((frame[..., 3] > 0).any(axis=1))[0]
                self.assertGreaterEqual(int(rows.max()), frame.shape[0] - 3, f"{name} frame {index} floats")

    def test_the_outline_is_never_black(self) -> None:
        # The delivered art's idiom: each part edged in a darker tone of its own colour.
        for name, sheet in self.strips.items():
            px = np.asarray(sheet).reshape(-1, 4)
            opaque = px[px[:, 3] > 0][:, :3].astype(int)
            self.assertFalse(((opaque.sum(axis=1)) == 0).any(), f"{name} has pure black in it")

    def test_the_kapre_sits_where_its_tree_puts_it(self) -> None:
        # The kapre is drawn in its tree's own frame; the game stands its strip at the same point.
        script = (ROOT / "game" / "scripts" / "kapre_2d.gd").read_text()
        self.assertEqual(_vector(script, "ART_AT"), creatures.kapre.ART_AT, "kapre_2d.gd ART_AT is not dilim_kapre.ART_AT")

    def test_its_cigar_is_hit_where_it_is_drawn(self) -> None:
        # The cigar's hit area and its light are at CIGAR_TIP in the game; the ember is drawn there.
        script = (ROOT / "game" / "scripts" / "kapre_2d.gd").read_text()
        kapre = creatures.kapre
        self.assertEqual(_vector(script, "CIGAR_TIP"), kapre.CIGAR_TIP, "kapre_2d.gd CIGAR_TIP is not dilim_kapre.CIGAR_TIP")
        frame = _frames(self.strips["kapre_idle"])[0]
        size = frame.shape[0]
        x = size // 2 + kapre.CIGAR_TIP[0] - kapre.ART_AT[0]
        y = size + kapre.CIGAR_TIP[1] - kapre.ART_AT[1]
        near = frame[int(y) - 1:int(y) + 2, int(x) - 1:int(x) + 2, :3].reshape(-1, 3).astype(int)
        embers = kapre.EMBER[2:].astype(int)
        self.assertTrue(any((px == e).all() for px in near for e in embers),
                        f"no ember drawn at the cigar's tip ({x}, {y}) in kapre_idle")

    def test_the_committed_strips_are_current(self) -> None:
        for name, sheet in self.strips.items():
            path = creatures.OUT / f"{name}.png"
            self.assertTrue(creatures.pixelart.same_pixels(sheet, path),
                            f"{path.name} is stale: run tools/build_dilim_creatures.py")


if __name__ == "__main__":
    unittest.main()
