#!/usr/bin/env python3
"""The priest in Piyesta's church, reskinned from the apo's own sheet.

WHY A RESKIN
------------
The priest is the one other person in the game who talks, and until now he was a dark
rectangle with a circle on top, drawn by `ChurchInterior2D._draw_priest`, and his lines were
printed under the APO's name and portrait. The refined design already says what he should
be: "Priest: idle and talking only. Cheapest as an outfit reskin on the MALE rig rather than
a new sheet." The male sheet IS the apo's, so this recolours the apo's frames:

  * hair  -> grey, so he reads as an older man at a glance
  * shirt, shorts, satchel, its strap, its crayons, the legs below the shorts, the shoes
          -> one black cassock, shaded by the brightness each pixel had before
  * a white collar along the neckline, which is the whole read of "priest" at this size
  * skin, eyes, blush and outline -> untouched, so he is drawn by the same hand as everyone

WHICH BROWN IS HAIR
-------------------
The sheet is painted, not indexed -- thousands of colours -- and the hair and the satchel
are the same brown. They are told apart by WHERE they are: the neck is the first row, from
the top, that holds any of the shirt's cream, and brown above it is hair, brown below it is
leather. Found per frame, because the walk bobs.

  python3 tools/build_priest.py            write game/assets/characters/priest/
  python3 tools/build_priest.py --check    exit 1 if the committed frames are stale
"""
from __future__ import annotations

import argparse
import colorsys
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "game/assets/characters/apo"
OUT = ROOT / "game/assets/characters/priest"
# source -> (output, cell width). The portrait is one picture; the sheets are 80-wide cells.
SHEETS = {
    "apo_idle.png": ("priest_idle.png", 80),
    "apo_walk.png": ("priest_walk.png", 80),
    "apo_portrait.png": ("priest_portrait.png", 0),
}
# ONE CELL OF THE TURNAROUND: front, three-quarter, SIDE, three-quarter back, back. The side one
# is how he stands while he talks to the apo -- the walk sheet has no standing frame. Only that
# cell is taken: the backs have no face, so the blob rule has nothing to tell hair from skin by.
SINGLE_CELLS = {"apo_turnaround.png": ("priest_side.png", 80, 2)}

# The cassock: near-black with a cool cast, so it does not read as a hole in a warm room.
CASSOCK_DEEP = (20, 19, 25)
CASSOCK_DARK = (33, 32, 40)
CASSOCK_LIT = (70, 69, 82)
COLLAR = (239, 238, 234)
COLLAR_SHADE = (196, 196, 204)
# Grey hair, darkest to lightest, taken off the brightness the brown had.
HAIR_DEEP = (34, 34, 40)
HAIR_DARK = (70, 70, 78)
HAIR_LIT = (196, 196, 202)


# WHERE THE BODY IS, per sheet, measured on the delivered frames at 6x with a grid: the row
# the neck starts on (the chin is the row above), the row the shorts start on, and the row the
# shins start on. The walk bobs by a pixel or two and the lines below absorb that -- the
# shins are also found per frame from the shorts' lowest blue.
LINES = {
    "apo_idle.png": {"neck": 53, "shorts": 80, "shins": 92},
    "apo_walk.png": {"neck": 53, "shorts": 78, "shins": 90},
    "apo_portrait.png": {"neck": 147, "shorts": 230, "shins": 262},
    "apo_turnaround.png": {"neck": 53, "shorts": 80, "shins": 92},
}


def hsv(r: int, g: int, b: int) -> tuple:
    return colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)


def is_skin(r: int, g: int, b: int) -> bool:
    h, s, v = hsv(r, g, b)
    return (h <= 0.12 or h >= 0.95) and 0.18 <= s <= 0.75 and v >= 0.60


def is_dark(r: int, g: int, b: int) -> bool:
    return hsv(r, g, b)[2] < 0.24


def lerp(a: tuple, b: tuple, t: float) -> tuple:
    t = max(0.0, min(1.0, t))
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def cassock(v: float) -> tuple:
    # The brightest thing on the apo is the cream shirt at ~0.94; that becomes the lit edge
    # of the cassock, and everything darker falls toward its shadow.
    if v < 0.34:
        return lerp(CASSOCK_DEEP, CASSOCK_DARK, v / 0.34)
    return lerp(CASSOCK_DARK, CASSOCK_LIT, (v - 0.34) / 0.62)


def hair(v: float) -> tuple:
    return lerp(HAIR_DARK, HAIR_LIT, (v - 0.18) / 0.55)


def blobs(mask: list, w: int, h: int) -> list:
    """Connected regions of a boolean grid, 4-neighbour, as lists of (x, y)."""
    seen = [[False] * w for _ in range(h)]
    out = []
    for y0 in range(h):
        for x0 in range(w):
            if not mask[y0][x0] or seen[y0][x0]:
                continue
            stack = [(x0, y0)]
            seen[y0][x0] = True
            region = []
            while stack:
                x, y = stack.pop()
                region.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and mask[ny][nx] and not seen[ny][nx]:
                        seen[ny][nx] = True
                        stack.append((nx, ny))
            out.append(region)
    return out


def recolour_cell(cell: Image.Image, lines: dict) -> Image.Image:
    px = cell.load()
    w, h = cell.size
    neck, shins = lines["neck"], lines["shins"]
    # The shins start under the shorts' lowest blue in THIS frame, if it has any.
    lowest_blue = -1
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            hh, ss, _vv = hsv(r, g, b)
            if a > 8 and 0.52 <= hh <= 0.78 and ss > 0.22:
                lowest_blue = max(lowest_blue, y)
    if lowest_blue > 0:
        shins = min(shins, lowest_blue + 1)

    skin = [[px[x, y][3] > 8 and is_skin(*px[x, y][:3]) for x in range(w)] for y in range(h)]
    # THE FACE AND THE HANDS ARE BLOBS, AND A HIGHLIGHT IN THE HAIR IS A SPECK. Skin-coloured
    # pixels are grouped, and only groups big enough to be a face, an ear or a hand keep their
    # colour; the tan glints in the painted hair are the same colour and much smaller.
    head_mask = [[skin[y][x] and y < neck for x in range(w)] for y in range(h)]
    hand_mask = [[skin[y][x] and neck <= y < shins for x in range(w)] for y in range(h)]
    keep = [[False] * w for _ in range(h)]
    head_blobs = blobs(head_mask, w, h)
    largest = max((len(b) for b in head_blobs), default=0)
    for region in head_blobs:
        if len(region) >= max(6, largest * 0.12):
            for x, y in region:
                keep[y][x] = True
    for region in blobs(hand_mask, w, h):
        if len(region) >= max(6, (w * h) // 900):
            for x, y in region:
                keep[y][x] = True

    out = cell.copy()
    opx = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a <= 8 or keep[y][x]:
                continue
            v = hsv(r, g, b)[2]
            if y < neck:
                if is_dark(r, g, b):
                    # The eyes and the mouth are drawn in a NEUTRAL black and stay; the hair's
                    # own darkest brown and the outline around it are warm, and go grey with it.
                    if hsv(r, g, b)[1] < 0.35:
                        continue
                    opx[x, y] = lerp(HAIR_DEEP, HAIR_DARK, v / 0.24) + (a,)
                    continue
                opx[x, y] = hair(v) + (a,)
            else:
                opx[x, y] = cassock(v) + (a,)

    # THE COLLAR runs across the throat, under the chin: the width of the face's lowest rows,
    # two rows deep, white over its own shade so it sits ON the black.
    chin = [x for x in range(w) if any(keep[y][x] for y in range(max(0, neck - 3), neck))]
    if chin:
        left, right = min(chin), max(chin)
        inset = max(1, (right - left) // 6)
        for x in range(left + inset, right - inset + 1):
            for depth, colour in ((0, COLLAR), (1, COLLAR_SHADE)):
                y = neck + depth
                if y < h and px[x, y][3] > 8 and not keep[y][x]:
                    opx[x, y] = colour + (px[x, y][3],)
    return out


def build_one(source: Path, cell_width: int) -> Image.Image:
    sheet = Image.open(source).convert("RGBA")
    lines = LINES[source.name]
    if cell_width <= 0:
        return recolour_cell(sheet, lines)
    out = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    for left in range(0, sheet.width, cell_width):
        cell = sheet.crop((left, 0, left + cell_width, sheet.height))
        out.paste(recolour_cell(cell, lines), (left, 0))
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    stale = []
    jobs = [(name, out, cell, -1) for name, (out, cell) in SHEETS.items()] \
        + [(name, out, cell, index) for name, (out, cell, index) in SINGLE_CELLS.items()]
    for source_name, out_name, cell, index in jobs:
        built = build_one(SRC / source_name, cell)
        if index >= 0:
            built = built.crop((index * cell, 0, (index + 1) * cell, built.height))
        target = OUT / out_name
        if args.check:
            if not target.exists() \
                    or Image.open(target).convert("RGBA").tobytes() != built.tobytes():
                stale.append(out_name)
            continue
        built.save(target)
        print("wrote %s %s" % (target.relative_to(ROOT), built.size))
    if args.check:
        if stale:
            print("stale: %s" % ", ".join(stale))
            return 1
        print("priest is up to date (%d files)" % len(jobs))
    return 0


if __name__ == "__main__":
    sys.exit(main())
