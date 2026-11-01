#!/usr/bin/env python3
"""Paint Lolo into every one of her paintings, for the house after the run.

WHY THIS EXISTS
---------------
The run ends in the house (DIARY.md; Kent, 2026-11-01): "they transport back to the house with
all the paintings and lolo in each of them (not as a ghost)". Lola painted him into every one so
he would always be somewhere (her first diary page says so), and once the apo has brought the
places back, the house shows it: each painting on the wall with him standing in it, alive, in
the painting's own scale.

THE ART IS KENT'S: five character sheets of Lolo alive
(game/assets/characters/lolo/source/LOLO1-5.png, 2026-11-01), young in the first and old in the
fifth, so he ages across her paintings in the order they hang -- LOLOn goes into painting n. The
ghost (HUD-assets-ideas/Lolo-Ghost.png, and every sprite the game already had of him) is not
used here: "not as a ghost" is the whole point.

⚠ THE SHEETS ARE ONLY READ HERE, so they sit in a `source/` folder with a `.gdignore`, as the
apo's references do. In the imported folder Godot took all five in and shipped ~10 MB of
1254 x 1254 sheets with the game, for a figure 18 px tall.

CUTTING
-------
Each sheet is 1254 x 1254 with the same layout; his FRONT pose in the turnaround panel is cut
from FRONT. The panel is a flat dark grey (std ~1.5), so it is keyed by flood fill from the cut's
edge within PANEL_TOL of the panel's own colour -- never by a threshold over the whole cut, which
would take his dark outline with it. The ground shadow under his feet is neutral and darker than
the panel; the fill runs through it too, or it smears into his shoes at the paintings' scale.
⚠ ONLY WHERE IT TOUCHES THE PANEL: his eyes and mouth are neutral and dark as well, and keying
every such pixel took his face out. Inside his face, the fill never reaches them. Then he is brought
down to HEIGHT with alpha-weighted averaging (so the keyed panel does not bleed dark into his
edges) and keyed hard, so he stays pixel art rather than a soft thumbnail.

OUTPUT
------
`game/assets/hub/paintings/level_N_lolo.png` beside each `level_N.png`, the same size. The house
hangs these in place of the originals once Mayon is finished (HouseEpilogue).

Usage:
    .venv/bin/python tools/build_house_lolo.py           # write the five
    .venv/bin/python tools/build_house_lolo.py --check   # verify they are up to date
"""

import argparse
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PAINTINGS = ROOT / "game" / "assets" / "hub" / "paintings"
SHEETS = ROOT / "game" / "assets" / "characters" / "lolo" / "source"

# His FRONT pose on every sheet (x0, y0, x1, y1), measured: the figure stands in 361..493 x
# 94..325 on all five, with panel round it -- and stops above the word "FRONT" under him.
FRONT = (340, 80, 515, 334)
# How far a pixel may stray from the panel's colour and still be panel.
PANEL_TOL = 14
# How tall he stands in a painting, in its own pixels.
HEIGHT = 18
# Where his feet go in each painting (x, y in its 128 x 72 pixels), and the sheet he is cut from.
SPOTS = {
    "level_1": (90, 61, "LOLO1"),   # on the path below the hut, among the terraces
    "level_2": (58, 62, "LOLO2"),   # in the plaza with the dancers
    "level_3": (117, 51, "LOLO3"),  # on the rocks at the sea's edge, looking out
    "level_4": (34, 61, "LOLO4"),   # on the forest path
    "level_5": (46, 59, "LOLO5"),   # in the field below the mountain, old now
}


def keyed(sheet: str) -> np.ndarray:
    cut = np.array(Image.open(SHEETS / ("%s.png" % sheet)).convert("RGB").crop(FRONT)).astype(int)
    height, width, _ = cut.shape
    edge = np.concatenate([cut[0], cut[-1], cut[:, 0], cut[:, -1]])
    panel = np.median(edge, axis=0)
    # Panel, or the ground shadow standing on it: neutral and darker than the panel.
    neutral = (cut.max(axis=2) - cut.min(axis=2)) <= 10
    near = (np.abs(cut - panel).max(axis=2) <= PANEL_TOL) | (neutral & (cut.sum(axis=2) < panel.sum()))
    background = np.zeros((height, width), dtype=bool)
    queue = deque()
    for y in range(height):
        for x in (0, width - 1):
            if near[y, x] and not background[y, x]:
                background[y, x] = True
                queue.append((y, x))
    for x in range(width):
        for y in (0, height - 1):
            if near[y, x] and not background[y, x]:
                background[y, x] = True
                queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < height and 0 <= nx < width and near[ny, nx] and not background[ny, nx]:
                background[ny, nx] = True
                queue.append((ny, nx))
    alpha = np.where(background, 0, 255)
    rgba = np.dstack([cut, alpha]).astype(np.uint8)
    ys, xs = np.nonzero(alpha)
    return rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def figure(sheet: str) -> Image.Image:
    rgba = keyed(sheet).astype(float)
    height, width = rgba.shape[:2]
    out_w = max(1, round(width * HEIGHT / height))
    alpha = rgba[..., 3] / 255.0

    def down(channel: np.ndarray) -> np.ndarray:
        return np.array(Image.fromarray(channel.astype(np.float32), "F").resize((out_w, HEIGHT), Image.BOX))

    weight = down(alpha)
    colour = [down(rgba[..., c] * alpha) / np.maximum(weight, 1e-6) for c in range(3)]
    solid = weight >= 0.5
    out = np.zeros((HEIGHT, out_w, 4), dtype=np.uint8)
    for c in range(3):
        out[..., c] = np.clip(np.round(colour[c]), 0, 255).astype(np.uint8)
    out[..., 3] = np.where(solid, 255, 0)
    return Image.fromarray(out, "RGBA")


def painted(level_id: str) -> Image.Image:
    base = Image.open(PAINTINGS / ("%s.png" % level_id)).convert("RGBA")
    x, y, sheet = SPOTS[level_id]
    him = figure(sheet)
    out = base.copy()
    out.alpha_composite(him, (x - him.width // 2, y - him.height))
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--check", action="store_true", help="fail if any is out of date")
    args = parser.parse_args()
    for level_id in SPOTS:
        path = PAINTINGS / ("%s_lolo.png" % level_id)
        image = painted(level_id)
        if args.check:
            if not path.exists():
                sys.exit("missing: %s" % path.relative_to(ROOT))
            if not np.array_equal(np.array(Image.open(path).convert("RGBA")), np.array(image)):
                sys.exit("out of date: %s -- run tools/build_house_lolo.py" % path.relative_to(ROOT))
            continue
        image.save(path)
        print("wrote %s" % path.relative_to(ROOT))
    if args.check:
        print("lolo in the paintings: up to date (%d)" % len(SPOTS))


if __name__ == "__main__":
    main()
