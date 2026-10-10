#!/usr/bin/env python3
"""The title vista: Kent's concept picture with its lettering taken out.

The loading screen and the home screen stand on one picture -- the apo looking out over the
place the game is set -- with the real logo, the tagline and the loading bar drawn over it
live by the game (title_card.gd). The concept it comes from has a stand-in logo, a tagline
and a LOADING bar painted into it, so this takes those out, two ways:

  * SKY -- the logo and the tagline sit on open sky. Only what was painted is taken: every
    pixel in the box that is not the colour of the sky beside it, grown a few pixels to
    catch its edge, with anything it closes round (the gem in the logo) taken too. The sky
    between the letters stays as it was. Each hole is then solved exactly from its edge
    (every pixel the mean of its four neighbours), which is the smooth gradient the sky
    already is -- the sky has almost no grain of its own (under one level), so nothing is
    added to it.
  * FOLIAGE -- the word LOADING and the bar sit on leaves, which a smooth fill turns into a
    smear and any one patch copied from elsewhere does not fit. So they are grown back out of
    the picture's own leaves a small square at a time, from the edges in, each
    square the one from the foreground whose pixels best match what is already round it --
    the picture at the edge of the hole, and the squares laid before it. (Texture quilting,
    after Efros & Freeman, 2001.)

Then scaled to 1600 x 900, the game's design size.

(October 2026) The first build filled whole boxes and added blocky grain to them, which read
as static in the sky and as a smear in the leaves -- Kent: "the parts where the bits are
visible".

Usage:
    python3 tools/build_title_vista.py           # writes game/assets/ui/title_vista.png
    python3 tools/build_title_vista.py --check   # compares, writes nothing, exit 1 if stale
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.sparse import coo_matrix
from scipy.sparse.linalg import splu

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelart import Pictures   # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "HUD-assets-ideas" / "title_vista_idea.webp"
OUT = ROOT / "game" / "assets" / "ui" / "title_vista.png"
SIZE = (1600, 900)

## What the concept paints that the game draws itself, in the concept's own pixels
## (x0, y0, x1, y1), and how each is taken out.
ERASE = [
    ("sky", (495, 60, 1175, 396)),       # the stand-in logo
    ("sky", (535, 402, 1140, 452)),      # DRAW · BECOME · DISCOVER
    ("foliage", (732, 748, 938, 786)),   # LOADING...
    ("foliage", (568, 785, 1104, 846)),  # the bar
]
## SKY: how far from the sky beside it a pixel has to be to count as painted, and how far
## the painted shape is grown to take its soft edge as well.
SKY_DISTANCE = 30.0
SKY_GROW = 4
## FOLIAGE: the squares, how much each overlaps the ones before it, how many places in the
## foreground (BAND, rows of the concept) are tried for each, and the seed they are drawn with.
PATCH = 14
OVERLAP = 5
CANDIDATES = 6000
BAND = (560, 940)
SEED = 20261011


def _solve(picture: np.ndarray, hole: np.ndarray) -> None:
    """Every pixel in `hole` the mean of its four neighbours, the pixels round the hole held
    as they are: the smooth fill, solved exactly rather than swept towards."""
    ys, xs = np.nonzero(hole)
    index = -np.ones(hole.shape, dtype=np.int64)
    index[ys, xs] = np.arange(ys.size)
    rows, cols, vals = [np.arange(ys.size)], [np.arange(ys.size)], [np.full(ys.size, 4.0)]
    right = np.zeros((ys.size, picture.shape[2]))
    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        ny, nx = ys + dy, xs + dx
        inside = index[ny, nx] >= 0
        rows.append(np.nonzero(inside)[0])
        cols.append(index[ny[inside], nx[inside]])
        vals.append(np.full(int(inside.sum()), -1.0))
        right[~inside] += picture[ny[~inside], nx[~inside]]
    a = coo_matrix((np.concatenate(vals), (np.concatenate(rows), np.concatenate(cols))),
                   shape=(ys.size, ys.size)).tocsc()
    lu = splu(a)
    for channel in range(picture.shape[2]):
        picture[ys, xs, channel] = lu.solve(right[:, channel])


def _sky(picture: np.ndarray, box: tuple[int, int, int, int]) -> None:
    x0, y0, x1, y1 = box
    region = picture[y0:y1, x0:x1]
    # The sky beside the box, row by row, blended across it: what an unpainted pixel would be.
    left = picture[y0:y1, x0 - 3:x0].mean(axis=1)
    right = picture[y0:y1, x1:x1 + 3].mean(axis=1)
    t = np.linspace(0.0, 1.0, x1 - x0)[None, :, None]
    expected = left[:, None, :] * (1.0 - t) + right[:, None, :] * t
    painted = np.linalg.norm(region - expected, axis=2) > SKY_DISTANCE
    painted = ndimage.binary_dilation(painted, iterations=SKY_GROW)
    painted = ndimage.binary_fill_holes(painted)
    hole = np.zeros(picture.shape[:2], dtype=bool)
    hole[y0:y1, x0:x1] = painted
    _solve(picture, hole)


def _foliage(picture: np.ndarray, boxes: list[tuple[int, int, int, int]], avoid: np.ndarray) -> None:
    """All the leafy boxes as one hole, grown back a square at a time. Not a strip copied from
    one other place and blended in: that took the terraces for the leaves' match and blended
    them into an orange glow."""
    height, width = picture.shape[:2]
    hole = np.zeros((height, width), dtype=bool)
    for x0, y0, x1, y1 in boxes:
        hole[y0:y1, x0:x1] = True
    # Where squares may come from: the foreground, clear of every box being taken out.
    rng = np.random.default_rng(SEED)
    blocked = np.pad(avoid, ((1, 0), (1, 0))).cumsum(0).cumsum(1)
    ys = rng.integers(BAND[0], BAND[1] - PATCH, CANDIDATES * 3)
    xs = rng.integers(0, width - PATCH, CANDIDATES * 3)
    covered = (blocked[ys + PATCH, xs + PATCH] - blocked[ys, xs + PATCH]
               - blocked[ys + PATCH, xs] + blocked[ys, xs])
    ys, xs = ys[covered == 0][:CANDIDATES], xs[covered == 0][:CANDIDATES]
    grid = np.arange(PATCH)
    squares = picture[ys[:, None, None] + grid[None, :, None], xs[:, None, None] + grid[None, None, :]]
    known = ~hole
    step = PATCH - OVERLAP
    top, bottom = min(b[1] for b in boxes), max(b[3] for b in boxes)
    left, right = min(b[0] for b in boxes), max(b[2] for b in boxes)
    windows = [(y, x) for y in range(top - OVERLAP, bottom, step)
               for x in range(left - OVERLAP, right, step) if hole[y:y + PATCH, x:x + PATCH].any()]
    # FROM THE EDGES IN: always the square that already has the most picture round it. Laid
    # left to right instead, the terraces at the bar's right end were matched square after
    # square along the whole row, and the hole's top edge showed as a straight line.
    while windows:
        context = [known[y:y + PATCH, x:x + PATCH].sum() for y, x in windows]
        y, x = windows.pop(int(np.argmax(context)))
        window = (slice(y, y + PATCH), slice(x, x + PATCH))
        empty = hole[window] & ~known[window]
        if not empty.any():
            continue
        seen = known[window][None, :, :, None]
        cost = (np.square(squares - picture[window][None]) * seen).sum(axis=(1, 2, 3))
        chosen = squares[int(np.argmin(cost))]
        # Where it overlaps a square already laid, the two are averaged, softening the join;
        # the picture outside the hole is never touched.
        laid = hole[window] & known[window]
        picture[window][laid] = (picture[window][laid] + chosen[laid]) * 0.5
        picture[window][empty] = chosen[empty]
        known[window] |= empty


def build() -> Image.Image:
    picture = np.asarray(Image.open(SOURCE).convert("RGB"), dtype=np.float64)
    # Nothing is copied FROM a box still to be taken out.
    avoid = np.zeros(picture.shape[:2], dtype=bool)
    for _kind, (x0, y0, x1, y1) in ERASE:
        avoid[y0:y1, x0:x1] = True
    for kind, box in ERASE:
        if kind == "sky":
            _sky(picture, box)
    _foliage(picture, [box for kind, box in ERASE if kind == "foliage"], avoid)
    cleaned = Image.fromarray(np.clip(np.rint(picture), 0, 255).astype(np.uint8), "RGB")
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
