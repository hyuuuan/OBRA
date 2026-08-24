#!/usr/bin/env python3
"""Cut the delivered artwork in level-1-assets/ into what the game actually loads.

WHY THIS EXISTS
---------------
The art arrives in two forms and neither is loadable as-is.

The character comes as a DESIGN SHEET: a 1254x1254 presentation page with a title, a
description, a palette, and twenty-three poses laid out in four bordered panels on a flat
dark background. It has no alpha at all. Every frame has to be found, cut out, keyed to
transparency and aligned to a common anchor before it is a sprite.

The four props come as 6x upscaled pixel art on a large transparent canvas -- 576x240 for
a bridge whose real size is 96x40. Downsampling by exactly six recovers the original
pixels with no loss (this script asserts that), and the game then draws them back up at an
integer scale, which keeps every pixel square instead of resampling them into mush.

Both halves are done here rather than by hand so that a redelivery is one command, and so
the numbers below -- which frame is which, how tall the character stands, where the feet
are -- are written down somewhere they can be argued with.

KEYING THE CHARACTER
--------------------
The panel background is a flat near-neutral #201F1B and each figure sits on a soft dark
ellipse of shadow. The character's own darkest colour is #321E08: nearly as dark, but
strongly warm. So the test is not brightness, it is CHROMA -- a pixel belongs to the
background if its channels are close together AND it is dark. That separates the shadow
from a boot, which no luminance threshold does.

Interior detail (the eyes, the gap under an arm) would fail that test too, so the mask is
then flood-filled from the frame border: only background CONNECTED TO THE OUTSIDE is
background. Everything the fill cannot reach belongs to the sprite.

ALIGNMENT
---------
Frames are placed on one shared canvas so that switching animation never moves the
character. Two anchors do that:

  vertical    the panel's own ground line, shared by every frame in that panel, so the
              artist's intended foot heights survive -- a walk cycle that lifts a heel is
              supposed to lift it.
  horizontal  the centre of the HEAD, not of the bounding box. Arms and legs swing; a
              bbox centre swings with them and the character moonwalks.

USAGE
    python3 tools/build_art.py            # write game/assets/
    python3 tools/build_art.py --check    # verify the committed files are up to date
"""

from __future__ import annotations

import argparse
import hashlib
import math
import sys
from collections import Counter, deque
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "level-1-assets"
CHARACTER_OUT = ROOT / "game" / "assets" / "characters" / "apo"
PROP_OUT = ROOT / "game" / "assets" / "level1" / "props"

# --- the character sheet -------------------------------------------------------------

SHEET = "Obra Assets Male.png"

# Panel interiors, measured off the tan border lines that box each section.
PANEL_X = (340, 1232)
PANELS = [
    ("turnaround", (30, 382), ["front", "34front", "side", "34back", "back"]),
    ("walk", (403, 653), ["0", "1", "2", "3", "4", "5"]),
    ("run", (674, 909), ["0", "1", "2", "3", "4", "5"]),
    ("extra", (930, 1221), ["idle", "look_up", "look_down", "wave", "jump", "cheer"]),
]

# How tall the character stands, in world pixels, measured on the idle pose.
#
# The collision capsule it replaces is 80px from the feet up, and the stick figure that
# stood in for it was 83. Ninety-six puts the eyeline above the capsule and lets the hair
# overhang it, which is what makes a chibi silhouette read; the body inside the capsule is
# unchanged, so no gate in GATES.md is affected by this number.
STANDING_HEIGHT = 96.0
# The pose the height is measured on. Every frame in walk/run/extra is drawn at one scale,
# so one factor derived from this pose keeps their differences intact -- run is shorter
# because it leans, not because it is smaller.
SCALE_REFERENCE = ("extra", "idle")
# The turnaround panel is drawn larger than the rest of the sheet and gets its own factor,
# derived from the standing pose in it rather than guessed.
TURNAROUND_REFERENCE = ("turnaround", "front")

# Which frames become which file. A strip is one row of frames, left to right.
STRIPS = [
    ("apo_idle", [("extra", "idle")]),
    ("apo_walk", [("walk", str(i)) for i in range(6)]),
    ("apo_run", [("run", str(i)) for i in range(6)]),
    ("apo_jump", [("extra", "jump")]),
    ("apo_look_up", [("extra", "look_up")]),
    ("apo_look_down", [("extra", "look_down")]),
    ("apo_wave", [("extra", "wave")]),
    ("apo_cheer", [("extra", "cheer")]),
    ("apo_turnaround", [("turnaround", n) for n in
                        ["front", "34front", "side", "34back", "back"]]),
]

# --- the props -----------------------------------------------------------------------

# Delivered at 6x. Verified, not assumed: the run lengths in all four are multiples of six.
PROP_UPSCALE = 6
PROPS = [
    ("Level 1 Assets Stair Dirt.png", "stair_step"),
    ("Floating Dirt Level 1 Asset.png", "floating_tread"),
    ("Level 1 Asset Treetrunk.png", "dead_tree"),
    ("Rice Terraces Broken Bridge.png", "broken_bridge"),
]


def foreground_mask(rgb: np.ndarray) -> np.ndarray:
    """Warm or bright is the sprite; near-neutral and dark is the panel or its shadow."""
    high = rgb.max(axis=2)
    low = rgb.min(axis=2)
    return ((high - low) > 10) | (high > 48)


def without_thin_columns(mask: np.ndarray, radius: int = 2) -> np.ndarray:
    """Erode horizontally, so anything narrower than 2*radius+1 disappears.

    Used ONLY to decide where the frames are, never to cut them. Two things in the sheet
    are thin: the 2px rules that divide the pose cells, and the strokes of the little
    labels printed under them. Both are foreground by every colour test, and the dividers
    bridge the gap between the poses and their labels -- so a row profile taken on the raw
    mask reports one tall band and every extra pose comes out with the word IDLE or JUMP
    baked into its feet, floating twenty pixels above the ground line it shares.
    """
    out = mask.copy()
    for step in range(1, radius + 1):
        out &= np.roll(mask, step, axis=1) & np.roll(mask, -step, axis=1)
    return out


def fill_from_border(mask: np.ndarray) -> np.ndarray:
    """Keep only background the outside can reach, so eyes stay eyes."""
    height, width = mask.shape
    background = np.zeros_like(mask, dtype=bool)
    queue: deque = deque()

    def seed(y: int, x: int) -> None:
        if not mask[y, x] and not background[y, x]:
            background[y, x] = True
            queue.append((y, x))

    for x in range(width):
        seed(0, x)
        seed(height - 1, x)
    for y in range(height):
        seed(y, 0)
        seed(y, width - 1)
    while queue:
        y, x = queue.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < height and 0 <= nx < width:
                seed(ny, nx)
    return ~background


def column_groups(band: np.ndarray, x0: int) -> list[tuple[int, int]]:
    """Split a panel's sprite row into one span per frame."""
    profile = band.sum(axis=0)
    groups: list[tuple[int, int]] = []
    start = None
    for index, value in enumerate(profile):
        if value > 1 and start is None:
            start = index
        elif value <= 1 and start is not None:
            if index - start > 6:
                groups.append((x0 + start, x0 + index - 1))
            start = None
    if start is not None:
        groups.append((x0 + start, x0 + band.shape[1] - 1))
    return groups


def tallest_row_band(mask: np.ndarray, y0: int) -> tuple[int, int]:
    """The sprites, not the section heading or the little labels under them."""
    rows = mask.sum(axis=1)
    bands: list[tuple[int, int]] = []
    start = None
    for index, value in enumerate(rows):
        if value > 2 and start is None:
            start = index
        elif value <= 2 and start is not None:
            if index - start > 4:
                bands.append((y0 + start, y0 + index - 1))
            start = None
    if start is not None:
        bands.append((y0 + start, y0 + mask.shape[0] - 1))
    bands.sort(key=lambda b: b[1] - b[0], reverse=True)
    return bands[0]


def cut_sheet() -> dict[tuple[str, str], dict]:
    """Every pose on the sheet, keyed, with the numbers needed to line them up."""
    sheet = Image.open(SOURCE / SHEET).convert("RGB")
    rgb = np.asarray(sheet, dtype=int)
    mask = foreground_mask(rgb)
    solid_only = without_thin_columns(mask)
    x0, x1 = PANEL_X
    frames: dict[tuple[str, str], dict] = {}

    for panel, (py0, py1), names in PANELS:
        band_y0, band_y1 = tallest_row_band(solid_only[py0:py1 + 1, x0:x1 + 1], py0)
        band = solid_only[band_y0:band_y1 + 1, x0:x1 + 1]
        groups = column_groups(band, x0)
        if len(groups) != len(names):
            raise SystemExit(
                f"{panel}: expected {len(names)} frames, found {len(groups)}. "
                "The sheet layout changed; the panel bounds above need re-measuring.")

        cut: list[dict] = []
        for (gx0, gx1), name in zip(groups, names):
            column = mask[band_y0:band_y1 + 1, gx0:gx1 + 1]
            rows = np.where(column.any(axis=1))[0]
            ty0, ty1 = band_y0 + rows[0], band_y0 + rows[-1]
            solid = fill_from_border(mask[ty0:ty1 + 1, gx0:gx1 + 1].copy())
            # Head centre, not bbox centre: the arms and legs swing and the head does not.
            head = solid[:max(1, int(solid.shape[0] * 0.30))]
            head_columns = np.where(head.any(axis=0))[0]
            anchor_x = gx0 + float(head_columns.mean())
            cut.append({
                "panel": panel, "name": name,
                "box": (gx0, ty0, gx1 + 1, ty1 + 1),
                "mask": solid, "anchor_x": anchor_x, "bottom": ty1 + 1,
            })

        # One ground line for the whole panel, so a lifted heel stays lifted.
        ground = max(frame["bottom"] for frame in cut)
        for frame in cut:
            frame["ground"] = ground
            frames[(panel, frame["name"])] = frame
    return frames


def keyed_image(sheet: Image.Image, frame: dict) -> Image.Image:
    box = frame["box"]
    rgb = np.asarray(sheet.crop(box), dtype=np.uint8)
    alpha = (frame["mask"] * 255).astype(np.uint8)
    return Image.fromarray(np.dstack([rgb, alpha]), "RGBA")


def scaled(image: Image.Image, factor: float) -> Image.Image:
    """Downscale without letting the keyed-out background bleed into the edges.

    The transparent pixels still carry the panel's dark colour, so a plain resize averages
    it into every edge and the sprite comes back wearing a black outline it was never
    drawn with. Premultiplying first is what stops that.
    """
    width = max(1, int(round(image.width * factor)))
    height = max(1, int(round(image.height * factor)))
    source = np.asarray(image, dtype=float)
    alpha = source[:, :, 3:4] / 255.0
    premultiplied = np.dstack([source[:, :, :3] * alpha, source[:, :, 3:4]]).astype(np.uint8)
    small = np.asarray(
        Image.fromarray(premultiplied, "RGBA").resize((width, height), Image.LANCZOS),
        dtype=float)
    out_alpha = np.clip(small[:, :, 3:4], 0, 255)
    with np.errstate(divide="ignore", invalid="ignore"):
        colour = np.where(out_alpha > 0, small[:, :, :3] * 255.0 / np.maximum(out_alpha, 1e-6), 0)
    return Image.fromarray(
        np.dstack([np.clip(colour, 0, 255), out_alpha]).astype(np.uint8), "RGBA")


def build_character(write: bool) -> dict[str, bytes]:
    sheet = Image.open(SOURCE / SHEET).convert("RGB")
    frames = cut_sheet()

    reference = frames[SCALE_REFERENCE]
    base_scale = STANDING_HEIGHT / (reference["box"][3] - reference["box"][1])
    turn = frames[TURNAROUND_REFERENCE]
    turn_scale = STANDING_HEIGHT / (turn["box"][3] - turn["box"][1])
    scales = {"turnaround": turn_scale, "walk": base_scale, "run": base_scale,
              "extra": base_scale}

    # One canvas for every animation, so a texture swap never shifts the character.
    left = right = top = 0.0
    placed: dict[tuple[str, str], tuple[Image.Image, float, float]] = {}
    for key, frame in frames.items():
        factor = scales[frame["panel"]]
        image = scaled(keyed_image(sheet, frame), factor)
        anchor = (frame["anchor_x"] - frame["box"][0]) * factor
        lift = (frame["ground"] - frame["box"][3]) * factor
        placed[key] = (image, anchor, lift)
        left = max(left, anchor)
        right = max(right, image.width - anchor)
        top = max(top, image.height + lift)
    cell_w = int(math.ceil(max(left, right))) * 2 + 2
    cell_h = int(math.ceil(top)) + 2

    written: dict[str, bytes] = {}
    for name, keys in STRIPS:
        strip = Image.new("RGBA", (cell_w * len(keys), cell_h), (0, 0, 0, 0))
        for index, key in enumerate(keys):
            image, anchor, lift = placed[key]
            x = index * cell_w + int(round(cell_w / 2.0 - anchor))
            y = cell_h - 1 - int(round(image.height + lift))
            strip.alpha_composite(image, (x, y))
        path = CHARACTER_OUT / f"{name}.png"
        written[str(path.relative_to(ROOT))] = _emit(strip, path, write)
    return written, cell_w, cell_h


def build_props(write: bool) -> dict[str, bytes]:
    written: dict[str, bytes] = {}
    for filename, name in PROPS:
        image = Image.open(SOURCE / filename).convert("RGBA")
        box = image.split()[-1].getbbox()
        # Trim on the upscale grid, or the downsample would straddle source pixels.
        x0 = box[0] - box[0] % PROP_UPSCALE
        y0 = box[1] - box[1] % PROP_UPSCALE
        x1 = box[2] + (-box[2]) % PROP_UPSCALE
        y1 = box[3] + (-box[3]) % PROP_UPSCALE
        cropped = image.crop((x0, y0, x1, y1))
        native = cropped.resize(
            (cropped.width // PROP_UPSCALE, cropped.height // PROP_UPSCALE), Image.NEAREST)
        # Assert the claim rather than trusting it: if the art is not really 6x, blowing
        # it back up will not reproduce the source and the downsample threw pixels away.
        back = native.resize(cropped.size, Image.NEAREST)
        if not np.array_equal(np.asarray(back), np.asarray(cropped)):
            raise SystemExit(
                f"{filename} is not {PROP_UPSCALE}x pixel art -- downsampling would lose "
                "detail. Ship it at the delivered size instead of guessing a scale.")
        path = PROP_OUT / f"{name}.png"
        written[str(path.relative_to(ROOT))] = _emit(native, path, write)
    return written


def _emit(image: Image.Image, path: Path, write: bool) -> bytes:
    import io
    buffer = io.BytesIO()
    image.save(buffer, "PNG", optimize=True)
    data = buffer.getvalue()
    if write:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    return data


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="fail if the committed files differ from a fresh build")
    args = parser.parse_args()

    character, cell_w, cell_h = build_character(write=not args.check)
    props = build_props(write=not args.check)
    everything = {**character, **props}

    if args.check:
        stale = []
        for rel, data in everything.items():
            path = ROOT / rel
            if not path.exists() or path.read_bytes() != data:
                stale.append(rel)
        if stale:
            print("stale, re-run tools/build_art.py:")
            for rel in stale:
                print("   ", rel)
            return 1
        print(f"art is up to date ({len(everything)} files)")
        return 0

    print(f"character cell {cell_w}x{cell_h}px, standing height {STANDING_HEIGHT:.0f}px")
    for rel in sorted(everything):
        print(f"   {len(everything[rel]):7d}  {rel}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
