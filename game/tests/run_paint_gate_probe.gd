extends SceneTree
## Paint is held back while the live guess is not sure, and back the moment it is.
##
##   godot --headless --path game --script res://tests/run_paint_gate_probe.gd
##
## Below and above the recogniser's gate the Paint button looked the same, so a guess it would
## refuse was painted and declined. Kent's call: make it unclickable below the gate. Checked: a
## guess short of the gate turns Paint off and says why; it stays off through the next strokes
## until a sure guess turns it back on; a guess that cannot be had at all does not lock it; and a
## page that asks the recogniser nothing (Mayon's refusing page) is never held back.

const CHECKS := 5

var level: Node2D
var panel: DrawPanel
var failures := 0
var checked := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		print("OBRA_PAINT_GATE_FAILED=watchdog")
		quit(2))
	level = (load("res://game_level.tscn") as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(40)
	panel = level.get("draw_panel") as DrawPanel
	level.call("_open_the_page", false)
	await _frames(4)
	var button := panel.get("transform_button") as Button
	var status := panel.get("status") as Label
	var bar := float(panel.get("client").call("current_bar"))

	_stroke(Vector2(120, 120), Vector2(300, 260))
	_guess(bar - 0.15, 0.4)
	await _frames(2)
	_check(button.disabled and panel.paint_held_for_a_guess() and status.text == DrawPanel.UNSURE_STATUS,
		"a guess short of the gate holds Paint back, and says why",
		"disabled %s, status \"%s\"" % [button.disabled, status.text])
	_stroke(Vector2(300, 260), Vector2(320, 120))
	await _frames(2)
	_check(button.disabled, "and keeps it held through the next stroke, until a new guess",
		"disabled %s" % button.disabled)
	_guess(bar + 0.2, 0.5)
	await _frames(2)
	_check(not button.disabled and status.text != DrawPanel.UNSURE_STATUS,
		"a sure guess gives Paint back", "disabled %s, status \"%s\"" % [button.disabled, status.text])
	_guess(bar - 0.2, 0.4)
	await _frames(2)
	panel.client.live_prediction_failed.emit("backend unreachable")
	await _frames(2)
	_check(not button.disabled, "a guess that cannot be had does not lock Paint", "disabled %s" % button.disabled)
	_guess(bar - 0.2, 0.4)
	await _frames(2)
	panel.set_refusing(true)
	_stroke(Vector2(100, 300), Vector2(200, 380))
	await _frames(2)
	_check(not panel.paint_held_for_a_guess() and not button.disabled,
		"a page that asks the recogniser nothing is never held back", "held %s, disabled %s" % [
			panel.paint_held_for_a_guess(), button.disabled])
	panel.set_refusing(false)
	_finish()


## A line on the page, as a drag puts it there.
func _stroke(from: Vector2, to: Vector2) -> void:
	var canvas := panel.get("canvas") as Node
	canvas.call("_start_stroke", from)
	for i in range(1, 9):
		canvas.call("_append_point", from.lerp(to, float(i) / 8.0), true)


## The recogniser's live answer for the page as it is now.
func _guess(confidence: float, margin: float) -> void:
	var canvas := panel.get("canvas") as Node
	panel.set("_guessed_revision", canvas.call("content_revision"))
	panel.client.live_prediction.emit("ladder", "Ladder", confidence, margin, {})


func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _finish() -> void:
	if checked != CHECKS:
		print("OBRA_PAINT_GATE_FAILED: %d checks ran, %d expected" % [checked, CHECKS])
		quit(1)
	elif failures == 0:
		print("OBRA_PAINT_GATE_OK")
		quit(0)
	else:
		print("OBRA_PAINT_GATE_FAILED=%d" % failures)
		quit(1)


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
