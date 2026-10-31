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
