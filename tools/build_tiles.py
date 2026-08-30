#!/usr/bin/env python3
"""Cut TextureMap_Piyesta into the tiles and props the rooms are built from.

WHY THIS EXISTS
---------------
Piyesta's four insides -- the church, the lit house, both alleys -- were drawn in code with
`draw_rect`: flat bands of one colour with a few lines on them. Beside the delivered plaza,
which is dense pixel art with mortar, moss, chips and a light coming from the left, they read
as grey boxes. The complaint was that they "look weird, not designed well, not detailed",
and it was right.

They should never have been hand-drawn. The artist shipped a labelled tileset for exactly
this job: three nine-slice wall sets, a stone plaza floor, church stucco, terracotta roof,
plank and thatch, a stair set with ledge caps, and a shelf of props -- lanterns, potted
plants, clay jars, balustrade, banners, festival ornaments. Building the rooms out of THOSE
makes them the same material as the plaza, because they are literally the same pixels.

WHAT COMES OUT
--------------
`game/assets/Level2/tiles/<name>.png` and a `tiles.json` naming every one.

The nine-slice sets keep the artist's own order, which is the order they are laid out on the
sheet and labelled: FILL TOP BOTTOM LEFT RIGHT TL TR BL BR. A wall built from them has a
grass or moss cap along its top edge and mitred corners, which is the whole reason the set
has nine tiles instead of one.

⚠ THE TILES ARE NOT ALL THE SAME SIZE. The nine-slice cells are about 65x78 and the plaza
floor blocks about 73x72; they are cut to their own alpha bounds rather than to a grid, so
nothing carries a margin of transparency that would show as a seam when tiled. The manifest
records each one's real size and the room code tiles by it.

    python3 tools/build_tiles.py [--check]
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "game" / "assets" / "Level2" / "texturemap.png"
OUT_DIR = ROOT / "game" / "assets" / "Level2" / "tiles"
MANIFEST = OUT_DIR / "tiles.json"

## The artist's own labels, in the order the cells are laid out on the sheet.
NINE = ["fill", "top", "bottom", "left", "right", "tl", "tr", "bl", "br"]
## Measured off the sheet's alpha: the nine cells of each set start at these columns.
NINE_COLS = [286, 369, 455, 541, 628, 713, 799, 886, 972]
NINE_WIDTH = 68

## Every region worth having, as (name, x, y, width, height). Measured, not guessed --
## `python3 -c` over the sheet's alpha gave every one of these bounds.
REGIONS: list[tuple[str, int, int, int, int]] = [
    # Section 1: stone plaza floor. Two rows of three; the top row is the cleanest.
    ("floor_a", 290, 62, 73, 70),
    ("floor_b", 371, 62, 74, 70),
    ("floor_c", 290, 139, 73, 72),
    ("floor_d", 371, 139, 74, 72),
    # Section 3: church stucco, and the one with a window in it.
    ("stucco_a", 827, 62, 68, 70),
    ("stucco_b", 904, 62, 48, 70),
    ("stucco_window", 1020, 139, 60, 72),
    ("stucco_pilaster", 961, 139, 50, 72),
    # Section 4: terracotta roof.
    ("roof", 1157, 62, 84, 70),
    # Section 5: thatch, and the two plank runs. ⚠ These start at 1411, not 1222 -- the
    # terracotta section is wider than it looks and the first cut put ROOF TILES on the
    # inside of the lit house's walls.
    ("thatch", 1411, 62, 88, 70),
    ("plank", 1411, 139, 88, 74),
    ("plank_h", 1510, 139, 100, 74),
    ("post", 1622, 139, 28, 74),
    # Section 7: stairs and steps, and the two small ledge caps beside them.
    ("stair_l", 289, 712, 79, 68),
    ("stair_r", 613, 712, 108, 68),
    ("step_block", 950, 712, 38, 68),
    # Props, cut to their own bounds.
    # Cropped BELOW each shelf heading -- see the note above the REGIONS table.
    ("banner", 1109, 332, 200, 182),
    ("lantern_hanging", 1352, 332, 99, 182),
    ("lantern_post", 1528, 332, 124, 182),
    ("plants", 1115, 566, 241, 114),
    ("jar_a", 1383, 566, 60, 84),
    ("jar_b", 1450, 566, 53, 84),
    ("balustrade", 1110, 750, 197, 70),
    ("ornament", 1391, 750, 240, 70),
]


def _crop(sheet: Image.Image, box: tuple[int, int, int, int]) -> Image.Image | None:
    """Cut, then shrink to what is actually opaque.

    ⚠ TIGHT TO THE ALPHA, not to the measured box. A tile carrying two rows of transparent
    margin tiles with two rows of gap, which reads as mortar in the wrong place and as a
    visible grid on a floor -- and the sheet's cells are not evenly spaced anyway.
    """
    piece = sheet.crop(box)
    alpha = np.array(piece)[..., 3] > 16
    if not alpha.any():
        return None
    rows = np.where(alpha.any(axis=1))[0]
    cols = np.where(alpha.any(axis=0))[0]
    return piece.crop((int(cols.min()), int(rows.min()),
                       int(cols.max()) + 1, int(rows.max()) + 1))


def build(check: bool) -> int:
    if not SOURCE.exists():
        print("missing source: %s" % SOURCE)
        return 1
    sheet = Image.open(SOURCE).convert("RGBA")
    if not check:
        OUT_DIR.mkdir(parents=True, exist_ok=True)

    tiles: dict[str, dict] = {}
    problems: list[str] = []

    def emit(name: str, box: tuple[int, int, int, int]) -> None:
        piece = _crop(sheet, box)
        if piece is None:
            problems.append("%s is empty at %s" % (name, box))
            return
        tiles[name] = {"file": "%s.png" % name, "size": [piece.width, piece.height]}
        if not check:
            piece.save(OUT_DIR / ("%s.png" % name))

    # The three nine-slice sets, in the rows the sheet lays them out on.
    for prefix, y, height in [("ground", 283, 78), ("moss", 429, 76), ("church", 573, 74)]:
        for index, part in enumerate(NINE):
            emit("%s_%s" % (prefix, part), (NINE_COLS[index], y, NINE_COLS[index] + NINE_WIDTH,
                                            y + height))
    for name, x, y, width, height in REGIONS:
        emit(name, (x, y, x + width, y + height))

    if not check:
        MANIFEST.write_text(json.dumps({
            "$comment": "Generated by tools/build_tiles.py from TextureMap_Piyesta. Do not "
                        "hand-edit -- edit the tool. Sizes are the tile's real opaque extent, "
                        "so tiling by them leaves no seam.",
            "nine_slice": ["ground", "moss", "church"],
            "parts": NINE,
            "tiles": tiles,
        }, indent=2) + "\n")

    for problem in problems:
        print("  PROBLEM  %s" % problem)
    print("%s %d tiles" % ("checked" if check else "wrote", len(tiles)))
    for prefix in ["ground", "moss", "church"]:
        got = [n for n in tiles if n.startswith(prefix + "_")]
        print("   %-8s nine-slice: %d/9  fill %s" % (
            prefix, len(got), tiles.get(prefix + "_fill", {}).get("size")))
    print("   props: %s" % ", ".join(n for n, *_ in REGIONS))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(build("--check" in sys.argv))
