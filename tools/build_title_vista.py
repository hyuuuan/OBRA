#!/usr/bin/env python3
"""The title vista: Kent's concept picture with its lettering taken out.

The loading screen and the home screen stand on one picture -- the apo looking out over the
place the game is set -- with the real logo, the tagline and the loading bar drawn over it
live by the game (title_card.gd). The concept it comes from has a stand-in logo, a tagline
and a LOADING bar painted into it, so this cuts those out:

  * each box in ERASE is filled from its own edges -- a harmonic fill, every pixel the mean
    of its neighbours, which is a smooth sky where the logo was and a smooth sea or field
    where the bar was;
  * then given back the grain of what is round it -- blocky noise, PIXEL px square, as rough
    as the ring of picture just outside the box -- so the fill reads as the same painting
    rather than as a smear;
  * and scaled to 1600 x 900, the game's design size.

The game draws the real logo, tagline and bar in the same places, so most of each fill is
covered anyway; what shows is its edges, which is what the grain is for.

Usage:
    python3 tools/build_title_vista.py           # writes game/assets/ui/title_vista.png
    python3 tools/build_title_vista.py --check   # compares, writes nothing, exit 1 if stale
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelart import Pictures   # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "HUD-assets-ideas" / "title_vista_idea.webp"
OUT = ROOT / "game" / "assets" / "ui" / "title_vista.png"
SIZE = (1600, 900)

## What the concept paints that the game draws itself, in the concept's own pixels
## (x0, y0, x1, y1): the stand-in logo, the tagline, the word LOADING and the bar.
ERASE = [
    (495, 60, 1175, 396),
    (535, 402, 1140, 452),
    (732, 748, 938, 786),
    (568, 785, 1104, 846),
]
## How wide the ring is that a box takes its grain from, and how square the grain is.
RING = 14
PIXEL = 3
SEED = 20261011


def _fill(picture: np.ndarray, box: tuple[int, int, int, int], rng: np.random.Generator) -> None:
    x0, y0, x1, y1 = box
    # The box plus one pixel all round: the border row stays fixed, and is what flows in.
    region = picture[y0 - 1:y1 + 1, x0 - 1:x1 + 1].copy()
    # Started from the four edges blended in (a Coons patch), not from their mean: the sky is a
    # gradient top to bottom, and a fill started flat never quite lost it -- a paler block
    # stood where the logo had been. The sweeps then only smooth what the patch got nearly right.
    rows, cols = region.shape[0], region.shape[1]
    v = np.linspace(0.0, 1.0, rows)[:, None, None]
    u = np.linspace(0.0, 1.0, cols)[None, :, None]
    top, bottom = region[0][None, :, :], region[-1][None, :, :]
    left, right = region[:, 0][:, None, :], region[:, -1][:, None, :]
    corners = ((1 - u) * (1 - v) * region[0, 0] + u * (1 - v) * region[0, -1]
               + (1 - u) * v * region[-1, 0] + u * v * region[-1, -1])
    patch = (1 - v) * top + v * bottom + (1 - u) * left + u * right - corners
    region[1:-1, 1:-1] = patch[1:-1, 1:-1]
    for _sweep in range(400):
        neighbours = (region[:-2, 1:-1] + region[2:, 1:-1] + region[1:-1, :-2] + region[1:-1, 2:]) * 0.25
        region[1:-1, 1:-1] = neighbours
    # The grain of what is round the box -- the RING only. Measured over the box as well, it
    # took the stand-in logo's own edges for the sky's grain and filled the sky with static.
    ry0, rx0 = max(0, y0 - RING), max(0, x0 - RING)
    around = picture[ry0:y1 + RING, rx0:x1 + RING]
    keep = np.ones(around.shape[:2], dtype=bool)
    keep[y0 - ry0:y1 - ry0, x0 - rx0:x1 - rx0] = False
    spread = around[keep].std(axis=0) * 0.35
    h, w = y1 - y0, x1 - x0
    blocks = rng.normal(0.0, 1.0, ((h + PIXEL - 1) // PIXEL, (w + PIXEL - 1) // PIXEL, 3))
    grain = np.repeat(np.repeat(blocks, PIXEL, axis=0), PIXEL, axis=1)[:h, :w] * spread
    region[1:-1, 1:-1] += grain
    picture[y0:y1, x0:x1] = region[1:-1, 1:-1]


def build() -> Image.Image:
    picture = np.asarray(Image.open(SOURCE).convert("RGB"), dtype=np.float64)
    rng = np.random.default_rng(SEED)
    for box in ERASE:
        _fill(picture, box, rng)
    cleaned = Image.fromarray(np.clip(picture, 0, 255).astype(np.uint8), "RGB")
    return cleaned.resize(SIZE, Image.LANCZOS)


def main(check: bool) -> int:
    pictures = Pictures(check=check, root=ROOT)
    pictures.put(build(), OUT)
    if pictures.stale:
        print("stale, re-run tools/build_title_vista.py:")
        for rel in pictures.stale:
            print("   ", rel)
        return 1
    print("%s %s" % ("checked" if check else "wrote", OUT.relative_to(ROOT)))
    return 0


if __name__ == "__main__":
    sys.exit(main("--check" in sys.argv))
