#!/usr/bin/env python3
"""Cliff kits for Levels 1-4: Mayon's construction, each level's own ground.

Mayon stands the player on broad painted cliffs (`MayonTerrain2D`): a lip she stands IN, a thick
face under it whose UNDERSIDE IS BROKEN, the ground carrying on below in darker repeats instead
of a flat fill, and a painted cap on every open end. Levels 1-4 stood on flat fills with a thin
strip on top and square ends. This gives them that construction -- in their own materials.

⚠ TWO WRONG TURNS, BOTH KENT'S CALL (2 November).
  * Procedural river stones packed into a wall read as a generic cobble wall: "nothing close to
    level 5". The quality has to be painted, not generated here.
  * Mayon's own rocks, regraded to a level's palette, were the right quality and the wrong
    place: "mayon has those rocks since its setting is in a volcano place, the other levels are
    not". Boulders belong on a volcano.
So each kit is cut from THAT LEVEL'S DELIVERED TILESET -- the material its artist painted for its
ground -- and only assembled here in Mayon's construction: the wall tiles laid in a strip, the
underside broken along the painted stones' own outlines (so what hangs below is a whole stone,
never a ruled cut), blades in the tileset's own greens over the walk line, and an end cap built
from its corner tile with a ragged outside.

  game/assets/Level<N>/cliff/face.png   the strip: LIP px above the walk line, tiles across
  game/assets/Level<N>/cliff/edge.png   a left-facing end cap with the same walk line

⚠ NO PICTURE OF A DRAWABLE CLASS. Payyo's example assembly has stone stairs and a fence in it;
neither may be used (CLAUDE.md: a ladder or stairs in a picture is a hint the level did not
mean to give). Only wall tiles, corner tiles, grass, ferns and rocks are cut.

  .venv/bin/python tools/build_cliff_kits.py           # write the kits
  .venv/bin/python tools/build_cliff_kits.py --check   # exit 1 if a committed kit is stale
"""

from __future__ import annotations

import argparse
import sys
from collections import deque
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixelart  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
## The tilesets are painted about one pixel to a pixel; the ground is drawn at twice that, so
## a stone is the size of Mayon's smaller rocks and of the apo's head.
SCALE = 2


@dataclass
class Recipe:
    """One level's kit, in the tileset's own (unscaled) pixels."""
    name: str
    out: str
    atlas: str
    ## Wall tiles laid across the strip, as boxes in the atlas, and the order they repeat in.
    tiles: list[tuple[int, int, int, int]]
    order: list[int]
    ## The rounded corner tile the cap is built on (its rounded corner at its top LEFT).
    corner: tuple[int, int, int, int]
    ## Rows at the top of a wall tile that are its own grass fringe: never cut.
    fringe: int
    ## Below this luminance a pixel is a joint between stones, not a stone.
    joint: float
    ## Rows of plants above the tile top, and how far into the tile the walk line sits.
    above: int = 12
    walk: int = 3
    ## The broken underside: how deep each chunk reaches, as a share of the tile height. Deep
    ## enough that the first darker repeat's top (150 px down) is always behind it.
    reach: tuple[float, float] = (0.74, 0.98)
    ## The largest painted stone, in tileset px: anything bigger is joints run together.
    biggest: int = 800
    ## Under the strip, before the repeats: the joints' own darkest earth.
    deep: str = "#1a140a"
    ## Short blades along the lip, in the fringe's own greens, dark to light.
    blades: list[str] = field(default_factory=list)
    seed: int = 1


def cut(atlas: Image.Image, box: tuple[int, int, int, int]) -> np.ndarray:
    return np.asarray(atlas.crop(box).convert("RGBA")).copy()


def trim(tile: np.ndarray, most: int = 6) -> np.ndarray:
    """Drop the atlas's outline: side columns much darker than the tile's own are its border.
    ⚠ One tile's outline survived a fixed inset and drew a dark rule at every join it made."""
    lum = luminance(tile)
    typical = float(np.median(lum.mean(0)))
    left, right = 0, tile.shape[1]
    while left < most and lum[:, left].mean() < typical * 0.8:
        left += 1
    while tile.shape[1] - right < most and lum[:, right - 1].mean() < typical * 0.8:
        right -= 1
    return tile[:, left:right]


def luminance(rgba: np.ndarray) -> np.ndarray:
    return (rgba[..., :3].astype(np.float32) @ np.array([0.299, 0.587, 0.114], np.float32)) / 255.0


def label(mask: np.ndarray, wrap: bool) -> tuple[np.ndarray, int]:
    """4-connected components of a mask, optionally wrapping across the left/right edge."""
    height, width = mask.shape
    labels = np.full(mask.shape, -1, dtype=np.int32)
    count = 0
    for y0, x0 in zip(*np.nonzero(mask)):
        if labels[y0, x0] >= 0:
            continue
        queue = deque([(y0, x0)])
        labels[y0, x0] = count
        while queue:
            y, x = queue.popleft()
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if wrap:
                    nx %= width
                if 0 <= ny < height and 0 <= nx < width and mask[ny, nx] and labels[ny, nx] < 0:
                    labels[ny, nx] = count
                    queue.append((ny, nx))
        count += 1
    return labels, count


## Neighbouring tiles overlap by this much, crossfaded. ⚠ The tilesets' "seamless" tiles are
## not: every join stepped two to three times harder than any step inside a tile.
JOIN = 8


def lay(tiles: list[np.ndarray], order: list[int], tall: int) -> np.ndarray:
    """Tiles across, each join crossfaded over JOIN columns -- the strip's own wrap included."""
    ramp = np.linspace(0.0, 1.0, JOIN + 2)[1:-1][None, :, None]
    row = tiles[order[0]][:tall].astype(np.float32)
    for index in order[1:] + [order[0]]:
        tile = tiles[index][:tall].astype(np.float32)
        joined = row[:, -JOIN:] * (1 - ramp) + tile[:, :JOIN] * ramp
        row = np.concatenate([row[:, :-JOIN], joined, tile[:, JOIN:]], axis=1)
    # The first tile was laid again at the end, crossfaded in from the last. Cut from just past
    # the first tile's start to just past that second copy's start: the strip then wraps from
    # the crossfade straight into the first tile, exactly as the tile itself runs on.
    first = tiles[order[0]].shape[1]
    return row[:, JOIN:row.shape[1] - first + JOIN].round().astype(np.uint8)


def chunks(width: int, depth: tuple[float, float], rng: np.random.Generator) -> np.ndarray:
    """The broken underside, in px: chunks of different depth with rounded ends, wrapping."""
    out = np.zeros(width, dtype=np.float32)
    x = 0
    while x < width:
        span = int(rng.integers(26, 70))
        reach = rng.uniform(*depth)
        for k in range(min(span, width - x)):
            edge = min(k, span - 1 - k)
            out[x + k] = reach - max(0, 7 - edge) * 1.6
        x += span
    return out


def break_underside(rgba: np.ndarray, recipe: Recipe, top: int, profile: np.ndarray,
                    wrap: bool, keep_x: tuple[np.ndarray, np.ndarray] | None = None) -> np.ndarray:
    """Cut a wall along its painted stones: a stone stays whole when its centre is above the
    profile, joints only well above it, and the tile's grass fringe always. `keep_x` (per row,
    outside and inside) is a cap's ragged sides: stones whose centre is outside them go."""
    height, width = rgba.shape[:2]
    seen = rgba[..., 3] > 40
    # Moss is not stone: green between stones would join them all into one blob.
    green = rgba[..., 1].astype(int) > rgba[..., 0].astype(int) + 12
    stone = seen & (luminance(rgba) >= recipe.joint) & ~green
    labels, count = label(stone, wrap)
    # Specks and highlights are not stones, and nor is anything bigger than one: both go by
    # the joints' rule instead of being kept or dropped whole.
    sizes = np.bincount(labels[labels >= 0], minlength=count)
    whole = (sizes >= 25) & (sizes <= recipe.biggest)
    labels = np.where((labels >= 0) & whole[np.clip(labels, 0, None)], labels, -1)
    ys, xs = np.nonzero(labels >= 0)
    ids = labels[ys, xs]
    weight = np.bincount(ids, minlength=count).astype(np.float32)
    cy = np.bincount(ids, ys, minlength=count) / np.maximum(weight, 1)
    if wrap:
        # Circular mean across the seam, so a stone straddling it is judged where it is.
        angle = xs / width * 2 * np.pi
        cx = (np.arctan2(np.bincount(ids, np.sin(angle), minlength=count),
                         np.bincount(ids, np.cos(angle), minlength=count)) % (2 * np.pi)) / (2 * np.pi) * width
    else:
        cx = np.bincount(ids, xs, minlength=count) / np.maximum(weight, 1)
    col = np.clip(cx.astype(int), 0, width - 1)
    row = np.clip(cy.astype(int), 0, height - 1)
    keep = cy < profile[col]
    if keep_x is not None:
        keep &= (cx > keep_x[0][row]) & (cx < keep_x[1][row])
    rows = np.arange(height)[:, None]
    kept = np.where(labels >= 0, np.append(keep, False)[labels], False)
    joints = seen & (labels < 0) & (rows < profile[None, :] - 5)
    fringe = seen & (rows < top + recipe.fringe)
    if keep_x is not None:
        columns = np.arange(width)[None, :]
        joints &= (columns > keep_x[0][:, None] + 3) & (columns < keep_x[1][:, None] - 6)
        fringe &= columns < keep_x[1][:, None] + 4
    solid = kept | joints | fringe
    out = rgba.copy()
    out[..., 3] = np.where(solid, out[..., 3], 0)
    # The face is in its own shadow toward the underside, as Mayon's is.
    shade = 1.0 - 0.32 * np.clip((rows - top - recipe.fringe) / max(1, height - top), 0, 1)
    out[..., :3] = (out[..., :3] * shade[..., None]).astype(np.uint8)
    _rim(out, wrap, inner=keep_x is None)
    return out


def _rim(rgba: np.ndarray, wrap: bool, inner: bool = True) -> None:
    """A dark rim where the face meets air below or beside it. A cap's inside lies over the
    strip, not over air, so it is not rimmed: rimmed, it drew a rule down every open end."""
    alpha = rgba[..., 3] > 0
    below = np.zeros_like(alpha)
    below[:-1] = alpha[1:]
    if wrap:
        left, right = np.roll(alpha, 1, 1), np.roll(alpha, -1, 1)
    else:
        left = np.zeros_like(alpha)
        left[:, 1:] = alpha[:, :-1]
        right = np.zeros_like(alpha)
        right[:, :-1] = alpha[:, 1:]
        if not inner:
            right[:] = True
            below[:] = True
    rim = alpha & ~(below & left & right)
    rim[:20] = False
    rgba[rim, :3] = (rgba[rim, :3] * 0.45).astype(np.uint8)


def paste(canvas: np.ndarray, sprite: np.ndarray, x: int, y: int, wrap: bool) -> None:
    """Alpha-over a sprite onto the canvas, wrapping across the strip's ends."""
    height, width = sprite.shape[:2]
    for row in range(height):
        cy = y + row
        if not 0 <= cy < canvas.shape[0]:
            continue
        for col in range(width):
            cx = (x + col) % canvas.shape[1] if wrap else x + col
            if not 0 <= cx < canvas.shape[1]:
                continue
            a = sprite[row, col, 3] / 255.0
            if a <= 0.0:
                continue
            under = canvas[cy, cx].astype(np.float32)
            over = sprite[row, col].astype(np.float32)
            colour = over[:3] * a + under[:3] * (1 - a)
            canvas[cy, cx, :3] = colour.astype(np.uint8)
            canvas[cy, cx, 3] = int(max(under[3], sprite[row, col, 3]))


def build_face(recipe: Recipe) -> Image.Image:
    rng = np.random.default_rng(recipe.seed)
    atlas = Image.open(ROOT / recipe.atlas)
    tiles = [trim(cut(atlas, box)) for box in recipe.tiles]
    tall = min(t.shape[0] for t in tiles)
    row = lay(tiles, recipe.order, tall)
    width = row.shape[1]
    canvas = np.zeros((recipe.above + tall, width, 4), dtype=np.uint8)
    canvas[recipe.above:] = row
    profile = recipe.above + chunks(width, (recipe.reach[0] * tall, recipe.reach[1] * tall), rng)
    canvas = break_underside(canvas, recipe, recipe.above, profile, wrap=True)
    # ⚠ Blades, not the tileset's plants: stood along the lip at this scale its sprouts read as
    # a row of lollipops and its ferns as pineapple tops.
    _blades(canvas, recipe, rng, wrap=True)
    return _scaled(canvas)


def _blades(canvas: np.ndarray, recipe: Recipe, rng: np.random.Generator, wrap: bool,
            start: int = 0) -> None:
    """Grass blades over the walk line, rooted in the fringe: one to five pixels, in clumps."""
    if not recipe.blades:
        return
    greens = pixelart.ramp(recipe.blades)[:, :3]
    root = recipe.above + recipe.walk + 1
    width = canvas.shape[1]
    clump = np.convolve(rng.random(width), np.ones(9) / 9, mode="same")
    for x in range(start, width):
        if canvas[root + 2, x, 3] == 0:
            continue
        tall = int(round(1 + clump[x] * 3 + (rng.random() < 0.2) * rng.integers(1, 4)))
        for k in range(tall):
            y = root - 1 - k
            shade = min(len(greens) - 1, int((k + 1) / tall * (len(greens) - 1) + rng.integers(0, 2)))
            canvas[y, x, :3] = greens[shade]
            canvas[y, x, 3] = 255


def build_edge(recipe: Recipe) -> Image.Image:
    rng = np.random.default_rng(recipe.seed + 1)
    atlas = Image.open(ROOT / recipe.atlas)
    corner = cut(atlas, recipe.corner)
    body = cut(atlas, recipe.tiles[0])[recipe.fringe + 2:]
    width = min(64, corner.shape[1])
    stack = [corner[:, :width]]
    while sum(part.shape[0] for part in stack) < 2.2 * corner.shape[0]:
        stack.append(body[:, :width])
    wall = np.concatenate(stack, axis=0)
    height = recipe.above + wall.shape[0]
    canvas = np.zeros((height, width, 4), dtype=np.uint8)
    canvas[recipe.above:] = wall
    rows = np.arange(height)
    # Stones stand proud of the edge (x 5 is the edge itself), and below the corner the cap
    # tucks in toward the bottom so it ends in stone, as Mayon's caps taper.
    wobble = np.sin(rows / 9.0) * 2 + rng.normal(0, 1.2, height)
    outside = np.clip(3 + wobble + np.clip(rows - height * 0.55, 0, None) * 0.18, 0, width)
    inside = np.clip(width - 14 - np.clip(rows - height * 0.45, 0, None) * 0.30
                     + np.sin(rows / 13.0) * 5, 0, width)
    profile = np.full(width, float(height - 6))
    canvas = break_underside(canvas, recipe, recipe.above, profile, wrap=False, keep_x=(outside, inside))
    _blades(canvas, recipe, rng, wrap=False, start=6)
    return _scaled(canvas)


def _scaled(rgba: np.ndarray) -> Image.Image:
    image = Image.fromarray(rgba, "RGBA")
    return image.resize((image.width * SCALE, image.height * SCALE), Image.NEAREST)


def lip(recipe: Recipe) -> int:
    """The runtime's `lip`: world px from the strip's top to the walk line."""
    return (recipe.above + recipe.walk) * SCALE


RECIPES = [
    # Payyo: texturemap.png section 3, the mossy river-stone retaining wall of the rice terraces,
    # its grass fringe on top, and section 5's rounded stone-wall corner (TL) at each open end.
    Recipe(
        name="payyo", out="game/assets/Level1/cliff", atlas="game/assets/Level1/texturemap.png",
        # Inset three pixels from each side but the top: the atlas outlines every tile.
        tiles=[(220, 399, 359, 523), (380, 399, 520, 522), (539, 399, 675, 522)],
        order=[0, 1, 2, 1, 0, 2, 0, 1, 2, 0],
        corner=(1252, 341, 1334, 428),
        fringe=15, joint=0.28, seed=1101, deep="#1d160b",
        blades=["#395412", "#4e6f0d", "#729506", "#92b502", "#a1c503"],
    ),
]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--only", default="")
    args = parser.parse_args()
    pictures = pixelart.Pictures(args.check, ROOT)
    for recipe in RECIPES:
        if args.only and recipe.name != args.only:
            continue
        pictures.put(build_face(recipe), ROOT / recipe.out / "face.png")
        pictures.put(build_edge(recipe), ROOT / recipe.out / "edge.png")
        print(f"{recipe.name}: lip {lip(recipe)}")
    if pictures.stale:
        print("stale:", *pictures.stale, sep="\n  ")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
