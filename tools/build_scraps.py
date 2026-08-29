#!/usr/bin/env python3
"""Tear Level2_CompletedLook into the seven pieces the player puts back together.

WHY THIS EXISTS
---------------
Scene 3 is the end of Piyesta: seven scraps of Lola's painting go into seven slots and the
picture is whole again. The design is specific about how they are cut --

    "Cut the seven scrap shapes from Level2_CompletedLook along irregular tear lines, not a
    grid. If two of them are the pieces that were strung up in the bandaritas, they can
    carry a slightly different weathering."

-- and it is specific for a reason. A grid is a jigsaw, and a jigsaw at the end of a level
is one more obstacle to get past. Torn paper is a thing being mended.

HOW THE TEAR IS MADE
--------------------
Voronoi on seven seeds gives seven regions with straight boundaries, which is a grid wearing
a different hat. So the distance to each seed is PERTURBED BY LOW-FREQUENCY NOISE before the
nearest one is chosen: two octaves of smoothed value noise, sampled at the pixel. Where the
noise is high a seed reaches further, where it is low it retreats, and the boundary between
any two regions wanders by tens of pixels instead of running straight. That is what a tear
looks like, and it costs one array per octave.

The seeds are placed on a jittered 4-3 stagger rather than at random: seven random points in
a 16:9 rectangle reliably produce one sliver and one piece half the picture wide, and the
player has to be able to pick every one of them up.

WHAT COMES OUT
--------------
`game/assets/Level2/scraps/scrap_0.png` .. `scrap_6.png`, each cropped to its own bounding
box with alpha outside the tear, plus `scraps.json` carrying:

  * `size`      -- the painting's own size, so the overlay can lay slots out proportionally
  * `pieces[]`  -- id, file, the bbox offset (WHICH IS THE SLOT POSITION -- a piece belongs
                   exactly where it was cut from), and its size

⚠ THE IDS MATCH THE LEDGER'S. `ScrapLedger` hands out `alley1_0`..`alley1_4` and
`alley2_0`..`alley2_1`, and `ScrapAssembly` matches a slot by ID, not by geometry. So the
two bandarita pieces are `alley2_*` by construction: they are the two the tool weathers
differently, which is the design's own suggestion and also makes the mapping legible when
somebody opens the folder.

    python3 tools/build_scraps.py [--check]
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "game" / "assets" / "Level2" / "completed_look.png"
OUT_DIR = ROOT / "game" / "assets" / "Level2" / "scraps"
MANIFEST = OUT_DIR / "scraps.json"

# The ledger's own ids, in the order the pieces are laid out. Five come off the birds in
# Alley 1 and two off the bandaritas in Alley 2 -- see ScrapLedger.
PIECE_IDS = [
    "alley1_0", "alley1_1", "alley1_2", "alley1_3", "alley1_4",
    "alley2_0", "alley2_1",
]
# The two that were strung up outdoors. Weathered a little more, per the design.
WEATHERED = {"alley2_0", "alley2_1"}

# Fixed, so a rebuild produces the same tear and the slot positions in scraps.json stay
# true for anything already authored against them.
SEED = 20260830

# How far the tear wanders, in pixels of the source. Big enough to read as torn at the size
# a scrap is drawn on screen, small enough that no piece grows a peninsula.
WANDER = 130.0


def _value_noise(shape: tuple[int, int], cells: tuple[int, int], rng) -> np.ndarray:
    """Smoothed value noise: random values on a coarse lattice, cosine-interpolated up.

    Cheap, dependency-free, and the only property that matters here is that it is SMOOTH --
    white noise would fray the boundary into static rather than tearing it.
    """
    gy, gx = cells
    lattice = rng.random((gy + 1, gx + 1))
    ys = np.linspace(0.0, gy, shape[0], endpoint=False)
    xs = np.linspace(0.0, gx, shape[1], endpoint=False)
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    fy = (ys - y0)[:, None]
    fx = (xs - x0)[None, :]
    # Cosine easing, which is what keeps the lattice from showing as diamonds.
    fy = (1.0 - np.cos(fy * np.pi)) * 0.5
    fx = (1.0 - np.cos(fx * np.pi)) * 0.5
    top = lattice[y0][:, x0] * (1.0 - fx) + lattice[y0][:, x0 + 1] * fx
    bottom = lattice[y0 + 1][:, x0] * (1.0 - fx) + lattice[y0 + 1][:, x0 + 1] * fx
    return top * (1.0 - fy) + bottom * fy


def _seed_points(width: int, height: int, rng) -> np.ndarray:
    """Seven seeds on a jittered 4-over-3 stagger.

    Not random: seven uniform points in a 16:9 rectangle reliably give one sliver and one
    piece half the picture wide, and every piece has to be big enough to pick up and small
    enough to carry.
    """
    rows = [4, 3]
    points = []
    for row_index, count in enumerate(rows):
        cy = height * (row_index + 0.5) / len(rows)
        for column in range(count):
            cx = width * (column + 0.5) / count
            points.append((
                cx + (rng.random() - 0.5) * width * 0.10,
                cy + (rng.random() - 0.5) * height * 0.16,
            ))
    return np.array(points, dtype=np.float64)


def _labels(width: int, height: int, rng) -> np.ndarray:
    """Which piece each pixel belongs to."""
    points = _seed_points(width, height, rng)
    ys = np.arange(height)[:, None].astype(np.float64)
    xs = np.arange(width)[None, :].astype(np.float64)
    # Two octaves: the first tears, the second roughens the tear.
    noise = (_value_noise((height, width), (5, 8), rng) - 0.5) * WANDER
    noise += (_value_noise((height, width), (13, 21), rng) - 0.5) * (WANDER * 0.45)
    best = None
    best_distance = None
    for index, (px, py) in enumerate(points):
        distance = np.hypot(xs - px, ys - py) + noise
        if best is None:
            best = np.full((height, width), index, dtype=np.uint8)
            best_distance = distance
            continue
        closer = distance < best_distance
        best = np.where(closer, np.uint8(index), best)
        best_distance = np.where(closer, distance, best_distance)
    return best


def _weather(piece: np.ndarray) -> np.ndarray:
    """A little sun and damp on the two that hung outside all afternoon."""
    out = piece.astype(np.float32)
    out[..., :3] *= np.array([1.06, 1.01, 0.90], dtype=np.float32)   # warmed, yellowed
    out[..., :3] = out[..., :3] * 0.88 + 34.0                        # and faded
    return np.clip(out, 0, 255).astype(np.uint8)


def build(check: bool) -> int:
    if not SOURCE.exists():
        print("missing source: %s" % SOURCE)
        return 1
    source = Image.open(SOURCE).convert("RGBA")
    width, height = source.size
    pixels = np.array(source)

    rng = np.random.default_rng(SEED)
    labels = _labels(width, height, rng)

    pieces = []
    problems = []
    for index, scrap_id in enumerate(PIECE_IDS):
        mask = labels == index
        if not mask.any():
            problems.append("%s is empty -- the tear swallowed a whole piece" % scrap_id)
            continue
        rows = np.where(mask.any(axis=1))[0]
        cols = np.where(mask.any(axis=0))[0]
        top, bottom = int(rows.min()), int(rows.max()) + 1
        left, right = int(cols.min()), int(cols.max()) + 1
        cut = pixels[top:bottom, left:right].copy()
        cut_mask = mask[top:bottom, left:right]
        if scrap_id in WEATHERED:
            cut = _weather(cut)
        cut[..., 3] = np.where(cut_mask, cut[..., 3], 0)
        # A piece that is mostly hole is a piece nobody can grab.
        coverage = float(cut_mask.mean())
        if coverage < 0.25:
            problems.append("%s covers only %.0f%% of its own box" % (scrap_id, coverage * 100))
        pieces.append({
            "id": scrap_id,
            "file": "scrap_%d.png" % index,
            # THE OFFSET IS THE SLOT. A torn piece belongs exactly where it was torn from,
            # so the overlay needs no separate slot table and the two cannot drift.
            "offset": [left, top],
            "size": [right - left, bottom - top],
            "weathered": scrap_id in WEATHERED,
        })
        if not check:
            OUT_DIR.mkdir(parents=True, exist_ok=True)
            Image.fromarray(cut, "RGBA").save(OUT_DIR / ("scrap_%d.png" % index))

    manifest = {
        "$comment": "Generated by tools/build_scraps.py. Do not hand-edit -- edit the tool. "
                    "`offset` is the piece's position in the whole painting, which IS its "
                    "slot: a torn piece belongs exactly where it was torn from.",
        "source": SOURCE.name,
        "size": [width, height],
        "pieces": pieces,
    }
    if not check:
        MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n")

    # Every pixel of the painting has to end up in exactly one piece, or the assembled
    # picture has a hole in it and nothing else in the game would ever say so.
    covered = np.zeros((height, width), dtype=bool)
    for index in range(len(PIECE_IDS)):
        covered |= labels == index
    if not covered.all():
        problems.append("the tear left %d uncovered pixels" % int((~covered).sum()))

    for problem in problems:
        print("  PROBLEM  %s" % problem)
    print("%s %d pieces from %dx%d" % ("checked" if check else "wrote", len(pieces), width, height))
    for piece in pieces:
        print("   %-10s %-13s at %-12s %s%s" % (
            piece["id"], piece["file"], tuple(piece["offset"]), tuple(piece["size"]),
            "  (weathered)" if piece["weathered"] else ""))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(build("--check" in sys.argv))
