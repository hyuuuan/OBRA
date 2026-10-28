#!/usr/bin/env python3
"""Lola, standing in -- game/assets/Level5/people/.

A PLACEHOLDER (ART_PLACEHOLDERS.md). Lola has no art: she appears in the present for the first
time at Mayon's summit, and the design calls her sprite the most important work in the project.
Until the art team delivers it, she is the apo's own delivered turnaround, recoloured: the hair
greyed by its own light and shade, the shirt a pale baro, the shorts a dark saya. Same idiom,
same proportions, and a true back view -- she is painting with her back turned -- and a front
for when she turns around. Replace by name: lola_back.png, lola_front.png.

USAGE
    python3 tools/build_mayon_lola.py            # write
    python3 tools/build_mayon_lola.py --check    # verify the committed files are current
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))

import pixelart  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SHEET = ROOT / "game" / "assets" / "characters" / "apo" / "apo_turnaround.png"
OUT = ROOT / "game" / "assets" / "Level5" / "people"
## The turnaround's frames: 0 is her front, 4 her back.
FRAMES = {"lola_front": 0, "lola_back": 4}
CELL = 80
## The head ends here: browns above it are hair; below, the bag and strap stay as they are.
HEAD_ROWS = 50
BARO = np.array([236, 226, 214])
SAYA = np.array([92, 46, 66])
## Her face's peach, kept.
SKIN = np.array([233, 181, 118])
## Where her face can begin, from the top of the cell.
FACE_FROM = 24


def recoloured(frame: Image.Image) -> Image.Image:
    pix = np.asarray(frame.convert("RGBA")).astype(np.float64)
    rgb = pix[..., :3]
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    opaque = pix[..., 3] > 0
    rows = np.arange(pix.shape[0])[:, None] * np.ones(pix.shape[1])[None, :]
    # Browns and their sunlit oranges -- every tone of the hair -- but not her face: the skin is
    # one peach, and the cheeks are pink (green no higher than blue's reach).
    brown = (rgb[..., 0] > rgb[..., 2] + 35) & (rgb[..., 1] > rgb[..., 2] + 15) & (rgb[..., 0] >= rgb[..., 1])
    # (Only below the crown: the hair's own sunlit specks up top are as peach as her face.)
    skin = (np.abs(rgb - SKIN).max(axis=-1) <= 24) & (rows >= FACE_FROM)
    pink = (rgb[..., 0] > 200) & (rgb[..., 1] < 160)
    hair = opaque & brown & ~skin & ~pink & (rows < HEAD_ROWS)
    grey = np.clip(lum * 1.35 + 55, 0, 235)
    rgb[hair] = np.stack([grey, grey, grey * 1.02], -1)[hair]
    cream = opaque & (rgb[..., 0] > 200) & (rgb[..., 2] > 140) & (np.abs(rgb[..., 0] - rgb[..., 1]) < 30)
    rgb[cream] = BARO * (lum[cream] / 220.0)[:, None]
    blue = opaque & (rgb[..., 2] > rgb[..., 0] + 30)
    rgb[blue] = SAYA * (lum[blue] / 90.0)[:, None]
    pix[..., :3] = np.clip(rgb, 0, 255)
    return Image.fromarray(pix.astype(np.uint8), "RGBA")


def pose(name: str) -> Image.Image:
    sheet = Image.open(SHEET).convert("RGBA")
    index = FRAMES[name]
    return recoloured(sheet.crop((index * CELL, 0, (index + 1) * CELL, sheet.height)))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    pictures = pixelart.Pictures(args.check, ROOT)
    for name in FRAMES:
        pictures.put(pose(name), OUT / f"{name}.png")
    if args.check:
        if pictures.stale:
            print("stale or missing:\n  " + "\n  ".join(pictures.stale))
            return 1
        print("OK: lola is current")
        return 0
    print("wrote lola_front.png, lola_back.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
