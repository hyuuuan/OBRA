#!/usr/bin/env python3
"""The Ifugao guardian at Ang Bale: a stand-in, repainted from Lola's own sheet.

Payyo's bale had two carved bulul in front of it, which said nothing about the house. The
cultural panel asked for more everyday Ifugao life, and the guardian replaced them: an elder
woman who keeps Lola's house in the painting and tells the apo how a bale is built
(ART_PLACEHOLDERS.md, "The Ifugao guardian").

There is no delivered art for her, so she is Lola's front pose and portrait repainted by
material, in the same hand and at the same scale as the people already in the game:

  * hair      -- near-black with grey in it, not Lola's silver, so the two never read as one;
  * skin      -- a shade deeper;
  * top       -- indigo, Lola's embroidered flower dissolved into it;
  * skirt     -- a wrap skirt in red and black bands with a thin pale line, the colours of an
                 Ifugao woven skirt (the bahag and full regional dress are deferred, Table 34);
  * beads     -- a short string of red and yellow at the collar.

⚠ LOLA'S ART IS NOT A PALETTE. It is soft-edged (about 4,600 colours), so a colour swap misses
most of it. Each pixel is sorted by WHERE it is (head, torso, skirt band) and, for skin, by
saturation: the cream top shares the skin's hue but not its saturation (0.31 against 0.51).
Each class keeps its own pixel's lightness on the new ramp, so the shading survives.

    python3 tools/build_payyo_guardian.py
    python3 tools/build_payyo_guardian.py --check
"""
from __future__ import annotations

import argparse
import colorsys
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "game/assets/Level5/people"
OUT = ROOT / "game/assets/Level1/people"

## Per source: the last row of the head, the skirt's rows (None for the bust), the row, span and
## thickness the beads are strung across, and the columns her hands lie outside of.
JOBS = {
    "guardian.png": {
        "src": "lola_front.png", "head_end": 87, "skirt": (115, 131),
        "beads": (89, 58, 77, 1), "hands": (49, 78),
    },
    "guardian_portrait.png": {
        "src": "lola_portrait.png", "head_end": 166, "skirt": None,
        "beads": (171, 80, 150, 2), "hands": (60, 158),
    },
}

OUTLINE_V = 0.3
## Skin is orange and saturated; the cream top is the same hue and much paler.
SKIN_SAT = 0.42
SKIN_HUE = (0.03, 0.11)

HAIR = [(18, 16, 20), (40, 36, 42), (70, 66, 72), (118, 114, 120), (170, 166, 172)]
TOP = [(20, 20, 40), (30, 32, 62), (42, 46, 86), (58, 64, 112), (80, 88, 140)]
RED = [(70, 14, 16), (120, 26, 26), (168, 40, 34), (204, 66, 48)]
BLACK = [(14, 12, 14), (30, 26, 30), (48, 42, 46), (66, 60, 62)]
PALE = [(150, 140, 120), (196, 186, 160), (228, 220, 196), (240, 234, 214)]
BEADS = [(196, 40, 36), (232, 186, 60), (196, 40, 36), (236, 228, 210)]


def _on_ramp(ramp: list[tuple[int, int, int]], v: float) -> tuple[int, int, int]:
    """The ramp step a lightness of `v` (0..1) lands on: shading kept, colour replaced."""
    index = min(len(ramp) - 1, max(0, int(v * len(ramp))))
    return ramp[index]


def _skirt_band(row: int, top: int) -> list[tuple[int, int, int]]:
    """Red, a black band, a pale line, repeating down the skirt: 4 + 2 + 1 rows."""
    phase = (row - top) % 7
    if phase < 4:
        return RED
    if phase < 6:
        return BLACK
    return PALE


def repaint(source: Image.Image, head_end: int, skirt: tuple[int, int] | None,
            beads: tuple[int, int, int, int], hands: tuple[int, int]) -> Image.Image:
    a = np.array(source.convert("RGBA"))
    out = a.copy()
    height, width, _ = a.shape
    for y in range(height):
        for x in range(width):
            r, g, b, alpha = (int(c) for c in a[y, x])
            if alpha == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            if v < OUTLINE_V:
                continue
            orange = SKIN_HUE[0] <= h <= SKIN_HUE[1]
            # ⚠ Below the head, skin is only her hands. Lola's embroidered flower and the gold
            # hem of her top are saturated warm colours too, and came out as patches of skin.
            where_skin_can_be = y <= head_end or x < hands[0] or x > hands[1]                 or (skirt is not None and y > skirt[1])
            if orange and s >= SKIN_SAT and v > 0.6 and where_skin_can_be:
                # A shade deeper, browner.
                out[y, x, :3] = (int(r * 0.80), int(g * 0.72), int(b * 0.66))
                continue
            if y <= head_end:
                out[y, x, :3] = _on_ramp(HAIR, v * 0.85)
            elif skirt is not None and skirt[0] <= y <= skirt[1]:
                out[y, x, :3] = _on_ramp(_skirt_band(y, skirt[0]), v * 1.25)
            elif skirt is not None and y > skirt[1]:
                continue  # legs and sandals stay as drawn
            else:
                out[y, x, :3] = _on_ramp(TOP, v * 0.95)
    row, left, right, thick = beads
    for index, x in enumerate(range(left, right, 3 * thick)):
        # A string that sags in the middle, and only on the figure, never on empty air.
        middle = (left + right) / 2.0
        y = row + int(round(2.0 * thick * (1.0 - abs(x - middle) / max(1.0, middle - left))))
        for dy in range(thick):
            for dx in range(2 * thick):
                if x + dx < width and out[y + dy, x + dx, 3]:
                    out[y + dy, x + dx, :3] = BEADS[index % len(BEADS)]
    return Image.fromarray(out)


def build() -> dict[str, Image.Image]:
    made = {}
    for name, job in JOBS.items():
        source = Image.open(SRC / job["src"])
        made[name] = repaint(source, job["head_end"], job["skirt"], job["beads"], job["hands"])
    return made


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="fail if the files are stale")
    args = parser.parse_args()
    made = build()
    stale = []
    for name, image in made.items():
        path = OUT / name
        if args.check:
            if not path.exists() or not np.array_equal(np.array(Image.open(path).convert("RGBA")),
                                                       np.array(image)):
                stale.append(name)
            continue
        OUT.mkdir(parents=True, exist_ok=True)
        image.save(path)
        print(f"wrote {path.relative_to(ROOT)} {image.size}")
    if stale:
        print("stale: " + ", ".join(stale), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
