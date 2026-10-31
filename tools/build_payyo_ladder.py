#!/usr/bin/env python3
"""Lift Ang Bale's painted ladder off the house, so the ladder alone can fade.

WHY THIS EXISTS
---------------
`game/assets/Level1/hut.png` has a ladder painted against the house's right side, and the
ladder has no collision: it is the old way up, and the Climb route asks her to draw one.
Payyo fades its old ways as she nears them (game_level.gd `_fades_the_old_way`), and a
ladder painted into the house cannot fade without the house fading with it. So the picture
is split in two:

  hut_house.png          the house with the ladder taken off it -- what stood behind the
                         ladder put back (the wall, the deck), and sky where there was none
  props/hut_ladder.png   exactly the pixels taken, cropped to the ladder; drawn over the
                         house, the two make the delivered picture again (within a few
                         levels at the ladder's soft edges)

WHY FROM hut.png AND NOT THE ORIGINAL
-------------------------------------
`hut.png` was reduced from `level-1-assets/Level 1 Asset Hut.png` by a resample that does
not reproduce exactly, and every collision band in bale_2d.gd was measured off hut.png's own
alpha. Rebuilding the house from the original would move the art out from under its
collision. So hut.png stays the source, and the split is done on it.

WHAT IS PUT BACK, AND FROM WHERE (hut.png pixels)
-------------------------------------------------
  the wall, y 217-239    the rows 22 above: the planks repeat every eleven
  the deck, y 240-255    the same rows 101 to the left, the stretch of deck between the
                         second and third posts, where no post or rat guard hangs under it
  below the deck         nothing: the ladder only ever stood in front of sky there

Usage:
    .venv/bin/python tools/build_payyo_ladder.py           # write both files
    .venv/bin/python tools/build_payyo_ladder.py --check   # verify they are up to date
"""

import argparse
import io
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "game" / "assets" / "Level1"
SOURCE = ASSETS / "hut.png"
HOUSE = ASSETS / "hut_house.png"
LADDER = ASSETS / "props" / "hut_ladder.png"

# Rows of hut.png: the ladder's top (with its outline), the deck's face, the deck's underside.
TOP, DECK_TOP, DECK_BOTTOM = 217, 240, 256
# Where the house's wall and deck end on the right: past it the ladder stood against sky.
WALL_RIGHT = 308
# How far the plank rows repeat, and where the clear stretch of deck is.
PLANK_PERIOD_X2 = 22
CLEAR_DECK = 101


def ladder_at(x: int, y: int) -> bool:
    """Whether hut.png's pixel at (x, y) is the ladder's: its rails and rungs, and the dark
    outline down their left side, which in the deck rows reaches out to x 259."""
    if TOP <= y < DECK_TOP:
        return x >= 266
    if DECK_TOP <= y < DECK_BOTTOM:
        return x >= 259
    return y >= DECK_BOTTOM and x >= 256


def split(hut: Image.Image) -> tuple[Image.Image, Image.Image, tuple[int, int]]:
    hut = hut.convert("RGBA")
    house = hut.copy()
    ladder = Image.new("RGBA", hut.size, (0, 0, 0, 0))
    source, house_px, ladder_px = hut.load(), house.load(), ladder.load()
    width, height = hut.size
    for y in range(height):
        for x in range(width):
            if not ladder_at(x, y):
                continue
            ladder_px[x, y] = source[x, y]
            if y < DECK_TOP and x < WALL_RIGHT:
                house_px[x, y] = source[x, y - PLANK_PERIOD_X2]
            elif y < DECK_BOTTOM and x < WALL_RIGHT:
                house_px[x, y] = source[x - CLEAR_DECK, y]
            else:
                house_px[x, y] = (0, 0, 0, 0)
    box = ladder.getbbox()
    return house, ladder.crop(box), (box[0], box[1])


def png_bytes(image: Image.Image) -> bytes:
    out = io.BytesIO()
    image.save(out, format="PNG")
    return out.getvalue()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="compare, never write")
    args = parser.parse_args()
    house, ladder, corner = split(Image.open(SOURCE))
    # The level places the ladder at the house's art origin plus this corner (the tscn's
    # OldLadder position); printed so a redelivery that moves it is caught.
    print(f"ladder corner in hut.png: {corner}, size {ladder.size}")
    stale = []
    for path, image in ((HOUSE, house), (LADDER, ladder)):
        wanted = png_bytes(image)
        if args.check:
            if not path.exists() or Image.open(path).convert("RGBA").tobytes() != image.tobytes():
                stale.append(path.relative_to(ROOT))
        else:
            path.write_bytes(wanted)
    if stale:
        print("out of date: " + ", ".join(str(p) for p in stale))
        return 1
    print("up to date" if args.check else "written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
