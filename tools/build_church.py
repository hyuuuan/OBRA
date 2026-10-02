#!/usr/bin/env python3
"""Pack the supplied church plates for Scene 2. No replacement art is generated.

The completed look is the composition reference. The rack moves to the left of the
altar to agree with Lolo's instruction; a short wall bay on the right accommodates
the live alley door. Both doors use the supplied doorway. Everything is fitted
offline, with one walk line at source row 790 and no foreground over the apo.

    python3 tools/build_church.py [--check]
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "level-2-assets/church"
OUT = ROOT / "game/assets/Level2/church"


def build() -> dict[str, Image.Image]:
    bg = Image.open(SRC / "CHURCH_BG.png").convert("RGBA")
    floor = Image.open(SRC / "CHURCH_FLOOR.png").convert("RGBA")
    furniture = Image.open(SRC / "CHURCH_ALTAR.png").convert("RGBA")
    assert bg.size == floor.size == furniture.size == (1672, 941)
    # Keep the original pixels; the extra bay is an undecorated slice of this wall.
    plate = Image.new("RGBA", (2072, 941), (15, 12, 8, 255))
    plate.alpha_composite(bg)
    plate.alpha_composite(bg.crop((1020, 0, 1420, 941)), (1672, 0))
    # Ignore stray low-alpha marks above the actual floor in the supplied cutout.
    plate.alpha_composite(floor.crop((0, 690, 1672, 890)), (0, 690))
    plate.alpha_composite(floor.crop((400, 740, 800, 890)), (1672, 740))

    def cut(box: tuple[int, int, int, int], width: int) -> Image.Image:
        art = furniture.crop(box)
        return art.resize((width, round(art.height * width / art.width)),
                          Image.Resampling.NEAREST)

    def stand(art: Image.Image, x: int, foot: int) -> None:
        plate.alpha_composite(art, (x - art.width // 2, foot - art.height))

    door = cut((80, 510, 268, 785), 160)
    # The plant overlaps the left edge of the arch on the sheet. Its matching right
    # jamb supplies a clean edge, without leaving detached leaves beside either door.
    door.paste(door.crop((142, 0, 160, door.height)).transpose(Image.Transpose.FLIP_LEFT_RIGHT),
               (0, 0))
    for x in (204, 1868):
        stand(door, x, 790)
    stand(cut((0, 590, 80, 786), 68), 70, 790)
    for x, box in zip((390, 530, 670, 810), (
        (316, 647, 468, 796), (476, 647, 626, 796),
        (635, 647, 785, 796), (792, 647, 942, 796),
    )):
        stand(cut(box, 126), x, 780)
    # The FLOOR already owns the dais: only put the altar above it, never a second stair.
    stand(cut((995, 220, 1412, 748), 380), 1230, 710)
    for x, box in zip((315, 660, 998), (
        (330, 455, 413, 612), (650, 455, 733, 612), (932, 450, 1004, 612),
    )):
        stand(cut(box, 62), x, 590)
    stand(cut((1414, 382, 1502, 476), 62), 1480, 487)
    # Rack remains a separate draw so placing the player's candle changes the picture.
    rack = cut((1432, 571, 1645, 792), 170)
    return {
        "nave.png": plate.crop((0, 70, 2072, 890)),
        "rack.png": rack,
        "candle.png": cut((1458, 597, 1485, 660), 24),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    images = build()
    if args.check:
        stale = []
        for name, expected in images.items():
            path = OUT / name
            if not path.exists():
                stale.append(name)
                continue
            with Image.open(path) as actual:
                if actual.size != expected.size or actual.convert("RGBA").tobytes() != expected.tobytes():
                    stale.append(name)
        if stale:
            print("Stale church assets: " + ", ".join(stale))
            return 1
        print("Church assets are up to date")
        return 0
    OUT.mkdir(parents=True, exist_ok=True)
    for name, art in images.items():
        art.save(OUT / name)
        print(f"wrote {(OUT / name).relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
