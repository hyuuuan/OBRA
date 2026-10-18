#!/usr/bin/env python3
"""Draw Dilim's creatures as animated pixel strips: the aswang as a dog and as a pig.

WHY CODE-DRAWN
--------------
The Makiling delivery is forest plates and a tileset -- it has no creatures in it -- and Kent's
call (2026-10-16) was code-drawn pixel strips now, replaceable by drawn art later without a code
change: Enemy2D loads `<kind>_<anim>.png` and falls back to its placeholder body for anything
missing. So a delivered `aswang_dog_run.png` simply wins.

HOW THEY ARE DRAWN
------------------
In the project's own idiom (tools/pixelart.py): a 24 x 24 logical grid scaled by PX = 2 to a
48 px frame, short ramps, light from the upper left. These are things seen in the dark: dark,
cold violet bodies with a paler edge light, and the EYES the one warm colour on them -- amber,
which is also the windup glint's colour, so a player learns to watch the eyes. Facing right;
the game mirrors them.

DARK, NOT BLACK. The darkness is the level's job, not the creature's: Dilim's design ties
seeing them to her lantern ("near dark ... when the aswangs are most dangerous and most
invisible"), and the dark layer already hides whatever stands beyond its light. Bodies drawn
near-black (fill #0f0c16) disappeared inside the light too, against the night forest, leaving
only an eye and a glint. So the body is dark enough to stay sinister and light enough to read
wherever her lantern reaches.

Every strip is one row of frames: idle 2, run 4, windup 2, attack 2, hurt 1, death 3.

USAGE
    python3 tools/build_dilim_creatures.py            # write game/assets/Level4/creatures/
    python3 tools/build_dilim_creatures.py --check    # verify the committed strips are current
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import numpy as np
from PIL import Image

import pixelart
from pixelart import Canvas, ramp

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "Level4" / "creatures"

GRID = 24
FRAME = GRID * pixelart.PX
## The row the feet stand on, in logical pixels: the frame's bottom edge is GROUND + 1.
GROUND = 21

ANIMS = {"idle": 2, "run": 4, "windup": 2, "attack": 2, "hurt": 1, "death": 3}

# Dark bodies with a cold edge light; the eye is the only warm thing on them. Dark, not black:
# see DARK, NOT BLACK above.
HIDE = ramp(["#1a1424", "#2b2238", "#3d3150", "#5e4f7a", "#857aa6"])
EYE = ramp(["#b8641c", "#ffbd3d", "#fff0c0"])
MOUTH = ramp(["#3a0d14", "#7a1f2b"])
TUSK = ramp(["#8f8670", "#d9cfae"])
HURT = ramp(["#5a1a22", "#c43a3a"])


def ellipse(canvas: Canvas, cx: float, cy: float, rx: float, ry: float, colour: np.ndarray) -> None:
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                canvas.px(x, y, colour)


def edge_light(canvas: Canvas) -> None:
    """Light from the upper left: the top-left rim of every filled shape gets the highest step,
    the bottom-right rim the lowest -- the one rule that makes separate parts read as one body."""
    alpha = canvas.buf[..., 3] > 0
    top = alpha & ~np.roll(alpha, 1, axis=0)
    left = alpha & ~np.roll(alpha, 1, axis=1)
    bottom = alpha & ~np.roll(alpha, -1, axis=0)
    hide = np.all(canvas.buf[..., :3] == HIDE[1][:3], axis=-1)
    canvas.buf[(top | left) & hide] = HIDE[3]
    canvas.buf[bottom & hide] = HIDE[0]


def leg(canvas: Canvas, x: int, top: int, lift: int, reach: int) -> None:
    """A two-pixel leg from the body down to the ground, its foot lifted and pushed by the pose."""
    foot_y = GROUND - lift
    for y in range(top, foot_y + 1):
        t = (y - top) / max(1, foot_y - top)
        lx = x + round(reach * t)
        canvas.fill(lx, y, 2, 1, HIDE[1])
    canvas.fill(x + reach - 1, foot_y, 3, 1, HIDE[0])


# --- the dog ------------------------------------------------------------------------------

## (front lift, front reach, back lift, back reach) per run frame: a gallop's gather and spread.
DOG_RUN = [(0, 2, 2, -2), (2, 0, 0, 0), (0, -2, 1, 2), (1, 0, 0, 0)]


def draw_dog(anim: str, frame: int) -> Canvas:
    canvas = Canvas(GRID, GRID, seed=pixelart.SEED + frame)
    drop = 0
    stretch = 0
    legs = (0, 0, 0, 0)
    if anim == "idle":
        drop = frame % 2
    elif anim == "run":
        legs = DOG_RUN[frame]
        drop = 1 if frame % 2 else 0
    elif anim == "windup":
        drop = 2 + frame
        legs = (0, -1, 0, 1)
    elif anim == "attack":
        stretch = 2
        legs = (3, 3, 2, -3) if frame == 0 else (1, 2, 1, -2)
        drop = -2 if frame == 0 else -1
    elif anim == "hurt":
        drop = 1
        legs = (0, -1, 0, -1)
    elif anim == "death":
        drop = 3 + frame * 2
        legs = (0, 2 + frame, 0, -2 - frame)
    body_y = 12 + drop
    # Legs first, so the body sits over their tops.
    leg(canvas, 15 + stretch, body_y + 2, legs[0], legs[1])
    leg(canvas, 13 + stretch, body_y + 2, max(0, legs[0] - 1), legs[1] - 1)
    leg(canvas, 7 - stretch, body_y + 2, legs[2], legs[3])
    leg(canvas, 5 - stretch, body_y + 2, max(0, legs[2] - 1), legs[3] + 1)
    # A lean body with a high hunched shoulder: wrong, the way an aswang dog is wrong.
    ellipse(canvas, 11.5, body_y + 0.5, 7.0 + stretch, 3.0, HIDE[1])
    ellipse(canvas, 14.5, body_y - 1.5, 3.0, 2.5, HIDE[1])
    head_y = body_y - 3 + (1 if anim == "windup" else 0)
    ellipse(canvas, 18.5 + stretch, head_y + 0.5, 2.8, 2.2, HIDE[1])
    canvas.fill(20 + stretch, head_y, 3, 2, HIDE[1])
    canvas.px(18 + stretch, head_y - 2, HIDE[1])
    canvas.px(17 + stretch, head_y - 3, HIDE[1])
    # A thin tail held low behind.
    for i in range(4):
        canvas.px(4 - stretch - i, body_y - 1 + i // 2, HIDE[1])
    edge_light(canvas)
    open_mouth = anim in ("windup", "attack")
    if open_mouth:
        canvas.fill(20 + stretch, head_y + 2, 3, 1, MOUTH[1])
    if anim == "hurt":
        canvas.px(19 + stretch, head_y, HURT[1])
    elif anim != "death" or frame == 0:
        canvas.px(19 + stretch, head_y, EYE[1])
        canvas.px(20 + stretch, head_y, EYE[2] if anim in ("windup", "attack") else EYE[0])
    return canvas


# --- the pig ------------------------------------------------------------------------------

PIG_RUN = [(0, 1, 1, -1), (1, 0, 0, 0), (0, -1, 1, 1), (1, 0, 0, 0)]


def draw_pig(anim: str, frame: int) -> Canvas:
    canvas = Canvas(GRID, GRID, seed=pixelart.SEED + 100 + frame)
    drop = 0
    stretch = 0
    legs = (0, 0, 0, 0)
    if anim == "idle":
        drop = frame % 2
    elif anim == "run":
        legs = PIG_RUN[frame]
        drop = frame % 2
    elif anim == "windup":
        drop = 1 + frame
        legs = (0, -1, 0, 1)
    elif anim == "attack":
        stretch = 2
        legs = (2, 2, 1, -2) if frame == 0 else (1, 1, 0, -1)
        drop = -1
    elif anim == "hurt":
        drop = 1
    elif anim == "death":
        drop = 2 + frame * 2
        legs = (0, 1 + frame, 0, -1 - frame)
    body_y = 13 + drop
    leg(canvas, 15 + stretch, body_y + 3, legs[0], legs[1])
    leg(canvas, 12 + stretch, body_y + 3, max(0, legs[0] - 1), legs[1])
    leg(canvas, 7 - stretch, body_y + 3, legs[2], legs[3])
    leg(canvas, 4 - stretch, body_y + 3, max(0, legs[2] - 1), legs[3])
    # Heavy and low: a barrel of a body with a ridge of bristles along the back.
    ellipse(canvas, 10.5, body_y + 0.5, 8.0 + stretch, 4.5, HIDE[1])
    for x in range(5, 16, 2):
        canvas.px(x, body_y - 4 - (x % 4 == 1), HIDE[1])
    head_y = body_y - 1 + (1 if anim == "windup" else 0)
    ellipse(canvas, 18.5 + stretch, head_y + 0.5, 3.2, 3.0, HIDE[1])
    canvas.fill(21 + stretch, head_y, 2, 3, HIDE[2])
    canvas.px(17 + stretch, head_y - 3, HIDE[1])
    edge_light(canvas)
    canvas.px(22 + stretch, head_y + 3, TUSK[1])
    canvas.px(23 + stretch, head_y + 2, TUSK[0])
    if anim == "hurt":
        canvas.px(19 + stretch, head_y - 1, HURT[1])
    elif anim != "death" or frame == 0:
        canvas.px(19 + stretch, head_y - 1, EYE[2] if anim in ("windup", "attack") else EYE[1])
    return canvas


KINDS = {"aswang_dog": draw_dog, "aswang_pig": draw_pig}


def strip(kind: str, anim: str) -> Image.Image:
    frames = [KINDS[kind](anim, index).image() for index in range(ANIMS[anim])]
    sheet = Image.new("RGBA", (FRAME * len(frames), FRAME), (0, 0, 0, 0))
    for index, picture in enumerate(frames):
        sheet.paste(picture, (index * FRAME, 0))
    return sheet


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="compare, do not write")
    args = ap.parse_args()
    pictures = pixelart.Pictures(args.check, ROOT)
    for kind in KINDS:
        for anim in ANIMS:
            pictures.put(strip(kind, anim), OUT / f"{kind}_{anim}.png")
    if args.check:
        if pictures.stale:
            print("stale or missing:\n  " + "\n  ".join(pictures.stale))
            return 1
        print(f"OK: {len(KINDS) * len(ANIMS)} creature strips are current")
        return 0
    print(f"wrote {len(KINDS) * len(ANIMS)} strips to {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
