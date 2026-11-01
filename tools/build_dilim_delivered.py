#!/usr/bin/env python3
"""Cut the art team's Dilim creatures (LEVEL4_Creatures/) into the game's strips.

WHAT ARRIVED
------------
`Creatures.zip` (2026-10-20): three character sheets, 1254 px square with no alpha. Each is a
turnaround, walk or fly cycles, and a row of poses, on a near-black panel with gold rules and labels:
    ASWANG/whitelady.png     a white lady -- in Dilim, the lean aswang (Kent, 2026-10-21)
    ASWANG/kapre.png         the kapre: small, standing, a cigar in its mouth
    ASWANG/manananggal.png   the manananggal, its lower legs drawn apart
    ASWANG/aswang.png        the supplied crawling aswang sheet (2026-11-01), replacing
                            the sculpted old/hulking aswang, `aswang_pig`
    ASWANG/tikbalang.png     the supplied tikbalang sheet (2026-11-01), idle and race cycles
    ASWANG/tiyanak.png       crying infant, transformation, and transformed encounter poses
They replace the sculpted strips of the same names (ART_PLACEHOLDERS.md: "a delivered strip of the
same name replaces one with no code change"). build_dilim_creatures.py draws everything else and
leaves these names alone (DELIVERED).

HOW THEY ARE CUT
----------------
The poses are pixel art scaled up and softened, with no steady pixel grid, so they are not
re-pixelated: each is keyed off its panel and scaled down smoothly, the way the apo's own painted
art is.
- A row of poses is a box on its sheet. The panel's colour is the box's commonest colour; a pixel
  more than KEY_DIFF from it, and not the gold of the rules, is the figure's. Where a row's labels
  are (Row.labels, boxes on the sheet), their cream letters go too, with LABEL_EDGE px round them
  for the dark edging -- only there, since a pale highlight on a figure can be the same cream.
- The figures are the row's connected shapes of MIN_AREA px or more, left to right: labels, panel
  corners, the stomp's dust and the angry pose's marks are all far smaller. A row whose frames are
  ruled apart, wings crossing from cell to cell, is cut at its cells' edges instead.
- Each pose stands on a soft dark shadow. Whatever is below its lowest bright pixel goes, and on its
  bottom rows so does anything darker than the panel that is not an edge of the figure itself.
  Specks left apart from the figure (SPECK of it or less) go too, and a hole it closes round of
  HOLE px or less -- a nostril or a pupil near the panel's own colour -- is filled back in.
- The manananggal's poses carry its legs under it, joined on by a drip of blood or a shadow; for
  its upper half they are cut away by hand (LEGS_AT), leaving the drip at the waist.
- One scale per creature (SCALE), premultiplied. The tiyanak's sheet draws its transformed poses
  at different sizes: match their visible body area to its crying form before framing them.
- A pose drawn facing left is mirrored (FACING_LEFT): the game's strips face right, and
  PixelStripAnimator turns them.
- Death, which no sheet draws, is the pose fading out -- and, for a flier, dropping as it fades.

THE STRIP CONTRACT (as build_dilim_creatures.py)
-------------------------------------------------
A row of square frames. Ground creatures stand on the bottom row, their feet centred across the
frame; fliers are centred both ways -- that point is the creature's position in the game.

USAGE
    python3 tools/build_dilim_delivered.py            # write game/assets/Level4/creatures/
    python3 tools/build_dilim_delivered.py --check    # verify the committed strips are current
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import numpy as np  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402
from scipy import ndimage  # noqa: E402

import pixelart  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "LEVEL4_Creatures" / "ASWANG"
OUT = ROOT / "game" / "assets" / "Level4" / "creatures"

## How far from the panel's colour a pixel must be to be the figure's, and how big a shape must be
## to be a figure.
KEY_DIFF = 10
MIN_AREA = 2000
## A pixel this much brighter than the panel is the figure's own, never its shadow.
BRIGHT = 20
## Clear pixels left round every frame, so nothing touches an edge it should not.
MARGIN = 2
## A piece apart from the figure this small a share of it is a speck: an anger mark's edge, dust.
SPECK = 0.015
## A hole the figure closes round, this small, is the figure's: a dark detail keyed out with the
## panel. A bigger one is a real gap (between strands of hair, an arm and its side).
HOLE = 30
## Ruled cells are cut this far inside their rules.
INSET = 4
## How far a label's dark edging reaches past its cream letters.
LABEL_EDGE = 3


@dataclass(frozen=True)
class Row:
    """A row of poses on a sheet: its box, its poses' names left to right, for frames ruled
    apart its cells' edges in sheet x, and where on the sheet any labels in it are."""

    box: tuple[int, int, int, int]
    names: tuple[str, ...]
    edges: tuple[int, ...] = ()
    labels: tuple[tuple[int, int, int, int], ...] = ()
    inset: int = INSET


def _cycle(stem: str) -> tuple[str, ...]:
    return tuple(f"{stem}{i}" for i in range(1, 7))


ROWS = {
    "tiyanak": [
        Row((375, 60, 1030, 193), ("cry1", "cry2", "cry3", "cry4")),
        Row((375, 250, 1510, 394), _cycle("change")),
        Row((375, 672, 936, 773), ("crawl1", "crawl2", "crawl3", "crawl4", "crawl5")),
        Row((365, 837, 755, 975), ("snarl1", "snarl2", "snarl3", "snarl4")),
        Row((774, 831, 1247, 976), ("crouch", "jump1", "jump2", "land")),
        Row((1270, 832, 1515, 976), ("hurt1", "hurt2")),
    ],
    "tikbalang": [
        Row((366, 466, 871, 613), ("idle1", "idle2", "idle3", "idle4"),
            edges=(366, 495, 620, 746, 871), labels=((366, 466, 540, 472),), inset=0),
        Row((934, 471, 1510, 613), ("run1", "run2", "run3", "run4"),
            edges=(934, 1078, 1223, 1362, 1510), inset=0),
    ],
    "aswang": [
        Row((320, 310, 904, 421), _cycle("walk"), edges=(320, 416, 513, 610, 711, 814, 904), inset=0),
        Row((320, 475, 901, 586), ("idle1", "idle2", "idle3", "idle4"),
            edges=(320, 465, 610, 755, 901), inset=0),
        Row((320, 638, 1075, 750), ("ready", "claw1", "claw2", "settle"),
            edges=(320, 488, 696, 909, 1075), inset=0),
        Row((1125, 637, 1505, 750), ("hurt1", "hurt2"), edges=(1125, 1303, 1505), inset=0),
    ],
    "whitelady": [
        Row((345, 440, 1235, 648), _cycle("walk")),
        Row((340, 975, 1235, 1176), ("idle", "float", "look_up", "look_down", "reach", "eerie")),
    ],
    "kapre": [
        Row((405, 440, 1230, 622), _cycle("walk")),
        Row((405, 960, 1230, 1162), ("idle", "look_up", "look_down", "reach", "stomp", "angry")),
    ],
    "manananggal": [
        Row((345, 1008, 1235, 1091), _cycle("fly"), edges=(345, 505, 628, 785, 925, 1078, 1235),
            labels=((345, 1074, 1235, 1091),)),
        Row((345, 700, 1235, 845), ("hover_perch", "look_up", "look_down", "scream"), labels=((345, 826, 1235, 845),)),
        Row((345, 848, 1235, 962), ("attack", "spooky", "playful"),
            labels=((345, 946, 1235, 962), (560, 848, 660, 945))),  # the perch's second line, LAND
        Row((30, 965, 320, 1070), ("legs_front", "legs_side", "legs_back"), labels=((30, 1056, 320, 1070),)),
    ],
}

## The manananggal's legs, drawn under its body in the poses its upper half takes, cut away: boxes
## in sheet px, below the drip of blood at its waist.
LEGS_AT = {
    ("manananggal", "look_up"): (744, 801, 780, 826),
    ("manananggal", "look_down"): (921, 802, 958, 826),
    ("manananggal", "attack"): (443, 918, 488, 951),
}

# Solid hair landmarks, in the supplied crawler sheet's coordinates. Its darkest hair shades
# overlap the panel colour, so colour keying alone punches holes through these locks. Restore
# the enclosed pockets at these points from the original RGB; the spaces between limbs stay
# transparent. These are source landmarks, not painted replacement pixels.
ASWANG_HAIR_AT = {
    "walk1": ((372, 350),),
    "walk2": ((472, 348), (447, 359)),
    "walk3": ((567, 348),),
    "walk4": ((654, 352),),
    "walk5": ((759, 349), (735, 360)),
    "walk6": ((842, 353),),
    "idle1": ((404, 506), (384, 509)),
    "idle2": ((524, 507), (537, 517)),
    "idle3": ((675, 505), (661, 507), (650, 515), (635, 523), (674, 539)),
    "idle4": ((822, 506), (843, 505), (793, 520)),
    "ready": ((414, 679), (379, 686)),
    "claw1": ((585, 669), (569, 678)),
    "claw2": ((751, 683), (788, 703)),
    "settle": ((1010, 677), (986, 677), (1003, 700)),
    "hurt1": ((1228, 661),),
    "hurt2": ((1422, 663), (1394, 672)),
}

# The front lock also opens onto the background at its tip, so an enclosed-hole repair cannot
# recover it. Narrow strokes down the INSIDE of that lock preserve its original dark RGB without
# widening the outside silhouette or filling the much larger spaces between the limbs.
ASWANG_FRONT_LOCK = {
    "walk1": (((395, 343), (393, 373)), 6),
    "walk2": (((489, 341), (487, 370)), 6),
    "walk3": (((581, 345), (579, 378)), 5),
    "walk4": (((678, 344), (676, 375)), 6),
    "walk5": (((776, 345), (776, 376)), 5),
    "walk6": (((867, 345), (865, 376)), 5),
    "idle1": (((398, 503), (396, 537)), 5),
    "idle2": (((535, 504), (535, 538)), 5),
    "idle3": (((680, 504), (676, 540)), 6),
    "idle4": (((836, 502), (835, 538)), 5),
    "ready": (((418, 671), (414, 705)), 5),
    "claw1": (((591, 666), (584, 697)), 5),
    "claw2": (((794, 665), (787, 704)), 4),
    "settle": (((1006, 675), (1002, 704)), 5),
}

# Dark mane pixels also overlap the tikbalang sheet's panel. These landmarks select only solid
# mane pockets; the real gap beside idle2's hanging arm is deliberately left transparent.
TIKBALANG_MANE_AT = {
    "idle1": ((418, 487), (405, 504)),
    "idle2": ((552, 492), (536, 509)),
    "idle3": ((675, 491), (658, 509)),
    "idle4": ((799, 499),),
    "run1": ((1032, 491), (1021, 502), (1001, 515)),
    "run2": ((1161, 506),),
    "run3": ((1312, 501), (1284, 520)),
    "run4": ((1442, 508), (1415, 529)),
}

## Each creature's one scale, from the sheet to the game: the white lady a head taller than the
## apo (106 px), the kapre half again her height on its branch (Kent, 2026-10-22: "make the kapre
## bigger"; its sheet's "small in form" left it her size), the manananggal's wings ~140 px across.
SCALE = {"whitelady": 0.66, "kapre": 0.86, "manananggal": 0.9, "aswang": 1.0, "tikbalang": 1.0,
         "tiyanak": 0.4}

## Poses drawn facing left.
FACING_LEFT = {"whitelady": {"idle", "float", "look_up", "look_down", "reach"},
               "aswang": {"hurt2"}}

## The game's strips, each from one sheet's poses. A `_death` strip is its one pose fading out.
STRIPS: dict[str, tuple[str, list[str]]] = {
    "tiyanak_idle": ("tiyanak", ["cry1", "cry2", "cry3", "cry4"]),
    "tiyanak_transform": ("tiyanak", list(_cycle("change"))),
    "tiyanak_true": ("tiyanak", ["snarl1", "snarl2", "snarl3", "snarl4"]),
    "tiyanak_run": ("tiyanak", ["crawl1", "crawl2", "crawl3", "crawl4", "crawl5"]),
    "tiyanak_windup": ("tiyanak", ["crouch"]),
    "tiyanak_attack": ("tiyanak", ["jump1", "jump2", "land"]),
    "tiyanak_leap": ("tiyanak", ["jump1", "jump2"]),
    "tiyanak_hurt": ("tiyanak", ["hurt1", "hurt2"]),
    "tiyanak_death": ("tiyanak", ["hurt1"]),
    "tikbalang_idle": ("tikbalang", ["idle1", "idle2", "idle3", "idle4"]),
    "tikbalang_run": ("tikbalang", ["run1", "run2", "run3", "run4"]),
    "aswang_pig_idle": ("aswang", ["idle1", "idle2", "idle3", "idle4"]),
    "aswang_pig_run": ("aswang", list(_cycle("walk"))),
    "aswang_pig_windup": ("aswang", ["ready"]),
    "aswang_pig_attack": ("aswang", ["claw1", "claw2", "settle"]),
    "aswang_pig_hurt": ("aswang", ["hurt1", "hurt2"]),
    "aswang_pig_death": ("aswang", ["hurt1"]),
    "aswang_dog_idle": ("whitelady", ["idle", "float"]),
    "aswang_dog_run": ("whitelady", list(_cycle("walk"))),
    "aswang_dog_windup": ("whitelady", ["eerie"]),
    "aswang_dog_attack": ("whitelady", ["reach"]),
    "aswang_dog_hurt": ("whitelady", ["look_up"]),
    "aswang_dog_death": ("whitelady", ["idle"]),
    "kapre_idle": ("kapre", ["idle"]),
    "kapre_knocked": ("kapre", ["angry"]),
    "kapre_falling": ("kapre", ["look_up"]),
    "kapre_walk": ("kapre", list(_cycle("walk"))),
    "manananggal_upper_idle": ("manananggal", list(_cycle("fly"))),
    "manananggal_upper_run": ("manananggal", list(_cycle("fly"))),
    "manananggal_upper_windup": ("manananggal", ["spooky"]),
    "manananggal_upper_attack": ("manananggal", ["attack"]),
    "manananggal_upper_hurt": ("manananggal", ["look_up"]),
    "manananggal_upper_death": ("manananggal", ["look_down"]),
    "manananggal_lower_idle": ("manananggal", ["legs_front"]),
    "manananggal_lower_death": ("manananggal", ["legs_front"]),
}
DELIVERED = frozenset(STRIPS)

FLYING = {"manananggal_upper"}

## The kapre in its tree, as Kapre2D stands it (its origin the balete's foot): the strip's
## bottom-centre -- its feet -- on top of the branch (dilim_small.PERCH 170 px up, its top 174 here,
## a pixel into the bark), ART_AT; its cigar, seen end on in its teeth, at CIGAR_TIP, where the hit
## area and the ember's light are; its lips, where the light on its face starts, at LIPS; its eyes
## at FACE. Measured off kapre_idle; tests/test_build_dilim_delivered.py holds them to it.
KAPRE_ART_AT = (-64, -173)
KAPRE_CIGAR_TIP = (-62, -271)
KAPRE_LIPS = (-62, -270)
KAPRE_FACE = (-62, -285)
## A death fades over three frames: how much of it is left, and how far it has dropped (px).
FADE = (0.7, 0.4, 0.15)
DROP = {"ground": (0, 1, 2), "flying": (4, 10, 18)}


def kind_of(strip: str) -> str:
    return strip.rsplit("_", 1)[0]


@lru_cache(maxsize=None)
def _sheet(name: str) -> np.ndarray:
    with Image.open(SRC / f"{name}.png") as image:
        return np.asarray(image.convert("RGB")).astype(int)


def _panel(band: np.ndarray) -> np.ndarray:
    """The panel's colour: the commonest in the box, to 4 levels."""
    q = (band // 4).reshape(-1, 3)
    values, counts = np.unique(q, axis=0, return_counts=True)
    return values[counts.argmax()] * 4 + 2


def _key(band: np.ndarray, panel: np.ndarray, labels: list[tuple[int, int, int, int]],
         *, remove_gold: bool = True) -> np.ndarray:
    r, g, b = band[..., 0], band[..., 1], band[..., 2]
    gold = (r > 120) & (g > 95) & (b < 120) & (r - b > 50) & (r >= g) & (g > b)
    mask = np.abs(band - panel).max(axis=2) > KEY_DIFF
    if remove_gold:
        mask &= ~gold
    if labels:
        cream = (r > 170) & (g > 150) & (r >= g) & (g > b) & (r - b > 35)
        where = np.zeros_like(cream)
        for lx0, ly0, lx1, ly1 in labels:
            where[max(0, ly0):ly1, max(0, lx0):lx1] = True
        mask &= ~ndimage.binary_dilation(cream & where, iterations=LABEL_EDGE)
    return mask


def _shapes(mask: np.ndarray, row: Row, x0: int) -> list[np.ndarray]:
    """Each figure's own pixels in a row's mask, left to right."""
    if row.edges:
        out = []
        for e0, e1 in zip(row.edges, row.edges[1:]):
            cell = np.zeros_like(mask)
            cell[:, e0 - x0 + row.inset:e1 - x0 - row.inset] = mask[:, e0 - x0 + row.inset:e1 - x0 - row.inset]
            lab, n = ndimage.label(ndimage.binary_dilation(cell, iterations=2))
            sizes = ndimage.sum(cell, lab, range(1, n + 1))
            keep = 1 + np.nonzero(sizes >= MIN_AREA // 8)[0]
            out.append(cell & np.isin(lab, keep))
        return out
    lab, n = ndimage.label(ndimage.binary_dilation(mask, iterations=2))
    found = []
    for i, box in enumerate(ndimage.find_objects(lab), 1):
        own = mask & (lab == i)
        if own.sum() >= MIN_AREA:
            found.append((box[1].start, own))
    return [own for _, own in sorted(found, key=lambda f: f[0])]


def _unshadowed(band: np.ndarray, own: np.ndarray, panel: np.ndarray) -> np.ndarray:
    """A figure without the soft shadow it stands on."""
    lum = band.mean(axis=2)
    bright = own & (lum > panel.mean() + BRIGHT)
    rows = np.nonzero(bright.any(axis=1))[0]
    if len(rows) == 0:
        return own
    out = own.copy()
    low = int(rows.max())
    out[low + 1:] = False
    dark = lum < panel.mean() - 2
    edge = ndimage.binary_dilation(bright, structure=np.ones((3, 3)))
    bottom = slice(max(0, low - 5), low + 1)
    out[bottom] &= ~(dark[bottom] & ~edge[bottom])
    lab, n = ndimage.label(out, structure=np.ones((3, 3)))
    if n:
        sizes = ndimage.sum(out, lab, range(1, n + 1))
        out &= np.isin(lab, 1 + np.nonzero(sizes > SPECK * sizes.sum())[0])
    holes = ndimage.binary_fill_holes(out) & ~out
    lab, n = ndimage.label(holes)
    if n:
        sizes = ndimage.sum(holes, lab, range(1, n + 1))
        out |= np.isin(lab, 1 + np.nonzero(sizes <= HOLE)[0])
    return out


def _restore_ink_pockets(own: np.ndarray, points: tuple[tuple[int, int], ...],
                         origin: tuple[int, int], subject: str) -> np.ndarray:
    """Restore original-colour ink at marked enclosed pockets, never exterior background."""
    holes = ndimage.binary_fill_holes(own) & ~own
    lab, _ = ndimage.label(holes)
    keep = set()
    x0, y0 = origin
    for x, y in points:
        if own[y - y0, x - x0]:
            continue
        pocket = int(lab[y - y0, x - x0])
        if pocket == 0:
            raise ValueError(f"{subject}: solid ink at {(x, y)} opens onto the background")
        keep.add(pocket)
    return own | np.isin(lab, list(keep))


def _restore_aswang_hair(own: np.ndarray, pose: str, origin: tuple[int, int]) -> np.ndarray:
    out = _restore_ink_pockets(own, ASWANG_HAIR_AT[pose], origin, f"aswang {pose}")
    x0, y0 = origin
    if pose in ASWANG_FRONT_LOCK:
        points, width = ASWANG_FRONT_LOCK[pose]
        matte = Image.new("1", (own.shape[1], own.shape[0]))
        ImageDraw.Draw(matte).line([(x - x0, y - y0) for x, y in points], fill=1, width=width)
        out |= np.asarray(matte, dtype=bool)
    # Closing the strand can enclose a couple of previously exterior pixels beside it.
    small, count = ndimage.label(ndimage.binary_fill_holes(out) & ~out)
    sizes = ndimage.sum(small > 0, small, range(1, count + 1))
    out |= np.isin(small, 1 + np.nonzero(sizes <= HOLE)[0])
    return out


@lru_cache(maxsize=None)
def poses(name: str) -> dict[str, Image.Image]:
    """Every pose on a sheet, keyed and cropped, at the sheet's own size."""
    sheet = _sheet(name)
    out = {}
    for row in ROWS[name]:
        x0, y0, x1, y1 = row.box
        band = sheet[y0:y1, x0:x1]
        panel = _panel(band)
        labels = [(lx0 - x0, ly0 - y0, lx1 - x0, ly1 - y0) for lx0, ly0, lx1, ly1 in row.labels]
        # Outside the explicit label boxes, these rows have no gold rules. The crawler's claws
        # and tikbalang's skin overlap the other sheets' gold ink: keep those character colours.
        shapes = _shapes(_key(band, panel, labels, remove_gold=name not in {"aswang", "tikbalang", "tiyanak"}), row, x0)
        assert len(shapes) == len(row.names), f"{name}: {len(shapes)} figures in a row of {len(row.names)}"
        for pose, own in zip(row.names, shapes):
            if (name, pose) in LEGS_AT:
                lx0, ly0, lx1, ly1 = LEGS_AT[(name, pose)]
                own = own.copy()
                own[ly0 - y0:ly1 - y0, lx0 - x0:lx1 - x0] = False
            own = _unshadowed(band, own, panel)
            if name == "aswang":
                own = _restore_aswang_hair(own, pose, (x0, y0))
            elif name == "tikbalang":
                own = _restore_ink_pockets(own, TIKBALANG_MANE_AT[pose], (x0, y0), f"tikbalang {pose}")
            ys, xs = np.nonzero(own)
            crop = (slice(ys.min(), ys.max() + 1), slice(xs.min(), xs.max() + 1))
            rgba = np.zeros(own[crop].shape + (4,), dtype=np.uint8)
            rgba[..., :3] = band[crop].clip(0, 255)
            rgba[..., 3] = np.where(own[crop], 255, 0)
            picture = Image.fromarray(rgba, "RGBA")
            if pose in FACING_LEFT.get(name, ()):
                picture = picture.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            out[pose] = picture
    return out


def _scaled(picture: Image.Image, scale: float) -> Image.Image:
    w, h = picture.size
    size = (max(1, round(w * scale)), max(1, round(h * scale)))
    out = np.asarray(picture.convert("RGBa").resize(size, Image.Resampling.LANCZOS).convert("RGBA")).copy()
    out[out[..., 3] < 8] = 0
    return Image.fromarray(out, "RGBA")


def _figure(name: str, pose: str) -> Image.Image:
    picture = poses(name)[pose]
    scale = SCALE[name]
    if name == "tiyanak" and not pose.startswith("cry"):
        # Blank frame dimensions and pose height do not measure a body: the swaddled baby is
        # wide, the snarling form stands up, and the crawling drawings are much smaller on
        # the sheet. Match visible ink area, keeping proportions and the current baby size.
        reference = np.mean([np.asarray(poses(name)[f"cry{i}"])[..., 3].sum()
                             for i in range(1, 5)])
        area = np.asarray(picture)[..., 3].sum()
        scale *= float(np.sqrt(reference / area))
    return _scaled(picture, scale)


def _anchor(picture: Image.Image, flying: bool) -> tuple[float, float]:
    """Where a frame hangs: a flier's middle, or the middle of a ground creature's feet."""
    alpha = np.asarray(picture)[..., 3] > 0
    ys, xs = np.nonzero(alpha)
    if flying:
        return float(xs.mean()), float(ys.mean())
    low = ys.max()
    feet = ys >= low - max(2, (low - ys.min()) // 8)
    return float(xs[feet].mean()), float(low + 1)


def _framed(pictures: list[Image.Image], drops: list[int], flying: bool) -> Image.Image:
    anchors = [_anchor(p, flying) for p in pictures]
    reach = 0.0
    for p, (ax, ay), drop in zip(pictures, anchors, drops):
        w, h = p.size
        reach = max(reach, ax, w - ax)
        reach = max(reach, ay + drop, h - ay - drop) if flying else max(reach, (ay + drop) / 2)
    size = 2 * int(np.ceil(reach)) + 2 * MARGIN
    frames = []
    for p, (ax, ay), drop in zip(pictures, anchors, drops):
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        x = round(size / 2 - ax)
        y = (round(size / 2 - ay) if flying else size - round(ay)) + drop
        # A ground death sinks through its bottom row: what goes below the frame is cut off.
        canvas.alpha_composite(p.crop((0, 0, p.width, min(p.height, size - y))), (x, y))
        frames.append(canvas)
    sheet = Image.new("RGBA", (size * len(frames), size), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        sheet.paste(frame, (i * size, 0))
    return sheet


def _faded(picture: Image.Image, left: float) -> Image.Image:
    rgba = np.asarray(picture).copy()
    rgba[..., 3] = (rgba[..., 3] * left).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def strip(name: str) -> Image.Image:
    sheet, pose_names = STRIPS[name]
    kind = kind_of(name)
    flying = kind in FLYING
    pictures = [_figure(sheet, pose) for pose in pose_names]
    drops = [0] * len(pictures)
    if name.endswith("_death"):
        pictures = [_faded(pictures[0], left) for left in FADE]
        drops = list(DROP["flying" if flying else "ground"])
    return _framed(pictures, drops, flying)


def strips() -> dict[str, Image.Image]:
    return {name: strip(name) for name in STRIPS}


def delivered() -> set[str]:
    return {path.name for path in SRC.glob("*.png")}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="compare, do not write")
    args = ap.parse_args()
    unclaimed = delivered() - {f"{sheet}.png" for sheet, _ in STRIPS.values()}
    if unclaimed:
        print("delivered but cut into nothing:\n  " + "\n  ".join(sorted(unclaimed)))
        return 1
    pictures = pixelart.Pictures(args.check, ROOT)
    made = strips()
    for name, image in made.items():
        pictures.put(image, OUT / f"{name}.png")
    if args.check:
        if pictures.stale:
            print("stale or missing:\n  " + "\n  ".join(pictures.stale))
            return 1
        print(f"OK: {len(made)} delivered creature strips are current")
        return 0
    print(f"wrote {len(made)} delivered strips to {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
