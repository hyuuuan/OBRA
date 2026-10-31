#!/usr/bin/env python3
"""Restore the earlier levels' actual scenery, without a rectangular painting behind it."""
import argparse
from pathlib import Path
from PIL import Image
import pixelart
ROOT=Path(__file__).resolve().parent.parent
ART=ROOT/'game/assets'
OUT=ART/'Level5/restoration'
SOURCES={
 'kubo':'Level1/hut.png',
 'terraces':'Level1/terraces_2.png',
 'bandaritas':'Level2/alley_1/bandaritas.png',
 'dancers':'Level2/dancers/dance_frame_01.png',
 'church':'Level2/church_facade.png',
 'storm':'Level3/storm/clouds.png',
 'bangka':ROOT/'LEVEL5_Mayon/authored/bangka_memory.png',
 'bakunawa':'Level3/bakunawa/turned_4.png',
 'forest':'Level4/backdrop/mountain_near.png',
 'waterfall':'Level4/backdrop/mountain_near.png',
 'flower':'Level1/hidden_flower.png',
}

def trimmed(path):
 image=Image.open(ART/path).convert('RGBA')
 return image.crop(image.getchannel('A').getbbox())

def main():
 parser=argparse.ArgumentParser()
 parser.add_argument('--check',action='store_true')
 pictures=pixelart.Pictures(parser.parse_args().check,ROOT)
 for ident,path in SOURCES.items():
  pictures.put(trimmed(path),OUT/f'{ident}.png')
 coral=Image.new('RGBA',(640,400))
 for path,x,width in [('Level3/props/coral_blue_0.png',0,260),('Level3/props/kelp_long_0.png',180,130),('Level3/props/coral_orange_0.png',290,200),('Level3/props/coral_violet_0.png',440,200)]:
  image=trimmed(path)
  image=image.resize((width,round(image.height*width/image.width)),Image.Resampling.NEAREST)
  coral.alpha_composite(image,(x,400-image.height))
 pictures.put(coral.crop(coral.getchannel('A').getbbox()),OUT/'coral.png')
 if pictures.stale: raise SystemExit('Stale restoration: '+', '.join(pictures.stale))

if __name__=='__main__': main()
