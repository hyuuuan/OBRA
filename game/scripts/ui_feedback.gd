extends Node
## THE OTHER HALF OF A BUTTON PRESS. `AudioDirector` already catches every button in the
## game and gives it a click; its own comment says what was still missing:
##
##   "`ui_click` was defined in the catalogue and called from nowhere, so no button in the
##    game made a sound. Silence plus NO PRESS ANIMATION BEYOND THE THEME'S STYLEBOX is a
##    large part of why the UI was reported as not responding at all."
##
## A stylebox swap is instantaneous and the same on every button, so a press reads as the
## screen redrawing rather than as the button answering. This is the animation half, and it
## is deliberately the SAME IDIOM as the drawing canvas's entrance -- the one piece of motion
## in this game people already recognise:
##
##   the canvas    scales up from 0.84 with TRANS_BACK (a pop that overshoots and settles),
##                 tinted from gold, while a radial burst on the scrim burns away over most
##                 of a second
##   a button      dips to 0.96 while held, pops back through the same TRANS_BACK, and lets
##                 a ring go out from where it was actually clicked and burn away
##
## Two motions from one family, so the interface reads as one thing. A second idiom would
## have been easier and would have made the UI feel assembled from parts.
##
## ⚠ IT HOOKS `node_added` FOR THE SAME REASON THE AUDIO DOES. The six inventory slots, the
## three answers to Lolo's question and every dialogue choice are built in code at runtime.
## Connecting at each authored call site would have missed exactly the buttons a player
## presses most, which is how the sound came to be missing in the first place.

## How far the button dips while held. Small: a button that visibly shrinks reads as a
## thing being squashed rather than a thing being pressed.
const PRESS_SCALE := 0.96
const PRESS_IN := 0.06
## The return, and where the overshoot lives. TRANS_BACK is the canvas's own curve.
const PRESS_OUT := 0.24
## A hover lift, well under the press dip so the two cannot be confused.
const HOVER_SCALE := 1.02
const HOVER_TIME := 0.12
## The ring. It leaves the click point, grows past the button's own corner and fades. Its
## WIDTHS live on `ui_ripple.gd` with the drawing that uses them -- see the note there about
## autoloads not existing in a `--script` run.
## ⚠ AND IT HAS TO BE SLOW ENOUGH TO SEE. The first version ran QUINT over 0.42s, which on
## a nine-hundred-pixel dialogue button put the ring past the far edge inside a tenth of a
## second -- so the animation was technically running and there was nothing on screen for
## all but two frames of it. CUBIC over half a second crosses the widest button in the game
## at a speed the eye can follow.
const RIPPLE_TIME := 0.5


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button == null or button.has_meta(&"ui_feedback"):
		return
	button.set_meta(&"ui_feedback", true)
	button.button_down.connect(_press_in.bind(button))
	button.button_up.connect(_press_out.bind(button))
	button.mouse_entered.connect(_hover.bind(button, true))
	button.mouse_exited.connect(_hover.bind(button, false))
	button.focus_entered.connect(_hover.bind(button, true))
	button.focus_exited.connect(_hover.bind(button, false))
	# The ring needs to know WHERE it was clicked, and `pressed` does not carry a position.
	# Keyboard and gamepad activation has no position at all and falls back to the centre.
	button.gui_input.connect(_note_click_point.bind(button))
	button.pressed.connect(_ripple.bind(button))


## ⚠ THE PIVOT HAS TO BE SET EVERY TIME, NOT ONCE. A button in a container is laid out
## after it enters the tree and re-laid out whenever the container changes, so a pivot
## cached at connect time belongs to a size the button no longer has -- and a scale about
## the wrong pivot slides the button sideways instead of pressing it.
func _centre(button: BaseButton) -> void:
	button.pivot_offset = button.size * 0.5


func _tween_scale(button: BaseButton, to: float, seconds: float, curve: Tween.TransitionType) -> void:
	if not is_instance_valid(button):
		return
	_centre(button)
	# ⚠ `has_meta` FIRST. `get_meta` with a default still logs "the object does not have any
	# meta values with the key", once per press, which buried the output of every UI test.
	if button.has_meta(&"ui_feedback_tween"):
		var running: Variant = button.get_meta(&"ui_feedback_tween")
		if running is Tween and (running as Tween).is_valid():
			(running as Tween).kill()
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2(to, to), seconds) \
		.set_trans(curve).set_ease(Tween.EASE_OUT)
	button.set_meta(&"ui_feedback_tween", tween)


func _press_in(button: BaseButton) -> void:
	if button.disabled:
		return
	_tween_scale(button, PRESS_SCALE, PRESS_IN, Tween.TRANS_QUAD)


func _press_out(button: BaseButton) -> void:
	if not is_instance_valid(button):
		return
	var to := HOVER_SCALE if (button.has_focus() or button.is_hovered()) else 1.0
	_tween_scale(button, to, PRESS_OUT, Tween.TRANS_BACK)


func _hover(button: BaseButton, entering: bool) -> void:
	if not is_instance_valid(button) or button.disabled or button.button_pressed:
		return
	_tween_scale(button, HOVER_SCALE if entering else 1.0, HOVER_TIME, Tween.TRANS_CUBIC)


func _note_click_point(event: InputEvent, button: BaseButton) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed:
		button.set_meta(&"ui_feedback_point", click.position)


## The wave. A ring that leaves the click point and burns away -- the button's own version
## of the burst the canvas puts across the scrim when it opens.
##
## ⚠ AN OUTLINE, NOT A DISC. A filled ripple over a button covers its label for the length
## of the animation, and these buttons carry two and three lines of text: the route's
## sentence and the requirement under it. A ring reads as the same motion and never hides
## the thing the player is reading.
func _ripple(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.disabled:
		return
	var centre := button.size * 0.5
	if button.has_meta(&"ui_feedback_point"):
		var from: Variant = button.get_meta(&"ui_feedback_point")
		if from is Vector2:
			centre = from
		button.remove_meta(&"ui_feedback_point")

	var ring := Control.new()
	ring.name = "PressRipple"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# ⚠ CLIPPED, OR IT IS NOT A BUTTON ANIMATION AT ALL. `draw_arc` does not stop at the
	# control's rect: the first version put a radius-900 arc centred inside a dialogue
	# button and drew a curve clean across the screen, over the level, the HUD and the two
	# buttons underneath it. The wave belongs to the button that was pressed.
	ring.clip_contents = true
	# Over the label, because it is a hairline and reads as light on top of it rather than
	# as something in front of it.
	ring.z_index = 1
	ring.set_script(RippleDraw)
	button.add_child(ring)
	ring.set(&"centre", centre)
	# Far enough to clear the corner it was clicked furthest from, so the wave always
	# reaches the whole button before it dies -- and no further, because it is clipped.
	var reach := maxf(centre.length(), (button.size - centre).length())
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_method(func(value: float) -> void:
		if is_instance_valid(ring):
			ring.set(&"radius", value)
			ring.queue_redraw(), 0.0, reach, RIPPLE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# The ring outruns its own fade -- it is still travelling while it dims, which is what
	# makes it read as a wave leaving rather than a circle being deleted.
	tween.tween_method(func(value: float) -> void:
		if is_instance_valid(ring):
			ring.set(&"fade", value), 1.0, 0.0, RIPPLE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# `finished` rather than a chained callback. Both work -- `chain()` on a parallel tween
	# was briefly blamed for a leak that turned out to be the probe counting FRAMES in a
	# headless run, where they are not time -- but the signal says "when the whole thing is
	# over" without depending on how the tweeners were grouped, and a ripple that fails to
	# free itself leaves one Control per press on every button for the life of the screen.
	tween.finished.connect(ring.queue_free)


## The ring's own drawing, as a GDScript class rather than a file: it is nine lines and
## exists only for this, and a one-node script in its own file is a thing to keep in sync.
const RippleDraw := preload("res://scripts/ui_ripple.gd")
