#!/usr/bin/env python3
"""Build Mayon's registered vista and new cliff cuts; source plates remain untouched."""
import argparse
from pathlib import Path
from PIL import Image
import pixelart
ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT/'LEVEL5_Mayon/authored'
OUT = ROOT/'game/assets/Level5'

def main():
    args=argparse.ArgumentParser()
    args.add_argument('--check',action='store_true')
    pictures=pixelart.Pictures(args.parse_args().check, ROOT)
    # These exports have different authored offsets, despite their equal canvas sizes.
    # Flatten the measured foot composition once; vertical parallax cannot split it later.
    vista=Image.new('RGBA',(1672,730),(165,99,64,255))
    for name,y in [('sky',-60),('volcano',-220),('meadow',20)]:
        vista.alpha_composite(Image.open(OUT/'backdrop'/f'{name}.png').convert('RGBA'),(0,y))
    pictures.put(vista,OUT/'backdrop/foot_vista.png')
    pictures.put(Image.open(SRC/'upper_slope.png').convert('RGBA'),OUT/'backdrop/upper_vista.png')
    atlas=Image.open(SRC/'cliff_atlas.png').convert('RGBA')
    for name, box in [('meadow',(0,76,1536,335)),('basalt',(0,383,1536,652)),('ash',(0,691,1536,997))]:
        pictures.put(atlas.crop(box),OUT/'terrain'/f'{name}.png')
    # Dedicated left-facing cliff ends. Preserve alpha and aspect ratio: these are
    # painted corner overlays, not horizontal cliff strips bent into vertical shapes.
    edges=Image.open(SRC/'cliff_edges.png').convert('RGBA')
    for index,name in enumerate(('meadow','basalt','ash')):
        cell=edges.crop((index*512,0,(index+1)*512,1024))
        bounds=cell.getchannel('A').point(lambda v:255 if v>24 else 0).getbbox()
        edge=cell.crop(bounds)
        edge=edge.resize((128,round(edge.height*128/edge.width)),Image.Resampling.NEAREST)
        pictures.put(edge,OUT/'terrain'/f'edge_{name}.png')
    props=Image.open(SRC/'ruin_props.png').convert('RGBA')
    for name,box,longest in [('old_crossing',(0,170,780,460),330),('old_steps',(760,0,1240,590),220),('basalt_column',(0,580,600,1250),380),('broken_arch',(600,600,1260,1240),330)]:
        image=props.crop(box)
        bounds=image.getchannel('A').point(lambda v:255 if v>24 else 0).getbbox()
        image=image.crop(bounds)
        scale=longest/max(image.size)
        image=image.resize((round(image.width*scale),round(image.height*scale)),Image.Resampling.NEAREST)
        pictures.put(image,OUT/'props'/f'{name}.png')
    if pictures.stale:
        raise SystemExit('Stale landscapes: '+', '.join(pictures.stale))

if __name__=='__main__': main()
