# Apo locomotion replacement — 2026-10-02

`walk_reference.png` and `run_reference.png` are the two supplied sheets, preserved
unchanged. `../apo_locomotion.png` is the transparent, two-row atlas prepared with
the built-in imagegen tool. This is a reference-based extraction **with corrected
in-between poses**, not a pixel-exact crop: the supplied sheets repeat wide-stride
poses without enough passing steps for a complete gait.

The atlas contains six walking frames on top and six running frames below.
`wanderer_figure.gd` owns the measured regions and anchors. The columns are not
perfectly evenly spaced, so do not replace these measurements with `hframes = 6`.
Both rows use the same 0.28 scale (approximately 96 world pixels standing). Walk
frames keep one foot on the floor; run frames 2 and 5 retain their flight height.
There is no additional runtime bob. The controller advances cycles by distance,
freezes them outside ground locomotion, and starts a new step after idle/landing.

All levels spawn the same `creatures/wanderer.tscn` through `level_base.gd`, including
restoring the player after a morph. Idle, jump, look, wave and climb art is retained.
The legacy `apo_walk.png` / `apo_run.png` remain reproducible build outputs used by
`tools/build_art.py` and other art tools; they are no longer loaded by the player.
Rebuilding those old sheets cannot overwrite the new atlas.

Validation:

```sh
godot --headless --path game --import
godot --headless --path game --script res://tests/run_locomotion_probe.gd
godot --path game --script res://tests/run_visual_walk.gd
godot --headless --path game --script res://tests/run_underwater_appearance_probe.gd
```

The visual runner saves `/tmp/obra_walk_walk.png` and `/tmp/obra_walk_run.png` and
compares the dry shader output with the original palette. The input probe exercises
walk, run, left/right, jumping, landing, stopping, wall collision, pause, foot
registration and the spawn path of every nonempty scene in `levels.json`.

## Generation prompt

Use case: background-extraction and identity-preserve game sprite preparation.
Extract the exact little boy character design from these two supplied character
sheets into a production-ready transparent sprite atlas for a Godot side-scroller.
Input 1 is WALK reference; input 2 is RUN reference. Preserve the brown hair, face,
cream shirt, diagonal satchel strap and brown bag on rear hip, blue shorts, brown
shoes, and the original chunky pixel-art shading and outline. Remove ALL lettering,
frame border, dark background and ground shadows. Output one atlas with exactly
TWO ROWS and SIX EQUAL CELLS PER ROW, 12 full-body sprites total, facing RIGHT. Top
row walk, bottom row run. Each cell has exactly the same size and scale, generous
transparent padding, pelvis on identical horizontal center within its cell and
common ground baseline per row. Crucial: the supplied poses repeat a spread-leg
silhouette; correct the in-between leg and arm poses to make genuine smooth
six-frame cycles, rather than six spread-leg copies. Walk row sequence: right leg
forward contact, right stance down with left foot swinging toward center, right
stance passing with left knee forward and heels close beneath torso, left leg
forward opposite contact, left stance down with right foot swinging toward center,
left stance passing right knee forward. Clearly visible narrowing of foot
separation at passing phases, alternating foreground leg, no sliding or amputated
limbs. Run row sequence: right contact extended, right stance compressed with rear
heel tucked, airborne passing with left knee forward and right heel tucked up,
left contact extended, left stance compressed with rear heel tucked, airborne
passing with right knee forward and left heel tucked. Run slight forward body
lean matching input 2; each flight pose has both shoes ABOVE baseline, never
normalize airborne feet down to ground. Keep character identity, head proportions,
pixel density and shoulder registration stable throughout. Do not mirror whole
figures to fake alternate steps. No added accessories. Actual alpha transparency.
No labels, text, grid lines or shadows. Landscape atlas approximately 3:1 aspect.
