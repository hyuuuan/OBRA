#!/usr/bin/env python3
"""Author what Dagat needs and the delivery does not contain: the ink jar on the seabed, the
rock the land stands on under the water, and the seabed itself.

WHY THIS EXISTS
---------------
The refills are the only thing keeping a long crossing payable, and they had no art -- they
were purple diamonds. The delivered underwater CompletedLook DOES have them in it: pale jars
with a dark cap and a blue drop on the front, standing on the terraces. They are painted into
that plate rather than shipped as a sprite, so this draws one, in the same idiom the rest of
the project's authored art uses (tools/pixelart.py: a logical pixel grid, short ramps, ordered
dither, light from the upper left).

THREE FRAMES, AND THE ONLY THING THAT MOVES IS THE GLOW. A pickup that animates its shape
reads as alive and asks to be looked at; this one has to read as a thing left on the seabed
that happens to still have something in it.

USAGE
    python3 tools/build_dagat_props.py            # write game/assets/Level3/props/
    python3 tools/build_dagat_props.py --check    # verify the committed files are current
"""

from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import numpy as np
from PIL import Image

import pixelart
from pixelart import Canvas, ramp

ROOT = Path(__file__).resolve().parent.parent
# ⚠ ITS OWN DIRECTORY, AND THE REASON IS OWNERSHIP. build_dagat.py rmtree's everything it
# generates before it rebuilds -- correct for a pipeline, and fatal if a second tool writes
# into the same folders. It wrote the jar into props/ once and the next --check deleted it.
# A directory nothing else touches makes that impossible rather than merely unlikely.
OUT = ROOT / "game" / "assets" / "Level3" / "authored"

# Read off the delivered plate so the jar belongs to the picture it stands in.
GLASS = ramp(["#6f7f86", "#93a4a8", "#b9c6c4", "#dbe3dc", "#f1f4ea"])
CAP = ramp(["#2a1d16", "#3d2b20", "#55392a", "#6d4a36", "#8a6246"])
DROP = ramp(["#0e3f66", "#1667a4", "#2b95d6", "#71c8ef"])
GLOW = ramp(["#1667a4", "#2b95d6", "#71c8ef", "#bdeaff"])
# What is in it, and the label round it.
INK = ramp(["#07173a", "#0e2758", "#163c82", "#2256ad", "#3a7bd2", "#6aa9ea", "#a8d6f7"])
PAPER = ramp(["#8f836a", "#bdb091", "#ddd2b5", "#f3ebd3"])
GLASS_EDGE = np.array([22, 36, 48, 255], dtype=np.uint8)

W, H = 20, 30
FRAMES = 3

# --- The ground the apo walks on, and the land under the water -------------------------------
#
# Kent: "Fix how the platforms at the islands are made since its so low quality and it looks
# like im not walking to a platform but to an image, refer to how platforms in level 2 are made
# since its so nice there walking it feels realistic."
#
# He was right on both counts, and they were one fault. Each beach was the delivered sand PLATE
# -- a 1672-wide painting at six to eight screen pixels to its pixel, with the beach drawn as a
# deep slab running toward the camera and driftwood painted onto it IN FRONT of the line the apo
# walks along -- over a heap of boulders drawn at three. Next to a character drawn at one, it was
# a picture the apo stood on the back edge of.
#
# Piyesta's plaza is built the other way (PiyestaPlaza2D): a thin strip of paving the feet go on,
# a coursed retaining wall of rounded stones with grass along its top, and fill below, all at one
# pixel to the pixel. So each beach is that now, in Dagat's colours:
#
#   * THE SAND, 34 rows, the height of Piyesta's paving: a lit lip the feet stand on, dithered
#     sand in this plate's own five tones, a few ripples and shells, damp along its foot.
#   * THE FACE, Piyesta's own retaining wall (assets/Level2/plaza/retaining.png) re-coloured:
#     its stones from brown to wet slate in the hues of this level's rock, its grass and vines to
#     sea-moss. Same stones, same light, the same pixel -- which is the point of using it.
#   * THE COURSES below it, down to the seabed: the same stones without the grass or the vines,
#     cut between the texture's own mortar lines (rows 10 and 96) so course meets course at a
#     joint and never through a stone, each set along by its own offset, and the whole of it
#     going down into the water's colour as the sea gets deep.
#   * THE SEAWARD EDGE IS WHOLE STONES, AND IT IS WHERE THE COLLISION IS. A straight cut through
#     a coursed wall is a sliced cake, so near the edge every stone is kept or dropped whole, and
#     the wall is solid out to its outermost stone in every row. The sand the apo walks on ends ON
#     the collision's edge, rounded and wet. See _edge_of_the_wall for the rules and LANDS for how
#     each beach's stones were chosen to meet it.
#
# ⚠ THE SAND PLATE IS NO LONGER DRAWN. It painted nothing above the walking line (measured: under
# 2% of any row above plate row 786), so taking it out takes only the slab this replaces. See the
# shore band's rows in dagat_backdrop_2d.gd.
#
# The land still goes down to the seabed, because the collision does: a diver who swims under the
# beach meets rock, not an air pocket.
RETAINING = ROOT / "game" / "assets" / "Level2" / "plaza" / "retaining.png"
## The beach's sand, as the plate paints it. The strip the apo walks on and the heap the next
## painting stands in are both this sand.
SAND = ramp(["#6f5141", "#be9564", "#e6b775", "#f0c888", "#f7dba6"])
## The rock's hue and the moss's, read off the terraces' rock (#1e3c56 .. #5e858d) and the green
## on their ledges.
ROCK_HUE, MOSS_HUE = 202.0, 158.0
## The colour the rock goes to with depth: the deep band's own fill below its plate.
DEEP_RGB = np.array([1.0, 27.0, 70.0])
## World rows. The land's picture starts just above the surface and runs past the lowest the
## camera ever looks. The shore band pins its pieces by this top: top_row = LAND_TOP - (-230).
LAND_TOP, LAND_BOTTOM = 556, 1867
SURFACE_Y = 560
SAND_ROWS, FACE_ROWS = 34, 96
## Where in the retaining wall a course is cut: under the grass, at its first mortar line, down to
## the full mortar band along its foot.
COURSE_ROWS = (10, 96)
## name: (world left, world right, the collision edge, whether the sea is to its right, seed,
## phase). The left and right are where the backdrop sets each piece down: the home land from the
## home ground's west end, the island's to the island ground's east end.
##
## ⚠ EACH PICTURE RUNS 120 PAST ITS EDGE, INTO THE SEA. It ran 30, and a stone standing out past
## the edge was sliced flat along the picture's border.
##
## ⚠ THE PHASE IS WHICH STONES ARRIVE AT THE EDGE, AND IT WAS SEARCHED FOR, NOT CHOSEN. Whole stones
## forty to seventy pixels wide cannot be made to end on a given column; only a different set of
## stones can. The wall is laid along by `phase` columns, and `--search-edges` tries every one of
## the wall's 864 and ranks them: the top course meets the sand's end (no stone short of it by more
## than 4 or past it by more than TOP_REACH), then fewest rows short of the collision by more than
## 16, then least rock standing out. The first edges, at phase 0, fell 60 pixels short of the
## collision: fifty pixels of sand the apo walked on over open water, and an invisible wall in it
## for a diver. run_level3_audit holds each picture to its collision.
LANDS = {
    "land_home.png": (100, 1120, 1000, True, 6100, 420),
    "land_island.png": (4380, 5380, 4500, False, 6200, 102),
}


def BAYER_AT(x: int, y: int) -> float:
    return float(pixelart.BAYER[y % 4, x % 4])


def _hls(rgb: np.ndarray) -> tuple:
    """RGB in 0..1 to hue (0..1), lightness, saturation, for a whole image at once."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    top, low = rgb.max(axis=-1), rgb.min(axis=-1)
    light = (top + low) / 2.0
    spread = top - low
    some = spread > 0
    safe = np.maximum(spread, 1e-6)
    sat = np.where(~some, 0.0, np.where(light < 0.5, spread / np.maximum(top + low, 1e-6),
                                        spread / np.maximum(2.0 - top - low, 1e-6)))
    rc, gc, bc = (top - r) / safe, (top - g) / safe, (top - b) / safe
    hue = np.where(r == top, bc - gc, np.where(g == top, 2.0 + rc - bc, 4.0 + gc - rc))
    return np.where(some, (hue / 6.0) % 1.0, 0.0), light, sat


def _rgb(hue: np.ndarray, light: np.ndarray, sat: np.ndarray) -> np.ndarray:
    def channel(m1, m2, h):
        h = h % 1.0
        return np.where(h < 1 / 6, m1 + (m2 - m1) * h * 6, np.where(
            h < 0.5, m2, np.where(h < 2 / 3, m1 + (m2 - m1) * (2 / 3 - h) * 6, m1)))
    m2 = np.where(light <= 0.5, light * (1.0 + sat), light + sat - light * sat)
    m1 = 2.0 * light - m2
    return np.stack([channel(m1, m2, hue + 1 / 3), channel(m1, m2, hue),
                     channel(m1, m2, hue - 1 / 3)], axis=-1)


def _wall() -> tuple:
    """Piyesta's retaining wall in this sea's colours, and where its vines are."""
    source = np.array(Image.open(RETAINING).convert("RGBA")).astype(float) / 255.0
    hue, light, sat = _hls(source[..., :3])
    degrees = hue * 360.0
    green = (degrees >= 65.0) & (degrees <= 170.0) & (sat > 0.18)
    new_hue = np.where(green, MOSS_HUE, ROCK_HUE) / 360.0
    new_light = np.where(green, light * 0.9, np.minimum(1.0, light * 1.12))
    new_sat = np.where(green, np.minimum(1.0, sat * 0.75), np.minimum(1.0, sat * 0.765 + 0.06))
    out = source.copy()
    out[..., :3] = _rgb(new_hue, new_light, new_sat)
    # Every vine pixel is still some green in the source, which it is not once darkened and
    # re-coloured -- so the vines are found here, and grown a pixel to take their outlines.
    vine = (degrees >= 55.0) & (degrees <= 185.0) & (sat > 0.08) & (light > 0.08)
    grown = vine.copy()
    grown[1:] |= vine[:-1]
    grown[:-1] |= vine[1:]
    grown[:, 1:] |= vine[:, :-1]
    grown[:, :-1] |= vine[:, 1:]
    return (out * 255.0).astype(np.uint8), grown


def _course(wall: np.ndarray, vines: np.ndarray) -> np.ndarray:
    """One course of the stones: under the grass, down to the mortar band, with every vine
    pixel filled from the same column a course-and-a-half away."""
    top, bottom = COURSE_ROWS
    course = wall[top:bottom].copy()
    hanging = vines[top:bottom].copy()
    rows = course.shape[0]
    for row in range(rows):
        for step in (43, 21, 64):
            other = (row + step) % rows
            fill = hanging[row] & ~hanging[other]
            course[row, fill] = course[other, fill]
            hanging[row] &= ~fill
    return course


def _periodic_noise(width: int, height: int, cell: int, seed: int) -> np.ndarray:
    """Value noise that wraps across its width, so the strip tiles along the beach."""
    rng = np.random.default_rng(seed)
    grid = rng.random((height // cell + 2, width // cell + 1))
    ys, xs = np.arange(height) / cell, np.arange(width) / cell
    y0, x0 = ys.astype(int), xs.astype(int)
    fy, fx = (ys - y0)[:, None], (xs - x0)[None, :]
    x1 = (x0 + 1) % grid.shape[1]
    grid[:, -1] = grid[:, 0]
    return (grid[y0][:, x0] * (1 - fx) * (1 - fy) + grid[y0][:, x1] * fx * (1 - fy)
            + grid[y0 + 1][:, x0] * (1 - fx) * fy + grid[y0 + 1][:, x1] * fx * fy)


SAND_WIDTH = 288


def _sand_strip() -> np.ndarray:
    """The 34 rows the feet are on: a lit lip, the plate's five sands dithered, a few ripples
    and shells, damp along the foot where it meets the stones."""
    rng = np.random.default_rng(3101)
    broad = _periodic_noise(SAND_WIDTH, SAND_ROWS, 6, 3)
    fine = _periodic_noise(SAND_WIDTH, SAND_ROWS, 2, 4)
    strip = np.zeros((SAND_ROWS, SAND_WIDTH, 4), dtype=np.uint8)
    strip[..., 3] = 255
    for y in range(SAND_ROWS):
        depth = y / float(SAND_ROWS - 1)
        for x in range(SAND_WIDTH):
            value = 0.62 + 0.22 * (broad[y, x] - 0.5) + 0.12 * (fine[y, x] - 0.5) \
                - 0.55 * max(0.0, depth - 0.62)
            if y == 0:
                value = 0.98
            elif y == 1:
                value = 0.86
            scaled = value * 4.0
            low = int(np.clip(np.floor(scaled), 0, 3))
            index = int(np.clip(low + (1 if scaled - low > BAYER_AT(x, y) else 0), 0, 4))
            strip[y, x, :3] = SAND[index][:3]
    for _ripple in range(14):
        x0, y0, length = int(rng.integers(0, SAND_WIDTH)), int(rng.integers(5, 18)), \
            int(rng.integers(5, 12))
        for dx in range(length):
            x = (x0 + dx) % SAND_WIDTH
            strip[y0, x, :3] = SAND[1][:3]
            strip[y0 - 1, x, :3] = SAND[4][:3]
    shells = [np.array([233, 214, 208]), np.array([199, 178, 173]), np.array([122, 106, 98])]
    for index in range(9):
        x, y = int(rng.integers(2, SAND_WIDTH - 3)), int(rng.integers(6, 24))
        strip[y, x, :3] = shells[index % 3]
        strip[y, x + 1, :3] = (shells[index % 3] * 0.85).astype(np.uint8)
    strip[SAND_ROWS - 3:, :, :3] = (SAND[0][:3] * 0.8).astype(np.uint8)
    return strip


def _flood(mask: np.ndarray, seeds: list) -> np.ndarray:
    from collections import deque
    height, width = mask.shape
    seen = np.zeros_like(mask)
    queue = deque()
    for y, x in seeds:
        if mask[y, x] and not seen[y, x]:
            seen[y, x] = True
            queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < height and 0 <= nx < width and mask[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                queue.append((ny, nx))
    return seen


## Face rows whose stones may not stand out past the sand's end: the top course, just under the
## feet. A stone there that passes the sand is a ledge beside the beach that nothing stands on.
TOP_COURSE, TOP_REACH = 30, 6
## How far any stone below that may stand out past the edge, under the water. The diver is drawn
## in front of the land, so rock past the collision reads as rock behind them; a wall that stops
## short of it is an invisible wall in open water, which is the worse of the two -- so a stone is
## kept if any of it is on the land's side, and only a boulder jutting out like a ledge is not.
MAX_REACH = 48
## How far the sand's rounded end bulges past the collision at its middle rows.
SAND_BULGE = 4
## The columns either side of the edge the stones are chosen in.
EDGE_BAND = 110


def _stones(region: np.ndarray) -> tuple:
    """The wall's stones near the edge, as a label per pixel and (top, left, right, size) for
    each: lit rock, not moss, bounded by the dark mortar between."""
    from collections import deque
    rgb = region[..., :3].astype(float)
    hue, light, sat = _hls(rgb / 255.0)
    green = (hue * 360.0 >= 65.0) & (hue * 360.0 <= 170.0) & (sat > 0.18)
    solid = (0.3 * rgb[..., 0] + 0.59 * rgb[..., 1] + 0.11 * rgb[..., 2] >= 34.0) & ~green
    height, width = solid.shape
    labels = np.full((height, width), -1, dtype=int)
    found = []
    for y in range(height):
        for x in range(width):
            if not solid[y, x] or labels[y, x] >= 0:
                continue
            label = len(found)
            labels[y, x] = label
            queue = deque([(y, x)])
            top, left, right, count = y, x, x, 0
            while queue:
                a, b = queue.popleft()
                count += 1
                top, left, right = min(top, a), min(left, b), max(right, b)
                for da, db in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    na, nb = a + da, b + db
                    if 0 <= na < height and 0 <= nb < width and solid[na, nb] \
                            and labels[na, nb] < 0:
                        labels[na, nb] = label
                        queue.append((na, nb))
            found.append((top, left, right, count))
    return labels, found


def _edge_of_the_wall(region: np.ndarray, x_off: int, cut: int, facing_right: bool) -> np.ndarray:
    """Which pixels of the face near the edge stay wall. Whole stones: one is kept if any of it
    is on the land's side of the edge and it stands out no further than MAX_REACH (TOP_REACH in the
    top course), with the mortar round it as its outline. Then the wall is solid out to its
    outermost stone in every row -- the sea showed through between the stones otherwise, a pile of
    rocks rather than a wall -- with two corrections, both found on screen:

    * the mortar is filled only as far as the rows around it reach (a running median), so the tip
      of one stone standing out cannot paint a hairline of mortar across the water to it; and
    * a thin mortar row between two courses is filled as far as the courses on BOTH sides of it
      reach, or no stone's outline covers it and the sea shows through it as a hairline instead.

    The grass lip along the top has no stones of its own and runs as far as the course under it."""
    labels, found = _stones(region)
    kept = []
    for top, left, right, count in found:
        left, right = left + x_off, right + x_off
        if facing_right:
            keep = left < cut and right < cut + MAX_REACH and count >= 40
            if top < TOP_COURSE:
                keep = keep and right < cut + TOP_REACH
        else:
            keep = right >= cut and left >= cut - MAX_REACH and count >= 40
            if top < TOP_COURSE:
                keep = keep and left >= cut - TOP_REACH
        kept.append(keep)
    keep = np.zeros(labels.shape, dtype=bool)
    stone = labels >= 0
    keep[stone] = np.array(kept, dtype=bool)[labels[stone]]
    for _round in range(2):
        grown = keep.copy()
        grown[1:] |= keep[:-1]
        grown[:-1] |= keep[1:]
        grown[:, 1:] |= keep[:, :-1]
        grown[:, :-1] |= keep[:, 1:]
        keep = grown
    height, width = keep.shape
    # The outermost wall pixel of each row: the largest column for a wall facing the sea on its
    # right, the smallest for one facing it on its left.
    pick, choose = (np.max, np.minimum) if facing_right else (np.min, np.maximum)
    extent = np.array([pick(np.where(keep[r])[0]) if keep[r].any() else (-1 if facing_right else width)
                       for r in range(height)])
    lip = COURSE_ROWS[0]
    extent[:lip] = pick(extent[lip:TOP_COURSE])
    smooth = np.array([np.median(extent[max(0, r - 3):r + 4]) for r in range(height)])
    up = np.array([pick(extent[max(0, r - 3):r]) if r > 0 else extent[r] for r in range(height)])
    down = np.array([pick(extent[r + 1:r + 4]) if r < height - 1 else extent[r]
                     for r in range(height)])
    fill = choose(extent, smooth)
    bridge = choose(up, down)
    columns = np.arange(width)[None, :]
    if facing_right:
        keep |= columns <= np.maximum(fill, bridge)[:, None]
    else:
        keep |= columns >= np.minimum(fill, bridge)[:, None]
    return keep


def draw_land(name: str, phase: int | None = None) -> Image.Image:
    import math
    left, right, edge, facing_right, seed, chosen = LANDS[name]
    phase = chosen if phase is None else phase
    width, height = right - left, LAND_BOTTOM - LAND_TOP
    wall, vines = _wall()
    course = _course(wall, vines)
    sand = _sand_strip()
    out = np.zeros((height, width, 4), dtype=np.uint8)
    # Laid by WORLD x, so the strip and the stones line up with nothing that moves with them.
    columns = np.arange(left, right)
    surface = SURFACE_Y - LAND_TOP
    out[surface:surface + SAND_ROWS] = sand[:, columns % sand.shape[1]]
    face_top = surface + SAND_ROWS
    out[face_top:face_top + FACE_ROWS] = wall[:, (columns + phase) % wall.shape[1]]
    y, number = face_top + FACE_ROWS, 1
    while y < height:
        rows = min(course.shape[0], height - y)
        along = (number * 347 + seed) % course.shape[1]
        out[y:y + rows] = course[:rows, (columns + phase + along) % course.shape[1]]
        y, number = y + rows, number + 1

    cut = edge - left
    near = slice(max(0, cut - EDGE_BAND), min(width, cut + EDGE_BAND))
    region = out[face_top:, near].copy()
    keep = _edge_of_the_wall(region, near.start, cut, facing_right)
    region[~keep] = 0
    out[face_top:, near] = region
    if facing_right:
        out[face_top:, near.stop:] = 0
    else:
        out[face_top:, :near.start] = 0

    # The sand ends ON the collision's edge -- at the walking row, exactly where the apo stops --
    # rounded at the top, bulging a few pixels at its middle, wet toward the end.
    wet = np.array([20.0, 38.0, 62.0])
    for row in range(SAND_ROWS):
        y = surface + row
        bulge = int(round(SAND_BULGE * math.sin(math.pi * min(1.0, (row + 1) / 30.0)) ** 0.8))
        # The last column of sand facing right, the first facing left.
        stop = cut - 2 + bulge if facing_right else cut + 1 - bulge
        if facing_right:
            out[y, stop + 1:] = 0
        else:
            out[y, :stop] = 0
        for k in range(6):
            x = stop - k if facing_right else stop + k
            share = 0.18 - 0.03 * k
            out[y, x, :3] = (out[y, x, :3] * (1.0 - share) + wet * share).astype(np.uint8)

    # Down into the water's colour as the sea gets deep.
    start = face_top + 60
    for y in range(start, height):
        share = min(1.0, (y - start) / 520.0) ** 0.9 * 0.82
        out[y, :, :3] = (out[y, :, :3] * (1.0 - share) + DEEP_RGB * share).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def _edge_fit(name: str, image: Image.Image) -> tuple:
    """How far the land reaches past its collision edge, row by row, for the sand and for the
    face below it: positive is out over the sea, negative short of the edge."""
    left, right, edge, facing_right, _seed, _phase = LANDS[name]
    alpha = np.array(image)[..., 3]
    width = alpha.shape[1]

    def reach(row: int) -> int:
        solid = np.where(alpha[row] > 0)[0]
        if facing_right:
            return int(left + solid.max() + 1 - edge)
        return int(edge - (right - width + solid.min()))

    surface = SURFACE_Y - LAND_TOP
    face_top = surface + SAND_ROWS
    return ([reach(surface + row) for row in range(SAND_ROWS)],
            np.array([reach(row) for row in range(face_top, alpha.shape[0])]))


def search_edges() -> None:
    """Rank every phase of the wall for each beach. See LANDS."""
    width = _wall()[0].shape[1]
    for name in LANDS:
        ranked = []
        for phase in range(0, width, 2):
            sand, face = _edge_fit(name, draw_land(name, phase))
            top = face[:TOP_COURSE]
            ranked.append((int((top < -4).sum() + (top > TOP_REACH).sum()), int((face < -16).sum()),
                           float(np.clip(face, 0, None).mean()), phase, int(face.min()),
                           int(face.max())))
        ranked.sort()
        print(name, "now", LANDS[name][5])
        for top_off, short, out, phase, low, high in ranked[:6]:
            print(f"  phase {phase:3d}: top course off {top_off}, rows short >16 {short}, "
                  f"mean out {out:.1f}, face {low}..{high}")


LAND = {name: (lambda name=name: draw_land(name)) for name in LANDS}


# --- The island's palms, without the beach they were painted on ----------------------------
#
# The delivered `palms_right` plate is a clump of palms on boulders at the end of a painted sand
# spit -- driftwood, a coral, the spit's own wavy edge -- and all of that lies below the walking
# line. Over the island's land it was a second beach painted across the first, at eight pixels to
# the pixel, which kept exactly the "walking to an image" look the land above replaced. So the
# island gets the clump alone: cut at the column the clump starts at, the sand keyed out of
# everything below the boulders' tops, and anything left that is no longer joined to the clump
# (a pebble that lay on the sand) dropped with it. The palms then end on their boulders at the
# landward end of the wall, the way `palms_left` already ends the home beach.
#
# ⚠ THE FULL HEIGHT OF THE PLATE, SO THE SWAY DOES NOT CHANGE. wind_sway.gdshader holds the foot
# by UV.y (`root`), so the texture keeps the plate's 941 rows and only loses columns.
PALMS_RIGHT = ROOT / "game" / "assets" / "Level3" / "shore" / "palms_right.png"
## The plate's columns the clump stands in: from its leftmost fern to the plate's own cut side.
PALM_COLUMNS = (1185, 1672)
## Plate rows from which a sand-coloured pixel is sand. Above this is trunk, whose highlights are
## the same orange-tan as the sand.
PALM_SAND_FROM = 760


def draw_palms_island() -> Image.Image:
    plate = np.array(Image.open(PALMS_RIGHT).convert("RGBA"))
    out = plate[:, PALM_COLUMNS[0]:PALM_COLUMNS[1]].copy()
    hue, light, sat = _hls(out[..., :3].astype(float) / 255.0)
    degrees = hue * 360.0
    sandy = (degrees >= 18.0) & (degrees <= 52.0) & (light > 0.42) & (sat > 0.30)
    sandy[:PALM_SAND_FROM] = False
    out[sandy] = 0
    solid = out[..., 3] > 0
    joined = _flood(solid, [(y, x) for y in range(PALM_SAND_FROM) for x in range(out.shape[1])])
    out[~joined] = 0
    return Image.fromarray(out, "RGBA")


PALMS = {"palms_island.png": draw_palms_island}


# --- The seabed: what the diver swims over -------------------------------------------------
#
# The floor was the delivered TERRACES plate at world rate: a tableau of stepped ledges with
# lit, mossed tops, and a strip of seabed along its foot. The collision under the water is a
# flat bed at 1709 and nothing else, so every one of those ledges was a platform a diver could
# see and swim straight through -- the "platforms" that made the sea below look messy -- and
# their foot was a band of black silhouettes cut straight along the plate's last row.
#
# So the two jobs are split. The floor the refills, the coral and the clams stand on is drawn
# here, as a strip that tiles on its own and is exactly as flat as the collision is; the
# terraces go back into the water behind it (terraces_far, below), hazed and slower, where a
# ledge is a place in the distance rather than a step.
#
# ⚠ THE WALKING LINE IS A ROW OF THIS STRIP, AND IT IS THE SEABED. `FLOOR_WALK` rows down from
# its top edge is where everything on the bed stands: the backdrop pins the strip so that row
# lands on level_3.gd's BED_Y, and run_level3_audit reads both numbers back off the backdrop.
# The strip's top edge sits above that row by a few pixels of sand seen from above -- the top
# of the floor, not a line -- so a jar stands IN the sand rather than on a rule.
SEABED = ramp(["#020d24", "#051836", "#0a2646", "#123756", "#1c4a63",
               "#2a606f", "#3d7a7c", "#56958c", "#76b09c", "#9ccab0"])
PEBBLE = ramp(["#061428", "#102840", "#1f3f58", "#345a6d", "#527b88", "#7ca0a6"])
SHELL_BITS = ramp(["#6d5f78", "#a998ad", "#ddd1da"])
WEED = ramp(["#0f352f", "#1a5440", "#2a744c", "#48945a"])
## Wide enough that the repeat is five times across the whole crossing, not twenty.
FLOOR_W, FLOOR_H = 320, 66
FLOOR_WALK = 6


def _periodic(xs: np.ndarray, width: int, terms) -> np.ndarray:
    """A sum of sines with a whole number of cycles across `width`, so it wraps."""
    import math
    out = np.zeros_like(xs, dtype=float)
    for cycles, phase, amp in terms:
        out += amp * np.sin(2.0 * math.pi * cycles * xs / width + phase)
    return out


def _noise(width: int, height: int, cell: int, seed: int) -> np.ndarray:
    """Smooth value noise, 0..1, that wraps across the width."""
    rng = np.random.default_rng(seed)
    gw, gh = width // cell, height // cell + 2
    grid = rng.uniform(0.0, 1.0, size=(gh, gw))
    ys, xs = np.mgrid[0:height, 0:width].astype(float)
    gx, gy = xs / cell, ys / cell
    x0, y0 = np.floor(gx).astype(int), np.floor(gy).astype(int)
    fx, fy = gx - x0, gy - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b = grid[y0, x0 % gw], grid[y0, (x0 + 1) % gw]
    c, d = grid[y0 + 1, x0 % gw], grid[y0 + 1, (x0 + 1) % gw]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def _tone(c: Canvas, x: int, y: int, value: float, colours: np.ndarray) -> None:
    """A fractional step of a ramp, dithered between the two steps either side of it. The
    x wraps, because the strip has to meet itself."""
    if not (0 <= y < c.h):
        return
    x %= c.w
    value = max(0.0, min(len(colours) - 1.0, value))
    low = int(value)
    above = colours[min(len(colours) - 1, low + 1)]
    c.px(x, y, above if value - low > BAYER_AT(x, y) else colours[low])


def draw_seabed_floor() -> Canvas:
    """The bed: a few rows of sand seen from above, then its front going down into the dark
    with stones set in it."""
    import math
    pixelart.PX = 3
    c = Canvas(FLOOR_W, FLOOR_H, seed=5100)
    rng = np.random.default_rng(5100)
    xs = np.arange(FLOOR_W, dtype=float)
    # The back of the sand's top and its front edge, each a gentle wave that wraps.
    far = 3.4 + _periodic(xs, FLOOR_W, [(3, 0.4, 0.9), (7, 1.3, 0.5), (19, 2.1, 0.3)])
    near = 9.6 + _periodic(xs, FLOOR_W, [(2, 2.0, 0.7), (11, 0.3, 0.4)])
    grain = _noise(FLOOR_W, FLOOR_H, 5, 5101)
    mass = _noise(FLOOR_W, FLOOR_H, 16, 5102)
    # Where the light through the surface lands on the sand: a few bright threads, not a net.
    caustics = [(rng.uniform(0, FLOOR_W), rng.uniform(2.0, 10.0)) for _ in range(16)]
    for x in range(FLOOR_W):
        f, n = far[x], near[x]
        for y in range(FLOOR_H):
            if y < f - 0.5:
                continue
            if y < n:
                t = (y - f) / max(1.0, n - f)
                v = 6.7 - 1.1 * t + 0.35 * math.sin(2 * math.pi * 13 * x / FLOOR_W + 1.4 * y)
                v += 0.6 * (grain[y, x] - 0.5)
                near_two = sorted(math.hypot(min(abs(x - cx), FLOOR_W - abs(x - cx)) * 0.6,
                                             (y - cy) * 1.8) for cx, cy in caustics)[:2]
                if near_two[1] - near_two[0] < 0.9 and near_two[0] < 9:
                    v += 0.9
                if y < f + 0.8:
                    v = max(v, 7.6)  # the crest of the sand, catching the light
                _tone(c, x, y, v, SEABED)
            else:
                # ⚠ NOISE, NOT STRATA. Ruled bands of sediment read as lines drawn across the
                # floor; a lumpy mass going dark with depth reads as ground.
                depth = (y - n) / (FLOOR_H - n)
                v = 4.8 - 5.2 * depth ** 0.62
                v += 1.1 * (mass[y, x] - 0.5) + 0.7 * (grain[y, x] - 0.5)
                if y < n + 1.0:
                    v = min(v, 4.0)  # the shadow under the lip of the sand
                _tone(c, x, y, v, SEABED)
    # ⚠ ONE STONE PER CELL OF A JITTERED GRID, NOT SEVENTY THROWN AT RANDOM. Thrown, a handful
    # landed on one column and stacked into a ladder of stones down the floor's face.
    # Fewer near the top, where the front is still the sand's own body, and now and then a
    # boulder, so the stones are a scatter rather than a pattern.
    columns, courses = 22, 4
    for course in range(courses):
        for column in range(columns):
            if rng.uniform() < (0.65, 0.45, 0.35, 0.35)[course]:
                continue
            cx = (column + rng.uniform(0.1, 0.9)) * FLOOR_W / columns
            n = near[int(cx) % FLOOR_W]
            depth = (course + rng.uniform(0.15, 0.85)) / courses
            r = rng.uniform(1.4, 3.2) * (1.0 + 0.8 * depth)
            if rng.uniform() < 0.12:
                r *= 1.7
            _stone(c, cx, n + 3 + depth * (FLOOR_H - n - 6), r, depth)
    for _ in range(26):
        cx = rng.uniform(0, FLOOR_W)
        _pebble(c, cx, far[int(cx) % FLOOR_W] + rng.uniform(1.8, 5.2), rng.uniform(0.9, 2.2))
    for _ in range(14):
        x = int(rng.uniform(0, FLOOR_W))
        y = int(far[x] + rng.uniform(1.5, 5))
        c.px(x, y, SHELL_BITS[2])
        c.px((x + 1) % FLOOR_W, y, SHELL_BITS[1])
    for _ in range(7):
        x0 = int(rng.uniform(0, FLOOR_W))
        _tuft(c, x0, int(far[x0] + 3), rng)
    return c


def _stone(c: Canvas, cx: float, cy: float, r: float, depth: float) -> None:
    """A stone set in the floor's front, drawn the way pixel art gives a thing its roundness: a
    lit cap along the top, the body a step above the sand around it, and a dark underside with
    its own shadow on the sand below. Darker the deeper it sits, because the water is."""
    base = max(0.5, 3.1 - 2.5 * depth)
    rx, ry = r, r * 0.78
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            d = (nx * nx + ny * ny) ** 0.5
            if d > 1.0:
                continue
            if ny > 0.45 and d > 0.7:
                v = base - 1.5
            elif ny < -0.3 and d > 0.62:
                v = base + 1.7
            else:
                v = base + 0.5 * (-0.4 * nx - 0.6 * ny)
            _tone(c, x, y, v, PEBBLE)
    for x in range(int(cx - rx * 0.6), int(cx + rx * 0.9) + 1):
        y = int(cy + ry + 1)
        if 0 <= y < c.h and c.buf[y, x % c.w, 3] > 0:
            _tone(c, x, y, max(0.0, 3.6 - 5.0 * depth ** 0.62), SEABED)


def _pebble(c: Canvas, cx: float, cy: float, r: float) -> None:
    """A pebble lying on the sand, with its shadow falling down and to the right of it."""
    import math
    for y in range(int(cy), int(cy + r + 1.2)):
        for x in range(int(cx - r + 1), int(cx + r + 2.2)):
            if 0 <= y < c.h and c.buf[y, x % c.w, 3] > 0:
                c.px(x % c.w, y, SEABED[5])
    for y in range(int(cy - r - 1), int(cy + r + 1)):
        for x in range(int(cx - r - 1), int(cx + r + 1)):
            dx, dy = x + 0.5 - cx, (y + 0.5 - cy) * 1.35
            d = math.hypot(dx, dy)
            if d > r:
                continue
            lit = (-dx - dy) / max(0.001, r)
            _tone(c, x, y, 1.0 if d > r - 0.7 and lit < 0.2 else 3.1 + 1.8 * lit, PEBBLE)


def _tuft(c: Canvas, x0: int, base: int, rng) -> None:
    """Sea grass: a few blades out of the sand, the tallest bent over at the top."""
    for blade in range(int(rng.integers(2, 5))):
        x = x0 + blade * 2 - 2
        height = int(rng.integers(3, 7))
        lean = int(rng.choice([-1, 1]))
        for k in range(height):
            y = base - k
            if 0 <= y < c.h:
                colour = WEED[3] if k == height - 1 else WEED[2] if k > height // 2 else WEED[1]
                c.px((x + (lean if k > height * 0.6 else 0)) % c.w, y, colour)


# The terraces, taken back into the water. The delivered plate is a fine painting of stepped
# rock, and at world rate it was a set of platforms nobody could stand on. Hazed toward the
# water's own colour at each depth and moved back to a slower rate in the backdrop, the same
# ledges are the far side of a valley. Its foot goes to the water's colour and then to nothing,
# so it has no cut edge for the floor in front of it to have to hide.
DEEP_PLATES = ROOT / "game" / "assets" / "Level3" / "deep"
## How much of the water stands between the eye and the terraces -- and, over FAR_FOOT, all
## of it: the ledges' feet are lost in the water long before the floor.
FAR_HAZE = 0.42
FAR_FOOT = (640.0, 772.0)
FAR_GONE = (748.0, 772.0)
## The deep band drops its floor layers this far below the waterline, so plate row r of the
## terraces stands in front of the water plate's row r + 360. Below the water plate is the
## DeepFill, whose colour this is.
FLOOR_DROP = 360
DEEP_FILL = np.array([1.0, 27.0, 70.0])


def draw_terraces_far() -> Image.Image:
    def smooth(a, b, x):
        t = np.clip((x - a) / (b - a), 0.0, 1.0)
        return t * t * (3 - 2 * t)

    plate = np.array(Image.open(DEEP_PLATES / "terraces.png").convert("RGBA")).astype(float)
    water = np.array(Image.open(DEEP_PLATES / "water.png").convert("RGB")).astype(float)
    water_rows = water.mean(axis=1)
    rows = np.arange(plate.shape[0], dtype=float)
    behind = np.array([water_rows[FLOOR_DROP + r] if FLOOR_DROP + r < water.shape[0]
                       else DEEP_FILL for r in range(plate.shape[0])])
    amount = (FAR_HAZE + (1.0 - FAR_HAZE) * smooth(FAR_FOOT[0], FAR_FOOT[1], rows))[:, None, None]
    out = plate.copy()
    out[..., :3] = plate[..., :3] * (1.0 - amount) + behind[:, None, :] * amount
    out[..., 3] = plate[..., 3] * (1.0 - smooth(FAR_GONE[0], FAR_GONE[1], rows))[:, None]
    out[int(FAR_GONE[1]):, :, 3] = 0
    return Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8), "RGBA")


SEABED_ART = {"seabed_floor.png": draw_seabed_floor, "terraces_far.png": draw_terraces_far}


# --- The things that live here --------------------------------------------------------------
#
# The delivery paints a sea with nothing moving in it but the water. These are the small
# lives that make it a place: gulls over the beach, the creatures the coral field's facts are
# ABOUT (Lolo names a jellyfish, a starfish, a clam and an urchin -- all deliberately things the
# player cannot draw -- and until now pointed at a piece of coral while he did), and the foam,
# splash, wake and bubbles that say something touched the water. Same idiom as everything else
# here: PX 3, short ramps, light from the upper left, an outline one step darker than the body.

GULL = ramp(["#2e3338", "#7d868d", "#c3cacf", "#eef0ea", "#ffffff"])
BEAK = ramp(["#9a5a1c", "#e39a3b", "#f6c46a"])
JELLY = ramp(["#5b2a6e", "#8e4a9a", "#c07cc4", "#e7b7e3", "#fbe6f7"])
STAR = ramp(["#7a2c12", "#b8481b", "#e27433", "#f5a55a", "#fcd49a"])
CLAM = ramp(["#3a3440", "#6c6474", "#a39aa6", "#d6ced3", "#f4eef0"])
URCHIN = ramp(["#1d0f2c", "#3e1f58", "#6a3a86", "#9a6ab2"])
FOAM = ramp(["#8fd3e0", "#c9eef2", "#f4fdfd"])
BUBBLE = ramp(["#5fb3cf", "#a9e3f0", "#f2fcff"])
SPARK = ramp(["#f5c542", "#fbe79a", "#ffffff"])


def _gull(frame: int) -> Canvas:
    """The "M" every gull is at a distance: two wings bent at the elbow, rising and falling
    over a small white body. Four beats -- up, level, down, level -- flying right."""
    pixelart.PX = 3
    c = Canvas(21, 13, seed=3100 + frame)
    elbow, tip = [(-4, -1), (-2, 0), (1, 3), (-1, 1)][frame]

    def stroke(x0: int, y0: int, x1: int, y1: int, colour: np.ndarray, under: np.ndarray) -> None:
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(steps + 1):
            x = x0 + round((x1 - x0) * i / steps)
            y = y0 + round((y1 - y0) * i / steps)
            c.px(x, y, colour)
            c.px(x, y + 1, under)

    # The far wing first, a step darker, so the near one reads in front of it.
    stroke(9, 6, 5, 6 + elbow, GULL[2], GULL[1])
    stroke(5, 6 + elbow, 1, 6 + tip, GULL[2], GULL[1])
    c.px(1, 6 + tip, GULL[0])
    # Body and tail.
    c.fill(7, 6, 7, 2, GULL[3])
    c.hline(8, 5, 5, GULL[4])
    c.hline(7, 8, 7, GULL[2])
    c.fill(4, 7, 3, 1, GULL[2])
    # Head, eye, beak -- the only thing that says which way it is going.
    c.fill(13, 5, 3, 3, GULL[4])
    c.px(15, 6, GULL[0])
    c.px(16, 6, BEAK[1])
    c.px(17, 6, BEAK[0])
    # The near wing.
    stroke(11, 6, 14, 6 + elbow, GULL[4], GULL[2])
    stroke(14, 6 + elbow, 19, 6 + tip, GULL[3], GULL[2])
    c.px(19, 6 + tip, GULL[0])
    c.px(18, 6 + tip, GULL[0])
    return c


def _jelly(frame: int) -> Canvas:
    """A bell that squeezes and opens, and tentacles that trail behind the pulse."""
    import math
    pixelart.PX = 3
    c = Canvas(16, 24, seed=3200 + frame)
    squeeze = [0, 1, 2, 1][frame]
    half = 7 - squeeze
    top = 1 + squeeze
    height = 8 + squeeze
    cx = 8
    for y in range(height):
        t = y / max(1, height - 1)
        w = int(round(half * math.sqrt(max(0.0, 1.0 - (1.0 - t) ** 2 * 0.85))))
        for x in range(cx - w, cx + w):
            shade = JELLY[3] if x < cx - w // 3 else JELLY[2]
            if y == height - 1:
                shade = JELLY[1]
            colour = shade.copy()
            colour[3] = 215
            c.px(x, top + y, colour)
    # A highlight on the lit shoulder of the bell.
    c.px(cx - half + 2, top + 2, JELLY[4])
    c.px(cx - half + 3, top + 1, JELLY[4])
    # Four tentacles, their wave running down them a quarter-phase a frame behind the bell.
    for i, x0 in enumerate([cx - 4, cx - 1, cx + 1, cx + 4]):
        for y in range(top + height, 23):
            sway = int(round(math.sin((y * 0.7) - frame * 1.6 + i) * 1.2))
            colour = JELLY[2 if (y + i) % 3 else 1].copy()
            colour[3] = 190
            c.px(x0 + sway, y, colour)
    return c


def _starfish(frame: int) -> Canvas:
    import math
    pixelart.PX = 3
    c = Canvas(15, 15, seed=3300)
    cx, cy = 7, 8
    for arm in range(5):
        angle = -math.pi / 2 + arm * 2 * math.pi / 5
        curl = 0.25 if (frame == 1 and arm == 1) else 0.0
        for r in range(8):
            a = angle + curl * r / 7.0
            x = cx + math.cos(a) * r
            y = cy + math.sin(a) * r
            width = 2 if r < 4 else 1
            for dx in range(-width + 1, width):
                for dy in range(-width + 1, width):
                    shade = STAR[3] if (x + dx) < cx and (y + dy) < cy else STAR[2]
                    c.px(int(round(x)) + dx, int(round(y)) + dy, shade)
            if r in (3, 5):
                c.px(int(round(x)), int(round(y)), STAR[4])
    c.fill(cx - 1, cy - 1, 3, 3, STAR[2])
    c.px(cx - 1, cy - 1, STAR[4])
    return c


def _clam(frame: int) -> Canvas:
    """Closed, ajar with the pearl showing, open -- and back, in the scene's own loop."""
    pixelart.PX = 3
    c = Canvas(16, 12, seed=3400)
    gape = [0, 2, 4][frame]
    # Bottom shell: a ridged half-disc.
    for x in range(1, 15):
        depth = 3 - abs(x - 8) // 3
        for y in range(depth + 1):
            c.px(x, 9 + y, CLAM[2] if (x % 3) else CLAM[1])
    c.hline(1, 9, 14, CLAM[3])
    # The pearl, only while it is open.
    if gape >= 2:
        c.fill(7, 9 - gape // 2 - 1, 2, 2, CLAM[4])
        c.px(7, 9 - gape // 2 - 1, (SPARK[2]))
    # Top shell, hinged at the left, lifted by `gape` at the right.
    for x in range(1, 15):
        lift = (x - 1) * gape // 13
        depth = 3 - abs(x - 8) // 3
        for y in range(depth + 1):
            c.px(x, 8 - lift - y, CLAM[3] if (x % 3) else CLAM[2])
        c.px(x, 8 - lift - depth, CLAM[4])
    return c


def _urchin(frame: int) -> Canvas:
    import math
    pixelart.PX = 3
    c = Canvas(15, 13, seed=3500)
    cx, cy = 7, 8
    for k in range(14):
        a = math.pi + k * math.pi / 13
        length = 6 if (k + frame) % 2 == 0 else 5
        for r in range(3, length + 1):
            c.px(int(round(cx + math.cos(a) * r)), int(round(cy + math.sin(a) * r)),
                 URCHIN[3] if r == length else URCHIN[1])
    for y in range(-3, 4):
        for x in range(-4, 5):
            if x * x / 16.0 + y * y / 9.0 <= 1.0:
                c.px(cx + x, cy + y, URCHIN[2] if (x < 0 and y < 0) else URCHIN[1])
    c.px(cx - 2, cy - 2, URCHIN[3])
    return c


def _foam(frame: int) -> Canvas:
    """Surf breaking against the shore: froth piled up where the water meets the land, thinning
    seaward into specks, and reaching a little further out in each frame of the surge.

    ⚠ IT TAPERS, AND IT HAS NO BOTTOM EDGE. It was a 144-pixel strip with a wavy top, a straight
    bottom and a regular pattern of holes -- a dashed rectangle floating on the water beside the
    beach, which is what it looked like. Column 0 is the shore; nothing is drawn more than a
    row under the waterline row, so the foam sits ON the water and the sea carries on under it."""
    import math
    pixelart.PX = 3
    width, height, line = 40, 8, 5
    c = Canvas(width, height, seed=3600)
    rng = np.random.default_rng(3600 + frame)
    reach = (0.45, 0.62, 0.8)[frame]
    for x in range(width):
        t = x / float(width - 1)
        # How much froth there is at this distance from the land: a heap against it, then
        # streaks, then nothing past this frame's reach.
        heap = max(0.0, 1.0 - t / 0.3)
        density = heap + max(0.0, 1.0 - t / reach) * 0.75
        if density <= 0.02:
            continue
        crest = line - int(round(3.2 * heap + 0.8 * math.sin(x * 0.9 + frame * 1.7)))
        for y in range(max(0, crest), min(height, line + 1 + int(heap * 2.5 + rng.uniform()))):
            if y > line and rng.uniform() > heap:
                continue  # under the waterline only where the heap is
            if heap < 0.2 and rng.uniform() > density:
                continue  # out on the water it breaks up into specks
            if y == crest:
                colour = FOAM[2]
            elif y <= line:
                colour = FOAM[2] if rng.uniform() < 0.35 else FOAM[1]
            else:
                colour = FOAM[0]
            c.px(x, y, colour)
    return c


def _splash(frame: int) -> Canvas:
    pixelart.PX = 3
    c = Canvas(11, 6, seed=3700)
    if frame == 0:
        c.px(5, 1, FOAM[2]); c.px(4, 2, FOAM[1]); c.px(6, 2, FOAM[1]); c.hline(3, 4, 5, FOAM[1])
    elif frame == 1:
        c.px(2, 2, FOAM[2]); c.px(8, 2, FOAM[2]); c.hline(1, 4, 9, FOAM[1]); c.px(5, 3, FOAM[2])
    else:
        c.hline(0, 5, 3, FOAM[0]); c.hline(8, 5, 3, FOAM[0])
    return c


def _wake(frame: int) -> Canvas:
    import math
    pixelart.PX = 3
    c = Canvas(26, 6, seed=3800)
    for x in range(26):
        fade = x / 25.0
        y = 2 + int(round(math.sin(x * 0.8 - frame * 2.1) * 1.0))
        if (x + frame) % 4 == 0 and fade > 0.3:
            continue
        colour = FOAM[2 if fade > 0.5 else 1].copy()
        colour[3] = int(90 + 165 * fade)
        c.px(x, y, colour)
        if fade > 0.6:
            c.px(x, y + 1, FOAM[0])
    return c


def _bubble(frame: int) -> Canvas:
    pixelart.PX = 3
    c = Canvas(5, 5, seed=3900)
    for (x, y) in [(1, 0), (2, 0), (3, 0), (0, 1), (4, 1), (0, 2), (4, 2), (0, 3), (4, 3),
                   (1, 4), (2, 4), (3, 4)]:
        c.px(x, y, BUBBLE[1])
    c.px(1 + frame % 2, 1, BUBBLE[2])
    return c


def _spark(frame: int) -> Canvas:
    pixelart.PX = 3
    c = Canvas(9, 9, seed=4000)
    reach = [1, 3, 4, 2][frame]
    for r in range(reach + 1):
        tone = SPARK[2] if r == 0 else SPARK[1 if r < 3 else 0]
        for dx, dy in [(r, 0), (-r, 0), (0, r), (0, -r)]:
            c.px(4 + dx, 4 + dy, tone)
    if reach >= 3:
        for dx, dy in [(1, 1), (-1, 1), (1, -1), (-1, -1)]:
            c.px(4 + dx, 4 + dy, SPARK[1])
    return c


LIFE = {
    "gull": (_gull, 4),
    "jelly": (_jelly, 4),
    "starfish": (_starfish, 2),
    "clam": (_clam, 3),
    "urchin": (_urchin, 2),
    "foam": (_foam, 3),
    "splash": (_splash, 3),
    "wake": (_wake, 3),
    "bubble": (_bubble, 2),
    "spark": (_spark, 4),
}


## The jar's half-width, row by row down its silhouette: the lip, the neck, the shoulders
## rounding out, the straight body, the bottom rounding in. None above the lip.
JAR_ROWS = {8: 4.0, 9: 3.6, 10: 5.2, 11: 6.3, 27: 6.6, 28: 5.8}
JAR_CENTRE, JAR_BODY, INK_TOP = 9.5, 7.0, 15


def _jar_half(y: int):
    if y < 8 or y > 28:
        return None
    return JAR_ROWS.get(y, JAR_BODY)


def _jar_px(c: Canvas, x: int, y: int, colour: np.ndarray, alpha: int | None = None) -> None:
    if 0 <= x < c.w and 0 <= y < c.h:
        c.buf[y, x] = colour
        if alpha is not None:
            c.buf[y, x, 3] = alpha


def _jar_tone(colours: np.ndarray, value: float, x: int, y: int) -> np.ndarray:
    value = max(0.0, min(len(colours) - 1.0, value))
    low = int(value)
    return colours[min(len(colours) - 1, low + 1)] if value - low > BAYER_AT(x, y) \
        else colours[low]


def draw(frame: int) -> Canvas:
    """The ink jar, as a jar: a glass vessel you can see the ink in.

    ⚠ IT WAS A WHITE CARD. The first jar was a flat rectangle of dithered pale grey with a drop
    on it and a stack of translucent rectangles behind it for a glow -- which read as a dark
    box -- and next to a painted seabed it was the flattest thing in the level. Kent asked for
    objects that look three-dimensional. So: rounded shoulders and bottom, a cork seen a little
    from above so its top is an ellipse, the ink inside shaded as the cylinder it is and bright
    along its surface, empty glass above it that the sea shows through, a paper label that
    darkens as it wraps round, a specular streak down the lit side and a spark on the shoulder.
    Light from the upper left, as everywhere.

    THREE FRAMES, AND WHAT MOVES IS THE INK: it brightens a step a frame, the drop with it, and
    a few motes rise off the cork. It is a thing left on the seabed that still has something
    in it, not a pickup that bounces."""
    import math
    # PX=3 rather than the library default of 2: this sits in a scene drawn at a much finer
    # grain than Piyesta's interiors, and at 2 the jar reads as a different game's prop.
    pixelart.PX = 3
    c = Canvas(W, H, seed=1703 + frame)
    swell = (0.0, 0.5, 1.0)[frame]
    for y in range(H):
        half = _jar_half(y)
        if half is None:
            continue
        x0 = int(math.floor(JAR_CENTRE - half + 0.5))
        x1 = int(math.ceil(JAR_CENTRE + half - 0.5))
        for x in range(x0, x1 + 1):
            if x in (x0, x1):
                _jar_px(c, x, y, GLASS_EDGE)
                continue
            across = (x + 0.5 - JAR_CENTRE) / half
            curve = math.sqrt(max(0.0, 1.0 - across * across))
            if INK_TOP <= y <= 27:
                v = 1.2 + 3.0 * curve - 0.9 * across + swell
                if y == INK_TOP:
                    v += 1.6  # the ink's surface, catching the light
                _jar_px(c, x, y, _jar_tone(INK, v, x, y))
            else:
                # Empty glass: mostly the sea behind it, tinted, thicker toward its rims.
                _jar_px(c, x, y, GLASS[2], 70 + int(40 * (1.0 - curve)))
    for x in range(int(JAR_CENTRE - 5.0), int(JAR_CENTRE + 5.0) + 1):
        _jar_px(c, x, 28, GLASS[1] if x > JAR_CENTRE else GLASS[2])  # the thick glass base
    for x in range(int(JAR_CENTRE - 4.0), int(JAR_CENTRE + 4.0) + 1):
        _jar_px(c, x, 29, GLASS_EDGE)
    for x in range(6, 14):
        _jar_px(c, x, 8, GLASS[4] if x < 9 else GLASS[3] if x < 12 else GLASS[1])  # the lip
    # The label, wrapped round its middle.
    for y in range(18, 25):
        for x in range(int(JAR_CENTRE - JAR_BODY) + 1, int(JAR_CENTRE + JAR_BODY)):
            across = (x + 0.5 - JAR_CENTRE) / JAR_BODY
            v = 0.6 + 2.6 * math.sqrt(max(0.0, 1.0 - across * across)) - 0.7 * across
            if y in (18, 24):
                v -= 0.8
            _jar_px(c, x, y, _jar_tone(PAPER, v, x, y))
    # The drop printed on it: a point at the top, round at the bottom, brighter as the ink is.
    lit = DROP[min(3, 2 + frame // 2)]
    for row, (a, b) in enumerate(((9, 10), (8, 11), (8, 11), (7, 12), (8, 11))):
        for x in range(a, b + 1):
            _jar_px(c, x, 19 + row, lit)
    _jar_px(c, 8, 20, DROP[3])
    _jar_px(c, 8, 21, DROP[3])
    for x, y in ((11, 21), (11, 22), (12, 22), (10, 23), (11, 23)):
        _jar_px(c, x, y, DROP[1])
    # The specular streak down the lit side, and a spark on the shoulder; a dimmer glint
    # down the far side, where the glass turns away.
    for y in range(12, 27):
        if not 18 <= y <= 24:
            _jar_px(c, 5, y, GLASS[4], 230 if y >= INK_TOP else 200)
    _jar_px(c, 6, 11, GLASS[4])
    _jar_px(c, 5, 12, GLASS[4])
    for y in range(13, 26, 3):
        _jar_px(c, 14, y, GLASS[3], 120)
    # The cork: a cylinder seen a little from above.
    for y in range(3, 8):
        for x in range(6, 14):
            across = (x + 0.5 - 10.0) / 4.0
            if y <= 4:
                if y == 3 and x in (6, 13):
                    continue
                v = 3.2 - 0.8 * across + (0.6 if y == 3 else 0.0)
            else:
                v = 2.6 - 1.6 * across - (0.6 if y == 7 else 0.0)
            _jar_px(c, x, y, _jar_tone(CAP, v, x, y))
    for x in range(7, 13):
        _jar_px(c, x, 2, GLASS_EDGE)
    for y in range(4, 8):
        _jar_px(c, 5, y, GLASS_EDGE)
        _jar_px(c, 14, y, GLASS_EDGE)
    # A few motes rising off it, so a still thing still has something happening.
    rng = np.random.default_rng(1703 + frame)
    for _ in range(2 + frame):
        _jar_px(c, int(rng.uniform(6, 14)), int(rng.uniform(0, 3)), GLOW[3], 170)
    return c


# --- The bangka ------------------------------------------------------------------------------
#
# ⚠ THE ONE OBJECT IN THE GAME THAT IS FOUND RATHER THAN DRAWN, and therefore the one that
# cannot get its picture from the player's ink. Everything else placed in the world is built
# out of the strokes somebody made on the canvas; the boat has none, so it was the engine's
# bare outline -- a white wireframe trapezium -- for the whole of the crossing the route is
# named after. This is its picture. The hull's COLLISION still comes from that outline, so the
# draft, the seat and the buoyancy are the numbers run_level3_boat_probe already measured.
#
# A bangka: a narrow hull that is a lens in profile, rising to a point at both ends and higher
# at the prow, bamboo booms out to a katig float carried a little low and forward, and a sail
# left furled on its spar. Weathered, because nobody came back for it.
HULL = ramp(["#2a1a12", "#4a2f1e", "#6b4526", "#8d5f33", "#b07f4a"])
TRIM = ramp(["#12323f", "#1c4f62", "#2a7288", "#49a0b4"])
BAMBOO = ramp(["#4a4326", "#6f6435", "#95884a", "#bfae6a"])
SAILCLOTH = ramp(["#6d6047", "#968660", "#bfae82", "#d8c9a0"])
ROPE = ramp(["#5b4a32", "#8a7350"])
BANGKA_W, BANGKA_H = 72, 44
## The row the hull floats at. level_3.gd pins the picture to the hull by this, so redrawing
## the sheer does not sink the boat.
BANGKA_WATERLINE = 30
BOW, STERN = 66, 6


def _sheer(x: int) -> int:
    """Top of the hull at this column. Lowest amidships, up at both ends, higher forward."""
    t = (x - STERN) / float(BOW - STERN)
    return BANGKA_WATERLINE - 4 - int(round(4.5 * (2.0 * t - 1.0) ** 3 * (0.5 + 0.5 * t)
                                            + 2.0 * (2.0 * t - 1.0) ** 2))


def _keel(x: int) -> int:
    """Bottom of the hull. Flat-ish amidships and drawn up to meet the sheer at the ends."""
    t = (x - STERN) / float(BOW - STERN)
    return BANGKA_WATERLINE + 3 - int(round(9.0 * (2.0 * t - 1.0) ** 6))


def _hull(c: Canvas, upturned: bool) -> None:
    """The hull alone. `upturned` turns it keel-up for the one lying on the sand, which is a
    reflection about the waterline rather than a second drawing."""
    def row(y: int) -> int:
        return BANGKA_WATERLINE * 2 - y if upturned else y

    for x in range(STERN, BOW + 1):
        top, bottom = _sheer(x), _keel(x)
        if bottom < top:
            continue
        for y in range(top, bottom + 1):
            down = (y - top) / max(1.0, float(bottom - top))
            shade = HULL[3] if down < 0.30 else (HULL[2] if down < 0.68 else HULL[1])
            c.px(x, row(y), shade)
        # Lit along the sheer, dark along the keel -- and the other way up when it is.
        c.px(x, row(top), HULL[0] if upturned else HULL[4])
        c.px(x, row(bottom), HULL[4] if upturned else HULL[0])
        # The one painted band a working boat carries, a plank under the sheer.
        if bottom - top >= 4:
            band = top + (1 if not upturned else 2)
            c.px(x, row(band), TRIM[2] if (x + band) % 3 else TRIM[1])
            c.px(x, row(band + 1), TRIM[0])
    # Stem and stern posts, carried on past the sheer from the last column the hull actually
    # HAS -- measured, not assumed: the ends taper to nothing a few columns inside STERN/BOW,
    # and posts put on those two left a hook floating clear of the boat.
    solid = [x for x in range(STERN, BOW + 1) if _keel(x) >= _sheer(x)]
    if not solid:
        return
    for x, height, lean in ((solid[-1], 5, -1), (solid[0], 3, 1)):
        for step in range(height):
            at = x + lean * ((step + 1) // 2)
            top = _sheer(at) - 1 - step
            c.px(at, row(top), HULL[3] if step % 2 else HULL[2])
            c.px(at - lean, row(top), HULL[1])
    # A thwart amidships: the plank the apo sits on, and the only thing inside the hull.
    if not upturned:
        seat = _sheer(36) + 3
        for x in range(28, 46):
            c.px(x, row(seat), HULL[3])
            c.px(x, row(seat + 1), HULL[1])
        # A coil of line in the stern, left by whoever left the boat.
        for dx in range(5):
            c.px(16 + dx, row(_sheer(18) + 4), ROPE[1] if dx % 2 else ROPE[0])
            c.px(16 + dx, row(_sheer(18) + 5), ROPE[0])


def _outrigger(c: Canvas) -> None:
    """The katig, and the two booms that carry it. In profile this is the thing that says
    bangka rather than rowboat, so it is forward of the hull and a little low, with the booms
    visible as separate members instead of a plank stuck to the keel."""
    float_y = BANGKA_WATERLINE + 7
    left, right = 30, BOW + 2
    for x in range(left, right + 1):
        thin = x <= left + 1 or x >= right - 1
        c.px(x, float_y, BAMBOO[3] if not thin else BAMBOO[2])
        c.px(x, float_y + 1, BAMBOO[2] if not thin else BAMBOO[1])
        if not thin:
            c.px(x, float_y + 2, BAMBOO[0])
    for boom_x in (24, 44):
        top = _sheer(boom_x) + 2
        steps = float_y - top
        for step in range(steps + 1):
            x = boom_x + int(round(step * 0.62))
            y = top + step
            c.px(x, y, BAMBOO[2])
            c.px(x + 1, y, BAMBOO[0])
        c.px(boom_x, top, ROPE[1])
        c.px(boom_x + int(round(steps * 0.62)), float_y - 1, ROPE[0])


def _mast_and_sail(c: Canvas) -> None:
    """Furled, and lashed to its spar. A boat left for years does not leave sail up, and a
    triangle of bright canvas would be the loudest thing on the screen."""
    mast_x = 44
    head = 5
    foot = _sheer(mast_x)
    # One stay each way, ending on the posts rather than sweeping over the whole boat: drawn
    # to the sheer it arced from end to end and read as a carrying handle.
    for target in (BOW - 3, STERN + 4):
        span = target - mast_x
        drop = _sheer(target) - 4 - head
        for step in range(abs(span) + 1):
            x = mast_x + (1 if span > 0 else -1) * step
            c.px(x, head + int(round(step / float(abs(span)) * drop)), ROPE[0])
    for y in range(head, foot + 1):
        c.px(mast_x, y, HULL[3])
        c.px(mast_x + 1, y, HULL[1])
    c.px(mast_x, head - 1, HULL[4])
    # The bundle: canvas rolled along a spar that droops away from the mast.
    length = 17
    for step in range(length):
        x = mast_x + 2 + step
        t = step / float(length - 1)
        droop = int(round(3.4 * t * t))
        thick = 4 - int(round(2.6 * abs(t - 0.42) * 2.0))
        thick = max(1, thick)
        top = head + 5 + droop
        for y in range(top, top + thick):
            c.px(x, y, SAILCLOTH[2] if y < top + thick - 1 else SAILCLOTH[1])
        c.px(x, top - 1, SAILCLOTH[3])
        c.px(x, top + thick, SAILCLOTH[0])
    for tie in (7, 15):
        t = tie / float(length - 1)
        top = head + 4 + int(round(3.4 * t * t))
        for y in range(top, top + 5):
            c.px(mast_x + 2 + tie, y, ROPE[0])


def draw_bangka_afloat() -> Canvas:
    pixelart.PX = 3
    c = Canvas(BANGKA_W, BANGKA_H, seed=2401)
    _mast_and_sail(c)
    _hull(c, False)
    _outrigger(c)
    # Wear: the sea takes the paint off a boat nobody looks after.
    c.speckle(STERN + 4, BANGKA_WATERLINE - 5, BOW - STERN - 8, 8, HULL[1], 0.05)
    return c


def draw_bangka_beached() -> Canvas:
    """The same boat, turned over on the sand. What the apo finds and presses E at.

    ⚠ DRAWN, NOT REFLECTED. Mirroring the floating hull about its waterline is the honest
    thing to do and it produced a stack of planks: upside down you see the OUTSIDE of the
    planking and the keel, which is one smooth arc with the sheer down in the sand -- not the
    inside of a boat with its rail in the air."""
    import math
    pixelart.PX = 3
    c = Canvas(BANGKA_W, BANGKA_H, seed=2403)
    sand = BANGKA_WATERLINE + 9
    left, right = STERN + 1, BOW + 1
    for x in range(left, right + 1):
        t = (x - left) / float(right - left)
        # The keel, highest a little aft of amidships, and the ends lifting clear of the sand.
        arc = 10.0 * math.sin(math.pi * min(1.0, max(0.0, t))) ** 0.7
        keel = sand - int(round(arc))
        lift = int(round(2.0 * (2.0 * t - 1.0) ** 2))
        foot = sand - lift
        if keel >= foot:
            continue
        for y in range(keel, foot + 1):
            down = (y - keel) / max(1.0, float(foot - keel))
            c.px(x, y, HULL[3] if down < 0.34 else (HULL[2] if down < 0.74 else HULL[1]))
        c.px(x, keel, HULL[4])
        c.px(x, foot, HULL[0])
        # The painted band is down by the sand now, because the rail is.
        if foot - keel >= 4:
            c.px(x, foot - 1, TRIM[1] if (x + foot) % 3 else TRIM[2])
    # The stems, still standing proud of the sand at both ends.
    for x, lean in ((right, -1), (left, 1)):
        for step in range(4):
            at = x + lean * ((step + 1) // 2)
            c.px(at, sand - 2 - step, HULL[3] if step % 2 else HULL[2])
            c.px(at - lean, sand - 2 - step, HULL[1])
    c.speckle(left + 5, sand - 8, right - left - 12, 7, HULL[1], 0.07)
    # ⚠ ITS SHADOW, AND THE BOOM AS A POLE. The two booms it was dragged up on were two flat
    # rows of olive under the hull, which at game scale read as a ruled stripe drawn along the
    # sand -- the one flat thing left on the beach. The hull now sits in its own shadow, darkest
    # under the keel and gone at the stems, and the boom is one length of bamboo lying in front
    # of it: lit along its top, dark along its underside, a node every nine pixels, cut ends
    # showing the pale cane, and its own shadow on the sand.
    shade = np.array([40, 26, 10, 0], dtype=np.uint8)
    for x in range(left - 2, right + 3):
        t = (x - left) / float(right - left)
        alpha = int(120 * max(0.0, 1.0 - abs(2.0 * t - 1.0) ** 1.6))
        if alpha > 12 and c.buf[sand + 1, x, 3] == 0:
            c.buf[sand + 1, x] = shade
            c.buf[sand + 1, x, 3] = alpha
    a, b = left + 4, right - 8
    for x in range(a, b):
        node = (x - a) % 9 == 0
        c.px(x, sand + 2, BAMBOO[1] if node else BAMBOO[2])
        c.px(x, sand + 3, BAMBOO[0])
        c.buf[sand + 4, x] = shade
        c.buf[sand + 4, x, 3] = 80
    c.px(a - 1, sand + 2, BAMBOO[3])
    c.px(b, sand + 2, BAMBOO[3])
    return c


BANGKA = {"bangka_afloat.png": draw_bangka_afloat,
          "bangka_beached.png": draw_bangka_beached}


# --- What is found, and what the crossing is rowed with -------------------------------------
#
# Three things the level had no picture of: what the bakunawa finds when the light shows it
# where to look, and the next painting in the island's sand -- both of which the level marked
# with a burst of sparkles over nothing -- and the paddle the apo rows the bangka with. Drawn in
# the same idiom as everything here.
#
# ⚠ THE GOLD IS THE HOUSE'S GOLD. Lola's paintings hang in gilt mouldings drawn from UISkin's
# GILT ramp; a piece of one found on the seabed has to be recognisably the same frame, or it is
# a piece of a different picture. The canvas in it is the house's own painting of this sea.

GILT_RAMP = ramp(["#8c571d", "#a57223", "#c89637", "#dba736", "#edca52", "#fbe567"])
CANVAS_BACK = ramp(["#8f7f64", "#c9b99a", "#e8dcc0"])
PAINTING_OF_THE_SEA = ROOT / "game" / "assets" / "hub" / "paintings" / "level_3.png"
FRAGMENT_W, FRAGMENT_H = 30, 22


def draw_painting_fragment() -> Canvas:
    """A torn corner of one of Lola's canvases, still in its gilt: what the bakunawa had lost.

    The design asks for "something the player recognises -- an object from Level 1's house, or a
    piece of the painting. A generic chest wastes the beat." The house is where her paintings
    hang, so the piece is a corner of one of them: the moulding's top and left bars, broken off,
    and a scrap of canvas torn diagonally across, with this very sea painted on it."""
    import math
    from PIL import Image
    pixelart.PX = 3
    c = Canvas(FRAGMENT_W, FRAGMENT_H, seed=4100)
    painting = np.array(Image.open(PAINTING_OF_THE_SEA).convert("RGBA"))
    # The torn edge: a diagonal from the top bar's broken end to the left bar's, ragged.
    def tear(x: int) -> float:
        return 21.0 - x * 0.78 + 1.4 * math.sin(x * 1.7) + 0.8 * math.sin(x * 3.9 + 1.0)
    for y in range(FRAGMENT_H):
        for x in range(FRAGMENT_W):
            if y > tear(x):
                continue
            if x < 4 or y < 4:
                continue
            # The canvas: the painting's own pixels -- the karst island in the middle of it and
            # the teal water under it, the part of that picture anybody would know again.
            sample = painting[min(painting.shape[0] - 1, 34 + y), min(painting.shape[1] - 1, 64 + x)]
            c.px(x, y, sample)
            # The last pixel before the tear is the canvas's own weave, pale, so the edge reads
            # as torn cloth rather than as a cut.
            if y + 1.2 > tear(x):
                c.px(x, y, CANVAS_BACK[2] if (x + y) % 2 else CANVAS_BACK[1])
    # The gilt: the top and left bars of the moulding, four pixels deep, broken off where the
    # canvas tore. Lit on its outer edge, a keyline on the inner, as the house draws it.
    top_end = 24
    left_end = 18
    for x in range(top_end):
        broken = x > top_end - 4 and (x * 7) % 3 == 0
        for y in range(4):
            if broken and y > 1:
                continue
            tone = [GILT_RAMP[4], GILT_RAMP[5], GILT_RAMP[3], GILT_RAMP[1]][y]
            c.px(x, y, tone)
    for y in range(left_end):
        broken = y > left_end - 4 and (y * 5) % 3 == 0
        for x in range(4):
            if broken and x > 1:
                continue
            tone = [GILT_RAMP[4], GILT_RAMP[5], GILT_RAMP[3], GILT_RAMP[1]][x]
            if y < 4:
                tone = GILT_RAMP[5] if x + y < 3 else tone
            c.px(x, y, tone)
    # The keyline round the outside and at the splintered ends, so it holds against the seabed.
    outline = GILT_RAMP[0]
    for x in range(top_end):
        c.px(x, 0, GILT_RAMP[5] if x % 5 else GILT_RAMP[4])
    for x in range(top_end - 3, top_end + 1):
        c.px(x, 1 + (x % 2), outline)
    for y in range(left_end - 3, left_end + 1):
        c.px(1 + (y % 2), y, outline)
    for x in range(4, top_end - 2):
        c.px(x, 4, GILT_RAMP[0])
    for y in range(4, left_end - 2):
        c.px(4, y, GILT_RAMP[0])
    # One ornament on the corner, the rosette every gilt corner in the house has at this size.
    for dx, dy in ((1, 1), (2, 1), (1, 2), (2, 2)):
        c.px(dx, dy, GILT_RAMP[5])
    c.px(2, 2, GILT_RAMP[2])
    return c


# The sand the next painting is half buried in: its own sand plate's colours, a low heap with a
# ragged crest, lit on top and shaded underneath. It is laid in front of the frame's foot.
MOUND_W, MOUND_H = 56, 9


def draw_sand_mound() -> Canvas:
    import math
    pixelart.PX = 3
    c = Canvas(MOUND_W, MOUND_H, seed=4200)
    for x in range(MOUND_W):
        t = x / float(MOUND_W - 1)
        crest = MOUND_H - 1 - int(round((math.sin(math.pi * t) ** 0.7) * (MOUND_H - 2)
                                        + 0.8 * math.sin(x * 0.9)))
        crest = max(0, min(MOUND_H - 1, crest))
        for y in range(crest, MOUND_H):
            depth = (y - crest) / float(max(1, MOUND_H - crest))
            if y == crest:
                colour = SAND[4] if (x % 3) else SAND[3]
            elif depth < 0.45:
                colour = SAND[3]
            elif depth < 0.8:
                colour = SAND[2] if (x + y) % 3 else SAND[3]
            else:
                colour = SAND[2]
            c.px(x, y, colour)
    for x, y in ((9, 6), (23, 5), (38, 6), (47, 7)):
        c.px(x, y, SAND[1])
    return c


# A paddle for the bangka: the apo sits in it for the whole of the Artist crossing, and a boat
# that moves with nobody visibly rowing it reads as a boat being dragged. Its shaft and blade
# are the hull's own wood.
PADDLE_W, PADDLE_H = 5, 28


def draw_paddle() -> Canvas:
    pixelart.PX = 3
    c = Canvas(PADDLE_W, PADDLE_H, seed=4300)
    # The grip at the top, a knob a pixel wider than the shaft.
    for x in range(1, 4):
        c.px(x, 0, HULL[1])
    c.px(2, 0, HULL[3])
    for y in range(1, 19):
        c.px(2, y, HULL[3] if y % 5 else HULL[2])
        c.px(1, y, HULL[1])
    # The blade, widening from the shaft and rounded at the tip, lit down its left edge.
    widths = [1, 2, 2, 2, 2, 2, 2, 1, 1]
    for index, half in enumerate(widths):
        y = 19 + index
        for x in range(2 - half, 3 + half):
            if not (0 <= x < PADDLE_W):
                continue
            colour = HULL[4] if x == 2 - half else HULL[3]
            if x == 2 + half:
                colour = HULL[1]
            c.px(x, y, colour)
    return c


FOUND = {"painting_fragment.png": draw_painting_fragment,
         "sand_mound.png": draw_sand_mound,
         "paddle.png": draw_paddle}


def build() -> list[Path]:
    OUT.mkdir(parents=True, exist_ok=True)
    written = []
    for frame in range(FRAMES):
        path = OUT / f"ink_jar_{frame}.png"
        draw(frame).save(path)
        written.append(path)
    for table in (LAND, PALMS, SEABED_ART, BANGKA, FOUND):
        for name, painter in table.items():
            path = OUT / name
            painter().save(path)
            written.append(path)
    for name, (painter, frames) in LIFE.items():
        for frame in range(frames):
            path = OUT / f"{name}_{frame}.png"
            painter(frame).save(path)
            written.append(path)
    return written


def _expected() -> list[Path]:
    return [OUT / f"ink_jar_{frame}.png" for frame in range(FRAMES)] + \
        [OUT / name for name in LAND] + [OUT / name for name in PALMS] + \
        [OUT / name for name in SEABED_ART] + \
        [OUT / name for name in BANGKA] + \
        [OUT / name for name in FOUND] + \
        [OUT / f"{name}_{frame}.png" for name, (_p, n) in LIFE.items() for frame in range(n)]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--search-edges", action="store_true",
                    help="rank every phase of the wall for each beach's edge (see LANDS)")
    args = ap.parse_args()
    if args.search_edges:
        search_edges()
        return 0

    before = {}
    if args.check:
        for path in _expected():
            if not path.exists():
                print(f"{path} does not exist -- run tools/build_dagat_props.py", file=sys.stderr)
                return 1
            before[path] = hashlib.sha256(path.read_bytes()).hexdigest()

    written = build()
    if args.check:
        stale = [p for p in written
                 if hashlib.sha256(p.read_bytes()).hexdigest() != before.get(p)]
        if stale:
            print("stale, rebuilt: " + ", ".join(p.name for p in stale), file=sys.stderr)
            return 1
        print(f"{len(written)} authored props are up to date")
        return 0
    print(f"Wrote {len(written)} frames to {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
