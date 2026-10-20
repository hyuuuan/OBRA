"""The aswang, as the folklore has it: not a dog or a pig but the thing itself at night -- a gaunt,
ash-grey woman-shape crawling on all fours, its elbows and knees jutting up like a spider's, long
matted black hair hanging over its face to the ground, bloodshot eyes peering through it, needle
teeth, long nails, and the long thin tongue, pointed like a mosquito's, it feeds with (the Maximo
Ramos classification, The Aswang Project; Wikipedia, "Aswang"). A ragged skirt is what is left of
the woman it is by day.

Two of them, on the two kinds the night sends (config/enemies.json, unchanged): `aswang_dog`, the
lean one, quick; `aswang_pig`, an old one, hulking and humped, its hair streaked grey, slower and
harder to put down. Sculpted, lit and outlined like the rest (creature_sculpt); 132-px frames, the
feet on the bottom row, the body centred across it, facing east.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

from creature_sculpt import Sculpt, hexes

EYE_RED = hexes("#4a0a08", "#b3241a", "#ff4a2a", "#ffc08a")
TOOTH = hexes("#3d3428", "#8f8670", "#d4caa8", "#f2ead2")
GUM = hexes("#2a070c", "#5c1420", "#8e2433", "#b54050")
TONGUE = hexes("#24050e", "#4e0e1e", "#7a1a30", "#a63046", "#cc5866")
SCLERA = hexes("#5a2a2a", "#b88480", "#e2c2ba", "#f8e6de")


@dataclass
class Aswang:
    name: str
    skin: object
    hair: object
    cloth: object
    torso: float = 30.0         # hip to shoulder
    chest: float = 9.5          # the ribcage's half-height
    waist: float = 6.5
    hump: float = 0.0           # 0 none .. 1 a crone's hump between the shoulders
    thigh: float = 22.0
    shin: float = 26.0
    upper_arm: float = 20.0
    forearm: float = 22.0
    limb_r: float = 3.4
    head_r: float = 12.0
    hair_len: float = 1.0       # how far the hair hangs: 1 to the ground
    grey: bool = False          # the hair streaked grey


@dataclass
class Crawl:
    phase: float = 0.0          # the crawl cycle, 0..1
    stride: float = 0.0         # 0 still .. 1 scuttling
    rear: float = 0.0           # 0 crawling .. 1 reared back on its haunches, claw up
    reach: float = 0.0          # 0 .. 1 lunged forward, the claw swept out
    tongue: float = 0.3         # 0 in .. 1 lashed out
    mouth: float = 0.4
    recoil: float = 0.0         # 0 .. 1 thrown back by a blow
    down: float = 0.0           # 0 .. 1 collapsing
    bob: float = 0.0


def _bend(a, b, length_a, length_b, up: float):
    """The joint between a and b for two bones of these lengths, bent toward `up` (-1 up, 1 down)."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    d = max(1e-3, math.hypot(dx, dy))
    d = min(d, length_a + length_b - 0.5)
    cos_a = (length_a * length_a + d * d - length_b * length_b) / (2 * length_a * d)
    ang = math.acos(max(-1.0, min(1.0, cos_a)))
    base = math.atan2(dy, dx)
    side = -1.0 if up < 0 else 1.0
    # Of the two bends, the one on the `up` side of the line a->b.
    for sign in (1, -1):
        t = base + sign * ang
        j = (a[0] + math.cos(t) * length_a, a[1] + math.sin(t) * length_a)
        cross = (b[0] - a[0]) * (j[1] - a[1]) - (b[1] - a[1]) * (j[0] - a[0])
        if (cross < 0) == (side < 0):
            return j
    return (a[0] + math.cos(base + ang) * length_a, a[1] + math.sin(base + ang) * length_a)


def _limb(s: Sculpt, name: str, root, end, la: float, lb: float, up: float, r: float, knob: float = 1.25):
    joint = _bend(root, end, la, lb, up)
    s.tube(name, [root, ((root[0] + joint[0]) / 2, (root[1] + joint[1]) / 2), joint,
                  ((joint[0] + end[0]) / 2, (joint[1] + end[1]) / 2), end], [r * 1.15, r, r * 0.8, r * 0.85, r * 0.6])
    s.ellipse(name, joint[0], joint[1], r * knob * 0.8, r * knob * 0.8)       # the knob of a bony joint
    return joint


def _claws(s: Sculpt, name: str, at, forward: float, n: int, spread: float, length: float, lift: float = 0.0):
    """A hand or foot flat on the ground: a palm, long bony fingers splayed forward, nails."""
    s.ellipse(name, at[0], at[1] - 1.2, 3.4, 2.2)
    tips = []
    for k in range(n):
        a = math.radians(-spread / 2 + spread * k / max(1, n - 1)) - lift
        tip = (at[0] + forward * math.cos(a) * length, at[1] - 0.8 + math.sin(a) * length * 0.35)
        s.capsule(name, (at[0] + forward * 1.5, at[1] - 1.0), tip, 0.95, 0.6)
        tips.append(tip)
    return tips


def draw(a: Aswang, c: Crawl) -> Sculpt:
    S = 132
    s = Sculpt(S, S)
    far = a.skin[[0, 0, 1, 2, 3, 3]]
    for name, ramp in [("far", far), ("skin", a.skin), ("limb", a.skin), ("hair", a.hair),
                       ("hair_lit", a.hair[[1, 2, 3, 4, 4]]), ("cloth", a.cloth), ("tongue", TONGUE), ("gum", GUM),
                       ("tooth", TOOTH), ("sclera", SCLERA), ("eye", EYE_RED)]:
        s.material(name, ramp)
    ground = S - 2.0
    step = math.tau * c.phase
    sw = c.stride * 6.0
    lift = lambda ph: max(0.0, math.sin(ph)) * 4.0 * c.stride
    sink = c.down * 22.0
    # The hips high, the shoulders low and forward: a stalking crawl. Rearing sits it back on its
    # haunches and lifts the shoulders; a lunge throws them forward; a blow knocks them back.
    hip = (S * 0.5 - a.torso * 0.5 - c.rear * 4 - c.recoil * 4 - c.reach * 10, ground - 38 + c.rear * 8 + sink * 0.6 - c.bob)
    shoulder = (hip[0] + a.torso + c.reach * 14 - c.rear * 8 - c.recoil * 8,
                ground - 30 - c.rear * 26 + c.recoil * 2 + sink - c.bob * 0.6)
    spine = math.atan2(shoulder[1] - hip[1], shoulder[0] - hip[0])
    # Feet and hands on the ground, moving in diagonal pairs.
    foot_far = (hip[0] - 14 - sw * math.sin(step + math.pi) - c.rear * 4, ground - lift(step + math.pi))
    foot_near = (hip[0] - 10 - sw * math.sin(step) - c.rear * 4, ground - lift(step))
    hand_far = (shoulder[0] + 14 + sw * math.sin(step) + c.reach * 8, ground - 1 - lift(step))
    hand_near = (shoulder[0] + 18 + sw * math.sin(step + math.pi) + c.reach * 14, ground - lift(step + math.pi))
    if c.rear > 0:
        # Reared, the near claw comes up off the ground, raised to strike.
        hand_near = (hand_near[0] * (1 - c.rear) + (shoulder[0] + 24) * c.rear, hand_near[1] * (1 - c.rear) + (shoulder[1] - 22) * c.rear)
    if c.reach > 0.5:
        # Lunging, it sweeps out level, the nails first.
        hand_near = (shoulder[0] + a.upper_arm + a.forearm - 12, shoulder[1] + 4)
    if c.down > 0:
        hand_near = (hand_near[0] + c.down * 6, min(ground, hand_near[1] + c.down * 30))
        hand_far = (hand_far[0] + c.down * 4, ground)
    head = (shoulder[0] + 10 + c.reach * 6 - c.recoil * 6, shoulder[1] - 4 - c.rear * 6 - c.recoil * 6 + c.down * 6)
    sway = math.sin(step) * 2.0 * c.stride + math.sin(c.bob * 3.0) * 0.8

    def hair_strand(root, k: int, n: int, lit: bool):
        hang = ground - 3 - root[1]
        hang = hang * a.hair_len * (0.75 + 0.25 * ((k * 5) % 3) / 2)
        if c.down > 0:
            hang *= 1 - c.down * 0.5
        x = root[0] + sway * (0.5 + k / n)
        pts = [root, (x + 1.5 - (k % 3), root[1] + hang * 0.35), (x - 1 + (k % 2) * 2, root[1] + hang * 0.7),
               (x + (k % 3) - 1 + sway, root[1] + hang)]
        s.tube("hair_lit" if lit else "hair", pts, [2.6, 2.3, 1.8, 0.7])

    # Far limbs first.
    _limb(s, "far", (hip[0] - 1, hip[1] + 2), foot_far, a.thigh, a.shin, -1, a.limb_r * 1.05)
    _claws(s, "far", foot_far, -1, 3, 50, 5.0)
    far_shoulder = (shoulder[0] - 3, shoulder[1] + 1)
    _limb(s, "far", far_shoulder, hand_far, a.upper_arm, a.forearm, -1, a.limb_r * 0.95)
    _claws(s, "far", hand_far, 1, 4, 60, 7.0)
    # The hair behind: from the back of the skull down its back and to the ground.
    for k in range(7):
        root = (head[0] - 9 + k * 1.6, head[1] - 7 + k * 0.6)
        hair_strand(root, k, 7, k % 3 == 1)
    # The body: a gaunt torso, the hips high, the ribcage at the shoulders, a hump if it has one.
    mid = ((hip[0] + shoulder[0]) / 2, (hip[1] + shoulder[1]) / 2 - 2)
    s.tube("skin", [hip, mid, shoulder], [a.waist + 1.5, a.waist, a.chest])
    if a.hump > 0:
        s.ellipse("skin", shoulder[0] - 7, shoulder[1] - a.chest * 0.7, a.chest * (0.7 + 0.4 * a.hump), a.chest * (0.5 + 0.4 * a.hump))
    # Its skirt: rags hung from the raised hips, the hem torn into strips.
    drop = 18 - c.down * 8
    hem = []
    for k in range(9):
        t = k / 8
        x = hip[0] - 10 + t * 22
        y = hip[1] + drop * (0.5 + 0.5 * t) * (0.55 if k % 2 else 1.0)
        hem.append((x + (1.2 if k % 2 else 0.0), y))
    s.poly("cloth", [(hip[0] - 10, hip[1] - 5), (hip[0] + 4, hip[1] - 7), (hip[0] + 12, hip[1] - 3)] + hem[::-1], bulge=0.2)
    # The near leg: the knee up high, the long foot flat, the toes nailed.
    knee = _limb(s, "limb", (hip[0] + 2, hip[1] + 3), foot_near, a.thigh, a.shin, -1, a.limb_r * 1.15)
    _claws(s, "limb", foot_near, -1, 3, 50, 5.5)
    # The near arm: long, the elbow up, the nails long -- behind the head, so the face shows, except
    # when it is raised to strike or sweeps out in a lunge, in front of everything.
    near_shoulder = (shoulder[0] + 1, shoulder[1] + 2)
    up = c.rear > 0.3 or c.reach > 0.5

    def near_arm():
        joint = _limb(s, "limb", near_shoulder, hand_near, a.upper_arm, a.forearm, -1, a.limb_r * 1.05)
        _claws(s, "limb", hand_near, 1, 4, 70, 9.0 if up else 7.5, lift=0.5 if c.rear > 0.3 else 0.0)
        return joint

    in_front = c.reach > 0.5 or c.rear > 0.3
    if not in_front:
        elbow = near_arm()
    # The head: thrust forward and low, tilted up at her; the skull gaunt, the jaw long.
    s.capsule("skin", (shoulder[0] + 2, shoulder[1] - 2), (head[0] - 3, head[1] + 2), a.chest * 0.55, a.head_r * 0.55)
    s.ellipse("skin", head[0], head[1], a.head_r, a.head_r * 0.98)
    jaw = (head[0] + a.head_r * 0.45, head[1] + a.head_r * 0.62)
    s.ellipse("skin", jaw[0], jaw[1], a.head_r * 0.62, a.head_r * 0.42)
    # Hair over the crown and the back of the skull, parted over the face, hanging past it to the
    # ground: a curtain either side of the eyes, which show through.
    s.ellipse("hair", head[0] - a.head_r * 0.35, head[1] - a.head_r * 0.4, a.head_r * 0.95, a.head_r * 0.75)
    s.ellipse("hair", head[0] - a.head_r * 0.55, head[1] + a.head_r * 0.1, a.head_r * 0.6, a.head_r * 0.85)
    for k in range(7):
        if k in (4, 5):
            continue          # the parting, over the eyes
        root = (head[0] - a.head_r * 0.95 + k * a.head_r * 0.3, head[1] - a.head_r * 0.62 + abs(k - 3) * 0.5)
        hair_strand(root, k, 7, k % 2 == 0)
    # The locks either side of the face, hanging straight down past it.
    for k, dx in enumerate((0.15, 1.02)):
        hair_strand((head[0] + a.head_r * dx, head[1] - a.head_r * 0.35), k + 3, 7, k == 1)
    if in_front:
        elbow = near_arm()
    # The mouth open on needle teeth, and the tongue: long, thin, a mosquito's point.
    mouth = (head[0] + a.head_r * 0.62, head[1] + a.head_r * 0.62)
    gape = 1.2 + c.mouth * 2.2 + c.recoil * 1.5
    s.ellipse("gum", mouth[0], mouth[1], a.head_r * 0.32, gape)
    if c.tongue > 0.05:
        length = 6 + c.tongue * 30
        pts = [mouth]
        for k in range(1, 7):
            t = k / 6
            droop = math.sin(t * math.pi * 0.9) * (8 - c.tongue * 4) + t * t * 10 * (1 - c.tongue * 0.6)
            pts.append((mouth[0] + t * length, mouth[1] + droop + math.sin(t * 6 + c.phase * 6 + c.bob) * 1.2))
        s.tube("tongue", pts, [1.6, 1.4, 1.2, 1.0, 0.8, 0.5, 0.25])

    def details():
        # The ribs and the knobs of the spine.
        for k in range(4):
            t = 0.55 + k * 0.11
            x = hip[0] + (shoulder[0] - hip[0]) * t
            y = hip[1] + (shoulder[1] - hip[1]) * t
            s.curve([(x - 1.5, y - a.chest * 0.2), (x, y + a.chest * 0.45), (x + 1.2, y + a.chest * 0.75)], s.tone("skin", 1), only_on_body=True)
        for k in range(6):
            t = 0.1 + k * 0.15
            x = hip[0] + (shoulder[0] - hip[0]) * t
            y = hip[1] + (shoulder[1] - hip[1]) * t - (a.waist if t < 0.5 else a.chest) * 0.95
            s.dot(x, y, s.tone("skin", 4))
        # The eyes: bloodshot, a red iris and a pinprick, peering out between the hair.
        for (ex, ey, r) in [(head[0] + a.head_r * 0.25, head[1] - a.head_r * 0.05, 2.4), (head[0] + a.head_r * 0.72, head[1] - a.head_r * 0.02, 2.0)]:
            for dx in range(-3, 4):
                for dy in range(-3, 4):
                    if dx * dx + dy * dy <= r * r + 0.5:
                        s.dot(ex + dx, ey + dy, s.tone("sclera", 2 if dy > 0 else 3))
            for dx, dy in [(0, 0), (1, 0), (0, 1), (1, 1), (0, -1), (1, -1)]:
                s.dot(ex + dx, ey + dy, s.tone("eye", 2))
            s.dot(ex + 1, ey, s.tone("eye", 0))
            s.dot(ex - 1, ey - 1, s.tone("eye", 3))
            # Veins, red, from the corners.
            s.dot(ex - r, ey, s.tone("eye", 1))
            s.dot(ex - r + 1, ey + 1, s.tone("eye", 1))
            s.dot(ex + r, ey + 1, s.tone("eye", 1))
            # The brow, heavy, a scowl.
            s.line((ex - r - 0.5, ey - r - 0.5), (ex + r, ey - r + 0.8), s.tone("skin", 0))
        # Needle teeth top and bottom.
        for k in range(4):
            tx = mouth[0] - a.head_r * 0.24 + k * a.head_r * 0.17
            s.line((tx, mouth[1] - gape + 0.2), (tx, mouth[1] - gape + 1.6), s.tone("tooth", 3))
            s.line((tx + 0.8, mouth[1] + gape - 0.2), (tx + 0.8, mouth[1] + gape - 1.4), s.tone("tooth", 2))
        # A sunken cheek, the knobs of the knee and elbow catching the light.
        s.curve([(head[0] - a.head_r * 0.1, head[1] + a.head_r * 0.3), (head[0] + a.head_r * 0.2, head[1] + a.head_r * 0.6)], s.tone("skin", 1), only_on_body=True)
        for j in (knee, elbow):
            s.dot(j[0] - 1, j[1] - 1, s.tone("skin", 5))
        if a.grey:
            # Grey streaks through the hair.
            for k in range(9):
                x = head[0] - a.head_r + k * 2.4
                for y in range(int(head[1] - a.head_r * 0.8), int(ground - 6), 3):
                    if s.mat[min(S - 1, max(0, y)), min(S - 1, max(0, int(x)))] in (s.names["hair"], s.names["hair_lit"]) and (y + k * 5) % 7 == 0:
                        s.dot(x, y, s.tone("hair_lit", 4))
    s.details = details
    return s


ASH = hexes("#121510", "#262c24", "#3e463a", "#5a6250", "#7a8068", "#9aa086")
ASH_OLD = hexes("#14120e", "#2c2820", "#463e32", "#62584a", "#827864", "#a29a82")
HAIR = hexes("#040305", "#0c0a0e", "#16131a", "#221d28", "#342c3c")
HAIR_OLD = hexes("#0a0a0c", "#1c1c20", "#302f36", "#4a4852", "#8a8892")
RAGS = hexes("#180a0a", "#341616", "#4e2222", "#683030", "#82423e")
RAGS_OLD = hexes("#0e0c14", "#1e1a2a", "#2e283e", "#403852", "#544a68")

LEAN = Aswang("aswang_dog", ASH, HAIR, RAGS, head_r=13.5)
OLD = Aswang("aswang_pig", ASH_OLD, HAIR_OLD, RAGS_OLD, torso=32, chest=12, waist=9.5, hump=0.6, thigh=20, shin=22,
             upper_arm=19, forearm=21, limb_r=4.2, head_r=14.5, hair_len=0.95, grey=True)


def crawl(n: int = 4) -> list[Crawl]:
    return [Crawl(phase=k / n, stride=1.0, bob=abs(math.sin(k / n * math.tau)) * 1.5, tongue=0.25, mouth=0.4) for k in range(n)]


ANIMS = {
    "idle": [Crawl(tongue=0.2, mouth=0.3), Crawl(tongue=0.45, mouth=0.5, bob=0.8)],
    "run": crawl(4),
    "windup": [Crawl(rear=0.7, tongue=0.6, mouth=0.8), Crawl(rear=1.0, tongue=0.9, mouth=1.0)],
    "attack": [Crawl(reach=1.0, tongue=0.35, mouth=1.0), Crawl(reach=0.7, tongue=0.3, mouth=0.8)],
    "hurt": [Crawl(recoil=1.0, tongue=0.1, mouth=1.0)],
    "death": [Crawl(recoil=0.5, down=0.35, tongue=0.4, mouth=0.8), Crawl(down=0.7, tongue=0.6, mouth=0.6), Crawl(down=1.0, tongue=0.7, mouth=0.3)],
}


def strips(a: Aswang) -> dict:
    return {anim: [draw(a, c) for c in poses] for anim, poses in ANIMS.items()}
