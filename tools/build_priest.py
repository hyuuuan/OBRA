#!/usr/bin/env python3
"""The priest in Piyesta's church: an old man in a white sotana, drawn by the apo's hand.

WHY THIS WAS REDONE
-------------------
Kent: the priest is "so weird its not detailed enough for a 8bit game". He was the apo's sheet
recoloured -- a CHILD'S body in a black sack, the satchel strap and the shorts' edges still
showing through, the blush turned into blue tears where it was taken for hair -- and then drawn
at 1.15 times its size, which on pixel art is uneven, smeared pixels.

WHAT HE IS NOW
--------------
A grown man, drawn at the apo's own pixel size and never scaled: 80 x 124 cells, the apo's 80 x
106 plus the body of an adult. A WHITE sotana, which is what a Filipino parish priest wears --
a standing collar with the clerical tab, a row of buttons, pleats from the waist, bell sleeves,
a wooden cross on a cord, black shoes under the hem. Light from the upper left, like the rest of
Piyesta, and the apo's own warm outline.

His HEAD is still the apo's -- the face, ears, eyes, mouth and blush of the delivered sheet -- so
he is drawn by the same hand as everyone else; his hair goes grey and he wears round spectacles,
found on the eyes rather than placed by number. The face is told from the hair by what the
painter did: skin is grouped into blobs and only a face-sized one is kept; the eyes and mouth
are a black core with a dark rim, which the hair never is; the blush is a saturated pink.

The robe is drawn from one geometry at any scale, so the dialogue portrait -- the apo's own
painted portrait head, recoloured the same way -- wears the same robe at three times the size.

    python3 tools/build_priest.py            write game/assets/characters/priest/
    python3 tools/build_priest.py --check    exit 1 if the committed frames are stale
"""
from __future__ import annotations

import argparse
import colorsys
import math
import sys
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "game/assets/characters/apo"
OUT = ROOT / "game/assets/characters/priest"
def hx(v): return tuple(int(v[i:i + 2], 16) for i in (1, 3, 5)) + (255,)

OUTLINE = hx('#3d3029')
ROBE = [hx('#8e877d'), hx('#b8b2a6'), hx('#dedad0'), hx('#f6f3ec')]   # deep, shade, base, lit
BUTTON = hx('#5c524b')
CORD = hx('#5a3b22')
WOOD = [hx('#6e4321'), hx('#9a6533'), hx('#c48b4f')]
SHOE = [hx('#221b17'), hx('#3d332c'), hx('#5a4d44')]
SKIN = [hx('#b9774a'), hx('#d99a63'), hx('#eab678'), hx('#f4c995')]
SKIN_LINE = hx('#7a4918')
HAIR = [hx('#3c3c44'), hx('#6c6c76'), hx('#9e9ea8'), hx('#cfcfd6'), hx('#ececf0')]
GLASS_RIM = hx('#4a3c30')
GLASS = (210, 228, 236, 90)

def hsv(c): return colorsys.rgb_to_hsv(c[0] / 255, c[1] / 255, c[2] / 255)

def is_skin(c):
    h, s, v = hsv(c)
    return (h <= 0.12 or h >= 0.95) and 0.18 <= s <= 0.75 and v >= 0.60

def is_blush(c):
    h, s, v = hsv(c)
    return (h <= 0.07 or h >= 0.93) and s > 0.35 and v > 0.7


def blobs(mask, w, h):
    seen = [[False] * w for _ in range(h)]
    out = []
    for y0 in range(h):
        for x0 in range(w):
            if not mask[y0][x0] or seen[y0][x0]:
                continue
            stack = [(x0, y0)]; seen[y0][x0] = True; region = []
            while stack:
                x, y = stack.pop(); region.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and mask[ny][nx] and not seen[ny][nx]:
                        seen[ny][nx] = True; stack.append((nx, ny))
            out.append(region)
    return out


def head_of(cell, neck):
    """The apo's head above `neck`, its hair grey. The face, ears, blush, eyes and mouth stay."""
    w, h = cell.size
    px = cell.load()
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    op = out.load()
    skin = [[y < neck and px[x, y][3] > 8 and (is_skin(px[x, y]) or is_blush(px[x, y])) for x in range(w)] for y in range(h)]
    keep = [[False] * w for _ in range(h)]
    regions = blobs(skin, w, h)
    largest = max((len(r) for r in regions), default=0)
    for r in regions:
        if len(r) >= max(6, largest * 0.12):
            for x, y in r: keep[y][x] = True
    # The eyes and the mouth are drawn in a NEUTRAL black, and the hair's own darks are warm: a
    # neutral dark pixel inside the face's box is face. So is blush.
    face = [(x, y) for y in range(h) for x in range(w) if keep[y][x]]
    if face:
        left = min(p[0] for p in face); right = max(p[0] for p in face)
        top = min(p[1] for p in face); bottom = max(p[1] for p in face)
        # Below the hairline: the eyes are a third of the way down the face, and the dark
        # outline of the fringe above them is hair.
        for y in range(top + (bottom - top) // 3, bottom + 1):
            for x in range(left, right + 1):
                c = px[x, y]
                if c[3] > 8 and not keep[y][x]:
                    hh, ss, vv = hsv(c)
                    # the black core of an eye or the mouth, and the dark rim beside it
                    near_black = any(hsv(px[nx, ny])[2] < 0.12 and px[nx, ny][3] > 8
                                     for nx, ny in ((x, y), (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
                                     if 0 <= nx < w and 0 <= ny < h)
                    if (near_black and vv < 0.62) or is_blush(c):
                        keep[y][x] = True
    for y in range(min(h, neck)):
        for x in range(w):
            c = px[x, y]
            if c[3] <= 8:
                continue
            if keep[y][x]:
                op[x, y] = c
                continue
            v = hsv(c)[2]
            # the hair's ramp, by the brightness it had
            idx = 0 if v < 0.22 else 1 if v < 0.40 else 2 if v < 0.58 else 3 if v < 0.75 else 4
            op[x, y] = HAIR[idx][:3] + (c[3],)
    return out, keep


def spectacles(img, keep, neck, side=False, scale=1.0):
    """Round wire spectacles over the eyes: found as the neutral-dark pixels inside the face."""
    w, h = img.size
    px = img.load()
    eyes = [(x, y) for y in range(h) for x in range(w)
            if y < neck and keep[y][x] and px[x, y][3] > 8 and hsv(px[x, y])[2] < 0.12]
    if not eyes:
        return
    # the eye pixels group into two (front) or one (side) small blobs
    mask = [[False] * w for _ in range(h)]
    for x, y in eyes: mask[y][x] = True
    def tall(g):
        xs = [p[0] for p in g]; ys = [p[1] for p in g]
        return (max(ys) - min(ys)) >= (max(xs) - min(xs))
    # The eyes are drawn as short upright strokes and the mouth as a flat one.
    groups = [g for g in blobs(mask, w, h) if 2 <= len(g) <= 30 * scale * scale and tall(g)]
    if not side and len(groups) > 2:
        # the pair most nearly level with each other
        best = None
        for i in range(len(groups)):
            for j in range(i + 1, len(groups)):
                dy = abs(min(p[1] for p in groups[i]) - min(p[1] for p in groups[j]))
                if best is None or dy < best[0]:
                    best = (dy, [groups[i], groups[j]])
        groups = best[1]
    groups = groups[:1 if side else 2]
    d = ImageDraw.Draw(img)
    centres = []
    for g in groups:
        xs = [p[0] for p in g]; ys = [p[1] for p in g]
        cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        centres.append((cx, cy))
        r = 4 * scale
        box = [round(cx - r), round(cy - r + 0.5 * scale), round(cx + r), round(cy + r - 0.5 * scale)]
        # the lens, faintly
        lens = Image.new('RGBA', img.size, (0, 0, 0, 0))
        ImageDraw.Draw(lens).ellipse(box, fill=GLASS)
        img.alpha_composite(lens)
        d.ellipse(box, outline=GLASS_RIM, width=max(1, round(scale)))
    if len(centres) == 2:
        (ax, ay), (bx, by) = sorted(centres)
        d.line([(ax + 4 * scale, ay - scale), (bx - 4 * scale, by - scale)], fill=GLASS_RIM,
               width=max(1, round(scale)))


## The apo's portrait is its own painting, not the sprite enlarged: its chin's middle is at
## (88, 147) and the robe is drawn under it at three times the sprite's size.
PORTRAIT_NECK = (88.5, 147)
PORTRAIT_SCALE = 3


def compose_portrait():
    por = Image.open(SRC / 'apo_portrait.png').convert('RGBA')
    head, keep = head_of(por, PORTRAIT_NECK[1])
    spectacles(head, keep, PORTRAIT_NECK[1], scale=3.2)
    robe = robe_front(PORTRAIT_SCALE)
    out = Image.new('RGBA', por.size, (0, 0, 0, 0))
    shift = (round(PORTRAIT_NECK[0] - 40 * PORTRAIT_SCALE), round(PORTRAIT_NECK[1] - 53 * PORTRAIT_SCALE))
    out.alpha_composite(robe, (0, 0), (-shift[0], -shift[1]))
    out.alpha_composite(head)
    return out


# --- The robe ---------------------------------------------------------------------------

def _mask(size, scale, shape):
    kind, data = shape
    m = Image.new('L', size, 0)
    d = ImageDraw.Draw(m)
    if kind == 'poly':
        d.polygon([(x * scale, y * scale) for x, y in data], fill=255)
    elif kind == 'ellipse':
        x0, y0, x1, y1 = data
        d.ellipse([x0 * scale, y0 * scale, x1 * scale - 1, y1 * scale - 1], fill=255)
    elif kind == 'rect':
        x0, y0, x1, y1 = data
        d.rectangle([x0 * scale, y0 * scale, x1 * scale - 1, y1 * scale - 1], fill=255)
    return m


def _rows(mask):
    """Each row's leftmost and rightmost pixel in a mask."""
    w, h = mask.size
    m = mask.load()
    out = {}
    for y in range(h):
        xs = [x for x in range(w) if m[x, y]]
        if xs:
            out[y] = (xs[0], xs[-1])
    return out


def _paint(canvas, mask, shade, outline, scale):
    """Shade a part's pixels and ring it in its own outline, over what is already there."""
    w, h = canvas.size
    m = mask.load()
    rows = _rows(mask)
    top = min(rows) if rows else 0
    bottom = max(rows) if rows else 0
    thick = max(1, round(scale * 0.8))
    ring = mask.copy()
    rp = ring.load()
    for _ in range(thick):
        grown = ring.copy()
        gp = grown.load()
        for y in range(h):
            for x in range(w):
                if rp[x, y]:
                    continue
                if any(0 <= x + dx < w and 0 <= y + dy < h and rp[x + dx, y + dy]
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    gp[x, y] = 255
        ring = grown
        rp = ring.load()
    cp = canvas.load()
    for y in range(h):
        for x in range(w):
            if rp[x, y] and not m[x, y] and outline is not None:
                cp[x, y] = outline
    for y in range(h):
        left, right = rows.get(y, (0, 0))
        for x in range(w):
            if m[x, y]:
                across = (x - left) / max(1, right - left)
                down = (y - top) / max(1, bottom - top)
                cp[x, y] = shade(x / scale, y / scale, across, down)


def robe_front(scale=1, size=(80, 124)):
    size = (size[0] * scale, size[1] * scale)
    canvas = Image.new('RGBA', size, (0, 0, 0, 0))
    s = scale

    def robe_shade(ux, uy, across, down):
        if down > 0.97:
            return ROBE[1]
        # pleats: two folds falling from the waist
        for fold in (33.0, 47.0):
            if uy > 84 and abs(ux - fold) < 0.6:
                return ROBE[1]
            if uy > 84 and 0.6 <= fold - ux < 1.6:
                return ROBE[3]
        if across < 0.13:
            return ROBE[3]
        if across > 0.93:
            return ROBE[0]
        if across > 0.8:
            return ROBE[1]
        return ROBE[2]

    def sleeve_shade(lit):
        def shade(ux, uy, across, down):
            if down > 0.88:
                return ROBE[1] if lit else ROBE[0]
            if lit:
                return ROBE[3] if across < 0.35 else ROBE[2]
            return ROBE[1] if across > 0.45 else ROBE[2]
        return shade

    def flat(colour):
        return lambda ux, uy, a, d: colour

    def hand_shade(ux, uy, across, down):
        return SKIN[3] if across < 0.35 and down < 0.5 else SKIN[2] if down < 0.7 else SKIN[1]

    def shoe_shade(ux, uy, across, down):
        return SHOE[2] if down < 0.3 and across < 0.5 else SHOE[1] if down < 0.6 else SHOE[0]

    parts = [
        (('poly', [(30, 52), (50, 52), (57, 57), (59, 64), (61, 115), (19, 115), (21, 64), (23, 57)]),
         robe_shade, OUTLINE),
        (('ellipse', (28, 111, 40, 122)), shoe_shade, OUTLINE),
        (('ellipse', (40, 111, 52, 122)), shoe_shade, OUTLINE),
        (('poly', [(30, 52), (50, 52), (57, 57), (59, 64), (61, 115), (19, 115), (21, 64), (23, 57)]),
         robe_shade, OUTLINE),
        (('ellipse', (18, 88, 26, 98)), hand_shade, SKIN_LINE),
        (('ellipse', (54, 88, 62, 98)), hand_shade, SKIN_LINE),
        (('poly', [(24, 57), (29, 61), (30, 86), (29, 92), (16, 92), (16, 86), (19, 65)]),
         sleeve_shade(True), OUTLINE),
        (('poly', [(56, 57), (51, 61), (50, 86), (51, 92), (64, 92), (64, 86), (61, 65)]),
         sleeve_shade(False), OUTLINE),
        (('rect', (33, 51, 47, 55)), lambda ux, uy, a, d: ROBE[3] if d < 0.5 else ROBE[2], OUTLINE),
        (('rect', (38, 52, 42, 55)), flat(SHOE[0]), None),
        (('rect', (39, 53, 41, 54)), flat(ROBE[3]), None),
    ]
    for shape, shade, outline in parts:
        _paint(canvas, _mask(size, s, shape), shade, outline, s)
    d = ImageDraw.Draw(canvas)
    # the buttons down the front
    for y in range(60, 114, 5):
        d.rectangle([40 * s - max(0, s // 3), y * s, 40 * s + max(0, s // 3), y * s + max(0, s // 3)], fill=BUTTON)
    # the cord and the wooden cross
    d.line([(35 * s, 56 * s), (39.5 * s, 71 * s)], fill=CORD, width=max(1, s // 2))
    d.line([(45 * s, 56 * s), (40.5 * s, 71 * s)], fill=CORD, width=max(1, s // 2))
    _paint(canvas, _mask(size, s, ('rect', (39, 71, 42, 84))), lambda ux, uy, a, dd: WOOD[2] if a < 0.4 else WOOD[1], OUTLINE, s)
    _paint(canvas, _mask(size, s, ('rect', (36, 74, 45, 77))), lambda ux, uy, a, dd: WOOD[2] if dd < 0.4 else WOOD[1], OUTLINE, s)
    _paint(canvas, _mask(size, s, ('rect', (39, 74, 42, 77))), lambda ux, uy, a, dd: WOOD[2], None, s)
    return canvas


def spectacles_side(img, keep, neck):
    """One round lens over the eye we can see, and the arm back to the ear."""
    w, h = img.size
    px = img.load()
    eyes = [(x, y) for y in range(h) for x in range(w)
            if y < neck and keep[y][x] and px[x, y][3] > 8 and hsv(px[x, y])[2] < 0.12]
    if not eyes:
        return
    mask = [[False] * w for _ in range(h)]
    for x, y in eyes: mask[y][x] = True
    groups = [g for g in blobs(mask, w, h) if 2 <= len(g) <= 30]
    groups = [g for g in groups if (max(p[1] for p in g) - min(p[1] for p in g)) >= (max(p[0] for p in g) - min(p[0] for p in g))]
    if not groups:
        return
    eye = min(groups, key=lambda g: min(p[1] for p in g))
    cx = (min(p[0] for p in eye) + max(p[0] for p in eye)) / 2
    cy = (min(p[1] for p in eye) + max(p[1] for p in eye)) / 2
    d = ImageDraw.Draw(img)
    box = [round(cx - 3), round(cy - 3), round(cx + 3), round(cy + 3)]
    lens = Image.new('RGBA', img.size, (0, 0, 0, 0))
    ImageDraw.Draw(lens).ellipse(box, fill=GLASS)
    img.alpha_composite(lens)
    d.ellipse(box, outline=GLASS_RIM)
    # the arm, back toward the ear (the face looks right, so back is left)
    d.line([(box[0], cy - 1), (box[0] - 8, cy - 2)], fill=GLASS_RIM)


def neck_of(head, keep, neck):
    """Where the body hangs from: under the middle of the head (not the chin, which in profile
    is at its front), from the face's lowest row."""
    rows = [y for y in range(len(keep)) if y < neck and any(keep[y])]
    bottom = max(rows)
    box = head.getbbox()
    return (box[0] + box[2]) / 2.0 - 1.0, bottom


def robe_side(phase, nx, chin, scale=1, size=(80, 124)):
    """The robe from the side, facing right, `phase` (0..1) through a stride (None: standing)."""
    size = (size[0] * scale, size[1] * scale)
    canvas = Image.new('RGBA', size, (0, 0, 0, 0))
    s = scale
    top = chin
    if phase is None:
        stride, swing = 0.0, 0.0
    else:
        stride = math.sin(phase * math.tau)
        swing = -0.32 * stride
    lead, trail = 9.0 * stride, -9.0 * stride
    hem = 115.0

    def robe_shade(ux, uy, across, down):
        if down > 0.97:
            return ROBE[1]
        if uy > 86 and abs(ux - (nx - 2 + trail * 0.25)) < 0.6:
            return ROBE[1]
        if across < 0.16:
            return ROBE[3]
        if across > 0.84:
            return ROBE[1]
        return ROBE[2]

    def shoe_shade(ux, uy, across, down):
        return SHOE[2] if down < 0.35 and across > 0.5 else SHOE[1] if down < 0.65 else SHOE[0]

    def hand_shade(ux, uy, across, down):
        return SKIN[3] if across > 0.5 and down < 0.5 else SKIN[2] if down < 0.7 else SKIN[1]

    def sleeve_shade(ux, uy, across, down):
        if down > 0.86:
            return ROBE[1]
        return ROBE[3] if across < 0.35 else ROBE[2]

    # The far shoe first, half behind the hem.
    _paint(canvas, _mask(size, s, ('ellipse', (nx - 7 + trail, hem - 4, nx + 5 + trail, hem + 7))), shoe_shade, OUTLINE, s)
    body = [(nx - 8, top - 1), (nx + 7, top - 1), (nx + 12, top + 6), (nx + 13, top + 20),
            (nx + 14, top + 42), (nx + 15 + max(0.0, lead) * 0.5, hem), (nx - 14 + min(0.0, trail) * 0.4, hem),
            (nx - 13, top + 30), (nx - 12, top + 8)]
    _paint(canvas, _mask(size, s, ('poly', body)), robe_shade, OUTLINE, s)
    _paint(canvas, _mask(size, s, ('ellipse', (nx - 3 + lead, hem - 4, nx + 10 + lead, hem + 7))), shoe_shade, OUTLINE, s)
    # the sleeve, swung about the shoulder, and the hand out of it
    shoulder = (nx + 0.5, top + 5.0)
    def at(dx, dy):
        c, sn = math.cos(swing), math.sin(swing)
        return (shoulder[0] + dx * c - dy * sn, shoulder[1] + dx * sn + dy * c)
    hand = at(0.5, 36.5)
    _paint(canvas, _mask(size, s, ('ellipse', (hand[0] - 4, hand[1] - 4, hand[0] + 4, hand[1] + 5))), hand_shade, SKIN_LINE, s)
    sleeve = [at(-5, -1), at(5, -1), at(7, 30), at(7.5, 34), at(-6.5, 34), at(-6, 30)]
    _paint(canvas, _mask(size, s, ('poly', sleeve)), sleeve_shade, OUTLINE, s)
    # the collar and its tab at the throat
    _paint(canvas, _mask(size, s, ('rect', (nx - 7, top - 2, nx + 9, top + 2))), lambda ux, uy, a, d: ROBE[3] if d < 0.5 else ROBE[2], OUTLINE, s)
    _paint(canvas, _mask(size, s, ('rect', (nx + 6, top - 1, nx + 9, top + 2))), lambda ux, uy, a, d: SHOE[0], None, s)
    # the cross against the chest, on its cord
    d = ImageDraw.Draw(canvas)
    d.line([((nx + 6) * s, (top + 1) * s), ((nx + 11) * s, (top + 15) * s)], fill=CORD, width=max(1, s // 2))
    _paint(canvas, _mask(size, s, ('rect', (nx + 10, top + 15, nx + 12, top + 25))), lambda ux, uy, a, dd: WOOD[2] if a < 0.5 else WOOD[1], OUTLINE, s)
    _paint(canvas, _mask(size, s, ('rect', (nx + 8, top + 17, nx + 14, top + 19))), lambda ux, uy, a, dd: WOOD[2] if dd < 0.5 else WOOD[1], OUTLINE, s)
    _paint(canvas, _mask(size, s, ('rect', (nx + 10, top + 17, nx + 12, top + 19))), lambda ux, uy, a, dd: WOOD[2], None, s)
    return canvas


def compose_walk():
    walk = Image.open(SRC / 'apo_walk.png').convert('RGBA')
    frames = []
    for k in range(6):
        cell = walk.crop((k * 80, 0, (k + 1) * 80, 106))
        head, keep = head_of(cell, 53)
        spectacles_side(head, keep, 53)
        nx, chin = neck_of(head, keep, 53)
        body = robe_side(k / 6.0, nx, chin + 1)
        out = Image.new('RGBA', (80, 124), (0, 0, 0, 0))
        out.alpha_composite(body)
        out.alpha_composite(head)
        frames.append(out)
    return frames


def compose_side():
    """Standing side-on to talk, facing LEFT as the church expects: the turnaround's side cell
    faces left, so it is turned to face right, dressed, and turned back."""
    turn = Image.open(SRC / 'apo_turnaround.png').convert('RGBA')
    cell = turn.crop((160, 0, 240, 106)).transpose(Image.FLIP_LEFT_RIGHT)
    head, keep = head_of(cell, 53)
    spectacles_side(head, keep, 53)
    nx, chin = neck_of(head, keep, 53)
    out = Image.new('RGBA', (80, 124), (0, 0, 0, 0))
    out.alpha_composite(robe_side(None, nx, chin + 1))
    out.alpha_composite(head)
    return out.transpose(Image.FLIP_LEFT_RIGHT)


def compose_front():
    idle = Image.open(SRC / 'apo_idle.png').convert('RGBA').crop((0, 0, 80, 106))
    head, keep = head_of(idle, 53)
    spectacles(head, keep, 53)
    body = robe_front()
    out = Image.new('RGBA', (80, 124), (0, 0, 0, 0))
    out.alpha_composite(body)
    out.alpha_composite(head)
    return out


## Where, in the portrait, the bust is cut: just under the wooden cross, so the speaker shows
## his collar and his cross. DialoguePortrait reads this as a fraction of the portrait's height.
PORTRAIT_CUT_ROW = round(PORTRAIT_NECK[1] - 53 * PORTRAIT_SCALE + 85 * PORTRAIT_SCALE)


def build() -> dict:
    walk = compose_walk()
    strip = Image.new("RGBA", (80 * len(walk), 124), (0, 0, 0, 0))
    for index, frame in enumerate(walk):
        strip.alpha_composite(frame, (index * 80, 0))
    images = {
        "priest_idle.png": compose_front(),
        "priest_walk.png": strip,
        "priest_side.png": compose_side(),
        "priest_portrait.png": compose_portrait(),
    }
    files = {}
    for name, image in images.items():
        buffer = BytesIO()
        image.save(buffer, "PNG")
        files[name] = buffer.getvalue()
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    files = build()
    if args.check:
        stale = [name for name, data in files.items()
                 if not (OUT / name).exists()
                 or Image.open(OUT / name).convert("RGBA").tobytes()
                 != Image.open(BytesIO(data)).convert("RGBA").tobytes()]
        if stale:
            print("stale: %s" % ", ".join(stale))
            return 1
        print("priest is up to date (%d files); portrait bust cut at row %d of 312"
              % (len(files), PORTRAIT_CUT_ROW))
        return 0
    OUT.mkdir(parents=True, exist_ok=True)
    for name, data in files.items():
        (OUT / name).write_bytes(data)
        print("wrote %s" % (OUT / name).relative_to(ROOT))
    print("portrait bust cut at row %d of 312 (%.3f)" % (PORTRAIT_CUT_ROW, PORTRAIT_CUT_ROW / 312.0))
    return 0


if __name__ == "__main__":
    sys.exit(main())
