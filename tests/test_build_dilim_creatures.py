"""tools/build_dilim_creatures.py: Dilim's sculpted creature strips, and what they must keep true.

The supplied sheets (the kapre, the manananggal, both aswang variants, the tikbalang) are cut by build_dilim_delivered.py
and tested in test_build_dilim_delivered.py, the kapre's place in its tree with them."""

from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import build_dilim_creatures as creatures  # noqa: E402
import build_dilim_delivered as delivered  # noqa: E402


def _frames(sheet) -> list[np.ndarray]:
    pixels = np.asarray(sheet)
    h, w = pixels.shape[:2]
    if w % h:
        return [pixels]
    return [pixels[:, i * h:(i + 1) * h] for i in range(w // h)]


class CreatureStripsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.strips = creatures.strips()

    def test_every_creature_has_its_strips(self) -> None:
        # What the game asks for: every state's strip for the enemies, and each one's own extras --
        # drawn here, or delivered.
        wanted = {
            "aswang_dog": ["idle", "run", "windup", "attack", "hurt", "death"],
            "aswang_pig": ["idle", "run", "windup", "attack", "hurt", "death"],
            "sigbin": ["idle", "run", "windup", "attack", "hurt", "death"],
            "manananggal_upper": ["idle", "run", "windup", "attack", "hurt", "death"],
            "wakwak": ["idle", "run", "windup", "attack", "hurt", "death"],
            "tiktik": ["idle", "run", "windup", "attack", "hurt", "death"],
            "bungisngis": ["idle", "run", "windup", "attack", "hurt", "death", "laugh", "aside"],
            "tiyanak": ["idle", "true", "run"],
            "tiyanak_undergrowth": ["idle"],
            "manananggal_lower": ["idle", "death"],
            "tikbalang": ["idle", "run"],
            "kapre": ["idle", "knocked", "falling", "walk"],
            "kapre_smoke": ["idle"],
            "kapre_cigar": ["idle"],
            "kapre_tree": ["idle", "felled"],
            "santelmo": ["idle", "hot"],
            "nuno_mound": ["idle"],
            "dead_tree": ["idle", "felled"],
        }
        made = set(self.strips) | delivered.DELIVERED
        for kind, anims in wanted.items():
            for anim in anims:
                self.assertIn(f"{kind}_{anim}", made, f"{kind} has no {anim} strip")

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

    def test_the_kapre_cuts_its_smoke_where_it_is_drawn(self) -> None:
        # Kapre2D cuts the smoke sheet into PUFFS frames of PUFF px; the sheet must be that.
        script = (ROOT / "game" / "scripts" / "kapre_2d.gd").read_text()
        puff = int(re.search(r"const PUFF := (\d+)", script).group(1))
        puffs = int(re.search(r"const PUFFS := (\d+)", script).group(1))
        self.assertEqual((puff, puffs), (creatures.kapre.PUFF, creatures.kapre.PUFFS), "kapre_2d.gd PUFF/PUFFS")
        self.assertEqual(self.strips["kapre_smoke_idle"].size, (puff * puffs, puff))

    def test_the_tiyanaks_undergrowth_hides_its_drop(self) -> None:
        # Tiyanak2D draws the picture across UNDERGROWTH, ART_MARGIN px out at either side, with
        # ART_BELOW px of it under the ground line: the bushes must span exactly that, and stand
        # solid on the ground the whole way.
        script = (ROOT / "game" / "scripts" / "tiyanak_2d.gd").read_text()
        span = re.search(r"const UNDERGROWTH := Rect2\(([-\d.]+), ([-\d.]+), ([-\d.]+), ([-\d.]+)\)", script)
        margin = float(re.search(r"const ART_MARGIN := ([\d.]+)", script).group(1))
        below = int(float(re.search(r"const ART_BELOW := ([\d.]+)", script).group(1)))
        start, width = float(span.group(1)), float(span.group(3))
        bushes = np.asarray(self.strips["tiyanak_undergrowth_idle"])[..., 3]
        self.assertEqual(bushes.shape[1], int(width + 2 * margin), "the picture is not the undergrowth's span")
        ground_row = bushes.shape[0] - below - 1
        ground = bushes[ground_row, int(margin):int(margin + width)] > 0
        self.assertTrue(ground.all(), f"{int((~ground).sum())} px of ground along it show through")
        self.assertGreaterEqual(int(np.nonzero((bushes > 0).any(axis=1))[0].min()), 1, "it runs off its top")
        # Over the drop -- where the floor is broken past the tiyanak, as the level lays it out --
        # it hangs on down, solid from the rim to where it starts to fade, so in her light the drop
        # is more bushes and not a hole.
        scene = (ROOT / "game" / "levels" / "level_4" / "level_4_environment.tscn").read_text()
        floor = re.search(r'\[node name="Ground"[^\[]*?platforms = Array\[Rect2\]\(\[(.*?)\]\)', scene, re.S).group(1)
        rects = [tuple(float(v) for v in r) for r in re.findall(r"Rect2\(([-\d.]+), [-\d.]+, ([-\d.]+), [-\d.]+\)", floor)]
        at = float(re.search(r'\[node name="Tiyanak"[^\n]*\]\nposition = Vector2\(([-\d.]+),', scene).group(1))
        ends = sorted(x + w for x, w in rects if x + w > at)
        rim = ends[0]
        far = min(x for x, w in rects if x >= rim)
        cols = slice(int(rim - at - start + margin), int(far - at - start + margin))
        solid = bushes.shape[0] - creatures.small.UNDERGROWTH_FADE
        hole = bushes[ground_row:solid, cols] < 200
        self.assertFalse(hole.any(), f"{int(hole.sum())} px of the drop ({rim:.0f}-{far:.0f}) show through it")

    def test_the_committed_strips_are_current(self) -> None:
        for name, sheet in self.strips.items():
            path = creatures.OUT / f"{name}.png"
            self.assertTrue(creatures.pixelart.same_pixels(sheet, path),
                            f"{path.name} is stale: run tools/build_dilim_creatures.py")


if __name__ == "__main__":
    unittest.main()
