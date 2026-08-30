#!/usr/bin/env python3
"""Author Piyesta's plaza as original 8-bit art, themed on the Basilica del Santo Nino.

WHY THIS EXISTS
---------------
The plaza was the delivered painting, pasted in as one flat picture with collision fitted
underneath it, and it never read right. It is a wide painterly VISTA -- a thing to look at
from one viewpoint -- and a side-scroller needs a thing to walk along. What the player saw
was two identical grass-topped walls, one behind the dancers and one in front of them, with
a thin strip of ground between: "the background has the platform and also the actual
platform". That is not a bug in the pasting. It is what a vista does when you stand a
character in it.

So the plaza is authored, the same way the interiors are: on a logical pixel grid, in short
ramps, with one light from the upper left. `tools/pixelart.py` is the shared library, so the
plaza and the four insides cannot drift into two idioms.

ONE GROUND LINE. The whole layout rule is that the plaza has exactly one horizon the player
stands on, everything built sits ON it, and the only thing in front of the player is a low
KERB -- ankle height, not a second wall. That single decision is what the complaint was
about.

THE THEME, AND A NOTE ABOUT IT
------------------------------
The Basilica Minore del Santo Nino in Cebu: coral-stone facade in three tiers, paired
pilasters, a round window in the pediment, and the belfry standing beside it. Sinulog's
colours are the Santo Nino's own red and gold, which is what the banderitas and the banners
are.

⚠ THIS REPLACES PAHIYAS. The delivered painting is unmistakably Lucban -- the woven-palm
arch crowned with a kiping aranya is that fiesta's signature -- and `level_02.json` said so
in writing. Changing it was asked for deliberately; the config is updated to match, and the
delivered painting stays in the repo and still backs the hub card.

⚠ AND THE SANTO NINO IMAGE IS SACRED. It is drawn and never built: no collision, no
interaction, no puzzle function, exactly as `cultural_constraints.church` requires and as
`ChurchInterior2D._check_the_guardrail` enforces. The facade here is a building; the image
itself lives in the retablo indoors and is inert there.

    python3 tools/build_plaza_art.py [--check]
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelart import PX, Canvas, ramp   # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "game" / "assets" / "Level2" / "plaza"
MANIFEST = OUT_DIR / "plaza.json"
SEED = 20260901

# --- Palettes ----------------------------------------------------------------------------
# Coral stone -- the Basilica's own material, quarried from the reef: pale, warm, and porous,
# so it weathers grey in the shadows and gold where the sun is on it.
CORAL = ["#4A4034", "#6E6152", "#948674", "#B7A895", "#D6C8B4", "#EFE4D2"]
## The plaza underfoot: cut stone, walked smooth, warmer than the walls.
PAVING = ["#3A3026", "#57493A", "#786752", "#96836B", "#B09C82", "#C7B499"]
## Roof tile. Every roof in Cebu is this colour.
TILE = ["#4A1F12", "#6E2F18", "#93441F", "#B85C2A", "#D4763C", "#E8955A"]
TIMBER = ["#2A1A0C", "#452C15", "#653F1E", "#87582C", "#A8763F", "#C79A5E"]
## Sinulog red and gold -- the Santo Nino's own colours, and what the fiesta is dressed in.
FIESTA_RED = ["#5A1010", "#8A1A18", "#B82824", "#D94438", "#EE6A56"]
FIESTA_GOLD = ["#6E4A08", "#9E7010", "#C89A1E", "#E6BE3C", "#F7DC78"]
GREEN = ["#1C3418", "#2E4E22", "#436B2E", "#5D8A3E", "#7BA855", "#9CC474"]
SKY = ["#2E7ECC", "#4C97DA", "#6FAFE4", "#96C7EE", "#BEDDF5", "#DCEDF9"]
IRON = ["#14161A", "#23262B", "#363A40", "#4C5058"]
GLASS = ["#3A4A52", "#5A7480", "#86A6B2", "#B8D2DA"]
SHELL = ["#8A7A54", "#C4B48A", "#E8DCB8", "#F6EFD6"]


def _emit(c: Canvas, name: str, tiles: dict) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    size = c.save(OUT_DIR / ("%s.png" % name))
    tiles[name] = {"file": "%s.png" % name, "size": [size[0], size[1]]}


# --- The ground --------------------------------------------------------------------------

def _paving(tiles: dict) -> None:
    """Cut stone, walked smooth. Three variants so a plaza does not repeat every metre."""
    for variant in range(3):
        c = Canvas(64, 32, SEED + variant * 613)
        pal = ramp(PAVING)
        c.fill(0, 0, c.w, c.h, pal[0])
        slab = 16
        for row in range(0, c.h, slab):
            offset = 0 if (row // slab) % 2 == 0 else slab // 2
            for x in range(-offset, c.w, slab):
                tone = pal[2 + int(c.rng.integers(0, 3))]
                c.fill(x + 1, row + 1, slab - 1, slab - 1, tone)
                # Worn hollow in the middle, dark in the joint: how a walked stone reads.
                c.dither(x + 3, row + 3, slab - 5, slab - 5, tone, pal[4], 0.4)
                c.hline(x + 1, row + 1, slab - 1, pal[4])
                c.vline(x + 1, row + 1, slab - 1, pal[3])
                c.speckle(x + 2, row + 2, slab - 3, slab - 3, pal[1], 0.02)
        name = "paving_%s" % "abc"[variant]
        _emit(c, name, tiles)


def _kerb(tiles: dict) -> None:
    """⚠ THE FIX FOR THE DOUBLED LEDGE, and it is deliberately SMALL.

    What used to stand in front of the player was a full grass-topped retaining wall, the
    twin of the one behind them, so the plaza read as two platforms with a strip between. A
    kerb is ankle height. It says "the ground stops here" and nothing else.
    """
    c = Canvas(64, 10, SEED + 77)
    pal = ramp(PAVING)
    c.fill(0, 0, c.w, c.h, pal[2])
    c.hline(0, 0, c.w, pal[5])
    c.hline(0, 1, c.w, pal[4])
    for x in range(0, c.w, 21):
        c.vline(x, 0, c.h, pal[1])
    c.hline(0, c.h - 2, c.w, pal[1])
    c.hline(0, c.h - 1, c.w, pal[0])
    _emit(c, "kerb", tiles)


def _retaining(tiles: dict) -> None:
    """Coral rubble below the kerb, going down out of frame. Not a ledge -- a footing."""
    c = Canvas(64, 48, SEED + 91)
    pal = ramp(CORAL)
    c.fill(0, 0, c.w, c.h, pal[0])
    y = 0
    row = 0
    while y < c.h:
        x = -int(c.rng.integers(0, 6)) - (5 if row % 2 else 0)
        while x < c.w:
            w = int(c.rng.integers(9, 15))
            c.fill(x + 1, y + 1, w - 1, 11, pal[1 + int(c.rng.integers(0, 2))])
            c.hline(x + 1, y + 1, w - 1, pal[3])
            c.hline(x + 1, y + 11, w - 1, pal[0])
            x += w
        y += 12
        row += 1
    # It is in shadow down here, and it gets darker as it goes.
    c.dither(0, c.h // 2, c.w, c.h // 2, pal[1], pal[0], 0.6)
    _emit(c, "retaining", tiles)


# --- The Basilica -------------------------------------------------------------------------

def _basilica(tiles: dict) -> None:
    """The facade: coral stone in three tiers, paired pilasters, a round window, a cross.

    Drawn as a BUILDING rather than as a picture of one -- the tiers are separated by real
    cornices that step out, every pilaster carries a lit left edge and a shadowed right, and
    the openings are cut back into the wall with a reveal. That is what makes a flat elevation
    read as masonry.
    """
    c = Canvas(240, 300, SEED + 101)
    stone = ramp(CORAL)
    tile = ramp(TILE)
    wood = ramp(TIMBER)
    gold = ramp(FIESTA_GOLD)

    body = (18, 40, 204, 260)          # x, y, w, h of the facade block
    c.fill(body[0], body[1], body[2], body[3], stone[2])
    # Coral is porous: mottle it before anything is drawn on top.
    c.dither(body[0], body[1], body[2], body[3], stone[2], stone[3], 0.45)
    c.speckle(body[0], body[1], body[2], body[3], stone[1], 0.03)

    def cornice(y: int, height: int = 6, out: int = 5) -> None:
        """A course that steps out of the wall, catching light on its top and casting below."""
        c.fill(body[0] - out, y, body[2] + out * 2, height, stone[4])
        c.hline(body[0] - out, y, body[2] + out * 2, stone[5])
        c.fill(body[0] - out, y + height, body[2] + out * 2, 3, stone[1])

    def pilaster(x: int, y: int, height: int, width: int = 13) -> None:
        c.fill(x, y, width, height, stone[3])
        c.vline(x, y, height, stone[5])
        c.vline(x + width - 1, y, height, stone[1])
        # A plinth and a capital, so it is a column and not a stripe.
        c.fill(x - 2, y + height - 7, width + 4, 7, stone[4])
        c.fill(x - 2, y, width + 4, 6, stone[4])
        c.hline(x - 2, y, width + 4, stone[5])

    def arch(x: int, y: int, w: int, h: int, inner: np.ndarray) -> None:
        """An opening with a semicircular head, cut back into the wall."""
        rad = w // 2
        for row in range(h):
            if row < rad:
                half = int((1.0 - ((rad - row) / rad) ** 2) ** 0.5 * rad)
            else:
                half = rad
            if half <= 0:
                continue
            c.fill(x + rad - half, y + row, half * 2, 1, inner)
        # The reveal: light down the left jamb, shadow down the right and under the head.
        for row in range(h):
            half = int((1.0 - ((rad - row) / rad) ** 2) ** 0.5 * rad) if row < rad else rad
            if half <= 1:
                continue
            c.px(x + rad - half, y + row, stone[5])
            c.px(x + rad + half - 1, y + row, stone[1])

    # --- third tier: the pediment, its round window, and the cross on top
    for row in range(30):
        half = int(70 * (row / 30.0))
        c.fill(120 - half, 40 + row, half * 2, 1, stone[3])
    c.fill(50, 68, 140, 5, stone[4])
    # The oculus. A round window is the one shape on this facade everybody remembers.
    for row in range(-11, 12):
        half = int((121 - row * row) ** 0.5)
        c.fill(120 - half, 55 + row, half * 2, 1, stone[1])
        if half > 2:
            c.fill(120 - half + 2, 55 + row, half * 2 - 4, 1, ramp(GLASS)[1])
    c.fill(118, 8, 4, 32, stone[4])         # the cross
    c.fill(110, 16, 20, 4, stone[4])
    c.hline(110, 16, 20, stone[5])

    cornice(72)
    # --- second tier: a central niche flanked by paired pilasters
    for x in [26, 44, 178, 196]:
        pilaster(x, 82, 78)
    arch(96, 84, 48, 72, stone[0])
    c.fill(100, 100, 40, 52, stone[1])
    # The image in the niche, in the Santo Nino's red and gold. Small, high, and out of reach
    # -- which is what it is, and what it should look like.
    c.fill(112, 116, 16, 28, ramp(FIESTA_RED)[2])
    c.fill(112, 116, 5, 28, ramp(FIESTA_RED)[3])
    c.fill(115, 106, 10, 11, ramp(SHELL)[1])
    c.fill(113, 100, 14, 6, gold[3])        # the crown
    c.hline(113, 100, 14, gold[4])

    cornice(162)
    # --- first tier: the main door, two side doors, and the pilasters between them
    for x in [26, 44, 178, 196]:
        pilaster(x, 172, 100)
    arch(92, 186, 56, 86, wood[1])
    # The door leaves, panelled, with a hinge band across each.
    for leaf in range(2):
        lx = 94 + leaf * 26
        c.fill(lx, 214, 24, 58, wood[2])
        c.vline(lx, 214, 58, wood[4])
        c.vline(lx + 23, 214, 58, wood[0])
        for band in [222, 250]:
            c.fill(lx, band, 24, 3, wood[1])
    for side in [58, 158]:
        arch(side, 208, 28, 64, wood[1])
        c.fill(side + 3, 226, 22, 46, wood[2])
    # The steps up to it, in the plaza's own paving.
    paving = ramp(PAVING)
    for step in range(3):
        c.fill(70 - step * 8, 272 + step * 10, 100 + step * 16, 10, paving[3])
        c.hline(70 - step * 8, 272 + step * 10, 100 + step * 16, paving[5])
    _emit(c, "basilica", tiles)


def _belfry(tiles: dict) -> None:
    """The bell tower that stands beside the church, and is taller than it."""
    c = Canvas(96, 360, SEED + 113)
    stone = ramp(CORAL)
    tile = ramp(TILE)
    iron = ramp(IRON)
    c.fill(10, 60, 76, 300, stone[2])
    c.dither(10, 60, 76, 300, stone[2], stone[3], 0.42)
    c.speckle(10, 60, 76, 300, stone[1], 0.03)
    # Three stages, each stepped in a little, with a string course between.
    for y in [140, 230]:
        c.fill(4, y, 88, 7, stone[4])
        c.hline(4, y, 88, stone[5])
        c.fill(4, y + 7, 88, 3, stone[1])
    # The belfry openings: an arch on each stage, with the bell in the top one.
    for y, h in [(78, 46), (162, 40), (252, 36)]:
        rad = 16
        for row in range(h):
            half = int((1.0 - ((rad - row) / rad) ** 2) ** 0.5 * rad) if row < rad else rad
            if half > 0:
                c.fill(48 - half, y + row, half * 2, 1, stone[0])
                c.px(48 - half, y + row, stone[5])
                c.px(48 + half - 1, y + row, stone[1])
        if y == 78:
            c.fill(40, 90, 16, 18, iron[2])
            c.hline(40, 90, 16, iron[3])
            c.fill(46, 108, 4, 5, iron[1])
    # The cupola and its cross.
    for row in range(26):
        half = int(40 * (1.0 - (row / 26.0) ** 2) ** 0.5)
        c.fill(48 - half, 60 - row, half * 2, 1, tile[2 + (row // 9)])
    c.fill(46, 20, 4, 16, stone[4])
    c.fill(40, 26, 16, 4, stone[4])
    for x in [10, 82]:
        c.vline(x, 60, 300, stone[4] if x == 10 else stone[1])
    _emit(c, "belfry", tiles)


# --- The town ------------------------------------------------------------------------------

def _townhouse(tiles: dict) -> None:
    """A bahay na bato: coral stone below, timber and capiz above, tile roof over it.

    Two variants, because a street of one house repeated is a street nobody believes.
    """
    for variant in range(2):
        c = Canvas(120, 190, SEED + 131 + variant * 37)
        stone = ramp(CORAL)
        wood = ramp(TIMBER)
        tile = ramp(TILE)
        shell = ramp(SHELL)
        # The roof: tile, with a ridge and an overhanging eave that casts on the wall.
        for row in range(26):
            inset = int((25 - row) * 0.7)
            c.fill(2 + inset, 8 + row, 116 - inset * 2, 1, tile[2 + (row // 10)])
        c.fill(0, 32, 120, 6, tile[1])
        c.hline(0, 32, 120, tile[4])
        c.fill(4, 38, 112, 4, wood[0])
        # The upper storey: timber frame with capiz shutters between the posts.
        c.fill(6, 42, 108, 62, wood[2])
        c.dither(6, 42, 108, 62, wood[2], wood[1], 0.4)
        for index in range(3):
            x = 14 + index * 32
            c.fill(x, 50, 26, 46, wood[1])
            for row in range(4):
                for col in range(3):
                    c.fill(x + 3 + col * 8, 53 + row * 11, 6, 8, shell[1])
                    c.dither(x + 3 + col * 8, 53 + row * 11, 6, 8, shell[1], shell[2], 0.45)
            c.hline(x, 50, 26, wood[4])
        c.fill(4, 104, 112, 5, wood[3])
        c.hline(4, 104, 112, wood[5])
        # The ground storey: coral stone, with a door and a barred window.
        c.fill(8, 109, 104, 81, stone[2])
        c.dither(8, 109, 104, 81, stone[2], stone[3], 0.45)
        c.speckle(8, 109, 104, 81, stone[1], 0.035)
        door_x = 22 if variant == 0 else 66
        c.fill(door_x, 132, 30, 58, stone[0])
        c.fill(door_x + 2, 136, 26, 54, wood[2])
        c.vline(door_x + 2, 136, 54, wood[4])
        c.vline(door_x + 27, 136, 54, wood[0])
        win_x = 66 if variant == 0 else 22
        c.fill(win_x, 138, 30, 30, stone[0])
        c.fill(win_x + 2, 140, 26, 26, ramp(GLASS)[0])
        for bar in range(4):
            c.vline(win_x + 4 + bar * 7, 140, 26, ramp(IRON)[2])
        c.hline(8, 109, 104, stone[5])
        _emit(c, "townhouse_%s" % "ab"[variant], tiles)


def _arcade(tiles: dict) -> None:
    """A repeating arcade bay: the covered walk that runs along a pilgrim courtyard."""
    c = Canvas(72, 150, SEED + 149)
    stone = ramp(CORAL)
    tile = ramp(TILE)
    c.fill(0, 22, c.w, 128, stone[2])
    c.dither(0, 22, c.w, 128, stone[2], stone[3], 0.4)
    for row in range(14):
        c.fill(0, 8 + row, c.w, 1, tile[2 + (row // 6)])
    c.fill(0, 22, c.w, 5, stone[4])
    c.hline(0, 22, c.w, stone[5])
    # The arch, cut back so it is a way through and not a painted shape.
    rad = 24
    for row in range(96):
        half = int((1.0 - ((rad - row) / rad) ** 2) ** 0.5 * rad) if row < rad else rad
        if half <= 0:
            continue
        c.fill(36 - half, 40 + row, half * 2, 1, stone[0])
        c.px(36 - half, 40 + row, stone[4])
        c.px(36 + half - 1, 40 + row, stone[1])
    c.fill(0, 136, c.w, 14, stone[3])
    c.hline(0, 136, c.w, stone[5])
    _emit(c, "arcade", tiles)


# --- Dressing ------------------------------------------------------------------------------

def _rooftops(tiles: dict) -> None:
    """The town below the plaza terrace, seen from above: a run of tiled roofs.

    ⚠ THIS EXISTS BECAUSE OF THE CAMERA, not because the design asked for it. The vertical
    follow keeps the player near the middle of the frame, so roughly four hundred units below
    their feet is always on screen -- and four hundred units of retaining wall is a blank
    band across the bottom third of every shot. The Basilica stands on high ground in a city;
    what is under the plaza is the rest of the city, and drawing it turns dead screen into
    depth.
    """
    c = Canvas(128, 64, SEED + 251)
    tile = ramp(TILE)
    stone = ramp(CORAL)
    sky = ramp(SKY)
    c.fill(0, 0, c.w, c.h, stone[0])
    x = -6
    while x < c.w:
        w = int(c.rng.integers(26, 44))
        top = int(c.rng.integers(6, 22))
        # The roof: two pitches meeting at a ridge, in courses of tile.
        for row in range(18):
            inset = int(row * 0.5)
            c.fill(x + inset, top + row, w - inset * 2, 1, tile[1 + (row // 7)])
        c.hline(x, top + 17, w, tile[0])
        # The wall under it, in shadow.
        c.fill(x + 3, top + 18, w - 6, c.h - top - 18, stone[1])
        c.dither(x + 3, top + 18, w - 6, c.h - top - 18, stone[1], stone[0], 0.55)
        # One lit window, because a town at a fiesta is awake.
        if c.rng.random() < 0.5:
            wx = x + 6 + int(c.rng.integers(0, max(1, w - 16)))
            c.fill(wx, top + 24, 5, 6, ramp(FIESTA_GOLD)[3])
        x += w + int(c.rng.integers(2, 7))
    _emit(c, "rooftops", tiles)


def _hills(tiles: dict) -> None:
    """What is behind the town. Cebu's ridge, hazed by distance."""
    c = Canvas(160, 70, SEED + 167)
    green = ramp(GREEN)
    sky = ramp(SKY)
    c.fill(0, 0, c.w, c.h, sky[4])
    for layer, tone in [(0, green[5]), (1, green[4]), (2, green[3])]:
        base = 24 + layer * 14
        for x in range(c.w):
            top = base + int(9 * np.sin(x / (13.0 + layer * 6) + layer * 2.1)
                             + 5 * np.sin(x / 5.0 + layer))
            c.fill(x, top, 1, c.h - top, tone)
    # Haze: the far ridge is nearly sky.
    c.dither(0, 0, c.w, 40, sky[4], green[5], 0.35)
    _emit(c, "hills", tiles)


def _palm(tiles: dict) -> None:
    """A coconut palm. The trunk is segmented and the fronds droop -- a straight trunk with
    straight spikes reads as a firework, which is what the first cut looked like."""
    c = Canvas(96, 150, SEED + 181)
    green = ramp(GREEN)
    wood = ramp(TIMBER)
    # The trunk: leaning, thickening toward the base, ringed where old fronds fell off.
    for row in range(112):
        t = row / 112.0
        x = 44 + int(7 * np.sin(t * 1.5))
        half = 3 + int(t * 3)
        c.fill(x - half, 38 + row, half * 2, 1, wood[2])
        c.px(x - half, 38 + row, wood[4])
        c.px(x + half - 1, 38 + row, wood[0])
        if row % 8 == 0:
            c.fill(x - half - 1, 38 + row, half * 2 + 2, 2, wood[1])
    # Fronds: a midrib that curves down, with leaflets stepping off it either side.
    for index in range(8):
        angle = -2.85 + index * 0.41
        droop = 0.030 + 0.014 * abs(index - 3.5)
        tone = green[3 + (index % 2)]
        for step in range(34):
            fx = 44 + np.cos(angle) * step * 1.5
            fy = 38 + np.sin(angle) * step * 1.5 + droop * step * step
            if not (0 <= int(fx) < c.w and 0 <= int(fy) < c.h):
                continue
            c.fill(int(fx), int(fy), 2, 2, green[1])
            leaf = max(1, 8 - step // 5)
            for side in (-1, 1):
                for blade in range(leaf):
                    bx = int(fx + side * blade)
                    by = int(fy + blade * 0.75 + (step % 3))
                    c.px(bx, by, tone)
    # A cluster of nuts where the fronds meet the trunk.
    for at in [(38, 34), (48, 36), (43, 41)]:
        c.fill(at[0], at[1], 7, 7, wood[3])
        c.px(at[0] + 1, at[1] + 1, wood[5])
    _emit(c, "palm", tiles)


def _dancer(tiles: dict) -> None:
    """A Sinulog dancer, in the Santo Nino's red and gold, with a candle.

    ⚠ AUTHORING THESE IS WHAT UNBLOCKS THE SCARE. They used to be painted into `MG_People`,
    which is why Problem 1's Protector route was mechanically complete and visually invisible:
    the composite would not give them up (a bbox cut takes the palm trunks behind two of them;
    a colour mask leaves the hats, hands and shoes). As sprites they can simply leave.

    Three frames: two of the step, and one fleeing.
    """
    red = ramp(FIESTA_RED)
    gold = ramp(FIESTA_GOLD)
    skin = ramp(SHELL)
    hair = ramp(TIMBER)
    flame = ramp(FIESTA_GOLD)
    for frame, name in enumerate(["dancer_a", "dancer_b", "dancer_flee"]):
        c = Canvas(44, 62, SEED + 223 + frame)
        fleeing = name == "dancer_flee"
        lean = 3 if fleeing else 0
        sway = 0 if frame == 0 else (2 if frame == 1 else 0)
        # The skirt: a trapezium, wider on the beat, with the gold band every one carries.
        hem = 20 if not fleeing else 15
        for row in range(24):
            t = row / 24.0
            half = int(6 + hem * t)
            x = 22 + sway - lean
            c.fill(x - half, 36 + row, half * 2, 1, red[2])
            c.px(x - half, 36 + row, red[3])
            c.px(x + half - 1, 36 + row, red[1])
        c.fill(22 + sway - lean - 16, 54, 32, 3, gold[3])
        c.fill(22 + sway - lean - 12, 44, 24, 2, gold[2])
        # Bodice, arms and head.
        c.fill(16 + sway - lean, 22, 12, 15, red[2])
        c.vline(16 + sway - lean, 22, 15, red[3])
        c.fill(18 + sway - lean, 12, 8, 9, skin[1])
        c.fill(17 + sway - lean, 8, 10, 6, hair[0])
        c.px(20 + sway - lean, 16, hair[0])
        c.px(24 + sway - lean, 16, hair[0])
        # The arms: raised on the beat, forward when running.
        for side in (-1, 1):
            if fleeing:
                for step in range(9):
                    c.fill(22 - lean + side * (6 + step), 26 + step // 2, 2, 2, skin[1])
            else:
                lift = 9 if (side > 0) == (frame == 0) else 4
                for step in range(9):
                    c.fill(22 + sway + side * (6 + step), 26 - step * lift // 9, 2, 2, skin[1])
        if not fleeing:
            # The candle. Sinulog is a candle dance before it is anything else.
            cx = 22 + sway + 15
            c.fill(cx, 12, 3, 9, ramp(SHELL)[2])
            c.px(cx + 1, 9, flame[4])
            c.fill(cx, 10, 3, 2, flame[3])
        _emit(c, name, tiles)


def _lamp_post(tiles: dict) -> None:
    c = Canvas(30, 150, SEED + 193)
    iron = ramp(IRON)
    gold = ramp(FIESTA_GOLD)
    c.fill(12, 24, 6, 118, iron[2])
    c.vline(12, 24, 118, iron[3])
    c.fill(6, 142, 18, 8, iron[1])
    c.hline(6, 142, 18, iron[2])
    c.fill(8, 14, 14, 14, gold[1])
    c.fill(10, 16, 10, 10, gold[3])
    c.dither(10, 16, 10, 10, gold[3], gold[4], 0.5)
    c.fill(11, 8, 8, 6, iron[2])
    _emit(c, "lamp_post", tiles)


def _banner(tiles: dict) -> None:
    """A hanging banner in the Santo Nino's red and gold."""
    c = Canvas(34, 96, SEED + 211)
    red = ramp(FIESTA_RED)
    gold = ramp(FIESTA_GOLD)
    c.fill(2, 0, 30, 5, gold[2])
    c.fill(4, 5, 26, 80, red[2])
    c.vline(4, 5, 80, red[3])
    c.vline(29, 5, 80, red[0])
    # The lozenge every one of these carries.
    for row in range(-9, 10):
        half = 9 - abs(row)
        if half > 0:
            c.fill(17 - half, 42 + row, half * 2, 1, gold[3])
            if half > 3:
                c.fill(17 - half + 3, 42 + row, half * 2 - 6, 1, red[1])
    for x in range(5, 30, 4):
        c.fill(x, 85, 2, 8, gold[2])
    _emit(c, "banner", tiles)


def build(check: bool) -> int:
    tiles: dict = {}
    _paving(tiles)
    _kerb(tiles)
    _retaining(tiles)
    _basilica(tiles)
    _belfry(tiles)
    _townhouse(tiles)
    _arcade(tiles)
    _rooftops(tiles)
    _hills(tiles)
    _palm(tiles)
    _dancer(tiles)
    _lamp_post(tiles)
    _banner(tiles)
    if not check:
        MANIFEST.write_text(json.dumps({
            "$comment": "Generated by tools/build_plaza_art.py. ORIGINAL 8-bit art for the "
                        "plaza, themed on the Basilica del Santo Nino. Replaces the delivered "
                        "Pahiyas painting as the playable backdrop -- see the module docstring "
                        "for why a vista does not work as a side-scroller.",
            "pixel_scale": PX,
            "tiles": tiles,
        }, indent=2) + "\n")
    print("%s %d plaza pieces at %dx" % ("checked" if check else "wrote", len(tiles), PX))
    for name in sorted(tiles):
        print("   %-14s %s" % (name, tiles[name]["size"]))
    return 0


if __name__ == "__main__":
    sys.exit(build("--check" in sys.argv))
