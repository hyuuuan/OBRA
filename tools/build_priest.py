#!/usr/bin/env python3
"""Pack the supplied elderly priest into Piyesta's existing animation cells.

The original sheet and its transparent cutout sheet live in level-2-assets/priest/.
Background removal was done with imagegen; this builder only crops, fits and packs
those finished cutouts. It never draws a replacement face or robe.

The church expects 80 x 124 cells, a six-frame right-facing walk, a left-facing
conversation pose, and feet on row 123. Each authored pose is fitted once with
nearest-neighbour sampling; runtime scale stays 1. The large portrait is retained
at source resolution, with its own measured bust cut (250 / 352).

    python3 tools/build_priest.py
    python3 tools/build_priest.py --check
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "level-2-assets/priest/character_cutouts.png"
OUT = ROOT / "game/assets/characters/priest"
CELL = (80, 124)
FOOT_ROW = 123
HEIGHT = 122
PORTRAIT_CUT_ROW = 250

# Measured on the transparent sheet, excluding labels, shadows and adjacent poses.
# All walk crops share the same top and floor so the feet do not jitter vertically.
IDLE = (363, 107, 493, 349)
SIDE = (715, 107, 836, 349)  # Already faces left.
PORTRAIT = (59, 156, 256, 508)
WALK = [(x, 452, x + width, 661) for x, width in
        [(345, 126), (489, 130), (641, 124), (797, 118), (939, 126), (1086, 128)]]


def cell(sheet: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    pose = sheet.crop(box)
    width = round(pose.width * HEIGHT / pose.height)
    if width > CELL[0]:
        raise ValueError(f"Priest pose exceeds its animation cell: {box}")
    pose = pose.resize((width, HEIGHT), Image.Resampling.NEAREST)
    frame = Image.new("RGBA", CELL)
    frame.paste(pose, ((CELL[0] - width) // 2, FOOT_ROW - HEIGHT))
    return frame


def build() -> dict[str, Image.Image]:
    sheet = Image.open(SRC).convert("RGBA")
    if sheet.size != (1254, 1254) or sheet.getchannel("A").getextrema() != (0, 255):
        raise ValueError("Expected the registered 1254 x 1254 transparent cutout sheet")
    walk = Image.new("RGBA", (CELL[0] * len(WALK), CELL[1]))
    for index, box in enumerate(WALK):
        walk.paste(cell(sheet, box), (index * CELL[0], 0))
    return {
        "priest_idle.png": cell(sheet, IDLE),
        "priest_walk.png": walk,
        "priest_side.png": cell(sheet, SIDE),
        "priest_portrait.png": sheet.crop(PORTRAIT),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    images = build()
    if args.check:
        stale = []
        for name, expected in images.items():
            path = OUT / name
            if not path.exists():
                stale.append(name)
                continue
            with Image.open(path) as actual:
                if actual.size != expected.size or actual.convert("RGBA").tobytes() != expected.tobytes():
                    stale.append(name)
        if stale:
            print("stale: " + ", ".join(stale))
            return 1
        print(f"Priest assets are up to date ({len(images)} files)")
        return 0
    OUT.mkdir(parents=True, exist_ok=True)
    for name, image in images.items():
        image.save(OUT / name)
        print(f"wrote {(OUT / name).relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
