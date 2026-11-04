# Dark forest ground — 4 November 2026

Built-in image generation produced `ground_source.png` and `foliage_source.png` from the
user's `reference.png`. The exact two prompts are saved beside them. The target is the
reference's chunky shaded brown blocks and detailed jungle plants, with deep green leaves.

Runtime kit: `game/assets/Level4/ground_forest/`. Both Level 4 ground dressings use it.
The previous `ground_mossy` source and kit remain available separately.

Rebuild with:

```sh
godot --headless --path game --script res://tools/build_forest_ground.gd
godot --headless --path game --import
```

The cutter uses nearest-neighbour resizing and a minimum-error pixel seam in an overlapping
strip to make the horizontal wrap continuous without blended stones. `face.png` is
384 × 256; `ground_tileset.tres` exposes it as 24 tiles of 64 × 64 for editor use. The six
surface tiles are a repeating sequence, not six interchangeable randomized top tiles.
The runtime keeps the strip in world phase across platform joins.

The foliage sheet supplies four transparent plants (bush, fern, shrub with a rock, and mossy
rocks) plus two short face-vine clusters. The cutter removes translucent generation halos
by alpha only, preserving solid dark outlines. Plants retain their bottom-centre anchors;
vines attach just under the cap, inset from open ends. Level 4's existing night tint,
darkness, terrain collisions, branches and moonlight rims apply.

`repeat_preview.png` shows three complete repetitions and all six foliage assets.
