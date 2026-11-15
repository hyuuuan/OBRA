# Supplied Dilim trees — 5 November 2026

`kapre_reference.png` is the user's first image, the buttressed trunk with a west-facing
branch and hanging vines. `forest_reference.png` is the second image, the bare hollow tree.
Both originals retain their supplied transparency and colors.

Rebuild from the repository root:

```sh
godot --headless --path game --script res://tools/build_dilim_trees.gd
godot --headless --path game --import
```

Verify exports without writing them by adding `-- --check` to the first command.
The builder removes only alpha below 24/255, then uses nearest-neighbor fitting; it does
not key dark bark or recolor either image.

Outputs live separately in `game/assets/Level4/trees/`, so rebuilding the older sculpted
creature or backdrop art cannot overwrite them:

- `kapre_tree_idle.png`: 260 × 500, trunk centered, branch under the existing Kapre feet
  at (-64, -173). The image's cropped upper trunk continues to the canopy using its own
  upper bark. The Kapre, cigar target and lights keep their existing positions.
- `dead_tree_idle.png`: 260 × 336, the second tree fitted to the clearing's existing origin.
- Both `*_felled.png`: supplied trunk crops laid east with a 64 px thickness. The clearing
  log matches the existing 280 px collision span.
- `forest_plate.png`: 1672 × 941, two complete trees replacing the old vine-tree frame
  through `ForestBand.plate_texture`. It retains the band's registration, parallax rate,
  night tint and dawn behavior. Mountain and terrace plates remain the distant landscape.
  The scene places this band at `plate_top = -140`, sinking its roots 20 world pixels
  into the ground so the trees feel planted rather than floating on their lowest tips.

The old `creatures/*tree*.png` and `backdrop/frame.png` are historical build outputs;
Level 4 uses the replacements above. Other levels keep their own tree artwork.

Windowed visual review:

```sh
godot --path game --resolution 1600x900 --script res://tests/run_visual_dilim_trees.gd
```

This captures scenery, Kapre and clearing at night and in clear light, plus both felled
trees, in `/tmp/obra_trees_review.png`. The segment 2 and finale probes check their existing
mechanics; the delivered creature tests measure the supplied branch and cigar lighting.
`review.png` is the reviewed contact sheet; `in_game.png` shows the Kapre and scenery in
clear light. Clear light is used only for artwork inspection, not the encounter's lighting.
