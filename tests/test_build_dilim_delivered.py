"""tools/build_dilim_delivered.py: the art team's Dilim creatures as the game's strips."""

from __future__ import annotations

import math
import re
import sys
import unittest
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import signal

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


def _vector(script: str, name: str) -> tuple[float, float]:
    found = re.search(rf"const {name} := Vector2\(([-\d.]+), ([-\d.]+)\)", script)
    assert found, f"no const {name} in the script"
    return (float(found.group(1)), float(found.group(2)))


def _found(frame: np.ndarray, template: np.ndarray) -> float:
    """How well a template is found anywhere in a frame, at 0.4 to 0.8 of its size (the legs drawn
    under the manananggal's body are about half the size of its lower half's own): the best
    normalised correlation of premultiplied colour, averaged over the three channels."""

    def premultiplied(x: np.ndarray) -> np.ndarray:
        return x[..., :3] * (x[..., 3:4] / 255.0)

    best = 0.0
    for scale in (0.4, 0.5, 0.6, 0.7, 0.8):
        size = (max(4, int(template.shape[1] * scale)), max(4, int(template.shape[0] * scale)))
        small = np.asarray(Image.fromarray(template.astype(np.uint8), "RGBA").resize(size, Image.BILINEAR)).astype(float)
        f, s = premultiplied(frame), premultiplied(small)
        score = 0.0
        for c in range(3):
            tc = s[..., c] - s[..., c].mean()
            ones = np.ones(tc.shape)
            total = signal.correlate2d(f[..., c], ones, mode="valid")
            squares = signal.correlate2d(f[..., c] ** 2, ones, mode="valid")
            spread = np.maximum(squares - total ** 2 / tc.size, 1e-6)
            score = score + signal.correlate2d(f[..., c], tc, mode="valid") / np.sqrt(spread * (tc ** 2).sum())
        best = max(best, float((score / 3).max()))
    return best


def _height(frame: np.ndarray) -> int:
    rows = np.nonzero((frame[..., 3] > 0).any(axis=1))[0]
    return int(rows.max() - rows.min() + 1)


class DeliveredStripsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.strips = delivered.strips()

    def test_every_delivered_sheet_is_cut(self) -> None:
        # A sheet the art team sent that nothing is cut from would be art lost without a word.
        used = {f"{sheet}.png" for sheet, _ in delivered.STRIPS.values()}
        self.assertEqual(delivered.delivered() - used, set(), "delivered and cut into nothing")

    def test_the_two_tools_never_write_the_same_strip(self) -> None:
        # The sculpted strips are drawn by build_dilim_creatures.py; a name both wrote would be
        # whichever ran last.
        self.assertEqual(set(creatures.strips()) & delivered.DELIVERED, set())

    def test_every_animation_is_a_row_of_square_frames(self) -> None:
        for name, (_, pose_names) in delivered.STRIPS.items():
            w, h = self.strips[name].size
            count = len(delivered.FADE) if name.endswith("_death") else len(pose_names)
            self.assertEqual(w, count * h, f"{name}: {count} frames in {w} x {h}")

    def test_nothing_is_cut_off_at_a_frame_edge(self) -> None:
        # A ground creature stands on its bottom row (and a death may sink through it); every
        # other edge must be clear.
        for name, sheet in self.strips.items():
            for index, frame in enumerate(_frames(sheet)):
                alpha = frame[..., 3] > 0
                edges = {"top": alpha[0].any(), "left": alpha[:, 0].any(), "right": alpha[:, -1].any()}
                if delivered.kind_of(name) in delivered.FLYING:
                    edges["bottom"] = alpha[-1].any()
                clipped = [edge for edge, hit in edges.items() if hit]
                self.assertEqual(clipped, [], f"{name} frame {index} runs off its {clipped}")

    def test_ground_creatures_stand_on_the_bottom_row(self) -> None:
        for name, sheet in self.strips.items():
            if delivered.kind_of(name) in delivered.FLYING or name.endswith("_death"):
                continue
            for index, frame in enumerate(_frames(sheet)):
                rows = np.nonzero((frame[..., 3] > 0).any(axis=1))[0]
                self.assertGreaterEqual(int(rows.max()), frame.shape[0] - 2, f"{name} frame {index} floats")

    def test_each_creature_is_its_size_in_the_game(self) -> None:
        # The white lady a head taller than the apo (106 px); the kapre half again her height on its
        # branch; the manananggal's wings wide enough to be the thing hunting from above.
        self.assertTrue(110 <= _height(_frames(self.strips["aswang_dog_idle"])[0]) <= 124)
        self.assertTrue(140 <= _height(_frames(self.strips["kapre_idle"])[0]) <= 170)
        self.assertTrue(130 <= _height(_frames(self.strips["tikbalang_idle"])[0]) <= 150)
        wings = _frames(self.strips["manananggal_upper_idle"])[0][..., 3] > 0
        cols = np.nonzero(wings.any(axis=0))[0]
        self.assertTrue(120 <= cols.max() - cols.min() + 1 <= 160, f"wings {cols.max() - cols.min() + 1} px")

    def test_tiyanak_has_a_normal_baby_a_transformation_and_a_solid_monster(self) -> None:
        poses = delivered.poses("tiyanak")
        for name, image in poses.items():
            px = np.asarray(image).astype(int)
            opaque = px[..., 3] > 128
            holes = delivered.ndimage.binary_fill_holes(opaque) & ~opaque
            self.assertFalse(holes[:image.height // 2].any(), f"{name}: holes in its head or face")
        for name in ("cry1", "cry2", "cry3", "cry4"):
            px = np.asarray(poses[name]).astype(int)
            white = (px[..., 3] > 128) & (px[..., :3].min(axis=2) > 170)
            red_eye = (px[..., 3] > 128) & (px[..., 0] > 190) & (px[..., 1] < 60) & (px[..., 2] < 60)
            self.assertGreater(int(white.sum()), 2000, f"{name}: missing swaddling cloth")
            self.assertFalse(red_eye.any(), f"{name}: the lure is already a red-eyed monster")
        for name in ("change6", "snarl1", "crawl1", "jump1"):
            px = np.asarray(poses[name]).astype(int)
            red_eye = (px[..., 3] > 128) & (px[..., 0] > 190) & (px[..., 1] < 60) & (px[..., 2] < 60)
            self.assertGreater(int(red_eye.sum()), 10, f"{name}: missing transformed red eyes")

    def test_tiyanak_does_not_shrink_when_it_transforms_or_crawls(self) -> None:
        # Compare the rendered bodies, not the transparent square frames. The original sheet
        # draws the crawling form at less than half the swaddled baby's visible body area.
        reference = np.mean([frame[..., 3].astype(float).sum()
                             for frame in _frames(self.strips["tiyanak_idle"])])
        for name, sheet in self.strips.items():
            if not name.startswith("tiyanak_") or name.endswith("_death"):
                continue
            for index, frame in enumerate(_frames(sheet)):
                relative = float(frame[..., 3].astype(float).sum() / reference)
                self.assertTrue(0.85 <= relative <= 1.15,
                                f"{name} frame {index}: body size is {relative:.0%} of the baby")

    def test_the_white_lady_faces_right_as_the_game_turns_her(self) -> None:
        # The strips face right and the animator mirrors them; a pose left facing left would turn
        # her back on her every time she came at her. Her face is east of her hair's mass.
        for name in ("aswang_dog_idle", "aswang_dog_run", "aswang_dog_attack", "aswang_dog_hurt"):
            for index, frame in enumerate(_frames(self.strips[name])):
                px = frame.astype(int)
                opaque = px[..., 3] > 0
                hair = opaque & (px[..., :3].max(axis=2) < 40)
                skin = opaque & (px[..., 2] > 180) & (px[..., 0] < px[..., 2]) & (px[..., 0] > 140)
                if not skin.any():
                    continue
                hx = np.nonzero(hair)[1].mean()
                face_rows = np.nonzero(skin.any(axis=1))[0]
                top_skin = skin[: face_rows.min() + 12]
                sx = np.nonzero(top_skin)[1].mean()
                self.assertGreater(sx, hx, f"{name} frame {index} faces left")

    def test_the_supplied_crawler_keeps_its_tongue_and_faces_right(self) -> None:
        # The runtime mirrors right-facing frames. The opposite-facing hurt pose on the sheet
        # must be turned too, or a hit makes the crawler abruptly turn away from the player.
        for name, sheet in self.strips.items():
            if not name.startswith("aswang_pig_") or name.endswith("_death"):
                continue
            for index, frame in enumerate(_frames(sheet)):
                px = frame.astype(int)
                r, g, b, a = (px[..., c] for c in range(4))
                red = (a > 128) & (r > 100) & (r > 2 * g) & (r > 2 * b)
                hair = (a > 128) & (px[..., :3].max(axis=2) < 60)
                self.assertGreater(int(red.sum()), 20, f"{name} frame {index}: missing eyes/tongue")
                self.assertTrue(hair.any(), f"{name} frame {index}: missing dark hair/outline")
                self.assertGreater(np.nonzero(red)[1].mean(), np.nonzero(hair)[1].mean(),
                                   f"{name} frame {index} faces left")

    def test_tikbalang_keeps_its_solid_mane_skin_and_rightward_facing(self) -> None:
        for name, picture in delivered.poses("tikbalang").items():
            px = np.asarray(picture).astype(int)
            r, g, b, a = (px[..., c] for c in range(4))
            opaque = a > 128
            holes = delivered.ndimage.binary_fill_holes(opaque) & ~opaque
            self.assertFalse(holes[:picture.height // 2].any(), f"{name}: holes through the mane")
            skin = opaque & (r > g + 20) & (g > b + 10)
            self.assertGreater(int(skin.sum()), 800, f"{name}: the key erased its brown skin")
            eye = opaque & (r > 150) & (g < 70) & (b < 70)
            mane = opaque & (px[..., :3].max(axis=2) < 60)
            self.assertTrue(eye.any(), f"{name}: missing red eye")
            self.assertGreater(np.nonzero(eye)[1].mean(), np.nonzero(mane)[1].mean(),
                               f"{name}: faces away from the race")
            lettering = opaque & (r > 190) & (g > 160) & (b < 130)
            self.assertFalse(lettering[:10].any(), f"{name}: sheet heading remains on the sprite")
        idle = np.asarray(delivered.poses("tikbalang")["idle2"])
        self.assertEqual(int(idle[79, 46, 3]), 0, "the gap beside its arm was filled in")

    def test_crawler_hair_is_solid_without_filling_the_spaces_between_limbs(self) -> None:
        # The old key left many enclosed transparent patches across the hair in every pose.
        # A blanket fill would hide those errors but also paint over the real arm/leg gaps.
        for name, picture in delivered.poses("aswang").items():
            alpha = np.asarray(picture)[..., 3] > 0
            holes = delivered.ndimage.binary_fill_holes(alpha) & ~alpha
            labels, count = delivered.ndimage.label(holes)
            for label in range(1, count + 1):
                y, _ = delivered.ndimage.center_of_mass(labels == label)
                self.assertGreaterEqual(y, alpha.shape[0] * 0.46,
                                        f"{name}: background shows through the hair")
        idle = np.asarray(delivered.poses("aswang")["idle1"])
        self.assertEqual(int(idle[28, 79, 3]), 255, "dark hair beside the face was erased")
        self.assertEqual(int(idle[31, 59, 3]), 255, "dark hair over the shoulder was erased")
        self.assertEqual(int(idle[77, 72, 3]), 0, "the space between the arms was filled")
        self.assertEqual(int(idle[91, 26, 3]), 0, "the space beside the rear leg was filled")
        walk = np.asarray(delivered.poses("aswang")["walk4"])
        for x, y in ((69, 31), (68, 37), (66, 47)):
            self.assertEqual(int(walk[y, x, 3]), 255, "the front hair lock has a transparent slit")

    def test_the_manananggal_upper_half_has_no_legs(self) -> None:
        # Its legs are what it leaves standing in the hollow, and the sheet draws them under its
        # body in the poses its upper half takes -- joined on by a drip of blood, so no rule about
        # separate pieces sees them. They are the same drawing as its lower half's own strip, so
        # that strip is looked for in every frame (normalised correlation, premultiplied colour):
        # with the legs left on it is found (0.76 and over); without them nothing scores over 0.5.
        legs = _frames(self.strips["manananggal_lower_idle"])[0].astype(float)
        ys, xs = np.nonzero(legs[..., 3] > 0)
        legs = legs[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        for name, sheet in self.strips.items():
            if not name.startswith("manananggal_upper"):
                continue
            frames = _frames(sheet)[:1] if name.endswith("_death") else _frames(sheet)
            for index, frame in enumerate(frames):
                score = _found(frame.astype(float), legs)
                self.assertLess(score, 0.65, f"{name} frame {index}: its legs are on it ({score:.2f})")

    def test_no_label_is_left_on_the_manananggal(self) -> None:
        # The sheet's cream lettering ("1" to "6", SPOOKY, LOOK UP) sits under its poses.
        for name, sheet in self.strips.items():
            if not name.startswith("manananggal_upper"):
                continue
            px = np.asarray(sheet).astype(int)
            r, g, b, a = px[..., 0], px[..., 1], px[..., 2], px[..., 3]
            cream = (a > 128) & (r > 170) & (g > 150) & (r >= g) & (g > b) & (r - b > 35)
            self.assertLessEqual(int(cream.sum()), 4, f"{name} has {int(cream.sum())} px of lettering")

    def test_the_kapre_stands_where_its_tree_puts_it(self) -> None:
        # The game stands its strip's bottom-centre at ART_AT: its feet, on top of the balete's
        # branch (PERCH px up, the bark's top 4 px above that), with the branch under them.
        script = (ROOT / "game" / "scripts" / "kapre_2d.gd").read_text()
        self.assertEqual(_vector(script, "ART_AT"), delivered.KAPRE_ART_AT, "kapre_2d.gd ART_AT")
        bark_top = -(creatures.small.PERCH + 4)
        self.assertLessEqual(abs(delivered.KAPRE_ART_AT[1] - bark_top), 2,
                             f"its feet are at {delivered.KAPRE_ART_AT[1]}, the branch's top at {bark_top}")
        tree = np.asarray(creatures.strips()["kapre_tree_idle"])[..., 3] > 0
        th, tw = tree.shape
        x, y = int(tw // 2 + delivered.KAPRE_ART_AT[0]), int(th + delivered.KAPRE_ART_AT[1])
        self.assertTrue(tree[y:y + 4, x - 4:x + 5].any(), "nothing of the branch under its feet")
        self.assertFalse(tree[y - 30:y - 6, x - 2:x + 3].all(), "its feet are inside the tree, not on it")

    def test_its_cigar_is_hit_where_it_is_drawn(self) -> None:
        script = (ROOT / "game" / "scripts" / "kapre_2d.gd").read_text()
        self.assertEqual(_vector(script, "CIGAR_TIP"), delivered.KAPRE_CIGAR_TIP, "kapre_2d.gd CIGAR_TIP")
        frame = _frames(self.strips["kapre_idle"])[0].astype(int)
        size = frame.shape[0]
        x = size // 2 + delivered.KAPRE_CIGAR_TIP[0] - delivered.KAPRE_ART_AT[0]
        y = size + delivered.KAPRE_CIGAR_TIP[1] - delivered.KAPRE_ART_AT[1]
        near = frame[y - 1:y + 2, x - 1:x + 2].reshape(-1, 4)
        ember = [(r, g, b) for r, g, b, a in near if a > 128 and r > 200 and r - b > 120 and 80 < g < 200]
        self.assertTrue(ember, f"no ember drawn at the cigar's tip ({x}, {y}) in kapre_idle")

    def _lights(self) -> dict:
        script = (ROOT / "game" / "scripts" / "kapre_2d.gd").read_text()
        field = (ROOT / "game" / "scripts" / "light_field.gd").read_text()

        def number(name: str) -> float:
            return float(re.search(rf"const {name} := ([\d.]+)", script).group(1))

        return {"ember": number("EMBER_GLOW"), "from": _vector(script, "FACE_LIGHT_FROM"), "face": number("FACE_LIGHT"),
                "toward": _vector(script, "FACE_LIGHT_TOWARD"), "half": number("FACE_LIGHT_HALF_ANGLE"),
                "soft": float(re.search(r"const SOFT_EDGE := ([\d.]+)", field).group(1))}

    def test_its_ember_lights_its_face(self) -> None:
        # In the woods' dark only what a light reaches shows; the light on its face is the one its
        # ember throws, from its lips.
        light = self._lights()
        self.assertEqual(light["from"], delivered.KAPRE_LIPS, "kapre_2d.gd FACE_LIGHT_FROM")
        dx = delivered.KAPRE_FACE[0] - light["from"][0]
        dy = delivered.KAPRE_FACE[1] - light["from"][1]
        reach = math.hypot(dx, dy)
        self.assertLessEqual(reach, light["face"] * light["soft"], f"its face is {reach:.0f} px from its light")
        # A cone: the face must be inside its fully lit part too (the shader's 0.7 of the half angle).
        off = abs(math.atan2(dy, dx) - math.atan2(light["toward"][1], light["toward"][0]))
        off = min(off, math.tau - off)
        self.assertLessEqual(off, light["half"] * 0.7, f"its face is {math.degrees(off):.0f} deg off its light")

    def test_its_light_leaves_the_air_dark(self) -> None:
        # A light shows whatever is behind it, and up the tree, where nothing is drawn, that is the
        # backdrop's daytime-painted sky. Its lights -- LightField's falloff exactly -- over the tree
        # and the kapre as the game stands them: the sky they show must be next to none, and the
        # ember itself must still show.
        light = self._lights()
        tree = np.asarray(creatures.strips()["kapre_tree_idle"])[..., 3] > 0
        stood = _frames(self.strips["kapre_idle"])[0][..., 3] > 0
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
        stamp(stood, *delivered.KAPRE_ART_AT)
        ys, xs = np.mgrid[0:h, 0:w] + 0.5
        xs, ys = xs + left, ys + top

        def falloff(cx: float, cy: float, radius: float) -> np.ndarray:
            d = np.hypot(xs - cx, ys - cy)
            t = np.clip((d - radius * light["soft"]) / (radius * (1 - light["soft"])), 0, 1)
            return np.where(d < radius, 1 - t * t * (3 - 2 * t), 0.0)

        ember = falloff(*delivered.KAPRE_CIGAR_TIP, light["ember"]) * 0.9
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
        tip = lit[int(delivered.KAPRE_CIGAR_TIP[1] - top), int(delivered.KAPRE_CIGAR_TIP[0] - left)]
        self.assertGreaterEqual(tip, 0.8, f"its ember is lit {tip:.2f}")

    def test_the_committed_strips_are_current(self) -> None:
        for name, sheet in self.strips.items():
            path = delivered.OUT / f"{name}.png"
            self.assertTrue(delivered.pixelart.same_pixels(sheet, path),
                            f"{path.name} is stale: run tools/build_dilim_delivered.py")


if __name__ == "__main__":
    unittest.main()
