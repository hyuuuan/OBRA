#!/usr/bin/env python3
"""Cut the delivered plaza painting into the backdrop the level stands in front of.

WHY THIS EXISTS, AND WHY IT IS SHAPED THIS WAY
----------------------------------------------
The plaza arrived as six registered 1920x1080 layers which composite at one transform into
`Level2_CompletedLook`. It is ONE PAINTING cut into six, not a parallax rig -- `DepthLayer2D`
offsets a layer by `camera_delta * (1 - scroll_scale)` on BOTH axes, so the moment the camera
moved vertically the six plates slid to six different heights and the plaza's terrace appeared
twice with sky between. So they are flattened here, once, offline, where they cannot drift.

⚠ AND THEN THE PAINTING IS CUT OFF AT THE GROUND LINE. That is the whole of the fix for the
doubled platform, and it took three attempts to find.

The painting is a VISTA. It has a low wall with planting behind the dancers AND a grass verge
over a retaining wall in front of them, with about sixty pixels of cobble between -- and the
apo is ninety-six tall. Stand him in that strip and he spans it, with a grass-topped wall
above his knees and another below them: two platforms, in a plaza that has one. No amount of
moving the collision fixes it, because both walls are IN THE PICTURE.

Cutting the plate at the painted dancers' feet removes the near half entirely. What is left
is sky, clouds, hills, the church, the houses, the kiosko, the arch, the palms and the dancers
themselves -- all of it standing ON the cut -- and the level builds the ground below it. One
ground line, and it is the line the artist stood four dancers on.

    plaza_backdrop.png   the painting, cut at the walk line, widened with its own sky

The walk line is measured off `mg_people`'s own alpha: the lowest row it covers. That is the
ground in this picture by definition.

    python3 tools/build_plaza.py [--check]
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "game" / "assets" / "Level2"

# Back to front. The order they compose in.
LAYERS = ["bg_sky", "bg_clouds", "mg_church", "ground", "mg_people", "fg_huts"]

## How many plate-widths wide the output is. The painting sits in the middle and its own sky
## runs out either side, so the camera can lead the player to the walls without running off
## the picture into nothing.
WIDE = 3


def walk_row() -> int:
    """Where the painted dancers' feet are -- the ground line, by the artist's own hand."""
    people = np.array(Image.open(SRC / "mg_people.png").convert("RGBA"))[..., 3] > 24
    return int(np.where(people.any(axis=1))[0].max())


def _sky_column(size: tuple[int, int], height: int) -> Image.Image:
    """The painting's own sky, one column stretched across the widened canvas.

    ⚠ TAKEN FROM `bg_sky` AND NOT FROM THE COMPOSITE. The flattened painting has the kiosko
    and the palms drawn over its sky, so a column sampled from it carries whatever happens to
    be at that x -- an early attempt pulled a roof beam and a hedge out of the plaza and
    stretched them as horizontal bars across the whole width of the level.
    """
    plate = np.array(Image.open(SRC / "bg_sky.png").convert("RGBA"))
    column = plate[:height, 300:301, :]
    return Image.fromarray(np.repeat(column, size[0] * WIDE, axis=1), "RGBA")


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
            # Registration is the entire premise: a plate on a different canvas cannot be
            # composited at the same transform.
            print("  PROBLEM  %s is %s, not %s" % (path.name, layer.size, size))
            return 1
        plaza.alpha_composite(layer)

    line = walk_row()
    # ⚠ EVERYTHING BELOW THE PAINTED DANCERS' FEET GOES. See the module docstring: the near
    # verge and its retaining wall are why the plaza read as two platforms, and they are in
    # the picture, so the picture is where they have to be removed.
    cropped = plaza.crop((0, 0, size[0], line))

    wide = Image.new("RGBA", (size[0] * WIDE, line), (0, 0, 0, 0))
    wide.alpha_composite(_sky_column(size, line))
    wide.alpha_composite(cropped, (size[0], 0))

    if not check:
        wide.save(SRC / "plaza_backdrop.png")
        # The older two-plate output is gone: nothing draws in front of the player any more,
        # because the thing that used to is the half of the painting that was cut off.
        for stale in ["plaza.png", "plaza_front.png"]:
            path = SRC / stale
            if path.exists():
                path.unlink()
            imported = SRC / (stale + ".import")
            if imported.exists():
                imported.unlink()

    print("%s plaza_backdrop.png at %dx%d" % (
        "checked" if check else "wrote", wide.width, wide.height))
    print("   walk line (painted dancers' feet)  plate row %d" % line)
    print("   painting sits at canvas x %d..%d of %d" % (size[0], size[0] * 2, wide.width))
    return 0


if __name__ == "__main__":
    sys.exit(build("--check" in sys.argv))
