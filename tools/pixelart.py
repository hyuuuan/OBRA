#!/usr/bin/env python3
"""The pixel-art library Piyesta's authored art is drawn with.

WHAT 8-BIT MEANS HERE, CONCRETELY
---------------------------------
Everything is drawn on a LOGICAL PIXEL GRID and scaled up by `PX` with nearest-neighbour, so
every mark in the output is a hard square block and nothing is ever antialiased. Colour comes
from short ramps -- five or six steps per material, no more -- and gradients are made with an
ordered Bayer dither between two adjacent steps rather than by interpolating, which is the
difference between pixel art and a photograph of pixel art.

Light is from the UPPER LEFT everywhere: the top and left edge of any raised thing carries
the next ramp step up, the bottom and right edge the next step down. That one rule is most of
what makes a set of separately drawn pieces look like they belong together.

Shared by `build_interiors.py` (the four insides) and `build_plaza_art.py` (the plaza), so
the two cannot drift into two different idioms.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

## One authored pixel is this many output pixels.
PX = 2
## The default stream. Every tool seeds its own canvases anyway; this is only so a Canvas
## made without one is still deterministic.
SEED = 20260831

## Ordered dither. The classic 4x4 Bayer matrix, normalised.
BAYER = np.array([
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
], dtype=np.float32) / 16.0


def ramp(hexes: list[str]) -> np.ndarray:
    out = np.zeros((len(hexes), 4), dtype=np.uint8)
    for index, value in enumerate(hexes):
        out[index] = [int(value[1:3], 16), int(value[3:5], 16), int(value[5:7], 16), 255]
    return out


class Canvas:
    """A grid of logical pixels holding RGBA directly.

    Kept as RGBA rather than palette indices because the rooms mix materials -- an iron rack
    against limestone -- and one shared index space across every ramp would be a fifth thing
    to keep in step for no gain.
    """

    def __init__(self, width: int, height: int, seed: int = SEED) -> None:
        self.w = width
        self.h = height
        self.buf = np.zeros((height, width, 4), dtype=np.uint8)
        self.rng = np.random.default_rng(seed)

    # -- primitives ------------------------------------------------------------------
    def fill(self, x: int, y: int, w: int, h: int, colour: np.ndarray) -> None:
        x0, y0 = max(0, x), max(0, y)
        x1, y1 = min(self.w, x + w), min(self.h, y + h)
        if x1 > x0 and y1 > y0:
            self.buf[y0:y1, x0:x1] = colour

    def px(self, x: int, y: int, colour: np.ndarray) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.buf[y, x] = colour

    def hline(self, x: int, y: int, w: int, colour: np.ndarray) -> None:
        self.fill(x, y, w, 1, colour)

    def vline(self, x: int, y: int, h: int, colour: np.ndarray) -> None:
        self.fill(x, y, 1, h, colour)

    def dither(self, x: int, y: int, w: int, h: int, lo: np.ndarray, hi: np.ndarray,
               amount: np.ndarray | float) -> None:
        """Blend two ramp steps with an ordered dither -- the 8-bit way to make a gradient."""
        ys, xs = np.mgrid[y:y + h, x:x + w]
        threshold = BAYER[ys % 4, xs % 4]
        pick = (np.asarray(amount) > threshold)
        region = np.where(pick[..., None], hi, lo).astype(np.uint8)
        x0, y0 = max(0, x), max(0, y)
        x1, y1 = min(self.w, x + w), min(self.h, y + h)
        self.buf[y0:y1, x0:x1] = region[y0 - y:y1 - y, x0 - x:x1 - x]

    def speckle(self, x: int, y: int, w: int, h: int, colour: np.ndarray,
                density: float) -> None:
        count = int(w * h * density)
        for _ in range(count):
            self.px(x + int(self.rng.integers(0, w)), y + int(self.rng.integers(0, h)), colour)

    def image(self) -> Image.Image:
        """The canvas at its shipped size: scaled up by PX with nearest-neighbour."""
        image = Image.fromarray(self.buf, "RGBA")
        return image.resize((self.w * PX, self.h * PX), Image.NEAREST)

    def save(self, path: Path) -> tuple[int, int]:
        image = self.image()
        image.save(path)
        return image.size


class Pictures:
    """Where a tool's pictures go: written, or under --check compared with what is there.

    ⚠ A CHECK THAT WRITES IS NOT A CHECK. `build_plaza_art.py --check` and
    `build_interiors.py --check` skipped only their manifests: every PNG was drawn and SAVED
    over the committed one, and the run always said it was fine. The redraw happened to match,
    but a hand-edited picture would have been overwritten by the command meant to look at it.
    Checking compares PIXELS, not bytes -- the committed PNGs were encoded by another Pillow, so
    their bytes differ while every pixel is the same.
    """

    def __init__(self, check: bool, root: Path) -> None:
        self.check = check
        self.root = root
        self.stale: list[str] = []

    def put(self, image: Image.Image, path: Path) -> None:
        if not self.check:
            path.parent.mkdir(parents=True, exist_ok=True)
            image.save(path)
            return
        if not same_pixels(image, path):
            self.stale.append(str(path.relative_to(self.root)))


def same_pixels(image: Image.Image, path: Path) -> bool:
    """Whether the PNG at `path` holds exactly these pixels, alpha included."""
    if not path.exists():
        return False
    with Image.open(path) as old:
        if old.size != image.size:
            return False
        return np.array_equal(np.asarray(old.convert("RGBA")), np.asarray(image.convert("RGBA")))
