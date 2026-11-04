#!/usr/bin/env python3
"""Registered, opaque memory backdrops and a silhouette cut from the delivered Makiling plate.

These are scenery, never screenshots of running levels. Original artist files stay untouched.
"""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "game/assets"
OUT = ASSETS / "Level5/journey"


def extend_own_ground(layer):
    """Continue a landscape's own lower texture, never a roof, pole or composite sky."""
    pixels=layer.load()
    occupied=[]
    for x in range(layer.width):
        covered=[y for y in range(layer.height) if pixels[x,y][3]>=240]
        if not covered:
            continue
        occupied.append(x)
        bottom=covered[-1]
        strip=[pixels[x,y] for y in range(max(covered[0],bottom-24),bottom+1)
               if pixels[x,y][3]>=240]
        for y in range(bottom+1,layer.height):
            rgb=strip[(y-bottom-1)%len(strip)]
            pixels[x,y]=(rgb[0],rgb[1],rgb[2],255)
    if occupied:
        # Remove only the delivery's outside padding. Interior negative space stays authored.
        for start,stop,source_x in [(0,occupied[0],occupied[0]),
                                    (occupied[-1]+1,layer.width,occupied[-1])]:
            for x in range(start,stop):
                for y in range(layer.height):
                    pixels[x,y]=pixels[source_x,y]
    return layer


def clean_alpha(image):
    image.putalpha(image.getchannel("A").point(lambda alpha: alpha if alpha>=24 else 0))
    return image


def build():
    sky = Image.new("RGBA", (1920, 1080), (33, 142, 239, 255))
    for name in ["bg_withclouds", "mountains_furthest_background", "mountain_further_background"]:
        layer = Image.open(ASSETS / f"Level1/{name}.png").convert("RGBA")
        if name == "mountain_further_background":
            # The delivered mountains have an irregular lower alpha cut. Continue their own
            # forest downwards; otherwise the sky reappears underneath a suspended landscape.
            layer=extend_own_ground(layer)
        sky.alpha_composite(layer)
    # Paper-margin padding in the delivery must not repeat as vertical sky-coloured bars.
    sky = sky.crop((150, 80, 1770, 880))
    outputs = {"payyo_sky.png": sky}
    for name in ["shore", "sea", "forest", "dawn", "plaza"]:
        base = Image.new("RGBA", (1672, 941), (22, 49, 64, 255))
        if name == "shore":
            base.paste((86, 179, 222, 255), (0, 0, 1672, 941))
            sources = ["Level3/shore/sky.png", "Level3/shore/mountains.png", "Level3/shore/ocean.png"]
        elif name == "sea":
            sources = ["Level3/deep/water.png"]
        elif name in ["forest", "dawn"]:
            sources = ["Level4/backdrop/mountain_far.png", "Level4/backdrop/mountain_near.png"]
            base.paste((31, 45, 58, 255), (0, 0, 1672, 941))
        else:
            base = Image.new("RGBA", (5760, 761), (0, 136, 253, 255))
            sources = ["Level2/plaza_backdrop.png"]
        for source in sources:
            layer = Image.open(ASSETS / source).convert("RGBA")
            if source == "Level3/shore/ocean.png":
                layer=extend_own_ground(layer)
            base.alpha_composite(layer)
        if name in ["forest", "dawn"]:
            # Register the walk line above the supplied lower mist/alpha cut. Extending those
            # pale edge pixels repeats them as a bright fence underneath the forest.
            base=base.crop((0,0,base.width,760))
            # Grade only the landscape; the player stays readable as in the original level.
            if name == "forest":
                shade = Image.new("RGBA",base.size,(26,35,57,145))
                base = Image.alpha_composite(base,shade)
            else:
                shade = Image.new("RGBA",base.size,(235,185,127,45))
                base = Image.alpha_composite(base,shade)
        if name == "shore":
            # Discard the ocean delivery's translucent blue cuts at its outside edges.
            base = base.crop((32, 0, base.width-32, base.height))
        outputs[name+"_sky.png"] = base
    # The nave's lower plinth is not a second floor behind the player.
    nave = Image.open(ASSETS/"Level2/church/nave.png").convert("RGBA")
    outputs["church_sky.png"] = nave.crop((0, 0, nave.width, 734))
    # The storefront delivery has 1-alpha noise below the painted buildings. Their real feet
    # are row 806, not the canvas's last row. Align the short alley to those feet.
    storefront=clean_alpha(Image.open(ASSETS/"Level2/alley_1/store.png").convert("RGBA"))
    walk_line=storefront.getchannel("A").getbbox()[3]
    alley=Image.new("RGBA",(1448,1087),(252,192,89,255))
    for source in ["sky","store","ground"]:
        part=clean_alpha(Image.open(ASSETS/f"Level2/alley_1/{source}.png").convert("RGBA"))
        alley.alpha_composite(part)
    outputs["alley_sky.png"]=alley.crop((0,0,alley.width,walk_line))
    # Keep Dagat's own sand cap over its underwater stone; do not use the reef's bare floor.
    home=Image.open(ASSETS/"Level3/authored/land_home.png").convert("RGBA")
    outputs["sand_ground.png"]=home.crop((64,4,1400,244))
    plate = Image.open(ROOT / "Painting_Covers/Level 4 Completed Look from Mayon.png").convert("RGBA")
    falls = plate.crop((1040, 440, 1420, 760))
    mask = Image.new("L",falls.size)
    ImageDraw.Draw(mask).polygon([(130,0),(238,0),(280,28),(302,73),(347,112),(379,180),
                                  (365,266),(327,319),(28,319),(0,269),(24,211),(57,172),
                                  (83,123),(91,66)],fill=255)
    falls.putalpha(ImageChops.multiply(falls.getchannel("A"),mask.filter(ImageFilter.GaussianBlur(4))))
    outputs["waterfall.png"] = falls
    # Canvas margins belong to the original registration, not a prop's ground anchor.
    # The complete dance frames retain their shared canvas and are deliberately not cut.
    for ident, source in {
        "terraces": "Level1/terraces_2.png", "kubo": "Level1/hut.png",
        "bandaritas": "Level2/alley_1/bandaritas.png", "church": "Level2/church/rack.png",
        "storm": "Level3/storm/clouds.png", "bangka": "Level3/authored/bangka_beached.png",
        "forest": "Level5/props/tree_broadleaf.png", "flower": "Level1/hidden_flower.png",
        "palms": "Level3/authored/palms_island.png",
    }.items():
        original = clean_alpha(Image.open(ASSETS/source).convert("RGBA"))
        outputs[ident+"_landmark.png"] = original.crop(original.getchannel("A").getbbox())
    return outputs


def main():
    check = argparse.ArgumentParser()
    check.add_argument("--check",action="store_true")
    args = check.parse_args()
    stale = []
    for name, image in build().items():
        path = OUT / name
        if args.check:
            if not path.exists() or Image.open(path).convert("RGBA").tobytes() != image.tobytes():
                stale.append(name)
        else:
            OUT.mkdir(parents=True,exist_ok=True)
            image.save(path)
    if stale:
        raise SystemExit("Stale Mayon journey art: "+", ".join(stale))


if __name__ == "__main__":
    main()
