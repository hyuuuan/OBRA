"""Dilim's small ones: the tiyanak (its bundle and what is in it), the santelmo, the nuno's mound,
and the manananggal's lower half. Sculpted, lit and outlined like the rest (creature_sculpt)."""

from __future__ import annotations

import math

from creature_sculpt import Sculpt, hexes

CLOTH = hexes("#3a3226", "#6e6450", "#9e937a", "#c4b99c", "#e0d6ba")
BABY = hexes("#3a2018", "#6e4232", "#9c6650", "#c48c70", "#e0b090")
TIY = hexes("#2a0a08", "#561814", "#7e2a20", "#a44434", "#c2644e", "#d98a70")
EYE_RED = hexes("#4a0a08", "#b3241a", "#ff4a2a", "#ffc08a")
TOOTH = hexes("#3d3428", "#8f8670", "#d4caa8", "#f2ead2")
GUM = hexes("#2a070c", "#5c1420", "#8e2433", "#b54050")
FIRE = hexes("#3a0e02", "#a03a06", "#ff7a14", "#ffc04a", "#fff2b0")
EARTH = hexes("#1a120a", "#33241a", "#4e3826", "#6a4e36", "#866648")
EARTH_RED = hexes("#20100a", "#40221a", "#603428", "#804a38", "#9e644c")
GRASS = hexes("#0e1a0c", "#1e3418", "#2e4c24", "#466a32")
LEAF = hexes("#0e1a0c", "#1e3a16", "#2e5a20", "#46802e")
RICE = hexes("#6a6458", "#b8b0a0", "#e8e2d4", "#ffffff")
SKIN_W = hexes("#231d27", "#433a45", "#625761", "#857980", "#a89c9e", "#c6bbb8")
TAPIS = hexes("#14080c", "#2e1220", "#4a1e32", "#682c46", "#8a3e5c")
GUT = hexes("#2a070c", "#5c1420", "#8e2433", "#bb4b54", "#dd8584")


# --- the tiyanak ---

def tiyanak_bundle(cry: float = 0.0, shake: float = 0.0) -> Sculpt:
    """A baby swaddled in a stained lampin, lying in the leaves, crying. 64 x 64, on the ground."""
    s = Sculpt(64, 64)
    for name, ramp in [("cloth", CLOTH), ("baby", BABY), ("gum", GUM)]:
        s.material(name, ramp)
    cx, ground = 32 + shake, 63
    s.ellipse("cloth", cx - 2, ground - 9, 15, 9)              # the swaddled body
    s.ellipse("cloth", cx + 9, ground - 15, 9, 9)              # the hood
    s.ellipse("baby", cx + 10, ground - 14, 6, 6)              # the face
    s.capsule("cloth", (cx - 12, ground - 12), (cx + 6, ground - 6), 3, 3)  # a fold across
    d = s
    def face():
        # Eyes squeezed shut, the brow knotted, the mouth open in a cry.
        s.line((cx + 7, ground - 16), (cx + 9, ground - 15), s.tone("baby", 0))
        s.line((cx + 11, ground - 15), (cx + 13, ground - 16), s.tone("baby", 0))
        mouth = 1 + int(cry * 2)
        s.ellipse("gum", cx + 10, ground - 11, 2.2, 0.8 + mouth * 0.6)
        # Dirt and a stain on the cloth.
        for x, y in [(cx - 8, ground - 6), (cx - 3, ground - 4), (cx + 2, ground - 7)]:
            s.dot(x, y, s.tone("cloth", 1))
        s.curve([(cx - 14, ground - 13), (cx - 4, ground - 16), (cx + 4, ground - 15)], s.tone("cloth", 4), only_on_body=True)
    face()
    return d


def tiyanak_true(step: float = 0.0, run: bool = False) -> Sculpt:
    """What is in the bundle: small, hunched, hairless, wrinkled and red; huge burning eyes, a
    wide mouth of needles, long claws. 64 x 64, on the ground."""
    s = Sculpt(64, 64)
    for name, ramp in [("far", TIY[[0, 0, 1, 2, 3, 3]]), ("skin", TIY), ("eye", EYE_RED), ("tooth", TOOTH), ("gum", GUM)]:
        s.material(name, ramp)
    cx, ground = 30, 63
    sw = math.sin(step * math.tau) * (6 if run else 1)
    # Far limbs.
    s.capsule("far", (cx - 4, ground - 14), (cx - 8 - sw, ground - 1), 2.4, 1.6)
    s.capsule("far", (cx + 4, ground - 24), (cx + 12 + sw, ground - 12), 1.8, 1.2)
    # A pot-bellied, hunched body; a big round head thrust forward.
    s.ellipse("skin", cx, ground - 16, 9, 9)
    head = (cx + 9, ground - 27)
    s.ellipse("skin", head[0], head[1], 9, 8.5)
    s.capsule("skin", (cx - 1, ground - 14), (cx + 5 + sw, ground - 1), 2.8, 1.8)
    s.ellipse("skin", cx + 6 + sw, ground - 1.5, 3, 1.5)
    arm_end = (cx + 16 - sw, ground - 10)
    s.capsule("skin", (cx + 5, ground - 22), arm_end, 2.2, 1.6)
    # Pointed ears back.
    s.poly("skin", [(head[0] - 7, head[1] - 2), (head[0] - 15, head[1] - 7), (head[0] - 6, head[1] + 2)], bulge=0.3)

    def details():
        # Claws: long, curved, three.
        for k in range(3):
            s.curve([arm_end, (arm_end[0] + 3, arm_end[1] + 1 + k), (arm_end[0] + 5, arm_end[1] + 3 + k * 1.5)], s.tone("tooth", 2))
        # Wrinkles over the brow and the belly.
        for k in range(3):
            s.curve([(head[0] - 5, head[1] - 6 + k * 2), (head[0], head[1] - 7 + k * 2), (head[0] + 4, head[1] - 5 + k * 2)], s.tone("skin", 1), only_on_body=True)
        s.curve([(cx - 6, ground - 14), (cx, ground - 11), (cx + 6, ground - 14)], s.tone("skin", 1), only_on_body=True)
        # Two huge eyes, burning, with glints.
        for ex in (head[0] + 1.5, head[0] + 7.5):
            s.ellipse("eye", ex, head[1] - 1.5, 3.3, 3.3)
        for ex in (head[0] + 1.5, head[0] + 7.5):
            s.line((ex + 0.5, head[1] - 3.5), (ex + 0.5, head[1] + 0.5), s.tone("eye", 0))
            s.dot(ex - 1, head[1] - 3, (255, 255, 255))
        # The mouth, wide, needle teeth.
        s.ellipse("gum", head[0] + 5, head[1] + 4.5, 5, 2)
        for k in range(5):
            x = head[0] + 1.5 + k * 1.8
            s.dot(x, head[1] + 3.5, s.tone("tooth", 3))
            s.dot(x + 0.8, head[1] + 5.5, s.tone("tooth", 2))
    details()
    return s


# --- the santelmo ---

def santelmo(flicker: float = 0.0, hot: float = 0.0) -> Sculpt:
    """A ball of ghost-fire with licking tongues of flame. 64 x 64, centred. `hot` 0..1 while it
    wants her: brighter and taller."""
    s = Sculpt(64, 64)
    s.material("fire", FIRE)
    s.material("core", FIRE[[2, 3, 3, 4, 4]])
    cx, cy = 32, 40
    r = 9 + hot * 2
    sway = math.sin(flicker * math.tau) * 2.5
    tall = 22 + hot * 6 + math.sin(flicker * math.tau * 2) * 2
    # A teardrop: a round belly of fire drawing up to a swaying tip.
    s.ellipse("fire", cx, cy, r, r * 0.95)
    s.poly("fire", [(cx - r * 0.9, cy - 2), (cx - r * 0.4 + sway * 0.4, cy - tall * 0.6), (cx + sway, cy - tall),
        (cx + r * 0.45 + sway * 0.4, cy - tall * 0.55), (cx + r * 0.9, cy - 2)], bulge=0.45)
    # A smaller lick beside it.
    s.poly("fire", [(cx + r * 0.3, cy - 4), (cx + r * 0.9 - sway, cy - tall * 0.7), (cx + r * 0.95, cy - 3)], bulge=0.4)
    s.ellipse("core", cx + 0.5, cy + 1.5, r * 0.5, r * 0.55)
    s.poly("core", [(cx - r * 0.35, cy), (cx + sway * 0.5, cy - tall * 0.45), (cx + r * 0.35, cy)], bulge=0.4)
    img = s
    for k in range(4):
        a = flicker * math.tau + k * 1.6
        s.dot(cx + math.cos(a) * (r + 5), cy - 6 - k * 4 + math.sin(a) * 2, s.tone("fire", 3), alpha=200)
    return img


# --- the nuno's mound ---

def nuno_mound(peek: float = 0.0) -> Sculpt:
    """A punso: a termite mound of two earths, burrows in its sides, grass at its foot, and on a
    banana leaf before it what has been left for the nuno -- rice and an egg. 176 x 64, on the
    ground; the mound 150 wide and 34 high, as the level has it."""
    s = Sculpt(176, 64)
    for name, ramp in [("earth", EARTH), ("earth_red", EARTH_RED), ("grass", GRASS), ("leaf", LEAF), ("rice", RICE)]:
        s.material(name, ramp)
    ground = 63
    cx = 88
    s.ellipse("earth", cx, ground, 75, 34)
    # Bands of the redder earth, ridged like a termite mound's walls.
    for k, (dx, w, h) in enumerate([(-30, 22, 26), (12, 26, 30), (42, 18, 20), (-52, 14, 16)]):
        s.ellipse("earth_red", cx + dx, ground, w, h)
    s.ellipse("earth", cx - 6, ground - 2, 18, 30)
    # Grass tufts round the foot.
    for k in range(14):
        x = 14 + k * 11 + (k % 3) * 2
        s.poly("grass", [(x - 3, ground), (x - 1 + (k % 2), ground - 6 - (k % 3) * 2), (x + 3, ground)], bulge=0.2)
    # The offering: a banana leaf with rice heaped on it, before the mound.
    s.ellipse("leaf", cx + 56, ground - 2, 14, 3)
    s.ellipse("rice", cx + 54, ground - 5, 6, 3.5)
    s.ellipse("rice", cx + 62, ground - 5, 3, 3.6)        # an egg
    img = s
    # Burrows: dark mouths in the walls, a lit lip above each.
    for x, y, w in [(cx - 22, ground - 14, 3), (cx + 14, ground - 22, 2.5), (cx + 34, ground - 9, 2.5), (cx - 46, ground - 8, 2)]:
        for dx in range(-int(w), int(w) + 1):
            s.dot(x + dx, y, s.tone("earth", 0))
            s.dot(x + dx, y + 1, s.tone("earth", 0))
        s.line((x - w, y - 1), (x + w, y - 1), s.tone("earth", 4))
    # Ridges down the walls.
    for x in (cx - 34, cx - 10, cx + 22, cx + 46):
        s.curve([(x, ground - 2), (x + 2, ground - 14), (x + 1, ground - 22)], s.tone("earth", 1), only_on_body=True)
    if peek > 0.5:
        # The nuno, peering from the biggest burrow: two pinprick eyes and a white beard.
        x, y = cx - 22, ground - 14
        s.dot(x - 1, y, s.tone("rice", 3))
        s.dot(x + 1, y, s.tone("rice", 3))
        s.line((x - 1, y + 1), (x + 1, y + 1), s.tone("rice", 2))
    return img


# --- the manananggal's lower half ---

def manananggal_lower(smoke: float = 0.0) -> Sculpt:
    """What she left standing: hips and legs in a tapis, the waist a ragged wound. 72 x 72, on the
    ground."""
    s = Sculpt(72, 72)
    for name, ramp in [("far", SKIN_W[[0, 0, 1, 2, 3, 3]]), ("skin", SKIN_W), ("tapis", TAPIS), ("gut", GUT)]:
        s.material(name, ramp)
    cx, ground = 36, 71
    # Below the hem, two slender legs, the calf full behind, bare feet flat on the ground.
    for name, x in [("far", cx - 4), ("skin", cx + 3)]:
        knee, ankle = (x, ground - 26), (x + 0.5, ground - 4)
        s.tube(name, [knee, (x - 1.4, ground - 17), (x, ground - 8), ankle], [3.6, 4.0, 2.6, 2.0])
        s.tube(name, [(ankle[0] - 1.5, ground - 2.2), (ankle[0] + 2.5, ground - 2), (ankle[0] + 6, ground - 1.6)], [2.2, 2.0, 1.4])
    # The tapis, wrapped from the waist round the hips to the knee: full over the seat behind,
    # close round the thighs, its hem a little uneven.
    s.poly("tapis", [(cx - 6, ground - 51), (cx - 9, ground - 46), (cx - 11.5, ground - 40), (cx - 11, ground - 33),
                     (cx - 8.5, ground - 27), (cx - 7, ground - 22), (cx - 3, ground - 21.5), (cx + 1, ground - 23),
                     (cx + 5, ground - 21.5), (cx + 7.5, ground - 23), (cx + 8.5, ground - 30), (cx + 9.5, ground - 39),
                     (cx + 8.5, ground - 46), (cx + 6, ground - 51)], bulge=0.45)
    # The waist above it, torn: skin ragged at the edge, the wound open on top.
    s.poly("skin", [(cx - 6, ground - 50), (cx - 6.5, ground - 54), (cx - 4, ground - 52.5), (cx - 2, ground - 56),
                    (cx + 1, ground - 53.5), (cx + 3, ground - 56.5), (cx + 5, ground - 53.5), (cx + 6.5, ground - 55),
                    (cx + 6, ground - 50)], bulge=0.4)
    s.ellipse("gut", cx, ground - 54, 5.5, 2.0)
    img = s
    # The wrap's edge folded over the front, and the stripes woven across it, round the hips.
    s.curve([(cx + 5, ground - 50), (cx + 4.5, ground - 38), (cx + 3, ground - 23)], s.tone("tapis", 1), only_on_body=True)
    for y, half in [(ground - 45, 9), (ground - 31, 10)]:
        s.curve([(cx - half, y - 1), (cx - 2, y + 1.5), (cx + half, y - 0.5)], s.tone("tapis", 4), only_on_body=True)
        s.curve([(cx - half, y + 1), (cx - 2, y + 3.5), (cx + half, y + 1.5)], s.tone("tapis", 4), only_on_body=True)
    # What runs from the wound: down the front of the tapis, and the spine's pale end in it.
    for x, ln in [(cx - 3, 6), (cx + 1, 10), (cx + 5, 4)]:
        s.line((x, ground - 51), (x, ground - 51 + ln), s.tone("gut", 2), only_on_body=True)
        s.dot(x, ground - 51 + ln, s.tone("gut", 3))
    s.dot(cx - 1, ground - 54, s.tone("skin", 5))
    s.dot(cx, ground - 54, s.tone("skin", 4))
    s.dot(cx - 3, ground - 53, s.tone("gut", 4))
    s.dot(cx + 4, ground - 54, s.tone("gut", 4))
    if smoke > 0:
        for k in range(8):
            a = k * 0.8
            s.dot(cx + math.cos(a) * (6 + smoke * 10), ground - 54 - smoke * 14 - k, s.tone("tapis", 4), alpha=int(200 * (1 - smoke)))
    return img


# --- the kapre's balete ---

BARK = hexes("#140c08", "#281c14", "#3e2c20", "#58402e", "#745840", "#927456")
WOOD = hexes("#3a2a1a", "#6a5032", "#94764c", "#b89a68", "#d4b886")
LEAVES = hexes("#06160e", "#0d2a18", "#174224", "#225a2e", "#337638", "#4f9446")
# How far up the trunk the kapre's branch comes out (its line at the seat), above the tree's foot.
PERCH = 170


def _leaf_marks(s: Sculpt, count: int, seed: int) -> None:
    """Leaves, not a balloon: small tufts picked out where a clump turns to the light."""
    from creature_sculpt import LIGHT
    k = seed
    for _ in range(count):
        k = (k * 1103515245 + 12345) & 0x7FFFFFFF
        x = k % s.w
        y = (k // s.w) % s.h
        if s.mat[y, x] != s.names["leaves"] or float(s.nrm[y, x] @ LIGHT) * 0.5 + 0.5 < 0.68:
            continue
        c = s.tone("leaves", 5)
        s.dot(x, y, c)
        s.dot(x + 1, y - 1, c)
        s.dot(x + 2, y, c)


def _mass(s: Sculpt, name: str, x: float, y: float, w: float) -> None:
    """A mass of leaf: a flat dark underside, its top broken into lit bumps -- each bump catches
    the light on its own, which is what makes it read as foliage."""
    s.ellipse(name, x, y, w, w * 0.66, flat=0.2)
    n = max(3, int(w / 9))
    for i in range(n):
        a = math.pi * (1.0 + i / (n - 1))
        r = w * (0.36 + 0.08 * ((i * 7) % 3) / 2)
        s.ellipse(name, x + math.cos(a) * w * 0.68, y + math.sin(a) * w * 0.52, r, r * 0.9, flat=0.1)


# The tiyanak's undergrowth: as wide as Tiyanak2D.UNDERGROWTH (480), as tall as its bushes stand
# (58) and a frond's tip over them, UNDERGROWTH_MARGIN px clear at the sides and top.
UNDERGROWTH_W = 480
UNDERGROWTH_H = 72
UNDERGROWTH_MARGIN = 4


def undergrowth() -> Sculpt:
    """The bushes the tiyanak hides its drop with: a ground cover of dark leaf along the whole
    width -- the drop under it never shows through -- two rows of leaf masses heaped on it, dark
    behind and lit in front, broad pointed leaves standing out of them and fronds of small leaves
    arching over. Its bottom row is the ground the tiyanak sits on."""
    m = UNDERGROWTH_MARGIN
    w, h = UNDERGROWTH_W + 2 * m, UNDERGROWTH_H + m
    ground = h
    s = Sculpt(w, h)
    s.material("leaves", LEAVES)
    s.material("leaves_dark", LEAVES[[0, 0, 1, 2, 2, 3]])
    s.material("fern", LEAF)
    # The cover: low dark leaf, solid to the ground, its top broken.
    top = [(m + i * 12.0, ground - 12.0 - 4.0 * math.sin(i * 1.9) - 3.0 * math.sin(i * 0.7))
           for i in range(UNDERGROWTH_W // 12 + 1)]
    s.poly("leaves_dark", [(m, ground)] + top + [(m + UNDERGROWTH_W, ground)], bulge=0.05)
    k = 7

    def rnd(n: int) -> int:
        nonlocal k
        k = (k * 1103515245 + 12345) & 0x7FFFFFFF
        return k % n

    # Behind: dark masses, high and low.
    for x in range(m + 18, m + UNDERGROWTH_W - 24, 24):
        size = 13 + rnd(8)
        _mass(s, "leaves_dark", x + rnd(6), ground - 20 - rnd(14), size)
    # Broad pointed leaves standing out of them, a midrib down each.
    for x in range(m + 26, m + UNDERGROWTH_W - 20, 46):
        tall = 30 + rnd(16)
        lean = rnd(9) - 4
        base = (float(x), ground - 12.0)
        tip = (x + lean * 2.0, ground - 12.0 - tall)
        s.poly("leaves", [base, (x - 7 + lean * 0.6, base[1] - tall * 0.45), tip,
                          (x + 7 + lean * 0.6, base[1] - tall * 0.45)], bulge=0.45)
        s.line(base, (tip[0] - lean * 0.2, tip[1] + 4), s.tone("leaves", 1), only_on_body=True)
    # Fronds of small leaves arching over, left and right.
    for i, x in enumerate(range(m + 50, m + UNDERGROWTH_W - 30, 70)):
        root = (float(x), ground - 16.0)
        for side in (-1, 1):
            reach = 24 + rnd(12)
            rise = 30 + rnd(14)
            pts = [(root[0] + side * reach * u, root[1] - rise * math.sin(u * math.pi * 0.7)) for u in (0.0, 0.3, 0.6, 0.85, 1.0)]
            s.tube("fern", pts, [1.4, 1.2, 1.0, 0.8, 0.6])
            for j in range(1, 9):
                u = j / 9
                lx = root[0] + side * reach * u
                ly = root[1] - rise * math.sin(u * math.pi * 0.7)
                r = 3.4 * (1.0 - u * 0.55)
                s.ellipse("fern", lx - side * 1.5, ly - r * 0.9, r, r * 0.7, flat=0.2)
                s.ellipse("fern", lx + side * 1.5, ly + r * 0.5, r, r * 0.7, flat=0.2)
    # In front: lit masses low on the cover, so it reads as bushes and not as a wall.
    for x in range(m + 16, m + UNDERGROWTH_W - 24, 32):
        size = 10 + rnd(6)
        _mass(s, "leaves", x + rnd(10), ground - 9 - rnd(6), size)
    _leaf_marks(s, 1400, 23)
    return s


def balete(felled: bool = False) -> Sculpt:
    """The kapre's tree: a balete, a strangler fig -- its trunk a lattice of roots grown round the
    tree they strangled, the dark of it showing between them, the roots flaring into buttresses
    at its foot and spreading into its branches at the top, a crown wider than it is tall, roots
    hanging from the branches to the ground. Standing, 260 x 500 with its foot on the bottom
    edge (the trunk about 70 wide, 340 to the crown, as the level has it). Felled, the trunk lies
    along the ground, its root plate torn up at one end, 380 x 96."""
    if felled:
        return _balete_felled()
    s = Sculpt(260, 500)
    s.material("bark", BARK)
    s.material("bark_dark", BARK[[0, 0, 1, 1, 2, 2]])
    s.material("leaves", LEAVES)
    s.material("leaves_dark", LEAVES[[0, 0, 1, 2, 2, 3]])
    cx, ground = 130, 499
    fork = ground - 300
    # The crown behind: the dark of it, spread wide.
    for x, y, rx, ry in [(cx, 146, 116, 50), (cx - 54, 112, 62, 50), (cx + 56, 108, 62, 50), (cx, 86, 70, 48)]:
        s.ellipse("leaves_dark", x, y, rx, ry, flat=0.3)
    for x, y, w in [(cx - 90, 160, 30), (cx + 92, 154, 30), (cx - 84, 118, 28), (cx + 88, 112, 28),
                    (cx - 48, 76, 30), (cx + 50, 72, 30), (cx, 56, 32), (cx - 40, 180, 28), (cx + 42, 178, 28)]:
        _mass(s, "leaves_dark", x, y, w)
    # The tree inside, strangled: dark between the roots.
    s.poly("bark_dark", [
        (cx - 30, fork - 10), (cx + 30, fork - 10), (cx + 36, fork + 30), (cx + 30, ground - 120),
        (cx + 42, ground - 40), (cx + 70, ground), (cx - 70, ground), (cx - 42, ground - 40),
        (cx - 30, ground - 120), (cx - 36, fork + 30),
    ], bulge=0.15)
    # The kapre's branch: one thick limb out of the trunk's west side, PERCH px up, the way it
    # faces -- where it sits, its back to the trunk -- thinning out and turning up at the end.
    perch = ground - PERCH
    limb = [(cx - 10, perch + 22), (cx - 34, perch + 12), (cx - 62, perch + 6), (cx - 90, perch + 4),
            (cx - 106, perch - 2), (cx - 114, perch - 12)]
    s.tube("bark", limb, [13.0, 11.5, 10.0, 7.6, 5.0, 2.8])
    # A bird's-nest fern on the trunk's other side.
    for k in range(9):
        a = math.radians(-160 + k * 17)
        root = (cx + 36, ground - 196)
        s.tube("leaves", [root, (root[0] + math.cos(a) * 12, root[1] + math.sin(a) * 12 - 3),
                          (root[0] + math.cos(a) * 24, root[1] + math.sin(a) * 20 + 2)], [2.2, 2.6, 0.8])
    # The roots grown round it, twisting, each one tube from its buttress at the foot up through
    # the fork and out along a branch into the crown.
    roots = [(-54, -18, 0.0, 7.0, (cx - 100, 166)), (-32, 2, 1.7, 5.8, (cx - 62, 146)),
             (-10, -22, 3.1, 6.6, (cx - 34, 160)), (12, 20, 4.4, 6.2, (cx + 38, 158)),
             (34, -2, 5.6, 5.8, (cx + 64, 144)), (56, 16, 0.9, 7.0, (cx + 100, 162))]
    paths = []
    for foot, top, phase, r, end in roots:
        pts, radii = [], []
        for j in range(12):
            t = j / 12
            y = ground - 2 - t * (ground - fork)
            spread = (1 - t) ** 2.4
            x = cx + foot * spread + top * (1 - spread) * 0.9 + math.sin(t * 5.2 + phase) * 7 * (1 - 0.6 * spread)
            pts.append((x, y))
            radii.append(r * (1.3 - 0.35 * t) * (0.80 + 0.20 * math.cos(t * 9 + phase)))
        bx, by = pts[-1]
        pts += [(bx + (end[0] - bx) * 0.35, by - 14), (bx + (end[0] - bx) * 0.75, (by + end[1]) / 2 - 4), end]
        radii += [r * 0.9, r * 0.65, r * 0.35]
        s.tube("bark", pts, radii)
        paths.append((pts, radii))
    # Two thin ones crossing over, the way a strangler's roots lattice.
    for p in ([(cx - 30, ground - 70), (cx - 4, ground - 150), (cx + 22, ground - 230)],
              [(cx + 26, ground - 120), (cx + 2, ground - 200), (cx - 20, fork + 6)]):
        s.tube("bark", p, [3.6, 2.8, 3.2])
    # Buttresses: fins flared out along the ground.
    for side in (-1, 1):
        for reach, h in [(96, 48), (78, 76)]:
            s.tube("bark", [(cx + side * 34, ground - h), (cx + side * (reach - 22), ground - 10), (cx + side * reach, ground - 2)],
                   [8.0, 5.0, 2.2])
    # Roots hanging from the branches, the outer two reaching the ground to root again.
    for x0, y0, length, r in [(cx - 92, 168, 110, 1.3), (cx - 66, 182, 200, 1.1), (cx - 46, 200, 76, 1.0),
                              (cx + 56, 196, 90, 1.0), (cx + 78, 170, 150, 1.2), (cx + 96, 162, 64, 1.0)]:
        s.tube("bark", [(x0, y0), (x0 + 2, y0 + length * 0.5), (x0 - 1, y0 + length)], [r, r, r * 0.7])
    for side in (-1, 1):
        x0 = cx + side * 94
        pts = [(x0 + side * math.sin(t * 2.6) * 6, 170 + t * (ground - 171)) for t in (k / 15 for k in range(16))]
        s.tube("bark", pts, [1.2 + 2.2 * (k / 15) ** 3 for k in range(16)])
    # The crown in front: the lit masses, more of them toward the light.
    for x, y, w in [(cx - 66, 138, 30), (cx - 34, 100, 32), (cx + 10, 86, 28), (cx - 14, 54, 24),
                    (cx + 58, 120, 26), (cx - 98, 122, 18), (cx + 96, 142, 16), (cx + 12, 140, 24),
                    (cx - 64, 72, 20), (cx + 50, 70, 18), (cx - 36, 164, 18)]:
        _mass(s, "leaves", x, y, w)
    img = s
    _leaf_marks(s, 2600, 7)
    # Grooves down the shadowed side of each root.
    for pts, radii in paths:
        for (x, y), r in list(zip(pts, radii))[2:11]:
            s.dot(x + r * 0.5, y, s.tone("bark", 1))
            s.dot(x + r * 0.5, y - 3, s.tone("bark", 1))
            s.dot(x + r * 0.5, y - 6, s.tone("bark", 1))
    return img


def _balete_felled() -> Sculpt:
    s = Sculpt(380, 96)
    s.material("bark", BARK)
    s.material("bark_dark", BARK[[0, 0, 1, 1, 2, 2]])
    s.material("wood", WOOD)
    s.material("earth", EARTH)
    s.material("leaves", LEAVES)
    s.material("leaves_dark", LEAVES[[0, 0, 1, 2, 2, 3]])
    ground = 96
    mid = ground - 32
    # The crown's wreck at the far end, crushed flat under the trunk.
    for x, y, w in [(346, ground - 20, 22), (330, ground - 14, 18), (356, ground - 40, 13)]:
        _mass(s, "leaves_dark", x, y, w)
    # The trunk on its side: the strangled tree dark between the roots.
    s.tube("bark_dark", [(44, mid), (200, mid + 1), (338, mid + 2)], [31, 29, 25])
    # The roots running its length, twisting over one another.
    lengthwise = [(-20, 0.0, 6.6), (-7, 1.9, 6.0), (7, 3.6, 7.0), (20, 5.1, 6.0)]
    for off, phase, r in lengthwise:
        pts, radii = [], []
        for j in range(15):
            t = j / 14
            pts.append((48 + t * 290, mid + off + math.sin(t * 6 + phase) * 6))
            radii.append(r * (0.80 + 0.20 * math.cos(t * 10 + phase)) * (1.0 - 0.15 * t))
        s.tube("bark", pts, radii)
    # The broken end, splintered pale, and the stubs of branches that snapped when it fell.
    s.poly("wood", [(334, mid - 22), (346, mid - 18), (342, mid - 8), (354, mid - 2), (344, mid + 6),
                    (352, mid + 14), (338, mid + 22), (330, mid)], bulge=0.2)
    for x, lean in [(246, -1), (296, 1)]:
        s.tube("bark", [(x, mid - 20), (x + lean * 8, mid - 34), (x + lean * 12, mid - 42)], [8, 6.5, 5.5])
        s.ellipse("wood", x + lean * 12, mid - 43, 5, 2.4, flat=0.5)
    # The root plate, torn up with the earth still in it, its roots splayed across the face.
    for a, bend, reach in [(200, 30, 36), (230, -24, 40), (262, 20, 44), (296, -18, 40), (166, -26, 34),
                           (134, 22, 32), (104, -20, 32), (326, 26, 34)]:
        ang, turn = math.radians(a), math.radians(a + bend)
        mid_p = (38 + math.cos(ang) * reach * 0.6, mid - 4 + math.sin(ang) * reach * 0.6)
        s.tube("bark", [(38, mid - 4), mid_p, (mid_p[0] + math.cos(turn) * reach * 0.5, mid_p[1] + math.sin(turn) * reach * 0.5)],
               [4.6, 3.0, 1.2])
    s.poly("earth", [(32, mid - 42), (48, mid - 36), (56, mid - 14), (56, mid + 12), (50, mid + 28),
                     (32, mid + 32), (18, mid + 24), (12, mid + 2), (14, mid - 22), (22, mid - 38)], bulge=0.3)
    for p in ([(24, mid - 30), (38, mid - 10), (34, mid + 10), (46, mid + 26)], [(50, mid - 26), (30, mid + 2), (20, mid + 20)]):
        s.tube("bark", p, [2.6, 3.0, 2.4, 1.6][:len(p)])
    img = s
    _leaf_marks(s, 900, 11)
    for off, phase, r in lengthwise:
        for j in range(1, 14):
            t = j / 14
            x = 48 + t * 290
            y = mid + off + math.sin(t * 6 + phase) * 6
            s.dot(x, y + r * 0.5, s.tone("bark", 1))
            s.dot(x + 3, y + r * 0.5, s.tone("bark", 1))
    for k in range(22):
        x, y = 14 + (k * 13) % 42, mid - 38 + (k * 17) % 68
        if s.mat[y, x] == s.names["earth"]:
            s.dot(x, y, s.tone("earth", 4))
    return img
