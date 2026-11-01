#!/usr/bin/env python3
"""Cut Mayon's original tree and parallax atlases, preserving their genuine alpha.

Sources and exact generation prompts live in LEVEL5_Mayon/authored/. The generator
did not obey equal tree cells; these measured boxes own the sprite registration.
"""
import argparse
from pathlib import Path

from PIL import Image
import pixelart

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "LEVEL5_Mayon/authored"
OUTPUT = ROOT / "game/assets/Level5"
TREES = {
    "tree_broadleaf": ((0, 0, 900, 520), 360),
    "tree_tall": ((900, 0, 1536, 520), 400),
    "palm_pair": ((0, 520, 810, 1024), 350),
    "ash_snag": ((810, 520, 1536, 1024), 240),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    pictures = pixelart.Pictures(parser.parse_args().check, ROOT)
    trees = Image.open(SOURCE / "foothill_trees.png").convert("RGBA")
    for name, (box, height) in TREES.items():
        tree = trees.crop(box)
        bounds = tree.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
        if bounds is None:
            raise SystemExit(f"No tree alpha in {name}")
        tree = tree.crop(bounds)
        tree = tree.resize((round(tree.width * height / tree.height), height), Image.Resampling.NEAREST)
        pictures.put(tree, OUTPUT / "props" / f"{name}.png")
    ridges = Image.open(SOURCE / "parallax_ridges.png").convert("RGBA")
    for index, name in enumerate(("far_ridge", "forest_ridge")):
        # Keep each panorama's full width and transparent skyline. Runtime mirrors
        # alternate repeats, so the same edge always meets itself without a seam.
        pictures.put(ridges.crop((0, index * 512, 1536, (index + 1) * 512)),
                     OUTPUT / "backdrop" / f"{name}.png")
    if pictures.stale:
        raise SystemExit("Stale Mayon scenery: " + ", ".join(pictures.stale))


if __name__ == "__main__":
    main()
