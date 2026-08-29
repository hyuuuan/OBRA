#!/usr/bin/env python3
"""Composite Piyesta's plaza into the two plates the game actually needs.

WHY THIS EXISTS
---------------
The plaza arrived as six registered 1920x1080 layers -- sky, clouds, church, people, huts,
ground -- and composited at one transform they reproduce `Level2_CompletedLook` exactly.
They are ONE PAINTING cut into six, not a parallax rig.

The level treated them as a parallax rig, and it fell apart in the only way that was
available to it. `DepthLayer2D` offsets a layer by `camera_delta * (1 - scroll_scale)` --
the WHOLE delta, both axes -- so the moment the camera moved vertically, six plates that
had been drawn to register slid to six different heights. What the player saw was the
plaza's terrace appearing twice at two heights with sky between them. Tiling made it worse:
four copies of the church across a plaza that has one.

So the compositing happens HERE, once, offline, where it cannot drift:

  plaza.png        all six, flattened -- the plaza as it was painted
  plaza_front.png  only what stands in FRONT of the player: the grass lip and the stone
                   retaining wall along the bottom of the plaza

TWO PLATES BECAUSE THERE ARE TWO SIDES OF THE PLAYER, and that is the whole reason the
front one is cut out. The apo walks on the cobbles the dancers are dancing on. The grass
verge and the wall below it are nearer the viewer than that, so they have to draw OVER the
apo's feet -- otherwise the character stands on top of the plaza's front kerb like a shelf,
which is exactly what the first pass looked like.

WHERE THE LINE IS
-----------------
`WALK_ROW` is where the painted dancers' feet are, measured off `mg_people`'s own alpha:
the lowest row it covers. That is the ground in this picture by definition -- it is where
the artist stood four people. The level's collision is placed on it, and `FRONT_ROW` starts
a little below so the cut is hidden behind the apo's shins rather than slicing them.

    python3 tools/build_plaza.py [--check]
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "game" / "assets" / "Level2"

# Back to front. This is the order they compose in, and it is the order the level used to
# declare as six separate parallax layers.
LAYERS = ["bg_sky", "bg_clouds", "mg_church", "ground", "mg_people", "fg_huts"]

# The plate that carries what is nearer the viewer than the player.
FRONT_LAYER = "fg_huts"
## A little below the walk line, so the cut runs behind the apo's shins instead of across
## them. Measured: fg_huts' front band is solid from row 839 down.
FRONT_ROW = 828


def walk_row() -> int:
    """Where the painted dancers' feet are -- the ground line, by the artist's own hand."""
    people = np.array(Image.open(SRC / "mg_people.png").convert("RGBA"))[..., 3] > 24
    rows = np.where(people.any(axis=1))[0]
    return int(rows.max())


def _wall_foot() -> int:
    """The lowest row the plaza's own structure reaches -- the bottom of the retaining wall."""
    huts = np.array(Image.open(SRC / "fg_huts.png").convert("RGBA"))[..., 3] > 24
    return int(np.where(huts.any(axis=1))[0].max())


## A stretch of plain verge and wall, taken from behind the dancers where nothing is built
## on it, to be repeated along the rest of the level.
BAND_FROM = (940, 1300)


def _band(plate: Image.Image, size: tuple[int, int], top: int) -> Image.Image:
    """⚠ THE GROUND ONLY, from `top` down. Taking the full height of the slice repeats
    everything standing on it -- the first cut tiled the dancers and the palms across the
    whole level, twenty-eight dancers instead of four."""
    return plate.crop((BAND_FROM[0], top, BAND_FROM[1], size[1]))


## The painting's own sky, as one column, stretched across the widened canvas. A flat colour
## behind the plate cannot match it -- the sky runs from #0085FD at the top to #2BA2EA at the
## horizon -- so the join showed as a hard vertical edge with a lighter rectangle beyond it.
## ⚠ TAKEN FROM `bg_sky` AND NOT FROM THE COMPOSITE. The flattened painting has the kiosko
## and the palms drawn over its sky, so a column sampled from it carries whatever happens to
## be at that x -- the first cut pulled a roof beam and a hedge out of the plaza and stretched
## them as horizontal bars across the whole width of the level. The sky plate is sky.
def _sky(size: tuple[int, int]) -> Image.Image:
    plate = np.array(Image.open(SRC / "bg_sky.png").convert("RGBA"))
    column = plate[:, 300:301, :]
    return Image.fromarray(np.repeat(column, size[0] * 3, axis=1), "RGBA")


def _widen(plate: Image.Image, size: tuple[int, int], band: Image.Image,
           top: int, sky: Image.Image = None) -> Image.Image:
    wide = Image.new("RGBA", (size[0] * 3, size[1]), (0, 0, 0, 0))
    if sky is not None:
        wide.alpha_composite(sky)
    x = 0
    while x < wide.width:
        wide.alpha_composite(band, (x, top))
        x += band.width
    # The painting goes on last and in the middle, so nothing repeats over it.
    wide.alpha_composite(plate, (size[0], 0))
    return wide


def build(check: bool) -> int:
    size = None
    plaza = None
    for name in LAYERS:
        path = SRC / ("%s.png" % name)
        if not path.exists():
            print("  PROBLEM  missing layer %s" % path.name)
            return 1
        layer = Image.open(path).convert("RGBA")
        if size is None:
            size = layer.size
            plaza = Image.new("RGBA", size, (0, 0, 0, 0))
        elif layer.size != size:
            # Registration is the entire premise. A plate that is not the same canvas
            # cannot be composited at the same transform.
            print("  PROBLEM  %s is %s, not %s" % (path.name, layer.size, size))
            return 1
        plaza.alpha_composite(layer)

    # ⚠ NOTHING BELOW THE WALL. `bg_sky` is a full opaque plate running to plate row 1025,
    # while the plaza's retaining wall stops around 935 -- so the flattened painting carries
    # a hundred rows of SKY UNDERNEATH THE GROUND. Left in, the level shows a strip of blue
    # below the plaza and the whole thing reads as a slab floating in the air, which is
    # exactly the complaint. The composite is cut off at the wall's own foot and what is
    # under a plaza is the level's ground fill.
    flat = np.array(plaza)
    # Three rows INSIDE the wall's foot rather than one past it: the plate's bottom edge is
    # antialiased against the sky behind it, so cutting exactly at the last opaque row leaves
    # a one-pixel cyan seam running the width of the plaza.
    flat[_wall_foot() - 2:, :, 3] = 0
    plaza = Image.fromarray(flat, "RGBA")

    front_src = Image.open(SRC / ("%s.png" % FRONT_LAYER)).convert("RGBA")
    front = Image.new("RGBA", size, (0, 0, 0, 0))
    # Same canvas, same offset: the front plate is drawn at the same position as the
    # backdrop and simply has nothing above the cut, so the two cannot slide apart.
    front.paste(front_src.crop((0, FRONT_ROW, size[0], size[1])), (0, FRONT_ROW))

    # ⚠ AND THE WALL RUNS ON PAST THE PLAZA. The player is stopped by walls at the edges of
    # the painting, but the CAMERA is not -- it is clamped to the level's world bounds, which
    # have to be wide enough to hold the four rooms parked thousands of units away. So at
    # either end of the plaza the view ran off the picture into empty sky.
    #
    # The painting cannot be tiled -- one church becomes four -- but its verge and retaining
    # wall are a repeating band, so THAT is tiled onto a canvas three plates wide with the
    # painting in the middle. The plaza ends at a wall the player can see continue.
    line = walk_row()
    plaza = _widen(plaza, size, _band(plaza, size, line), line, _sky(size))
    front = _widen(front, size, _band(front, size, FRONT_ROW), FRONT_ROW)
    # AND CUT BELOW THE WALL AGAIN. The sky column is composited full height, so widening
    # puts sky back under the ground that was just cleared out of it -- a pale blue strip
    # between the retaining wall and the level's dark ground fill.
    wide = np.array(plaza)
    wide[_wall_foot() - 2:, :, 3] = 0
    plaza = Image.fromarray(wide, "RGBA")
    size = plaza.size

    if not check:
        plaza.save(SRC / "plaza.png")
        front.save(SRC / "plaza_front.png")
    print("%s plaza.png and plaza_front.png at %dx%d (painting centred, wall tiled either side)"
        % ("checked" if check else "wrote", size[0], size[1]))
    print("   walk line (painted dancers' feet)  plate row %d" % line)
    print("   front plate starts at              plate row %d" % FRONT_ROW)
    print("   painting cut off below             plate row %d (the wall's foot)" % _wall_foot())
    if FRONT_ROW < line:
        print("  PROBLEM  the front plate starts above the walk line and would cover the apo")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(build("--check" in sys.argv))
