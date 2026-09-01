#!/usr/bin/env python3
"""Take the four painted dancers out of the plaza and hand them back as sprites.

WHY
---
Piyesta's first beat lets the player scare the dancers off the plaza, permanently -- the
design's own words are *"the plaza is lolo's memory, and the player has just emptied it"*.
That has been mechanically complete and visually invisible for as long as the plaza has been
the delivered painting, because the dancers are painted INTO `mg_people.png`. `DancerGroup2D`
drew nothing rather than put eight dancers where the picture has four.

The authored 8-bit dancers exist (`build_plaza_art.py`) and are nowhere near the painted ones.
Swapping four beautiful painted figures for four blocky ones to gain an animation is a bad
trade in a plaza the whole level is judged on. So the dancers are CUT OUT of the painting and
handed back as sprites: the plaza looks exactly as it did, and now they can leave.

HOW, AND WHY IT IS NOT SYMMETRICAL
----------------------------------
Two of the four are cleanly separable and two are not. Label the plate's alpha and the middle
pair fall out as their own connected components -- they stand against sky and town, touching
nothing. The outer pair stand in front of the palm arch's legs and are fused into the same
component as the whole arch, so there is no component to lift.

So the outer two are not cut at all. Their boxes are CLEARED -- dancer, pole and the little
bench behind her, all of it -- and the pole is rebuilt by tiling the clean stretch just above
each hat, cross-faded at the joins. A decorated pole is a repeating thing (spiral ribbon,
garlands of kiping) so a copy of it reads as more pole; an autocorrelation over the clean run
finds no true period, which is the giveaway that it is hand-painted, so the cross-fade is
doing the work rather than a lucky alignment.

The two clean cut-outs then stand in for all four. They are two poses, mirrored for the outer
pair, which is what the painting does anyway -- the four are individually drawn variations,
not copies (template-matching one against another gives a mean channel difference of 33, where
a copy-paste would give nearly nothing).

    tools/build_dancers.py [--check]

Writes `mg_people_nodancers.png` beside the plates -- `build_plaza.py` composites that instead
-- and two sprites into the plaza sheet, where `PiyestaTiles` picks them up by name.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "game" / "assets" / "Level2"
SHEET = SRC / "plaza"

## The two that stand against nothing, and so come away whole. Found by labelling, not by
## hard-coded boxes -- but asserted against these, because a plate redelivered with the
## dancers moved should fail loudly rather than cut a hole in the church.
CLEAN_NEAR = [(638, 857), (639, 1022)]

## The two that are fused into the palm arch. Box to clear, and the stretch of clean pole to
## rebuild it from: `band` is rows, `cols` is the pole's own width at that height.
## ⚠ `cols` IS THE POLE AND NOTHING ELSE, and `band` starts one period above the box.
##
## The first version took a ninety-row band across cols 688..806. Rows 580 and above carry
## the garland that hangs out to col 832, so every tile repeated that overhang and the plaza
## grew a stack of horizontal ledges beside each pole. Measured per row, the pole is a clean
## eighty-odd pixels from row 588 down; these columns are that, plus two either side.
##
## And the band STARTS one garland period above the box (49 rows on the left, 45 on the
## right, from an autocorrelation over the clean run) so the first tile continues the real
## pole's pattern instead of restarting it. The correlation is shallow -- it is hand-painted,
## not tiled -- so this aligns the join rather than making it vanish; the cross-fade does the
## rest.
FUSED = [
    {"box": (634, 818, 686, 852), "band": (585, 645), "cols": (690, 798)},
    {"box": (634, 818, 1164, 1332), "band": (589, 645), "cols": (1168, 1266)},
]
## How many rows each tile of rebuilt pole fades into the one above it.
BLEND = 10


def _components(alpha: np.ndarray) -> tuple[np.ndarray, list]:
    labels, _ = ndimage.label(alpha > 24)
    return labels, ndimage.find_objects(labels)


def _clean_cuts(plate: np.ndarray, labels: np.ndarray, boxes: list) -> list:
    """The two whole dancers, as (id, slice) -- matched to where they are expected to be."""
    found = []
    for row, col in CLEAN_NEAR:
        hit = None
        for index, box in enumerate(boxes, start=1):
            if box is None:
                continue
            if abs(box[0].start - row) <= 4 and abs(box[1].start - col) <= 4:
                hit = (index, box)
                break
        if hit is None:
            raise SystemExit(
                "  PROBLEM  no isolated dancer near row %d col %d -- has mg_people.png been "
                "redelivered? Re-measure before touching anything else." % (row, col))
        found.append(hit)
    return found


def _rebuild_pole(work: np.ndarray, plate: np.ndarray, leg: dict) -> None:
    """Clear a fused dancer's box and grow the pole back down through it."""
    r0, r1, c0, c1 = leg["box"]
    work[r0:r1, c0:c1] = 0

    b0, b1 = leg["band"]
    pc0, pc1 = leg["cols"]
    band = plate[b0:b1, pc0:pc1].astype(np.float32)
    height = b1 - b0

    row = r0
    first = True
    while row < r1:
        take = min(height, r1 - row)
        piece = band[:take]
        target = work[row:row + take, pc0:pc1].astype(np.float32)
        weight = np.ones((take, 1, 1), dtype=np.float32)
        if not first:
            # Fade the head of each tile into the tail of the one above. The pole has no true
            # period -- it is hand-painted -- so without this every join is a hard line across
            # the garland.
            fade = min(BLEND, take)
            weight[:fade, 0, 0] = np.linspace(0.0, 1.0, fade, dtype=np.float32)
        # ⚠ NEVER BLEND TOWARD A TRANSPARENT PIXEL. Cleared pixels are (0,0,0,0), so a
        # straight cross-fade pulls the join's colour toward black and each seam came out as
        # a grey smudge across the garland. Where there is nothing to fade from, take the
        # piece whole.
        weight = np.maximum(weight, 1.0 - target[..., 3:4] / 255.0)
        blended = target * (1.0 - weight) + piece * weight
        # ⚠ THRESHOLD, DO NOT USE `> 0`. The painting has soft atmospheric edges -- pixels at
        # alpha 2 and 3 all round the arch -- and writing those wholesale laid a translucent
        # veil across the whole cleared box, which read as a pale rectangle hanging in the
        # plaza. Same threshold the labelling uses, so the pole's silhouette here is the
        # silhouette everything else in this file was measured against.
        solid = piece[..., 3] > 24
        out = work[row:row + take, pc0:pc1]
        out[solid] = np.clip(blended, 0, 255).astype(np.uint8)[solid]
        row += take
        first = False


def build(check: bool) -> int:
    path = SRC / "mg_people.png"
    if not path.exists():
        print("  PROBLEM  missing %s" % path.name)
        return 1
    plate = np.array(Image.open(path).convert("RGBA"))
    labels, boxes = _components(plate[..., 3])

    work = plate.copy()
    sprites = []
    for order, (index, box) in enumerate(_clean_cuts(plate, labels, boxes)):
        mask = labels[box] == index
        cut = plate[box].copy()
        cut[~mask] = 0
        sprites.append(("painted_dancer_%s" % "ab"[order], cut, box))
        work[box][mask] = 0

    for leg in FUSED:
        _rebuild_pole(work, plate, leg)

    manifest = json.loads((SHEET / "plaza.json").read_text())
    for name, cut, _box in sprites:
        manifest["tiles"][name] = {
            "file": "%s.png" % name, "size": [cut.shape[1], cut.shape[0]]}
        if not check:
            Image.fromarray(cut, "RGBA").save(SHEET / ("%s.png" % name))
    if not check:
        Image.fromarray(work, "RGBA").save(SRC / "mg_people_nodancers.png")
        (SHEET / "plaza.json").write_text(json.dumps(manifest, indent=2) + "\n")

    print("%s mg_people_nodancers.png and %d sprites"
          % ("checked" if check else "wrote", len(sprites)))
    for name, cut, box in sprites:
        print("   %-18s %3dx%3d  cut from rows %d..%d cols %d..%d"
              % (name, cut.shape[1], cut.shape[0],
                 box[0].start, box[0].stop, box[1].start, box[1].stop))
    print("   poles rebuilt at cols %s" % ", ".join(
        "%d..%d" % (leg["cols"][0], leg["cols"][1]) for leg in FUSED))
    # What the level needs to stand its four sprites exactly where the painting had them.
    # World x IS plate x, and the walk line is the plate row the feet sit on.
    print("   painted at plate x 697, 857, 1022, 1174 (widths ~150), feet on row 817")
    return 0


if __name__ == "__main__":
    sys.exit(build("--check" in sys.argv))
