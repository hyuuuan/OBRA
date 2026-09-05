#!/usr/bin/env python3
"""The ground Piyesta's plaza stands on, and the props its dance screen is dressed with.

⚠ THIS USED TO AUTHOR THE WHOLE PLAZA, AND IT DOES NOT ANY MORE.

For one pass the plaza was drawn from scratch here -- a Basilica del Santo Nino facade in
three tiers, a belfry, bahay na bato, an arcade, a kiosko, a woven arch, a stall, palms,
hills, hedges, clouds, a kerb and a lamp post: seven hundred lines of it. That pass existed
because the delivered painting read as two platforms, and it was the wrong fix. The painting
is a VISTA with a wall behind the dancers and a verge in front of them, and the right answer
was to CUT it at the walk line, not to replace it -- see `tools/build_plaza.py`. Authored, the
plaza was coherent and it was never as good as the plate.

So those nineteen pieces are gone, along with the code that drew them. They are in the
history if the delivered painting ever has to go; they are not in the game, where they were
being generated, imported, loaded into `PiyestaTiles` and drawn by nothing. What survives is
the half that is still load-bearing:

    paving_a/b/c, retaining, rooftops_a/b/c   the ground BELOW the cut painting
    dancer_a, dancer_b, fan_a/b/c, drum       the dance screen's stage
    banner                                    the church nave, dressed for the fiesta

Same method as before and as the interiors: a logical pixel grid scaled by nearest-neighbour,
six-step ramps, ordered dithering, one light from the upper left. `tools/pixelart.py` is the
shared library so these and the four insides cannot drift into two idioms.

⚠ AND THE SANTO NINO IMAGE IS SACRED. Nothing here draws it any more -- the facade went with
the rest -- but the rule stands wherever it does appear: drawn and never built, no collision,
no interaction, no puzzle function, as `cultural_constraints.church` requires and
`ChurchInterior2D._check_the_guardrail` enforces. The image lives in the retablo indoors and
is inert there.

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
# ⚠ SAMPLED OFF `Level2_CompletedLook.png`, NOT INVENTED, and that is the single change that
# closed most of the gap. The first pass used ramps chosen by eye and every one of them was
# too grey and too dark: coral stone at #948674 against the painting's #DFAB67, cobbles in
# slate where the painting is warm tan. The picture is SUNNY -- warm, saturated, high-key --
# and no amount of extra detail reads right in the wrong palette.

## The Basilica's coral stone, lit. Warm cream, not grey.
CORAL = ["#3A2A18", "#6B4E2E", "#9A7245", "#C79A5E", "#E5BC80", "#F8DCAB"]
## The plaza underfoot: warm cut stone, walked smooth.
PAVING = ["#4A3218", "#6B4A22", "#8F6633", "#B48A52", "#CFAA75", "#E4C89C"]
## Roof tile, off the painting's own houses.
TILE = ["#241412", "#3E2420", "#7A3624", "#A8492D", "#C8613A", "#E4855A"]
TIMBER = ["#2A1A0C", "#452C15", "#6B4526", "#8E5F32", "#B07C42", "#CFA164"]
## Nipa thatch: the kiosko and the stall are roofed in it, and it is the warmest thing here.
THATCH = ["#1A0E04", "#4A2C12", "#7A4E24", "#A87A38", "#D3A44A", "#F6CC63"]
## Sinulog red and gold -- the Santo Nino's own colours.
FIESTA_RED = ["#5A0C10", "#830A14", "#AE0F1C", "#CE2A24", "#E8533C", "#F5836A"]
FIESTA_GOLD = ["#7A5206", "#A87708", "#D4A014", "#EFC12C", "#F8DC63", "#FDEFA6"]
## Sunlit grass on the verge, and the deeper green of planting.
GRASS = ["#4A3A10", "#7E601B", "#A88A2C", "#BFB310", "#D6CE2A", "#EDE45A"]
GREEN = ["#1B2E08", "#293D09", "#31521E", "#466119", "#5F7817", "#7E9A2C"]
## The mossy stone the plaza is retained by, which is what the painting's front edge is.
MOSS = ["#141310", "#241C14", "#2F2619", "#41341E", "#5A3A1E", "#6E5A2A"]
## Sky and cloud, straight off the plate.
SKY = ["#0F79D4", "#1697F9", "#1D9DFA", "#24A3FB", "#5CBCFC", "#9AD6FD"]
CLOUD = ["#7FA8C4", "#A8CBE0", "#CDE4F0", "#E3F0F6", "#F2F8FA"]
IRON = ["#14161A", "#23262B", "#363A40", "#4C5058"]
GLASS = ["#2E4450", "#4A6A7C", "#7A9EAE", "#B0CEDA"]
SHELL = ["#8A7A54", "#C4B48A", "#E8DCB8", "#F6EFD6"]
## The dancers, read off the plate: a white saya panelled in red and gold, a straw hat, a
## flower fan in the raised hand.
CLOTH = ["#9A8C78", "#C6B9A2", "#E0D5C2", "#F0E8DA", "#FBF6EC"]
STRAW = ["#7A5C24", "#A07C34", "#C9A455", "#E8C87A", "#F6E2A8"]
SKIN = ["#6E4A30", "#8A5F3E", "#B0805A", "#C99A6E", "#DDB58A"]
HAIR = ["#120A06", "#22140C", "#382214", "#4E3220"]
## Distant ridge, hazed toward the sky.
HILL = ["#3E5A3A", "#4E6E48", "#5F8257", "#75986A", "#8FAE84"]


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

def _rooftops(tiles: dict) -> None:
    """The town below the plaza terrace, seen from above: a run of tiled roofs.

    ⚠ THIS EXISTS BECAUSE OF THE CAMERA, not because the design asked for it. The vertical
    follow keeps the player near the middle of the frame, so roughly four hundred units below
    their feet is always on screen -- and four hundred units of retaining wall is a blank
    band across the bottom third of every shot. The Basilica stands on high ground in a city;
    what is under the plaza is the rest of the city, and drawing it turns dead screen into
    depth.
    """
    for variant in range(3):
        _rooftop_run(tiles, variant)


def _rooftop_run(tiles: dict, variant: int) -> None:
    c = Canvas(128, 64, SEED + 251 + variant * 419)
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
    _emit(c, "rooftops_%s" % "abc"[variant], tiles)


def _dancer(tiles: dict) -> None:
    """A Sinulog dancer, drawn off the plate rather than sketched.

    ⚠ THE FIRST VERSION WAS A RED CONE with a head and two stick arms, and next to everything
    else it was the weakest thing on screen. The plate is specific and every part of it reads
    at this size: a WHITE saya panelled in red and gold with a scalloped hem, a red bodice
    with short white puffed sleeves, a wide straw hat over dark hair, and a flower fan of red
    and yellow held up in one hand. That fan is the silhouette -- it is what says "dancer"
    from across a plaza.

    TWO FRAMES, not three. There was a `dancer_flee` as well, drawn leaning over a leading
    foot, and it is gone with the rest of the authored plaza: the dancers who actually run
    are the painting's own cut-outs and they flee by moving, not by changing frame. These two
    are the DANCE SCREEN's dancers -- the four along the back of the stage -- and that screen
    never needed a third.
    """
    cloth = ramp(CLOTH)
    red = ramp(FIESTA_RED)
    gold = ramp(FIESTA_GOLD)
    straw = ramp(STRAW)
    skin = ramp(SKIN)
    hair = ramp(HAIR)
    wood = ramp(TIMBER)

    for frame, name in enumerate(["dancer_a", "dancer_b"]):
        c = Canvas(58, 66, SEED + 223 + frame)
        mid = 29
        sway = -1 if frame == 0 else 1
        # --- the saya: white, flared, panelled, with a scalloped hem
        top_half = 9
        hem_half = 22
        for row in range(26):
            t = row / 25.0
            half = int(top_half + (hem_half - top_half) * (t ** 0.82))
            x = mid + int(sway * t * 2)
            c.fill(x - half, 34 + row, half * 2, 1, cloth[3])
            c.px(x - half, 34 + row, cloth[4])
            c.px(x + half - 1, 34 + row, cloth[1])
        # Red and gold panels running down it, and two bands across.
        for panel in range(-1, 2):
            for row in range(26):
                t = row / 25.0
                half = int(top_half + (hem_half - top_half) * (t ** 0.82))
                x = mid + int(sway * t * 2) + int(panel * half * 0.62)
                c.fill(x, 34 + row, 2, 1, red[2] if panel == 0 else gold[2])
        for band, tone in [(0.42, gold[3]), (0.72, red[2])]:
            row = int(26 * band)
            t = row / 25.0
            half = int(top_half + (hem_half - top_half) * (t ** 0.82))
            x = mid + int(sway * t * 2)
            c.fill(x - half, 34 + row, half * 2, 2, tone)
        # The scalloped hem, with the little dark tassels the plate has.
        hem_row = 34 + 25
        for step in range(-hem_half, hem_half, 4):
            x = mid + int(sway * 2) + step
            c.fill(x, hem_row, 4, 2, cloth[4])
            c.px(x + 1, hem_row + 2, red[1])
        # --- legs and shoes under it
        for side in (-1, 1):
            c.fill(mid + side * 5 - 1, 59, 3, 4, skin[2])
            c.fill(mid + side * 5 - 2, 63, 5, 3, wood[2])
        # --- bodice, sash, sleeves
        c.fill(mid - 8, 21, 16, 13, red[2])
        c.dither(mid - 8, 21, 16, 13, red[2], red[3], 0.4)
        c.vline(mid - 8, 21, 13, red[3])
        c.vline(mid + 7, 21, 13, red[1])
        for mark in range(3):
            c.fill(mid - 4, 24 + mark * 3, 8, 1, gold[3])
        c.fill(mid - 9, 32, 18, 3, red[1])          # the sash
        c.hline(mid - 9, 32, 18, gold[2])
        for side in (-1, 1):                         # puffed white sleeves
            sx = mid + side * 11
            c.fill(sx - 3, 21, 6, 7, cloth[3])
            c.hline(sx - 3, 21, 6, cloth[4])
            c.px(sx + side * 2, 27, cloth[1])
        # --- arms. One up with the fan on the step, both forward when running.
        raised = (1 if frame == 0 else -1)
        for side in (-1, 1):
            up = side == raised
            for step in range(8):
                if up:
                    ax = mid + side * (13 + int(step * 0.8))
                    ay = 26 - step * 2
                else:
                    ax = mid + side * (13 + step)
                    ay = 27 + step // 2
                c.fill(ax - 1, ay, 3, 3, skin[2 if step < 5 else 3])
            if up:
                _fan(c, mid + side * 20, 6, red, gold)
        # --- head: hair, face, and the wide straw hat over it
        c.fill(mid - 7, 8, 14, 13, hair[1])
        c.fill(mid - 6, 10, 12, 9, skin[3])
        c.dither(mid - 6, 10, 12, 9, skin[3], skin[2], 0.35)
        c.px(mid - 3, 13, hair[0])
        c.px(mid + 2, 13, hair[0])
        c.fill(mid - 2, 16, 4, 1, red[3])
        c.fill(mid - 8, 17, 3, 5, hair[1])           # hair falling either side
        c.fill(mid + 5, 17, 3, 5, hair[1])
        for row in range(4):                          # the brim
            half = 15 - row
            c.fill(mid - half, 6 + row, half * 2, 1, straw[3 if row < 2 else 2])
        c.hline(mid - 15, 6, 30, straw[4])
        for row in range(5):                          # the crown
            half = 7 - row // 3
            c.fill(mid - half, 1 + row, half * 2, 1, straw[2 + (row // 3)])
        c.hline(mid - 6, 1, 12, straw[4])
        _emit(c, name, tiles)


def _fan(c: Canvas, cx: int, cy: int, red, gold) -> None:
    """The flower fan: eight petals of red and yellow around a gold centre.

    This is the dancer's silhouette. Without it the figure is a person in a dress; with it,
    from any distance, it is somebody dancing.
    """
    for petal in range(8):
        angle = petal * (np.pi * 2.0 / 8.0)
        pal = red if petal % 2 == 0 else gold
        for step in range(4, 9):
            px_ = cx + int(np.cos(angle) * step)
            py = cy + int(np.sin(angle) * step)
            c.fill(px_ - 1, py - 1, 3, 3, pal[2 + (step > 6)])
    c.fill(cx - 2, cy - 2, 5, 5, gold[3])
    c.fill(cx - 1, cy - 1, 3, 3, gold[4])


def _fan_sprites(tiles: dict) -> None:
    """The dancer's flower fan, on its own, for the dance screen to use as a cue.

    The cues were rings with a scratch inside them. The fan is the thing the dance is
    actually done with, it is already the dancers' silhouette, and it gives the screen
    something to be about.
    """
    for variant in range(3):
        c = Canvas(30, 30, SEED + 701 + variant * 53)
        red = ramp(FIESTA_RED)
        gold = ramp(FIESTA_GOLD)
        green = ramp(GREEN)
        petals = 8 + variant
        for petal in range(petals):
            angle = petal * (np.pi * 2.0 / petals) + variant * 0.3
            pal = red if petal % 2 == 0 else gold
            for step in range(4, 14):
                px_ = 15 + int(np.cos(angle) * step * 0.92)
                py = 15 + int(np.sin(angle) * step * 0.92)
                width = 3 if step < 10 else 2
                c.fill(px_ - width // 2, py - width // 2, width, width,
                       pal[2 + (step > 10)])
        # A few green leaves showing between the petals, like the plate's.
        for leaf in range(4):
            angle = leaf * (np.pi / 2.0) + 0.4
            for step in range(9, 14):
                c.px(15 + int(np.cos(angle) * step), 15 + int(np.sin(angle) * step),
                     green[3])
        c.fill(12, 12, 7, 7, gold[3])
        c.fill(13, 13, 5, 5, gold[4])
        c.px(14, 14, gold[5] if len(gold) > 5 else gold[4])
        _emit(c, "fan_%s" % "abc"[variant], tiles)


def _drum(tiles: dict) -> None:
    """A Sinulog drum. The dance is driven by them, and the judgement post is one."""
    c = Canvas(46, 54, SEED + 719)
    wood = ramp(TIMBER)
    red = ramp(FIESTA_RED)
    gold = ramp(FIESTA_GOLD)
    skin = ramp(SHELL)
    c.fill(4, 10, 38, 36, red[2])
    c.dither(4, 10, 38, 36, red[2], red[3], 0.4)
    c.vline(4, 10, 36, red[3])
    c.vline(41, 10, 36, red[1])
    # The heads, and the cords lacing them together.
    for y in [8, 44]:
        for row in range(6):
            half = int(21 * (1.0 - abs(row - 2.5) / 5.0) ** 0.4)
            c.fill(23 - half, y + row, half * 2, 1, skin[2])
        c.hline(2, y, 42, skin[3])
    for index in range(6):
        x = 6 + index * 7
        for step in range(28):
            c.px(x + (step % 3), 14 + step, gold[2])
    _emit(c, "drum", tiles)


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


def _carried() -> dict:
    """Entries in the manifest that another tool owns, kept across a rebuild."""
    if not MANIFEST.exists():
        return {}
    existing = json.loads(MANIFEST.read_text()).get("tiles", {})
    return {name: entry for name, entry in existing.items()
            if name.startswith("painted_dancer_") and (OUT_DIR / entry["file"]).exists()}


def build(check: bool) -> int:
    tiles: dict = {}
    _paving(tiles)
    _fan_sprites(tiles)
    _drum(tiles)
    _retaining(tiles)
    _rooftops(tiles)
    _dancer(tiles)
    _banner(tiles)
    # ⚠ CARRY THE DANCER CUTS FORWARD. `tools/build_dancers.py` writes `painted_dancer_a` and
    # `_b` into this same manifest, and this function used to rebuild it from scratch -- so
    # running the two tools in the wrong order silently dropped the dancers out of the sheet
    # and left four holes in the plaza where the painting expects people. The scene probe
    # catches the result, but a tool should not lay the trap in the first place.
    for name in sorted(_carried()):
        tiles[name] = _carried()[name]
    if not check:
        MANIFEST.write_text(json.dumps({
            "$comment": "Generated by tools/build_plaza_art.py, except painted_dancer_*, "
                        "which tools/build_dancers.py owns and this tool carries forward. "
                        "The ground under the cut painting, plus the dance screen's props "
                        "-- see the module docstring for what used to be here and why it "
                        "is not.",
            "pixel_scale": PX,
            "tiles": tiles,
        }, indent=2) + "\n")
    print("%s %d plaza pieces at %dx" % ("checked" if check else "wrote", len(tiles), PX))
    for name in sorted(tiles):
        print("   %-14s %s" % (name, tiles[name]["size"]))
    return 0


if __name__ == "__main__":
    sys.exit(build("--check" in sys.argv))
