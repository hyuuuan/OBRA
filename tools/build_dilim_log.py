#!/usr/bin/env python3
"""Cut the fallen log off Makiling's tileset: the old way over the bungisngis's ravine.

WHY THIS EXISTS
---------------
Dilim fades the way that used to be there as she nears a crossing (level_4.gd
`_fades_the_old_way`), and the ravine the bungisngis stands at had no way over it to fade. The
delivered tileset (LEVEL4_Mt.Makiling/TextureMap_Makiling.png, section 7, "Log / branch
platforms") has one: a mossy log hung with vines, long enough to lie across a 300-px ravine.
build_dilim.py cuts the plates and tiles but no props ("no slopes, root or log platforms"), and
it needs scipy, which the tools' environment does not have; this needs none.

KEYING
------
The sheet is a flat cream page, not a checkerboard, so it is keyed the way build_dilim.py's
`flat_key` keys a flat page -- the page's colour read off the strip's border -- with two more
passes the log needs:

  page inside a loop    the branch's crook and the gaps between hanging leaves are page too,
                        cut off from the border by the art around them; any page pixel is
                        background, wherever it is, since nothing in the log is that cream
  the sheet's halo      the sheet rims its sprites with near-white; background grows through
                        near-white neutral pixels joined to it. The log's own greys (its
                        stones, about 160) are inside it and never touch background
  the label             "BROKEN LOGS & STUMPS" begins under the vines; only the largest
                        piece is kept

Usage:
    .venv/bin/python tools/build_dilim_log.py           # write the log
    .venv/bin/python tools/build_dilim_log.py --check   # verify it is up to date
"""

import argparse
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SHEET = ROOT / "LEVEL4_Mt.Makiling" / "TextureMap_Makiling.png"
OUT = ROOT / "game" / "assets" / "Level4" / "props" / "fallen_log.png"

# The log's strip on the sheet (x0, y0, x1, y1), measured by hand: section 7's long platform.
STRIP = (1075, 478, 1435, 562)
# How far a pixel may stray from the page and still be it; how pale and grey a halo pixel is;
# how far from the page the rim the key leaves still is.
PAGE_TOL = 18
NEUTRAL = 30
HALO_MIN = 190
RIM_TOL = 70
RIM_REACH = 2


def grown(mask: np.ndarray) -> np.ndarray:
    out = mask.copy()
    out[1:] |= mask[:-1]
    out[:-1] |= mask[1:]
    out[:, 1:] |= mask[:, :-1]
    out[:, :-1] |= mask[:, 1:]
    return out


def largest_piece(solid: np.ndarray) -> np.ndarray:
    height, width = solid.shape
    seen = np.zeros_like(solid)
    best: list[tuple[int, int]] = []
    for sy in range(height):
        for sx in range(width):
            if not solid[sy, sx] or seen[sy, sx]:
                continue
            piece = []
            queue = deque([(sy, sx)])
            seen[sy, sx] = True
            while queue:
                y, x = queue.popleft()
                piece.append((y, x))
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < height and 0 <= nx < width and solid[ny, nx] \
                            and not seen[ny, nx]:
                        seen[ny, nx] = True
                        queue.append((ny, nx))
            if len(piece) > len(best):
                best = piece
    out = np.zeros_like(solid)
    ys, xs = zip(*best)
    out[list(ys), list(xs)] = True
    return out


def cut() -> Image.Image:
    if not SHEET.exists():
        raise SystemExit(f"missing delivered art: {SHEET}")
    sheet = np.asarray(Image.open(SHEET).convert("RGB")).astype(np.int16)
    x0, y0, x1, y1 = STRIP
    rgb = sheet[y0:y1, x0:x1]
    page = np.median(np.concatenate([rgb[:3].reshape(-1, 3), rgb[-3:].reshape(-1, 3)]), axis=0)
    off_page = np.abs(rgb - page).max(axis=-1)
    neutral = (rgb.max(axis=-1) - rgb.min(axis=-1)) <= NEUTRAL
    background = neutral & (off_page <= PAGE_TOL)
    halo = neutral & (rgb.min(axis=-1) >= HALO_MIN)
    while True:
        more = background | (grown(background) & halo)
        if (more == background).all():
            break
        background = more
    for _ in range(RIM_REACH):
        background |= grown(background) & (off_page <= RIM_TOL)
    log = largest_piece(~background)
    out = np.dstack([rgb.astype(np.uint8), np.where(log, 255, 0).astype(np.uint8)])
    out[~log] = 0
    image = Image.fromarray(out, "RGBA")
    return image.crop(image.getbbox())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="compare, never write")
    args = parser.parse_args()
    log = cut()
    print(f"fallen log: {log.size}")
    if args.check:
        if not OUT.exists() or Image.open(OUT).convert("RGBA").tobytes() != log.tobytes():
            print(f"out of date: {OUT.relative_to(ROOT)}")
            return 1
        print("up to date")
        return 0
    OUT.parent.mkdir(parents=True, exist_ok=True)
    log.save(OUT)
    print("written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
