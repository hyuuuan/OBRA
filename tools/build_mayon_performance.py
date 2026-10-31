#!/usr/bin/env python3
"""Cut the original generated Mayon performance atlases into registered game sprites.

This is extraction, not sprite recolouring: originals and prompts are retained in
LEVEL5_Mayon/authored. One scale per actor preserves head size in seated poses.
"""
from pathlib import Path
import argparse
from PIL import Image
import pixelart
from build_portrait_outlines import outlined

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'LEVEL5_Mayon/authored'
OUT = ROOT / 'game/assets/Level5'
LOLA = ['back', 'paint', 'turn', 'front', 'flowers', 'remember', 'seated', 'seated_flowers']
APO = ['raise', 'paint', 'failed', 'lower', 'seated', 'seated_paint', 'offer', 'pickup']


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
        ('lola', 'lola_atlas.png', LOLA, 124, (128, 144)),
        ('apo', 'apo_performance_atlas.png', APO, 96, (112, 112)),
    ]:
        for pose, image in atlas(source, poses, height, cell):
            pictures.put(image, OUT / 'people' / f'{who}_{pose}.png')
    sheet = Image.open(SOURCE / 'lola_atlas.png').convert('RGBA')
    portrait = sheet.crop((1152 + 52, 54, 1536 - 48, 405))
    # The same silhouette contract as the other dialogue speakers; this crop already
    # ends below the hands, so it is a complete bust rather than another sprite cell.
    portrait = outlined(portrait)
    portrait = portrait.resize((round(portrait.width * 220 / portrait.height), 220), Image.Resampling.NEAREST)
    pictures.put(portrait, OUT / 'people/lola_portrait.png')
    room = Image.open(SOURCE / 'frame_room.png').convert('RGBA')
    pictures.put(room.resize((1600, 900), Image.Resampling.NEAREST), OUT / 'frame/room.png')
    if pictures.stale:
        raise SystemExit('Stale performance assets: ' + ', '.join(pictures.stale))


if __name__ == '__main__':
    main()
