"""The kapre, drawn for its tree: a dark, hairy giant sat on the balete's branch (dilim_small.PERCH)
with its back to the trunk, facing west -- the way she comes -- one foot up on the branch, its arm
draped over that knee, the other leg hanging, and a cigar as long as her forearm in its teeth. Its
eyes glow; the ember lights its face.

Drawn facing west, unlike the rest (which face east and are mirrored), so the light still falls
from the upper left on the side she sees.

WHERE IT SITS
-------------
Every number here is in the tree's own frame: x from the trunk's foot, y up from it (negative), as
Kapre2D's origin has them. The frame's bottom-centre goes at ART_AT; the cigar's tip is CIGAR_TIP,
where the kapre's `cigar` hit area and its light are -- kapre_2d.gd carries both numbers, and
tests/test_build_dilim_creatures.py holds them to these and to the ember in the drawn strip.
"""

from __future__ import annotations

import math

import numpy as np
from PIL import Image

from creature_sculpt import Sculpt, hexes
from dilim_giants import BAHAG, TOOTH
from dilim_small import PERCH

# The frame, fitted to the drawing: its bottom row is the hanging foot (it is anchored there, as
# a ground creature is by its feet), its top the thread of smoke off the cigar.
W, H = 136, 214
LEFT, TOP = -136, -324
ART_AT = (LEFT + W // 2, TOP + H)
CIGAR_TIP = (-122, -280)
# The middle of its head: the ember's light must reach it at full strength (kapre_2d.gd CIGAR_GLOW).
FACE = (-66, -282)

KAPRE_SKIN = hexes("#0c0806", "#20140c", "#362216", "#4c3220", "#66462c", "#845c3a")
KAPRE_HAIR = hexes("#030202", "#0a0806", "#14100c", "#201913", "#30251c")
EMBER = hexes("#4a1604", "#b0400c", "#ff8a24", "#ffe08a")
CIGAR = hexes("#140a05", "#33190c", "#552c15", "#7a4524")
EYE_GLOW = hexes("#3a2a04", "#a07a10", "#f0d040", "#fff6c0")
SMOKE = hexes("#4a4a50", "#8a8a92", "#c8c8d0", "#ececf0")
ASH = hexes("#3a3632", "#6a645c", "#9a9288", "#c4bcb0")
SEAT = -(PERCH + 4)


def P(x: float, y: float) -> tuple[float, float]:
    return (x - LEFT, y - TOP)


def _pts(*points):
    return [P(x, y) for x, y in points]


def seated(ember: float = 0.0, puff: float = -1.0, startled: bool = False, breath: float = 0.0,
           cigar: bool = True) -> Sculpt:
    """Sat on its branch. `ember` 0 resting .. 1 drawn on; `puff` 0..1 a breath of smoke on its way
    out of its mouth (negative, none); `startled`, eyes wide -- and with `cigar` gone from its mouth,
    the mouth open in a shout; `breath` lifts the chest a pixel."""
    s = Sculpt(W, H)
    skin = KAPRE_SKIN
    for name, ramp in [("far", skin[[0, 0, 1, 2, 3, 3]]), ("skin", skin), ("limb", skin), ("hair", KAPRE_HAIR),
                       ("hair_lit", KAPRE_HAIR[[1, 2, 3, 4, 4]]), ("cloth", BAHAG), ("cigar", CIGAR), ("ash", ASH),
                       ("tooth", TOOTH), ("ember", EMBER), ("glow", EYE_GLOW), ("smoke", SMOKE)]:
        s.material(name, ramp)
    lift = -breath

    # The far arm, its hand on the branch behind its hip.
    s.tube("far", _pts((-38, -246 + lift), (-30, -222), (-28, -194), (-26, -180)), [9.0, 8.0, 7.0, 6.0])
    s.ellipse("far", *P(-25, -179), 7, 5)
    # Its hair behind it: a mass, and locks down its back to the waist.
    s.ellipse("hair", *P(-50, -276 + lift), 25, 26)
    for k in range(9):
        x0 = -56 + k * 3.4
        tip = (x0 + 6 + (k % 3) * 3, -214 - (k % 4) * 6)
        s.tube("hair_lit" if k % 3 == 1 else "hair", _pts((x0, -282 + lift), (x0 + 3, -248), tip), [5.0, 4.6, 2.0])

    # The far leg, its foot up on the branch and its knee raised.
    s.tube("far", _pts((-44, -188), (-62, -208), (-80, -224), (-90, -206), (-98, -184)), [13.0, 13.0, 10.0, 9.4, 7.0])
    s.ellipse("far", *P(-104, -179), 10, 5)
    for k in range(3):
        s.ellipse("far", *P(-112 - k * 0.5, -179 + k * 1.6), 2.6, 2.0)

    # The near leg before the body, hanging over the branch: the thigh along it, the shin down.
    s.tube("limb", _pts((-44, -184), (-62, -180), (-80, -176), (-86, -160), (-87, -138), (-88, -122)),
           [15.0, 14.0, 11.0, 11.0, 9.0, 7.0])
    s.ellipse("limb", *P(-81, -175), 8, 7)                            # the knee
    s.ellipse("limb", *P(-96, -116), 12, 6)                           # a big foot, toes west
    for k in range(4):
        s.ellipse("limb", *P(-106 - k * 0.3, -117 + k * 1.8), 2.8, 2.0)

    # The body: hips on the branch, the back on the trunk, a deep chest, shoulders hunched forward.
    s.tube("skin", _pts((-42, -192), (-45, -214 + lift), (-48, -236 + lift), (-46, -254 + lift)),
           [20.0, 20.0, 26.0, 20.0])
    s.ellipse("skin", *P(-62, -236 + lift), 14, 13, flat=0.5)         # the chest's front
    # A bahag: the band round the hips, its flap hung straight down over the branch in front.
    s.tube("cloth", _pts((-30, -197), (-46, -195), (-62, -192)), [3.0, 3.6, 3.0])
    s.poly("cloth", _pts((-64, -193), (-54, -194), (-55, -166), (-58, -163), (-61, -167), (-64, -162)), bulge=0.25)

    # The head, thrust forward of the shoulders: neck, skull, a heavy jaw, the brow, a broad nose.
    s.tube("skin", _pts((-48, -252 + lift), (-58, -266 + lift)), [15.0, 14.0])
    head = (FACE[0], FACE[1] + lift)
    hx, hy = head
    s.ellipse("skin", *P(*head), 24, 25)
    s.ellipse("skin", *P(hx - 10, hy + 15), 15, 11)                   # the jaw
    s.ellipse("skin", *P(hx - 13, hy - 8), 13, 6, flat=0.4)           # the brow
    s.ellipse("skin", *P(hx - 23, hy + 3), 6, 6)                      # a broad nose
    s.ellipse("skin", *P(hx - 22, hy + 13), 6, 4)                     # the lips
    # Matted hair over the crown and back of the skull, a fringe over the brow and locks down
    # past the jaw -- the face left open.
    for x, y, rx, ry in [(hx + 6, hy - 12, 22, 15), (hx - 6, hy - 20, 14, 8), (hx - 16, hy - 15, 8, 6),
                         (hx + 14, hy - 2, 12, 16)]:
        s.ellipse("hair", *P(x, y), rx, ry)
    for k in range(5):
        x0 = hx - 20 + k * 6
        s.tube("hair_lit" if k % 2 else "hair", _pts((x0 + 3, hy - 20), (x0 - 1, hy - 13), (x0 - 2 + k % 2, hy - 8 - (k % 2) * 2)),
               [4.0, 3.4, 1.4])
    for k in range(4):
        x0 = hx + 2 + k * 4
        s.tube("hair_lit" if k % 2 == 0 else "hair", _pts((x0, hy - 8), (x0 + 2 - k % 2 * 3, hy + 6), (x0 - 1, hy + 18),
               (x0 + 1 + k, hy + 34 + k * 3)), [3.6, 3.6, 3.0, 1.4])
    # A beard from the jaw down onto the chest.
    for k in range(6):
        x0 = hx - 24 + k * 3.8
        tip = (x0 + 3 + (k % 2) * 2, hy + 44 + (k % 3) * 5)
        s.tube("hair_lit" if k % 3 == 1 else "hair", _pts((x0, hy + 19), (x0 + 1.5 - (k % 2) * 3, hy + 28), (x0 + 1, hy + 36), tip),
               [3.4, 3.4, 2.8, 1.2])

    # The near arm: down from the shoulder, the elbow on the raised knee, the forearm over it and
    # the hand hanging past it, the fingers loose.
    s.ellipse("limb", *P(-50, -246 + lift), 13, 12)
    s.tube("limb", _pts((-50, -246 + lift), (-62, -240), (-76, -236), (-90, -230), (-102, -220)),
           [11.0, 11.0, 8.6, 9.6, 6.6])
    s.ellipse("limb", *P(-105, -214), 7.0, 7.4)
    for k in range(4):
        s.tube("limb", _pts((-110 + k * 2.6, -212), (-112 + k * 2.6, -204), (-110 + k * 2.4, -198 + (k % 2))), [2.6, 2.4, 1.8])

    # The cigar in its teeth, held up, its band at the lips and its ash at the tip.
    mouth = (hx - 26, hy + 12)
    tip = CIGAR_TIP
    if cigar:
        s.tube("cigar", [P(*mouth), P((mouth[0] + tip[0]) / 2, (mouth[1] + tip[1]) / 2 + 1), P(tip[0] + 3, tip[1])],
               [3.6, 4.0, 4.0])
        s.ellipse("ash", *P(tip[0] + 2, tip[1]), 2.4, 3.8)

    def details():
        tone = s.tone
        # Hairy: tufts breaking the outline along the top of the arm and the hanging shin, and a
        # few strands on the forearm.
        _tufts(s, "limb", -100, -56, -252, -222, tone("hair", 1))
        _tufts(s, "limb", -84, -70, -196, -170, tone("hair", 1), side=True)
        for x, y in [(-70, -236), (-79, -233), (-88, -229), (-74, -232), (-84, -228)]:
            s.line(P(x, y), P(x - 2, y + 2), tone("hair", 2), only_on_body=True)
        # A deep line under the chest.
        s.curve(_pts((-70, -226 + lift), (-60, -224 + lift), (-48, -226 + lift)), tone("skin", 1), only_on_body=True)
        # The eyes, glowing out of the dark under the brow: the near one big.
        # The cheek and the nose catching the light, a crease from the nose to the mouth.
        for dx, dy in [(-14, 4), (-13, 4), (-15, 5), (-25, 1), (-26, 2)]:
            s.dot(hx + dx - LEFT, hy + dy - TOP, tone("skin", 5))
        s.curve(_pts((hx - 19, hy + 6), (hx - 17, hy + 10), (hx - 18, hy + 14)), tone("skin", 1), only_on_body=True)
        wide = 1 if startled else 0
        for ex, ey, big in [(hx - 13, hy - 2, True), (hx - 22, hy - 2, False)]:
            r = (2 if big else 1) + wide
            for dx in range(-r, r + 1):
                for dy in range(-1 - wide, 2 + wide):
                    if dx * dx / (r + 0.5) ** 2 + dy * dy / (1.5 + wide) ** 2 <= 1.0:
                        s.dot(ex + dx - LEFT, ey + dy - TOP, tone("glow", 2))
            s.dot(ex - LEFT, ey - TOP, tone("glow", 3))
            s.dot(ex - 1 - LEFT, ey - TOP, tone("glow", 3))
        if not startled:
            s.line(P(hx - 26, hy - 5), P(hx - 7, hy - 6), tone("skin", 0))
        # The mouth: a slit round the cigar, or open in a shout.
        mx, my = mouth
        if not cigar:
            for dx in range(-3, 4):
                for dy in range(-3, 5):
                    if dx * dx / 10 + dy * dy / 17 <= 1.0:
                        s.dot(mx + 4 + dx - LEFT, my + dy - TOP, tone("skin", 0))
            for dx in (-2, 0, 2):
                s.dot(mx + 4 + dx - LEFT, my - 3 - TOP, tone("tooth", 2))
        else:
            s.line(P(mx + 1, my + 2), P(mx + 8, my + 3), tone("skin", 0))
        # The ember, the band, and a thread of smoke going up off the tip.
        if cigar:
            tx, ty = tip
            core = 3 if ember > 0.5 else 2
            for dx, dy in [(0, 0), (0, -1), (0, 1), (-1, 0), (-1, -1), (-1, 1), (0, -2), (0, 2)]:
                s.dot(tx + dx - LEFT, ty + dy - TOP, tone("ember", core if abs(dy) < 2 else core - 1))
            if ember > 0.5:
                for dx, dy in [(-2, 0), (1, 0), (-2, -1), (-2, 1)]:
                    s.dot(tx + dx - LEFT, ty + dy - TOP, tone("ember", 2))
            s.line(P(mx - 5, my - 2), P(mx - 5, my + 3), tone("cloth", 3))
            for k in range(9):
                y = ty - 5 - k * 3
                x = tx + math.sin(k * 0.9 + ember * 2.5) * 2.5 - k * 0.6
                s.dot(x - LEFT, y - TOP, tone("smoke", 2 if k < 4 else 1), alpha=220 - k * 20)
        if puff >= 0.0:
            # A breath of smoke out of the side of its mouth, going up over the cigar as it thins.
            for k, (dx, dy, r) in enumerate([(-3, -7, 2.6), (-6, -13, 3.6), (-8, -20, 4.4), (-12, -27, 4.0)]):
                cx = mx + dx - puff * 6 - LEFT
                cy = my + dy - puff * 12 - TOP
                rr = r * (0.7 + puff * 0.6)
                a = int(200 * (1.0 - puff * 0.7))
                for px in range(int(-rr), int(rr) + 1):
                    for py in range(int(-rr), int(rr) + 1):
                        if px * px + py * py <= rr * rr:
                            lit = (px + py) < -rr * 0.3
                            s.dot(cx + px, cy + py, tone("smoke", 3 if lit else 2), alpha=a)
    s.details = details
    return s


def _tufts(s: Sculpt, name: str, x0: float, x1: float, y0: float, y1: float, colour, side: bool = False) -> None:
    """Hair standing off a limb's edge: at every few px along it, a strand of one or two px out
    past the silhouette -- the top edge, or (`side`) the west one."""
    m = s.names[name]
    ax, ay = P(x0, y0)
    bx, by = P(x1, y1)
    if not side:
        for k, x in enumerate(range(int(ax), int(bx), 3)):
            col = np.nonzero(s.mat[int(ay):int(by), x] == m)[0]
            if col.size:
                y = int(ay) + col[0]
                for h in range(1 + k % 2):
                    s.dot(x - (h if k % 3 else 0), y - 1 - h, colour)
    else:
        for k, y in enumerate(range(int(ay), int(by), 3)):
            row = np.nonzero(s.mat[y, int(ax):int(bx)] == m)[0]
            if row.size:
                x = int(ax) + row[0]
                for h in range(1 + k % 2):
                    s.dot(x - 1 - h, y + h, colour)


def _ember_lit(s: Sculpt, img: Image.Image, strength: float) -> Image.Image:
    """The ember's light on what is near it: a warm wash over the body within its reach -- the body
    only, not what glows on it (the ember, the eyes) or the smoke."""
    a = np.asarray(img).astype(np.float32)
    ys, xs = np.mgrid[0:img.height, 0:img.width]
    tx, ty = P(*CIGAR_TIP)
    d = np.hypot(xs - tx, ys - ty)
    k = np.clip(1.0 - d / 46.0, 0.0, 1.0) ** 1.6 * strength
    k = k * ((s.mat >= 0) & (s.over[..., 3] == 0))
    warm = np.array([255.0, 140.0, 50.0])
    a[..., :3] = a[..., :3] * (1 - k[..., None] * 0.55) + warm * k[..., None] * 0.55
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def render(s: Sculpt, ember: float = 0.0) -> Image.Image:
    s.details()
    img = s.render()
    return _ember_lit(s, img, 0.35 + 0.35 * ember) if ember >= 0.0 else img


def frames(anim: str) -> list[Image.Image]:
    if anim == "idle":
        # Sat smoking: drawn on (the ember brightens), the breath let out, and gone up.
        poses = [dict(ember=0.0), dict(ember=1.0, breath=1.0), dict(ember=0.4, puff=0.0, breath=1.0), dict(ember=0.1, puff=0.8)]
        return [render(seated(**p), p["ember"]) for p in poses]
    if anim == "knocked":
        # Its cigar knocked out of its mouth.
        return [render(seated(startled=True, cigar=False), -1.0)]
    if anim == "falling":
        # Its tree going down under it: startled, the cigar still clenched, the ember flaring.
        return [render(seated(startled=True, ember=1.0), 1.0)]
    raise KeyError(anim)


ANIMS = ["idle", "knocked", "falling"]




def cigar() -> Image.Image:
    """The cigar alone, as it falls when it is knocked from the kapre's mouth: lying east-west, its
    ember at the west end. 40 x 12."""
    s = Sculpt(40, 12)
    s.material("cigar", CIGAR)
    s.material("ash", ASH)
    s.tube("cigar", [(35, 6), (20, 6), (7, 6)], [3.6, 4.0, 4.0])
    s.ellipse("ash", 6, 6, 2.4, 3.8)
    for dx, dy in [(0, 0), (0, -1), (0, 1), (1, 0), (1, -1), (1, 1)]:
        s.dot(3 + dx, 6 + dy, EMBER[2])
    s.dot(4, 6, EMBER[3])
    return s.render()


# --- its smoke ---

SMOKE_TONES = hexes("#605c5a", "#827d78", "#a49e96", "#c6c0b6", "#e2ddd2")
PUFF = 96
PUFFS = 6


def puff(seed: int) -> Image.Image:
    """One puff of the smoke the kapre lets down over the path: a low lump of rounded billows lit
    from the upper left, flat underneath where it sits on the haze, no outline -- the edge only
    thinner. The first four are billows of the bank; the last two a middling and a small one, for
    the thread of it coming off the cigar, which grows as it comes down. PUFF px square; Kapre2D
    draws a bank of them, drifting, fading in and out, faded by how much smoke is left."""
    rng = np.random.default_rng(seed)
    size = PUFF
    scale = {PUFFS - 2: 0.62, PUFFS - 1: 0.36}.get(seed, 1.0)
    ys, xs = np.mgrid[0:size, 0:size] + 0.5
    best = np.full((size, size), np.inf)
    nx = np.zeros((size, size))
    ny = np.zeros((size, size))
    circles = [(size * 0.5, size * 0.6, size * 0.22 * scale)]
    for _ in range(5 + seed % 3):
        a = rng.uniform(math.pi * 0.9, math.pi * 2.1)
        d = rng.uniform(0.12, 0.24) * size * scale
        r = rng.uniform(0.11, 0.18) * size * scale
        cx = float(np.clip(size * 0.5 + math.cos(a) * d * 1.5, r + 2, size - r - 2))
        cy = float(np.clip(size * 0.6 + math.sin(a) * d * 0.6, r * 0.78 + 2, size - r * 0.78 - 2))
        circles.append((cx, cy, r))
    for cx, cy, r in circles:
        ox, oy = xs - cx, (ys - cy) / 0.78
        q = np.hypot(ox, oy) / r
        closer = q < best
        best = np.where(closer, q, best)
        nx = np.where(closer, ox / r, nx)
        ny = np.where(closer, oy / r, ny)
    inside = best <= 1.0
    nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1))
    from creature_sculpt import LIGHT
    lit = np.clip((np.stack([nx, ny, nz], -1) @ LIGHT) * 0.5 + 0.5, 0, 1)
    idx = np.where(lit > 0.9, 4, np.where(lit > 0.76, 3, np.where(lit > 0.42, 2, 1)))
    bottom = max(cy + r * 0.78 for cx, cy, r in circles)
    idx = np.where(ys > bottom - (bottom - size * 0.6) * 0.45, np.minimum(idx, 1), idx)
    out = np.zeros((size, size, 4), np.uint8)
    out[inside, :3] = SMOKE_TONES[idx[inside]]
    pad = np.pad(inside, 1)
    edge = inside & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    out[inside, 3] = 230
    out[edge, 3] = 120
    return Image.fromarray(out, "RGBA")


def smoke() -> list[Image.Image]:
    return [puff(k) for k in range(PUFFS)]
