#!/usr/bin/env python3
"""Cut LEVEL4_Mt.Makiling/ into game/assets/Level4/ -- Dilim's art pipeline.

WHY THIS EXISTS
---------------
The Makiling delivery is 1672x941 parallax plates like Dagat's, but exported WITHOUT alpha: the
"transparent" parts are a grey-and-white checkerboard painted into the pixels, and the two
ground strips sit on flat off-white. So before anything else every layer has to be keyed.

A CHECKERBOARD IS NOT KEYED BY THRESHOLD. The clouds on BG_Mountain are white, and where a cloud
touches a white square of the checker the two are the same colour -- a "make near-white
transparent" pass punches the cloud tops out, and a looser one eats the fog. What tells them
apart is the GRID: a square of checker is a whole square of one flat colour with squares of the
other colour beside it, and a cloud is not. So:

1. The checker's real grid is measured off a stretch of the plate that is only checker. Its
   pitch is not a whole number (29.9 px on BG_Mountain -- the export was resampled), so the
   grid is fitted, not assumed.
2. A cell is background if nearly every pixel in it is that cell's checker colour.
3. Background cells are flooded from the plate's border: only a cell reachable through other
   background cells counts. A white square inside a cloud is surrounded by cloud, and a cloud
   never lines up with the grid, so the cells around its edge are never clean -- the flood
   cannot get in.
4. Only the cells on the boundary, beside a flooded cell, are keyed pixel by pixel, and only
   pixels joined to the flood: whatever a mistake costs, it costs inside one cell.
5. The pale fringe the checker leaves on dark edges is taken off.

The flat-backed strips are keyed the same way without the grid: a pixel flood from the border
through the page colour.

THREE RULES, as tools/build_dagat.py has them:
- PLATES ARE NEVER TRIMMED. They are registered to each other by their margins.
- EVERY DELIVERED FILE IS CLAIMED: cut by a rule here, or named as reference only.
- --check compares PIXELS and writes nothing.

USAGE
    python3 tools/build_dilim.py            # write game/assets/Level4/backdrop/
    python3 tools/build_dilim.py --check    # verify the committed files are current
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))

import pixelart  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "LEVEL4_Mt.Makiling"
OUT = ROOT / "game" / "assets" / "Level4" / "backdrop"
PLATE = (1672, 941)

## Every plate, by the name the game uses, and how it is keyed. Back to front.
PLATES: dict[str, tuple[str, str]] = {
    "sky": ("BG_Sky.png", "opaque"),
    "mountain_far": ("BG_Mountain.png", "checker"),
    "mountain_near": ("BG_Mountain2.png", "checker"),
    "ground_far": ("FG_Ground2.png", "flat"),
    "ground_near": ("FG_Ground.png", "flat"),
    "frame": ("FG_Details.png", "checker"),
}
## Delivered for the eye, not the engine: the composed look and the mockup it came from.
REFERENCE_ONLY = {"Level4_CompletedLook.png", "ChatGPT Image Aug 14, 2026, 04_46_26 PM.png"}
NOT_YET_CUT: set[str] = set()

## THE TILESET'S SEAMLESS TEXTURES, one per section of TextureMap_Makiling: the section's box,
## measured by hand off the sheet, and which of its tiles to take. Each tile sits on the sheet's
## cream page with its own dark outline, so it is found as a square of not-page inside the box
## and cut INSIDE the outline -- tiled as drawn, the outline is a grid of seams.
TILESET = "TextureMap_Makiling.png"
TILES: dict[str, tuple[tuple[int, int, int, int], int]] = {
    "leaf": ((5, 80, 410, 270), 0),      # 1) jungle canopy / leaf ground cover (top surface)
    "mud": ((420, 80, 740, 270), 1),     # 2) mud / dirt wall
    "stone": ((745, 80, 1095, 270), 0),  # 3) mossy stone retaining wall
    "path": ((1100, 80, 1445, 270), 0),  # 4) forest path / packed earth
}
TILE_OUT = ROOT / "game" / "assets" / "Level4" / "tiles"
## How far inside a tile's found square its outline ends.
TILE_INSET = 7

## THE CLOUDS, measured by hand off the plates (x0, y0, x1, y1), with room around each. They are
## the only white art on a checker plate, and only inside these does the flood go cell by cell by
## the checker's own pattern; everywhere else any checker grey joined to the flood is background.
CLOUDS: dict[str, list[tuple[int, int, int, int]]] = {
    "BG_Mountain.png": [(530, 190, 810, 340), (930, 200, 1210, 350), (310, 350, 450, 430),
                        (1170, 370, 1370, 460)],
    "BG_Mountain2.png": [(980, 60, 1330, 190), (320, 180, 520, 270), (1270, 200, 1460, 290)],
}

## How far a pixel may stray from a checker grey and still be it: the export left a few levels of
## noise on both, and its greys are not quite neutral.
LEVEL_TOL = 5
## How much of a cell's interior must be one grey for the cell to be background.
CLEAN_CELL = 0.95
## How far in from a cell's measured edge its interior starts.
MARGIN = 3
## How far from the page colour a flat-backed strip's background may stray.
PAGE_TOL = 6
## A pixel this close to background and this near the checker's colours is fringe, not art.
FRINGE_REACH = 2
FRINGE_TOL = 40
## Opaque crumbs smaller than this, left by the key, go.
CRUMB = 24
## An opaque island this much flat checker grey is leftover checker, not art -- up to this size.
ISLAND_GREY = 0.97
ISLAND_MAX = 12000


def load(name: str) -> np.ndarray:
    path = SRC / name
    if not path.exists():
        raise SystemExit(f"missing delivered art: {path}")
    return np.asarray(Image.open(path).convert("RGB")).astype(np.int16)


def neutral(rgb: np.ndarray) -> np.ndarray:
    return (rgb.max(axis=-1) - rgb.min(axis=-1)) <= 4


# --- the checker --------------------------------------------------------------------------

def checker_levels(rgb: np.ndarray) -> tuple[int, int]:
    """The checker's two greys, read off the plate's border."""
    border = np.concatenate([rgb[:4].reshape(-1, 3), rgb[-4:].reshape(-1, 3),
                             rgb[:, :4].reshape(-1, 3), rgb[:, -4:].reshape(-1, 3)])
    light = border[neutral(border) & (border.mean(axis=1) >= 200)]
    values, counts = np.unique(light[:, 0], return_counts=True)
    top = values[np.argsort(counts)[::-1]]
    first = int(top[0])
    second = next(int(v) for v in top[1:] if abs(int(v) - first) >= 6)
    return min(first, second), max(first, second)


def grey_class(rgb: np.ndarray, lo: int, hi: int) -> np.ndarray:
    """0 where a pixel is the checker's darker grey, 1 where its lighter, -1 where neither."""
    level = rgb.mean(axis=-1)
    flat = (rgb.max(axis=-1) - rgb.min(axis=-1)) <= LEVEL_TOL
    out = np.full(rgb.shape[:2], -1, np.int8)
    out[flat & (np.abs(level - lo) <= LEVEL_TOL)] = 0
    out[flat & (np.abs(level - hi) <= LEVEL_TOL)] = 1
    return out


def grid_lines(classes: np.ndarray, axis: int) -> np.ndarray:
    """Where the checker's cells meet along one axis, measured rather than assumed: every place
    a line across the plate flips from one grey to the other, piled up, with the gaps the art
    covers filled at the measured pitch. The export was resampled, so the pitch is not a whole
    number and is not the same across and down -- one fitted line drifts by cells."""
    lines = classes if axis == 1 else classes.T
    width = lines.shape[1]
    votes = np.zeros(width, int)
    for row in lines[::3]:
        a, b = row[:-1], row[1:]
        flips = np.nonzero((a >= 0) & (b >= 0) & (a != b))[0] + 1
        votes[flips] += 1
    strong = np.nonzero(votes >= max(3, votes.max() * 0.15))[0]
    if strong.size < 4:
        raise SystemExit("too little checker to measure its grid")
    # Neighbouring columns are one line, a pixel of jitter apart.
    merged: list[float] = []
    group = [strong[0]]
    for x in strong[1:]:
        if x - group[-1] <= 2:
            group.append(x)
        else:
            merged.append(float(np.average(group, weights=votes[group])))
            group = [x]
    merged.append(float(np.average(group, weights=votes[group])))
    pitch = float(np.median(np.diff(merged)))
    filled = [merged[0]]
    for x in merged[1:]:
        while x - filled[-1] > pitch * 1.5:
            filled.append(filled[-1] + pitch)
        filled.append(x)
    while filled[0] - pitch > 0:
        filled.insert(0, filled[0] - pitch)
    while filled[-1] + pitch < width:
        filled.append(filled[-1] + pitch)
    return np.array(filled)


def checker_key(rgb: np.ndarray, clouds: list[tuple[int, int, int, int]] | None = None
                ) -> np.ndarray:
    """Background mask for a plate on a painted checkerboard (True = background)."""
    lo, hi = checker_levels(rgb)
    classes = grey_class(rgb, lo, hi)
    h, w = classes.shape
    xs = grid_lines(classes, 1)
    ys = grid_lines(classes, 0)
    cell_x = np.searchsorted(xs, np.arange(w) + 0.5)
    cell_y = np.searchsorted(ys, np.arange(h) + 0.5)
    ncx, ncy = int(cell_x.max()) + 1, int(cell_y.max()) + 1
    grid_x, grid_y = np.meshgrid(cell_x, cell_y)
    cell_id = grid_y * ncx + grid_x
    # Judged on its interior: a pixel of jitter at a cell's edge belongs to its neighbour.
    edge_x = np.minimum(np.abs(np.arange(w)[None, :] - xs[np.clip(cell_x - 1, 0, len(xs) - 1)][None, :]),
                        np.abs(xs[np.clip(cell_x, 0, len(xs) - 1)][None, :] - np.arange(w)[None, :]))
    edge_y = np.minimum(np.abs(np.arange(h)[:, None] - ys[np.clip(cell_y - 1, 0, len(ys) - 1)][:, None]),
                        np.abs(ys[np.clip(cell_y, 0, len(ys) - 1)][:, None] - np.arange(h)[:, None]))
    interior = (edge_x >= MARGIN) & (edge_y >= MARGIN)
    ids = np.arange(ncx * ncy)

    def one_grey_share(region: np.ndarray) -> np.ndarray:
        count = np.asarray(ndimage.sum(region, labels=cell_id, index=ids))
        dark = np.asarray(ndimage.sum(region & (classes == 0), labels=cell_id, index=ids))
        light = np.asarray(ndimage.sum(region & (classes == 1), labels=cell_id, index=ids))
        return np.maximum(dark, light) / np.maximum(count, 1), count

    share, inner = one_grey_share(interior)
    # ⚠ THE PLATE'S EDGE CUTS CELLS INTO SLIVERS. The grid does not start at pixel 0, so the cells
    # along every edge can be a few pixels wide -- too thin to have an interior at all -- and those
    # are exactly the cells the flood starts from. A sliver is judged on all of its pixels.
    whole, _ = one_grey_share(np.ones_like(interior))
    share = np.where(inner >= 9, share, whole)
    clean_cells = (share >= CLEAN_CELL).reshape(ncy, ncx)
    # Which grey each clean cell is.
    region = np.where(inner >= 9, 1, 0)
    dark_n = np.asarray(ndimage.sum((classes == 0) & (interior | (region[cell_id] == 0)),
                                    labels=cell_id, index=ids))
    light_n = np.asarray(ndimage.sum((classes == 1) & (interior | (region[cell_id] == 0)),
                                     labels=cell_id, index=ids))
    grey = (light_n > dark_n).reshape(ncy, ncx)
    # ⚠ A CHECKER SQUARE HAS A SQUARE OF THE OTHER GREY BESIDE IT. That is the test, not "can it be
    # reached from the border": the frame's vines close off pockets of checker the border flood
    # never reaches, and a white square inside a cloud is ringed by cloud, never by grey.
    beside = np.zeros_like(clean_cells)
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        other = np.zeros_like(clean_cells)
        other_grey = np.zeros_like(grey)
        ys0, ys1 = max(dy, 0), ncy + min(dy, 0)
        xs0, xs1 = max(dx, 0), ncx + min(dx, 0)
        other[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx] = clean_cells[ys0:ys1, xs0:xs1]
        other_grey[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx] = grey[ys0:ys1, xs0:xs1]
        beside |= other & (other_grey != grey)
    flooded = clean_cells & beside
    # From there, pixel by pixel through checker that is the grey its cell's place in the checker
    # says it should be -- however many mixed cells that crosses. A cloud's white can carry the
    # flood into the white cells along its edge but never across a grey one, so whatever a cloud
    # loses, it loses inside the light cells it touches.
    # ⚠ WHICH GREY A CELL SHOULD BE IS READ LOCALLY. Where art hides the checker for a long way,
    # filling the gap at the measured pitch can gain or lose a line, and every cell past it swaps
    # greys -- a global parity keyed one grey and left the other as a grid of white squares. So
    # each patch of clean cells says which way round it is, and a cell borrows the nearest's.
    cell_parity = (np.arange(ncx)[None, :] + np.arange(ncy)[:, None]) % 2
    patches, count = ndimage.label(clean_cells, structure=np.ones((3, 3), bool))
    flip = (cell_parity ^ grey.astype(int)).astype(float)
    if count:
        votes = np.asarray(ndimage.mean(flip, labels=patches, index=np.arange(1, count + 1)))
        patch_flip = np.concatenate([[0], np.round(votes)]).astype(int)
        _, (near_y, near_x) = ndimage.distance_transform_edt(~clean_cells, return_indices=True)
        cell_flip = patch_flip[patches[near_y, near_x]]
    else:
        cell_flip = np.zeros_like(cell_parity)
    expected = (cell_parity ^ cell_flip)[grid_y, grid_x]
    # ⚠ AND THROUGH THE SEAMS. The resampled export blends the two greys along every cell edge into
    # a grey that is neither; on a grid line, any flat grey between the two carries the flood.
    level = rgb.mean(axis=-1)
    # Strictly BETWEEN the greys: a cloud's own white on a grid line is not a seam, and counting it
    # as one let the flood cross a grey cell along the line and into the cloud.
    seam = ((rgb.max(axis=-1) - rgb.min(axis=-1)) <= LEVEL_TOL) \
        & (level > lo + 2) & (level < hi - 2) & ((edge_x <= 2) | (edge_y <= 2))
    seeds = flooded[grid_y, grid_x] & interior & (classes >= 0)
    protected = np.zeros(classes.shape, bool)
    for x0, y0, x1, y1 in clouds or []:
        protected[y0:y1, x0:x1] = True
    passable = np.where(protected, (classes == expected) | seam, (classes >= 0) | seam)
    joined, _ = ndimage.label(passable)
    keep = np.unique(joined[seeds])
    return np.isin(joined, keep[keep > 0])


# --- the flat page ------------------------------------------------------------------------

def flat_key(rgb: np.ndarray) -> np.ndarray:
    """Background mask for a strip on a flat off-white page: the page colour, from the border."""
    border = np.concatenate([rgb[:3].reshape(-1, 3), rgb[-3:].reshape(-1, 3)])
    page = np.median(border, axis=0)
    near = neutral(rgb) & (np.abs(rgb - page).max(axis=-1) <= PAGE_TOL)
    labels, _ = ndimage.label(near)
    edge = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    return np.isin(labels, edge[edge > 0])


# --- the edge -----------------------------------------------------------------------------

def without_fringe(rgb: np.ndarray, background: np.ndarray, colours: list[int]) -> np.ndarray:
    """Take off the pale rim the key leaves: pixels next to background that are still nearly
    the background's colour. Then drop crumbs too small to be art."""
    reach = ndimage.binary_dilation(background, iterations=FRINGE_REACH) & ~background
    pale = np.zeros(background.shape, bool)
    for grey in colours:
        pale |= (np.abs(rgb - grey).max(axis=-1) <= FRINGE_TOL)
    background = background | (reach & pale)
    solid, count = ndimage.label(~background)
    if count:
        sizes = ndimage.sum(np.ones_like(solid), solid, index=np.arange(1, count + 1))
        crumbs = np.isin(solid, np.arange(1, count + 1)[np.asarray(sizes) < CRUMB])
        background = background | crumbs
    return background


def without_checker_islands(rgb: np.ndarray, background: np.ndarray, lo: int,
                            hi: int) -> np.ndarray:
    """Leftover checker the flood could not reach -- a square cut off by keyed seams on every
    side, a block caught between a cloud and a hill -- goes: an island of opaque pixels that is
    nearly all flat checker grey is not art. A cloud carries its blue shading with it, so no
    cloud is ever that grey; the size cap keeps anything large out of it regardless."""
    level = rgb.mean(axis=-1)
    grey = ((rgb.max(axis=-1) - rgb.min(axis=-1)) <= LEVEL_TOL) \
        & (level >= lo - LEVEL_TOL) & (level <= hi + LEVEL_TOL)
    islands, count = ndimage.label(~background)
    if not count:
        return background
    ids = np.arange(1, count + 1)
    share = np.asarray(ndimage.mean(grey, labels=islands, index=ids))
    size = np.asarray(ndimage.sum(np.ones_like(islands), labels=islands, index=ids))
    drop = ids[(share >= ISLAND_GREY) & (size <= ISLAND_MAX)]
    return background | np.isin(islands, drop)


def keyed(name: str, method: str) -> Image.Image:
    rgb = load(name)
    if rgb.shape[:2] != (PLATE[1], PLATE[0]):
        raise SystemExit(f"{name} is {rgb.shape[1]}x{rgb.shape[0]}, not the {PLATE} plate")
    if method == "opaque":
        return Image.fromarray(rgb.astype(np.uint8), "RGB").convert("RGBA")
    if method == "checker":
        lo, hi = checker_levels(rgb)
        background = without_fringe(rgb, checker_key(rgb, CLOUDS.get(name)), [lo, hi])
        background = without_checker_islands(rgb, background, lo, hi)
    else:
        page = int(np.median(np.concatenate([rgb[:3].reshape(-1, 3), rgb[-3:].reshape(-1, 3)])))
        background = without_fringe(rgb, flat_key(rgb), [page])
    alpha = np.where(background, 0, 255).astype(np.uint8)
    out = np.dstack([rgb.astype(np.uint8), alpha])
    out[background] = 0
    return Image.fromarray(out, "RGBA")


def tile(name: str) -> Image.Image:
    """One seamless texture off the tileset: the chosen square in its section, inside its outline."""
    (x0, y0, x1, y1), index = TILES[name]
    sheet = load(TILESET)
    page = np.median(sheet[5:30, 5:200].reshape(-1, 3), axis=0)
    not_page = np.abs(sheet[y0:y1, x0:x1] - page).max(axis=-1) > 24
    labels, _ = ndimage.label(not_page)
    squares = []
    for box in ndimage.find_objects(labels):
        h, w = box[0].stop - box[0].start, box[1].stop - box[1].start
        if 45 <= w <= 80 and 45 <= h <= 80:
            squares.append((box[0].start + y0, box[1].start + x0, h, w))
    squares.sort(key=lambda sq: (sq[0] // 40, sq[1]))
    if index >= len(squares):
        raise SystemExit(f"tileset section {name!r} has {len(squares)} tiles, not {index + 1}")
    y, x, h, w = squares[index]
    inner = sheet[y + TILE_INSET:y + h - TILE_INSET, x + TILE_INSET:x + w - TILE_INSET]
    return Image.fromarray(inner.astype(np.uint8), "RGB").convert("RGBA")


def delivered() -> set[str]:
    return {p.name for p in SRC.glob("*.png")}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="compare, do not write")
    args = ap.parse_args()
    claimed = {source for source, _ in PLATES.values()} | REFERENCE_ONLY | NOT_YET_CUT | {TILESET}
    orphans = sorted(delivered() - claimed)
    if orphans:
        print("ERROR: delivered art nothing claims: " + ", ".join(orphans), file=sys.stderr)
        return 1
    pictures = pixelart.Pictures(args.check, ROOT)
    for plate, (source, method) in PLATES.items():
        pictures.put(keyed(source, method), OUT / f"{plate}.png")
    for name in TILES:
        pictures.put(tile(name), TILE_OUT / f"{name}.png")
    if args.check:
        if pictures.stale:
            print("stale or missing:\n  " + "\n  ".join(pictures.stale))
            return 1
        print(f"OK: {len(PLATES)} Makiling plates and {len(TILES)} tiles are current")
        return 0
    print(f"wrote {len(PLATES)} plates and {len(TILES)} tiles under game/assets/Level4/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
