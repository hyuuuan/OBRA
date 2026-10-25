#!/usr/bin/env python3
"""Cut LEVEL5_Mayon/ into game/assets/Level5/ -- Mayon's art pipeline.

WHY THIS EXISTS
---------------
The Mayon delivery is drawn and exported the way Makiling's was: 1672x941 parallax plates with
the "transparent" parts a grey-and-white checkerboard painted into the pixels. So the plates are
keyed by tools/build_dilim.py's grid key -- measured checker cells, flooded from clean cells that
have a cell of the other grey beside them, never a threshold. Read its header for why.

THREE THINGS MAKILING DID NOT HAVE, and the passes they need:

1. POCKETS SEALED INSIDE THE ART. The bell tower's bell hangs in a window whose checker is cut
   into slivers by the bell, its yoke and the arch; the meadow's right-hand palm closes a pocket
   between its fronds and the bushes. No cell in there is clean, so the grid flood never starts.
   A pocket is still recognisable without the grid: a patch of near-neutral pale pixels, most of
   it the checker's own greys -- and holding some of EACH grey, because the meadow's petals are
   pure white too and sit inside its grass. The plume's notches and the palms' fronds seal
   pockets as small as ten pixels, blended by the resampled export.
2. SPECKS IN NOTCHES. Where the plume's edge turns sharply, a pixel or two of checker -- blended
   pale by the resampled export -- sits a step further from the flood than the fringe pass
   reaches. A pixel that pale within a few pixels of background is checker; the plume's own
   highlights are yellow, nowhere near a grey.

3. A PALE RIM. The resampled export blended every silhouette's outermost pixel toward the checker
   white -- a light line along the volcano's flank and round every frond, too coloured for the
   fringe pass, which only takes near-grey. Those pixels are art in the wrong colour, not
   background: deleting them would shrink every shape by a pixel, so they are repainted with the
   colour of the art just inside them. A rim pixel is pale when it is much lighter and greyer
   than its inside; a sunlit edge is lighter but keeps its colour.

THE TILESET IS ON A DARK PAGE, not a checker. Its seamless textures are cut inside each tile's
outline (tiled as drawn, an outline is a grid of seams); its props are keyed by flooding the page
colour in from the edge of each prop's box, so a dark outline the page touches only at a corner
stays.

THE RULES, as tools/build_dilim.py and tools/build_dagat.py have them:
- PLATES ARE NEVER TRIMMED. They are registered to each other by their margins.
- EVERY DELIVERED FILE IS CLAIMED: cut by a rule here, or named as reference only.
- --check compares PIXELS and writes nothing.

USAGE
    python3 tools/build_mayon.py            # write game/assets/Level5/
    python3 tools/build_mayon.py --check    # verify the committed files are current
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
from build_dilim import (FRINGE_TOL, LEVEL_TOL, checker_key, checker_levels,  # noqa: E402
                         grey_class, without_checker_islands, without_fringe)

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "LEVEL5_Mayon"
OUT = ROOT / "game" / "assets" / "Level5"
PLATE = (1672, 941)

## Every plate, by the name the game uses, and how it is keyed. Back to front.
PLATES: dict[str, tuple[str, str]] = {
    "sky": ("BG_Sky.png", "opaque"),
    "volcano": ("BG_Volcano.png", "checker"),
    "meadow": ("MG_Meadow.png", "checker"),
    "ground": ("FG_Ground.png", "checker"),
}
## Pictures on the checker that are a thing, not a plate: keyed the same way, then trimmed to the
## art and reduced -- the tower is delivered at 1122x1402, taller than the whole screen.
KEYED_PROPS: dict[str, tuple[str, int]] = {
    "bell_tower": ("Prop_BellTower.png", 3),
}
## Delivered for the eye, not the engine: the composed look (the hub's Mayon painting is cut from
## its copy in Painting_Covers/ by tools/build_art.py).
REFERENCE_ONLY = {"Mayon_CompletedLook.png"}

## THE TILESET: boxes (x, y, w, h) measured by hand off TextureMap_Mayon, each around one tile.
TILESET = "TextureMap_Mayon.png"
TILES: dict[str, tuple[int, int, int, int]] = {
    "soil": (470, 130, 56, 56),      # 2) volcanic soil / rock wall: the first square
    "path": (923, 129, 50, 54),      # 3) path tiles: a plain square of packed earth
    "masonry": (1013, 240, 54, 44),  # 4) ruined stone masonry: one block of coursed stone
}
## How far inside a tile's box its outline ends.
TILE_INSET = 5
## The grass that tops the ground, off section 1's first strip: the grass and the drips under it,
## its rounded ends cut off so it can repeat.
GRASS: tuple[int, int, int, int] = (40, 131, 100, 24)
## Props off section 9 (and two floating ground pieces off section 7), each box with room round it.
SHEET_PROPS: dict[str, tuple[int, int, int, int]] = {
    "rock_big": (625, 569, 86, 52),
    "rock_mid": (719, 569, 47, 50),
    "rock_low": (773, 574, 52, 41),
    "fern": (946, 557, 50, 37),
    "fern_wide": (1004, 550, 63, 44),
    "flowers_white": (943, 603, 49, 50),
    "flowers_orange": (998, 603, 49, 50),
    "palm": (1160, 518, 103, 199),
    "palm_short": (1109, 599, 77, 118),
    "ruin_pillar": (1237, 594, 60, 123),
    "ruin_stub": (1308, 644, 42, 73),
    "vine": (1290, 518, 48, 130),
    "island_wide": (22, 568, 137, 93),
    "island_small": (258, 576, 77, 52),
}

## How far from the page colour the dark sheet's background may stray.
PAGE_TOL = 9
## Prop crumbs smaller than this go.
PROP_CRUMB = 6
## A sealed pocket of checker: at least this many near-neutral pale pixels, at least this share
## of them exactly a checker grey, and some of each grey.
POCKET_MIN = 10
POCKET_GREY = 0.25
POCKET_EACH = 0.05
## How far from neutral, and how far under the checker's darker grey, a pocket's pixels may be.
POCKET_TINT = 12
POCKET_UNDER = 10
## How near background a pixel as pale as the checker must be to count as a speck of it.
SPECK_REACH = 4
## A rim pixel is pale when it is this much lighter than the art inside it, and has at most this
## share of that art's colour; it is judged against the art within RIM_REACH px.
RIM_LIGHTER = 25.0
RIM_COLOUR = 0.8
RIM_REACH = 5


def load(name: str) -> np.ndarray:
    path = SRC / name
    if not path.exists():
        raise SystemExit(f"missing delivered art: {path}")
    return np.asarray(Image.open(path).convert("RGB")).astype(np.int16)


# --- the two passes Makiling did not need -------------------------------------------------

def without_pockets(rgb: np.ndarray, background: np.ndarray, lo: int, hi: int) -> np.ndarray:
    """Checker sealed inside the art: a patch of pale, near-neutral pixels, mostly checker grey."""
    classes = grey_class(rgb, lo, hi)
    level = rgb.mean(axis=-1)
    pale = ((rgb.max(axis=-1) - rgb.min(axis=-1)) <= POCKET_TINT) & (level >= lo - POCKET_UNDER)
    patches, count = ndimage.label(pale & ~background)
    if not count:
        return background
    ids = np.arange(1, count + 1)
    size = np.asarray(ndimage.sum(np.ones_like(patches), labels=patches, index=ids))
    dark = np.asarray(ndimage.sum(classes == 0, labels=patches, index=ids))
    light = np.asarray(ndimage.sum(classes == 1, labels=patches, index=ids))
    pocket = (size >= POCKET_MIN) & (dark + light >= POCKET_GREY * size) \
        & (dark >= POCKET_EACH * size) & (light >= POCKET_EACH * size)
    return background | np.isin(patches, ids[pocket])


def without_specks(rgb: np.ndarray, background: np.ndarray, lo: int, hi: int) -> np.ndarray:
    """Checker-pale pixels a few pixels from background are checker the flood stopped short of."""
    pale = (np.abs(rgb - lo).max(axis=-1) <= FRINGE_TOL) | (np.abs(rgb - hi).max(axis=-1) <= FRINGE_TOL)
    for _ in range(2):
        near = ndimage.binary_dilation(background, iterations=SPECK_REACH) & ~background
        background = background | (near & pale)
    return background


def checker_background(rgb: np.ndarray) -> np.ndarray:
    lo, hi = checker_levels(rgb)
    background = without_fringe(rgb, checker_key(rgb, []), [lo, hi])
    background = without_checker_islands(rgb, background, lo, hi)
    background = without_pockets(rgb, background, lo, hi)
    background = without_specks(rgb, background, lo, hi)
    # The pockets leave the same pale rim the flood does.
    return without_fringe(rgb, background, [lo, hi])


def without_pale_rim(rgb: np.ndarray, background: np.ndarray) -> np.ndarray:
    """The silhouette's outermost pixels, blended toward the checker's white by the export,
    repainted with the colour of the art just inside them."""
    rim = ~background & ndimage.binary_dilation(background)
    inner = (~background & ~rim).astype(float)
    weight = ndimage.uniform_filter(inner, RIM_REACH)
    near = weight > 0.02
    lum = rgb @ np.array([0.2126, 0.7152, 0.0722])
    sat = (rgb.max(axis=-1) - rgb.min(axis=-1)).astype(float)
    mean = lambda values: ndimage.uniform_filter(values * inner, RIM_REACH) / np.maximum(weight, 1e-6)
    pale = rim & near & (lum - mean(lum) > RIM_LIGHTER) & (sat < mean(sat) * RIM_COLOUR)
    out = rgb.copy()
    for channel in range(3):
        out[..., channel] = np.where(pale, np.round(mean(rgb[..., channel].astype(float))),
                                     rgb[..., channel])
    return out


def with_alpha(rgb: np.ndarray, background: np.ndarray) -> Image.Image:
    out = np.dstack([rgb.astype(np.uint8), np.where(background, 0, 255).astype(np.uint8)])
    out[background] = 0
    return Image.fromarray(out, "RGBA")


def keyed(name: str, method: str) -> Image.Image:
    rgb = load(name)
    if rgb.shape[:2] != (PLATE[1], PLATE[0]):
        raise SystemExit(f"{name} is {rgb.shape[1]}x{rgb.shape[0]}, not the {PLATE} plate")
    if method == "opaque":
        return Image.fromarray(rgb.astype(np.uint8), "RGB").convert("RGBA")
    background = checker_background(rgb)
    return with_alpha(without_pale_rim(rgb, background), background)


# --- things, not plates --------------------------------------------------------------------

def trimmed(image: Image.Image) -> Image.Image:
    box = image.getchannel("A").getbbox()
    return image.crop(box) if box else image


def reduced(image: Image.Image, factor: int) -> Image.Image:
    """Down by a whole factor, averaging premultiplied colour so no dark rim bleeds in from the
    keyed-out pixels, and padded first so every block is whole."""
    w, h = image.size
    pw, ph = -w % factor, -h % factor
    padded = Image.new("RGBA", (w + pw, h + ph), (0, 0, 0, 0))
    padded.paste(image, (pw // 2, ph))
    pix = np.asarray(padded).astype(np.float64)
    alpha = pix[..., 3:4] / 255.0
    pre = np.concatenate([pix[..., :3] * alpha, alpha], axis=-1)
    hh, ww = pre.shape[0] // factor, pre.shape[1] // factor
    blocks = pre.reshape(hh, factor, ww, factor, 4).mean(axis=(1, 3))
    a = blocks[..., 3:4]
    colour = np.where(a > 0, blocks[..., :3] / np.maximum(a, 1e-9), 0.0)
    # Pixel art keeps hard edges: a block is either there or not.
    solid = (a[..., 0] >= 0.5)
    out = np.dstack([np.clip(np.round(colour), 0, 255), np.where(solid, 255, 0)]).astype(np.uint8)
    out[~solid] = 0
    return Image.fromarray(out, "RGBA")


def keyed_prop(name: str, factor: int) -> Image.Image:
    rgb = load(name)
    background = checker_background(rgb)
    return trimmed(reduced(with_alpha(without_pale_rim(rgb, background), background), factor))


def sheet() -> tuple[np.ndarray, np.ndarray]:
    rgb = load(TILESET)
    page = np.median(rgb[5:30, 600:700].reshape(-1, 3), axis=0)
    return rgb, page


def tile(name: str) -> Image.Image:
    """One seamless texture off the tileset, inside its outline."""
    x, y, w, h = TILES[name]
    rgb, _ = sheet()
    inner = rgb[y + TILE_INSET:y + h - TILE_INSET, x + TILE_INSET:x + w - TILE_INSET]
    return Image.fromarray(inner.astype(np.uint8), "RGB").convert("RGBA")


def page_background(box: np.ndarray, page: np.ndarray, one_piece: bool = False) -> np.ndarray:
    """The page, flooded in from the box's edge. `one_piece` keeps only the biggest shape: the
    sheet packs its props close, and a box with room round a palm catches a vine's leaf and the
    corner of a ruin."""
    near = np.abs(box - page).max(axis=-1) <= PAGE_TOL
    labels, _ = ndimage.label(near)
    edge = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    background = np.isin(labels, edge[edge > 0])
    solid, count = ndimage.label(~background, structure=np.ones((3, 3), bool))
    if count:
        sizes = np.asarray(ndimage.sum(np.ones_like(solid), solid, index=np.arange(1, count + 1)))
        ids = np.arange(1, count + 1)
        drop = ids[ids != ids[np.argmax(sizes)]] if one_piece else ids[sizes < PROP_CRUMB]
        background |= np.isin(solid, drop)
    return background


def sheet_prop(name: str) -> Image.Image:
    x, y, w, h = SHEET_PROPS[name]
    rgb, page = sheet()
    box = rgb[y:y + h, x:x + w]
    return trimmed(with_alpha(box, page_background(box, page, one_piece=True)))


def grass() -> Image.Image:
    """The ground's top: grass and its drips, keyed off the page below the drips."""
    x, y, w, h = GRASS
    rgb, page = sheet()
    box = rgb[y:y + h, x:x + w]
    return with_alpha(box, page_background(box, page))


def delivered() -> set[str]:
    return {p.name for p in SRC.glob("*.png")}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="compare, do not write")
    args = ap.parse_args()
    claimed = ({source for source, _ in PLATES.values()} | {s for s, _ in KEYED_PROPS.values()}
               | REFERENCE_ONLY | {TILESET})
    orphans = sorted(delivered() - claimed)
    if orphans:
        print("ERROR: delivered art nothing claims: " + ", ".join(orphans), file=sys.stderr)
        return 1
    pictures = pixelart.Pictures(args.check, ROOT)
    for plate, (source, method) in PLATES.items():
        pictures.put(keyed(source, method), OUT / "backdrop" / f"{plate}.png")
    for prop, (source, factor) in KEYED_PROPS.items():
        pictures.put(keyed_prop(source, factor), OUT / "props" / f"{prop}.png")
    for name in TILES:
        pictures.put(tile(name), OUT / "tiles" / f"{name}.png")
    pictures.put(grass(), OUT / "tiles" / "grass.png")
    for name in SHEET_PROPS:
        pictures.put(sheet_prop(name), OUT / "props" / f"{name}.png")
    total = len(PLATES) + len(KEYED_PROPS) + len(TILES) + 1 + len(SHEET_PROPS)
    if args.check:
        if pictures.stale:
            print("stale or missing:\n  " + "\n  ".join(pictures.stale))
            return 1
        print(f"OK: {total} Mayon pictures are current")
        return 0
    print(f"wrote {total} pictures under game/assets/Level5/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
