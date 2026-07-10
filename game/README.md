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
- `axe` -> Quick Draw `axe`, placeable/equippable destructible tool
- `ladder` -> Quick Draw `ladder`, settling climbable utility
- `key` -> Quick Draw `key`, reusable lock utility
- `umbrella` -> Quick Draw `umbrella`, toggleable fall-drag utility
- `flashlight` -> Quick Draw `flashlight`, persistent toggleable light cone
- `sailboat` -> Quick Draw `sailboat`, placeable water-aware vehicle

After editing enabled entities, retrain/export the ONNX model. The backend
intentionally refuses to serve if `labels.json` does not match the enabled roster.

## Entity Expansion

To add a future animal or object:

1. Add an enabled entry to `config/entities.json`.
2. Set `quickdraw_label` to the exact Quick Draw category to train on.
3. Pick `spawn_mode`: `playable`, `pickup`, `obstacle`, or `static`.
4. Create the scene named by `scene_path`.
5. Run `python3 model/download_data.py`, retrain, and copy/export the new ONNX files.

Every runtime entry exposes `apply_drawing(drawing: Image, strokes: Array)` and
`configure_entity(entry)`. Living morphs also expose physics-anchor, grip-anchor,
and morph-state methods. `runtime_role` in the version 2 manifest selects active
ragdoll morph, controllable physics morph, or utility placement behavior.

Animation metadata is optional but recommended for playable entities:

- `rig_profile`: points to a JSON profile in `config/rigs/`.
- `rig_type`: one of `walker`, `biped`, `flier`, `swimmer`, `hopper`, or `none`.
- Missing stroke data falls back to the simple drawing-as-sprite behavior.

The runtime rig builds actual `RigidBody2D` sections and `PinJoint2D` constraints
from the player's ink; no template limbs are added. Connected strokes become
articulated chains, closed strokes become solid hulls, and open strokes become
compound capsules. Malformed drawings degrade to a stable compound body rather
than creating an unbounded joint graph.

## Controls

- Move: WASD or arrow keys
- Jump/flap/hop: Space
- Return to drawing screen from the game level: R
- Place: mouse, wheel or Q/E to rotate, left click confirm, right click cancel
- Inventory slots: 1–6
- Interact/equip/pick up: E
- Use equipped utility: F

## Current Scenes

- `game_level.tscn`: in-game draw panel, ink/inventory/placement systems, and environment baseplate
- `environment/environment_baseplate.tscn`: visual-only depth layers, parallax camera,
  placeholder props, gameplay collision, spawn point, and entity root
- `creatures/*.tscn`: active-ragdoll containers with `DrawingSkin` physics rig nodes
- `objects/*.tscn`: controllable shape morphs and placeable utility rigidbodies
- `config/rigs/*.json`: per-entity gait, motor, mass/contact, and alignment tuning

The environment baseplate is intentionally asset-light. Replace placeholder prop
children inside the existing depth layers when adding art; keep `GameplayPlane`,
`EntityRoot`, `SpawnPoint`, and the collision bodies in place so spawning, camera
follow, and 2D movement continue to work.

The physics rig resolves joints heuristically from the player's stroke graph and
drives them with bounded motors and contact-aware forces. Future level content can
add `WaterArea2D`, destructible, lockable, and utility-requirement targets without
changing classification or drawing data.
