# O.B.R.A. Godot Client

This folder is now a runnable Godot 4 project. The first screen captures a drawing,
calls the Python backend, then spawns the entity returned by the classifier.

## Project Flow

1. Open this `game/` folder in Godot 4.x.
2. Start the backend from `backend/` after training/exporting `model/model.onnx`.
3. Run the Godot project.
4. Draw, click **Transform**, and the matching entity scene is spawned.

The playable entities are defined in `config/entities.json`:

- `fish` -> Quick Draw `fish`, swim controller
- `frog` -> Quick Draw `frog`, hop controller
- `spider` -> Quick Draw `spider`, climb controller
- `bird` -> Quick Draw `bird`, flap/glide controller
- `humanoid` -> Quick Draw `yoga`, platform controller
- `cat` -> Quick Draw `cat`, ground-walk controller
- `dog` -> Quick Draw `dog`, ground-walk controller
- `rabbit` -> Quick Draw `rabbit`, hop controller
- `butterfly` -> Quick Draw `butterfly`, flap/glide controller
- `snake` -> Quick Draw `snake`, swim/slither controller
- `circle` -> Quick Draw `circle`, controllable round physics body
- `square` -> Quick Draw `square`, controllable box physics body
- `triangle` -> Quick Draw `triangle`, controllable polygon physics body

After editing enabled entities, retrain/export the ONNX model. The backend
intentionally refuses to serve if `labels.json` does not match the enabled roster.

## Entity Expansion

To add a future animal or object:

1. Add an enabled entry to `config/entities.json`.
2. Set `quickdraw_label` to the exact Quick Draw category to train on.
3. Pick `spawn_mode`: `playable`, `pickup`, `obstacle`, or `static`.
4. Create the scene named by `scene_path`.
5. Run `python3 model/download_data.py`, retrain, and copy/export the new ONNX files.

Playable entries should expose an `apply_drawing(drawing: Image, strokes: Array)`
method. The provided controllers inherit that from `scripts/playable_entity.gd`.
Dynamic shape objects expose the same method through `scripts/physics_shape_object.gd`;
they apply the drawing as ink, rebuild a matching `RigidBody2D` collider, and map
movement input to force, torque, and jump impulses.

Animation metadata is optional but recommended for playable entities:

- `rig_profile`: points to a JSON profile in `config/rigs/`.
- `rig_type`: one of `walker`, `biped`, `flier`, `swimmer`, `hopper`, or `none`.
- Missing stroke data falls back to the simple drawing-as-sprite behavior.

The runtime rig (`scripts/runtime_rig_2d.gd`) animates the player's actual drawn
strokes — no template limbs are added. The drawing canvas hands the raw stroke
polylines to the spawned entity, which resolves a skeleton from them: the most
connected stroke cluster becomes the body, every open stroke touching it becomes a
limb pivoting at the exact contact point, a stroke drawn across the body splits into
two limbs at the crossing, and strokes touching a limb chain onto it. All motion is
driven by real movement — gait phase advances with distance traveled, wings beat on
flap impulses, the swim wave scales with speed — and every pose eases back to the
drawn rest pose when movement stops. The backend still only classifies sketches; it
does not generate animation frames.

## Controls

- Move: WASD or arrow keys
- Jump/flap/hop: Space
- Return to drawing screen from the game level: R

## Current Scenes

- `draw_screen.tscn`: drawing canvas, backend request, confidence/margin handling
- `game_level.tscn`: manifest-backed drawing flow plus the semi-3D environment baseplate
- `environment/environment_baseplate.tscn`: visual-only depth layers, parallax camera,
  placeholder props, gameplay collision, spawn point, and entity root
- `creatures/*.tscn`: playable bodies with `DrawingSkin` runtime rig nodes
- `objects/*.tscn`: controllable physics bodies for simple recognized shapes
- `config/rigs/*.json`: per-entity gait/animation profiles (stride, swing angles,
  squash amounts, ground offset)

The environment baseplate is intentionally asset-light. Replace placeholder prop
children inside the existing depth layers when adding art; keep `GameplayPlane`,
`EntityRoot`, `SpawnPoint`, and the collision bodies in place so spawning, camera
follow, and 2D movement continue to work.

Phase 2 resolves joints heuristically from the drawn strokes and animates them with
Godot-native transforms. Skeleton2D/Polygon2D mesh skinning or model-assisted joint
detection can layer on later without changing the stroke pipeline.
