# Apo swimming — 2026-10-15

`swim_reference.png` is the supplied **Underwater Pixel Swim Animation Sheet.png**,
preserved unchanged. `tools/build_apo_swim.py` imports its actual pixels into five
transparent strips beside the avatar's other sprites:

| Strip | Frames |
|---|---:|
| `apo_swim_right.png` | 6 |
| `apo_swim_left.png` | 6 |
| `apo_swim_idle_side.png` | 4 |
| `apo_swim_idle_front.png` | 4 |
| `apo_swim_float.png` | 4 |

Each frame occupies a 320 × 320 cell registered at the cream shirt's centre.
The importer removes the presentation background, headings and stray fragments,
keeps the bubbles, and preserves the source colours and pose pixels without
resampling. `wanderer_figure.gd` draws every strip at 0.5 scale with nearest
filtering and the existing underwater lighting material. The art already swims
head first; it needs no quarter turn of a running pose.

Horizontal swimming uses the authored direction row. The left row cancels the
figure's normal facing mirror so it still faces left. Diving tilts the stroke;
W/Space alone and breath recovery use the upward float animation. Resting below
the surface uses side idle; resting at the surface uses front idle. Moving swim
cycles follow distance; four-frame idle/float cycles take one second and freeze
with the game's pause. The earlier levels' wading/struggling pose stays separate.

Rebuild and verify:

```sh
python3 tools/build_apo_swim.py
python3 tools/build_apo_swim.py --check
godot --headless --path game --import
godot --headless --path game --script res://tests/run_locomotion_probe.gd
godot --headless --path game --script res://tests/run_underwater_appearance_probe.gd
godot --path game --script res://tests/run_visual_swim.gd
```

The visual runner saves all 24 frames in `/tmp/obra_swim_frames.png` and captures
right/left swimming, rising, diving and resting through real input in Level 3.
