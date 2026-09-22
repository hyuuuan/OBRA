# Terrace stone fill

Generated with the built-in image-generation tool on 2026-09-22.
Revised to match the user's close-up reference: squared blocks, dark joints and sparse highlights.
Used by `terrace_material.gd` at 256 world units per repeat; grass is a separate
30-pixel cap cut directly from `terrace_reference.png` (the supplied close-up).
Exposed upper corners use eight-pixel stepped rounds; shared joins stay flat.
UVs and depth shading use world coordinates
so adjacent terrace blocks agree. No level geometry was changed.

## Generation prompt

Use case: stylized-concept. Generate a square seamless game texture of ONLY the brown underground stone wall from the supplied reference image. Match this reference extremely closely: chunky squared-off irregular brown earth blocks, dark nearly black thick joints, sparse simple ochre pixel highlights, low detail 16-bit pixel art, NOT rounded cobblestones, NOT realistic rock texture, NOT diagonal stones. Roughly 8 blocks across and 8 rows, mostly horizontal courses with irregular broken blocks. Match the reference brown palette and coarse pixel size. Flat orthographic front view. Entire image filled edge to edge with wall, seamless on all four sides, even illumination. NO grass, NO border, NO background, NO text. Grass cap will be supplied separately in game. IMPORTANT: solid opaque RGB image with NO transparency. Clean dark brown mortar everywhere between blocks. Clear warm medium brown stones with visible ochre highlights, like the reference, NOT muddy nearly-black stones. Avoid any noise artifacts or red or green speckles.
