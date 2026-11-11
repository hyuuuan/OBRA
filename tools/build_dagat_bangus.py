#!/usr/bin/env python3
"""Import the three supplied Dagat fish poses onto one transparent strip."""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "LEVEL3_Dagat/creatures/fish.JPG"
OUTPUT = ROOT / "game/assets/Level3/creatures/bangus_swim.png"
CELL = (120, 36)
EYE_ROWS = (285, 741, 1184)


def frame(source: Image.Image, eye_y: int) -> Image.Image:
    # All three pupils share an x. Register their y so the tail moves around a steady head.
    pose = source.crop((33, eye_y - 128, 993, eye_y + 160))
    red, green, blue = pose.split()
    paper = ImageChops.darker(red, ImageChops.darker(green, blue)).point(
        lambda value: 255 if value >= 190 else 0
    )
    # Only the connected page goes transparent. The pale scales inside the outline stay.
    ImageDraw.floodfill(paper, (0, 0), 128)
    pose.putalpha(paper.point(lambda value: 0 if value == 128 else 255))
    return pose.resize(CELL, Image.Resampling.BOX)


def main() -> None:
    with Image.open(SOURCE) as image:
        source = image.convert("RGB")
    if source.size != (1024, 1536):
        raise ValueError("Fish sheet dimensions changed. Re-measure the frame regions.")
    strip = Image.new("RGBA", (CELL[0] * len(EYE_ROWS), CELL[1]))
    for index, eye_y in enumerate(EYE_ROWS):
        strip.paste(frame(source, eye_y), (index * CELL[0], 0))
    strip.save(OUTPUT)


if __name__ == "__main__":
    main()
