# Supplied priest artwork

`character_sheet.png` is the unmodified user-supplied **Elderly Priest Pixel Art Character
Sheet.png**. `character_cutouts.png` is the transparent production sheet, prepared with the
built-in imagegen tool. All poses remain available here; the church currently uses front,
six walking frames, left-facing side, and the large portrait.

Run `python3 tools/build_priest.py` to pack the runtime PNGs into
`game/assets/characters/priest/`, or add `--check` to verify them. Then reimport Godot assets:
`godot --headless --path game --import`.

The builder only crops and fits the cutouts with nearest-neighbour sampling. Sprite cells
are 80 × 124 with feet on row 123; the walk faces right and the talking pose faces left.
The portrait is 197 × 352; `DialoguePortrait` cuts at row 250, below the pendant.

## Image preparation prompts (built-in imagegen)

1. **Background extraction:** Remove only the dark background, decorative borders, labels
   and palette swatches. Retain every priest depiction in its original position, pose,
   proportions, colors and pixel detail, including the large portrait, five turnaround
   poses, six walk frames, six run frames and six action poses. Preserve dark outlines,
   spectacles and shoes; remove ground shadows. Output real RGBA transparency with no
   redesign, rearranging or added characters.
2. **Edge cleanup:** Remove stray red/yellow/white speckles and translucent fringes outside
   the character silhouettes. Preserve the character artwork, palette, gold crosses,
   robes, spectacles and hair, as well as the registered 1254 × 1254 canvas. Keep solid
   pixel-art outlines and transparency; no new art, smoothing, shadows or rearranging.
