# Supplied moonlit ground — 4 November 2026

`reference.png` is the user's supplied 2172 × 724 artwork. This kit is cut directly from
that image to preserve the requested art style and level of pixelation. It is not redrawn
or regenerated. No resizing, RGB smoothing or global color limit is applied.

Rebuild:

```sh
godot --headless --path game --script res://tools/build_moonlit_ground.gd
godot --headless --path game --import
```

Runtime ground: `game/assets/Level4/ground_moonlit/`.

- `face.png`: 1216 × 448. Four clear wall sections are joined by minimum-error pixel cuts
  and closed into a horizontal repeat. Cuts choose original source pixels without blending.
- `ground_tileset.tres`: 19 × 7 atlas of 64 × 64 cells. The top row forms a repeating sequence;
  its tiles are not interchangeable random variants.
- `kit.json`: the moss lip and underground repeat, with zero plants or vines.

Separate foliage: `game/assets/Level4/foliage_moonlit/`.

- `plant_0..3.png`: original mossy rocks, broadleaf bush, fern and bush beside a rock.
- `vine_0..1.png`: original hanging leaf clusters with the brown wall removed.
- `foliage.json`: native-size plant spacing and vine attachment offset.

The original color-key cutout erased dark navy leaf interiors along with the background.
Color now seeds a silhouette mask; a 7 px close and enclosed-hole fill restore interior
shadows using source RGB. Recovered vine pixels painted over brown wall use dark leaf-shadow
color rather than restoring the wall. The walk-line strip is cropped out of bush exports.

`cuts.json` records the crop recipe. Sprite boxes are measured in the 2048 px chat preview
and mapped to the original resolution by the cutter. `repeat_preview.png` shows two repeats
and all six sprites at native size.

Both Level 4 dressings use this kit with a white tint: the artwork already contains moonlight.
The level's darkness still controls visibility. `BackgroundBushes` and `GroundVines` are
independent scene layers using `moonlit_foliage_2d.gd`. Bushes draw behind the ground, vines
on the face, and both below Nuno's spirit and every creature. Placement checks the complete
sprite bounds against existing encounter trigger volumes (including the finale), hazards,
supplies and ink jars; those places stay free of decoration. Other levels retain their
existing plant spacing and tints. Terrain collision, branches and moonlight rims retain
their existing roles. `run_moonlit_foliage_probe` guards the export and visibility fixes.

Windowed review: `res://tests/run_visual_moonlit_foliage.gd` photographs an intact quiet-path
bush, Nuno at his mound, and two spawned aswang in the finale. Reviewed captures are saved as
`foliage_fixed.png`, `nuno_clear.png` and `aswang_clear.png` beside this file.
