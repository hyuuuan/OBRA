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
never a ruled cut), a thick lip of its own grass edge tile draping in clumps, darker going down
with a shadow under the lip and under every broken layer, and its own grass spilling over the
corners, with its ferns and grass standing on the lip.

  game/assets/Level<N>/cliff/face.png     the strip: stone under a thick lip; tiles across
  game/assets/Level<N>/cliff/edge.png     grass spilling down a left-facing side
  game/assets/Level<N>/cliff/plant_N.png  plants off the atlas, at its own size
  game/assets/Level<N>/cliff/kit.json     the rows the runtime needs (walk line, band, ...)

⚠ NO PICTURE OF A DRAWABLE CLASS. Payyo's example assembly has stone stairs and a fence in it;
neither may be used (CLAUDE.md: a ladder or stairs in a picture is a hint the level did not
mean to give). Only wall tiles, corner tiles, grass and ferns are cut.

  .venv/bin/python tools/build_cliff_kits.py           # write the kits
  .venv/bin/python tools/build_cliff_kits.py --check   # exit 1 if a committed kit is stale
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import deque
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixelart  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
## The tilesets are painted about one pixel to a pixel, and the ground is drawn at exactly that.
## ⚠ NOT ENLARGED. At twice the size every painted stone went to blocks and the ground read as
## low-resolution AI art beside its own crisp backdrop (Kent: "lower resolution like not hd").
## Kept as a name so the test and the runtime numbers say where they come from.
SCALE = 1
## Wall courses stacked in the strip: one is too shallow at this size to cover the first darker
## repeat 150 px down, and the strip's underside must always be below it.
COURSES = 2
## How far the lip's corner overhangs the wall, tileset px.
OVERHANG = 6


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
    ## The grass edge tile laid across as the thick lip, the rows of it that are solid grass,
    ## and how far its green fringe may hang in clumps below that.
    lip_tile: tuple[int, int, int, int] = (0, 0, 0, 0)
    lip_band: int = 27
    lip_drape: int = 8
    ## The corner tile's grass down its side: rows from, rows to, columns.
    spill: tuple[int, int, int] = (0, 0, 0)
    ## Plants off the atlas; the first one stands on every open corner.
    plants: list[tuple[int, int, int, int]] = field(default_factory=list)
    corner_plant: int = 0
    ## Rows of air above the slab for its blades, and how far into the slab the walk line sits.
    above: int = 8
    walk: int = 6
    ## How much darker the stone is at the strip's underside than under the lip.
    fall: float = 0.42
    ## Rows of the shadow each broken layer drops on the one below.
    drop: int = 14
    ## The broken underside: how deep each chunk reaches, as a share of the tile height. Deep
    ## enough that the first darker repeat's top (150 px down) is always behind it.
    reach: tuple[float, float] = (0.78, 0.98)
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


def stack(upper: np.ndarray, lower: np.ndarray) -> np.ndarray:
    """One course over another, the join crossfaded over JOIN rows."""
    ramp = np.linspace(0.0, 1.0, JOIN + 2)[1:-1][:, None, None]
    joined = upper[-JOIN:].astype(np.float32) * (1 - ramp) + lower[:JOIN].astype(np.float32) * ramp
    return np.concatenate([upper[:-JOIN], joined.round().astype(np.uint8), lower[JOIN:]], axis=0)


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


def keyed(atlas: Image.Image, box: tuple[int, int, int, int]) -> np.ndarray:
    """A sprite off the atlas, cropped to what is drawn (the atlas page is transparent)."""
    sprite = cut(atlas, box)
    sprite[..., 3] = np.where(sprite[..., 3] > 40, 255, 0)
    ys, xs = np.nonzero(sprite[..., 3])
    return sprite[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def greenish(rgba: np.ndarray, margin: int = 8) -> np.ndarray:
    return (rgba[..., 1].astype(int) > rgba[..., 0].astype(int) + margin) & (rgba[..., 3] > 40)


def slab(recipe: Recipe, atlas: Image.Image, width: int, rng: np.random.Generator) -> np.ndarray:
    """The thick lip: the tileset's own grass edge tile laid across, its solid band kept whole and
    its hanging fringe kept only where it is green, cut deeper in clumps -- Mayon's lip drapes."""
    tile = trim(cut(atlas, recipe.lip_tile))
    band = lay([tile], [0] * max(2, -(-width // (tile.shape[1] - JOIN)) + 1), tile.shape[0])
    while band.shape[1] < width:
        band = np.concatenate([band, band], axis=1)
    band = band[:, :width].copy()
    rows = np.arange(band.shape[0])[:, None]
    clump = np.convolve(np.concatenate([rng.random(width)] * 3), np.ones(15) / 15, "same")[width:2 * width]
    reach = recipe.lip_band + 6 + np.round(clump * 2.4 * recipe.lip_drape - recipe.lip_drape * 0.6)
    keep = (rows < recipe.lip_band) | (greenish(band) & (rows < reach[None, :]))
    band[..., 3] = np.where(keep, 255, 0)
    return band


def build_face(recipe: Recipe) -> Image.Image:
    rng = np.random.default_rng(recipe.seed)
    atlas = Image.open(ROOT / recipe.atlas)
    tiles = [trim(cut(atlas, box)) for box in recipe.tiles]
    tall = min(t.shape[0] for t in tiles)
    wall = lay(tiles, recipe.order, tall)
    # Lower courses are the same stone without its grass fringe, laid in another order so the
    # joins do not line up, and crossfaded into the course above.
    bodies = [t[recipe.fringe + 2:] for t in tiles]
    for course in range(1, COURSES):
        turn = course * 3 % len(recipe.order)
        below = lay(bodies, recipe.order[turn:] + recipe.order[:turn], tall - recipe.fringe - 2)
        wall = stack(wall, below)
    width = wall.shape[1]
    # The wall's own thin fringe goes under the slab, which is laid over its top.
    wall_top = recipe.above + recipe.lip_band - recipe.fringe + 4
    canvas = np.zeros((wall_top + wall.shape[0], width, 4), dtype=np.uint8)
    canvas[wall_top:] = wall
    deep = wall.shape[0]
    profile = wall_top + chunks(width, (recipe.reach[0] * deep, recipe.reach[1] * deep), rng)
    canvas = break_underside(canvas, recipe, wall_top, profile, wrap=True)
    rows = np.arange(canvas.shape[0])[:, None]
    # Darker going down: daylight on the top courses, shadow toward the underside.
    fall = 1.0 - recipe.fall * np.clip((rows - wall_top) / max(1, canvas.shape[0] - wall_top), 0, 1)
    canvas[..., :3] = (canvas[..., :3] * fall[..., None]).astype(np.uint8)
    lip = slab(recipe, atlas, width, rng)
    hang = np.array([np.nonzero(lip[:, x, 3])[0].max() + 1 for x in range(width)]) + recipe.above
    # The lip shades the stone under it, deepest right under the hanging grass.
    for k in range(12):
        under = (rows == hang[None, :] + k) & (canvas[..., 3:4][..., 0] > 0)
        canvas[under, :3] = (canvas[under, :3] * (0.5 + 0.5 * k / 12)).astype(np.uint8)
    on = lip[..., 3] > 0
    region = canvas[recipe.above:recipe.above + lip.shape[0]]
    region[on] = lip[on]
    # Each broken layer drops a shadow on the one below it: what makes the repeats read as rock
    # stepping back rather than as bands of paint.
    bottom = np.array([np.nonzero(canvas[:, x, 3])[0].max() for x in range(width)])
    shadow = np.zeros((recipe.drop, width, 4), dtype=np.uint8)
    for k in range(recipe.drop):
        shadow[k, :, 3] = int(150 * (1 - k / recipe.drop) ** 1.5)
    canvas = np.concatenate([canvas, np.zeros((recipe.drop, width, 4), np.uint8)], axis=0)
    for x in range(width):
        canvas[bottom[x] + 1:bottom[x] + 1 + recipe.drop, x] = shadow[:, x]
    _blades(canvas, recipe, rng, wrap=True)
    return _scaled(canvas)


def _blades(canvas: np.ndarray, recipe: Recipe, rng: np.random.Generator, wrap: bool,
            start: int = 0) -> None:
    """Grass blades over the slab, rooted in it: one to five pixels, in clumps."""
    if not recipe.blades:
        return
    greens = pixelart.ramp(recipe.blades)[:, :3]
    root = recipe.above + 1
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
    """Grass spilling over a left-facing corner and a little way down the side, cut from the
    tileset's own corner tile: its grass, not its stones -- the stones are the wall's own, cut
    straight and shaded at runtime. ⚠ A column of the corner tile's stones laid over the wall
    was the "weird" edge: two sets of stones that did not meet, chewed at a random line."""
    atlas = Image.open(ROOT / recipe.atlas)
    corner = cut(atlas, recipe.corner)
    side = corner[recipe.spill[0]:recipe.spill[1], :recipe.spill[2]].copy()
    side[..., 3] = np.where(greenish(side), 255, 0)
    # Only the grass joined to the edge column: loose moss in the joints further in stays put.
    labels, _ = label(side[..., 3] > 0, False)
    touching = np.unique(labels[:, :3][labels[:, :3] >= 0])
    side[..., 3] = np.where(np.isin(labels, touching), side[..., 3], 0)
    out = np.zeros((side.shape[0], side.shape[1] + OVERHANG, 4), dtype=np.uint8)
    out[:, OVERHANG:] = side
    # The tile's grass hangs from its own edge; here it hangs from the slab's, OVERHANG further out.
    for y in range(side.shape[0]):
        if out[y, OVERHANG, 3] and not out[y, OVERHANG - 1, 3]:
            span = max(0, OVERHANG - y // 6)
            out[y, OVERHANG - span:OVERHANG] = out[y, OVERHANG]
    _rim(out, False)
    return _scaled(out)


def build_plants(recipe: Recipe) -> list[Image.Image]:
    atlas = Image.open(ROOT / recipe.atlas)
    return [_scaled(keyed(atlas, box)) for box in recipe.plants]


def _scaled(rgba: np.ndarray) -> Image.Image:
    image = Image.fromarray(rgba, "RGBA")
    return image.resize((image.width * SCALE, image.height * SCALE), Image.NEAREST)


def lip(recipe: Recipe) -> int:
    """World px from the strip's top to the walk line."""
    return (recipe.above + recipe.walk) * SCALE


def kit(recipe: Recipe) -> dict:
    """What the runtime needs to know about the pictures, so the scene restates none of it."""
    return {
        "lip": lip(recipe),
        # The slab's solid band ends here: the overhang at a corner is cut from these rows.
        "band": (recipe.above + recipe.lip_band) * SCALE,
        # Stone only from here down: where the darker repeats are cut from.
        "skip": (recipe.above + recipe.lip_band + 3 * recipe.lip_drape) * SCALE,
        "deep": recipe.deep,
        "overhang": OVERHANG * SCALE,
        "plants": len(recipe.plants),
        "corner_plant": recipe.corner_plant,
    }


RECIPES = [
    # Payyo, all from texturemap.png: section 3's mossy river-stone retaining wall; section 5's
    # grass "bottom" edge as the thick lip; the grass down the side of section 5's rounded
    # stone-wall corner; and section 8's ferns and grass. ⚠ No flowers: the gorge hides one, and
    # a terrace sown with them would make the real one nothing to find.
    Recipe(
        name="payyo", out="game/assets/Level1/cliff", atlas="game/assets/Level1/texturemap.png",
        # Inset three pixels from each side but the top: the atlas outlines every tile.
        tiles=[(220, 399, 359, 523), (380, 399, 520, 522), (539, 399, 675, 522)],
        order=[0, 1, 2, 1, 0, 2, 0, 1, 2, 0, 2, 1, 0, 1],
        corner=(1252, 341, 1334, 428),
        lip_tile=(933, 79, 1018, 147),
        spill=(14, 62, 20),
        plants=[(739, 716, 779, 754), (792, 719, 836, 754), (740, 673, 779, 698),
                (934, 674, 971, 701), (854, 727, 883, 754)],
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
        out = ROOT / recipe.out
        pictures.put(build_face(recipe), out / "face.png")
        pictures.put(build_edge(recipe), out / "edge.png")
        for index, plant in enumerate(build_plants(recipe)):
            pictures.put(plant, out / f"plant_{index}.png")
        text = json.dumps(kit(recipe), indent=2) + "\n"
        if args.check:
            if not (out / "kit.json").exists() or (out / "kit.json").read_text() != text:
                pictures.stale.append(str((out / "kit.json").relative_to(ROOT)))
        else:
            (out / "kit.json").write_text(text)
    if pictures.stale:
        print("stale:", *pictures.stale, sep="\n  ")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
