#!/usr/bin/env python3
"""Cut Mayon's actor atlases and supplied Lola performance board into game sprites.

This is extraction, not sprite recolouring: originals and prompts are retained in
LEVEL5_Mayon/authored. One scale per actor preserves head size in seated poses.
"""
from pathlib import Path
import argparse
from PIL import Image
import numpy as np
from scipy import ndimage
import pixelart
from build_portrait_outlines import outlined

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'LEVEL5_Mayon/authored'
OUT = ROOT / 'game/assets/Level5'
APO = ['raise', 'paint', 'failed', 'lower', 'seated', 'seated_paint', 'offer', 'pickup']
# Cells the atlases still hold but the game no longer shows: the real room went when the run
# began ending in the house (#182). The lists above stay whole because they name the atlas's
# cells in order; these are only not written. frame_room.png is kept with the other originals.
RETIRED = {'seated', 'seated_flowers', 'seated_paint', 'pickup'}
LOLA_CELL = (128, 144)
LOLA_HEIGHT = 108


def silhouette(sheet, region):
    """Extract an actor without disconnected tips from an adjacent atlas cell."""
    frame = sheet.crop(region)
    alpha = np.asarray(frame.getchannel('A')).copy()
    components, _ = ndimage.label(alpha >= 32, structure=np.ones((3, 3)))
    areas = np.bincount(components.ravel())
    areas[0] = 0
    alpha[components != int(areas.argmax())] = 0
    frame.putalpha(Image.fromarray(alpha))
    return frame


def registered_strip(frames, walking=False):
    bounds = [frame.getbbox() for frame in frames]
    scale = LOLA_HEIGHT / max(box[3] - box[1] for box in bounds)
    baseline = max(box[3] for box in bounds)
    strip = Image.new('RGBA', (LOLA_CELL[0] * len(frames), LOLA_CELL[1]))
    for i, frame in enumerate(frames):
        bottom = baseline if walking else bounds[i][3]
        feet = frame.crop((0, bottom - 10, frame.width, bottom)).getbbox()
        centre = frame.width / 2 if walking else (feet[0] + feet[2]) / 2
        size = (round(frame.width * scale), round(frame.height * scale))
        strip.alpha_composite(frame.resize(size, Image.Resampling.NEAREST),
                              (i * LOLA_CELL[0] + LOLA_CELL[0] // 2 - round(centre * scale),
                               LOLA_CELL[1] - round(bottom * scale)))
    return strip


def lola_assets():
    sheet = Image.open(SOURCE / 'lola_supplied_sheet.png').convert('RGBA')
    sheet.putalpha(sheet.getchannel('A').point(lambda a: a if a >= 32 else 0))
    regions = {
        'front': (310, 30, 410, 190),
        'turn': (595, 30, 690, 190),
        'back': (875, 30, 985, 190),
        'flowers': (285, 410, 385, 550),
        'remember': (405, 410, 510, 550),
    }
    for pose, region in regions.items():
        frame = silhouette(sheet, region)
        yield pose, registered_strip([frame])
    walks = [silhouette(sheet, (295 + i * 119, 250, 405 + i * 119, 385)) for i in range(6)]
    yield 'walk', registered_strip(walks, walking=True)
    # Two supplied six-frame painting loops, then six pause/idle variations.
    painting = Image.new('RGBA', (18 * LOLA_CELL[0], LOLA_CELL[1]))
    for row, (top, bottom) in enumerate([(800, 975), (1020, 1205), (1250, 1445)]):
        poses = [silhouette(sheet, (30 + i * 165, top, 170 + i * 165, bottom)) for i in range(6)]
        # The board draws its three animation rows at different source sizes.
        painting.alpha_composite(registered_strip(poses), (row * 6 * LOLA_CELL[0], 0))
    yield 'painting_idle', painting
    yield 'paint', painting.crop((3 * LOLA_CELL[0], 0, 4 * LOLA_CELL[0], LOLA_CELL[1]))
    portrait = silhouette(sheet, (30, 65, 245, 338))
    yield 'portrait', outlined(portrait.crop(portrait.getbbox()))


def atlas(name, poses, height, cell):
    sheet = Image.open(SOURCE / name).convert('RGBA')
    w, h = sheet.width // 4, sheet.height // 2
    # The generated transparent margin is not part of the character's registration.
    boxes = []
    for i in range(8):
        frame = sheet.crop((i % 4 * w, i // 4 * h, (i % 4 + 1) * w, (i // 4 + 1) * h))
        box = frame.getchannel('A').point(lambda a: 255 if a >= 32 else 0).getbbox()
        boxes.append(frame.crop(box))
    scale = height / max(p.height for p in boxes[:4])
    for pose, frame in zip(poses, boxes):
        size = (round(frame.width * scale), round(frame.height * scale))
        frame = frame.resize(size, Image.Resampling.NEAREST)
        result = Image.new('RGBA', cell)
        result.alpha_composite(frame, ((cell[0] - size[0]) // 2, cell[1] - size[1]))
        yield pose, result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    pictures = pixelart.Pictures(args.check, ROOT)
    for who, source, poses, height, cell in [
        ('apo', 'apo_performance_atlas.png', APO, 96, (112, 112)),
    ]:
        for pose, image in atlas(source, poses, height, cell):
            if pose not in RETIRED:
                pictures.put(image, OUT / 'people' / f'{who}_{pose}.png')
    for pose, image in lola_assets():
        pictures.put(image, OUT / 'people' / f'lola_{pose}.png')
    if pictures.stale:
        raise SystemExit('Stale performance assets: ' + ', '.join(pictures.stale))


if __name__ == '__main__':
    main()
