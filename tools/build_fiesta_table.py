#!/usr/bin/env python3
"""Fiesta food for Piyesta's plaza: one long table, drawn in the plaza's own pixel idiom.

The cultural panel asked for more of everyday Filipino life, food first (Chapter 5, Table 34),
and a Cebu fiesta is the one day every house opens its table. So the plaza has one, on the way
to the church, and Lolo says what is on it.

What is on it, and what is deliberately not:

  * puso     -- rice cooked in a pouch of woven coconut leaf, hung in a bunch: Cebu's own;
  * bibingka -- rice cakes baked on banana leaf, charred on top;
  * adobo    -- in a clay pot (palayok);
  * pancit   -- noodles, for a long life;
  * mangoes  -- a basket of them.

⚠ NO LECHON AND NO BREAD. Both are the heart of a real fiesta table, and both are drawable
classes (`pig`, `bread`). The plaza's next beat asks for something that can feed, so a loaf or a
roast pig standing in the square is a hint the level never meant to give, and a picture of a
class anywhere is one more thing the class audits would have to argue about. Nothing on the
table is one of the fifty.

Drawn with `pixelart.Canvas`, the library the rest of the plaza is drawn with, in the same ramps
(`build_plaza_art.py`), light from the upper left, scaled by PX with nearest-neighbour.

    python3 tools/build_fiesta_table.py
    python3 tools/build_fiesta_table.py --check
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelart import SEED, Canvas, Pictures, ramp  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game/assets/Level2/plaza/fiesta_table.png"

TIMBER = ["#2A1A0C", "#452C15", "#6B4526", "#8E5F32", "#B07C42", "#CFA164"]
CLOTH = ["#9A8C78", "#C6B9A2", "#E0D5C2", "#F0E8DA", "#FBF6EC"]
FIESTA_RED = ["#5A0C10", "#830A14", "#AE0F1C", "#CE2A24", "#E8533C", "#F5836A"]
FIESTA_GOLD = ["#7A5206", "#A87708", "#D4A014", "#EFC12C", "#F8DC63", "#FDEFA6"]
GREEN = ["#1B2E08", "#293D09", "#31521E", "#466119", "#5F7817", "#7E9A2C"]
STRAW = ["#7A5C24", "#A07C34", "#C9A455", "#E8C87A", "#F6E2A8"]
## Leaf weave going pale as it dries in the heat: the puso pouches.
WEAVE = ["#5E6A22", "#86902E", "#AEB24A", "#CFCC72", "#E6E2A0"]
## Clay, for the palayok.
CLAY = ["#2E140A", "#4E2412", "#74381C", "#9A5028", "#BC6C3A"]
## Adobo: soy and vinegar, nearly black at the bottom of the pot.
STEW = ["#1E0E06", "#3A1C0C", "#5A2E14", "#7A4620"]
## Bibingka: golden crumb, charred spots.
CAKE = ["#5A3410", "#9A6420", "#C99236", "#E8B85A", "#F6D88A"]
## Pancit: yellow noodles.
NOODLE = ["#8A6410", "#B88A1E", "#D8AE3A", "#EDCC62"]
MANGO = ["#8A5A06", "#C48A0C", "#E8B220", "#F6D64A", "#FBEA8A"]

WIDTH, HEIGHT = 104, 62
## The table top's row, and the floor's: the feet stand on the last row.
TOP = 34
FLOOR = HEIGHT - 1


def _table(c: Canvas) -> None:
    wood = ramp(TIMBER)
    cloth = ramp(CLOTH)
    red = ramp(FIESTA_RED)
    # Legs, then the top, then a cloth over it with a red-and-gold fiesta border.
    for x in [10, 88]:
        c.fill(x, TOP + 6, 4, FLOOR - TOP - 5, wood[2])
        c.vline(x, TOP + 6, FLOOR - TOP - 5, wood[3])
        c.vline(x + 3, TOP + 6, FLOOR - TOP - 5, wood[1])
    c.fill(4, TOP, 96, 4, wood[3])
    c.hline(4, TOP, 96, wood[4])
    c.fill(2, TOP + 2, 100, 9, cloth[3])
    c.dither(2, TOP + 6, 100, 5, cloth[2], cloth[3], 0.5)
    c.hline(2, TOP + 2, 100, cloth[4])
    c.fill(2, TOP + 10, 100, 2, red[2])
    gold = ramp(FIESTA_GOLD)
    for x in range(4, 100, 6):
        c.fill(x, TOP + 12, 3, 2, gold[3])
        c.px(x + 1, TOP + 14, gold[2])
    # Banana leaves laid along the top, under the food.
    leaf = ramp(GREEN)
    c.fill(8, TOP - 1, 88, 2, leaf[4])
    c.hline(8, TOP - 1, 88, leaf[5])
    for x in range(10, 94, 5):
        c.px(x, TOP, leaf[2])


def _puso(c: Canvas) -> None:
    """A bunch of puso hung from a pole at the table's end, as the stalls in Cebu hang them."""
    wood = ramp(TIMBER)
    weave = ramp(WEAVE)
    c.fill(97, 2, 3, TOP - 1, wood[2])
    c.vline(97, 2, TOP - 1, wood[4])
    c.fill(84, 3, 16, 2, wood[3])
    for index, (x, y) in enumerate([(85, 8), (90, 10), (95, 7), (87, 15), (93, 16)]):
        # Each pouch a small diamond of weave on a string.
        c.vline(x + 2, 5, y - 5, weave[0])
        for row in range(7):
            half = 3 - abs(row - 3)
            c.fill(x + 2 - half, y + row, half * 2 + 1, 1, weave[2 + (index % 2)])
        c.px(x + 1, y + 2, weave[4])
        c.px(x + 2, y + 3, weave[0])
        c.px(x + 3, y + 4, weave[1])


def _palayok(c: Canvas) -> None:
    """Adobo in a clay pot, the lid set aside."""
    clay = ramp(CLAY)
    stew = ramp(STEW)
    for row in range(14):
        half = int(round(9 * (1.0 - ((row - 7) / 8.0) ** 2) ** 0.5))
        c.fill(24 - half, TOP - 14 + row, half * 2, 1, clay[2])
        c.px(24 - half, TOP - 14 + row, clay[3])
        c.px(24 + half - 1, TOP - 14 + row, clay[1])
    c.fill(16, TOP - 15, 16, 2, clay[3])
    c.fill(18, TOP - 14, 12, 2, stew[1])
    c.hline(19, TOP - 14, 4, stew[3])
    c.px(25, TOP - 14, stew[3])
    c.px(28, TOP - 13, stew[2])


def _bibingka(c: Canvas) -> None:
    """Two rice cakes on their leaves: wide and flat, round, charred on top.

    ⚠ FLAT AND ROUND, NOT TALL. The first drawing was two domed blocks, and a domed block on a
    table reads as a loaf -- `bread`, the one thing this table must not show.
    """
    cake = ramp(CAKE)
    leaf = ramp(GREEN)
    for cx in [41, 54]:
        # The leaf underneath, wider than the cake, then the cake's side, then its top.
        for row in range(4):
            half = int(round(7.5 * (1.0 - ((row - 1.5) / 2.5) ** 2) ** 0.5))
            c.fill(cx - half, TOP - 4 + row, half * 2, 1, leaf[3] if row else leaf[4])
        c.fill(cx - 6, TOP - 4, 12, 2, cake[1])
        for row in range(3):
            half = int(round(6 * (1.0 - ((row - 1) / 2.0) ** 2) ** 0.5))
            c.fill(cx - half, TOP - 7 + row, half * 2, 1, cake[3] if row else cake[4])
        for dx, dy in [(-3, -6), (1, -7), (3, -5), (-1, -5)]:
            c.px(cx + dx, TOP + dy, cake[0])


def _pancit(c: Canvas) -> None:
    """A plate heaped with noodles, a little green on top."""
    noodle = ramp(NOODLE)
    plate = ramp(CLOTH)
    leaf = ramp(GREEN)
    c.fill(58, TOP - 2, 16, 2, plate[4])
    c.hline(58, TOP - 1, 16, plate[1])
    for row in range(6):
        half = 7 - abs(row - 1) if row < 2 else 7 - row
        c.fill(66 - half, TOP - 3 - row, half * 2, 1, noodle[1 + (row % 3)])
    for x in range(60, 72, 2):
        c.px(x, TOP - 4 - (x % 3), noodle[3])
    for x, y in [(63, TOP - 7), (67, TOP - 6), (65, TOP - 8)]:
        c.px(x, y, leaf[4])


def _mangoes(c: Canvas) -> None:
    """A low basket of mangoes."""
    straw = ramp(STRAW)
    mango = ramp(MANGO)
    c.fill(74, TOP - 5, 14, 5, straw[2])
    for x in range(74, 88, 2):
        c.vline(x, TOP - 5, 5, straw[1])
    c.hline(74, TOP - 5, 14, straw[3])
    # Each its own oval, with a dark pixel between neighbours so the heap reads as fruit.
    for x, y in [(75, TOP - 9), (80, TOP - 9), (84, TOP - 9), (77, TOP - 13), (82, TOP - 13)]:
        c.fill(x, y + 1, 5, 3, mango[2])
        c.fill(x + 1, y, 3, 5, mango[2])
        c.fill(x + 1, y + 1, 2, 2, mango[3])
        c.px(x + 1, y + 1, mango[4])
        c.px(x + 3, y + 4, mango[0])
        c.px(x + 4, y + 3, mango[1])
        c.px(x + 2, y - 1, ramp(GREEN)[3])


def build() -> Canvas:
    c = Canvas(WIDTH, HEIGHT, SEED + 1224)
    _puso(c)
    _table(c)
    _palayok(c)
    _bibingka(c)
    _pancit(c)
    _mangoes(c)
    # The dark outline the plaza's props carry, round everything drawn.
    import numpy as np
    alpha = c.buf[..., 3] > 0
    edge = np.zeros_like(alpha)
    edge[1:, :] |= alpha[:-1, :]
    edge[:-1, :] |= alpha[1:, :]
    edge[:, 1:] |= alpha[:, :-1]
    edge[:, :-1] |= alpha[:, 1:]
    outline = edge & ~alpha
    c.buf[outline] = (20, 12, 6, 255)
    # Steam off the adobo, after the outline: a wisp outlined in black reads as a crack.
    for x, y in [(20, TOP - 19), (21, TOP - 18), (21, TOP - 20), (27, TOP - 21), (26, TOP - 19),
                 (27, TOP - 18)]:
        c.px(x, y, ramp(CLOTH)[2])
    return c


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="fail if the picture is stale")
    args = parser.parse_args()
    pictures = Pictures(args.check, ROOT)
    pictures.put(build().image(), OUT)
    if pictures.stale:
        print("stale: " + ", ".join(pictures.stale), file=sys.stderr)
        return 1
    if not args.check:
        print(f"wrote {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
