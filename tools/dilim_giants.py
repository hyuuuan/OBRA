"""Dilim's tall ones on one two-legged rig: the tikbalang, the kapre and the bungisngis.

A `Giant` is proportions, palette and a head; a `Stance` poses it (legs' stride phase, how far it
leans, where the arms are, what the face is doing). Every frame is sculpted, lit and outlined the
same way (creature_sculpt). Facing right as drawn; the feet stand on the frame's bottom edge and the
body is centred across it, which is what sits on the creature's position in the game.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

from creature_sculpt import Sculpt, hexes, rot

EYE_RED = hexes("#4a0a08", "#b3241a", "#ff4a2a", "#ffc08a")
TOOTH = hexes("#3d3428", "#8f8670", "#d4caa8", "#f2ead2")
GUM = hexes("#2a070c", "#5c1420", "#8e2433", "#b54050")
GOLD = hexes("#5a3d10", "#9a6f1e", "#d6a73a", "#f5d27a")
HOOF = hexes("#100c0a", "#2a221d", "#463b33", "#665a4f")


@dataclass
class Giant:
    name: str
    skin: object
    hair: object
    size: int = 200
    leg: float = 64.0           # hip to sole
    thigh_r: float = 5.0
    shin_r: float = 3.6
    torso: float = 46.0         # hip to the base of the neck
    chest_r: float = 13.0
    waist_r: float = 9.0
    arm: float = 58.0           # shoulder to fingertip
    arm_r: float = 3.6
    neck: float = 10.0
    head: str = "horse"
    feet: str = "hoof"          # hoof / foot
    cloth: object = None        # a bahag, if any
    gaunt: bool = True
    belly: float = 0.0          # 0 none .. 1 a great round gut


@dataclass
class Stance:
    phase: float = 0.0          # walk cycle 0..1
    stride: float = 0.0         # 0 standing .. 1 a full stride
    lean: float = 0.0           # degrees forward
    bob: float = 0.0
    arm_swing: float = 0.0      # 0 .. 1 with the stride
    arms_up: float = 0.0        # 0 down .. 1 raised overhead (a club's windup)
    mouth: float = 0.0          # 0 shut .. 1 wide
    shake: float = 0.0          # px sideways (a laugh)
    sit: float = 0.0            # 0 standing .. 1 sat down


def _along(a, b, t: float, push: float = 0.0):
    """The point t along a->b, pushed off the line toward the front (+x, the way they face) by
    `push`, or toward the back if it is negative -- where a muscle swells."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dx, dy) or 1.0
    px, py = -dy / n, dx / n
    if px < 0:
        px, py = -px, -py
    return (a[0] + dx * t + px * push, a[1] + dy * t + py * push)


def _leg(s: Sculpt, g: Giant, name: str, hip, phase: float, st: Stance, ground: float) -> None:
    swing = math.sin(phase * math.tau) * 16.0 * st.stride
    lift = max(0.0, math.cos(phase * math.tau)) * 7.0 * st.stride
    sat = st.sit
    foot = (hip[0] + swing + sat * 18, ground - lift)
    reach = math.hypot(foot[0] - hip[0], foot[1] - hip[1])
    bend = max(0.0, (g.leg - reach)) * 0.55 + 6 + sat * 20
    knee = ((hip[0] + foot[0]) / 2 + bend, (hip[1] + foot[1]) / 2 - sat * 10)
    # One tube: the thigh full over the front, the knee narrow, the calf full behind, the ankle
    # thin -- not a pipe.
    t, sh = g.thigh_r, g.shin_r
    s.tube(name, [hip, _along(hip, knee, 0.42, t * 0.18), knee, _along(knee, foot, 0.3, -sh * 0.32),
                  _along(knee, foot, 0.86), foot], [t, t * 1.08, sh * 0.84, sh * 1.12, sh * 0.6, sh * 0.62])
    kneecap = _along(hip, knee, 0.97, sh * 0.42)
    s.ellipse(name, kneecap[0], kneecap[1], sh * 0.55, sh * 0.5)
    if g.feet == "hoof":
        s.capsule(name, (foot[0], foot[1] - 9), (foot[0] + 0.5, foot[1] - 6), g.shin_r * 0.9, g.shin_r * 1.1)
        s.poly("hoof", [(foot[0] - 4.5, foot[1] - 7), (foot[0] + 5, foot[1] - 7), (foot[0] + 7, foot[1]), (foot[0] - 5, foot[1])], bulge=0.35)
    else:
        s.ellipse(name, foot[0] + 4, foot[1] - 2.5, g.shin_r + 4, 3)


def _arm(s: Sculpt, g: Giant, name: str, shoulder, swing: float, up: float, hand_out: list) -> None:
    upper = g.arm * 0.46
    lower = g.arm * 0.42
    a = math.radians(4 + swing * 26 - up * 150)
    elbow = (shoulder[0] + math.sin(a) * upper, shoulder[1] + math.cos(a) * upper)
    b = a + math.radians(6 - up * 40)
    hand = (elbow[0] + math.sin(b) * lower, elbow[1] + math.cos(b) * lower)
    # The shoulder's round cap, then one tube: the biceps full, the elbow narrow, the forearm full
    # near the elbow, the wrist thin.
    r = g.arm_r
    s.ellipse(name, shoulder[0], shoulder[1] + r * 0.3, r * 1.45, r * 1.3)
    s.tube(name, [shoulder, _along(shoulder, elbow, 0.5, r * 0.22), elbow, _along(elbow, hand, 0.3, r * 0.1),
                  _along(elbow, hand, 0.88), hand], [r * 1.15, r * 1.2, r * 0.76, r * 1.0, r * 0.6, r * 0.62])
    # The hand, and long fingers, three of them, hanging.
    palm = (hand[0] + math.sin(b) * r * 0.5, hand[1] + math.cos(b) * r * 0.5)
    s.ellipse(name, palm[0], palm[1], r * 0.78, r * 0.86)
    for k in range(3):
        tip = (palm[0] + math.sin(b) * r * 1.5 + (k - 1) * r * 0.34, palm[1] + math.cos(b) * r * 1.5 + k * r * 0.12)
        s.capsule(name, palm, tip, r * 0.27, r * 0.15)
    hand_out.append(hand)


def draw(g: Giant, st: Stance) -> Sculpt:
    S = g.size
    s = Sculpt(S, S)
    far_skin = g.skin[[0, 0, 1, 2, 3, 3]]
    # The near limbs are the skin's own colour under another name, so an edge is drawn where they
    # cross the body -- otherwise an arm hanging in front of the chest melts into it.
    mats = [("far", far_skin), ("skin", g.skin), ("limb", g.skin), ("hair", g.hair), ("hair_lit", g.hair[[1, 2, 3, 4, 4]]),
        ("hoof", HOOF), ("eye", EYE_RED), ("tooth", TOOTH), ("gum", GUM), ("gold", GOLD)]
    if g.cloth is not None:
        mats.append(("cloth", g.cloth))
    mats += _EXTRA
    for name, ramp in mats:
        s.material(name, ramp)
    ground = S - 1.0
    hip_y = ground - g.leg * (1.0 - 0.06 * st.stride) + st.bob + st.sit * g.leg * 0.45
    hip = (S * 0.5 + st.shake, hip_y)
    lean = math.radians(st.lean)
    neck_base = (hip[0] + math.sin(lean) * g.torso, hip[1] - math.cos(lean) * g.torso)
    shoulder_far = (neck_base[0] - 5, neck_base[1] + 5)
    shoulder_near = (neck_base[0] - 2, neck_base[1] + 6)
    hands: list = []
    # Far limbs first.
    _arm(s, g, "far", shoulder_far, -st.arm_swing * math.sin(st.phase * math.tau), st.arms_up, hands)
    _leg(s, g, "far", (hip[0] - 3, hip[1]), st.phase + 0.5, st, ground - 1)
    # The near leg before the body, so the top of the thigh goes under the hips and not over them.
    _leg(s, g, "limb", (hip[0] + 3, hip[1]), st.phase, st, ground)
    # Torso: one tube from the hips through the waist to a chest carried forward.
    pelvis = (hip[0], hip[1] - 2)
    top = (neck_base[0], neck_base[1] + g.chest_r * 0.35)
    waist = _along(pelvis, top, 0.36)
    chest = _along(pelvis, top, 0.72, g.chest_r * 0.12)
    hips = g.waist_r * (0.95 if g.gaunt else 1.0) + (0.0 if g.gaunt else 2.0)
    s.tube("skin", [(pelvis[0] + (2 if g.gaunt else 0), pelvis[1]), waist, chest, top], [hips, g.waist_r, g.chest_r, g.chest_r * 0.8])
    # The chest's front, a mass of its own, and a gut hung under it if it has one.
    pec = (chest[0] + g.chest_r * 0.45, chest[1] + g.chest_r * 0.1)
    if not g.gaunt:
        s.ellipse("skin", pec[0], pec[1], g.chest_r * 0.6, g.chest_r * 0.5, flat=0.6)
    gut = None
    if g.belly > 0:
        gut = (waist[0] + g.waist_r * 0.3 * g.belly, waist[1] + g.waist_r * 0.2)
        s.ellipse("skin", gut[0], gut[1], g.waist_r * (0.7 + 0.35 * g.belly), g.waist_r * (0.66 + 0.3 * g.belly))
    if g.cloth is not None:
        # A bahag: a band hugging the hips, its long flap hanging in front between the legs.
        w = g.waist_r
        s.tube("cloth", [(hip[0] - w * 0.8, hip[1] - 6), (hip[0], hip[1] - 4), (hip[0] + w * 0.84, hip[1] - 6)], [3.0, 3.8, 3.0])
        sway = st.stride * math.sin(st.phase * math.tau) * 3
        s.poly("cloth", [(hip[0] + w * 0.38, hip[1] - 4), (hip[0] + w * 0.86, hip[1] - 4),
            (hip[0] + w * 0.8 + sway, hip[1] + g.leg * 0.42), (hip[0] + w * 0.48 + sway, hip[1] + g.leg * 0.46)], bulge=0.25)
    # The head.
    head_info = HEADS[g.head](s, g, st, neck_base, lean)
    _arm(s, g, "limb", shoulder_near, st.arm_swing * math.sin(st.phase * math.tau), st.arms_up, hands)
    # Ribs on a gaunt chest.
    if g.gaunt:
        cx, cy = neck_base[0] + 2, neck_base[1] + g.chest_r * 0.5
        for k in range(4):
            y = cy + k * 3.5
            s.curve([(cx - g.chest_r * 0.7, y), (cx, y - 1.5), (cx + g.chest_r * 0.7, y + 0.5)], s.tone("skin", 1), only_on_body=True)
    # The line under the chest, the belly's underside and its navel, and a lit edge down the back.
    s.curve([(pec[0] - g.chest_r * 0.4, pec[1] + g.chest_r * 0.42), (pec[0] + g.chest_r * 0.1, pec[1] + g.chest_r * 0.5),
             (pec[0] + g.chest_r * 0.55, pec[1] + g.chest_r * 0.3)], s.tone("skin", 1), only_on_body=True)
    if gut is not None:
        gw, gh = g.waist_r * (0.7 + 0.35 * g.belly), g.waist_r * (0.66 + 0.3 * g.belly)
        s.curve([(gut[0] - gw * 0.5, gut[1] + gh * 0.88), (gut[0] + gw * 0.2, gut[1] + gh * 0.98),
                 (gut[0] + gw * 0.8, gut[1] + gh * 0.6)], s.tone("skin", 1), only_on_body=True)
        s.dot(gut[0] + gw * 0.55, gut[1] + gh * 0.1, s.tone("skin", 1))
        s.dot(gut[0] + gw * 0.55, gut[1] + gh * 0.1 + 1, s.tone("skin", 0))
    s.curve([(pelvis[0] - g.waist_r * 0.8, pelvis[1] - 6), (waist[0] - g.waist_r * 0.85, waist[1]),
             (chest[0] - g.chest_r * 0.85, chest[1])], s.tone("skin", 4), only_on_body=True)
    if head_info:
        head_info()
    s.hands = hands
    return s


# --- heads ---

def _horse_head(s: Sculpt, g: Giant, st: Stance, neck_base, lean):
    # A long neck rising forward, a horse's skull on it: brow, long face, muzzle; ears up; a mane.
    top = (neck_base[0] + 6 + math.sin(lean) * 6, neck_base[1] - g.neck)
    s.capsule("skin", neck_base, top, 6.5, 5.0)
    poll = (top[0] - 1, top[1] - 6)
    muzzle = (poll[0] + 24, poll[1] + 14)
    # The long face tapering from the brow to the muzzle, the nose's line bowed a little, a round
    # jowl at the back of the jaw, and the soft muzzle at the end.
    s.ellipse("skin", poll[0] + 4, poll[1] + 7, 7.0, 6.5)
    s.tube("skin", [poll, _along(poll, muzzle, 0.5, -1.2), muzzle], [7.2, 5.6, 4.4])
    s.ellipse("skin", poll[0] + 2, poll[1] + 1, 7.0, 7.0)
    s.ellipse("skin", muzzle[0] - 0.5, muzzle[1] + 1, 5.0, 4.6)
    jaw = (muzzle[0] - 3, muzzle[1] + 4 + st.mouth * 3)
    s.capsule("skin", (poll[0] + 3, poll[1] + 6), jaw, 4.5, 3.4)
    # Ears, pricked.
    for dx, name in [(-3, "far"), (1, "skin")]:
        base = (poll[0] + dx, poll[1] - 5)
        s.poly(name, [(base[0] - 2, base[1] + 2), (base[0] - 1, base[1] - 9), (base[0] + 3, base[1] + 2)], bulge=0.3)
    # The mane: a thick mass down the crest of the neck to the shoulders, then long strands over it,
    # wind-taken; three of them gold (the folklore's three golden hairs).
    s.capsule("hair", (poll[0] - 3, poll[1] - 3), (neck_base[0] - 6, neck_base[1] + 4), 5.5, 6.5)
    s.capsule("hair", (neck_base[0] - 6, neck_base[1] + 4), (neck_base[0] - 12, neck_base[1] + 22), 6.5, 3.0)
    for k in range(16):
        t = k / 15.0
        root = (poll[0] - 3 - t * 9 + math.sin(lean) * t * 6, poll[1] - 2 + t * 24)
        pts = [root]
        for j in range(1, 5):
            u = j / 4.0
            pts.append((root[0] - u * (12 + t * 8) - st.stride * u * 6,
                root[1] + u * (10 + t * 6) + math.sin(u * 4 + k + st.phase * math.tau) * 1.5))
        mat = "gold" if k in (4, 9, 12) else ("hair_lit" if k % 3 == 1 else "hair")
        for a, b in zip(pts, pts[1:]):
            r = 2.2 * (1 - 0.18 * pts.index(a))
            s.capsule(mat, a, b, r, max(0.6, r - 0.4))
    eye = (poll[0] + 5, poll[1] + 1)

    def details():
        s.line((eye[0] - 3, eye[1] - 2), (eye[0] + 2, eye[1] - 2.5), s.tone("skin", 0))
        s.dot(eye[0], eye[1], s.tone("eye", 3))
        s.dot(eye[0] + 1, eye[1], s.tone("eye", 2))
        s.dot(eye[0] - 1, eye[1] + 0.3, s.tone("eye", 1))
        # The nostril, flared, and the line of the mouth.
        s.dot(muzzle[0] + 2, muzzle[1] - 0.5, s.tone("skin", 0))
        s.dot(muzzle[0] + 3, muzzle[1] - 1, s.tone("skin", 0))
        s.line((muzzle[0] - 6, muzzle[1] + 3), (muzzle[0] + 2, muzzle[1] + 3.5), s.tone("skin", 1))
        if st.mouth > 0.3:
            s.line((muzzle[0] - 4, muzzle[1] + 4), (muzzle[0] + 1, muzzle[1] + 4), s.tone("tooth", 2))
        # The bony ridge of the face, lit.
        s.curve([(poll[0] + 4, poll[1] - 4), (poll[0] + 12, poll[1] + 1), (muzzle[0] - 2, muzzle[1] - 4)], s.tone("skin", 5), only_on_body=True)
    return details


HEADS = {"horse": _horse_head}

TIK_SKIN = hexes("#120806", "#2c160c", "#462414", "#64361e", "#86502c", "#a86c3e")
TIK_HAIR = hexes("#030202", "#0c0907", "#18120d", "#261d16", "#3a2d22")

TIKBALANG = Giant("tikbalang", TIK_SKIN, TIK_HAIR, size=200, leg=62, thigh_r=8.0, shin_r=5.4, torso=40,
    chest_r=14, waist_r=9, arm=70, arm_r=4.6, neck=12, head="horse", feet="hoof", gaunt=True)


def walk(n: int, **kw) -> list[Stance]:
    return [Stance(phase=k / n, stride=1.0, arm_swing=1.0, bob=-abs(math.sin(k / n * math.tau)) * 2.5, **kw) for k in range(n)]


TIKBALANG_ANIMS = {
    "idle": [Stance(lean=8), Stance(lean=9, bob=1)],
    "run": walk(4, lean=18),
}


# --- the bungisngis: a one-eyed giant, always laughing ---

WOOD = hexes("#1a0f08", "#3a2414", "#5a3a20", "#7c5532", "#9e7448")


def _cyclops_head(s: Sculpt, g: Giant, st: Stance, neck_base, lean):
    head = (neck_base[0] + 8 + st.shake, neck_base[1] - 16)
    s.capsule("skin", neck_base, (head[0] - 2, head[1] + 10), 10, 11)
    s.ellipse("skin", head[0], head[1], 17, 18)
    # Wild hair over the crown and the back of the skull.
    for k in range(9):
        a = math.radians(-160 + k * 22)
        root = (head[0] - 4 + math.cos(a) * 12, head[1] - 6 + math.sin(a) * 12)
        tip = (root[0] - 6 + math.cos(a) * 8 - st.shake, root[1] - 2 + math.sin(a) * 9)
        s.capsule("hair_lit" if k % 3 == 0 else "hair", root, tip, 4.0, 1.2)
    s.ellipse("hair", head[0] - 6, head[1] - 9, 13, 9)
    # The great upper lip and the jaw under it; the mouth opens with `mouth`.
    gape = 3 + st.mouth * 9
    s.ellipse("gum", head[0] + 9, head[1] + 9 + gape * 0.4, 9, 3 + gape * 0.5)
    s.ellipse("skin", head[0] + 10, head[1] + 5, 11, 6)       # the lip, overhanging
    s.ellipse("skin", head[0] + 6, head[1] + 14 + gape, 11, 6)  # the jaw
    eye_c = (head[0] + 5, head[1] - 4)
    s.ellipse("eyeball", eye_c[0], eye_c[1], 7, 6)

    def details():
        # The single eye: a white, an amber iris, a black pupil, a glint -- or squeezed shut laughing.
        if st.mouth > 0.7:
            s.curve([(eye_c[0] - 6, eye_c[1]), (eye_c[0], eye_c[1] - 3), (eye_c[0] + 6, eye_c[1])], s.tone("skin", 0))
            s.curve([(eye_c[0] - 5, eye_c[1] + 1), (eye_c[0], eye_c[1] - 2), (eye_c[0] + 5, eye_c[1] + 1)], s.tone("skin", 1))
        else:
            s.ellipse("iris", eye_c[0] + 1.5, eye_c[1] + 0.5, 3.4, 3.4)
            s.dot(eye_c[0] + 2, eye_c[1] + 0.5, s.tone("skin", 0))
            s.dot(eye_c[0] + 2, eye_c[1] + 1.5, s.tone("skin", 0))
            s.dot(eye_c[0] + 1, eye_c[1] - 1, s.tone("tooth", 3))
        # A heavy brow over it.
        s.curve([(eye_c[0] - 8, eye_c[1] - 6), (eye_c[0], eye_c[1] - 9), (eye_c[0] + 8, eye_c[1] - 6)], s.tone("skin", 1), only_on_body=True)
        # Teeth along the jaw, big and square; two tusks rising from it past the lip.
        for k in range(5):
            x = head[0] + 1 + k * 3.3
            y = head[1] + 9 + gape * 0.85
            s.line((x, y), (x, y - 2.5), s.tone("tooth", 2 if k % 2 else 3))
            s.line((x + 1, y), (x + 1, y - 2.5), s.tone("tooth", 1))
        for x in (head[0] + 1, head[0] + 15):
            s.curve([(x, head[1] + 12 + gape * 0.8), (x - 0.5, head[1] + 6), (x + 1, head[1] + 1)], s.tone("tooth", 3))
            s.curve([(x + 1, head[1] + 12 + gape * 0.8), (x + 0.5, head[1] + 6), (x + 2, head[1] + 2)], s.tone("tooth", 2))
        # The nose, broad, and the lip's lit edge.
        s.dot(head[0] + 15, head[1] + 1, s.tone("skin", 1))
        s.dot(head[0] + 16, head[1] + 2, s.tone("skin", 0))
        s.curve([(head[0] + 1, head[1] + 1), (head[0] + 10, head[1] - 0.5), (head[0] + 20, head[1] + 3)], s.tone("skin", 5), only_on_body=True)
    return details


HEADS["cyclops"] = _cyclops_head

BUNG_SKIN = hexes("#0e100a", "#232a18", "#3a4426", "#546236", "#72844a", "#92a462")
BUNG_HAIR = hexes("#060504", "#141009", "#231c13", "#352a1d", "#4a3b2a")
BAHAG = hexes("#1a0808", "#3e1212", "#622020", "#86342c", "#a8503e")
EYEBALL = hexes("#4a4338", "#9a9180", "#d8d0bc", "#f4eedc")
IRIS = hexes("#2a1404", "#6b3a0c", "#b8721c", "#e8b24a")

BUNGISNGIS = Giant("bungisngis", BUNG_SKIN, BUNG_HAIR, size=250, leg=48, thigh_r=15, shin_r=12, torso=46,
    chest_r=24, waist_r=23, arm=64, arm_r=10.0, neck=10, head="cyclops", feet="foot", cloth=BAHAG, gaunt=False,
    belly=1.0)


def draw_bungisngis(st: Stance, club: bool = True) -> Sculpt:
    s = draw_with_extra(BUNGISNGIS, st, extra=[("eyeball", EYEBALL), ("iris", IRIS), ("wood", WOOD)])
    if club and getattr(s, "hands", None):
        hand = s.hands[-1]
        # The club: a knotted log, gripped, its head toward where the arm points.
        up = st.arms_up
        tip = (hand[0] + 8 - up * 4, hand[1] + 40 - up * 90)
        s.tube("wood", [hand, _along(hand, tip, 0.55), tip], [3.4, 5.0, 8.5])
        # Its head swollen and knotted, the stubs of lopped branches standing off it.
        s.ellipse("wood", tip[0], tip[1], 8.5, 8.5)
        for t, side in [(0.62, 1), (0.8, -1), (0.95, 1)]:
            knob = _along(hand, tip, t, side * 6.5)
            s.ellipse("wood", knob[0], knob[1], 3.0, 2.6)
        for t in (0.35, 0.6, 0.85):
            knot = _along(hand, tip, t)
            s.dot(knot[0] + 1, knot[1], s.tone("wood", 1))
            s.dot(knot[0] + 2, knot[1] + 1, s.tone("wood", 0))
    return s


def draw_with_extra(g: Giant, st: Stance, extra: list) -> Sculpt:
    """draw(), with more materials registered first (the heads that need them)."""
    global _EXTRA
    _EXTRA = extra
    try:
        return draw(g, st)
    finally:
        _EXTRA = []


_EXTRA: list = []

BUNGISNGIS_ANIMS = {
    "idle": [Stance(mouth=0.35), Stance(mouth=0.45, bob=1)],
    "run": walk(4, lean=6, mouth=0.4),
    "windup": [Stance(arms_up=0.7, mouth=0.5, lean=-4), Stance(arms_up=1.0, mouth=0.6, lean=-6)],
    "attack": [Stance(arms_up=-0.1, mouth=0.8, lean=14, bob=3), Stance(arms_up=-0.2, mouth=0.6, lean=10, bob=2)],
    "hurt": [Stance(mouth=0.6, lean=-10)],
    "death": [Stance(mouth=0.5, sit=0.4), Stance(mouth=0.4, sit=0.8), Stance(mouth=0.3, sit=1.0, lean=-20)],
    "laugh": [Stance(mouth=1.0, shake=-2, lean=-8), Stance(mouth=0.9, shake=2, lean=-10, bob=2)],
    "aside": [Stance(mouth=0.8, sit=1.0, lean=-6), Stance(mouth=0.9, sit=1.0, lean=-7, bob=1)],
}


# --- the kapre: a dark, hairy giant up a balete, smoking ---

EMBER = hexes("#4a1604", "#b0400c", "#ff8a24", "#ffe08a")
CIGAR = hexes("#140a05", "#33190c", "#552c15", "#7a4524")
EYE_GLOW = hexes("#3a2a04", "#a07a10", "#f0d040", "#fff6c0")


def _kapre_head(s: Sculpt, g: Giant, st: Stance, neck_base, lean):
    head = (neck_base[0] + 6, neck_base[1] - 14)
    s.capsule("skin", neck_base, (head[0] - 2, head[1] + 8), 9, 10)
    # Long matted hair falling past the shoulders, behind.
    for k in range(10):
        root = (head[0] - 10 + k * 1.6, head[1] - 12 + k * 0.6)
        tip = (root[0] - 8 - k * 0.6, root[1] + 34 + (k % 3) * 4)
        s.capsule("hair_lit" if k % 4 == 1 else "hair", root, tip, 4.5, 2.2)
    s.ellipse("skin", head[0], head[1], 13, 14)
    s.ellipse("hair", head[0] - 3, head[1] - 7, 13, 9)
    # A beard down over the chest, in hanks.
    for k in range(7):
        root = (head[0] - 2 + k * 2.2, head[1] + 6)
        tip = (root[0] - 2 + (k % 2) * 2, root[1] + 20 + (k % 3) * 4)
        s.capsule("hair_lit" if k % 3 == 0 else "hair", root, tip, 3.2, 1.2)
    eye = (head[0] + 6, head[1] - 2)
    cigar_root = (head[0] + 11, head[1] + 5)
    cigar_tip = (cigar_root[0] + 18, cigar_root[1] - 4)
    s.capsule("cigar", cigar_root, cigar_tip, 2.4, 2.6)

    def details():
        # Eyes glowing out of the dark face, a heavy brow over them.
        for dx in (0, -5):
            s.dot(eye[0] + dx, eye[1], s.tone("glow", 3))
            s.dot(eye[0] + dx + 1, eye[1], s.tone("glow", 2))
            s.dot(eye[0] + dx - 1, eye[1], s.tone("glow", 1))
        s.line((eye[0] - 8, eye[1] - 3), (eye[0] + 3, eye[1] - 3), s.tone("skin", 0))
        # The ember, pulsing with `mouth` (used here as the draw on the cigar), and its ash ring.
        glow = 3 if st.mouth > 0.5 else 2
        s.dot(cigar_tip[0], cigar_tip[1], s.tone("ember", glow))
        s.dot(cigar_tip[0] + 1, cigar_tip[1], s.tone("ember", glow - 1))
        s.dot(cigar_tip[0], cigar_tip[1] - 1, s.tone("ember", 1))
        s.dot(cigar_tip[0], cigar_tip[1] + 1, s.tone("ember", 1))
        s.line((cigar_tip[0] - 2, cigar_tip[1] - 2), (cigar_tip[0] - 2, cigar_tip[1] + 2), s.tone("cigar", 3))
        # Smoke curling up from the ember.
        for k in range(5):
            y = cigar_tip[1] - 4 - k * 4
            x = cigar_tip[0] + math.sin(k * 1.3 + st.mouth * 3) * 3
            s.dot(x, y, s.tone("smoke", 2 if k < 3 else 1), alpha=200 - k * 30)
            s.dot(x + 1, y - 1, s.tone("smoke", 1), alpha=160 - k * 25)
    return details


HEADS["kapre"] = _kapre_head

KAPRE_SKIN = hexes("#0c0806", "#20140c", "#362216", "#4c3220", "#66462c", "#845c3a")
KAPRE_HAIR = hexes("#030202", "#0a0806", "#14100c", "#201913", "#30251c")
SMOKE = hexes("#4a4a50", "#8a8a92", "#c8c8d0", "#ececf0")

KAPRE = Giant("kapre", KAPRE_SKIN, KAPRE_HAIR, size=160, leg=52, thigh_r=11, shin_r=8, torso=46,
    chest_r=21, waist_r=17, arm=60, arm_r=8.0, neck=8, head="kapre", feet="foot", cloth=BAHAG, gaunt=False)


def draw_kapre(st: Stance) -> Sculpt:
    return draw_with_extra(KAPRE, st, extra=[("cigar", CIGAR), ("ember", EMBER), ("glow", EYE_GLOW), ("smoke", SMOKE)])


KAPRE_ANIMS = {
    "idle": [Stance(sit=1.0, lean=-4, mouth=0.2), Stance(sit=1.0, lean=-4, mouth=0.9, bob=1)],
}
