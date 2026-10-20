"""Dilim's props that are drawn like its creatures: the last clearing's dead tree. Sculpted, lit and
outlined like the rest (creature_sculpt), in the kapre's balete's bark (dilim_small)."""

from __future__ import annotations

import math

import numpy as np

from creature_sculpt import Sculpt, hexes
from dilim_small import BARK, EARTH, WOOD

# Wood the bark fell off long ago: the bark's own brown, greyed and bleached by the weather -- so the
# tree reads as dead at a glance, and pale enough to be found at the edge of her light.
DEADWOOD = hexes("#17120d", "#302820", "#4a3f35", "#66584d", "#827265", "#a19082")


def _materials(s: Sculpt) -> None:
    s.material("core", BARK[[0, 0, 0, 1, 1, 2]])
    # Two of the same wood, strand by strand in turn, so a seam is drawn where one lies on the next.
    s.material("dead", DEADWOOD)
    s.material("dead_b", DEADWOOD)
    s.material("bark", BARK)
    s.material("wood", WOOD)
    s.material("earth", EARTH)
    s.material("hollow", BARK[[0, 0, 0, 0, 1, 1]])


def _wood(k: int) -> str:
    return "dead" if k % 2 == 0 else "dead_b"


def _sleeve(s: Sculpt, name: str, points: list, radii: list, a: int, b: int, seed: float) -> None:
    """Bark still round a strand, from point `a` of its path to point `b`: the tube's own cylinder,
    torn off raggedly at both ends rather than capped -- a capped run reads as a sausage laid on
    the wood, not bark peeling from it."""
    best = np.full((s.h, s.w), np.inf, dtype=np.float32)
    nx = np.zeros((s.h, s.w), dtype=np.float32)
    ny = np.zeros((s.h, s.w), dtype=np.float32)
    u = np.zeros((s.h, s.w), dtype=np.float32)
    across = np.zeros((s.h, s.w), dtype=np.float32)
    for i, ((ax, ay), (bx, by), r0, r1) in enumerate(zip(points, points[1:], radii, radii[1:])):
        vx, vy = bx - ax, by - ay
        length2 = max(vx * vx + vy * vy, 1e-6)
        px = s.xs + 0.5 - ax
        py = s.ys + 0.5 - ay
        t = np.clip((px * vx + py * vy) / length2, 0.0, 1.0)
        ox = px - t * vx
        oy = py - t * vy
        r = np.maximum(r0 + (r1 - r0) * t, 0.5)
        q = np.sqrt(ox * ox + oy * oy) / r
        closer = q < best
        best = np.where(closer, q, best)
        nx = np.where(closer, ox / r, nx)
        ny = np.where(closer, oy / r, ny)
        u = np.where(closer, i + t, u)
        across = np.where(closer, (vx * oy - vy * ox) / math.sqrt(length2), across)
    # A few teeth across the strand's width, not a fringe.
    rag = 0.30 * np.sin(across * 0.75 + seed) + 0.16 * np.sin(across * 1.9 + seed * 1.7)
    lo = a + 0.3 + rag if a > 0 else -1.0
    hi = b - 0.3 + rag
    s._paint((best <= 1.0) & (u >= lo) & (u <= hi), name, nx, ny)


def _crooked(p0: tuple, p1: tuple, wobble: float, seed: int, steps: int = 4) -> list:
    """A twig from p0 to p1, kinked sideways at every step the way dead wood grows."""
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    length = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / length, dx / length
    k, pts = seed, []
    for j in range(steps + 1):
        t = j / steps
        k = (k * 1103515245 + 12345) & 0x7FFFFFFF
        w = wobble * (((k >> 8) % 1000) / 1000.0 - 0.5) * math.sin(t * math.pi) * 2
        pts.append((p0[0] + dx * t + nx * w, p0[1] + dy * t + ny * w))
    return pts


def _twigs(s: Sculpt, twigs: list) -> None:
    for k, (p0, p1, r0) in enumerate(twigs):
        pts = _crooked(p0, p1, 5, 3 + k * 2)
        s.tube("dead", pts, [r0 + (0.7 - r0) * j / (len(pts) - 1) for j in range(len(pts))])


def _snapped(s: Sculpt, tip: tuple, toward: tuple, r: float) -> None:
    """A broken end: pale splinters standing out of the wood where it snapped."""
    length = math.hypot(*toward) or 1.0
    dx, dy = toward[0] / length, toward[1] / length
    nx, ny = -dy, dx
    teeth = [0.5, 1.0, 0.35, 0.85, 0.45]
    pts = [(tip[0] - dx * 2 + nx * r, tip[1] - dy * 2 + ny * r)]
    for i, reach in enumerate(teeth):
        a = r - (i + 0.5) * 2 * r / len(teeth)
        out = r * 0.4 + reach * (r * 0.5 + 3)
        pts.append((tip[0] + dx * out + nx * a, tip[1] + dy * out + ny * a))
        if i < len(teeth) - 1:
            b = r - (i + 1) * 2 * r / len(teeth)
            pts.append((tip[0] + dx * r * 0.3 + nx * b, tip[1] + dy * r * 0.3 + ny * b))
    pts.append((tip[0] - dx * 2 - nx * r, tip[1] - dy * 2 - ny * r))
    s.poly("wood", pts, bulge=0.25)


# The hollow, upright as it stands: a tall split in the wood, its rim turned in.
HOLLOW_RIM = [(-2, -30), (6, -18), (12, -2), (12, 14), (4, 24), (-8, 23), (-14, 10), (-12, -8), (-7, -20)]
HOLLOW_PIT = [(-2, -25), (4, -15), (8, -1), (8, 12), (2, 18), (-6, 18), (-10, 8), (-9, -7), (-5, -17)]


def _hollow(s: Sculpt, x: float, y: float, lying: bool) -> None:
    """The hollow, upright or (`lying`) turned a quarter clockwise with the tree. A rim bowled
    inward -- lit on its far side, as a hole is -- round a dark pit."""
    def place(points):
        return [(x - py, y + px) if lying else (x + px, y + py) for px, py in points]
    s.poly("dead_b", place(HOLLOW_RIM), bulge=-0.6)
    s.poly("hollow", place(HOLLOW_PIT), bulge=0.2)


def _knot(s: Sculpt, x: float, y: float) -> None:
    s.ellipse("dead", x, y, 6, 7, flat=1.7)
    s.ellipse("hollow", x, y - 1, 4, 5)


def _beside(pts: list, radii: list, f: float) -> list:
    """The points `f` of the radius off a path, toward its shadowed side -- the side away from the
    upper-left light, whichever way the path runs."""
    out = []
    for i, ((x, y), r) in enumerate(zip(pts, radii)):
        (ax, ay), (bx, by) = pts[max(0, i - 1)], pts[min(len(pts) - 1, i + 1)]
        length = math.hypot(bx - ax, by - ay) or 1.0
        nx, ny = -(by - ay) / length, (bx - ax) / length
        if nx * 0.55 + ny * 0.65 < 0:
            nx, ny = -nx, -ny
        out.append((x + nx * r * f, y + ny * r * f))
    return out


def _grain(s: Sculpt, paths: list, bark_runs: list, skip: int) -> None:
    """Grain along each strand on its shadowed side, in runs, from the trunk on out along its limb;
    fissures down the bark left on it."""
    for pts, radii in paths:
        run = _beside(pts, radii, 0.45)
        for start in range(skip, len(run) - 2, 5):
            s.curve(run[start:start + 4], s.tone("dead", 1), only_on_body=True)
    for k, a, b in bark_runs:
        pts, radii = paths[k]
        for f in (-0.4, 0.3):
            s.curve(_beside(pts, radii, f)[a:b + 1], s.tone("bark", 1), only_on_body=True)


def _crack(s: Sculpt, points: list, lying: bool) -> None:
    """The split down the trunk: a dark crack, its lit lip on the side toward the light."""
    s.curve(points, s.tone("core", 0), only_on_body=True)
    s.curve([(x, y + 1) if lying else (x + 1, y) for x, y in points], s.tone("core", 0), only_on_body=True)
    s.curve([(x, y - 1) if lying else (x - 1, y) for x, y in points], s.tone("dead", 5), only_on_body=True)


# The trunk's strands, left to right as it stands (top to bottom as it lies): where each sits
# across the trunk, its phase in the twist, its thickness. Each runs on up into one of the limbs.
STRANDS = [(-17, 0.0, 9.0), (-7, 1.7, 9.5), (3, 3.2, 9.5), (13, 4.6, 9.0), (22, 5.9, 8.0)]
# Bark still on a strand: which one, from which point of its path to which.
BARK_RUNS = [(3, 0, 6), (0, 0, 3), (4, 5, 9), (1, 9, 12)]
# And standing, up on two of its limbs.
LIMB_BARK = [(3, 14, 16), (1, 14, 16)]


def dead_tree(felled: bool = False) -> Sculpt:
    """The last clearing's dead tree: long dead and still standing -- strands of grey wood twisted
    round a dark heart, the bark mostly gone and peeling where it is left, a split down the trunk,
    a hollow at its foot and a knot-hole by the fork, roots gripping the ground, and bare limbs in
    elbows ending in twigs, its top snapped off long ago. Standing, 260 x 336 with its foot on the
    bottom edge and its trunk on the middle column (about 54 across and 182 to the fork, as
    DeadTree2D's trunk is). Felled, it lies east, 380 x 140: the picture's middle is the middle
    of the 280 x 64 trunk the finale lays down, the root plate torn up on end at its west end and
    the limbs broken at the far one."""
    if felled:
        return _dead_tree_felled()
    s = Sculpt(260, 336)
    _materials(s)
    cx, ground = 130, 335
    fork = ground - 182
    # Roots gripping the ground, behind the trunk's foot: knuckled, one arched clear of the earth
    # and diving back in, one coming up again past each.
    roots = [
        ([(cx - 12, ground - 36), (cx - 36, ground - 22), (cx - 58, ground - 14), (cx - 82, ground - 8), (cx - 106, ground)], [12, 9, 7, 5, 2.4]),
        ([(cx - 6, ground - 24), (cx - 24, ground - 9), (cx - 42, ground - 3), (cx - 58, ground + 1)], [10, 8, 5, 2.2]),
        ([(cx + 14, ground - 38), (cx + 36, ground - 32), (cx + 56, ground - 26), (cx + 76, ground - 14), (cx + 96, ground - 3),
          (cx + 106, ground + 2)], [12, 9.5, 8, 6, 4, 2.2]),
        ([(cx + 6, ground - 22), (cx + 26, ground - 7), (cx + 42, ground + 1)], [10, 7, 2.5]),
        ([(cx + 108, ground + 3), (cx + 114, ground - 5), (cx + 120, ground - 6), (cx + 126, ground + 2)], [2.0, 3.0, 2.6, 1.6]),
        ([(cx - 110, ground + 3), (cx - 116, ground - 4), (cx - 124, ground + 2)], [2.0, 2.6, 1.4]),
    ]
    for k, (pts, radii) in enumerate(roots):
        s.tube(_wood(k), pts, radii)
    # A low limb that broke off long ago, its stub left.
    s.tube("dead_b", [(cx - 14, ground - 132), (cx - 30, ground - 142), (cx - 40, ground - 152)], [9, 7, 6])
    # The trunk: a dark heart, and round it the strands of old wood twisted together, parting at
    # the top into its limbs -- one strand to each, so wood runs unbroken from foot to twig.
    s.tube("core", [(cx, ground - 2), (cx - 4, ground - 90), (cx, fork + 6)], [32, 25, 21])
    limbs = [
        # Left: up and out in elbows.
        ([(cx - 30, fork - 26), (cx - 42, fork - 54), (cx - 38, fork - 80), (cx - 54, fork - 106), (cx - 70, fork - 124)], 4.0),
        # The left arm: out and down, long.
        ([(cx - 30, fork - 12), (cx - 56, fork - 28), (cx - 80, fork - 26), (cx - 102, fork - 42), (cx - 118, fork - 40)], 2.2),
        # The leader, its top snapped off.
        ([(cx + 2, fork - 30), (cx - 4, fork - 58), (cx + 3, fork - 86), (cx + 1, fork - 98)], 9.0),
        # Right: up in a twist.
        ([(cx + 26, fork - 22), (cx + 42, fork - 48), (cx + 64, fork - 62), (cx + 78, fork - 92), (cx + 86, fork - 122)], 4.0),
        # The right arm, leaving the trunk below the rest and drooping out.
        ([(cx + 48, fork + 18), (cx + 72, fork + 10), (cx + 92, fork + 18), (cx + 110, fork + 8), (cx + 120, fork - 8)], 2.0),
    ]
    paths = []
    for k, ((off, phase, r), (limb, tip)) in enumerate(zip(STRANDS, limbs)):
        top = 0.78 if k == 4 else 1.0
        pts, radii = [], []
        for j in range(13):
            t = j / 12 * top
            flare = (1 - t) ** 3 * 1.5
            lean = -7 * math.sin(t * math.pi * 0.9)
            pts.append((cx + lean + off * (1 + flare) + math.sin(t * 5.0 + phase) * 6.5, ground - 4 - t * (ground - fork)))
            radii.append(r * (1.15 - 0.25 * t) * (0.85 + 0.15 * math.cos(t * 8 + phase)))
        for i, p in enumerate(limb):
            pts.append(p)
            radii.append(radii[12] + (tip - radii[12]) * (i + 1) / len(limb))
        s.tube(_wood(k), pts, radii)
        paths.append((pts, radii))
    for n, (k, a, b) in enumerate(BARK_RUNS + LIMB_BARK):
        pts, radii = paths[k]
        _sleeve(s, "bark", pts, [r + 1.0 for r in radii], a, b, n * 3.1)
    _twigs(s, [
        ((cx - 70, fork - 124), (cx - 76, fork - 150), 2.6), ((cx - 70, fork - 124), (cx - 96, fork - 140), 2.4),
        ((cx - 40, fork - 78), (cx - 20, fork - 112), 3.0), ((cx - 118, fork - 40), (cx - 124, fork - 66), 1.8),
        ((cx - 118, fork - 40), (cx - 126, fork - 28), 1.6), ((cx - 80, fork - 26), (cx - 88, fork - 52), 2.0),
        ((cx + 86, fork - 122), (cx + 80, fork - 146), 2.6), ((cx + 86, fork - 122), (cx + 108, fork - 136), 2.4),
        ((cx + 64, fork - 62), (cx + 56, fork - 94), 2.4), ((cx + 120, fork - 8), (cx + 126, fork - 32), 1.8),
        ((cx + 92, fork + 18), (cx + 104, fork + 34), 1.6), ((cx + 42, fork - 48), (cx + 64, fork - 40), 2.2),
    ])
    _hollow(s, cx - 4, ground - 58, lying=False)
    _knot(s, cx + 14, fork + 30)
    _snapped(s, (cx + 1, fork - 98), (0, -1), 9.5)
    _snapped(s, (cx - 40, ground - 152), (-1, -1), 6.5)
    img = s
    _grain(s, paths, BARK_RUNS + LIMB_BARK, skip=1)
    _crack(s, [(cx - 1, fork + 4), (cx - 5, fork + 30), (cx - 1, fork + 62), (cx - 4, fork + 90)], lying=False)
    return img


def _dead_tree_felled() -> Sculpt:
    s = Sculpt(380, 140)
    _materials(s)
    ground = 139
    # The span the finale lays down starts 140 west of the picture's middle; the trunk's end -- the
    # root plate on it -- sits a little inside it, so what stops a walker is what it walks into.
    foot = 190 - 140 + 16
    mid = ground - 33
    fork = foot + 224
    # Under and beyond its far end: the right limb, crushed on the ground as it came down, and a
    # piece of it broken off further on.
    s.tube("dead_b", [(fork - 6, ground - 14), (fork + 24, ground - 9), (fork + 50, ground - 6)], [9, 6.5, 4.5])
    s.tube("dead", [(fork + 54, ground - 4), (fork + 66, ground - 5), (fork + 76, ground - 4)], [3.6, 3.0, 2.6])
    # Behind its foot, the earth the root plate tore up with it, on end: a slab, lumpy at its edge.
    px, py = foot - 8, ground - 52
    s.poly("earth", [(px - 2, py - 48), (px + 8, py - 42), (px + 14, py - 46), (px + 20, py - 28), (px + 24, py - 4),
                     (px + 22, py + 26), (px + 18, py + 52), (px - 16, py + 52), (px - 22, py + 34), (px - 28, py + 20),
                     (px - 25, py + 4), (px - 30, py - 12), (px - 22, py - 24), (px - 18, py - 40)], bulge=0.35)
    for x, y, r in [(px - 24, py - 20, 7), (px - 28, py + 10, 6), (px - 18, py + 40, 8), (px + 2, py - 44, 7),
                    (px + 16, py - 36, 6), (px - 12, py - 36, 6)]:
        s.ellipse("earth", x, y, r, r * 0.85)
    # The trunk on its side: the dark heart, and the strands lying along it into the limbs.
    s.tube("core", [(foot + 18, mid), (foot + 120, mid + 1), (fork - 20, mid + 2)], [30, 29, 24])
    limbs = [
        # The left limb, in the air now: up and east from the fork.
        ([(fork + 20, mid - 30), (fork + 38, mid - 44), (fork + 52, mid - 48), (fork + 62, mid - 64)], 3.0),
        # The left arm, standing straight up off the log.
        ([(fork + 12, mid - 32), (fork + 22, mid - 56), (fork + 20, mid - 76), (fork + 30, mid - 92)], 2.4),
        # The leader, broken again where it hit.
        ([(fork + 24, mid + 2), (fork + 42, mid - 1), (fork + 52, mid)], 9.0),
        # The right limb, under it and into the ground.
        ([(fork + 14, mid + 18)], 8.0),
        # The right arm, snapped off beneath.
        ([(fork - 30, mid + 30)], 6.0),
    ]
    paths = []
    for k, ((off, phase, r), (limb, tip)) in enumerate(zip(STRANDS, limbs)):
        top = 0.88 if k == 4 else 1.0
        pts, radii = [], []
        for j in range(13):
            t = j / 12 * top
            flare = (1 - t) ** 3 * 0.5
            # Thicker lying than standing by a little: the 64 the finale's trunk stands to.
            y = mid + (off * 1.15 - 2) * (1 + flare) + math.sin(t * 3.6 + phase) * 3.0 * (1 - abs(off) / 40)
            pts.append((foot + 4 + t * (fork - foot - 4), y))
            radii.append(r * 1.1 * (1.1 - 0.15 * t) * (0.88 + 0.12 * math.cos(t * 8 + phase)))
        for i, p in enumerate(limb):
            pts.append(p)
            radii.append(radii[12] + (tip - radii[12]) * (i + 1) / len(limb))
        s.tube(_wood(k), pts, radii)
        paths.append((pts, radii))
    for n, (k, a, b) in enumerate(BARK_RUNS):
        pts, radii = paths[k]
        _sleeve(s, "bark", pts, [r + 1.0 for r in radii], a, b, n * 3.1)
    # The root plate over the trunk's end: the roots that gripped the ground, gone up into the air
    # with it, fanned out of the whole end of the trunk and curling over the earth, their ends
    # drooping where they leave it and rootlets hanging off them.
    # Where each leaves the trunk's end, which way, how far, how thick, and how it curls as it goes.
    fan = [(-30, -96, 62, 6.5, 5), (-26, -116, 70, 6.0, -5), (-20, -136, 65, 6.5, 6), (-13, -152, 60, 5.5, -5),
           (-6, -166, 58, 6.0, 5), (1, -180, 55, 5.5, -6), (8, 166, 55, 6.0, 5), (15, 150, 50, 5.5, -5),
           (21, 134, 42, 5.0, 6), (-34, -76, 50, 4.6, -7), (26, 118, 32, 4.4, 5)]
    ends = []
    for k, (off, deg, reach, r, curl) in enumerate(fan):
        # From inside the trunk's end, so they flare out of it rather than meet it at a seam.
        pts = [(foot + 22, mid + off * 0.8), (foot + 10, mid + off)]
        heading = math.radians(deg)
        for j in range(5):
            step = reach / 5
            heading += math.radians(curl)
            # Out of the earth the last of it droops.
            sag = 1.6 * j if j >= 3 else 0.0
            pts.append((pts[-1][0] + math.cos(heading) * step, pts[-1][1] + math.sin(heading) * step + sag))
        s.tube(_wood(k), pts, [r * 1.2] + [r * (1 - 0.85 * j / 5) for j in range(6)])
        ends.append((pts[-2], deg))
    for (x, y), deg in ends:
        if deg < -100:
            s.tube("dead_b", [(x, y), (x - 1, y + 5), (x + 1, y + 10)], [1.0, 0.8, 0.6])
    # The low limb's stub, pointing up off the log now.
    s.tube("dead_b", [(foot + 132, mid - 18), (foot + 142, mid - 32), (foot + 152, mid - 40)], [9, 7, 6])
    _twigs(s, [
        ((fork + 62, mid - 64), (fork + 58, mid - 92), 2.2), ((fork + 62, mid - 64), (fork + 80, mid - 80), 2.0),
        ((fork + 38, mid - 44), (fork + 46, mid - 70), 2.2), ((fork + 30, mid - 92), (fork + 22, mid - 102), 1.8),
        ((fork + 30, mid - 92), (fork + 42, mid - 102), 1.8), ((fork + 20, mid - 76), (fork + 4, mid - 88), 1.8),
    ])
    _hollow(s, foot + 78, mid - 2, lying=True)
    _knot(s, fork - 26, mid + 12)
    _snapped(s, (fork + 52, mid), (1, 0), 9.5)
    _snapped(s, (foot + 152, mid - 40), (1, -1), 6.5)
    _snapped(s, (fork + 76, ground - 4), (1, 0), 3.0)
    img = s
    _grain(s, paths, BARK_RUNS, skip=3)
    _crack(s, [(fork - 4, mid - 3), (fork - 40, mid + 1), (fork - 80, mid - 3), (fork - 110, mid)], lying=True)
    # The earth on the plate, picked out where it catches the light.
    for k in range(20):
        x, y = px - 26 + (k * 13) % 46, py - 44 + (k * 17) % 94
        if s.mat[y, x] == s.names["earth"]:
            s.dot(x, y, s.tone("earth", 4))
    return img
