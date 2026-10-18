"""Dilim's four-legged creatures on one rig: the aswang as a dog and as a pig, and the sigbin.

Each is a `Beast` -- proportions and palette -- posed by a `Pose`: where each leg's foot is in its
stride, how the body pitches, how low it crouches, whether the jaw is open. An animation is a list
of poses; every frame is sculpted, lit and outlined the same way (creature_sculpt).
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

from creature_sculpt import Sculpt, hexes

FUR_DOG = hexes("#0a0612", "#1a1028", "#2a1c42", "#3e2c5e", "#58427e", "#7a62a4")
FUR_PIG = hexes("#070506", "#140e10", "#22181b", "#33252a", "#48363c", "#634c52")
EYE = hexes("#4a0a08", "#b3241a", "#ff4a2a", "#ffc08a")
GUM = hexes("#2a070c", "#5c1420", "#8e2433", "#b54050")
TOOTH = hexes("#3d3428", "#8f8670", "#d4caa8", "#f2ead2")
SNOUT = hexes("#1f1316", "#4a2f35", "#704a50", "#93686d")


@dataclass
class Beast:
    name: str
    fur: object
    size: int = 72
    body_len: float = 28.0      # shoulder to hip
    body_depth: float = 10.0    # half-height of the chest
    belly: float = 7.0          # half-height at the hips
    leg_len: float = 16.0
    leg_thick: float = 2.6
    neck: float = 9.0
    head_len: float = 12.0
    head_h: float = 5.5
    snout_len: float = 9.0
    ears: str = "pointed"       # pointed / small / long
    tail: str = "ragged"        # ragged / curl / whip
    tusks: bool = False
    crest: bool = False         # a bristled ridge along the spine
    ribs: bool = True
    hind_extra: float = 0.0     # hind legs this much longer (the sigbin's kangaroo crouch)
    eye_big: bool = False       # a big glowing eye with a pupil and a glint (the chibi look)


@dataclass
class Pose:
    feet: list = field(default_factory=lambda: [0.0, 0.5, 0.25, 0.75])  # stride phase per leg: FL FR HL HR
    stride: float = 1.0         # 0 standing .. 1 a full stride
    pitch: float = 0.0          # degrees, + head down
    crouch: float = 0.0         # 0 .. 1, body lowered toward the ground
    bob: float = 0.0            # px up
    jaw: float = 0.0            # 0 shut .. 1 wide
    reach: float = 0.0          # 0 .. 1, stretched in a lunge
    head_low: float = 0.0       # px the head drops
    fade: float = 0.0           # death: how far over it has gone (0 .. 1)


def _leg(s: Sculpt, name: str, hip: tuple[float, float], phase: float, b: Beast, p: Pose, ground: float, hind: bool) -> None:
    """A digitigrade leg: upper, lower, a paw on the ground. `phase` 0..1 around the stride."""
    swing = math.sin(phase * math.tau) * 7.0 * p.stride
    if hind and b.hind_extra > 0:
        # A long hock folded back: the leg bends twice, like a hare's or a kangaroo's.
        foot = (hip[0] + swing * 0.6 + 3.0, ground)
        knee = (hip[0] + 5.0, hip[1] + (ground - hip[1]) * 0.4)
        hock = (hip[0] - 4.0, hip[1] + (ground - hip[1]) * 0.75)
        s.capsule(name, hip, knee, b.leg_thick + 2.2, b.leg_thick + 0.8)
        s.capsule(name, knee, hock, b.leg_thick + 0.8, b.leg_thick * 0.8)
        s.capsule(name, hock, foot, b.leg_thick * 0.8, b.leg_thick * 0.6)
        s.ellipse(name, foot[0] + 2, foot[1] - 0.5, b.leg_thick + 2.0, 1.4)
        return
    lift = max(0.0, math.cos(phase * math.tau)) * 4.0 * p.stride
    foot = (hip[0] + swing + (2.0 if hind else -1.0), ground - lift)
    # The knee/hock: hind legs bend back, fore legs forward.
    mid = ((hip[0] + foot[0]) / 2 + (-4.0 if hind else 2.5), (hip[1] + foot[1]) / 2)
    s.capsule(name, hip, mid, b.leg_thick + (1.4 if hind else 0.6), b.leg_thick)
    s.capsule(name, mid, foot, b.leg_thick, b.leg_thick * 0.7)
    s.ellipse(name, foot[0] + 1.5, foot[1] - 0.5, b.leg_thick + 1.2, 1.6)


def draw(b: Beast, p: Pose) -> Sculpt:
    S = b.size
    s = Sculpt(S, S)
    far = b.fur[[0, 0, 1, 2, 3, 3]]
    for name, ramp in [("far", far), ("fur", b.fur), ("snout", SNOUT), ("gum", GUM), ("tooth", TOOTH), ("eye", EYE)]:
        s.material(name, ramp)
    ground = S - 2.0
    stand = b.leg_len * (1.0 - 0.35 * p.crouch)
    # The body centred in the frame, which is what sits on the creature's position in the game; the
    # frame is wide enough for the nose in a lunge and the tail behind.
    hip = (S * 0.5 - b.body_len * 0.5, ground - stand - b.belly * 0.6 - p.bob)
    shoulder = (hip[0] + b.body_len * (1.0 + p.reach * 0.25), ground - stand - b.body_depth * 0.55 - p.bob)
    # Pitch the spine: a lunge or a crouch leans it forward and down.
    tilt = math.radians(p.pitch)
    shoulder = (shoulder[0], shoulder[1] + math.sin(tilt) * b.body_len * 0.3)
    if p.fade > 0.0:
        # Going over: the body sinks and rolls; the legs fold under.
        hip = (hip[0], hip[1] + p.fade * (stand * 0.8))
        shoulder = (shoulder[0], shoulder[1] + p.fade * (stand * 0.9))
    # Far legs first, darker.
    _leg(s, "far", (hip[0] + 2, hip[1] + 2), p.feet[3], b, p, ground - 1, True)
    _leg(s, "far", (shoulder[0] - 1, shoulder[1] + 3), p.feet[1], b, p, ground - 1, False)
    # Tail.
    tail_root = (hip[0] - 3, hip[1] - 2)
    if b.tail == "ragged":
        wave = math.sin(p.bob * 2.0) * 2.0
        pts = [tail_root, (tail_root[0] - 7, tail_root[1] + 1 - wave), (tail_root[0] - 13, tail_root[1] + 6),
            (tail_root[0] - 17, tail_root[1] + 12 + wave)]
        for k, (a, c) in enumerate(zip(pts, pts[1:])):
            s.capsule("fur", a, c, 3.0 - k * 0.8, 2.4 - k * 0.8)
            s.poly("fur", [(c[0] + 1, c[1] - 1), (c[0] - 3, c[1] + 1.5), (c[0] + 1.5, c[1] + 2)], bulge=0.2)
    elif b.tail == "curl":
        s.capsule("fur", tail_root, (tail_root[0] - 4, tail_root[1] - 3), 1.4, 1.0)
        s.capsule("fur", (tail_root[0] - 4, tail_root[1] - 3), (tail_root[0] - 2, tail_root[1] - 6), 1.0, 0.6)
    else:  # whip
        pts = [tail_root]
        for k in range(1, 7):
            t = k / 6.0
            pts.append((tail_root[0] - t * 26, tail_root[1] - math.sin(t * 3.0 + p.bob) * 6 + t * 4))
        for a, c in zip(pts, pts[1:]):
            s.capsule("fur", a, c, 1.6 * (1 - 0.12 * pts.index(a)), 1.0)
    # The body: hindquarters, a deep chest, the belly tucked up between.
    s.ellipse("fur", hip[0] + 2, hip[1], b.belly + 2, b.belly)
    s.ellipse("fur", shoulder[0] - 2, shoulder[1] + 1, b.body_depth * 0.9, b.body_depth)
    s.capsule("fur", (hip[0] + 2, hip[1] - 1), (shoulder[0] - 2, shoulder[1] - 1), b.belly * 0.9, b.body_depth * 0.8)
    # Near legs, over the body.
    _leg(s, "fur", (hip[0] + 4, hip[1] + 1), p.feet[2], b, p, ground, True)
    _leg(s, "fur", (shoulder[0] + 1, shoulder[1] + 4), p.feet[0], b, p, ground, False)
    # Neck and head, reaching forward and down with the pitch.
    neck_base = (shoulder[0] + 2, shoulder[1] - b.body_depth * 0.4)
    head_c = (neck_base[0] + b.neck * math.cos(tilt * 0.6 - 0.35) + p.reach * 6,
        neck_base[1] - b.neck * 0.55 + p.head_low + math.sin(tilt) * 4)
    s.capsule("fur", neck_base, head_c, b.body_depth * 0.55, b.head_h * 0.9)
    s.ellipse("fur", head_c[0], head_c[1], b.head_len * 0.55, b.head_h)
    # The muzzle, the jaw hanging with `jaw`.
    nose = (head_c[0] + b.head_len * 0.5 + b.snout_len, head_c[1] + 1.5)
    s.capsule("fur", (head_c[0] + 2, head_c[1] - 0.5), nose, b.head_h * 0.62, b.head_h * 0.38)
    jaw_open = p.jaw * 4.0
    jaw_tip = (nose[0] - 2, nose[1] + 2.5 + jaw_open)
    if jaw_open > 0.5:
        s.poly("gum", [(head_c[0] + 3, head_c[1] + 2), (nose[0] - 1, nose[1] + 1), jaw_tip], bulge=0.2)
    s.capsule("fur", (head_c[0] + 2, head_c[1] + 2.5), jaw_tip, b.head_h * 0.45, b.head_h * 0.3)
    if b.tusks:
        s.ellipse("snout", nose[0] + 0.5, nose[1] - 0.5, 2.2, 3.4, flat=0.6)
        s.dot(nose[0] + 1, nose[1] - 1.5, s.tone("snout", 0))
        s.dot(nose[0] + 1, nose[1] + 0.8, s.tone("snout", 0))
    else:
        s.ellipse("snout", nose[0], nose[1] - 0.5, 1.8, 1.6)
    # Ears.
    if b.ears == "pointed":
        base = (head_c[0] - 2, head_c[1] - b.head_h + 1)
        s.poly("fur", [base, (base[0] + 2, base[1] - 7 - p.bob * 0.3), (base[0] + 5, base[1] + 1)], bulge=0.3)
        s.poly("far", [(base[0] - 3, base[1] + 1), (base[0] - 2, base[1] - 6), (base[0] + 1, base[1] + 1)], bulge=0.3)
    elif b.ears == "small":
        base = (head_c[0] - 3, head_c[1] - b.head_h + 1)
        s.poly("fur", [base, (base[0] + 1, base[1] - 4), (base[0] + 4, base[1] + 1)], bulge=0.3)
    else:  # long, the sigbin's: back over the neck, able to clap
        base = (head_c[0] - 2, head_c[1] - b.head_h + 2)
        s.capsule("fur", base, (base[0] - 12, base[1] - 4 - p.bob), 2.4, 1.6)
        s.capsule("far", (base[0] - 1, base[1]), (base[0] - 11, base[1] - 7 - p.bob), 2.0, 1.2)
    # Shaggy fur: irregular tufts along the back, a mane at the scruff, ragged under the belly.
    rng = [0.3, 0.9, 0.5, 1.0, 0.2, 0.7, 0.4, 0.95, 0.6, 0.15, 0.8]
    crest_from = (hip[0] - 1, hip[1] - b.belly + 1)
    crest_to = (shoulder[0] + 3, shoulder[1] - b.body_depth + 1)
    n = 10
    for k in range(n + 1):
        t = k / n
        x = crest_from[0] + (crest_to[0] - crest_from[0]) * t
        y = crest_from[1] + (crest_to[1] - crest_from[1]) * t - math.sin(t * math.pi) * 2
        mane = max(0.0, (t - 0.6) / 0.4)
        tall = (2.6 if b.crest else 1.6) + rng[k % len(rng)] * (2.2 if b.crest else 1.6) + mane * 3.0
        lean = -1.5 - mane * 1.5
        s.poly("fur", [(x - 1.8, y + 1.5), (x + lean, y - tall), (x + 1.8, y + 1.5)], bulge=0.2)
    for k in range(4):
        t = k / 3
        x = neck_base_x = shoulder[0] + 1 + t * 5
        y = shoulder[1] - b.body_depth * 0.2 + t * 4
        s.poly("fur", [(x - 1.5, y), (x - 3.5, y + 4 + rng[k] * 2), (x + 1.5, y + 1)], bulge=0.2)
    for k in range(6):
        x = hip[0] + 5 + k * (b.body_len - 8) / 5
        y = (hip[1] + shoulder[1]) / 2 + b.belly * 0.8
        s.poly("fur", [(x - 1.6, y - 1), (x - 0.5, y + 2 + rng[k + 3] * 2), (x + 1.4, y - 1)], bulge=0.2)
    # --- detail on top ---
    if b.ribs:
        for k in range(3):
            x = shoulder[0] - 5 - k * 3.5
            s.curve([(x, shoulder[1] - 2), (x - 1, shoulder[1] + 2), (x, shoulder[1] + 5)], s.tone("fur", 1), only_on_body=True)
    # Fur strokes along the flank and back -- only where the bands do not already say it.
    for k in range(9 if not b.eye_big else 0):
        t = (k + 0.5) / 9
        x = hip[0] + (shoulder[0] - hip[0]) * t
        y = hip[1] + (shoulder[1] - hip[1]) * t
        s.line((x - 1, y - b.belly * 0.5), (x + 2, y - b.belly * 0.5 - 1.5), s.tone("fur", 5), only_on_body=True)
        s.line((x, y + b.belly * 0.3), (x + 2, y + b.belly * 0.3 + 1), s.tone("fur", 1), only_on_body=True)
    # The eye, a red ember with a glint, under a heavy brow.
    eye = (head_c[0] + 2.5, head_c[1] - 1.5)
    if b.eye_big:
        # A big burning eye: a red disc, a dark slit pupil, a white glint, under a scowling brow.
        s.ellipse("eye", eye[0] + 1, eye[1] + 0.5, 3.4, 3.0)
        s.line((eye[0] - 3, eye[1] - 3.5), (eye[0] + 4, eye[1] - 2), s.tone("fur", 0))
        s.line((eye[0] - 3, eye[1] - 2.5), (eye[0] + 4, eye[1] - 1), s.tone("fur", 0))
    else:
        s.line((eye[0] - 2, eye[1] - 1.5), (eye[0] + 2, eye[1] - 1), s.tone("fur", 0))
    if b.eye_big:
        s.line((eye[0] + 1.5, eye[1] - 1), (eye[0] + 1.5, eye[1] + 2), s.tone("eye", 0))
        s.dot(eye[0] - 0.5, eye[1] - 0.5, (255, 255, 255))
        s.dot(eye[0], eye[1] - 0.5, (255, 240, 220))
    else:
        s.dot(eye[0], eye[1], s.tone("eye", 3))
        s.dot(eye[0] + 1, eye[1], s.tone("eye", 2))
        s.dot(eye[0] - 1, eye[1], s.tone("eye", 1))
        s.dot(eye[0] + 2, eye[1] + 0.4, s.tone("eye", 1))
    # Teeth: fangs at the front of each jaw; tusks for the pig.
    if p.jaw > 0.1 or b.tusks:
        for k, x in enumerate([nose[0] - 2, nose[0] - 4.5, nose[0] - 7]):
            s.line((x, nose[1] + 1.5), (x, nose[1] + 2.5 + (1 if k == 0 else 0)), s.tone("tooth", 3 if k == 0 else 2))
        s.line((jaw_tip[0] - 1, jaw_tip[1] - 1), (jaw_tip[0] - 1, jaw_tip[1] - 2.5), s.tone("tooth", 3))
    if b.tusks:
        t0 = (nose[0] - 4, nose[1] + 2)
        s.capsule("tooth", t0, (t0[0] + 1.5, t0[1] - 3), 1.3, 0.9)
        s.capsule("tooth", (t0[0] + 1.5, t0[1] - 3), (t0[0] + 0.5, t0[1] - 6), 0.9, 0.4)
    return s


SIGBIN_HIDE = hexes("#0f0c0b", "#241d1a", "#3a2f29", "#54453b", "#726052", "#93806f")

SIGBIN = Beast("sigbin", SIGBIN_HIDE, size=120, body_len=24, body_depth=9, belly=8, leg_len=13, leg_thick=2.2,
    neck=7, head_len=11, head_h=5.0, snout_len=6, ears="long", tail="whip", crest=False, ribs=True, hind_extra=6)

DOG = Beast("aswang_dog", FUR_DOG, size=132, body_len=24, body_depth=12, belly=10.0, leg_len=12, leg_thick=4.2,
    neck=6, head_len=22, head_h=10.5, snout_len=7, ears="pointed", tail="ragged", crest=False, ribs=False, eye_big=True)
PIG = Beast("aswang_pig", FUR_PIG, size=120, body_len=30, body_depth=12, belly=10.5, leg_len=11, leg_thick=3.2,
    neck=5, head_len=15, head_h=7.0, snout_len=9, ears="small", tail="curl", tusks=True, crest=True, ribs=False)


def run_cycle(n: int = 4) -> list[Pose]:
    return [Pose(feet=[(k / n + o) % 1.0 for o in (0.0, 0.5, 0.55, 0.05)], stride=1.0,
        bob=abs(math.sin(k / n * math.tau)) * 1.5, jaw=0.2) for k in range(n)]


ANIMS = {
    "idle": [Pose(stride=0.0, bob=0.0), Pose(stride=0.0, bob=0.6, jaw=0.1)],
    "run": run_cycle(4),
    "windup": [Pose(stride=0.0, crouch=0.6, pitch=14, jaw=0.8, head_low=3), Pose(stride=0.0, crouch=0.75, pitch=18, jaw=1.0, head_low=4)],
    "attack": [Pose(feet=[0.75, 0.8, 0.25, 0.3], stride=1.0, reach=1.0, jaw=1.0, bob=4), Pose(feet=[0.9, 0.95, 0.4, 0.45], stride=0.8, reach=0.7, jaw=0.6, bob=2)],
    "hurt": [Pose(stride=0.2, crouch=0.3, pitch=-12, jaw=0.6)],
    "death": [Pose(stride=0.0, fade=0.35, jaw=0.4), Pose(stride=0.0, fade=0.7, jaw=0.2), Pose(stride=0.0, fade=1.0, crouch=1.0)],
}
