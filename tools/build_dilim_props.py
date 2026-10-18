#!/usr/bin/env python3
"""Draw the things in Dilim's satchel as pixel icons: asin, abo, bawang, kandila, langis, buntot pagi.

WHY CODE-DRAWN
--------------
Like the creature strips (build_dilim_creatures.py): nothing in the Makiling delivery is a
pickup, and Kent's call was code-drawn now, replaceable by drawn art later without a code change
-- the quick slots and the pickups load `<id>.png` from game/assets/Level4/props/, so a delivered
`asin.png` simply wins.

HOW THEY ARE DRAWN
------------------
In the project's own idiom (tools/pixelart.py): a 16 x 16 logical grid scaled by PX = 2 to a
32 px icon, short ramps, light from the upper left. Each sits on a leaf -- the way an offering
is set down -- so the six read as one family at a glance, and each is its own colour so a
player tells them apart by colour before shape: white salt, grey ash, cream-and-violet garlic,
a candle's amber flame, a bottle's oil-gold, and the bone-pale barb on a stingray-tail whip.
None is a shape from the fifty.

USAGE
    python3 tools/build_dilim_props.py            # write game/assets/Level4/props/
    python3 tools/build_dilim_props.py --check    # verify the committed icons are current
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import pixelart
from pixelart import Canvas, ramp

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "Level4" / "props"

GRID = 16
ICON = GRID * pixelart.PX

LEAF = ramp(["#1d3a1c", "#2f5a2a", "#4a7f38", "#6fa24a"])
SALT = ramp(["#9aa3ab", "#cfd6dc", "#f1f4f6", "#ffffff"])
ASH = ramp(["#3b3a3d", "#5c5a5e", "#7f7c80", "#a7a3a6"])
CLAY = ramp(["#5a2e1a", "#8a4a2a", "#b06a3c"])
GARLIC = ramp(["#b9a88e", "#e6dcc8", "#fbf6ea"])
VIOLET = ramp(["#6b4a7a", "#9a74ad"])
WAX = ramp(["#c9b48a", "#ead9b0", "#fbf1d8"])
FLAME = ramp(["#b8641c", "#ffbd3d", "#fff0c0"])
GLASS = ramp(["#3f5a5e", "#6d8f92", "#b7d3d1"])
OIL = ramp(["#8a5a12", "#c98a22", "#f0c25a"])
CORK = ramp(["#6b4a2a", "#9a7046"])
TAIL = ramp(["#2e2a2c", "#5a5052", "#8a7c78"])
RATTAN = ramp(["#4a2e16", "#7a4e26", "#b07a40"])
BARB = ramp(["#e3d3b0"])[0]


def leaf(canvas: Canvas) -> None:
    """The leaf each one is set down on: a low oval, its midrib catching the light."""
    for y, (x0, x1) in enumerate([(4, 11), (2, 13), (1, 14), (2, 13)]):
        canvas.hline(x0, 12 + y, x1 - x0 + 1, LEAF[1] if y else LEAF[2])
    canvas.hline(3, 13, 10, LEAF[0])
    canvas.hline(4, 12, 7, LEAF[3])


def draw_asin() -> Canvas:
    canvas = Canvas(GRID, GRID, seed=401)
    leaf(canvas)
    # A heap of salt, crystals catching the light up its left side.
    for y, (x0, x1) in enumerate([(7, 8), (6, 9), (5, 10), (4, 11), (3, 12), (3, 12)]):
        canvas.hline(x0, 6 + y, x1 - x0 + 1, SALT[1])
        canvas.px(x0, 6 + y, SALT[2])
        canvas.px(x1, 6 + y, SALT[0])
    canvas.px(7, 6, SALT[3])
    canvas.speckle(4, 8, 8, 4, SALT[3], 0.18)
    canvas.speckle(4, 9, 8, 3, SALT[0], 0.1)
    return canvas


def draw_abo() -> Canvas:
    canvas = Canvas(GRID, GRID, seed=402)
    leaf(canvas)
    # A clay bowl of ash, a little of it lifting off the top.
    canvas.hline(3, 9, 10, CLAY[2])
    for y, (x0, x1) in enumerate([(3, 12), (4, 11), (5, 10)]):
        canvas.hline(x0, 10 + y, x1 - x0 + 1, CLAY[1])
    canvas.hline(5, 12, 6, CLAY[0])
    canvas.hline(4, 8, 8, ASH[2])
    canvas.hline(5, 7, 6, ASH[1])
    canvas.speckle(4, 7, 8, 2, ASH[3], 0.25)
    for x, y in ((6, 5), (9, 4), (7, 3), (10, 2)):
        canvas.px(x, y, ASH[2])
    return canvas


def draw_bawang() -> Canvas:
    canvas = Canvas(GRID, GRID, seed=403)
    leaf(canvas)
    # A bulb of garlic: cloves in cream, violet between them, a dry stalk on top.
    for y, (x0, x1) in enumerate([(6, 9), (4, 11), (3, 12), (3, 12), (4, 11), (5, 10)]):
        canvas.hline(x0, 6 + y, x1 - x0 + 1, GARLIC[1])
        canvas.px(x0, 6 + y, GARLIC[2])
        canvas.px(x1, 6 + y, GARLIC[0])
    for x in (5, 8, 10):
        canvas.vline(x, 8, 3, VIOLET[1])
    canvas.px(7, 7, GARLIC[2])
    canvas.vline(7, 3, 3, GARLIC[0])
    canvas.px(8, 3, GARLIC[0])
    return canvas


def draw_kandila() -> Canvas:
    canvas = Canvas(GRID, GRID, seed=404)
    leaf(canvas)
    # A candle stub, lit: the wax lit down its left, the flame the one warm thing.
    canvas.fill(6, 6, 4, 6, WAX[1])
    canvas.vline(6, 6, 6, WAX[2])
    canvas.vline(9, 6, 6, WAX[0])
    canvas.px(8, 6, WAX[2])
    canvas.vline(7, 4, 2, FLAME[0])
    canvas.px(7, 2, FLAME[1])
    canvas.px(7, 3, FLAME[2])
    canvas.px(8, 3, FLAME[1])
    canvas.px(6, 4, FLAME[1])
    return canvas


def draw_langis() -> Canvas:
    canvas = Canvas(GRID, GRID, seed=405)
    leaf(canvas)
    # A small bottle of lamp oil: glass at the edges, the oil gold inside, a cork.
    canvas.fill(5, 6, 6, 6, GLASS[1])
    canvas.fill(6, 8, 4, 4, OIL[1])
    canvas.hline(6, 8, 4, OIL[2])
    canvas.vline(5, 6, 6, GLASS[2])
    canvas.vline(10, 6, 6, GLASS[0])
    canvas.fill(7, 3, 2, 3, GLASS[1])
    canvas.px(7, 3, GLASS[2])
    canvas.fill(7, 1, 2, 2, CORK[1])
    canvas.px(8, 2, CORK[0])
    return canvas


def draw_buntot_pagi() -> Canvas:
    canvas = Canvas(GRID, GRID, seed=406)
    leaf(canvas)
    # A stingray's tail dried into a whip: a rattan-bound grip low on the left, the tail thick off
    # it and tapering up and over in a curl, and the barb near its root the one pale thing.
    for i, (x, y) in enumerate([(2, 11), (3, 10), (4, 9)]):
        canvas.px(x, y, RATTAN[1])
        canvas.px(x + 1, y, RATTAN[2] if i % 2 == 0 else RATTAN[0])
    tail = [(5, 8), (6, 7), (7, 6), (8, 5), (9, 4), (10, 3), (11, 3), (12, 3), (13, 4), (13, 5), (12, 6)]
    for i, (x, y) in enumerate(tail):
        canvas.px(x, y, TAIL[1])
        if i < 5:
            canvas.px(x, y + 1, TAIL[0])
            canvas.px(x - 1, y, TAIL[2])
    canvas.px(7, 5, BARB)
    canvas.px(8, 4, BARB)
    return canvas


ITEMS = {"asin": draw_asin, "abo": draw_abo, "bawang": draw_bawang,
         "kandila": draw_kandila, "langis": draw_langis, "buntot_pagi": draw_buntot_pagi}


def icon(item: str):
    return ITEMS[item]().image()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="compare, do not write")
    args = ap.parse_args()
    pictures = pixelart.Pictures(args.check, ROOT)
    for item in ITEMS:
        pictures.put(icon(item), OUT / f"{item}.png")
    if args.check:
        if pictures.stale:
            print("stale or missing:\n  " + "\n  ".join(pictures.stale))
            return 1
        print(f"OK: {len(ITEMS)} satchel icons are current")
        return 0
    print(f"wrote {len(ITEMS)} icons to {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
