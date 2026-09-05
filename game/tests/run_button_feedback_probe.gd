extends SceneTree
## The press animation, without a viewport.
##   godot --headless --path game --script res://tests/run_button_feedback_probe.gd
##
## It cannot see the animation -- `run_visual_button_feedback` is for that -- but it can see
## the three things that would make it silently stop happening:
##
##   the hook       every button, including one built after the layer exists, gets attached
##   the press      holding actually changes the button's scale, and letting go returns it
##   the ripple     a ring is added on `pressed` and takes itself away again
##
## ⚠ AND IT BUILDS THE AUTOLOAD ITSELF. `/root/UIFeedback` does not exist in a `--script`
## run -- no autoload does -- so a probe that assumed the project setting was enough would
## test nothing at all and say so in green.

## ⚠ WAIT ON THE CLOCK, NOT ON FRAMES. A headless run is uncapped, so `await process_frame`
## seventy times can be a fraction of the half-second the ripple takes -- the first version
## of this reported the ring as leaking when it had simply not finished yet, and would have
## reported a genuine leak identically. Tweens advance on real delta; so must the waits.
const UIFeedbackTimes := preload("res://scripts/ui_feedback.gd")

var feedback: Node
var failures := 0


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-44s %s" % ["OK  " if ok else "FAIL", what, detail])


func _run() -> void:
	feedback = (load("res://scripts/ui_feedback.gd") as Script).new()
	feedback.name = "UIFeedback"
	root.add_child(feedback)
	await process_frame

	# BUILT AFTER the layer, which is the case that matters: the dialogue choices, the six
	# inventory slots and the three route answers are all made at runtime, and they are the
	# buttons a player presses most.
	var button := Button.new()
	button.text = "Let us put it back."
	button.size = Vector2(320.0, 96.0)
	root.add_child(button)
	await process_frame

	_check(button.has_meta(&"ui_feedback"), "a button built at runtime is hooked",
		"attached through node_added, like the click sound")
	_check(button.button_down.is_connected(Callable(feedback, "_press_in")) \
		or button.button_down.get_connections().size() > 0,
		"and its press is connected", "%d listeners on button_down"
		% button.button_down.get_connections().size())

	button.emit_signal("button_down")
	await _wait(UIFeedbackTimes.PRESS_IN + 0.04)
	var held := button.scale.x
	_check(held < 0.999, "holding it presses it in", "scale %.3f" % held)
	_check(absf(button.pivot_offset.x - button.size.x * 0.5) < 0.01,
		"about its own middle, not its corner",
		"pivot %.0f of %.0f wide" % [button.pivot_offset.x, button.size.x])

	button.emit_signal("button_up")
	await _wait(UIFeedbackTimes.PRESS_OUT + 0.10)
	_check(absf(button.scale.x - 1.0) < 0.02, "and letting go returns it",
		"scale %.3f" % button.scale.x)

	# THE WAVE. It is a child node with a life of its own, so the two things worth asserting
	# are that it arrives and that it leaves -- a ripple that never frees itself would pile
	# one Control per press onto every button in the game.
	button.emit_signal("pressed")
	await process_frame
	var ring := button.get_node_or_null(^"PressRipple")
	_check(ring != null, "pressing sends a ring out from it",
		"PressRipple" if ring != null else "no ripple was added")
	await _wait(UIFeedbackTimes.RIPPLE_TIME + 0.25)
	_check(button.get_node_or_null(^"PressRipple") == null,
		"and the ring takes itself away", "no leak per press")

	# A disabled button must do neither: motion on something that cannot be used reads as
	# the game accepting a press it is about to ignore.
	button.disabled = true
	button.emit_signal("button_down")
	await _wait(UIFeedbackTimes.PRESS_IN + 0.04)
	_check(absf(button.scale.x - 1.0) < 0.02, "a disabled button does not answer",
		"scale %.3f" % button.scale.x)

	print("OBRA_BUTTON_FEEDBACK_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)
