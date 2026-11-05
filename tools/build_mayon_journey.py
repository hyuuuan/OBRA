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


def registered_frames(pattern, count):
    """Keep the delivery's common canvas registration while removing its outside padding."""
    frames=[clean_alpha(Image.open(ASSETS/pattern.format(i)).convert("RGBA")) for i in range(count)]
    boxes=[frame.getchannel("A").getbbox() for frame in frames]
    box=(min(b[0] for b in boxes),min(b[1] for b in boxes),
         max(b[2] for b in boxes),max(b[3] for b in boxes))
    return [frame.crop(box) for frame in frames]


def plaza_people(source):
    """Keep the clear figures and arch from Piyesta, with continuous pillar stems."""
    original = Image.open(source / "mg_people.png").convert("RGBA")
    people = Image.open(source / "mg_people_nodancers.png").convert("RGBA")
    join, bottom = 634, 818
    overlap = 8
    for start, end, left, right, period in [
        (685, 807, 696, 782, 49),
        (1162, 1272, 1184, 1263, 45),
    ]:
        # The pillars curve above the dancers. Align each clean row to the
        # upright, keeping some of the original variation in its silhouette.
        rows = []
        for y in range(join - period - overlap, join):
            row = original.crop((start, y, end, y + 1))
            edge = row.getchannel("A").point(lambda value: 255 if value > 24 else 0).getbbox()
            row = row.crop((edge[0] - 1, 0, edge[2] + 1, 1))
            width = round((right - left) * 0.75 + row.width * 0.25)
            aligned = Image.new("RGBA", (end - start, 1))
            aligned.paste(row.resize((width, 1), Image.Resampling.NEAREST),
                          ((left + right - width) // 2 - start, 0))
            rows.append(aligned)

        for y in range(join - overlap, bottom):
            phase = (y - join + overlap) % period
            row = rows[phase]
            if phase < overlap:
                previous = original.crop((start, y, end, y + 1)) if y < join else rows[period + phase]
                row = Image.blend(previous, row, (phase + 1) / overlap)
            people.paste(row, (start, y))
    return people


def plaza_backdrop():
    """Composite Piyesta's registered plates at the same walk line as Level 2."""
    source = ASSETS / "Level2"
    with Image.open(source / "plaza_backdrop.png") as plate:
        width, height = plate.size
        sky_column = plate.crop((0, 0, 1, height)).convert("RGBA")
    town = Image.new("RGBA", (width, height), (0, 136, 253, 255))
    town.alpha_composite(sky_column.resize(town.size, Image.Resampling.NEAREST))

    with Image.open(source / "bg_sky.png") as sky:
        top = sky.getchannel("A").point(lambda value: 255 if value > 8 else 0).getbbox()[1]
    for name in ["bg_sky", "bg_clouds", "mg_church", "mg_people", "fg_huts"]:
        layer = plaza_people(source) if name == "mg_people" else Image.open(source / f"{name}.png").convert("RGBA")
        town.alpha_composite(layer.crop((0, top, layer.width, top + height)), ((width - layer.width) // 2, 0))
    return town


def rice_beds():
    """Side-view rice grows out of three stone banks, in the delivery's own palette."""
    result=Image.new("RGBA",(900,276))
    stone=Image.open(ASSETS/"Level1/cliff/face.png").convert("RGBA")
    for row,(x,y,width) in enumerate([(212,0,476),(104,86,692),(0,172,900)]):
        field=Image.new("RGBA",(width//2,52))
        draw=ImageDraw.Draw(field)
        for clump in range(3,width//2-2,7):
            root=27+(clump+row)%3
            for stem in range(3):
                height=14+(clump*13+stem*7+row*3)%11
                lean=stem*3-3
                tip=(clump+lean,root-height)
                draw.line([(clump,root),tip],fill="#7a9b24",width=1)
                draw.line([(clump,root-3),(clump-4,root-10)],fill="#a7b332",width=1)
                draw.line([(clump+1,root-4),(clump+5,root-9)],fill="#c8c33f",width=1)
                draw.line([tip,(tip[0]+2,tip[1]+4)],fill="#c79b24",width=2)
                draw.line([(tip[0],tip[1]),(tip[0]+1,tip[1]+2)],fill="#e6ce53",width=1)
        field=field.resize((width,104),Image.Resampling.NEAREST)
        # Use the opaque interior stone under a shallow grass lip, never a paper border.
        bank=stone.crop((0,8,width,54))
        field.alpha_composite(bank,(0,58))
        result.alpha_composite(field,(x,y))
    return result


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
    outputs = {"payyo_sky.png": sky, "plaza_sky.png": plaza_backdrop()}
    for name in ["shore", "sea", "forest", "dawn"]:
        base = Image.new("RGBA", (1672, 941), (22, 49, 64, 255))
        if name == "shore":
            base.paste((86, 179, 222, 255), (0, 0, 1672, 941))
            sources = ["Level3/shore/sky.png", "Level3/shore/mountains.png", "Level3/shore/ocean.png"]
        elif name == "sea":
            sources = ["Level3/deep/water.png"]
        elif name in ["forest", "dawn"]:
            sources = ["Level4/backdrop/mountain_far.png", "Level4/backdrop/mountain_near.png"]
            base.paste((31, 45, 58, 255), (0, 0, 1672, 941))
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
    alpha=ImageChops.multiply(falls.getchannel("A"),mask.filter(ImageFilter.GaussianBlur(4)))
    # The upper crop is forest haze rather than a hard silhouette. Fade its registration
    # edge into the live forest, so the waterfall never carries a rectangular patch of sky.
    haze=Image.new("L",falls.size,255)
    haze_draw=ImageDraw.Draw(haze)
    for row in range(64):
        t=row/63
        haze_draw.line((0,row,falls.width,row),fill=round(255*t*t*(3-2*t)))
    falls.putalpha(ImageChops.multiply(alpha,haze))
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
    atlas=Image.open(ASSETS/"Level1/texturemap.png").convert("RGBA")
    outputs["rice_beds.png"]=rice_beds()
    # These pieces already belong together in the original Payyo atlas. Preserve their
    # proportions and assemble the yard in world coordinates instead of scaling a collage.
    for name,box in {
        "fence":(738,912,818,959), "gate":(830,912,888,960),
        "pot":(899,912,931,961), "bamboo":(946,907,988,963),
        "stone_lamp":(996,906,1046,965),
    }.items():
        prop=clean_alpha(atlas.crop(box))
        outputs["payyo_"+name+".png"]=prop.crop(prop.getchannel("A").getbbox())
    for name,source in {
        "payyo_bank":"Level1/terraces_near_background.png",
        "shore_jetty":"Level3/authored/jetty.png",
        "deep_terraces":"Level3/deep/terraces.png",
        "deep_ridges":"Level3/deep/ridges.png",
    }.items():
        image=clean_alpha(Image.open(ASSETS/source).convert("RGBA"))
        outputs[name+".png"]=image.crop(image.getchannel("A").getbbox())
    for name,pattern,count in [
        ("kelp_long","Level3/props/kelp_long_{}.png",3),
        ("kelp_short","Level3/props/kelp_short_{}.png",3),
        ("coral_red","Level3/props/coral_red_{}.png",3),
        ("coral_orange","Level3/props/coral_orange_{}.png",3),
        ("fish_school","Level3/ambience/school_{}.png",4),
        ("bakunawa","Level3/bakunawa/searching_{}.png",13),
        ("surf","Level3/shore/surf_{}.png",3),
    ]:
        for index,frame in enumerate(registered_frames(pattern,count)):
            outputs[f"{name}_{index:02d}.png"]=frame
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
