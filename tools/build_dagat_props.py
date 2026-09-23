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
# on the way: the sand plate's own earth band at the top, darkening into the deep's rock, with
# a ragged face where it meets the water and a few ledges lit the way the painted terraces are.
#
# Colours are read off the delivered plates, not chosen: EARTH is the sand plate's bottom rows,
# ROCK the terraces' body, LEDGE the terraces' lit tops.
EARTH = ramp(["#1c1e2c", "#272939", "#33354a"])
ROCK = ramp(["#040d23", "#082048", "#102850", "#183058", "#28406a"])
LEDGE = ramp(["#1f6f78", "#3fa6a0", "#8fd8c0", "#c8f0c8"])
MOSS = ramp(["#244a36", "#3a6e44"])
SHELF_W, SHELF_H = 160, 384
FACE_W = 46
# ⚠ THE LIP: the 151 rows of the SAND PLATE the face used to start below. The face was pinned
# at the plate's last row, so it dressed the land's seaward edge only from there down -- and
# the sand above it, from the surface the apo walks on to that row, was still cut off with a
# ruled vertical line. Under water and dark, but a ruled line, and the first thing anybody
# noticed about the end of the beach. These rows carry the sand plate's own colours down to
# its earth band, so the face now begins where the sand does and the whole edge is ragged.
LIP_H = 51
## How far behind its own edge the lip is opaque. See draw_shelf_face.
LIP_DEPTH = 15
# Read off the sand plate: its lit surface, the shaded body under it, wet sand, and the earth
# band that the shelf's own first stop already matches.
SAND = ramp(["#6f5141", "#be9564", "#e6b775", "#f0c888", "#f7dba6"])
LIP_STOPS = [(0, SAND[3]), (14, SAND[3]), (24, SAND[2]), (34, SAND[1]),
             (40, SAND[0]), (50, EARTH[1])]
# (row, colour) stops down the column. The first matches the sand plate's last row exactly,
# which is the only place the two pictures touch.
SHELF_STOPS = [(0, EARTH[1]), (12, EARTH[1]), (64, ROCK[3]), (150, ROCK[2]),
               (260, ROCK[1]), (383, ROCK[0])]
# Where the face juts out into a ledge, and how far: (top row, rows thick, logical px out).
LEDGES = [(66, 8, 16), (148, 6, 12), (229, 9, 18), (305, 7, 14), (354, 6, 11)]


def _shelf_row(c: Canvas, y: int, x0: int, w: int) -> None:
    for (ya, lo), (yb, hi) in zip(SHELF_STOPS, SHELF_STOPS[1:]):
        if ya <= y <= yb:
            amount = 0.0 if yb == ya else (y - ya) / float(yb - ya)
            c.dither(x0, y, w, 1, lo, hi, amount)
            return


def _step(colour: np.ndarray, by: int) -> np.ndarray:
    """The same material a step lighter (by > 0) or darker, on whichever ramp it lives on."""
    for ramp_ in (ROCK, EARTH):
        for index, value in enumerate(ramp_):
            if (value[:3] == colour[:3]).all():
                return ramp_[max(0, min(len(ramp_) - 1, index + by))]
    return colour


def _boulder(c: Canvas, cx: int, cy: int, r: int, wrap: int = 0) -> None:
    """A rounded stone the way the painted terraces draw them: a dark outline, a body lit
    from the upper left, a rim of the next step up on the lit side. Darker the deeper it is,
    because the water is."""
    import math
    depth = min(1.0, cy / float(SHELF_H))
    body_hi = ROCK[3] if depth < 0.55 else ROCK[2]
    body_lo = ROCK[2] if depth < 0.55 else ROCK[1]
    rim = ROCK[4] if depth < 0.55 else ROCK[3]
    ry = max(2.0, r * 0.78)
    for dy in range(-int(ry) - 1, int(ry) + 2):
        for dx in range(-r - 1, r + 2):
            d = math.hypot(dx / float(r), dy / ry)
            if d > 1.0:
                continue
            x = cx + dx
            if wrap:
                x %= wrap
            y = cy + dy
            if d > 0.86:
                c.px(x, y, ROCK[0])
                continue
            light = (-dx / float(r) - dy / ry) * 0.5 + 0.5
            if light > 0.78 and d > 0.55:
                c.px(x, y, rim)
            elif (light + BAYER_AT(x, y) * 0.3) > 0.62:
                c.px(x, y, body_hi)
            else:
                c.px(x, y, body_lo)


def BAYER_AT(x: int, y: int) -> float:
    return float(pixelart.BAYER[y % 4, x % 4])


def _shelf_body(c: Canvas, width: int, seed: int, wrap: bool) -> None:
    """Gradient, strata, boulders and grit. With `wrap`, all of it is periodic across the
    width so the tile meets itself at the seam."""
    import math
    for y in range(SHELF_H):
        _shelf_row(c, y, 0, width)
    rng = np.random.default_rng(seed)
    # Strata: gently wavy lines a step darker, on whole periods of the tile.
    for row in (30, 88, 141, 203, 262, 318, 360):
        phase = float(rng.uniform(0, math.tau))
        for x in range(width):
            wave = 1.6 * math.sin(math.tau * x / width + phase) \
                + 0.8 * math.sin(math.tau * 3 * x / width + phase * 2)
            y = row + int(round(wave))
            c.px(x, y, _step(c.buf[y, x].copy(), -1))
    # Grit, sparse and dark, so a flat area is not flat.
    for _ in range(width * SHELF_H // 16):
        x = int(rng.integers(0, width))
        y = int(rng.integers(0, SHELF_H))
        c.px(x, y, _step(c.buf[y, x].copy(), -1))
    # Boulders set into the face of it, fewer near the top where it is still packed earth.
    for _ in range(width * SHELF_H // 900):
        r = int(rng.integers(3, 8))
        cy = int(rng.integers(40, SHELF_H - r - 2))
        cx = int(rng.integers(0, width))
        _boulder(c, cx, cy, r, width if wrap else 0)


def draw_shelf_fill() -> Canvas:
    pixelart.PX = 3
    c = Canvas(SHELF_W, SHELF_H, seed=2203)
    _shelf_body(c, SHELF_W, 2203, True)
    return c


def draw_shelf_face() -> Canvas:
    """The seaward edge, facing right. Mirrored in the scene for the island, which faces left.

    A ragged edge with a few ledges jutting out of it, each lit on its top the way the
    painted terraces are -- teal going to near-white -- with weed hanging off the lip and the
    underside cut back, so it reads as a shelf a thing could rest on rather than a notch.

    ⚠ IT BEGINS AT THE SAND, NOT UNDER IT. The top LIP_H rows are the sand plate's own band,
    so the land's edge is ragged from the surface the apo stands on all the way down, instead
    of a ruled cut through the sand with a ragged rock starting under it."""
    import math
    pixelart.PX = 3
    c = Canvas(FACE_W, LIP_H + SHELF_H, seed=2207)
    body = Canvas(FACE_W, SHELF_H, seed=2207)
    _shelf_body(body, FACE_W, 2207, False)
    c.buf[LIP_H:] = body.buf
    for y in range(LIP_H):
        for (ya, lo), (yb, hi) in zip(LIP_STOPS, LIP_STOPS[1:]):
            if ya <= y <= yb:
                amount = 0.0 if yb == ya else (y - ya) / float(yb - ya)
                c.dither(0, y, FACE_W, 1, lo, hi, amount)
                break
    base = FACE_W - 20
    edge = []
    for y in range(LIP_H + SHELF_H):
        e = base + int(round(2.6 * math.sin(y / 13.0) + 1.6 * math.sin(y / 5.7 + 1.0)
                             + 1.0 * math.sin(y / 2.3)))
        if y < LIP_H:
            # Sand runs further out than rock does and draws back as it wets: the lip is a
            # slope into the water, not a wall, so nothing here reads as a second cliff.
            e += int(round((1.0 - y / float(LIP_H)) * 11.0))
        for top, thick, out in LEDGES:
            if top + LIP_H <= y < top + LIP_H + thick:
                # Full reach for the top rows, cut back underneath.
                cut = max(0, (y - top - LIP_H) - 2) * out // max(1, thick)
                e = max(e, base + out - cut - 1)
        edge.append(min(FACE_W - 1, e))
    for y in range(LIP_H + SHELF_H):
        c.buf[y, edge[y] + 1:] = 0
        # A right-hand face is on the shadow side: its edge carries the step down.
        c.px(edge[y], y, ROCK[0] if y >= LIP_H else SAND[0])
        c.px(edge[y] - 1, y, _step(c.buf[y, edge[y] - 1].copy(), -1))
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
    for cy, cx in ((11, base - 8), (26, base - 2), (39, base - 13), (45, base - 5)):
        c.px(cx, cy, SAND[0])
        c.px(cx + 1, cy, SAND[1])
        c.px(cx, cy + 1, SAND[0])
    # The slab of each ledge, a step lighter than the wall behind it so it reads as rock
    # standing out of the face rather than a line drawn on it, outlined underneath.
    for top_row, thick, out in LEDGES:
        top = top_row + LIP_H
        for y in range(top, top + thick):
            for x in range(base - 4, edge[y] + 1):
                slab = ROCK[3] if (x + y) % 4 else ROCK[2]
                if y >= top + thick - 2 or x == edge[y]:
                    slab = ROCK[1]
                c.px(x, y, slab)
            c.px(edge[y], y, ROCK[0])
        for x in range(base - 2, edge[top + thick - 1] + 1):
            c.px(x, top + thick, ROCK[0])
    for top_row, thick, out in LEDGES:
        top = top_row + LIP_H
        lip = edge[top]
        x0 = base - 6
        for x in range(x0, lip + 1):
            c.px(x, top, LEDGE[3] if x > x0 + 4 else LEDGE[2])
            c.px(x, top + 1, LEDGE[1] if x > x0 + 2 else LEDGE[0])
        # A boulder sitting on the ledge, half the time.
        if (top_row // 7) % 2 == 0:
            _boulder(c, lip - 5, top - 3, 3)
            for x in range(lip - 8, lip - 1):
                c.px(x, top, LEDGE[2])
        # Weed hanging off the lip.
        for x in range(base + 1, lip, 3):
            length = 2 + (x * 7 + top_row) % 4
            for dy in range(length):
                c.px(x, top + thick + 1 + dy, MOSS[1] if dy < length - 1 else MOSS[0])
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
