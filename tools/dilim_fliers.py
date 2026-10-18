"""Dilim's fliers: the manananggal's upper half (bat wings), the wakwak and the tik-tik (birds).
Sculpted, lit and outlined like the rest (creature_sculpt); centred in their frames, since a flier's
position in the game is its middle."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from creature_sculpt import Sculpt, hexes, rot, strip  # noqa: E402

W, H = 176, 128
SKIN = hexes("#1e1424", "#3a2a44", "#5a4664", "#7c6686", "#a08aa8", "#c4b0c8")
HAIR = hexes("#050407", "#100d15", "#1d1824", "#2e2737", "#463d52")
MEMBRANE = hexes("#120a1a", "#2a1638", "#42245a", "#5e367c", "#7c4c9e")
BONE = hexes("#1c1422", "#54445c", "#85738c", "#b3a2b6")
GUT = hexes("#2a070c", "#5c1420", "#8e2433", "#bb4b54", "#dd8584")
CLAW = hexes("#2b2420", "#6b5f55", "#b6a894", "#e8dcc4")
EYE = hexes("#5a0b0b", "#c42a1e", "#ff5a3c", "#ffb38f")


def wing(s: Sculpt, side: float, shoulder: tuple[float, float], lift: float, far: bool) -> None:
    """A bat's wing off `shoulder`: humerus, forearm, then four fingers fanning to the tips, the
    membrane stretched between them and scalloped at its trailing edge. `lift` -1 down .. 1 up."""
    mat = "membrane_far" if far else "membrane"
    reach = 0.58 if far else 0.72
    elbow = (shoulder[0] + side * 16 * reach, shoulder[1] - 12 * reach * (0.4 + lift))
    wrist = (elbow[0] + side * 18 * reach, elbow[1] - 14 * reach * lift - 4)
    tips = []
    for i, (angle, length) in enumerate([(-52, 52), (-24, 58), (6, 52), (36, 42)]):
        a = angle * side + (-lift * 18) * side
        tip = rot((wrist[0] + side * length * reach, wrist[1]), wrist, a)
        tips.append(tip)
    # The membrane: shoulder, along the bones to each tip, scalloping back between them, to the
    # flank under the arm.
    flank = (shoulder[0] + side * 4, shoulder[1] + 22)
    outline = [shoulder, elbow, wrist, tips[0]]
    for a, b in zip(tips, tips[1:]):
        # A shallow arc between two fingertips: the skin pulled taut, sagging a little in.
        toward = None
        for t, depth in [(0.25, 0.10), (0.5, 0.16), (0.75, 0.10)]:
            x = a[0] + (b[0] - a[0]) * t
            y = a[1] + (b[1] - a[1]) * t
            outline.append((x + (wrist[0] - x) * depth, y + (wrist[1] - y) * depth))
        outline.append(b)
    last = tips[-1]
    for t, depth in [(0.3, 0.12), (0.6, 0.16)]:
        x = last[0] + (flank[0] - last[0]) * t
        y = last[1] + (flank[1] - last[1]) * t
        outline.append((x + (shoulder[0] - x) * depth, y + (shoulder[1] - y) * depth))
    outline.append(flank)
    s.poly(mat, outline, bulge=0.22)
    # Each panel of skin between two fingers sags: darker toward its middle, so it reads stretched.
    deep = mat + "_deep"
    for a, b in zip([wrist] + tips[:-1], tips):
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        inner = [wrist, (wrist[0] + (a[0] - wrist[0]) * 0.72, wrist[1] + (a[1] - wrist[1]) * 0.72),
            (mid[0] + (wrist[0] - mid[0]) * 0.55, mid[1] + (wrist[1] - mid[1]) * 0.55),
            (wrist[0] + (b[0] - wrist[0]) * 0.72, wrist[1] + (b[1] - wrist[1]) * 0.72)]
        s.poly(deep, inner, bulge=0.5)
    # And the panel under the arm, toward the flank.
    s.poly(deep, [shoulder, (elbow[0] * 0.5 + wrist[0] * 0.5, elbow[1] * 0.5 + wrist[1] * 0.5 + 6),
        (flank[0] + side * 8, flank[1] - 6)], bulge=0.5)
    bone = "bone_far" if far else "bone"
    s.capsule(bone, shoulder, elbow, 3.0, 2.4)
    s.capsule(bone, elbow, wrist, 2.4, 1.9)
    s.ellipse(bone, wrist[0], wrist[1], 2.6, 2.6)
    for tip in tips:
        s.capsule(bone, wrist, tip, 1.5, 0.7)
    # Veins in the membrane, faint, from the wrist.
    vein = s.tone(mat, 1)
    for a, b in zip(tips, tips[1:]):
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        s.line(wrist, ((wrist[0] + mid[0]) / 2, (wrist[1] + mid[1]) / 2), vein, only_on_body=True)
    # The thumb's claw, hooked, at the wrist.
    s.capsule("claw", wrist, (wrist[0] + side * 3, wrist[1] - 5), 1.4, 0.5)


def manananggal_upper(lift: float, reach: float = 0.0) -> Sculpt:
    s = Sculpt(W, H)
    for name, ramp in [("membrane_far", MEMBRANE[[0, 0, 1, 2, 3]]), ("membrane_far_deep", MEMBRANE[[0, 0, 0, 1, 2]]),
            ("bone_far", BONE[[0, 0, 1, 2]]),
            ("membrane", MEMBRANE), ("membrane_deep", MEMBRANE[[0, 0, 1, 2, 3]]), ("bone", BONE), ("gut", GUT),
            ("hair", HAIR), ("hair_lit", HAIR[[0, 1, 2, 3, 4]] if False else HAIR[[1, 2, 3, 4, 4]]), ("skin", SKIN),
            ("claw", CLAW), ("eye", EYE)]:
        s.material(name, ramp)
    cx, cy = 88, 58 + lift * 3
    shoulder_l, shoulder_r = (cx - 9, cy - 8), (cx + 9, cy - 8)
    # Behind everything: the far wing, darker and smaller.
    wing(s, -1, shoulder_l, lift * 0.9, far=True)
    # What hangs from where she parted, swinging behind.
    sway = -lift * 3
    for i, (dx, length, r) in enumerate([(-5, 22, 2.6), (0, 30, 2.4), (5, 18, 2.2), (2, 26, 1.8)]):
        top = (cx + dx, cy + 18)
        mid = (cx + dx + sway * 0.5 - 2, top[1] + length * 0.55)
        end = (cx + dx + sway - 4, top[1] + length)
        s.capsule("gut", top, mid, r, r * 0.8)
        s.capsule("gut", mid, end, r * 0.8, r * 0.45)
    # Hair streaming back from the head in long wet strands, behind the torso.
    import math
    head = (cx + 7, cy - 21)
    for i in range(14):
        k = i / 13.0
        start = (head[0] - 2 - k * 4, head[1] - 7 + k * 9)
        pts = [start]
        for j in range(1, 6):
            t = j / 5.0
            x = start[0] - t * (30 + k * 16)
            y = start[1] + t * (8 + k * 26) + math.sin(t * 5.0 + k * 3.0 + lift * 1.5) * (2.0 + 2.5 * t)
            pts.append((x, y))
        strand = "hair_lit" if i % 3 == 1 else "hair"
        for a, b in zip(pts, pts[1:]):
            r0 = 2.0 * (1.0 - 0.6 * (pts.index(a) / 5.0))
            s.capsule(strand, a, b, r0, max(0.6, r0 - 0.5))
    # The torso: ribs showing, shoulders, ragged at the waist.
    s.ellipse("skin", cx, cy + 3, 8, 14)
    s.ellipse("skin", cx, cy - 7, 11, 6)
    s.poly("skin", [(cx - 7, cy + 12), (cx - 5, cy + 21), (cx - 2, cy + 17), (cx, cy + 22),
        (cx + 2, cy + 17), (cx + 5, cy + 21), (cx + 7, cy + 12)], bulge=0.4)
    # The near wing over the torso's edge.
    wing(s, 1, shoulder_r, lift, far=False)
    # Arms reaching forward, clawed.
    elbow = (cx + 13 + reach * 4, cy + 9 - reach * 6)
    hand = (cx + 26 + reach * 8, cy + 4 - reach * 2)
    s.capsule("skin", shoulder_r, elbow, 2.8, 2.1)
    s.capsule("skin", elbow, hand, 2.1, 1.7)
    for k in range(4):
        s.capsule("claw", hand, (hand[0] + 8, hand[1] - 3 + k * 2.5), 0.9, 0.3)
    # The head: gaunt, long-jawed, tilted forward to hunt.
    s.ellipse("skin", head[0], head[1], 12, 12)
    s.ellipse("skin", head[0] + 6, head[1] + 7, 7, 5.5)
    s.ellipse("skin", head[0] + 9, head[1] + 1, 2.4, 2.8)
    # Hair over the crown, and a hank down the near side of the face.
    s.ellipse("hair", head[0] - 3, head[1] - 5, 9, 7)
    s.capsule("hair", (head[0] - 4, head[1] - 4), (head[0] - 6, head[1] + 13), 4.5, 2.0)
    s.capsule("hair", (head[0] + 2, head[1] - 9), (head[0] + 7, head[1] - 4), 3.0, 1.5)
    img = s
    # Collarbones, and the ribs: dark curves on a starved chest.
    s.curve([(cx - 9, cy - 9), (cx - 3, cy - 7), (cx, cy - 8)], s.tone("skin", 1), only_on_body=True)
    s.curve([(cx + 1, cy - 8), (cx + 5, cy - 7), (cx + 10, cy - 9)], s.tone("skin", 1), only_on_body=True)
    for k in range(4):
        y = cy - 2 + k * 3.5
        s.curve([(cx - 7, y + 1), (cx - 2, y - 1), (cx + 3, y), (cx + 7, y + 2)], s.tone("skin", 2), only_on_body=True)
    # The eye, sunk in a dark socket and burning; a glint.
    eye = (head[0] + 6, head[1] - 1)
    # A big burning eye in a dark socket: a red disc, a slit pupil, a white glint, a scowl.
    s.ellipse("hair", eye[0], eye[1], 4.4, 3.6)
    s.ellipse("eye", eye[0] + 0.5, eye[1] + 0.3, 3.2, 2.8)
    s.line((eye[0] + 1, eye[1] - 1.5), (eye[0] + 1, eye[1] + 1.8), s.tone("eye", 0))
    s.dot(eye[0] - 1, eye[1] - 1, (255, 255, 255))
    s.line((eye[0] - 4, eye[1] - 4.5), (eye[0] + 4, eye[1] - 3), s.tone("skin", 0))
    # The cheek hollow and the mouth, open, with fangs.
    s.line((head[0] + 2, head[1] + 3), (head[0] + 4, head[1] + 6), s.tone("skin", 1))
    mouth = (head[0] + 8, head[1] + 7)
    s.line((mouth[0] - 3, mouth[1]), (mouth[0] + 2, mouth[1] - 1), s.tone("gut", 0))
    s.line((mouth[0] - 2, mouth[1] + 1), (mouth[0] + 1, mouth[1] + 1), s.tone("gut", 1))
    s.dot(mouth[0] - 2, mouth[1] + 1, s.tone("claw", 3))
    s.dot(mouth[0] + 1, mouth[1] + 1, s.tone("claw", 3))
    s.dot(mouth[0] + 1, mouth[1] + 2, s.tone("claw", 2))
    return img


MANANANGGAL_ANIMS = {
    "idle": [(1.0, 0), (0.35, 0), (-0.6, 0), (0.1, 0)],
    "run": [(1.0, 0), (0.35, 0), (-0.6, 0), (0.1, 0)],
    "windup": [(1.0, 0.6), (1.0, 1.0)],
    "attack": [(-0.8, 1.0), (-0.5, 0.8)],
    "hurt": [(0.4, -0.3)],
    "death": [(0.6, -0.4), (-0.2, -0.6), (-0.9, -0.8)],
}


# --- the wakwak and the tik-tik: birds ---

WAK = hexes("#0a0a16", "#161a30", "#242a4a", "#343e66", "#4a5684", "#6670a4")
BEAK = hexes("#2b2010", "#6b5428", "#a88a48", "#dcc488")
EYE = hexes("#5a0b0b", "#c42a1e", "#ff5a3c", "#ffb38f")
TIK = hexes("#050406", "#100d12", "#1c1820", "#2b2531", "#3e3646")
ASH = hexes("#4a4848", "#7a7878", "#a8a6a6", "#d4d2d2")


def _feathered_wing(s, mat, shoulder, side, lift, scale):
    """A raptor's wing: arm bones, a row of long primaries fanning off the hand, secondaries
    behind along the forearm, each feather its own capsule so the edge is ragged."""
    elbow = (shoulder[0] + side * 12 * scale, shoulder[1] - 10 * scale * (0.3 + lift))
    wrist = (elbow[0] + side * 14 * scale, elbow[1] - 10 * scale * lift)
    s.capsule(mat, shoulder, elbow, 4 * scale, 3 * scale)
    s.capsule(mat, elbow, wrist, 3 * scale, 2.4 * scale)
    import math as _m
    for k in range(6):
        a = _m.radians((-40 + k * 14) * side - lift * 20 * side)
        length = (26 - k * 1.5) * scale
        tip = (wrist[0] + _m.cos(a) * length * side if side > 0 else wrist[0] - _m.cos(a) * length,
            wrist[1] + _m.sin(a) * length * (1 if side > 0 else -1) * -1)
        tip = (wrist[0] + side * _m.cos(_m.radians(-40 + k * 14 - lift * 20)) * length,
            wrist[1] + _m.sin(_m.radians(-40 + k * 14 - lift * 20)) * length)
        s.capsule(mat, wrist, tip, 2.6 * scale, 0.7)
    for k in range(3):
        t = 0.2 + k * 0.3
        root = (shoulder[0] + (wrist[0] - shoulder[0]) * t, shoulder[1] + (wrist[1] - shoulder[1]) * t)
        s.capsule(mat, root, (root[0] - side * 3, root[1] + (9 - k * 2) * scale), 3.2 * scale, 1.2)
    return wrist


def wakwak(lift: float, dive: float = 0.0) -> Sculpt:
    W, H = 120, 104
    s = Sculpt(W, H)
    for name, ramp in [("far", WAK[[0, 0, 1, 2, 3, 3]]), ("wing", WAK), ("body", WAK), ("beak", BEAK), ("eye", EYE)]:
        s.material(name, ramp)
    cx, cy = 60, 54 + lift * 3
    _feathered_wing(s, "far", (cx - 4, cy - 6), -1, lift * 0.9, 0.85)
    # Tail fanned behind; talons hanging.
    for k in range(4):
        s.capsule("body", (cx - 8, cy + 4), (cx - 24, cy + 2 + k * 3), 2.4, 1.0)
    for k in (-3, 3):
        foot = (cx + k + dive * 6, cy + 18 + (1 - dive) * 2)
        s.capsule("body", (cx + k, cy + 8), foot, 1.6, 1.2)
        for j in range(3):
            s.capsule("beak", foot, (foot[0] + 2 + j * 1.2, foot[1] + 3), 0.9, 0.4)
    s.ellipse("body", cx, cy, 14, 11)
    head = (cx + 13 + dive * 4, cy - 9 + dive * 3)
    s.capsule("body", (cx + 6, cy - 4), head, 7, 6)
    s.ellipse("body", head[0], head[1], 7, 6.5)
    beak_root = (head[0] + 5, head[1] - 1)
    s.poly("beak", [beak_root, (beak_root[0] + 8, beak_root[1] - 1), (beak_root[0] + 13, beak_root[1] + 3),
        (beak_root[0] + 11, beak_root[1] + 8), (beak_root[0] + 8, beak_root[1] + 4), (beak_root[0] + 1, beak_root[1] + 5)], bulge=0.3)
    _feathered_wing(s, "wing", (cx + 2, cy - 6), 1, lift, 1.0)
    img = s
    # Hooked tip, the eye with a glint, a pale throat ruff, feather marks on the breast.
    s.dot(beak_root[0] + 11, beak_root[1] + 7, s.tone("beak", 0))
    s.ellipse("eye", head[0] + 2, head[1] - 2, 2.6, 2.4)
    s.line((head[0] + 2.5, head[1] - 3.5), (head[0] + 2.5, head[1] - 0.5), s.tone("eye", 0))
    s.dot(head[0] + 1, head[1] - 3, (255, 255, 255))
    s.line((head[0] - 2, head[1] - 6), (head[0] + 5, head[1] - 4.5), s.tone("body", 0))
    for k in range(5):
        s.curve([(cx - 6 + k * 3, cy + 2), (cx - 5 + k * 3, cy + 5)], s.tone("body", 4), only_on_body=True)
    return img


WAKWAK_ANIMS = {
    "idle": [(1.0, 0), (0.3, 0), (-0.7, 0), (0.0, 0)],
    "run": [(1.0, 0), (0.3, 0), (-0.7, 0), (0.0, 0)],
    "windup": [(1.0, 0.0), (1.0, 0.3)],
    "attack": [(-0.9, 1.0), (-0.6, 1.0)],
    "hurt": [(0.3, 0.0)],
    "death": [(0.5, 0.0), (-0.3, 0.0), (-1.0, 0.0)],
}


def tiktik(lift: float, ashed: bool = True) -> Sculpt:
    W, H = 64, 56
    s = Sculpt(W, H)
    for name, ramp in [("far", TIK[[0, 0, 1, 2, 3]]), ("wing", TIK), ("body", TIK), ("beak", BEAK), ("eye", EYE), ("ash", ASH)]:
        s.material(name, ramp)
    cx, cy = 30, 30 + lift * 2
    _feathered_wing(s, "far", (cx - 2, cy - 3), -1, lift * 0.9, 0.42)
    for k in range(3):
        s.capsule("body", (cx - 5, cy + 2), (cx - 15, cy + 1 + k * 2), 1.6, 0.7)
    s.ellipse("body", cx, cy, 7, 5.5)
    head = (cx + 7, cy - 4)
    s.ellipse("body", head[0], head[1], 4, 3.8)
    # A long, thin, down-curved beak.
    s.curve([(head[0] + 3, head[1]), (head[0] + 9, head[1] + 1), (head[0] + 14, head[1] + 4)], s.tone("beak", 2))
    s.curve([(head[0] + 3, head[1] + 1), (head[0] + 9, head[1] + 2), (head[0] + 13, head[1] + 4)], s.tone("beak", 1))
    _feathered_wing(s, "wing", (cx + 1, cy - 3), 1, lift, 0.5)
    img = s
    s.dot(head[0] + 1, head[1] - 1, s.tone("eye", 2))
    s.dot(head[0] + 1, head[1] - 2, s.tone("eye", 3))
    if ashed:
        # The ash on it -- the only reason it can be seen.
        for x, y in [(cx - 3, cy - 2), (cx + 2, cy + 1), (cx - 6, cy + 2), (head[0], head[1] - 3), (cx + 4, cy - 4),
                (cx - 1, cy + 3), (cx + 8, cy - 9), (cx - 9, cy - 6)]:
            s.dot(x, y, s.tone("ash", 2 + (int(x) % 2)))
    return img


TIKTIK_ANIMS = {
    "idle": [1.0, 0.3, -0.7, 0.0],
    "run": [1.0, 0.3, -0.7, 0.0],
    "windup": [1.0, 1.0],
    "attack": [-0.9, -0.6],
    "hurt": [0.3],
    "death": [0.5, -0.3, -1.0],
}
