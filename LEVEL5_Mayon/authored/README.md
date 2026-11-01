# Mayon original performance art

Generated on 31 October 2026 with the built-in OpenAI image_gen tool. The original
apo turnaround and delivered Mayon painting were style references. Full prompts
are retained in `prompts.json`; no downloaded or third-party stock assets were used.

- `lola_atlas.png`: eight equal cells, four columns by two rows. Back, painting,
  turning, front, receiving flowers, returning to the painting, seated listening,
  seated with flowers. This replaces the child's turnaround recoloured grey.
- `apo_performance_atlas.png`: raise, paint, failed attempt, lower, seated,
  seated painting, offer flowers, pick up an ordinary brush.
- `frame_room.png`: ordinary Filipino painting room, empty of actors. Actors are
  composited at runtime on the rattan bench, with one registration per actor.

`tools/build_mayon_performance.py` cuts transparent sprites, a bust at source
resolution, and the room at 1600x900.
One scale per atlas preserves head size across standing and seated poses. Original
sources stay here; runtime paths stay under `game/assets/Level5/`.

## Art review and remaining provisional material

The generated character performances, portrait, and room are integrated original
artwork and still need human art-direction review. Replace each generated original
or a same-name runtime pose without changing gameplay. They are not artist-delivered
assets and should not be represented as such.

The memory scraps remain deterministic crops of earlier paintings, rather than
twelve newly illustrated memories. Their torn edges are procedural. The summit
compositions reuse transparent scenery from those levels (see the revision below).

Mayon is silent. Its synthesized wind, eruption, brush and ending cue were removed on
1 November 2026; `mayon_brush` and `mayon_ending` remain in `game/config/audio.json` as
hooks with no file. A recorded Lola voice is also absent; no dialogue playback depends on one.

## Landscape revision after in-game visual review

`upper_slope.png`, `cliff_atlas.png`, and `ruin_props.png` were generated with the
same built-in tool; their exact text-only prompts are in `prompts.json`.
`build_mayon_landscape.py` owns the measured cuts and the foot vista composed
from the delivered sky, volcano, and meadow at their measured offsets. The old
vertical parallax bands are no longer used by the level: they separated as the
camera climbed. `MayonVista2D` covers the viewport and blends to the upper slope.

The cliff atlas owns three materials (meadow, exposed basalt, pale ash). Each
runtime strip has a fixed walk-line registration and uses world texture phase.
The ruin atlas supplies the old crossing and steps, a basalt column, and a broken
arch. Replace the original atlases with matching measured regions, or replace
same-name runtime cuts under `terrain/` and `props/` with the same dimensions.
The generated atlas did not follow the requested equal cells; the builder's
explicit source rectangles are authoritative.

The summit now uses transparent scenery from the actual earlier levels.
`build_mayon_restoration.py` lists every source: Payyo's hut and terraces,
Piyesta's bunting, troupe and church, Dagat's coral, storm clouds and
bakunawa, and the Makiling forest/waterfall plate. Forest and waterfall are two
views of that same source painting, with a night tint on the forest. These are
compositions of existing game art, not twelve newly commissioned illustrations.
`bloom_width`, `bloom_elevation`, and `bloom_tint` in `level_05.json` register each
piece in the summit. The old enlarged torn-card summit outputs have been removed.

The new upper slope, cliff materials, crossing, steps, column and arch join the
provisional generated-art review list. The crossing and steps are no longer
repeated path/masonry rectangles. Memory targets remain procedural torn crops;
there is still no recorded Lola voice, and Mayon has no audio.

`bangka_memory.png` is a dedicated generated restoration vignette with water
ripples, replacing the enlargement of Dagat's small code-drawn boat. It is part of
the generated-art review list; its exact prompt is retained beside the others.

## Dedicated cliff edge textures

`cliff_edges.png` is a generated three-column atlas of left-facing end caps: meadow, basalt,
and ash. The existing `cliff_atlas.png` was the material/style reference. It was generated with
the built-in image_gen tool on 31 October 2026; the exact prompt is in `cliff_edges.prompt.txt`
and `prompts.json`. Source output: `exec-3df527f2-e296-4201-be92-5c5011789019.png`.

`build_mayon_landscape.py` cuts each 512x1024 column at its alpha bounds and reduces it with
nearest filtering to 128px wide, preserving its aspect ratio and genuine alpha. Runtime files:
`terrain/edge_meadow.png` (128x313), `edge_basalt.png` (128x295), and `edge_ash.png` (128x315).
They replace the earlier procedural edge polygons and warped cliff-face mesh.

Replacement contract: art faces left, overlap extends right, top grass/crust aligns to the
terrain's existing lip offset, and the ragged outside extends about 10 world pixels past the
collision edge. Runtime mirrors the art at right-facing ends. Ordinary steps use native size;
the tall ascent wall uses uniform scale to cover the riser without stretching either axis
separately. Caps inherit the terrain's tint and whitening material. They add no collision and
do not bridge the span. Keep this orientation, alpha and walk-line registration when replacing
same-name outputs. This new generated edge atlas joins the provisional art-review inventory.

## Foothill trees and parallax — 1 November 2026

`foothill_trees.png` and `parallax_ridges.png` were generated with the built-in OpenAI
image_gen tool, using the existing foot and upper vistas as style references. Exact prompts
are in `scenery.prompts.json`. These are original generated assets awaiting art-direction
review, rather than artist-delivered pieces.

`tools/build_mayon_scenery.py` preserves their genuine alpha and cuts:

- `props/tree_broadleaf.png`, `tree_tall.png`, `palm_pair.png`, `ash_snag.png`.
- `backdrop/far_ridge.png`, `forest_ridge.png` (1536x512 each).

Tree cells did not follow the requested equal grid; the builder's measured source rectangles
are authoritative. Tree runtime heights are 360, 400, 350 and 240px, with aspect ratio preserved.
Their bottom-centre is the root registration used by the scene. Replace same-name sprites
at the same dimensions to retain the placement. The eleven lower-slope trees and one bare
cone snag are decorative and add no collision; living trees stop below x4200.

`MayonVista2D` keeps each existing painting registered while panning it inside a 10% overscan.
The new ridge and forest scroll at 0.12 and 0.28 world-pixels per camera-pixel, respectively.
They share vertical framing with the camera, so a jump cannot separate the painted bands.
Alternate horizontal repeats are mirrored. Full bottom-quarter texture chunks continue
below the strips; no single-row stretching. Forest fades out by x5100; the far ridge
fades out by x11800. Both are drawn by the existing SkyBand and inherit its summit whitening.

Replace the ridge panoramas with genuine-alpha, full-width 1536x512 images, with a transparent
sky above the ridge and opaque artwork across the entire bottom quarter. Keep the two rows
separate and do not flatten a sky into either strip. The source originals remain here; the
runtime uses only the cuts under `game/assets/Level5/`.

## Painted pixel wind — 1 November 2026

`wind_streaks.png` is a generated three-column, four-row animation atlas: three breeze
designs, four registered frames each. The built-in OpenAI image_gen tool produced the atlas,
then redrew it on a coarse pixel grid to remove soft edges and glow. The complete initial
and revision prompts are in `wind_streaks.prompts.json`. This joins the generated-art review
inventory.

`build_mayon_scenery.py` samples the 1536x1024 atlas onto its logical 384x256 pixel grid,
removes faint alpha fringe, and centres each silhouette in its fixed cell. The generated
rows drifted in their cells; this registration prevents a jump between frames. Runtime uses
`game/assets/Level5/weather/wind_streaks.png`, nearest filtering and whole-pixel movement.
Marks render about 170-195px wide with gentle alpha fades. Four staggered slots produce a gust
about every 1.8 seconds, usually two visible and at most three; the peak opacity is 46%.
The ordinary pause clock and Reduce Motion setting stop the animation, and the summit's
existing x12200 boundary disables it.

Replacement contract: a 3x4 atlas, a fixed centre in every 128x64 logical cell, each column a
design and each row its next frame, right-to-left direction, flat ivory/cream/silver pixels
on genuine transparency. Do not trim individual cells, add glow, or smooth the pixel edges.
