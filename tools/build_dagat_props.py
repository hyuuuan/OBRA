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
    underside cut back, so it reads as a shelf a thing could rest on rather than a notch."""
    import math
    pixelart.PX = 3
    c = Canvas(FACE_W, SHELF_H, seed=2207)
    _shelf_body(c, FACE_W, 2207, False)
    base = FACE_W - 20
    edge = []
    for y in range(SHELF_H):
        e = base + int(round(2.6 * math.sin(y / 13.0) + 1.6 * math.sin(y / 5.7 + 1.0)
                             + 1.0 * math.sin(y / 2.3)))
        for top, thick, out in LEDGES:
            if top <= y < top + thick:
                # Full reach for the top rows, cut back underneath.
                cut = max(0, (y - top) - 2) * out // max(1, thick)
                e = max(e, base + out - cut - 1)
        edge.append(min(FACE_W - 1, e))
    for y in range(SHELF_H):
        c.buf[y, edge[y] + 1:] = 0
        # A right-hand face is on the shadow side: its edge carries the step down.
        c.px(edge[y], y, ROCK[0])
        c.px(edge[y] - 1, y, _step(c.buf[y, edge[y] - 1].copy(), -1))
    # The slab of each ledge, a step lighter than the wall behind it so it reads as rock
    # standing out of the face rather than a line drawn on it, outlined underneath.
    for top, thick, out in LEDGES:
        for y in range(top, top + thick):
            for x in range(base - 4, edge[y] + 1):
                slab = ROCK[3] if (x + y) % 4 else ROCK[2]
                if y >= top + thick - 2 or x == edge[y]:
                    slab = ROCK[1]
                c.px(x, y, slab)
            c.px(edge[y], y, ROCK[0])
        for x in range(base - 2, edge[top + thick - 1] + 1):
            c.px(x, top + thick, ROCK[0])
    for top, thick, out in LEDGES:
        lip = edge[top]
        x0 = base - 6
        for x in range(x0, lip + 1):
            c.px(x, top, LEDGE[3] if x > x0 + 4 else LEDGE[2])
            c.px(x, top + 1, LEDGE[1] if x > x0 + 2 else LEDGE[0])
        # A boulder sitting on the ledge, half the time.
        if (top // 7) % 2 == 0:
            _boulder(c, lip - 5, top - 3, 3)
            for x in range(lip - 8, lip - 1):
                c.px(x, top, LEDGE[2])
        # Weed hanging off the lip.
        for x in range(base + 1, lip, 3):
            length = 2 + (x * 7 + top) % 4
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


LIFE = {
    "gull": (_gull, 4),
    "jelly": (_jelly, 4),
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


def build() -> list[Path]:
    OUT.mkdir(parents=True, exist_ok=True)
    written = []
    for frame in range(FRAMES):
        path = OUT / f"ink_jar_{frame}.png"
        draw(frame).save(path)
        written.append(path)
    for name, painter in SHELF.items():
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
        [OUT / name for name in SHELF] + \
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
