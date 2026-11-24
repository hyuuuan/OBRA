#!/usr/bin/env python3
"""The mano: the apo takes Lola's hand and touches it to the forehead (the ending, the house).

The cultural panel asked that the game's ending show the respect a Filipino child shows an elder
(Chapter 5, Table 34): when the apo comes home, the first thing done is the mano -- "Mano po,
Lola" -- the elder's hand lifted to the bowed forehead. There is no delivered art for it, so the
two cells are made from poses already in the game:

  * apo_mano.png -- Mayon's `apo_lower` (bowed, facing right), the brush taken out of the hand,
                    and the near arm drawn lifting to the forehead;
  * lola_mano.png -- Lola's `front`, her right hand (screen left) brought out from her side and
                    held out at the height of the apo's bowed head.

HOW THE TWO MEET. The hands are drawn so that when the apo's cell (112 x 112, drawn at (0, -56)
from the feet, as Mayon's performances are) stands GAP pixels left of Lola's (128 x 144, drawn at
(0, -72)), the apo's hand closes over Lola's. HouseEpilogue reads `MANO_GAP` for that distance.

    python3 tools/build_mano_poses.py
    python3 tools/build_mano_poses.py --check
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
PEOPLE = ROOT / "game/assets/Level5/people"

OUTLINE = (34, 20, 14, 255)
APO_SKIN = (232, 166, 112, 255)
APO_SKIN_LIT = (246, 196, 146, 255)
APO_SLEEVE = (226, 214, 178, 255)
LOLA_SKIN = (234, 168, 115, 255)
LOLA_SKIN_LIT = (246, 198, 150, 255)
LOLA_SLEEVE = (236, 210, 166, 255)
LOLA_SLEEVE_SHADE = (206, 178, 132, 255)

## Where the two hands meet, in each cell's own pixels.
APO_HAND = (75, 50)
LOLA_HAND = (19, 81)
## The cells' centres, as Sprite2D centres them.
APO_CENTRE_X = 56
LOLA_CENTRE_X = 64
## How far right of the apo's feet Lola's feet stand for the hands to meet:
## apo hand x - apo centre = lola hand x - lola centre + gap.
MANO_GAP = (APO_HAND[0] - APO_CENTRE_X) - (LOLA_HAND[0] - LOLA_CENTRE_X)


def _outline_round(a: np.ndarray, rows: range, cols: range) -> None:
    """Put the dark edge back where a drawn pixel now meets the empty air."""
    h, w, _ = a.shape
    alpha = a[..., 3] > 0
    for y in rows:
        for x in cols:
            if alpha[y, x]:
                continue
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                yy, xx = y + dy, x + dx
                if 0 <= yy < h and 0 <= xx < w and alpha[yy, xx] and tuple(a[yy, xx]) != OUTLINE:
                    a[y, x] = OUTLINE
                    break


def apo_mano() -> Image.Image:
    image = Image.open(PEOPLE / "apo_lower.png").convert("RGBA")
    a = np.array(image)
    # The brush, which apo_lower trails from the hand to the floor: everything right of the
    # shorts, below the hand. The hand itself stays, at the far side.
    a[89:101, 53:112] = 0
    image = Image.fromarray(a)
    draw = ImageDraw.Draw(image)
    # ⚠ IN FRONT OF THE FACE, NOT ON IT. Meeting on the face read as the apo hiding it; the
    # hands meet just ahead of the bowed forehead, and the forearm rises past the chin.
    shoulder = (50, 67)
    elbow = (66, 67)
    hand = APO_HAND
    # The arm: an outline stroke, then skin over it, then the sleeve at the shoulder.
    draw.line([shoulder, elbow, hand], fill=OUTLINE, width=6, joint="curve")
    draw.line([shoulder, elbow, hand], fill=APO_SKIN, width=3, joint="curve")
    draw.line([(shoulder[0] + 1, shoulder[1] - 1), (elbow[0], elbow[1] - 1)], fill=APO_SKIN_LIT, width=1)
    draw.line([(shoulder[0] - 1, shoulder[1]), (shoulder[0] + 5, shoulder[1])], fill=OUTLINE, width=6)
    draw.line([(shoulder[0] - 1, shoulder[1]), (shoulder[0] + 4, shoulder[1])], fill=APO_SLEEVE, width=4)
    # The hand, closed round Lola's: a knuckle row lit from the upper left.
    draw.rectangle([hand[0] - 3, hand[1] - 3, hand[0] + 3, hand[1] + 3], fill=OUTLINE)
    draw.rectangle([hand[0] - 2, hand[1] - 2, hand[0] + 2, hand[1] + 2], fill=APO_SKIN)
    draw.line([(hand[0] - 2, hand[1] - 2), (hand[0] + 1, hand[1] - 2)], fill=APO_SKIN_LIT)
    return image


def lola_mano() -> Image.Image:
    image = Image.open(PEOPLE / "lola_front.png").convert("RGBA")
    a = np.array(image)
    # Her near hand, which hangs at her side below the sleeve: taken out, and the edge redrawn.
    a[100:117, 30:47] = 0
    _outline_round(a, range(98, 118), range(28, 50))
    image = Image.fromarray(a)
    draw = ImageDraw.Draw(image)
    shoulder = (45, 92)
    elbow = (34, 92)
    hand = LOLA_HAND
    draw.line([shoulder, elbow, hand], fill=OUTLINE, width=7, joint="curve")
    draw.line([shoulder, elbow], fill=LOLA_SLEEVE, width=4)
    draw.line([(shoulder[0], shoulder[1] + 1), (elbow[0], elbow[1] + 1)], fill=LOLA_SLEEVE_SHADE, width=1)
    draw.line([elbow, hand], fill=LOLA_SKIN, width=3)
    # The hand held out, back up, for the apo to take.
    draw.rectangle([hand[0] - 3, hand[1] - 2, hand[0] + 2, hand[1] + 3], fill=OUTLINE)
    draw.rectangle([hand[0] - 2, hand[1] - 1, hand[0] + 1, hand[1] + 2], fill=LOLA_SKIN)
    draw.line([(hand[0] - 2, hand[1] - 1), (hand[0] + 1, hand[1] - 1)], fill=LOLA_SKIN_LIT)
    return image


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="fail if the cells are stale")
    args = parser.parse_args()
    stale = []
    for name, image in (("apo_mano.png", apo_mano()), ("lola_mano.png", lola_mano())):
        path = PEOPLE / name
        if args.check:
            if not path.exists() or not np.array_equal(np.asarray(Image.open(path).convert("RGBA")),
                                                       np.asarray(image)):
                stale.append(name)
            continue
        image.save(path)
        print(f"wrote {path.relative_to(ROOT)} {image.size}")
    print(f"MANO_GAP = {MANO_GAP}")
    if stale:
        print("stale: " + ", ".join(stale), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
