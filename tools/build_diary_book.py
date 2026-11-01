#!/usr/bin/env python3
"""Cut Lola's diary out of the book animation in HUD-assets-ideas, without its tabs.

WHY THIS EXISTS
---------------
The bag's Diary tab shows her diary as a book that turns its pages (Kent's ask: "it should flip
like a book ... but i only want the book not the tabs because i already have an inventory tabs
thing"). The source is `HUD-assets-ideas/Book-Inventory-Animation.gif`, 45 frames of 150 x 158:
five cycles of a content page (an RPG's armour, items, skills, quests, map) followed by the same
eight-frame page turn. Only the turn is kept -- frames 1..8, blank pages, which is all a diary
needs: the words are set on them in Godot.

KEYING
------
Five ribbon tabs (Inventory, Items, Skills, Quest, Map) stand up out of the book's top edge. They
are tucked BEHIND the pages, and the page that turns rises over the cover's top edge while the
ribbons are still there, so they cannot be cropped off by row without cutting the turning page.
They are keyed by colour instead: the ribbons are painted in eight colours (reds, oranges and the
whites of their lettering) that the book itself never uses -- measured over every kept frame,
and `--check` fails if a ribbon colour is ever found below the cover's top edge, which is where
it would mean a colour was shared after all.

OUTPUT
------
`game/assets/hud/diary_book.png`: the eight frames side by side, each cropped to the same box
(the union of what is left in all eight), so a frame index is `x = index * FRAME_W`. Frame 7
(the last) is the book at rest; 0..7 in order is one page turned from right to left, and played
backwards it is a page turned back.

Usage:
    .venv/bin/python tools/build_diary_book.py           # write the strip
    .venv/bin/python tools/build_diary_book.py --check   # verify it is up to date
"""

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "HUD-assets-ideas" / "Book-Inventory-Animation.gif"
OUT = ROOT / "game" / "assets" / "hud" / "diary_book.png"

# One page turn: blank, the page lifting, crossing and settling, blank (GIF frames 1..8).
TURN = range(1, 9)
# The cover's top edge in the source frame; nothing below it is ribbon.
COVER_TOP = 48
# The ribbons' own colours. None is used anywhere in the book.
RIBBON = {
    (165, 48, 48), (228, 59, 68), (207, 87, 60), (117, 36, 56),
    (235, 237, 233), (247, 118, 34), (255, 255, 255), (199, 207, 204),
}


def frames() -> list[np.ndarray]:
    gif = Image.open(SOURCE)
    out = []
    for index in TURN:
        gif.seek(index)
        out.append(np.array(gif.convert("RGBA")))
    return out


def ribbon_mask(frame: np.ndarray) -> np.ndarray:
    mask = np.zeros(frame.shape[:2], dtype=bool)
    for colour in RIBBON:
        mask |= np.all(frame[:, :, :3] == colour, axis=2)
    return mask & (frame[:, :, 3] > 0)


def build() -> Image.Image:
    kept = []
    for frame in frames():
        mask = ribbon_mask(frame)
        if mask[COVER_TOP:].any():
            ys, xs = np.nonzero(mask[COVER_TOP:])
            raise SystemExit("a ribbon colour is used in the book at (%d, %d)" % (xs[0], ys[0] + COVER_TOP))
        frame = frame.copy()
        frame[mask] = 0
        kept.append(frame)
    solid = np.zeros(kept[0].shape[:2], dtype=bool)
    for frame in kept:
        solid |= frame[:, :, 3] > 0
    ys, xs = np.nonzero(solid)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    width, height = box[2] - box[0], box[3] - box[1]
    strip = Image.new("RGBA", (width * len(kept), height), (0, 0, 0, 0))
    for index, frame in enumerate(kept):
        strip.paste(Image.fromarray(frame).crop(box), (index * width, 0))
    return strip


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--check", action="store_true", help="fail if the strip is out of date")
    args = parser.parse_args()
    strip = build()
    if args.check:
        if not OUT.exists():
            sys.exit("missing: %s" % OUT.relative_to(ROOT))
        if not np.array_equal(np.array(Image.open(OUT).convert("RGBA")), np.array(strip)):
            sys.exit("out of date: %s -- run tools/build_diary_book.py" % OUT.relative_to(ROOT))
        print("diary book: up to date (%d frames of %d x %d)" % (len(TURN), strip.width // len(TURN), strip.height))
        return
    OUT.parent.mkdir(parents=True, exist_ok=True)
    strip.save(OUT)
    print("wrote %s (%d frames of %d x %d)" % (OUT.relative_to(ROOT), len(TURN), strip.width // len(TURN), strip.height))


if __name__ == "__main__":
    main()
