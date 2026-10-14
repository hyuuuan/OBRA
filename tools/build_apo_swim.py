#!/usr/bin/env python3
"""Import the supplied swim sheet without redrawing or resampling its pixels.

Run `python3 tools/build_apo_swim.py` after replacing source/swim_reference.png.
The presentation headings are outside the measured frame regions. Chroma keys
the dark neutral page; the cream shirt registers each frame at a shared torso
anchor, so bubbles, hands and kicking boots cannot move the body between cells.
"""

from collections import deque
from io import BytesIO
from pathlib import Path
import argparse
from statistics import median

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game/assets/characters/apo"
SOURCE = OUT / "source/swim_reference.png"
CELL = 320
# Half-open source regions, measured between figures, below each heading.
ROWS = {
    "swim_right": (80, 280, [8, 198, 374, 546, 734, 922, 1114]),
    "swim_left": (345, 550, [20, 212, 399, 582, 758, 931, 1114]),
    "swim_idle_side": (615, 820, [30, 285, 560, 835, 1105]),
    "swim_idle_front": (890, 1100, [30, 285, 560, 835, 1105]),
    "swim_float": (1140, 1390, [30, 285, 560, 835, 1105]),
}


def extract(image: Image.Image) -> tuple[Image.Image, tuple[int, int]]:
    width, height = image.size
    pixels = list(image.getdata())
    mask = [max(p) - min(p) > 10 or max(p) > 60 for p in pixels]
    # Tiny warm components are page lettering/adjacent-frame fragments. Keep
    # detached blue bubbles, including their small highlights, at their positions.
    visited = set()
    for start, solid in enumerate(mask):
        if not solid or start in visited:
            continue
        queue = deque([start])
        visited.add(start)
        component = []
        while queue:
            index = queue.popleft()
            component.append(index)
            x, y = index % width, index // width
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                other = ny * width + nx
                if (0 <= nx < width and 0 <= ny < height
                        and mask[other] and other not in visited):
                    visited.add(other)
                    queue.append(other)
        blue = any(pixels[i][2] > pixels[i][0] + 10 for i in component)
        if len(component) < 64 and not blue:
            for index in component:
                mask[index] = False
    # Restore enclosed black facial ink, but reopen page visible through limbs
    # and bubble rings. Never fill a bubble with the dark presentation background.
    seen = set()
    for start, solid in enumerate(mask):
        if solid or start in seen:
            continue
        queue = deque([start])
        seen.add(start)
        pocket = []
        border = False
        while queue:
            index = queue.popleft()
            pocket.append(index)
            x, y = index % width, index // width
            border |= x in (0, width - 1) or y in (0, height - 1)
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                other = ny * width + nx
                if (0 <= nx < width and 0 <= ny < height
                        and not mask[other] and other not in seen):
                    seen.add(other)
                    queue.append(other)
        if not border and median(max(pixels[i]) for i in pocket) < 14:
            for index in pocket:
                mask[index] = True
    shirt = [(i % width, i // width) for i, (r, g, b) in enumerate(pixels)
             if mask[i] and r > 150 and g > 145 and b > 70
             and 0 <= r - g < 30 and 15 < g - b < 75]
    if not shirt:
        raise ValueError("No cream shirt in measured frame")
    anchor = tuple(round(sum(p[axis] for p in shirt) / len(shirt)) for axis in (0, 1))
    result = Image.new("RGBA", image.size)
    result.putdata([(*p, 255) if solid else (0, 0, 0, 0)
                    for p, solid in zip(pixels, mask)])
    return result, anchor


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    sheet = Image.open(SOURCE).convert("RGB")
    if sheet.size != (1122, 1402):
        raise ValueError("Redelivery needs remeasured regions (expected 1122 x 1402)")
    for name, (top, bottom, columns) in ROWS.items():
        strip = Image.new("RGBA", (CELL * (len(columns) - 1), CELL))
        for frame, (left, right) in enumerate(zip(columns, columns[1:])):
            image, (anchor_x, anchor_y) = extract(sheet.crop((left, top, right, bottom)))
            bounds = image.getbbox()
            if bounds is None:
                raise ValueError(f"Empty {name} frame {frame}")
            x, y = CELL // 2 - anchor_x, CELL // 2 - anchor_y
            if not (0 <= x + bounds[0] < x + bounds[2] <= CELL
                    and 0 <= y + bounds[1] < y + bounds[3] <= CELL):
                raise ValueError(f"Clipped {name} frame {frame}")
            strip.alpha_composite(image, (frame * CELL + x, y))
        path = OUT / f"apo_{name}.png"
        buffer = BytesIO()
        strip.save(buffer, format="PNG")
        if args.check:
            if not path.exists() or path.read_bytes() != buffer.getvalue():
                raise SystemExit(f"Stale import: {path}")
        else:
            path.write_bytes(buffer.getvalue())
        print(f"{path.relative_to(ROOT)}: {len(columns) - 1} frames")


if __name__ == "__main__":
    main()
