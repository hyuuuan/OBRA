"""tools/build_dilim_creatures.py: Dilim's creature strips, and what they must keep true."""

from __future__ import annotations

import math
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
            "kapre": ["idle", "knocked", "falling"],
            "kapre_smoke": ["idle"],
            "kapre_cigar": ["idle"],
            "kapre_tree": ["idle", "felled"],
            "santelmo": ["idle", "hot"],
            "nuno_mound": ["idle"],
            "dead_tree": ["idle", "felled"],
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

    def _kapre_lights(self) -> dict:
        script = (ROOT / "game" / "scripts" / "kapre_2d.gd").read_text()
        field = (ROOT / "game" / "scripts" / "light_field.gd").read_text()

        def number(name: str) -> float:
            return float(re.search(rf"const {name} := ([\d.]+)", script).group(1))

        return {"ember": number("EMBER_GLOW"), "from": _vector(script, "FACE_LIGHT_FROM"), "face": number("FACE_LIGHT"),
                "toward": _vector(script, "FACE_LIGHT_TOWARD"), "half": number("FACE_LIGHT_HALF_ANGLE"),
                "soft": float(re.search(r"const SOFT_EDGE := ([\d.]+)", field).group(1))}

    def test_its_ember_lights_its_face(self) -> None:
        # In the woods' dark only what a light reaches shows; the light on the kapre's face is the one
        # its ember throws, from its lips.
        light = self._kapre_lights()
        kapre = creatures.kapre
        self.assertEqual(light["from"], kapre.LIPS, "kapre_2d.gd FACE_LIGHT_FROM is not dilim_kapre.LIPS")
        dx, dy = kapre.FACE[0] - light["from"][0], kapre.FACE[1] - light["from"][1]
        reach = math.hypot(dx, dy)
        self.assertLessEqual(reach, light["face"] * light["soft"], f"its face is {reach:.0f} px from its light")
        # A cone: the face must be inside its fully lit part too (the shader's 0.7 of the half angle).
        off = abs(math.atan2(dy, dx) - math.atan2(light["toward"][1], light["toward"][0]))
        off = min(off, math.tau - off)
        self.assertLessEqual(off, light["half"] * 0.7, f"its face is {math.degrees(off):.0f} deg off its light")

    def test_its_light_leaves_the_air_dark(self) -> None:
        # A light shows whatever is behind it, and up the tree, where nothing is drawn, that is the
        # backdrop's daytime-painted sky. Its lights -- LightField's falloff exactly -- over the tree
        # and the kapre as the game stands them: the sky they show must be next to none (one cone from
        # the tip showed a wedge of it), and the ember itself must still show.
        light = self._kapre_lights()
        kapre = creatures.kapre
        tree = np.asarray(self.strips["kapre_tree_idle"])[..., 3] > 0
        sat = _frames(self.strips["kapre_idle"])[0][..., 3] > 0
        left, top, w, h = -200, -360, 280, 300
        drawn = np.zeros((h, w), dtype=bool)

        def stamp(alpha: np.ndarray, foot_x: float, foot_y: float) -> None:
            ah, aw = alpha.shape
            x0, y0 = int(foot_x - aw // 2 - left), int(foot_y - ah - top)
            for row in range(ah):
                y = y0 + row
                if 0 <= y < h:
                    xs = slice(max(0, x0), min(w, x0 + aw))
                    drawn[y, xs] |= alpha[row, xs.start - x0:xs.stop - x0]

        stamp(tree, 0, 0)
        stamp(sat, kapre.ART_AT[0], kapre.ART_AT[1])
        ys, xs = np.mgrid[0:h, 0:w] + 0.5
        xs, ys = xs + left, ys + top

        def falloff(cx: float, cy: float, radius: float) -> np.ndarray:
            d = np.hypot(xs - cx, ys - cy)
            t = np.clip((d - radius * light["soft"]) / (radius * (1 - light["soft"])), 0, 1)
            return np.where(d < radius, 1 - t * t * (3 - 2 * t), 0.0)

        ember = falloff(*kapre.CIGAR_TIP, light["ember"]) * 0.9
        face = falloff(*light["from"], light["face"]) * 0.7
        ox, oy = xs - light["from"][0], ys - light["from"][1]
        d = np.maximum(np.hypot(ox, oy), 1e-6)
        tx, ty = light["toward"]
        angle = np.arccos(np.clip((ox * tx + oy * ty) / d / math.hypot(tx, ty), -1, 1))
        t = np.clip((angle - light["half"] * 0.7) / (light["half"] * 0.3), 0, 1)
        face = face * np.where(d > 1, 1 - t * t * (3 - 2 * t), 1)
        lit = np.maximum(ember, face)
        sky = float((lit * ~drawn).sum())
        self.assertLessEqual(sky, 100.0, f"its lights show {sky:.0f} px of sky")
        tip = lit[int(kapre.CIGAR_TIP[1] - top), int(kapre.CIGAR_TIP[0] - left)]
        self.assertGreaterEqual(tip, 0.8, f"its ember is lit {tip:.2f}")

    def test_the_kapre_cuts_its_smoke_where_it_is_drawn(self) -> None:
        # Kapre2D cuts the smoke sheet into PUFFS frames of PUFF px; the sheet must be that.
        script = (ROOT / "game" / "scripts" / "kapre_2d.gd").read_text()
        puff = int(re.search(r"const PUFF := (\d+)", script).group(1))
        puffs = int(re.search(r"const PUFFS := (\d+)", script).group(1))
        self.assertEqual((puff, puffs), (creatures.kapre.PUFF, creatures.kapre.PUFFS), "kapre_2d.gd PUFF/PUFFS")
        self.assertEqual(self.strips["kapre_smoke_idle"].size, (puff * puffs, puff))

    def test_the_committed_strips_are_current(self) -> None:
        for name, sheet in self.strips.items():
            path = creatures.OUT / f"{name}.png"
            self.assertTrue(creatures.pixelart.same_pixels(sheet, path),
                            f"{path.name} is stale: run tools/build_dilim_creatures.py")


if __name__ == "__main__":
    unittest.main()
