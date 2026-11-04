# Dilim ground

`ground_mossy.png` is the full-size source generated with the built-in image generation tool
on 2026-11-04. `ground_mossy.prompt.txt` records the exact prompt; `ground_cap_reference.png`
and `ground_body_reference.png` are the two references supplied by the user. The earlier
flat layered-earth attempt was rejected as too simple.

The runtime copy is `game/assets/Level4/ground_mossy/face.png`, reduced to 384 x 256:

```sh
sips --resampleHeightWidth 256 384 LEVEL4_Mt.Makiling/authored/ground_mossy.png --out game/assets/Level4/ground_mossy/face.png
godot --headless --path game --import
```

Both mud and stone dressings use this block. `kit.json` supplies a 30 px moss band, a soil-only
repeat starting at row 52, no extra leaf spill and no plant stamps. The original detailed kits
remain separate, so running `tools/build_cliff_kits.py` does not overwrite this asset.
