#!/usr/bin/env python3
"""Tear Mayon's memory fragments out of the earlier paintings -- game/assets/Level5/fragments/.

WHY THIS EXISTS
---------------
Act Two of Mayon is twelve pieces of every place the apo has been, breaking loose from the
mountain and going white (LEVEL_5.md). The design says most can be cut from the existing level
art rather than drawn new, and that is what this does: each fragment is a box out of one of the
finished paintings -- Payyo's terraces, the fiesta, Dagat's shore, its deep and its storm, the
Makiling forest -- torn along a ragged edge with the paper showing at the tear.

ONE IS MADE BY HAND, and is meant to look like nothing: a scrap of path with a small flower at
its edge, a flower lola painted for no reason. It is the fifth flower.

THE TEAR IS SEEDED. Each fragment's edge is its own (seeded by its id), the same every build, so
--check compares pixels and a screenshot of the corridor can be compared with the last one.

USAGE
    python3 tools/build_mayon_fragments.py            # write game/assets/Level5/fragments/
    python3 tools/build_mayon_fragments.py --check    # verify the committed files are current
"""

from __future__ import annotations

import argparse
import sys
import zlib
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))

import pixelart  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "Level5" / "fragments"

## The finished paintings, by what they show (their file names do not: "Mt Makiling Completed
## Look" is Dagat's storm, and Dilim's forest is "Completed Look from Mayon").
TERRACES = "Painting_Covers/Level 1 Rice Terraces Completed Look.png"
FIESTA = "game/assets/Level2/completed_look.png"
SHORE = "game/assets/Level3/shore/completed_look.png"
DEEP = "game/assets/Level3/deep/completed_look.png"
STORM = "Painting_Covers/Level 4 Mt Makiling Completed Look.png"
FOREST = "Painting_Covers/Level 4 Completed Look from Mayon.png"
BANGKA = "game/assets/Level3/authored/bangka_afloat.png"

## id -> (painting, box (x0, y0, x1, y1), night). Measured by hand off the paintings at 1672x941.
FRAGMENTS: dict[str, tuple[str, tuple[int, int, int, int], bool]] = {
    "kubo": (TERRACES, (1380, 360, 1672, 620), False),       # the bahay kubo on its terrace
    "terraces": (TERRACES, (40, 430, 480, 780), False),      # the terraces lolo walked
    "bandaritas": (FIESTA, (330, 200, 790, 440), False),     # the fiesta's bunting
    "church": (FIESTA, (1040, 260, 1440, 720), False),       # the church, its door
    "dancers": (FIESTA, (580, 560, 1100, 800), False),       # the dancers in the plaza
    "bangka": (SHORE, (560, 520, 1110, 800), False),         # the sea, lolo's bangka set on it
    "bakunawa": (DEEP, (1000, 150, 1500, 520), False),       # the deep, and what searched it
    "coral": (DEEP, (40, 560, 540, 800), False),             # the reef
    "storm": (STORM, (300, 330, 1100, 700), False),          # the storm over the sea
    "forest": (FOREST, (0, 60, 500, 560), True),             # Dilim, by night
    "waterfall": (FOREST, (1040, 440, 1420, 760), False),    # the falls under the balete
}
## The flower's fragment, made here: a scrap of path, a flower at its edge.
FLOWER = "flower"
PATH_TILE = "game/assets/Level5/tiles/path.png"
GRASS = "game/assets/Level5/tiles/grass.png"
HIDDEN_FLOWER = "game/assets/Level1/hidden_flower.png"
FLOWER_SIZE = (150, 96)

## Every fragment's longest side, in px: the size it drifts at in the corridor.
LONGEST = 280
## The night Dilim was painted in, graded onto its fragment (MakilingBackdrop2D's tint).
NIGHT = np.array([0.34, 0.38, 0.55])
## The tear: how deep the ragged edge bites, its grain, and the paper showing along it.
TEAR_DEPTH = 9.0
TEAR_GRAIN = 7
PAPER = np.array([244, 239, 228])
PAPER_RIM = 2.0


def _load(path: str) -> Image.Image:
    full = ROOT / path
    if not full.exists():
        raise SystemExit(f"missing source art: {full}")
    return Image.open(full).convert("RGBA")


def _fit(image: Image.Image) -> Image.Image:
    """Down to LONGEST on its longest side, nearest: it is pixel art."""
    w, h = image.size
    scale = LONGEST / max(w, h)
    return image.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.NEAREST)


def torn(image: Image.Image, seed_name: str) -> Image.Image:
    """The picture with a ragged, seeded edge and the paper showing along the tear."""
    pix = np.asarray(image).astype(np.int16).copy()
    h, w = pix.shape[:2]
    rng = np.random.default_rng(zlib.crc32(seed_name.encode()))
    coarse = rng.random((h // TEAR_GRAIN + 2, w // TEAR_GRAIN + 2))
    noise = ndimage.zoom(coarse, TEAR_GRAIN, order=1)[:h, :w]
    inside = np.ones((h, w), bool)
    inside[0, :] = inside[-1, :] = inside[:, 0] = inside[:, -1] = False
    depth = ndimage.distance_transform_edt(inside)
    bite = 2.0 + TEAR_DEPTH * noise
    keep = depth > bite
    rim = keep & (depth <= bite + PAPER_RIM)
    pix[rim, :3] = PAPER
    pix[..., 3] = np.where(keep, pix[..., 3], 0)
    pix[~keep] = 0
    return Image.fromarray(pix.astype(np.uint8), "RGBA")


def fragment(fragment_id: str) -> Image.Image:
    if fragment_id == FLOWER:
        return torn(flower_scrap(), fragment_id)
    painting, box, night = FRAGMENTS[fragment_id]
    picture = _load(painting).crop(box)
    if fragment_id == "bangka":
        boat = _load(BANGKA)
        scale = (picture.width * 0.55) / boat.width
        boat = boat.resize((round(boat.width * scale), round(boat.height * scale)), Image.NEAREST)
        picture.alpha_composite(boat, ((picture.width - boat.width) // 2,
                                       round(picture.height * 0.62) - boat.height))
    if night:
        pix = np.asarray(picture).astype(np.float64)
        pix[..., :3] *= NIGHT
        picture = Image.fromarray(np.clip(pix, 0, 255).astype(np.uint8), "RGBA")
    return torn(_fit(picture), fragment_id)


def flower_scrap() -> Image.Image:
    """Nothing much: a scrap of path, grass along its top, a small flower at its edge."""
    w, h = FLOWER_SIZE
    scrap = Image.new("RGBA", (w, h))
    path = _load(PATH_TILE)
    for y in range(0, h, path.height):
        for x in range(0, w, path.width):
            scrap.alpha_composite(path, (x, y))
    grass = _load(GRASS)
    for x in range(0, w, grass.width):
        scrap.alpha_composite(grass, (x, 0))
    flower = _load(HIDDEN_FLOWER)
    scrap.alpha_composite(flower, (w - flower.width - 14, h - flower.height - 10))
    return scrap


def ids() -> list[str]:
    return list(FRAGMENTS) + [FLOWER]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="compare, do not write")
    args = ap.parse_args()
    pictures = pixelart.Pictures(args.check, ROOT)
    for fragment_id in ids():
        pictures.put(fragment(fragment_id), OUT / f"{fragment_id}.png")
    if args.check:
        if pictures.stale:
            print("stale or missing:\n  " + "\n  ".join(pictures.stale))
            return 1
        print(f"OK: {len(ids())} Mayon fragments are current")
        return 0
    print(f"wrote {len(ids())} fragments under game/assets/Level5/fragments/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
