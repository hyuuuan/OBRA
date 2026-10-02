#!/usr/bin/env python3
"""The maya that carry Lola's painting through Piyesta's alleys, as pixel art.

WHY
---
Kent: "fix the appearance of the birds ... its so weird its not detailed enough for a 8bit
game". They were drawn in code (ScrapBird2D._draw): three smooth polygons and a circle, which
at the alley's zoom are antialiased brown arrowheads with no pixel in them, beside an apo who
is painted pixel by pixel. So they are pixel art now, at the apo's own density -- one texel to
one world pixel -- and the code only picks a frame.

WHAT THEY ARE
-------------
The maya: the Eurasian tree sparrow, the bird of every Philippine town plaza and the one the
design means. What makes one read as a maya and not "a brown bird" is its head, so that is where
the pixels go: a chestnut cap, a white cheek with a black spot in it, a black bib under the
bill, black lores, a stubby dark cone of a bill. A streaked brown back, a white wing bar, buff
below. Light from the upper left, like everything in Piyesta.

HOW
---
The bodies are hand-placed pixels -- one character per pixel, below -- because a face this
small is drawn, not computed. The flying wing is the one thing that moves, so it is rasterised
from a feathered outline at each point of the stroke (up, level, down), foreshortened on the
level beat as a wing seen edge-on is, shaded by where along it a pixel is (lit leading edge,
streaked coverts, the white bar, dark primaries) and given its own outline so it reads against
the body it crosses.

The painting piece a bird carries is drawn here too, as a small torn piece of canvas with a
little of the Dagat sea on it, the same size and anchor as the card it replaces.

    python3 tools/build_birds.py            write game/assets/Level2/birds/
    python3 tools/build_birds.py --check    exit 1 if the committed files are stale
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "Level2" / "birds"

PALETTE = {
    "O": "#24180f",  # outline
    "K": "#16110d",  # black: bib, lores, cheek spot
    "C": "#7e3f1d",  # chestnut cap, shade
    "c": "#a4582a",  # chestnut cap
    "h": "#c07a44",  # chestnut cap, lit
    "W": "#f3eee2",  # white cheek and collar
    "w": "#cdc5b4",  # white, shade
    "B": "#6e4b2c",  # back
    "L": "#93693f",  # back, lit
    "b": "#3d2919",  # back streak
    "F": "#2f2217",  # flight feathers
    "f": "#4a3524",  # flight feather edge
    "V": "#ebe2cc",  # wing bar
    "G": "#c8bba3",  # belly
    "g": "#a6987f",  # belly, shade
    "Y": "#3a332d",  # bill
    "y": "#6d655c",  # bill, lit
    "E": "#0b0908",  # eye
    "e": "#ffffff",  # eye glint
    "P": "#a87c5c",  # legs
    # The painting piece.
    "o": "#3b2e22",  # its edge
    "q": "#f4ecd8",  # canvas, lit
    "p": "#e2d5b9",  # canvas
    "r": "#b4a383",  # canvas, shade
    "S": "#3a4560",  # sky
    "s": "#56628a",  # sky, lighter
    "t": "#8e97b0",  # cloud
    "M": "#2b3a33",  # the island
    "m": "#405a49",  # the island, lit
    "A": "#2b7480",  # sea
    "a": "#4f9fa5",  # sea, lighter
    "x": "#cfe6e2",  # foam
}

# --- The bodies, facing right ------------------------------------------------------------

PERCH = """
..................OOOOO.......
................OOchhhcO......
...............OcchhhhccO.....
..............OCcccccccccO....
..............OCCCcccccccKO...
.............OCCCWWWWWKEeKYO..
.............OCCWWKKWWWWKKyYO.
.............OCWWWKKWWWWKKYO..
............OBWWWWWWWWWKKKO...
...........OBBLWWWWWWWGKKO....
.........OOBBLLBwWWWWGGGGO....
.......OOBLbLBbLBwwGGGGGGGO...
.....OOBLbLBLbLBBBGGGGGGGGO...
...OOFFVVVVVVVBbBBGGGGGGGgO...
.OOFFFFfBbBbBBBBBGGGGGGGggO...
OFFFFFOOfFfFfBBBGGGGGGggggO...
OOOOOO..OOfFFBBgGGGGGgggO.....
.........OOOOggggggggOO.......
.............OOOOOOOO.........
...............P...P..........
..............PP..PP..........
"""

BLINK = PERCH.replace("KEeKYO..", "KKKKYO..")

PECK = """
..............................
..............................
..............................
..............................
.OOO..........................
.OFFOO........................
..OFFfOOO.....................
...OOfFFBBOOOO................
.....OOVVVVBBBOOO.............
.......OBbLBLbLBBOO...........
........OBLbLBLBBBBOO.........
.........OBBBBBBBBGGGOOOO.....
..........OBBBBGGGGGWWWccO....
..........OgGGGGGGGWWKWCchcO..
...........OgGGGGGWWWWWKCccO..
............OggggGGWWWKKEeKO..
.............OOggggOKKKKKKYyO.
...............OOOOOKKKKYYYO..
.................P..POOOOOOO..
.................P..P.........
...............PP..PP.........
"""

DAZED = """
..............................
..............................
..............................
..............................
..............................
..............................
..............................
..............................
..............................
..........PP..PP..............
...........P...P..............
.......OOOOOOOOOOOOO..........
.....OOgggGGGGGGGGGGOOO.......
...OOFFfBgGGGGGGGGWWWKKOO.....
.OOFFFFfBBLBbGGGGWWKKKKKYO....
OFFFFFFBBLBbLBBBBWWWKOOKYyO...
.OOFFFFBBBBBBBBBCCCccccchhO...
...OOOOOOOOOOOOOOOOOOOOOOOO...
"""

# In flight: head, back, belly and tail, with nothing on the back -- the wing goes there.
FLYING = """
.......................OOOOO........
.....................OOchhcCO.......
....................OcchhccccO......
..OOOO..........OOOBCCcccccKKO......
.OFFfFOO....OOOBBLbBCWWWWKEeKYO.....
OFFFFFFfOOOOBLbLBLBBWWKKWWKKKyYO....
.OFFFFFFBBBLBbLBBBBBWWKKWWWKKYO.....
..OOFFFfBBBBBBBBBGGWWWWWWKKKO.......
....OOOOgGGGGGGGGGGGGGWWWKO.........
........OOgggggggggGGGGOO...........
..........OOOOOOOOOOOOO.............
"""
# Where the wing meets the body, in FLYING's own pixels.
SHOULDER = (17.0, 4.0)
WING_LENGTH = 18.0

# The piece of painting it carries, 21 x 24: torn canvas, a little Dagat sky and sea on it.
SCRAP = """
..oooo..ooooooo.ooo..
.oqqqpooqqqqqqpopppo.
oqpSSSSSSSSSSSSSSSppo
oqSSsssSSSSSSSStSSSpo
.oSsssSSSSSSSStttSSpo
.opSSSSSSSSSSSSSSSSpo
oqSSSSSSSSSSSmmSSSSpo
oqSSSSSSSSSSmmmmSSSpo
opSSSSSSSSSmMMMMmSSpo
.opAAAAAAAAAAAAAAAApo
.opAaaAAAAAAxAAAAAApo
oqpAAAAAAAAAAAAaaAApo
oqpAAAAxAAAAAAAAAAApo
opAAAAAAAAAaaAAAAArpo
.opAaaAAAAAAAAAAAArpo
.opAAAAAAAAAAAAxAArpo
oqpAAAAAAAaaAAAAAArpo
opAAAxAAAAAAAAAaaArpo
.opAAAAAAAAAAAAAAArpo
oqpAAAAaaAAAAxAAAArpo
opprrrrrrrrrrrrrrrrpo
.opppppppppppppppppro
..ooppoooopppppoooro.
....oo....ooooo..oo..
"""

# --- The sheet ---------------------------------------------------------------------------

## Every frame is a cell of this size, and the bird's own origin -- the point ScrapBird2D's
## node sits at -- is at ORIGIN in every cell, so the code draws any frame the same way.
CELL = (44, 44)
ORIGIN = (22, 24)
## Where, relative to the origin, the drawing is pinned in each state. In the air the shoulder is
## on the origin. Perched, the feet are ten below it -- on the string. On the floor, six below:
## the node of a bird on the floor sits six above the floor line (ScrapBird2D, `floor_y - 6`).
PERCH_FEET = 10
FLOOR_FEET = 6


def _rgba(key: str) -> tuple:
    value = PALETTE[key]
    return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def draw(art: str) -> Image.Image:
    rows = art.strip("\n").split("\n")
    width = max(len(row) for row in rows)
    for index, row in enumerate(rows):
        if len(row) != width:
            raise ValueError(f"row {index} is {len(row)} wide, not {width}")
    image = Image.new("RGBA", (width, len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, key in enumerate(row):
            if key != ".":
                image.putpixel((x, y), _rgba(key))
    return image


def _wing(angle_deg: float, thin: float, size: tuple) -> Image.Image:
    """The near wing from the shoulder: swept back, raised by `angle_deg` (down when negative),
    and `thin` of its width where it is seen edge-on."""
    angle = math.radians(angle_deg)
    axis = (-math.cos(angle), -math.sin(angle))
    normal = (-axis[1], axis[0])
    length = WING_LENGTH * (0.8 + 0.2 * thin)
    sx, sy = SHOULDER
    # (along, half-width): the leading edge out to the tip, then the trailing edge back, notched
    # between the primaries near the tip.
    outline = [(0.0, 3.0), (0.3, 3.6), (0.6, 3.0), (0.85, 1.8), (1.0, 0.3),
               (1.0, -0.6), (0.93, -1.6), (0.88, -0.6), (0.82, -2.2), (0.76, -1.0),
               (0.70, -2.8), (0.55, -3.6), (0.3, -4.2), (0.0, -3.0)]
    points = [(sx + axis[0] * length * t + normal[0] * half * thin,
               sy + axis[1] * length * t + normal[1] * half * thin) for t, half in outline]
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    wing = Image.new("RGBA", size, (0, 0, 0, 0))
    for y in range(size[1]):
        for x in range(size[0]):
            if not mask.getpixel((x, y)):
                continue
            dx, dy = x + 0.5 - sx, y + 0.5 - sy
            along = (dx * axis[0] + dy * axis[1]) / WING_LENGTH
            across = dx * normal[0] + dy * normal[1]
            if along > 0.62:
                key = "F" if (x + y) % 3 else "f"
            elif 0.43 < along <= 0.49:
                key = "V"
            elif across > 2.2:
                key = "L"
            elif (int(along * 10) + int(across)) % 3 == 0:
                key = "b"
            else:
                key = "B"
            wing.putpixel((x, y), _rgba(key))
    return wing


def flying(angle_deg: float, thin: float) -> tuple:
    """A flight frame and where its shoulder is in it. Laid on a canvas with room above and
    below the body for the wing at either end of its stroke."""
    body = draw(FLYING)
    room = 18
    size = (body.width, body.height + room * 2)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(body, (0, room))
    global SHOULDER
    kept = SHOULDER
    SHOULDER = (kept[0], kept[1] + room)
    wing = _wing(angle_deg, thin, size)
    SHOULDER = kept
    # The wing's own outline, so it reads against the body it crosses.
    for y in range(size[1]):
        for x in range(size[0]):
            if wing.getpixel((x, y))[3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < size[0] and 0 <= ny < size[1] and wing.getpixel((nx, ny))[3]:
                    canvas.putpixel((x, y), _rgba("O"))
                    break
    canvas.alpha_composite(wing)
    return canvas, (int(kept[0]), int(kept[1]) + room)


def _feet(image: Image.Image) -> tuple:
    """The middle of a standing drawing's feet, and the row under them."""
    box = image.getbbox()
    legs = [x for x in range(image.width) for y in range(image.height)
            if image.getpixel((x, y))[:3] == _rgba("P")[:3]]
    middle = (min(legs) + max(legs)) // 2 if legs else (box[0] + box[2]) // 2
    return middle, box[3]


def _beak(image: Image.Image) -> tuple:
    """The tip of the bill: the bill pixel furthest forward."""
    bill = [(x, y) for x in range(image.width) for y in range(image.height)
            if image.getpixel((x, y))[:3] in (_rgba("Y")[:3], _rgba("y")[:3])]
    tip = max(bill, key=lambda point: (point[0], -point[1]))
    return tip


def frames() -> list:
    """(name, picture, the point in the picture that goes on ORIGIN + pin)."""
    out = []
    for name, angle, thin in (("fly_up", 62.0, 1.0), ("fly_mid", 14.0, 0.5),
                              ("fly_down", -38.0, 1.0)):
        picture, shoulder = flying(angle, thin)
        out.append((name, picture, shoulder, (0, 0)))
    for name, art, pin in (("perch", PERCH, PERCH_FEET), ("blink", BLINK, PERCH_FEET),
                           ("stand", PERCH, FLOOR_FEET), ("peck", PECK, FLOOR_FEET),
                           ("dazed", DAZED, FLOOR_FEET)):
        picture = draw(art)
        feet = _feet(picture)
        out.append((name, picture, feet, (0, pin)))
    return out


def build() -> dict:
    """Every file this writes, as bytes."""
    listed = frames()
    sheet = Image.new("RGBA", (CELL[0] * len(listed), CELL[1]), (0, 0, 0, 0))
    manifest = {"cell": list(CELL), "origin": list(ORIGIN), "frames": {}}
    for index, (name, picture, anchor, pin) in enumerate(listed):
        at = (index * CELL[0] + ORIGIN[0] + pin[0] - anchor[0], ORIGIN[1] + pin[1] - anchor[1])
        box = picture.getbbox()
        if at[0] + box[0] < index * CELL[0] or at[0] + box[2] > (index + 1) * CELL[0] \
                or at[1] + box[1] < 0 or at[1] + box[3] > CELL[1]:
            raise ValueError(f"{name} does not fit its {CELL} cell")
        sheet.alpha_composite(picture, at)
        tip = _beak(picture)
        manifest["frames"][name] = {
            "index": index,
            # The bill's tip relative to the bird's origin: where the piece it carries hangs.
            "beak": [at[0] - index * CELL[0] + tip[0] - ORIGIN[0], at[1] + tip[1] - ORIGIN[1]],
        }
    scrap = draw(SCRAP)
    if scrap.size != (21, 24):
        raise ValueError(f"the scrap is {scrap.size}, and ScrapBird2D.draw_scrap needs 21 x 24")
    files = {}
    for name, image in (("maya.png", sheet), ("scrap.png", scrap)):
        from io import BytesIO
        buffer = BytesIO()
        image.save(buffer, "PNG")
        files[name] = buffer.getvalue()
    files["maya.json"] = (json.dumps(manifest, indent=2) + "\n").encode()
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    files = build()
    if args.check:
        stale = [name for name, data in files.items()
                 if not (OUT / name).exists()
                 or hashlib.sha256((OUT / name).read_bytes()).digest() != hashlib.sha256(data).digest()]
        if stale:
            print("stale: " + ", ".join(stale), file=sys.stderr)
            return 1
        print(f"{len(files)} bird files are up to date")
        return 0
    OUT.mkdir(parents=True, exist_ok=True)
    for name, data in files.items():
        (OUT / name).write_bytes(data)
    print(f"Wrote {len(files)} files to {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
