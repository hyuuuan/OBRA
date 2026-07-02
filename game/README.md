# O.B.R.A. Godot Client

This folder is now a runnable Godot 4 project. The first screen captures a drawing,
calls the Python backend, then spawns the entity returned by the classifier.

## Project Flow

1. Open this `game/` folder in Godot 4.x.
2. Start the backend from `backend/` after training/exporting `model/model.onnx`.
3. Run the Godot project.
4. Draw, click **Transform**, and the matching entity scene is spawned.

The v1 playable entities are defined in `config/entities.json`:

- `fish` -> Quick Draw `fish`, swim controller
- `frog` -> Quick Draw `frog`, hop controller
- `spider` -> Quick Draw `spider`, climb controller
- `bird` -> Quick Draw `bird`, flap/glide controller
- `humanoid` -> Quick Draw `yoga`, platform controller

## Entity Expansion

To add a future animal or object:

1. Add an enabled entry to `config/entities.json`.
2. Set `quickdraw_label` to the exact Quick Draw category to train on.
3. Pick `spawn_mode`: `playable`, `pickup`, `obstacle`, or `static`.
4. Create the scene named by `scene_path`.
5. Run `python3 model/download_data.py`, retrain, and copy/export the new ONNX files.

Playable entries should expose an `apply_drawing(drawing: Image)` method. The provided
controllers inherit that from `scripts/playable_entity.gd`.

## Controls

- Move: WASD or arrow keys
- Jump/flap/hop: Space
- Return to drawing screen from the game level: R

## Current Scenes

- `draw_screen.tscn`: drawing canvas, backend request, confidence/margin handling
- `game_level.tscn`: manifest-backed spawn point and simple floor/walls
- `creatures/*.tscn`: simple Sprite2D bodies skinned with the player's drawing

The first version intentionally uses Sprite2D bodies. Upgrade to Skeleton2D/Polygon2D
after all five entities are reliable and fun to control.
