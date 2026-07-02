# O.B.R.A. — Godot Client

The scripts in `scripts/` are ready to attach; the scenes you create in the Godot
editor (that part is hands-on by nature). Follow this once and the whole loop works.

## 0. Setup
1. Download **Godot 4.x** (standard build) and create a new project **in this `game/`
   folder** so the `scripts/` directory is picked up.
2. Project Settings → **Input Map**: add actions `jump` (Space), `move_left` (A/Left),
   `move_right` (D/Right).

## 1. The drawing screen (scene: `draw_screen.tscn`)

Build this node tree:

```
DrawScreen (Control)
├── SubViewportContainer
│   └── SubViewport            <- e.g. 512x512, "Update Mode: Always"
│       ├── ColorRect          <- white, full rect (the paper)
│       └── Canvas (Control)   <- full rect, attach scripts/drawing_canvas.gd
├── TransformButton (Button)
├── ClearButton (Button)
├── StatusLabel (Label)
└── SketchClient (Node)        <- attach scripts/sketch_client.gd
```

Then in the Inspector for **SketchClient**, set `Canvas Viewport` to the SubViewport.

Wire the buttons (signals tab or a small script on DrawScreen):

```gdscript
extends Control

@onready var client: Node = $SketchClient
@onready var status: Label = $StatusLabel

func _ready() -> void:
    $TransformButton.pressed.connect(client.send_drawing)
    $ClearButton.pressed.connect($SubViewportContainer/SubViewport/Canvas.clear_canvas)
    client.prediction_received.connect(_on_prediction)
    client.prediction_failed.connect(func(msg): status.text = msg)

func _on_prediction(creature: String, confidence: float, drawing: Image) -> void:
    status.text = "%s (%.0f%%)" % [creature, confidence * 100.0]
    # Next step: change to the game scene and spawn the matching creature:
    # GameState.pending = {"creature": creature, "drawing": drawing}
    # get_tree().change_scene_to_file("res://game_level.tscn")
```

**Milestone 1 (do this before any gameplay):** run the Python backend
(`uvicorn main:app --port 8000` in `backend/`), press Play in Godot, draw a frog,
click Transform, and see `frog (97%)` in the label. That's the full ML round trip.

## 2. The creatures (one scene per class)

For each class make a scene `creatures/frog.tscn`, `creatures/fish.tscn`,
`creatures/spider.tscn`:

```
Frog (CharacterBody2D)          <- attach scripts/frog_controller.gd
├── Body (Sprite2D)             <- the player's drawing lands here (apply_drawing)
└── CollisionShape2D
```

- `frog_controller.gd` is provided (charge-and-release hop). Copy it as the starting
  point for the others and change only the `_physics_process` movement:
  - **fish**: no gravity; smooth 8-direction swimming (`velocity = input * speed`).
  - **spider**: normal gravity, but when a wall is touched (`is_on_wall()`), allow
    climbing (set `velocity.y` from input while touching).
- Spawn the right one after recognition:

```gdscript
const CREATURES := {
    "frog": preload("res://creatures/frog.tscn"),
    "fish": preload("res://creatures/fish.tscn"),
    "spider": preload("res://creatures/spider.tscn"),
}

func spawn(creature: String, drawing: Image) -> void:
    var body := CREATURES[creature].instantiate()
    add_child(body)
    body.apply_drawing(drawing)
```

Later, upgrade `Body (Sprite2D)` to a `Polygon2D` + `Skeleton2D` rig so the drawing
deforms while moving — same `apply_drawing` idea, just a fancier body. Do that only
after all three classes are playable with plain sprites.

## Notes
- Develop/demo as a **desktop** build talking to `http://127.0.0.1:8000`. Web export
  is a stretch goal (CORS is already enabled server-side if you attempt it).
- The transparent-background trick: the drawing arrives as black ink on white paper.
  In `apply_drawing`, you can punch out the white with a few lines if you want the
  ink-only look — or just keep the white card as a "paper cutout" art style (easier
  and honestly charming).
