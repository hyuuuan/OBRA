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
        for ex in (head[0] + 2, head[0] + 7):
            s.ellipse("eye", ex, head[1] - 1, 2.6, 2.6)
        for ex in (head[0] + 2, head[0] + 7):
            s.dot(ex - 1, head[1] - 2, s.tone("eye", 3))
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
    cx, cy = 32, 38
    r = 9 + hot * 2
    s.ellipse("fire", cx, cy, r, r)
    for k in range(5):
        a = -math.pi / 2 + (k - 2) * 0.5 + math.sin(flicker * math.tau + k) * 0.15
        length = 10 + (k % 2) * 6 + hot * 6 + math.sin(flicker * math.tau * 2 + k * 1.7) * 3
        base = (cx + math.cos(a) * r * 0.6, cy + math.sin(a) * r * 0.6)
        tip = (cx + math.cos(a) * (r + length), cy + math.sin(a) * (r + length))
        s.capsule("fire", base, tip, 4.0 - abs(k - 2) * 0.6, 0.6)
    s.ellipse("core", cx + 1, cy + 1, r * 0.55, r * 0.55)
    img = s
    for k in range(6):
        a = flicker * math.tau + k * 1.05
        s.dot(cx + math.cos(a) * (r + 6), cy + math.sin(a) * (r + 4) - 4, s.tone("fire", 3), alpha=170)
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
    s.capsule("far", (cx - 3, ground - 30), (cx - 5, ground - 2), 4.0, 2.6)
    s.capsule("skin", (cx + 3, ground - 30), (cx + 4, ground - 2), 4.2, 2.8)
    s.ellipse("skin", cx + 6, ground - 1.5, 4, 1.6)
    s.ellipse("far", cx - 2, ground - 1.5, 3.5, 1.4)
    # The tapis, wrapped to the knee, its hem uneven.
    s.poly("tapis", [(cx - 10, ground - 46), (cx + 10, ground - 46), (cx + 9, ground - 22), (cx + 4, ground - 20),
        (cx - 1, ground - 22), (cx - 6, ground - 19), (cx - 10, ground - 22)], bulge=0.35)
    # The waist: torn, wet, what hangs from it.
    s.ellipse("gut", cx, ground - 46, 10, 3.5)
    for dx, ln in [(-5, 7), (0, 10), (5, 6)]:
        s.capsule("gut", (cx + dx, ground - 46), (cx + dx + 1, ground - 46 - ln * 0.4), 1.8, 1.0)
    img = s
    # Stripes woven in the tapis.
    for y in (ground - 40, ground - 32):
        s.line((cx - 9, y), (cx + 9, y), s.tone("tapis", 4))
    s.dot(cx - 3, ground - 47, s.tone("gut", 4))
    s.dot(cx + 4, ground - 46, s.tone("gut", 4))
    if smoke > 0:
        for k in range(8):
            a = k * 0.8
            s.dot(cx + math.cos(a) * (6 + smoke * 10), ground - 48 - smoke * 14 - k, s.tone("tapis", 4), alpha=int(200 * (1 - smoke)))
    return img
