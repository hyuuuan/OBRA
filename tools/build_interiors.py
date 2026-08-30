#!/usr/bin/env python3
"""Author Piyesta's interior materials as original 8-bit pixel art.

WHY THIS EXISTS
---------------
The four insides were first hand-drawn with `draw_rect` -- flat bands of colour -- and then,
correcting that, tiled straight out of `TextureMap_Piyesta`. Both were wrong, and the second
was wrong in a way that matters more: that sheet is the PLAZA's material. Its walls are
mossy rubble with grass growing out of the top and its ground is packed earth, because they
are the outside of a town. Tiling them into a church nave puts moss and dirt on the inside
of a building that has neither, and into a house puts a garden wall in somebody's front room.

So this authors the interiors instead. The delivered art is the reference -- its palette
range, its light from the left, its density of detail -- and nothing here is copied from it.

WHAT 8-BIT MEANS HERE, CONCRETELY
---------------------------------
Everything is drawn on a LOGICAL PIXEL GRID and scaled up by `PX` with nearest-neighbour, so
every mark in the output is a hard square block of pixels and nothing is ever antialiased.
Colour comes from short ramps -- five or six steps per material, no more -- and gradients are
made with an ordered Bayer dither between two adjacent steps rather than by interpolating,
which is the difference between pixel art and a photograph of pixel art.

Light is from the UPPER LEFT everywhere, matching the plaza: the top and left edge of any
raised thing carries the next ramp step up, the bottom and right edge the next step down.

THE MATERIALS, AND WHY EACH ROOM HAS ITS OWN
-------------------------------------------
  church  dressed limestone ashlar under lime plaster, stone flag floor, timber ceiling.
          A nave is the best-built room in a town: big squared blocks, fine joints, no moss.
  house   sawali -- woven split bamboo -- in a timber frame, over a plank floor. This is a
          lowland house, not a stone one.
  alley   lime plaster over rubble, blown and fallen away in patches, damp running down it,
          granite setts underfoot with a drain down the middle. Shaded and cold.

    python3 tools/build_interiors.py [--check]
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "game" / "assets" / "Level2" / "interiors"
MANIFEST = OUT_DIR / "interiors.json"

from pixelart import PX, BAYER, Canvas, ramp   # noqa: E402  the shared 8-bit library

SEED = 20260831

# --- The palettes ------------------------------------------------------------------------
# Short ramps, darkest first. Hues are taken from the delivered plaza so these rooms belong
# to the same town; the values are chosen for material, not sampled from it.

LIMESTONE = ["#3B2C1C", "#5E472C", "#856541", "#A8845A", "#C9A87B", "#E6CCA4"]
LIME_PLASTER = ["#5A4A34", "#7E6B4C", "#A08B68", "#BFA987", "#DAC7A9", "#F0E2C8"]
FLAGSTONE = ["#2E2519", "#4A3D2A", "#6B5A41", "#8A775B", "#A79479", "#C2B199"]
TIMBER = ["#2A1A0C", "#452C15", "#653F1E", "#87582C", "#A8763F", "#C79A5E"]
SAWALI = ["#4A3818", "#6E5325", "#957336", "#B8964C", "#D4B672", "#EBD79B"]
PLASTER_COLD = ["#20262A", "#33393C", "#4A5051", "#636866", "#7D817B", "#989B90"]
RUBBLE = ["#171B1E", "#262B2E", "#383D3F", "#4B5052", "#5E6262"]
SETT = ["#191B1F", "#272A2E", "#383B3E", "#4A4D4F", "#5D5F60", "#71716F"]
IRON = ["#14161A", "#23262B", "#363A40", "#4C5058"]
GILT = ["#4A3208", "#7A5410", "#A87C1E", "#D4A63A", "#F0D06E"]
CANDLE = ["#8A7A54", "#C4B48A", "#E8DCB8", "#F6EFD6"]
FLAME = ["#8A4A08", "#D48A18", "#F0C24A", "#FFF0B0"]
GLASS = ["#3A5A6A", "#5E88A0", "#8FB8CC", "#C4E0EC"]
DAY = ["#A8763F", "#D4A96C", "#EBCF9A", "#F8ECC8"]


def ramp(hexes: list[str]) -> np.ndarray:
    out = np.zeros((len(hexes), 4), dtype=np.uint8)
    for index, value in enumerate(hexes):
        out[index] = [int(value[1:3], 16), int(value[3:5], 16), int(value[5:7], 16), 255]
    return out


# --- Materials ---------------------------------------------------------------------------

def ashlar(c: Canvas, pal: np.ndarray, course: int = 14, block: int = 30) -> None:
    """Dressed stone: big squared blocks, fine joints, lit from the upper left.

    A nave is the best-built room in a town, so the blocks are large and regular and the
    joints are one pixel. What stops it reading as a grid is that no two blocks share a tone
    and the wear is per-block rather than per-wall.
    """
    c.fill(0, 0, c.w, c.h, pal[1])
    row = 0
    y = 0
    while y < c.h:
        offset = 0 if row % 2 == 0 else block // 2
        x = -offset
        while x < c.w:
            tone = pal[3 + int(c.rng.integers(0, 2))]
            c.fill(x + 1, y + 1, block - 1, course - 1, tone)
            # Light from the upper left: a highlight along the top and left of every block,
            # a shadow along the bottom and right.
            c.hline(x + 1, y + 1, block - 1, pal[min(5, 4 + int(c.rng.integers(0, 2)))])
            c.vline(x + 1, y + 1, course - 1, pal[4])
            c.hline(x + 1, y + course - 1, block - 1, pal[2])
            c.vline(x + block - 1, y + 1, course - 1, pal[2])
            # Wear: a few darker grains, and now and then a chipped corner.
            c.speckle(x + 2, y + 2, max(1, block - 4), max(1, course - 3), pal[2], 0.03)
            if c.rng.random() < 0.16:
                c.fill(x + block - 4, y + course - 4, 3, 3, pal[1])
            x += block
        y += course
        row += 1


def plaster(c: Canvas, pal: np.ndarray, warm: bool = True) -> None:
    """Lime plaster: mottled, not flat, with hairline cracks and a settled tone."""
    c.fill(0, 0, c.w, c.h, pal[3])
    # Large soft patches, dithered between two steps so the variation is pixel art rather
    # than noise.
    for _ in range(7):
        w = int(c.rng.integers(c.w // 4, c.w))
        h = int(c.rng.integers(c.h // 5, c.h // 2))
        x = int(c.rng.integers(-w // 3, c.w))
        y = int(c.rng.integers(-h // 3, c.h))
        up = c.rng.random() < 0.5
        c.dither(max(0, x), max(0, y), min(w, c.w - max(0, x)), min(h, c.h - max(0, y)),
                 pal[3], pal[4] if up else pal[2], 0.45)
    c.speckle(0, 0, c.w, c.h, pal[2], 0.02)
    for _ in range(2):
        x = int(c.rng.integers(4, c.w - 4))
        y = 0
        while y < c.h:
            c.px(x, y, pal[1])
            x += int(c.rng.integers(-1, 2))
            y += 1


def plaster_over_rubble(c: Canvas, pal: np.ndarray, stone: np.ndarray) -> None:
    """An alley wall: rendered once, long ago, and falling off.

    The patches where it has gone are what make this read as a back street rather than as a
    corridor -- and they are why the alleys must not be the plaza's mossy garden wall.
    """
    plaster(c, pal)
    # Blown render, showing the rubble behind it.
    for _ in range(5):
        w = int(c.rng.integers(10, 26))
        h = int(c.rng.integers(8, 20))
        x = int(c.rng.integers(0, max(1, c.w - w)))
        y = int(c.rng.integers(0, max(1, c.h - h)))
        c.fill(x, y, w, h, stone[1])
        # Rubble is small and irregular; the mortar between it is the darkest step.
        sy = y
        while sy < y + h:
            sx = x + int(c.rng.integers(0, 3))
            while sx < x + w:
                bw = int(c.rng.integers(3, 7))
                bh = int(c.rng.integers(3, 5))
                c.fill(sx, sy, min(bw, x + w - sx), min(bh, y + h - sy),
                       stone[2 + int(c.rng.integers(0, 2))])
                c.hline(sx, sy, min(bw, x + w - sx), stone[min(4, 3)])
                sx += bw + 1
            sy += bh + 1
        # A lip of plaster around the hole, brighter where it has broken away.
        c.hline(x, y - 1, w, pal[5])
        c.vline(x - 1, y, h, pal[5])
    # Damp running down from the top: this is the one thing that says "shaded and cold".
    for _ in range(6):
        x = int(c.rng.integers(0, c.w))
        h = int(c.rng.integers(c.h // 3, c.h))
        w = int(c.rng.integers(1, 4))
        c.dither(x, 0, min(w, c.w - x), h, pal[3], pal[1], 0.55)


def sawali(c: Canvas, pal: np.ndarray, timber: np.ndarray) -> None:
    """Woven split bamboo in a timber frame -- what a lowland house is walled with.

    The weave is the whole material: strips passing over and under, so the tone alternates on
    a checker of the strip width and each strip carries a lit edge where it rides over.
    """
    strip = 4
    c.fill(0, 0, c.w, c.h, pal[2])
    for y in range(0, c.h, strip):
        for x in range(0, c.w, strip):
            over = ((x // strip) + (y // strip)) % 2 == 0
            tone = pal[4] if over else pal[2]
            c.fill(x, y, strip, strip, tone)
            if over:
                # The strip riding over catches the light along its upper edge.
                c.hline(x, y, strip, pal[5])
                c.vline(x, y, strip, pal[5])
            else:
                c.hline(x, y + strip - 1, strip, pal[1])
    c.speckle(0, 0, c.w, c.h, pal[1], 0.015)
    # The frame: a squared post every so often, which is what the panels are held in. The
    # spacing is drawn from the stream so the three variants do not line their posts up.
    step = 26 + int(c.rng.integers(0, 3)) * 6
    for x in range(int(c.rng.integers(0, 8)), c.w, step):
        c.fill(x, 0, 5, c.h, timber[2])
        c.vline(x, 0, c.h, timber[4])
        c.vline(x + 4, 0, c.h, timber[1])


def flagstones(c: Canvas, pal: np.ndarray) -> None:
    """A church floor: big square flags, worn hollow in the middle, dark in the joints."""
    flag = 22
    c.fill(0, 0, c.w, c.h, pal[0])
    for y in range(0, c.h, flag):
        for x in range(0, c.w, flag):
            tone = pal[2 + int(c.rng.integers(0, 2))]
            c.fill(x + 1, y + 1, flag - 1, flag - 1, tone)
            # Worn: brighter toward the middle of the flag, dithered outward.
            c.dither(x + 4, y + 4, flag - 7, flag - 7, tone, pal[4], 0.4)
            c.hline(x + 1, y + 1, flag - 1, pal[4])
            c.vline(x + 1, y + 1, flag - 1, pal[3])
            c.speckle(x + 2, y + 2, flag - 3, flag - 3, pal[1], 0.02)


def boards(c: Canvas, pal: np.ndarray, height: int = 9) -> None:
    """A plank floor, seen at a shallow angle: long boards, grain, and the odd knot."""
    c.fill(0, 0, c.w, c.h, pal[1])
    for y in range(0, c.h, height):
        tone = pal[2 + int(c.rng.integers(0, 2))]
        c.fill(0, y, c.w, height - 1, tone)
        c.hline(0, y, c.w, pal[4])
        c.hline(0, y + height - 2, c.w, pal[1])
        for _ in range(c.w // 12):
            gx = int(c.rng.integers(0, c.w))
            gw = int(c.rng.integers(4, 14))
            c.hline(gx, y + int(c.rng.integers(2, max(3, height - 3))), gw, pal[1])
        if c.rng.random() < 0.4:
            kx = int(c.rng.integers(2, max(3, c.w - 4)))
            ky = y + height // 2
            c.fill(kx, ky - 1, 3, 2, pal[0])
            c.px(kx + 1, ky - 2, pal[1])


def setts(c: Canvas, pal: np.ndarray) -> None:
    """Granite setts: small, irregular, and wet enough to catch a highlight."""
    c.fill(0, 0, c.w, c.h, pal[0])
    y = 0
    row = 0
    while y < c.h:
        x = -int(c.rng.integers(0, 5)) - (3 if row % 2 else 0)
        while x < c.w:
            w = int(c.rng.integers(6, 10))
            h = 6
            tone = pal[2 + int(c.rng.integers(0, 3))]
            c.fill(x + 1, y + 1, w - 1, h - 1, tone)
            c.hline(x + 1, y + 1, w - 1, pal[5])
            c.hline(x + 1, y + h - 1, w - 1, pal[1])
            x += w
        y += h
        row += 1


# --- The pieces --------------------------------------------------------------------------

## ⚠ THREE OF EVERY WALL, BECAUSE ONE TILE REPEATED IS A GRID.
##
## A single 64x64 wall tiled across a nine-metre alley puts the same fallen patch of render
## and the same damp streak at the same interval the whole way along, and the eye finds that
## rhythm before it finds the material. Three variants, each drawn from a different point in
## the same seeded stream, and the room picks between them per tile -- so the wall repeats
## every twelve metres instead of every one and a half, which at this camera is never.
WALL_VARIANTS = 5


def _wall(name: str, kind: str, tiles: dict) -> None:
    for variant in range(WALL_VARIANTS):
        c = Canvas(64, 64)
        # Advance the stream so each variant is a different piece of wall rather than the
        # same one three times.
        c.rng = np.random.default_rng(SEED + variant * 977)
        if kind == "church":
            ashlar(c, ramp(LIMESTONE))
        elif kind == "church_upper":
            plaster(c, ramp(LIME_PLASTER))
        elif kind == "house":
            sawali(c, ramp(SAWALI), ramp(TIMBER))
        else:
            plaster_over_rubble(c, ramp(PLASTER_COLD), ramp(RUBBLE))
        key = "%s_%s" % (name, "abcde"[variant])
        tiles[key] = _emit(c, key)


def _floor(name: str, kind: str, tiles: dict) -> None:
    c = Canvas(64, 32)
    if kind == "church":
        flagstones(c, ramp(FLAGSTONE))
    elif kind == "house":
        boards(c, ramp(TIMBER))
    else:
        setts(c, ramp(SETT))
    tiles[name] = _emit(c, name)


def _ceiling(name: str, kind: str, tiles: dict) -> None:
    """Beams with something between them. A room with no ceiling is an open-topped pit."""
    c = Canvas(64, 26)
    wood = ramp(TIMBER)
    if kind == "church":
        c.fill(0, 0, c.w, c.h, ramp(LIME_PLASTER)[1])
        c.dither(0, 0, c.w, c.h, ramp(LIME_PLASTER)[1], ramp(LIME_PLASTER)[2], 0.4)
    else:
        # Nipa: the underside of a thatched roof, bundles lashed across.
        straw = ramp(SAWALI)
        c.fill(0, 0, c.w, c.h, straw[1])
        for y in range(0, c.h, 4):
            c.hline(0, y, c.w, straw[3])
            c.hline(0, y + 1, c.w, straw[2])
            c.speckle(0, y, c.w, 3, straw[0], 0.06)
    # ⚠ THE BEAMS ARE SLIM AND THE PANELS BETWEEN THEM ARE WIDE. The first cut had nine-pixel
    # beams every twenty-one, which is more timber than ceiling -- it read as a fence seen
    # end-on rather than as something over your head.
    for x in range(0, c.w, 26):
        c.fill(x, 0, 5, c.h, wood[2])
        c.vline(x, 0, c.h, wood[4])
        c.vline(x + 4, 0, c.h, wood[0])
        # The shadow a beam throws on the panel beside it is what gives a ceiling depth.
        c.dither(x + 5, 0, 5, c.h, wood[0], wood[1], 0.45)
    # A wall plate along the bottom, where the ceiling meets the wall head.
    c.hline(0, c.h - 4, c.w, wood[3])
    c.hline(0, c.h - 3, c.w, wood[1])
    c.fill(0, c.h - 2, c.w, 2, wood[0])
    tiles[name] = _emit(c, name)


def _church_window(tiles: dict) -> None:
    """A tall arched window with tracery, and the day pouring through it."""
    c = Canvas(40, 74)
    stone = ramp(LIMESTONE)
    glass = ramp(GLASS)
    day = ramp(DAY)
    c.fill(0, 0, c.w, c.h, stone[2])
    # The arched opening: a rectangle with a semicircular head, cut by hand so the curve is
    # made of steps rather than of a smooth line.
    for y in range(c.h):
        if y < 16:
            half = int((1.0 - ((16 - y) / 16.0) ** 2) ** 0.5 * 13)
        else:
            half = 13
        if half <= 0:
            continue
        c.fill(20 - half, y + 4, half * 2, 1, glass[1])
    # Light in the glass, brightest at the head where the sun is. WARM ALL THE WAY DOWN:
    # the first version left the lower panes blue against a warm head, which read as two
    # different windows stacked.
    c.dither(7, 6, 26, 60, day[1], day[2], 0.5)
    c.dither(7, 6, 26, 30, day[2], day[3], 0.6)
    # Tracery: one mullion and two transoms, in the same stone as the jamb.
    c.fill(19, 8, 2, 62, stone[3])
    for y in [26, 46]:
        c.fill(7, y, 26, 2, stone[3])
    # The reveal: the jamb is deeper on the shadowed side.
    c.vline(6, 6, 64, stone[1])
    c.vline(33, 6, 64, stone[4])
    c.hline(6, 69, 28, stone[1])
    tiles["church_window"] = _emit(c, "church_window")


def _house_window(tiles: dict) -> None:
    """A capiz shutter: squares of shell in a wooden lattice, glowing where the sun is."""
    c = Canvas(44, 36)
    wood = ramp(TIMBER)
    shell = ramp(CANDLE)
    c.fill(0, 0, c.w, c.h, wood[2])
    for row in range(3):
        for col in range(4):
            x = 3 + col * 10
            y = 3 + row * 10
            c.fill(x, y, 8, 8, shell[1])
            c.dither(x, y, 8, 8, shell[1], shell[2], 0.45)
            c.hline(x, y, 8, shell[3])
    c.hline(0, 0, c.w, wood[4])
    c.hline(0, c.h - 1, c.w, wood[0])
    tiles["house_window"] = _emit(c, "house_window")


def _pew(tiles: dict) -> None:
    """A church bench, from the side: a real back, a seat, and squared ends.

    The first version had a three-pixel back and read as a table, which put dining furniture
    down the nave.
    """
    c = Canvas(56, 34)
    wood = ramp(TIMBER)
    # The back: tall, panelled, and the tallest thing on the piece.
    c.fill(0, 0, c.w, 13, wood[2])
    c.hline(0, 0, c.w, wood[4])
    c.hline(0, 12, c.w, wood[0])
    for x in range(4, c.w - 4, 13):
        c.fill(x, 3, 9, 7, wood[1])
        c.hline(x, 3, 9, wood[3])
    # The seat, standing proud of the back.
    c.fill(0, 14, c.w, 5, wood[3])
    c.hline(0, 14, c.w, wood[5])
    c.hline(0, 18, c.w, wood[0])
    # Squared ends down to the floor, with a rail between them.
    for x in [1, c.w - 6]:
        c.fill(x, 19, 5, c.h - 19, wood[2])
        c.vline(x, 19, c.h - 19, wood[4])
        c.vline(x + 4, 19, c.h - 19, wood[0])
    c.fill(6, c.h - 8, c.w - 12, 3, wood[1])
    tiles["pew"] = _emit(c, "pew")


def _candle_rack(tiles: dict) -> None:
    c = Canvas(46, 34)
    iron = ramp(IRON)
    wax = ramp(CANDLE)
    flame = ramp(FLAME)
    c.fill(0, 12, c.w, 3, iron[2])
    c.hline(0, 12, c.w, iron[3])
    for x in [3, c.w - 6]:
        c.fill(x, 15, 3, c.h - 15, iron[1])
    for index in range(7):
        x = 4 + index * 6
        height = 6 + (index * 3) % 5
        c.fill(x, 12 - height, 3, height, wax[1])
        c.vline(x, 12 - height, height, wax[2])
        if index % 2 == 0:
            c.px(x + 1, 12 - height - 2, flame[2])
            c.px(x + 1, 12 - height - 1, flame[1])
    tiles["candle_rack"] = _emit(c, "candle_rack")


def _altar(tiles: dict) -> None:
    """The altar and the retablo over it: stone table, gilded timber, a niche."""
    c = Canvas(96, 120)
    stone = ramp(LIMESTONE)
    wood = ramp(TIMBER)
    gilt = ramp(GILT)
    # The retablo: three bays, columns between them, a crowned cornice.
    c.fill(14, 0, 68, 92, wood[1])
    for bay in range(3):
        x = 18 + bay * 22
        c.fill(x, 8, 16, 76, wood[1])
        c.dither(x, 8, 16, 76, wood[1], wood[2], 0.4)
        # An arched head to each bay, so the retablo is joinery and not three dark slots.
        for y in range(10):
            half = int((1.0 - ((10 - y) / 10.0) ** 2) ** 0.5 * 8)
            if half > 0:
                c.fill(x + 8 - half, y + 8, half * 2, 1, wood[0])
    # THE SANTO IN THE MIDDLE BAY. A retablo without a figure in it is a bookcase -- and this
    # is the one thing in the room the cultural guardrail is about, so it has to be legible
    # enough that nobody mistakes it for scenery.
    robe = ramp(GILT)
    skin = ramp(CANDLE)
    c.fill(44, 34, 12, 30, ramp(TIMBER)[0])
    c.fill(45, 36, 10, 26, robe[1])
    c.vline(45, 36, 26, robe[3])
    c.fill(47, 28, 6, 7, skin[2])
    for y in range(6):
        half = int((1.0 - ((6 - y) / 6.0) ** 2) ** 0.5 * 7)
        if half > 0:
            c.fill(50 - half, 24 + y, half * 2, 1, robe[4])
    for col in range(4):
        x = 14 + col * 22
        c.fill(x, 4, 5, 86, gilt[2])
        c.vline(x, 4, 86, gilt[4])
        c.vline(x + 4, 4, 86, gilt[0])
    c.fill(10, 0, 76, 6, gilt[3])
    c.hline(10, 0, 76, gilt[4])
    # The altar table beneath it, and its cloth.
    c.fill(6, 92, 84, 20, stone[3])
    c.hline(6, 92, 84, stone[5])
    c.fill(2, 96, 92, 7, ramp(CANDLE)[2])
    c.hline(2, 96, 92, ramp(CANDLE)[3])
    c.fill(6, 112, 84, 8, stone[2])
    tiles["altar"] = _emit(c, "altar")


def _table(tiles: dict) -> None:
    """A low wooden table. What the candle is standing on in the lit house."""
    c = Canvas(52, 30)
    wood = ramp(TIMBER)
    c.fill(0, 0, c.w, 6, wood[3])
    c.hline(0, 0, c.w, wood[5])
    c.hline(0, 5, c.w, wood[1])
    c.fill(1, 6, c.w - 2, 3, wood[1])
    for x in [4, c.w - 9]:
        c.fill(x, 9, 5, c.h - 9, wood[2])
        c.vline(x, 9, c.h - 9, wood[4])
        c.vline(x + 4, 9, c.h - 9, wood[0])
    c.fill(9, c.h - 9, c.w - 18, 3, wood[1])
    tiles["table"] = _emit(c, "table")


def _kandila(tiles: dict) -> None:
    """The candle itself, on its brass stand. Two frames: unlit, and burning.

    ⚠ IT IS THE ONE THING PROBLEM 1 IS ABOUT, so it is drawn to be found across a room --
    tall for its width, pale against everything else, and the lit one throws a halo.
    """
    for lit in [False, True]:
        c = Canvas(18, 40)
        wax = ramp(CANDLE)
        brass = ramp(GILT)
        flame = ramp(FLAME)
        c.fill(4, 34, 10, 4, brass[2])
        c.hline(4, 34, 10, brass[4])
        c.hline(4, 37, 10, brass[0])
        c.fill(6, 30, 6, 4, brass[1])
        c.fill(6, 8, 6, 22, wax[1])
        c.vline(6, 8, 22, wax[2])
        c.vline(11, 8, 22, wax[0])
        c.hline(6, 8, 6, wax[3])
        # A drip down one side, which is what makes a rectangle read as wax.
        c.fill(11, 14, 1, 7, wax[2])
        if lit:
            c.px(9, 6, flame[1])
            c.fill(8, 3, 3, 3, flame[2])
            c.px(9, 1, flame[3])
            c.px(9, 2, flame[3])
        name = "kandila_lit" if lit else "kandila"
        tiles[name] = _emit(c, name)


def _santo_nino_print(tiles: dict) -> None:
    """A framed print of the Santo Nino. There is one in every Cebuano house.

    ⚠ DRAWN, NEVER BUILT. Like the retablo's image and the one in the Basilica's facade
    niche, this is part of a texture: no node, no area, no collision, nothing to interact
    with. It is there because a house in this town would have one, not as a thing to use.
    """
    c = Canvas(30, 38, SEED + 401)
    wood = ramp(TIMBER)
    gilt = ramp(GILT)
    red = ramp(FLAME)
    skin = ramp(CANDLE)
    c.fill(0, 0, c.w, c.h, wood[1])
    c.hline(0, 0, c.w, wood[3])
    c.fill(3, 3, c.w - 6, c.h - 6, gilt[0])
    c.fill(4, 4, c.w - 8, c.h - 8, ramp(LIME_PLASTER)[4])
    # The image: a small figure in red with a gold crown, holding a globe.
    c.fill(11, 16, 9, 16, red[1])
    c.vline(11, 16, 16, red[2])
    c.fill(13, 10, 5, 6, skin[2])
    c.fill(12, 6, 7, 4, gilt[3])
    c.px(15, 4, gilt[4])
    c.fill(19, 20, 3, 3, gilt[2])
    tiles["santo_nino_print"] = _emit(c, "santo_nino_print")


def _votive_stand(tiles: dict) -> None:
    """A tiered stand of votive candles -- what a shrine actually looks like at a fiesta."""
    c = Canvas(52, 46, SEED + 409)
    iron = ramp(IRON)
    wax = ramp(CANDLE)
    flame = ramp(FLAME)
    for tier in range(3):
        y = 16 + tier * 10
        c.fill(4 + tier * 3, y, 44 - tier * 6, 3, iron[2])
        c.hline(4 + tier * 3, y, 44 - tier * 6, iron[3])
        for index in range((7 - tier * 1)):
            x = 7 + tier * 3 + index * 6
            h = 5 + (index * 3) % 4
            c.fill(x, y - h, 3, h, wax[1])
            c.vline(x, y - h, h, wax[2])
            if (index + tier) % 2 == 0:
                c.px(x + 1, y - h - 2, flame[2])
                c.px(x + 1, y - h - 1, flame[1])
    c.fill(6, 43, 40, 3, iron[1])
    tiles["votive_stand"] = _emit(c, "votive_stand")


def _font(tiles: dict) -> None:
    """The holy-water font by the door. Stone, and the first thing anybody touches."""
    c = Canvas(30, 40, SEED + 419)
    stone = ramp(LIMESTONE)
    water = ramp(GLASS)
    c.fill(11, 14, 8, 26, stone[2])
    c.vline(11, 14, 26, stone[4])
    c.fill(6, 36, 18, 4, stone[3])
    for row in range(10):
        half = int(13 * (0.6 + 0.4 * (row / 10.0)))
        c.fill(15 - half, 6 + row, half * 2, 1, stone[3])
        c.px(15 - half, 6 + row, stone[5])
        c.px(15 + half - 1, 6 + row, stone[1])
    c.fill(5, 6, 20, 3, water[1])
    c.hline(5, 6, 20, water[3])
    tiles["font"] = _emit(c, "font")


def _washing_line(tiles: dict) -> None:
    """A line of washing across an alley. Nothing says back street faster."""
    c = Canvas(120, 44, SEED + 431)
    rope = ramp(SAWALI)
    cloths = [ramp(FLAME), ramp(GLASS), ramp(CANDLE), ramp(SAWALI)]
    for x in range(c.w):
        c.px(x, 3 + int(2 * np.sin(x / 26.0)), rope[1])
    x = 4
    index = 0
    while x < c.w - 14:
        pal = cloths[index % len(cloths)]
        w = int(c.rng.integers(11, 19))
        h = int(c.rng.integers(16, 32))
        y = 4 + int(2 * np.sin(x / 26.0))
        c.fill(x, y, w, h, pal[1])
        c.dither(x, y, w, h, pal[1], pal[2], 0.45)
        c.hline(x, y, w, pal[3])
        # It hangs, so the hem is not straight.
        for step in range(w):
            c.px(x + step, y + h + (1 if step % 4 else 0), pal[0])
        x += w + int(c.rng.integers(5, 13))
        index += 1
    tiles["washing_line"] = _emit(c, "washing_line")


def _drainpipe(tiles: dict) -> None:
    """Cast iron down the wall, with the stain it has left."""
    c = Canvas(16, 120, SEED + 433)
    iron = ramp(IRON)
    damp = ramp(PLASTER_COLD)
    c.dither(1, 0, 14, c.h, damp[3], damp[1], 0.4)
    c.fill(5, 0, 7, c.h, iron[2])
    c.vline(5, 0, c.h, iron[3])
    c.vline(11, 0, c.h, iron[0])
    for y in range(0, c.h, 26):
        c.fill(3, y, 11, 4, iron[1])
        c.hline(3, y, 11, iron[3])
    tiles["drainpipe"] = _emit(c, "drainpipe")


def _handbills(tiles: dict) -> None:
    """Fiesta bills pasted on an alley wall, sun-bleached and half torn off."""
    c = Canvas(64, 46, SEED + 439)
    paper = ramp(CANDLE)
    ink = ramp(FLAME)
    for index in range(3):
        x = 2 + index * 21
        y = 3 + (index % 2) * 9
        w = int(c.rng.integers(14, 19))
        h = int(c.rng.integers(20, 30))
        c.fill(x, y, w, h, paper[1])
        c.dither(x, y, w, h, paper[1], paper[0], 0.35)
        for line in range(3, h - 4, 5):
            c.fill(x + 2, y + line, w - 5, 2, ink[0] if line < 8 else paper[0])
        # A corner peeled back.
        if index % 2 == 0:
            for step in range(6):
                c.fill(x + w - 6 + step, y + h - 6 + step, 6 - step, 1, paper[2])
    tiles["handbills"] = _emit(c, "handbills")


def _shelf(tiles: dict) -> None:
    """A plank shelf with jars on it. What a house keeps its salt and vinegar on."""
    c = Canvas(58, 34, SEED + 443)
    wood = ramp(TIMBER)
    clay = ramp(FLAME)
    c.fill(0, 22, c.w, 5, wood[3])
    c.hline(0, 22, c.w, wood[5])
    c.hline(0, 26, c.w, wood[0])
    for x in [3, c.w - 8]:
        c.fill(x, 27, 5, 7, wood[1])
    for index in range(4):
        x = 5 + index * 13
        h = 12 + (index * 5) % 6
        c.fill(x, 22 - h, 9, h, clay[1 + (index % 2)])
        c.vline(x, 22 - h, h, clay[2])
        c.fill(x + 1, 22 - h - 2, 7, 3, clay[0])
    tiles["shelf"] = _emit(c, "shelf")


def _crate(tiles: dict) -> None:
    c = Canvas(30, 26)
    wood = ramp(TIMBER)
    c.fill(0, 0, c.w, c.h, wood[2])
    c.hline(0, 0, c.w, wood[4])
    c.vline(0, 0, c.h, wood[4])
    c.hline(0, c.h - 1, c.w, wood[0])
    c.vline(c.w - 1, 0, c.h, wood[0])
    for y in [7, 17]:
        c.hline(0, y, c.w, wood[1])
        c.hline(0, y + 1, c.w, wood[3])
    for x in [4, c.w - 6]:
        c.vline(x, 0, c.h, wood[1])
    tiles["crate"] = _emit(c, "crate")


def _barrel(tiles: dict) -> None:
    c = Canvas(26, 34)
    wood = ramp(TIMBER)
    iron = ramp(IRON)
    for y in range(c.h):
        bulge = int(2 * (1 - ((y - c.h / 2) / (c.h / 2)) ** 2))
        c.fill(2 - bulge, y, c.w - 4 + bulge * 2, 1, wood[2])
    for x in range(3, c.w - 3, 5):
        c.vline(x, 1, c.h - 2, wood[1])
    c.dither(1, 1, 8, c.h - 2, wood[2], wood[4], 0.5)
    for y in [4, c.h - 7]:
        c.fill(0, y, c.w, 3, iron[2])
        c.hline(0, y, c.w, iron[3])
    tiles["barrel"] = _emit(c, "barrel")


def _drain(tiles: dict) -> None:
    """The channel down the middle of an alley. Every back street has one."""
    c = Canvas(64, 14)
    stone = ramp(SETT)
    c.fill(0, 0, c.w, c.h, stone[2])
    c.fill(0, 4, c.w, 6, stone[0])
    c.hline(0, 4, c.w, stone[4])
    c.hline(0, 9, c.w, stone[3])
    # Standing water, dithered so it reads as wet rather than as a blue stripe.
    c.dither(0, 6, c.w, 3, stone[0], ramp(GLASS)[0], 0.35)
    tiles["drain"] = _emit(c, "drain")


def _emit(c: Canvas, name: str) -> dict:
    size = c.save(OUT_DIR / ("%s.png" % name))
    return {"file": "%s.png" % name, "size": [size[0], size[1]]}


def build(check: bool) -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    tiles: dict = {}
    _wall("church_wall", "church", tiles)
    _wall("church_upper", "church_upper", tiles)
    _wall("house_wall", "house", tiles)
    _wall("alley_wall", "alley", tiles)
    _floor("church_floor", "church", tiles)
    _floor("house_floor", "house", tiles)
    _floor("alley_floor", "alley", tiles)
    _ceiling("church_ceiling", "church", tiles)
    _ceiling("house_ceiling", "house", tiles)
    _church_window(tiles)
    _house_window(tiles)
    _pew(tiles)
    _candle_rack(tiles)
    _altar(tiles)
    _santo_nino_print(tiles)
    _votive_stand(tiles)
    _font(tiles)
    _washing_line(tiles)
    _drainpipe(tiles)
    _handbills(tiles)
    _shelf(tiles)
    _table(tiles)
    _kandila(tiles)
    _crate(tiles)
    _barrel(tiles)
    _drain(tiles)

    if not check:
        MANIFEST.write_text(json.dumps({
            "$comment": "Generated by tools/build_interiors.py. ORIGINAL 8-bit art authored "
                        "for the interiors, on a logical pixel grid scaled by PX with "
                        "nearest-neighbour. The delivered plaza is the style reference and "
                        "nothing here is copied from it -- its material is the OUTSIDE of a "
                        "town, and tiling mossy rubble and packed earth into a nave was the "
                        "mistake this replaces.",
            "pixel_scale": PX,
            "tiles": tiles,
        }, indent=2) + "\n")
    print("%s %d interior pieces at %dx" % ("checked" if check else "wrote", len(tiles), PX))
    for name in sorted(tiles):
        print("   %-16s %s" % (name, tiles[name]["size"]))
    return 0


if __name__ == "__main__":
    sys.exit(build("--check" in sys.argv))
