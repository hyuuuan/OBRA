#!/usr/bin/env python3
"""The dialogue portraits, with their outlines drawn back on.

Kent: "the dialogue avatars for the characters have faulty drawing edges like the black
outlines of the characters are not visible making them like cut off or like broken in bits".
`lolo_portrait.png` and `apo_portrait.png` were cut from their design sheets with the
background knocked out, and the knock-out took most of the outline with it: Lolo's survives
as slivers with gaps between them, the apo's hardly at all, so a speaker blown up behind the
dialogue box looked chipped. (The Padre's portrait came from its own sheet with its outline
whole, and is the measure: 6% of its silhouette's edge is light, where Lolo's was 19%.)

So each is redrawn here, not hand-patched:

  * the body is everything solid, opened by a small square so the loose slivers of the old
    outline fall away, and its enclosed holes filled;
  * a ring OUTLINE pixels wide is laid round it in ink -- a square ring, so it follows the
    figure in steps the way a pixel-art outline does -- on a canvas grown by OUTLINE on every
    side so the ring is never cut off at the picture's edge;
  * and written beside the original as `*_portrait_outlined.png`. The originals are
    tools/build_art.py's, and stay as it makes them.

Usage:
    python3 tools/build_portrait_outlines.py           # writes the outlined portraits
    python3 tools/build_portrait_outlines.py --check   # compares, writes nothing, exit 1 if stale
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelart import Pictures   # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
CHARACTERS = ROOT / "game" / "assets" / "characters"
SPEAKERS = ["lolo", "apo"]
## As wide as the Padre's own outline at the size both are shown.
OUTLINE = 7
## Anything thinner than this many pixels each side of its middle is a sliver, not the figure.
CLEAN = 2
INK = (20, 16, 12, 255)


def outlined(source: Image.Image) -> Image.Image:
    padded = Image.new("RGBA", (source.width + OUTLINE * 2, source.height + OUTLINE * 2))
    padded.paste(source.convert("RGBA"), (OUTLINE, OUTLINE))
    picture = np.asarray(padded).copy()
    body = picture[..., 3] > 128
    body = ndimage.binary_opening(body, structure=np.ones((CLEAN * 2 + 1, CLEAN * 2 + 1)))
    body = ndimage.binary_fill_holes(body)
    ring = ndimage.binary_dilation(body, structure=np.ones((OUTLINE * 2 + 1, OUTLINE * 2 + 1))) & ~body
    out = np.zeros_like(picture)
    out[body] = picture[body]
    out[body, 3] = 255
    out[ring] = INK
    return Image.fromarray(out, "RGBA")


def main(check: bool) -> int:
    pictures = Pictures(check=check, root=ROOT)
    for speaker in SPEAKERS:
        source = Image.open(CHARACTERS / speaker / f"{speaker}_portrait.png")
        pictures.put(outlined(source), CHARACTERS / speaker / f"{speaker}_portrait_outlined.png")
    if pictures.stale:
        print("stale, re-run tools/build_portrait_outlines.py:")
        for rel in pictures.stale:
            print("   ", rel)
        return 1
    print("%s %d outlined portraits" % ("checked" if check else "wrote", len(SPEAKERS)))
    return 0


if __name__ == "__main__":
    sys.exit(main("--check" in sys.argv))
