#!/usr/bin/env python3
"""Author what Dagat needs and the delivery does not contain: the ink jar on the seabed, and
the rock the land stands on under the water.

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

# --- The shelf: what the land stands on, under the water ----------------------------------
#
# The sand plate stops 150 pixels under the surface the apo walks on, and the sea goes down
# a thousand more. Under the beach there was nothing painted at all -- the deep's ruins showed
# through beneath the sand, and the collision under it was an air pocket a swimmer could get
# into and not out of. The land now goes down to the seabed, and this is what it looks like
# on the way: the sand plate's own earth band at the top, turning into the deep's rock, with a
# ragged face where it meets the water.
#
# ⚠ BLOCKS, NOT A GRADIENT WITH SPOTS ON IT. The first version was a smooth dither from earth
# to rock with round boulders scattered through it and ruled strata across it, and under the
# water it read as a dark wall with polka dots -- a slab, not a place. The painted terraces the
# diver swims past are built of rock BLOCKS: irregular courses, a near-black crevice between
# every two, each block lit along its upper-left rim and falling into shadow on its lower-right,
# moss on the tops nearest the light. So is this now, cell by cell, in their colours.
#
# ⚠ AND NOTHING STICKS OUT OF THE FACE THAT IS NOT PART OF IT. The face had five thin lit
# ledges jutting out of it with weed hanging off them, which at game scale read as five small
# platforms floating beside the land -- the "parts that are not connected". What the face has
# now is its own bulges, lit and mossed on top where they face the light: rock that is the wall.
#
# Colours are read off the delivered plates, not chosen: EARTH is the sand plate's last rows,
# ROCK the terraces' cliff (crevice, faces, and the lit rims of its blocks), MOSS the green on
# its ledges.
EARTH = ramp(["#181c2c", "#202838", "#282838"])
ROCK = ramp(["#000820", "#001030", "#001838", "#002048", "#102850", "#203858"])
MOSS = ramp(["#183c34", "#205838", "#2e6a3e"])
SHELF_W, SHELF_H = 160, 384
FACE_W = 46
# ⚠ THE LIP: the 151 rows of the SAND PLATE the face used to start below. The face was pinned
# at the plate's last row, so it dressed the land's seaward edge only from there down -- and
# the sand above it, from the surface the apo walks on to that row, was still cut off with a
# ruled vertical line. These rows carry the sand plate's own colours down to its earth band,
# so the face begins where the sand does and the whole edge is ragged.
LIP_H = 51
## How far behind its own edge the lip is opaque. See draw_shelf_face.
LIP_DEPTH = 15
# Read off the sand plate: its lit surface, the shaded body under it, wet sand, and the earth
# band that the shelf's own first rows already match.
SAND = ramp(["#6f5141", "#be9564", "#e6b775", "#f0c888", "#f7dba6"])
LIP_STOPS = [(0, SAND[3]), (14, SAND[3]), (24, SAND[2]), (34, SAND[1]),
             (40, SAND[0]), (50, EARTH[1])]
## Rows of packed earth at the top before any rock shows, then rows over which the rock takes
## over. The earth's first row is the sand plate's last, which is the only place they touch.
EARTH_ROWS, EARTH_BLEND = 10, 26
## The size of a block, in logical pixels: wider than tall, so they lie in courses.
BLOCK = (19, 12)
## Where the face's edge sits, from its left, and the columns at its landward side that
## dither away into the fill behind it (so there is no seam where the two textures meet).
FACE_BASE, FACE_FEATHER = FACE_W - 20, 6


def BAYER_AT(x: int, y: int) -> float:
    return float(pixelart.BAYER[y % 4, x % 4])


def _blocks(width: int, height: int, seed: int, wrap: bool):
    """Voronoi blocks on a jittered, brick-offset grid. Returns, per pixel: which block it is
    in, how far it is from the nearest edge of that block (0 on the crevice), and which way it
    lies from the block's middle (for the lit rim and the shadow side)."""
    rng = np.random.default_rng(seed)
    bw, bh = BLOCK
    seeds = []
    for r in range(-1, height // bh + 2):
        shift = (r % 2) * bw * 0.5
        for q in range(-1, width // bw + 2):
            x = q * bw + shift + rng.uniform(-0.38, 0.38) * bw
            y = r * bh + rng.uniform(-0.32, 0.32) * bh
            seeds.append((x % width if wrap else x, y))
    seeds = np.array(seeds, dtype=np.float64)
    ids = np.arange(len(seeds))
    if wrap:
        # Every seed a period to either side, so a block cut by the tile's edge carries on
        # into the next tile as the same block.
        seeds = np.concatenate([seeds, seeds + [width, 0.0], seeds - [width, 0.0]])
        ids = np.concatenate([ids, ids, ids])
    cell = np.zeros((height, width), dtype=np.int64)
    gap = np.zeros((height, width), dtype=np.float64)
    toward = np.zeros((height, width, 2), dtype=np.float64)
    xs = np.arange(width, dtype=np.float64) + 0.5
    for y in range(height):
        # Stretched on x, so blocks come out wider than they are tall.
        dx = (xs[:, None] - seeds[None, :, 0]) * 0.72
        dy = (y + 0.5 - seeds[None, :, 1])
        d = np.sqrt(dx * dx + dy * dy)
        order = np.argsort(d, axis=1)[:, :2]
        near = order[:, 0]
        d1 = d[np.arange(width), near]
        d2 = d[np.arange(width), order[:, 1]]
        cell[y] = ids[near]
        gap[y] = d2 - d1
        toward[y, :, 0] = dx[np.arange(width), near]
        toward[y, :, 1] = dy[0, near]
    return cell, gap, toward, seeds[: len(seeds) // 3 if wrap else len(seeds), 1]


def _paint_rock(c: Canvas, top: int, width: int, height: int, seed: int, wrap: bool) -> None:
    """Earth, then blocks of rock, darker the deeper they sit -- because the water is."""
    cell, gap, toward, seed_y = _blocks(width, height, seed, wrap)
    rng = np.random.default_rng(seed + 1)
    tone_of = rng.uniform(0.0, 1.0, size=int(cell.max()) + 1)
    mossy = rng.uniform(0.0, 1.0, size=int(cell.max()) + 1) < 0.34
    # ⚠ THE EARTH ENDS ALONG THE BLOCKS, NOT ALONG A ROW. A dithered row-by-row change from
    # earth to rock is a ruled band across the whole land; a block is earth or rock as a whole,
    # so where one gives way to the other the line runs along crevices, the way rock shows
    # through soil.
    earth_until = rng.uniform(EARTH_ROWS, EARTH_ROWS + EARTH_BLEND, size=int(cell.max()) + 1)
    for y in range(height):
        depth = y / float(height)
        for x in range(width):
            b = BAYER_AT(x, y + top)
            k = cell[y, x]
            if y < EARTH_ROWS or seed_y[k] < earth_until[k]:
                c.px(x, y + top, EARTH[2] if (x * 5 + y * 3) % 17 == 0 else EARTH[1])
                continue
            g = gap[y, x]
            vx, vy = toward[y, x]
            length = max(0.001, float(np.hypot(vx, vy)))
            lit = (-vx - vy) / length  # +1 toward the upper left, where the light is
            if g < 1.05:
                c.px(x, y + top, ROCK[0])
                continue
            # A body tone per block, a little lighter toward its lit side, darker with depth.
            tone = 1.45 + 1.1 * tone_of[k] + 0.35 * lit
            tone *= 1.0 - 0.55 * depth
            if g < 2.4 and lit > 0.35:
                # The rim that catches the light -- moss on it near the surface.
                if mossy[k] and depth < 0.34 and vy < 0 and abs(vx) < -vy * 1.6:
                    c.px(x, y + top, MOSS[2] if depth < 0.2 else MOSS[1])
                    continue
                tone += 1.2 if depth < 0.5 else 0.8
            elif g < 2.2 and lit < -0.35:
                tone -= 0.9
            tone = max(0.0, min(4.0, tone))
            low = int(tone)
            frac = tone - low
            c.px(x, y + top, ROCK[min(5, low + 1)] if frac > b else ROCK[low])


def draw_shelf_fill() -> Canvas:
    pixelart.PX = 3
    c = Canvas(SHELF_W, SHELF_H, seed=2203)
    _paint_rock(c, 0, SHELF_W, SHELF_H, 2203, True)
    return c


def _face_edge() -> list[int]:
    """Where the face's edge is, row by row: the lip's slope into the water, then the rock's
    own irregular line, with a few bulges -- rounded, so each reads as the wall bulging and
    not as a shelf stuck to it."""
    import math
    bulges = [(62, 30, 5), (171, 38, 6), (262, 26, 4), (338, 34, 5)]
    edge = []
    for y in range(LIP_H + SHELF_H):
        e = FACE_BASE + 2.4 * math.sin(y / 15.0 + 0.4) + 1.5 * math.sin(y / 6.1 + 1.0) \
            + 0.8 * math.sin(y / 2.7)
        if y < LIP_H:
            # Sand runs further out than rock does and draws back as it wets: the lip is a
            # slope into the water, not a wall, so nothing here reads as a second cliff.
            e += (1.0 - y / float(LIP_H)) * 11.0
        else:
            for top, span, out in bulges:
                t = (y - LIP_H - top) / float(span)
                if 0.0 <= t <= 1.0:
                    e += out * math.sin(math.pi * t) ** 0.8
        edge.append(min(FACE_W - 1, int(round(e))))
    return edge


def draw_shelf_face() -> Canvas:
    """The seaward edge, facing right. Mirrored in the scene for the island, which faces left.

    ⚠ IT BEGINS AT THE SAND, NOT UNDER IT. The top LIP_H rows are the sand plate's own band,
    so the land's edge is ragged from the surface the apo stands on all the way down, instead
    of a ruled cut through the sand with a ragged rock starting under it."""
    pixelart.PX = 3
    c = Canvas(FACE_W, LIP_H + SHELF_H, seed=2207)
    _paint_rock(c, LIP_H, FACE_W, SHELF_H, 2207, False)
    for y in range(LIP_H):
        for (ya, lo), (yb, hi) in zip(LIP_STOPS, LIP_STOPS[1:]):
            if ya <= y <= yb:
                amount = 0.0 if yb == ya else (y - ya) / float(yb - ya)
                c.dither(0, y, FACE_W, 1, lo, hi, amount)
                break
    edge = _face_edge()
    for y in range(LIP_H + SHELF_H):
        e = edge[y]
        c.buf[y, e + 1:] = 0
        if y < LIP_H:
            c.px(e, y, SAND[0])
            c.px(e - 1, y, SAND[1] if (e + y) % 2 else SAND[0])
            continue
        # A right-hand face is on the shadow side: its edge is the crevice colour, and the
        # pixel inside it a step down.
        c.px(e, y, ROCK[0])
        c.px(e - 1, y, ROCK[1])
        # Where this row reaches further out than the one above it, the rock faces UP -- the
        # top of a bulge -- and takes the light, and near the surface, the moss.
        above = edge[y - 1] if y > LIP_H else e
        for x in range(above + 1, e + 1):
            depth = (y - LIP_H) / float(SHELF_H)
            c.px(x, y, MOSS[2] if depth < 0.3 else ROCK[5])
            if y + 1 < LIP_H + SHELF_H and x < edge[y + 1]:
                c.px(x, y + 1, MOSS[1] if depth < 0.3 else ROCK[4])
    # ⚠ THE LIP IS AN EDGE, NOT A SLAB. Opaque for LIP_DEPTH columns behind the edge and
    # dithered away inland of that: drawn to the full width it was a second, flatter sand
    # laid over the plate's, and the join where the two met was a straighter line than the
    # one it was put there to hide. The plate's own sand carries on behind this.
    for y in range(LIP_H):
        left = edge[y] - LIP_DEPTH
        c.buf[y, :max(0, left)] = 0
        for x in range(max(0, left), min(FACE_W, left + 6)):
            if BAYER_AT(x, y) > (x - left) / 6.0:
                c.buf[y, x] = 0
        # Wet sand darkening toward the water.
        for x in range(max(0, edge[y] - 5), edge[y]):
            if (x + y) % 3 == 0:
                c.px(x, y, SAND[1])
    for cy, cx in ((11, FACE_BASE - 8), (26, FACE_BASE - 2), (39, FACE_BASE - 13),
                   (45, FACE_BASE - 5)):
        c.px(cx, cy, SAND[0])
        c.px(cx + 1, cy, SAND[1])
        c.px(cx, cy + 1, SAND[0])
    # ⚠ AND THE ROCK FEATHERS INTO THE FILL BEHIND IT. Two textures meeting on a column read
    # as a seam however alike they are; dithered across a few columns, the blocks of one run
    # into the blocks of the other. The fill is laid far enough out to sit under all of this.
    for y in range(LIP_H, LIP_H + SHELF_H):
        for x in range(FACE_FEATHER):
            if BAYER_AT(x, y) >= (x + 0.5) / float(FACE_FEATHER):
                c.buf[y, x] = 0
    return c


SHELF = {"shelf_fill.png": draw_shelf_fill, "shelf_face.png": draw_shelf_face}


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
    """Surf running up the sand and sliding back: a strip that tiles sideways."""
    import math
    pixelart.PX = 3
    c = Canvas(48, 7, seed=3600)
    reach = [0, 1, 2][frame]
    for x in range(48):
        crest = 3 + int(round(math.sin(x * 2 * math.pi / 16.0 + frame) * 1.2)) - reach // 2
        for y in range(crest, 7):
            if (x * 7 + y * 3 + frame) % 5 == 0:
                continue
            c.px(x, y, FOAM[2] if y == crest else FOAM[1 if y < 5 else 0])
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


def build() -> list[Path]:
    OUT.mkdir(parents=True, exist_ok=True)
    written = []
    for frame in range(FRAMES):
        path = OUT / f"ink_jar_{frame}.png"
        draw(frame).save(path)
        written.append(path)
    for table in (SHELF, BANGKA):
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
        [OUT / name for name in SHELF] + [OUT / name for name in BANGKA] + \
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
