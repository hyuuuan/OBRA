extends Control
## One expanding ring, drawn for `UIFeedback`. Nothing sets these but the tween that owns
## it, and the node frees itself when that tween finishes.

## ⚠ ITS OWN CONSTANTS, NOT `UIFeedback`'s. Autoloads DO NOT EXIST in a `--script` run --
## `/root/UIFeedback` is null there -- so a `_draw` that reached for one would work in the
## game and throw in every test that photographs it, which is the only place the animation
## can be checked at all.
const RING_WIDTH := 3.0
const INNER_WIDTH := 1.8
const INNER_GAP := 7.0
## Enough that a ring the width of a button is not visibly a polygon.
const SEGMENTS := 64

## Where the button was clicked, in the button's own coordinates.
var centre := Vector2.ZERO
## How far the wave has travelled.
var radius := 0.0
## 1 at the click, 0 when it is gone. Kept separate from `modulate` so the tween can run
## the two on different curves -- the ring outruns its own fade, which is what makes it
## read as a wave rather than as a circle being deleted.
var fade := 1.0


func _draw() -> void:
	if radius <= 0.5 or fade <= 0.005:
		return
	# ⚠ OUTLINED, FOR THE SAME REASON EVERY LABEL IN THIS UI IS. The buttons come in three
	# families and two of them are pale cream; a gold ring on cream is a ring you can only
	# find if you already know it is there, which is exactly what the first version was.
	# A dark halo under a bright line reads on any of the three, and it is the trick the
	# requirement strip and the hint bar already use for their text.
	draw_arc(centre, radius, 0.0, TAU, SEGMENTS,
		Color(UISkin.INK.r, UISkin.INK.g, UISkin.INK.b, 0.42 * fade),
		RING_WIDTH + 3.0, true)
	draw_arc(centre, radius, 0.0, TAU, SEGMENTS,
		Color(UISkin.GOLD_PALE.r, UISkin.GOLD_PALE.g, UISkin.GOLD_PALE.b, 0.95 * fade),
		RING_WIDTH, true)
	# A second, softer ring just inside it. One line reads as a circle; two reads as a
	# wavefront with a direction.
	if radius > INNER_GAP + 4.0:
		draw_arc(centre, radius - INNER_GAP, 0.0, TAU, SEGMENTS,
			Color(UISkin.GOLD.r, UISkin.GOLD.g, UISkin.GOLD.b, 0.38 * fade),
			INNER_WIDTH, true)
