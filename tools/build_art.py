#!/usr/bin/env python3
"""Cut the delivered artwork in level-1-assets/ into what the game actually loads.

WHY THIS EXISTS
---------------
The art arrives in two forms and neither is loadable as-is.

The character comes as a DESIGN SHEET: a 1254x1254 presentation page with a title, a
description, a palette, and twenty-three poses laid out in four bordered panels on a flat
dark background. It has no alpha at all. Every frame has to be found, cut out, keyed to
transparency and aligned to a common anchor before it is a sprite.

The four props come as 6x upscaled pixel art on a large transparent canvas -- 576x240 for
a bridge whose real size is 96x40. Downsampling by exactly six recovers the original
pixels with no loss (this script asserts that), and the game then draws them back up at an
integer scale, which keeps every pixel square instead of resampling them into mush.

Both halves are done here rather than by hand so that a redelivery is one command, and so
the numbers below -- which frame is which, how tall the character stands, where the feet
are -- are written down somewhere they can be argued with.

KEYING THE CHARACTER
--------------------
The panel background is a flat near-neutral #201F1B and each figure sits on a soft dark
ellipse of shadow. The character's own darkest colour is #321E08: nearly as dark, but
strongly warm. So the test is not brightness, it is CHROMA -- a pixel belongs to the
background if its channels are close together AND it is dark. That separates the shadow
from a boot, which no luminance threshold does.

Interior detail (the eyes, the gap under an arm) would fail that test too, so the mask is
then flood-filled from the frame border: only background CONNECTED TO THE OUTSIDE is
background. Everything the fill cannot reach belongs to the sprite.

ALIGNMENT
---------
Frames are placed on one shared canvas so that switching animation never moves the
character. Two anchors do that:

  vertical    the panel's own ground line, shared by every frame in that panel, so the
              artist's intended foot heights survive -- a walk cycle that lifts a heel is
              supposed to lift it.
  horizontal  the centre of the HEAD, not of the bounding box. Arms and legs swing; a
              bbox centre swings with them and the character moonwalks.

USAGE
    python3 tools/build_art.py            # write game/assets/
    python3 tools/build_art.py --check    # verify the committed files are up to date
"""

from __future__ import annotations

import argparse
import hashlib
import math
import sys
from collections import Counter, deque
from pathlib import Path
from typing import NamedTuple

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "level-1-assets"
CHARACTER_OUT = ROOT / "game" / "assets" / "characters"
# Level1, capital L: the folder already exists under that name and macOS merges the two
# silently, so a res:// path spelled level1 loads here and fails on any case-sensitive
# platform the game is exported to.
PROP_OUT = ROOT / "game" / "assets" / "Level1" / "props"
UI_OUT = ROOT / "game" / "assets" / "ui"
HUB_OUT = ROOT / "game" / "assets" / "hub" / "paintings"

# --- the character sheets ------------------------------------------------------------
#
# TWO CHARACTERS ARRIVE ON THE SAME PRESENTATION TEMPLATE. The apo and Lolo were drawn
# months apart and delivered as separate 1254x1254 pages, but the pages are laid out to
# the identical grid: a hero card down the left, then TURNAROUND, WALK CYCLE, RUN CYCLE
# and EXTRA POSES stacked in bordered panels down the right. So the panel bounds below
# are shared, and one cutter serves both -- measured against Lolo's page and found to
# land inside every frame on it, which is the only reason sharing them is safe rather
# than lucky.

# Panel interiors, measured off the tan border lines that box each section.
PANEL_X = (340, 1232)
PANELS = [
    ("turnaround", (30, 382), ["front", "34front", "side", "34back", "back"]),
    ("walk", (403, 653), ["0", "1", "2", "3", "4", "5"]),
    ("run", (674, 909), ["0", "1", "2", "3", "4", "5"]),
    ("extra", (930, 1221), ["idle", "look_up", "look_down", "wave", "jump", "cheer"]),
]

# The pose the standing height is measured on. Every frame in walk/run/extra is drawn at
# one scale, so one factor derived from this pose keeps their differences intact -- run is
# shorter because it leans, not because it is smaller.
SCALE_REFERENCE = ("extra", "idle")
# The turnaround panel is drawn larger than the rest of the sheet and gets its own factor,
# derived from the standing pose in it rather than guessed.
TURNAROUND_REFERENCE = ("turnaround", "front")

# Which frames become which file. A strip is one row of frames, left to right.
STRIPS = [
    ("idle", [("extra", "idle")]),
    ("walk", [("walk", str(i)) for i in range(6)]),
    ("run", [("run", str(i)) for i in range(6)]),
    ("jump", [("extra", "jump")]),
    ("look_up", [("extra", "look_up")]),
    ("look_down", [("extra", "look_down")]),
    ("wave", [("extra", "wave")]),
    ("cheer", [("extra", "cheer")]),
    ("turnaround", [("turnaround", n) for n in
                    ["front", "34front", "side", "34back", "back"]]),
]


class CharacterSheet(NamedTuple):
    """One delivered design page and what the game wants out of it."""

    ## What the files are called and which folder they land in: apo_walk.png under
    ## characters/apo, lolo_walk.png under characters/lolo.
    name: str
    source: Path
    ## The hero card in the page's top-left corner, inside its border stroke.
    ##
    ## EACH SHEET CARRIES A SECOND, BIGGER DRAWING OF THE CHARACTER and on the apo's page
    ## it went unused for months. The pose strips are cut down to what the game world
    ## needs; this one is three hundred pixels tall in the source and is a different
    ## drawing rather than the same one enlarged -- shading in the hair, folds in the
    ## cloth that the small frames have no room for. It is exactly what a dialogue
    ## portrait wants, and cutting it costs nothing because the keying is already written.
    hero: tuple[int, int, int, int]
    ## How tall the character stands in the world, in game pixels, on the idle pose.
    standing: float
    ## How to build a walk cycle for this character, or None if it does not need one.
    ## See WalkCycle and build_walk.
    walk: "WalkCycle | None" = None
    ## How to give the delivered run its foot travel, or None. See RunCycle and build_run.
    run: "RunCycle | None" = None


# --- the walk that was not on the sheet ----------------------------------------------
#
# THE DELIVERED WALK IS NOT A CYCLE. Measured across its six frames the gap between the
# feet stays between 53 and 56 pixels, so the legs never pass each other, and the leg mass
# either side of the body axis is the same in all six. It is six near-identical striding
# poses with the hair and the satchel jittering between them. The run sheet is no better
# for the purpose: it plants the same foot at the same place in all six frames, so playing
# it slowly -- which is what the game did until now -- is a boy hopping on one leg.
#
# A SIDE-ON WALK IS NOT READ FROM ITS CONTACTS. Left-foot-forward and right-foot-forward
# look nearly identical from the side; what says "walking" is the PASS between them, the
# moment the legs come together and one swings through. That is the frame neither sheet
# has, and it is why the character reads as sliding.
#
# So the cycle is built here from the one pose the sheet does have. It is built by MOVING
# PIXELS, never by redrawing them: the head, the face, the shirt, the satchel and the arms
# are the delivered artwork untouched, and only the legs below the knee are repositioned.


class WalkCycle(NamedTuple):
    """How to make a walk out of a sheet that only has a stride."""

    ## Which delivered frame the whole cycle is built from. The six are near-identical;
    ## this is the one whose feet are furthest apart and whose boots are cleanest.
    source: tuple[str, str]
    ## The row the legs stop being one shape and become two, measured on the cell. Above it
    ## the thighs, the shorts and the satchel are a single mass and nothing can be moved
    ## without taking the satchel with it; below it there is a clean gap between the boots.
    knee: int
    ## The row below which the two legs are swapped for the second half of the cycle. One
    ## row above the knee, so the swap takes the whole of both shins -- and low enough that
    ## the satchel, which hangs to about the knee row, is never mirrored with them.
    swap: int
    ## How far each boot travels toward the body on the closing frame and on the pass, and
    ## how far the swinging foot lifts on each.
    steps: tuple[tuple[int, int], ...]
    ## How many rows the shin takes to catch up with its boot. A boot that jumps sideways in
    ## one row snaps off the leg; spread over the whole shin it smears into a diagonal
    ## streak. Five rows is where the leg bends instead of doing either.
    ramp: int
    ## Where the gap between the two legs is, on the cell. The walk's legs stand either
    ## side of the middle; the run's are both left of it, because the character leans.
    split: int = 40


class RunCycle(NamedTuple):
    """How to give a delivered run legs that alternate. See build_run."""

    ## The row the run's torso ends and the walk's legs begin.
    cut: int
    ## How far to slide those legs to meet the leaning hips. A running figure is pitched
    ## forward, so its hips sit further back over its feet than a walking one's.
    offset: int
    ## How far the legs close, in the run's own terms. NOT the walk's: a walk brings its
    ## feet together and stands on one of them, and a run never does -- both feet are off
    ## the ground in the middle of a running stride, and the legs stay scissored through
    ## it. Borrowing the walk's full pass put the boots on top of each other under a
    ## leaning torso and read as a stumble.
    steps: tuple[tuple[int, int], ...]


## The apo, at ninety-six pixels.
##
## The collision capsule it replaces is 80px from the feet up, and the stick figure that
## stood in for it was 83. Ninety-six puts the eyeline above the capsule and lets the hair
## overhang it, which is what makes a chibi silhouette read; the body inside the capsule is
## unchanged, so no gate in GATES.md is affected by this number.
APO = CharacterSheet(
    name="apo",
    source=SOURCE / "Obra Assets Male.png",
    hero=(40, 115, 305, 470),
    standing=96.0,
    ## THE RUN BORROWS THE WALK'S LEGS, because it has none of its own worth keeping and
    ## everything else about it is worth keeping.
    ##
    ## The delivered run pins both boots at the same two columns in all six frames and
    ## plants the same foot in every one of them, so on screen it is a boy hopping. It
    ## cannot be fixed in place the way the walk was: the walk's trick is to reflect the
    ## shins about the body, and that works there because the apo's rear leg is drawn BELOW
    ## the satchel -- a whole boot and shin from row 92 down. In the run he leans and the
    ## satchel swings down with him, covering rows 68 to 95 over the whole of the rear leg,
    ## so the bag and the boot occupy the SAME ROWS and no horizontal cut separates them.
    ## Reflect below the bag and only the front boot moves, and it comes off its shin;
    ## reflect above it and the bag changes shoulders halfway through every stride.
    ##
    ## But the run sheet's value was never its legs. It is the LEAN and the pumped arms --
    ## the torso is pitched forward, the elbows are up, and none of that is anywhere else on
    ## the sheet. So the run keeps its own six torsos and takes the walk's six pairs of
    ## legs, which alternate. The legs slide back to meet the hips, because a running figure
    ## sits further forward over its feet than a walking one.
    ## The cut and the slide are MEASURED, not chosen: for every row from 88 to 96 and
    ## every offset from -20 to -4, the average distance between the torso's edges just
    ## above the seam and the legs' edges just below it. 88 and -11 win it by three times,
    ## and cutting there takes the shorts with the legs rather than leaving the run's own
    ## shorts ending in a flat horizontal line above a pair of legs that do not fit them.
    run=RunCycle(cut=88, offset=-11, steps=((0, 0), (4, 1), (8, 2))),
    walk=WalkCycle(
        source=("walk", "3"),
        knee=92,
        swap=91,
        # Contact, closing, pass. The foot that swings lifts as it comes through, because
        # two boots sliding together along the floor is a shuffle rather than a step.
        steps=((0, 0), (6, 1), (11, 3)),
        ramp=5,
    ),
)

## Lolo, at eighty-four -- deliberately shorter than the apo he floats beside.
##
## He is the grandfather and a ghost, and both of those pull in opposite directions: an
## elder should not be dwarfed by a child, but a COMPANION that stands as tall as the
## player reads as a second protagonist walking alongside them rather than as a guide at
## their shoulder. Seven eighths splits it -- he is unmistakably a person rather than a
## pet, and the eye still lands on the apo first.
##
## The height is measured tail tip to crown, and the tail is most of what makes him read
## as a spirit, so he occupies less of that box than a figure with legs would.
LOLO = CharacterSheet(
    name="lolo",
    source=ROOT / "HUD-assets-ideas" / "Lolo-Ghost.png",
    hero=(30, 111, 300, 500),
    standing=84.0,
)

SHEETS = [APO, LOLO]


# --- the props -----------------------------------------------------------------------

# Delivered at 6x. Verified, not assumed: the run lengths in all four are multiples of six.
PROP_UPSCALE = 6
PROPS = [
    ("Level 1 Assets Stair Dirt.png", "stair_step"),
    ("Floating Dirt Level 1 Asset.png", "floating_tread"),
    ("Level 1 Asset Treetrunk.png", "dead_tree"),
    ("Rice Terraces Broken Bridge.png", "broken_bridge"),
]

# StairTread2D does not draw a stair, it draws ONE step, at whatever size the level gives
# it -- and the delivered art is a three-step run. So two bands come out of it: the grass
# the player stands on and the earth face below. They are cut from the widest step, where
# the art is opaque corner to corner, and doubled so their pixels come out the same size
# as the props' when the level draws those at 2x.
#
# Their sizes are chosen so a tread CROPS them rather than tiling them. A cap is 14px tall
# and a riser at most 24; anything shorter repeats inside the box and puts a seam of grass
# across the middle of a step.
STAIR_BANDS = [
    # The cap comes off the TOP step, which is the only place the grass is a clean strip
    # rather than a fringe overhanging the step below it. It is 18px of art, so it repeats
    # across a wide tread -- grass is irregular enough that the seam does not read, and a
    # step with no green on it does not look like the terraces it is cut into.
    ("stair_cap", (30, 0, 18, 7)),
    ("stair_riser", (2, 20, 46, 12)),
]
BAND_UPSCALE = 2


# --- the haybale and what is inside it ---------------------------------------------------

# THESE TWO ARE PAINTED, NOT PIXEL ART, and that is why they are handled apart from PROPS.
# The four props above are 6x upscaled pixel art and the cutter asserts it: blow the
# downsample back up and it has to reproduce the source exactly. Neither of these would,
# because neither was ever on a pixel grid -- so they are area-averaged down to the size
# they are drawn at instead, and drawn at 1:1 from there.
HAYBALE_SOURCE = "Haybale.png"
## How big the heap is in the level. The delivered art crops to 983x678, so this is that
## shape at a size the apo (96px) stands beside as a heap she could duck into rather than a
## hill. The two smaller heaps on the terrace draw the same texture at exactly HALF this, so
## their pixels stay square.
HAYBALE_SIZE = (208, 144)
## The mouth in the delivered heap, in source pixels, and the straw to cover it with.
##
## ONE PICTURE HAS TO SERVE FOUR STATES. The heap Kent drew has a way in; the other two on
## the terrace do not, and a heap that has been combed is not one with a doorway in it. So a
## second cut fills the mouth by MIRRORING the straw from the far side of the heap over it
## -- same picture, same lighting, same stalks, and no seam that is not already in the art.
HAYBALE_MOUTH = (292, 414, 570, 760)
HAYBALE_PATCH_FROM = (600, 414, 878, 760)

HAYBALE_INTERIOR_SOURCE = "Haybale Interior Idea.png"
## A TILEABLE STRIP, not the whole picture. The delivered interior has the chest and the
## canvas painted into the middle of it, and both of those are real nodes in the level --
## the baul is Node 3's problem and outlives this room. So the backdrop is cut from the left
## end, which is wall and floor and nothing else, and repeated across the room.
HAYBALE_INTERIOR_STRIP = (24, 0, 424, 680)
## Where the dirt starts in that strip, so the level can line the floor up with it.
HAYBALE_INTERIOR_FLOOR = 536
## How much straw to put above it and how much floor below.
##
## The camera sees seven hundred and eighty units of world and the strip is six hundred and
## eighty tall, so on its own it leaves sky above the straw and nothing under the floor. The
## straw band is extended by FLIPPING it rather than repeating it: vertical stalks upside
## down are still vertical stalks, and a repeat puts a visible seam across the wall.
HAYBALE_INTERIOR_ABOVE = 560
HAYBALE_INTERIOR_BELOW = 420


# --- the paintings in Lolo and Lola's house ---------------------------------------------

PAINTING_SOURCE = ROOT / "Painting_Covers"
## How big a painting hangs in the hub. 16:9, because that is what the covers are drawn at,
## and a painting letterboxed inside its own frame looks like a screenshot rather than a
## picture.
##
## A HUNDRED AND TWENTY-EIGHT IS A SIZE IN THE ROOM, not a thumbnail size. The house is
## built to the apo, who is ninety-six pixels tall, so this is a picture about as tall as
## the child looking at it and a shade under two metres wide -- a grand thing to have on a
## wall and still a thing rather than a mural. At 256 it was three and a half metres across
## and the room had to be a hall to hold five of them.
PAINTING_SIZE = (128, 72)

## WHICH COVER IS WHICH LEVEL, BY WHAT IS IN IT rather than by its filename.
##
## The filenames disagree with themselves: two of the five are called "Level 4", one is
## labelled "from Dagat" and shows a fiesta, and the one called "Mt Makiling" is a storm at
## sea. Going by content instead, the five line up exactly with the levels the design
## already names -- terraces, pista, dagat, the forest, Mayon -- so that is the order used
## here, and the mismatch is worth knowing about before anyone renames a file to match.
PAINTINGS = [
    ("level_1", "Level 1 Rice Terraces Completed Look.png"),      # Ifugao terraces
    ("level_2", "Level 2 Completed Look from Dagat.png"),         # a fiesta plaza
    ("level_3", "Level 4 Mt Makiling Completed Look.png"),        # a storm at sea
    ("level_4", "Level 4 Completed Look from Mayon.png"),         # rainforest under Makiling
    ("level_5", "Level 5.png"),                                   # Mayon over the ruins
]


# --- the wordmark ----------------------------------------------------------------------

LOGO_SOURCE = ROOT / "HUD-assets-ideas" / "Logo.jpg"
## The flat page the wordmark was presented on.
LOGO_PAGE = (0x14, 0x35, 0x1A)
## How far off that colour a pixel has to be to belong to the mark.
LOGO_KEY = 26
## THE LOGO IS 3x PIXEL ART INSIDE A JPEG, which is the worst way to receive pixel art:
## every hard edge in it is a block boundary, and JPEG puts its ringing exactly there. The
## run lengths still divide by three, so the grid survives -- what does not survive is the
## colour, which comes back as four thousand shades of gold instead of a dozen.
##
## So the downsample takes the MEDIAN of each 3x3 block rather than the mean. A mean drags
## every block toward the ringing around it; a median ignores it, because the ringing is a
## minority of the samples. The phase below was measured by trying all nine and keeping the
## one whose blocks came out most uniform.
LOGO_UPSCALE = 3
LOGO_PHASE = (1, 2)
## And then the palette is rebuilt by k-means over the opaque pixels only. Twenty-four is
## where the gold stops banding: the mark is shaded, not flat, so it needs more than a
## poster palette, and the error curve has no knee to pick instead.
LOGO_COLOURS = 24
LOGO_SEED = 7


def foreground_mask(rgb: np.ndarray) -> np.ndarray:
    """Warm or bright is the sprite; near-neutral and dark is the panel or its shadow."""
    high = rgb.max(axis=2)
    low = rgb.min(axis=2)
    return ((high - low) > 10) | (high > 48)


def page_colour(rgb: np.ndarray) -> int:
    """How bright the flat page behind the figures is, as one number.

    Measured off the sheet rather than written down, because the two pages are not the
    same colour -- the apo's is 201F1B and Lolo's a good deal darker at 131413 -- and a
    third would be a third. It is the modal pixel of the whole page, which on a design
    sheet is overwhelmingly empty background.
    """
    sample = rgb[::3, ::3].reshape(-1, 3)
    common = Counter(map(tuple, sample)).most_common(1)[0][0]
    return int(max(common))


## How much darker than the page a pocket has to be before it counts as ink.
##
## THE FILL CANNOT TELL A HOLE FROM AN OUTLINE on its own -- both are dark and both are
## sealed off from the outside -- so it rescues them alike, and Lolo's tail curls round on
## itself in half his poses. Each of those curls encloses a bite of page, and each came
## back as a dark blot pasted on the tail.
##
## What separates them is that a HOLE IS THE PAGE SHOWING THROUGH and is therefore exactly
## as bright as the page, while ink is drawn darker than it. Measured across both sheets
## the two populations sit either side of this margin with room to spare: pockets of page
## read within six of it, and the darkest thing that is genuinely drawn -- Lolo's eyes and
## mouth, which are flat black -- is twenty below.
PAGE_MARGIN = 6


def without_thin_columns(mask: np.ndarray, radius: int = 2) -> np.ndarray:
    """Erode horizontally, so anything narrower than 2*radius+1 disappears.

    Used ONLY to decide where the frames are, never to cut them. Two things in the sheet
    are thin: the 2px rules that divide the pose cells, and the strokes of the little
    labels printed under them. Both are foreground by every colour test, and the dividers
    bridge the gap between the poses and their labels -- so a row profile taken on the raw
    mask reports one tall band and every extra pose comes out with the word IDLE or JUMP
    baked into its feet, floating twenty pixels above the ground line it shares.
    """
    out = mask.copy()
    for step in range(1, radius + 1):
        out &= np.roll(mask, step, axis=1) & np.roll(mask, -step, axis=1)
    return out


def without_page_holes(solid: np.ndarray, raw: np.ndarray, rgb: np.ndarray,
                       page: int) -> np.ndarray:
    """Reopen the pockets of page that the border fill sealed up. See PAGE_MARGIN."""
    out = solid.copy()
    sealed = solid & ~raw
    height, width = sealed.shape
    seen = np.zeros_like(sealed, dtype=bool)
    for sy in range(height):
        for sx in range(width):
            if not sealed[sy, sx] or seen[sy, sx]:
                continue
            queue: deque = deque([(sy, sx)])
            seen[sy, sx] = True
            pocket = [(sy, sx)]
            while queue:
                y, x = queue.popleft()
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy, x + dx
                    if (0 <= ny < height and 0 <= nx < width
                            and sealed[ny, nx] and not seen[ny, nx]):
                        seen[ny, nx] = True
                        queue.append((ny, nx))
                        pocket.append((ny, nx))
            brightness = np.median([rgb[y, x].max() for y, x in pocket])
            if brightness >= page - PAGE_MARGIN:
                for y, x in pocket:
                    out[y, x] = False
    return out


def fill_from_border(mask: np.ndarray) -> np.ndarray:
    """Keep only background the outside can reach, so eyes stay eyes.

    THE CROP IS PADDED WITH A RING OF BACKGROUND FIRST, so the flood can always get all
    the way round the figure. Without it the function silently depends on the caller
    having left a margin, and a box cut tight to the drawing has none: the gap between an
    arm and a torso opens at the edge of the crop, the flood cannot reach round into it,
    and it fills solid. That is what happened to the apo's three-quarter view the day the
    frame boxes were tightened onto the drawing itself -- three thousand pixels of daylight
    under one arm turned into shirt, with nothing about the alignment changed to hint at
    why.
    """
    mask = np.pad(mask, 1, constant_values=False)
    height, width = mask.shape
    background = np.zeros_like(mask, dtype=bool)
    queue: deque = deque()

    def seed(y: int, x: int) -> None:
        if not mask[y, x] and not background[y, x]:
            background[y, x] = True
            queue.append((y, x))

    for x in range(width):
        seed(0, x)
        seed(height - 1, x)
    for y in range(height):
        seed(y, 0)
        seed(y, width - 1)
    while queue:
        y, x = queue.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < height and 0 <= nx < width:
                seed(ny, nx)
    return ~background[1:-1, 1:-1]


def largest_blob(mask: np.ndarray) -> np.ndarray:
    """The biggest single drawing in a cell, with every other speck dropped.

    A POSE IS ONE DRAWING, and that is the only thing separating a frame from the panel
    chrome printed around it. Lolo's page puts its section heading and the rule under it
    INSIDE the sprite row rather than above it -- the jump pose reaches higher than the
    rule does, so no horizontal cut divides the two -- and the thin verticals ruling one
    pose off from the next run the whole height of the panel. All of it keys as
    foreground: it is gold on near-black, which is exactly what a chroma test is looking
    for. Taken on bounding boxes, `idle` came out with EXTRA POSES / ACTIONS printed
    across its head.

    Measured across both delivered sheets, this rule has three orders of magnitude of
    daylight in it: every one of the forty-six poses is a single blob of eight to
    twenty-three thousand pixels, and the largest thing that is NOT part of a pose is
    twenty. No frame on either page has a detached hand or a floating accessory that this
    would eat -- which is the assumption to re-test, on the frames rather than in the
    abstract, if a third sheet is ever cut through here.
    """
    height, width = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    best: np.ndarray | None = None
    best_size = 0
    for sy in range(height):
        for sx in range(width):
            if not mask[sy, sx] or seen[sy, sx]:
                continue
            blob = np.zeros_like(mask, dtype=bool)
            queue: deque = deque([(sy, sx)])
            seen[sy, sx] = True
            blob[sy, sx] = True
            size = 0
            while queue:
                y, x = queue.popleft()
                size += 1
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = y + dy, x + dx
                        if (0 <= ny < height and 0 <= nx < width
                                and mask[ny, nx] and not seen[ny, nx]):
                            seen[ny, nx] = True
                            blob[ny, nx] = True
                            queue.append((ny, nx))
            if size > best_size:
                best_size, best = size, blob
    if best is None:
        raise SystemExit("a frame cell keyed to nothing at all")
    return best


def column_groups(band: np.ndarray, x0: int) -> list[tuple[int, int]]:
    """Split a panel's sprite row into one span per frame."""
    profile = band.sum(axis=0)
    groups: list[tuple[int, int]] = []
    start = None
    for index, value in enumerate(profile):
        if value > 1 and start is None:
            start = index
        elif value <= 1 and start is not None:
            if index - start > 6:
                groups.append((x0 + start, x0 + index - 1))
            start = None
    if start is not None:
        groups.append((x0 + start, x0 + band.shape[1] - 1))
    return groups


def tallest_row_band(mask: np.ndarray, y0: int) -> tuple[int, int]:
    """The sprites, not the section heading or the little labels under them."""
    rows = mask.sum(axis=1)
    bands: list[tuple[int, int]] = []
    start = None
    for index, value in enumerate(rows):
        if value > 2 and start is None:
            start = index
        elif value <= 2 and start is not None:
            if index - start > 4:
                bands.append((y0 + start, y0 + index - 1))
            start = None
    if start is not None:
        bands.append((y0 + start, y0 + mask.shape[0] - 1))
    bands.sort(key=lambda b: b[1] - b[0], reverse=True)
    return bands[0]


def cut_sheet(page: Path) -> dict[tuple[str, str], dict]:
    """Every pose on one design page, keyed, with the numbers needed to line them up."""
    sheet = Image.open(page).convert("RGB")
    rgb = np.asarray(sheet, dtype=int)
    mask = foreground_mask(rgb)
    page = page_colour(rgb)
    solid_only = without_thin_columns(mask)
    x0, x1 = PANEL_X
    frames: dict[tuple[str, str], dict] = {}

    for panel, (py0, py1), names in PANELS:
        band_y0, band_y1 = tallest_row_band(solid_only[py0:py1 + 1, x0:x1 + 1], py0)
        band = solid_only[band_y0:band_y1 + 1, x0:x1 + 1]
        groups = column_groups(band, x0)
        if len(groups) != len(names):
            raise SystemExit(
                f"{page.name}: {panel} expected {len(names)} frames, found "
                f"{len(groups)}. The sheet layout changed; the panel bounds above need "
                "re-measuring against this page.")

        cut: list[dict] = []
        for (gx0, gx1), name in zip(groups, names):
            # The pose itself, with the heading, the rules and the speckle of the page
            # left behind -- see largest_blob. The box is taken off the blob on BOTH axes:
            # a column group that has swallowed a divider is too wide as well as too tall,
            # and an anchor measured across that extra width puts the character off centre.
            blob = largest_blob(mask[band_y0:band_y1 + 1, gx0:gx1 + 1])
            rows = np.where(blob.any(axis=1))[0]
            cols = np.where(blob.any(axis=0))[0]
            ty0, ty1 = band_y0 + rows[0], band_y0 + rows[-1]
            gx0, gx1 = gx0 + int(cols[0]), gx0 + int(cols[-1])
            window = mask[ty0:ty1 + 1, gx0:gx1 + 1]
            solid = without_page_holes(
                fill_from_border(window.copy()), window,
                rgb[ty0:ty1 + 1, gx0:gx1 + 1], page)
            # Head centre, not bbox centre: the arms and legs swing and the head does not.
            head = solid[:max(1, int(solid.shape[0] * 0.30))]
            head_columns = np.where(head.any(axis=0))[0]
            anchor_x = gx0 + float(head_columns.mean())
            cut.append({
                "panel": panel, "name": name,
                "box": (gx0, ty0, gx1 + 1, ty1 + 1),
                "mask": solid, "anchor_x": anchor_x, "bottom": ty1 + 1,
            })

        # One ground line for the whole panel, so a lifted heel stays lifted.
        ground = max(frame["bottom"] for frame in cut)
        for frame in cut:
            frame["ground"] = ground
            frames[(panel, frame["name"])] = frame
    return frames


def keyed_image(sheet: Image.Image, frame: dict) -> Image.Image:
    box = frame["box"]
    rgb = np.asarray(sheet.crop(box), dtype=np.uint8)
    alpha = (frame["mask"] * 255).astype(np.uint8)
    return Image.fromarray(np.dstack([rgb, alpha]), "RGBA")


def scaled(image: Image.Image, factor: float) -> Image.Image:
    """Downscale without letting the keyed-out background bleed into the edges.

    The transparent pixels still carry the panel's dark colour, so a plain resize averages
    it into every edge and the sprite comes back wearing a black outline it was never
    drawn with. Premultiplying first is what stops that.
    """
    width = max(1, int(round(image.width * factor)))
    height = max(1, int(round(image.height * factor)))
    source = np.asarray(image, dtype=float)
    alpha = source[:, :, 3:4] / 255.0
    premultiplied = np.dstack([source[:, :, :3] * alpha, source[:, :, 3:4]]).astype(np.uint8)
    small = np.asarray(
        Image.fromarray(premultiplied, "RGBA").resize((width, height), Image.LANCZOS),
        dtype=float)
    out_alpha = np.clip(small[:, :, 3:4], 0, 255)
    with np.errstate(divide="ignore", invalid="ignore"):
        colour = np.where(out_alpha > 0, small[:, :, :3] * 255.0 / np.maximum(out_alpha, 1e-6), 0)
    return Image.fromarray(
        np.dstack([np.clip(colour, 0, 255), out_alpha]).astype(np.uint8), "RGBA")


def close_legs(cell: np.ndarray, knee: int, ramp: int, axis: int, draw: int,
               lift: int) -> np.ndarray:
    """Bring the boots toward each other under the body, and lift the swinging one.

    Everything above the knee row is left exactly as delivered -- which is what keeps the
    satchel, the shirt and the arms the artist's rather than this script's. Below it the
    two legs are separate shapes, so each is slid toward the body axis by whole pixels: a
    translation, never a scale, because a boot squeezed horizontally stops being a boot
    long before the legs are close enough to read as passing.
    """
    out = cell.copy()
    out[knee:, :, :] = 0
    height = cell.shape[0]
    for y in range(knee, height):
        travelled = min(1.0, (y - knee) / float(ramp))
        shift = int(round(draw * travelled))
        for x in range(cell.shape[1]):
            if cell[y, x, 3] == 0:
                continue
            rear = x < axis
            nx = x + shift if rear else x - shift
            ny = y - (lift if rear else 0)
            if 0 <= nx < cell.shape[1] and knee <= ny < height:
                out[ny, nx, :] = cell[y, x, :]
    return out


def swap_legs(cell: np.ndarray, gait: WalkCycle) -> np.ndarray:
    """Put the other foot in front, by reflecting the shins about the body axis.

    The two halves of a walk are the same pose with the legs exchanged, and at this size
    the legs are near enough symmetrical -- both are a bare shin and a boot -- that
    reflecting them IS the exchange. It has to happen below the satchel: reflected with
    them, the satchel swaps shoulders halfway through every step.
    """
    out = cell.copy()
    out[gait.swap:, :, :] = out[gait.swap:, ::-1, :]
    return out


def build_walk(cell: Image.Image, gait: WalkCycle) -> list[Image.Image]:
    """One delivered stride, made into a cycle. See WalkCycle for why it is not on the sheet."""
    source = np.asarray(cell.convert("RGBA")).copy()
    half = [close_legs(source, gait.knee, gait.ramp, gait.split, draw, lift)
            for draw, lift in gait.steps]
    frames = half + [swap_legs(f, gait) for f in half]
    return [Image.fromarray(f, "RGBA") for f in frames]


def run_legs(cell: Image.Image, walk: WalkCycle, gait: RunCycle) -> list[Image.Image]:
    """The walk's legs, swung the run's distance rather than the walk's. See RunCycle."""
    source = np.asarray(cell.convert("RGBA")).copy()
    half = [close_legs(source, walk.knee, walk.ramp, walk.split, draw, lift)
            for draw, lift in gait.steps]
    frames = half + [swap_legs(f, walk) for f in half]
    return [Image.fromarray(f, "RGBA") for f in frames]


def build_run(torsos: list[Image.Image], legs: list[Image.Image],
              gait: RunCycle) -> list[Image.Image]:
    """The delivered run above the cut, the borrowed legs below it. See RunCycle."""
    out: list[Image.Image] = []
    for torso, leg in zip(torsos, legs):
        top = np.asarray(torso.convert("RGBA")).copy()
        bottom = np.asarray(leg.convert("RGBA"))
        height, width = top.shape[0], top.shape[1]
        top[gait.cut:, :, :] = 0
        for y in range(gait.cut, height):
            for x in range(width):
                if bottom[y, x, 3] == 0:
                    continue
                moved = x + gait.offset
                if 0 <= moved < width:
                    top[y, moved, :] = bottom[y, x, :]
        out.append(Image.fromarray(top, "RGBA"))
    return out


def build_character(spec: CharacterSheet, write: bool) -> tuple[dict[str, bytes], int, int]:
    sheet = Image.open(spec.source).convert("RGB")
    frames = cut_sheet(spec.source)

    reference = frames[SCALE_REFERENCE]
    base_scale = spec.standing / (reference["box"][3] - reference["box"][1])
    turn = frames[TURNAROUND_REFERENCE]
    turn_scale = spec.standing / (turn["box"][3] - turn["box"][1])
    scales = {"turnaround": turn_scale, "walk": base_scale, "run": base_scale,
              "extra": base_scale}

    # One canvas for every animation, so a texture swap never shifts the character.
    left = right = top = 0.0
    placed: dict[tuple[str, str], tuple[Image.Image, float, float]] = {}
    for key, frame in frames.items():
        factor = scales[frame["panel"]]
        image = scaled(keyed_image(sheet, frame), factor)
        anchor = (frame["anchor_x"] - frame["box"][0]) * factor
        lift = (frame["ground"] - frame["box"][3]) * factor
        placed[key] = (image, anchor, lift)
        left = max(left, anchor)
        right = max(right, image.width - anchor)
        top = max(top, image.height + lift)
    cell_w = int(math.ceil(max(left, right))) * 2 + 2
    cell_h = int(math.ceil(top)) + 2

    def compose(key: tuple[str, str]) -> Image.Image:
        """One frame, on the shared cell, where every strip puts it."""
        image, anchor, lift = placed[key]
        cell = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
        cell.alpha_composite(image, (int(round(cell_w / 2.0 - anchor)),
                                     cell_h - 1 - int(round(image.height + lift))))
        return cell

    written: dict[str, bytes] = {}
    for name, keys in STRIPS:
        # The walk is BUILT rather than cut, because it is not on the sheet -- see WalkCycle.
        # It is made on the shared cell like everything else, so switching to it from any
        # other pose still moves nothing.
        cells = [compose(key) for key in keys]
        if name == "walk" and spec.walk is not None:
            cells = build_walk(compose(spec.walk.source), spec.walk)
        elif name == "run" and spec.run is not None and spec.walk is not None:
            cells = build_run(cells,
                              run_legs(compose(spec.walk.source), spec.walk, spec.run),
                              spec.run)
        strip = Image.new("RGBA", (cell_w * len(cells), cell_h), (0, 0, 0, 0))
        for index, cell in enumerate(cells):
            strip.alpha_composite(cell, (index * cell_w, 0))
        path = CHARACTER_OUT / spec.name / f"{spec.name}_{name}.png"
        written[str(path.relative_to(ROOT))] = _emit(strip, path, write)
    return written, cell_w, cell_h


def build_portrait(spec: CharacterSheet, write: bool) -> tuple[dict[str, bytes], tuple[int, int]]:
    """The big hero drawing, keyed and trimmed, for the dialogue box."""
    sheet = Image.open(spec.source).convert("RGB")
    rgb = np.asarray(sheet.crop(spec.hero), dtype=int)
    solid = fill_from_border(foreground_mask(rgb).copy())
    keyed = keyed_image(sheet, {"box": spec.hero, "mask": solid})
    # Trimmed to the figure. The panel is mostly empty and the drop shadow under the feet
    # is keyed out with the background, so the bbox is the character and nothing else.
    bounds = keyed.getchannel("A").getbbox()
    if bounds is None:
        raise SystemExit(
            f"{spec.source.name}: the hero card keyed to nothing; its `hero` bounds need "
            "re-measuring")
    portrait = keyed.crop(bounds)
    path = CHARACTER_OUT / spec.name / f"{spec.name}_portrait.png"
    return {str(path.relative_to(ROOT)): _emit(portrait, path, write)}, portrait.size


def build_props(write: bool) -> dict[str, bytes]:
    written: dict[str, bytes] = {}
    for filename, name in PROPS:
        image = Image.open(SOURCE / filename).convert("RGBA")
        box = image.split()[-1].getbbox()
        # Trim on the upscale grid, or the downsample would straddle source pixels.
        x0 = box[0] - box[0] % PROP_UPSCALE
        y0 = box[1] - box[1] % PROP_UPSCALE
        x1 = box[2] + (-box[2]) % PROP_UPSCALE
        y1 = box[3] + (-box[3]) % PROP_UPSCALE
        cropped = image.crop((x0, y0, x1, y1))
        native = cropped.resize(
            (cropped.width // PROP_UPSCALE, cropped.height // PROP_UPSCALE), Image.NEAREST)
        # Assert the claim rather than trusting it: if the art is not really 6x, blowing
        # it back up will not reproduce the source and the downsample threw pixels away.
        back = native.resize(cropped.size, Image.NEAREST)
        if not np.array_equal(np.asarray(back), np.asarray(cropped)):
            raise SystemExit(
                f"{filename} is not {PROP_UPSCALE}x pixel art -- downsampling would lose "
                "detail. Ship it at the delivered size instead of guessing a scale.")
        path = PROP_OUT / f"{name}.png"
        written[str(path.relative_to(ROOT))] = _emit(native, path, write)
        if name == "stair_step":
            for band_name, (bx, by, bw, bh) in STAIR_BANDS:
                band = native.crop((bx, by, bx + bw, by + bh))
                if np.asarray(band)[:, :, 3].min() < 255:
                    raise SystemExit(
                        f"{band_name} is not fully opaque -- a tread would show holes "
                        "through it. The band bounds need re-measuring against the art.")
                band = band.resize((bw * BAND_UPSCALE, bh * BAND_UPSCALE), Image.NEAREST)
                band_path = PROP_OUT / f"{band_name}.png"
                written[str(band_path.relative_to(ROOT))] = _emit(band, band_path, write)
    return written


def build_haybale(write: bool) -> tuple[dict[str, bytes], str]:
    """The heap on the terrace, a mouthless copy of it, and the wall inside it."""
    written: dict[str, bytes] = {}
    source = SOURCE / HAYBALE_SOURCE
    if not source.exists():
        raise SystemExit(f"missing {HAYBALE_SOURCE}")
    image = Image.open(source).convert("RGBA")
    pixels = np.asarray(image).astype(int)
    # Delivered on a white page. Keyed on distance from white rather than on brightness:
    # the palest straw in it is within twenty of white and a brightness threshold eats it.
    # SOFT, or the heap keeps a white rind. The page is anti-aliased against the straw, so
    # a hard threshold leaves every edge pixel opaque and one value off white -- a bright
    # halo round a heap standing on a green terrace. Alpha ramps over the same distance
    # instead, which is what the artist's own edge already is.
    flat = pixels[:, :, :3]
    distance = np.abs(flat - 255).max(axis=2)
    alpha = np.clip(distance / 40.0, 0.0, 1.0) * 255.0
    keyed = np.dstack([flat.astype(np.uint8), alpha.astype(np.uint8)])
    cut = Image.fromarray(keyed, "RGBA")
    box = cut.split()[-1].getbbox()

    mouthless = cut.copy()
    patch = cut.crop(HAYBALE_PATCH_FROM).transpose(Image.FLIP_LEFT_RIGHT)
    # FEATHERED, or the patch is a rectangle of slightly brighter straw with four visible
    # sides -- which is what it was, and reads worse than the doorway it was covering. A
    # blurred mask lets the two overlap over thirty pixels, which is longer than any stalk
    # in the picture is wide, so nothing lines up to give the join away.
    mask = Image.new("L", patch.size, 0)
    ImageDraw.Draw(mask).rectangle((34, 34, patch.width - 35, patch.height - 35), fill=255)
    mouthless.paste(patch, HAYBALE_MOUTH[:2],
                    mask.filter(ImageFilter.GaussianBlur(18)))

    for name, art in [("haybale", cut), ("haybale_solid", mouthless)]:
        # BOX, not a filter. This is a five-fold reduction of painted straw; anything
        # sharpening turns every stalk into a fence of alternating pixels.
        small = art.crop(box).resize(HAYBALE_SIZE, Image.BOX)
        path = PROP_OUT / f"{name}.png"
        written[str(path.relative_to(ROOT))] = _emit(small, path, write)

    inside = SOURCE / HAYBALE_INTERIOR_SOURCE
    if not inside.exists():
        raise SystemExit(f"missing {HAYBALE_INTERIOR_SOURCE}")
    strip = Image.open(inside).convert("RGB").crop(HAYBALE_INTERIOR_STRIP)
    width, height = strip.size
    tall = Image.new("RGB",
                     (width, HAYBALE_INTERIOR_ABOVE + height + HAYBALE_INTERIOR_BELOW))
    straw = strip.crop((0, 0, width, HAYBALE_INTERIOR_FLOOR - 140))
    flipped = straw.transpose(Image.FLIP_TOP_BOTTOM)
    y = HAYBALE_INTERIOR_ABOVE
    while y > 0:
        y -= flipped.height
        tall.paste(flipped, (0, y))
    tall.paste(strip, (0, HAYBALE_INTERIOR_ABOVE))
    floor = strip.crop((0, height - 24, width, height))
    y = HAYBALE_INTERIOR_ABOVE + height
    while y < tall.height:
        tall.paste(floor, (0, y))
        y += floor.height
    path = PROP_OUT / "haybale_interior.png"
    written[str(path.relative_to(ROOT))] = _emit(tall, path, write)
    return written, (f"haybale {HAYBALE_SIZE[0]}x{HAYBALE_SIZE[1]}px, "
                     f"interior tile {tall.width}x{tall.height}px with its floor at "
                     f"{HAYBALE_INTERIOR_ABOVE + HAYBALE_INTERIOR_FLOOR}")


def build_paintings(write: bool) -> dict[str, bytes]:
    """The five covers, down to the size they hang at.

    Area-averaged rather than filtered: these come in at 1672x941 and go on a wall at 256
    wide, which is a seven-fold reduction. A sharpening filter at that ratio turns every
    rice terrace into a fence of alternating pixels; averaging keeps the picture reading as
    a picture at a size where none of the detail can survive anyway.
    """
    written: dict[str, bytes] = {}
    for level_id, filename in PAINTINGS:
        source = PAINTING_SOURCE / filename
        if not source.exists():
            raise SystemExit(f"missing painting cover: {filename}")
        image = Image.open(source).convert("RGB").resize(PAINTING_SIZE, Image.BOX)
        path = HUB_OUT / f"{level_id}.png"
        written[str(path.relative_to(ROOT))] = _emit(image, path, write)
    return written


def build_logo(write: bool) -> tuple[dict[str, bytes], tuple[int, int]]:
    """The OBRA wordmark, off its presentation page and back onto its own grid."""
    page = np.asarray(Image.open(LOGO_SOURCE).convert("RGB"), dtype=float)
    height, width, _ = page.shape
    ox, oy = LOGO_PHASE
    mark = np.abs(page - np.array(LOGO_PAGE, dtype=float)).max(axis=2) > LOGO_KEY
    ys, xs = np.where(mark)
    x0 = ox + LOGO_UPSCALE * ((int(xs.min()) - ox) // LOGO_UPSCALE)
    y0 = oy + LOGO_UPSCALE * ((int(ys.min()) - oy) // LOGO_UPSCALE)
    x1 = x0 + LOGO_UPSCALE * ((int(xs.max()) - x0) // LOGO_UPSCALE + 1)
    y1 = y0 + LOGO_UPSCALE * ((int(ys.max()) - y0) // LOGO_UPSCALE + 1)
    crop = page[y0:min(y1, height), x0:min(x1, width)]
    rows, cols = crop.shape[0] // LOGO_UPSCALE, crop.shape[1] // LOGO_UPSCALE
    crop = crop[:rows * LOGO_UPSCALE, :cols * LOGO_UPSCALE]
    blocks = crop.reshape(rows, LOGO_UPSCALE, cols, LOGO_UPSCALE, 3)
    native = np.median(blocks.transpose(0, 2, 1, 3, 4).reshape(rows, cols, -1, 3), axis=2)

    opaque = np.abs(native - np.array(LOGO_PAGE, dtype=float)).max(axis=2) > LOGO_KEY
    flat = native[opaque]
    generator = np.random.default_rng(LOGO_SEED)
    centres = flat[generator.choice(len(flat), LOGO_COLOURS, replace=False)].copy()
    labels = np.zeros(len(flat), dtype=int)
    for _ in range(40):
        labels = ((flat[:, None, :] - centres[None, :, :]) ** 2).sum(axis=2).argmin(axis=1)
        for index in range(LOGO_COLOURS):
            chosen = labels == index
            if chosen.any():
                centres[index] = flat[chosen].mean(axis=0)
    native[opaque] = np.rint(centres[labels])

    out = np.dstack([native, (opaque * 255).astype(float)]).astype(np.uint8)
    image = Image.fromarray(out, "RGBA")
    image = image.crop(image.split()[-1].getbbox())
    path = UI_OUT / "obra_logo.png"
    return {str(path.relative_to(ROOT)): _emit(image, path, write)}, image.size


def _emit(image: Image.Image, path: Path, write: bool) -> bytes:
    import io
    buffer = io.BytesIO()
    image.save(buffer, "PNG", optimize=True)
    data = buffer.getvalue()
    if write:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    return data


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="fail if the committed files differ from a fresh build")
    args = parser.parse_args()

    everything: dict[str, bytes] = {}
    figures: list[str] = []
    for spec in SHEETS:
        character, cell_w, cell_h = build_character(spec, write=not args.check)
        portrait, portrait_size = build_portrait(spec, write=not args.check)
        everything.update(character)
        everything.update(portrait)
        figures.append(
            f"{spec.name}: cell {cell_w}x{cell_h}px at {spec.standing:.0f}px standing, "
            f"portrait {portrait_size[0]}x{portrait_size[1]}px")

    props = build_props(write=not args.check)
    logo, logo_size = build_logo(write=not args.check)
    paintings = build_paintings(write=not args.check)
    haybale, haybale_note = build_haybale(write=not args.check)
    everything.update({**props, **logo, **paintings, **haybale})
    figures.append(haybale_note)

    if args.check:
        stale = []
        for rel, data in everything.items():
            path = ROOT / rel
            if not path.exists() or path.read_bytes() != data:
                stale.append(rel)
        if stale:
            print("stale, re-run tools/build_art.py:")
            for rel in stale:
                print("   ", rel)
            return 1
        print(f"art is up to date ({len(everything)} files)")
        return 0

    for line in figures:
        print(line)
    print(f"wordmark {logo_size[0]}x{logo_size[1]}px native")
    for rel in sorted(everything):
        print(f"   {len(everything[rel]):7d}  {rel}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
