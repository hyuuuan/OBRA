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
CAP = ramp(["#2a1d16", "#3d2b20", "#55392a", "#6d4a36"])
DROP = ramp(["#0e3f66", "#1667a4", "#2b95d6", "#71c8ef"])
GLOW = ramp(["#1667a4", "#2b95d6", "#71c8ef", "#bdeaff"])

W, H = 20, 30
FRAMES = 3

# --- The land under the water ---------------------------------------------------------------
#
# The sand plate stops 150 pixels under the surface the apo walks on, and the sea goes down
# a thousand more. The land has to go down to the seabed too -- the collision does -- and this
# is what it looks like on the way.
#
# ⚠ A PILE OF BOULDERS, NOT A WALL OF BLOCKS. Twice before this was drawn as a surface: first
# a smooth dither with round stones scattered through it, a dark slab with polka dots; then
# Voronoi blocks in courses with a crevice between every two, which at game scale was a black
# cobbled wall standing in the sea -- "the platform" in "the platform and the ocean below since
# its so messy". Rock under water is rounded stone heaped on stone. Each boulder here is a lumpy
# ellipse lit from the upper left, with a lit rim along its top, a dark rim along its underside,
# moss on its top near the surface, and the whole pile darkening with depth as the water does.
# The gaps between them are the crevices, and near the top they are the plate's own earth.
#
# ⚠ ONE PAINTING PER BEACH, NOT A TILE AND AN EDGE. The rock used to be a tiled fill with a
# separate face texture laid over its seaward end, and the join between the two textures was a
# seam however alike they were. Each beach's land is one picture now -- the home beach's facing
# east, the island's facing west, each with its own seed so the two are not the same heap --
# and its seaward edge is where its own stones stop: the stones nearest the water are pulled in
# to end a little either side of the collision edge, so the edge is a line of boulders and not
# a cut.
#
# ⚠ AND THE SAND'S EDGE IS THE SAND PLATE'S OWN PIXELS. The plate is laid across the ground
# and cut straight at the collision edge. The land carries the plate's pixels on past the cut,
# mirrored from just inside it, round-shouldered at the surface and wet toward the water -- so
# the beach ends on its own sand, with no second, flatter sand dithered over it. (The dithered
# lip that did that job read as a checkerboard down the side of the beach.)
#
# Colours: CLIFF from the terraces' rock and the water beside it, EARTH the sand plate's last
# rows, MOSS the green on the terraces' ledges.
CLIFF = ramp(["#040c1a", "#08172a", "#0e223a", "#152e48", "#1e3c56", "#294c64",
              "#365d72", "#48707f", "#5e858d"])
EARTH = ramp(["#20242f", "#282a3a", "#303444"])
MOSS = ramp(["#15362f", "#1f5237", "#2d6b3e", "#468a4a"])
## The beach's sand, as the plate paints it. The heap the next painting stands in is this sand.
SAND = ramp(["#6f5141", "#be9564", "#e6b775", "#f0c888", "#f7dba6"])
SAND_PLATE = ROOT / "game" / "assets" / "Level3" / "shore" / "sand.png"
## World rows: the land's picture starts just above the surface and runs past the lowest the
## camera ever looks; the sand plate's dark earth band starts at BAND_Y and the plate ends at
## ROCK_Y. The shore band pins its plate's top at PLATE_TOP, so the land's own top_row in the
## backdrop is LAND_TOP - PLATE_TOP.
LAND_TOP, LAND_BOTTOM = 556, 1867
SURFACE_Y, BAND_Y, ROCK_Y = 560, 660, 711
PLATE_TOP = -230
LAND_PX = 3
## name: (world left, world right, the collision edge, whether the sea is to its right, the
## world x the sand plate's column 0 is laid at, seed). The left and right are where the
## backdrop sets each piece down: the home land from the home ground's west end, the island's
## to the island ground's east end.
LANDS = {
    "land_home.png": (100, 1030, 1000, True, 100, 6100),
    "land_island.png": (4468, 5380, 4500, False, 4500, 6200),
}


def BAYER_AT(x: int, y: int) -> float:
    return float(pixelart.BAYER[y % 4, x % 4])


def _boulders(width: int, height: int, seed: int, edge_of, facing_right: bool,
              first_row: float) -> list:
    """A packed pile: scanned in rows, each row's stones sized at random, the ones that would
    stand past the edge pulled in to end a little either side of it. Drawn in a shuffled order
    so no row is always in front of the next."""
    import math
    rng = np.random.default_rng(seed)
    out = []
    y = first_row
    while y < height + 16:
        x = rng.uniform(-14, 0)
        row_r = rng.uniform(7, 14)
        while x < width + 14:
            r = row_r * rng.uniform(0.65, 1.4)
            if rng.uniform() < 0.07:
                r *= 1.6
            cx, cy = x + r, y + rng.uniform(-3, 3) + r * 0.6
            e = edge_of(cy)
            reach = rng.uniform(-3.0, 6.0)
            if facing_right and cx + r > e + reach:
                cx = e + reach - r
            if not facing_right and cx - r < e - reach:
                cx = e - reach + r
            out.append((cx, cy, r, rng.uniform(0, 2 * math.pi), rng.uniform(0, 2 * math.pi),
                        rng.uniform(-0.6, 0.6)))
            x += r * rng.uniform(1.5, 1.9)
        y += row_r * rng.uniform(1.0, 1.3)
    out = [out[i] for i in rng.permutation(len(out))]
    # THE CORNER UNDER THE SAND. Where the plate's earth band meets the water the pile's own
    # stones may stop short of the edge and leave the band's straight cut showing. Three
    # stones on the corner itself, drawn last, so the band always ends in rock.
    cut = edge_of(None)
    for k in range(3):
        r = rng.uniform(8.0, 11.0)
        cy = first_row + 4.0 + k * rng.uniform(9.0, 12.0)
        cx = cut + (r * 0.35 if facing_right else -r * 0.35) + rng.uniform(-1.5, 1.5)
        out.append((cx, cy, r, rng.uniform(0, 2 * math.pi), rng.uniform(0, 2 * math.pi),
                    rng.uniform(-0.3, 0.5)))
    return out


def _paint_land(width: int, height: int, seed: int, edge_of, facing_right: bool) -> Canvas:
    import math
    tone = np.full((height, width), -9.0)
    lid = np.zeros((height, width), dtype=bool)
    grain = _noise(width, height, 3, seed + 11)
    first = (ROCK_Y - LAND_TOP) / LAND_PX - 16
    for cx, cy, r, p1, p2, shade in _boulders(width, height, seed, edge_of, facing_right, first):
        ry = r * 0.78
        for y in range(max(0, int(cy - ry * 1.3) - 1), min(height, int(cy + ry * 1.3) + 2)):
            depth = max(0.0, (LAND_TOP + y * LAND_PX - ROCK_Y) / float(LAND_BOTTOM - ROCK_Y))
            for x in range(max(0, int(cx - r * 1.3) - 1), min(width, int(cx + r * 1.3) + 2)):
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                angle = math.atan2(dy / ry, dx / r)
                lump = 1.0 + 0.16 * math.sin(3 * angle + p1) + 0.09 * math.sin(5 * angle + p2)
                nx, ny = dx / (r * lump), dy / (ry * lump)
                d = math.hypot(nx, ny)
                if d > 1.0:
                    continue
                # The light is from the upper left on both beaches: the island's land is its
                # own painting, not the home one flipped, so its stones are not lit backwards.
                lit = -0.55 * nx - 0.83 * ny
                v = 4.2 + shade + 1.6 * lit * (0.4 + 0.6 * d)
                if d > 0.86 and ny > 0.1:
                    v = 1.0 + shade * 0.5
                elif d > 0.8 and lit > 0.45:
                    v += 1.3
                v += 0.8 * (grain[y, x] - 0.5)
                v -= 3.2 * depth ** 1.05
                tone[y, x] = v
                lid[y, x] = ny < -0.55 and d > 0.55
    c = Canvas(width, height, seed=seed)
    rng = np.random.default_rng(seed + 3)
    for y in range(height):
        world_y = LAND_TOP + y * LAND_PX
        depth = max(0.0, (world_y - ROCK_Y) / float(LAND_BOTTOM - ROCK_Y))
        e = edge_of(y)
        for x in range(width):
            v = tone[y, x]
            if v < -5:
                inside = (x < e - 3) if facing_right else (x > e + 3)
                if world_y < BAND_Y or not inside:
                    continue  # the plate above, or the water beside
                if world_y < ROCK_Y + 36:
                    c.px(x, y, EARTH[1] if (x * 5 + y * 3) % 13 else EARTH[2])
                    continue
                v = 0.6 - 0.6 * depth  # a crevice between two stones
            if lid[y, x] and depth < 0.22 and rng.uniform() < 0.45 - depth * 1.5:
                c.px(x, y, MOSS[3] if depth < 0.08 else MOSS[2])
                continue
            _tone(c, x, y, v, CLIFF)
    return c


def _shoulder(world_y: int) -> int:
    """How far past the collision edge the sand runs, in world pixels, row by row: rounded at
    the surface, a wet face bulging a little, tucked back in as the earth band begins."""
    import math
    t = (world_y - SURFACE_Y) / float(ROCK_Y - SURFACE_Y)
    if t < 0.03:
        return 0
    bulge = 9 * math.sin(math.pi * min(1.0, (t - 0.03) / 0.5)) ** 0.8
    if t >= 0.45:
        bulge *= max(0.0, 1.0 - (t - 0.45) / 0.55)
    return int(round(bulge))


def draw_land(name: str) -> Image.Image:
    import math
    left, right, edge, facing_right, plate_x0, seed = LANDS[name]
    pixelart.PX = LAND_PX
    width = (right - left) // LAND_PX
    height = (LAND_BOTTOM - LAND_TOP) // LAND_PX
    cut = (edge - left) / LAND_PX
    base = cut + (-2 if facing_right else 2)

    def edge_of(y):
        if y is None:
            return cut
        e = base + 2.4 * math.sin(y / 13.0 + seed) + 1.3 * math.sin(y / 5.3 + 1.1)
        # In the sand plate's own rows the edge never draws back inside the plate's cut, or
        # the plate's straight edge shows beyond it.
        if LAND_TOP + y * LAND_PX < ROCK_Y + 6:
            reach = 4 + 3 * math.sin(y / 3.1)
            e = max(e, cut + reach) if facing_right else min(e, cut - reach)
        return e

    c = _paint_land(width, height, seed, edge_of, facing_right)
    out = np.array(Image.fromarray(c.buf, "RGBA").resize((width * LAND_PX, height * LAND_PX),
                                                         Image.NEAREST))
    plate = np.array(Image.open(SAND_PLATE).convert("RGBA"))
    # The sand's edge, at the plate's own resolution. Only down to the earth band: below that
    # the stones take over the corner, and the plate's pixels carried out there were a dark
    # post standing on the rock.
    for world_y in range(SURFACE_Y - 2, BAND_Y):
        row, y = world_y - PLATE_TOP, world_y - LAND_TOP
        if not (0 <= row < plate.shape[0] and 0 <= y < out.shape[0]):
            continue
        reach = _shoulder(world_y)
        for k in range(-12, reach + 1):
            world_x = edge + k if facing_right else edge - 1 - k
            x = world_x - left
            if not 0 <= x < out.shape[1]:
                continue
            inward = -k - 1 if k < 0 else k  # past the cut, the plate's pixels mirrored
            column = (edge - 1 - inward if facing_right else edge + inward) - plate_x0
            source = plate[row, column % plate.shape[1]].astype(float)
            if source[3] < 128:
                continue
            wet = 0.0 if k < -9 else 0.12 if k < -3 else 0.26 if k < reach - 2 else 0.5
            rgb = source[:3] * (1.0 - wet) + np.array([20.0, 38.0, 62.0]) * wet
            out[y, x, :3] = np.clip(rgb, 0, 255)
            out[y, x, 3] = 255
    return Image.fromarray(out, "RGBA")


LAND = {name: (lambda name=name: draw_land(name)) for name in LANDS}


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


def draw(frame: int) -> Canvas:
    # PX=3 rather than the library default of 2: this sits in a scene drawn at a much finer
    # grain than Piyesta's interiors, and at 2 the jar reads as a different game's prop.
    pixelart.PX = 3
    c = Canvas(W, H, seed=1703 + frame)

    # The glow behind it, which is the only thing that changes between frames.
    reach = [3, 4, 5][frame]
    for step in range(reach):
        tone = GLOW[max(0, 1 - step // 2)].copy()
        tone[3] = 30 - step * 5
        c.fill(4 - step, 9 - step, 12 + step * 2, 17 + step * 2, tone)

    # The jar: a straight-sided vessel, lit from the upper left.
    c.fill(5, 10, 10, 16, GLASS[2])
    # ⚠ A GRADIENT AMOUNT, NOT A CONSTANT. A flat 0.45 dithers the whole face at one rate,
    # which is a checkerboard rather than a curved surface -- the ordered dither only reads
    # as a cylinder when the mix varies across it, bright on the lit side and dark on the
    # shaded one.
    across = np.linspace(0.92, 0.08, 10)[None, :].repeat(16, axis=0)
    c.dither(5, 10, 10, 16, GLASS[1], GLASS[3], across)
    c.vline(5, 10, 16, GLASS[4])          # lit edge
    c.hline(5, 10, 10, GLASS[4])
    c.vline(14, 10, 16, GLASS[0])         # shaded edge
    c.hline(5, 25, 10, GLASS[0])

    # The cap, and the neck under it.
    c.fill(6, 6, 8, 4, CAP[2])
    c.hline(6, 6, 8, CAP[3])
    c.hline(6, 9, 8, CAP[0])
    c.fill(7, 4, 6, 2, CAP[1])

    # The drop on the front, brighter as the glow swells.
    lit = DROP[min(3, 2 + frame // 2)]
    c.fill(9, 15, 2, 5, lit)
    c.fill(8, 17, 4, 3, lit)
    c.px(8, 16, DROP[1])
    c.px(11, 16, DROP[1])
    c.px(9, 14, DROP[3])

    # A few motes rising off it, so a still prop still has something happening.
    c.speckle(6, 2 + frame, 8, 4, GLOW[3], 0.07)
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
    # The two booms it was dragged up on, lying beside it on the sand.
    for x in range(left + 4, right - 6):
        c.px(x, sand + 2, BAMBOO[2])
        c.px(x, sand + 3, BAMBOO[0])
    c.speckle(left + 5, sand - 8, right - left - 12, 7, HULL[1], 0.07)
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
    for table in (LAND, SEABED_ART, BANGKA, FOUND):
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
        [OUT / name for name in LAND] + [OUT / name for name in SEABED_ART] + \
        [OUT / name for name in BANGKA] + \
        [OUT / name for name in FOUND] + \
        [OUT / f"{name}_{frame}.png" for name, (_p, n) in LIFE.items() for frame in range(n)]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

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
