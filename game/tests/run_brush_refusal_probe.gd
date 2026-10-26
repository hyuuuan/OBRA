extends SceneTree
## The brush refuses: where a level says so, the canvas opens quiet -- no running guess, no
## words, no ink taken, nothing sent to the recogniser -- and Paint, or putting the brush down,
## fades the lines and closes the page. Everywhere else the page is the page it always was.
##
##   godot --headless --path game --script res://tests/run_brush_refusal_probe.gd

## Stands in for the recogniser, counting what is asked of it.
class StubClient extends Node:
	var live := 0
	var sent := 0

	func request_live_guess() -> bool:
		live += 1
		return false

	func send_drawing() -> void:
		sent += 1


## Every check this probe makes. A script error that skips them must not pass as quiet.
const CHECKS := 4

var failures := 0
var checked := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _a_refusing_page_takes_nothing_and_fades()
	await _an_ordinary_page_is_unchanged()
	if checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_BRUSH_REFUSAL_OK")
		quit(0)
	else:
		print("OBRA_BRUSH_REFUSAL_FAILED=%d" % failures)
		quit(1)


func _a_refusing_page_takes_nothing_and_fades() -> void:
	var script := GDScript.new()
	script.source_code = "extends \"res://scripts/game_level.gd\"\n" \
		+ "var refused_with: Array = []\n" \
		+ "func _brush_refuses_here() -> bool:\n\treturn true\n" \
		+ "func _brush_refused(strokes: int) -> void:\n\trefused_with.append(strokes)\n"
	script.reload()
	var level := await _open_level(script)
	var panel := level.get("draw_panel") as DrawPanel
	var stub := StubClient.new()
	panel.add_child(stub)
	panel.client = stub
	var ink := level.get("ink_manager") as InkManager
	var ink_before := ink.remaining()
	var profile := root.get_node("PlayerProfile")
	var drawn_before: int = profile.call("class_diversity")
	var heard: Array[int] = []
	panel.quietly_refused.connect(func(strokes: int) -> void: heard.append(strokes))
	var made := [0]
	panel.drawing_ready.connect(func(_a, _b, _c, _d, _e, _f) -> void: made[0] += 1)
	level.call("_on_draw_button_pressed")
	_draw_two_lines(panel)
	await create_timer(1.0).timeout
	var guess_text := panel.guess_label.text
	_check(panel.is_open() and panel.is_refusing() and stub.live == 0 and panel.status.text == ""
		and guess_text == "" and is_zero_approx(float(panel.get("_claim")))
		and not panel.transform_button.disabled,
		"a refusing page takes no guess, says nothing, and shows no ink going",
		"open %s, refusing %s, guesses asked %d, status '%s', guess '%s', claim %.2f" % [
			panel.is_open(), panel.is_refusing(), stub.live, panel.status.text, guess_text,
			float(panel.get("_claim"))])
	panel.call("_on_transform_pressed")
	await create_timer(0.4).timeout
	var mid_fade := panel.canvas.modulate.a
	await create_timer(DrawPanel.REFUSAL_FADE).timeout
	_check(mid_fade > 0.05 and mid_fade < 0.95 and not panel.is_open() and heard == [2]
		and stub.sent == 0 and made[0] == 0 and is_equal_approx(ink.remaining(), ink_before)
		and level.get("refused_with") == [2],
		"Paint fades the lines and closes the page, and nothing is sent, made or spent",
		"%.2f through the fade, open after %s, heard %s, sent %d, made %d, ink %.1f -> %.1f, level told %s" % [
			mid_fade, panel.is_open(), heard, stub.sent, made[0], ink_before, ink.remaining(),
			level.get("refused_with")])
	# Putting the brush down is trying too.
	level.call("_on_draw_button_pressed")
	_draw_two_lines(panel)
	await create_timer(0.2).timeout
	var took := panel.handle_cancel()
	await create_timer(DrawPanel.REFUSAL_FADE + 0.3).timeout
	var drawn_after: int = profile.call("class_diversity")
	_check(took and not panel.is_open() and heard == [2, 2] and stub.sent == 0
		and panel.canvas.modulate.a == 1.0 and drawn_after == drawn_before,
		"putting the brush down refuses the same way, and the page comes back clean",
		"cancel taken %s, heard %s, sent %d, page alpha %.2f, classes drawn %d -> %d" % [took, heard,
			stub.sent, panel.canvas.modulate.a, drawn_before, drawn_after])
	level.queue_free()
	await _frames(3)


func _an_ordinary_page_is_unchanged() -> void:
	var level := await _open_level(null)
	var panel := level.get("draw_panel") as DrawPanel
	var stub := StubClient.new()
	panel.add_child(stub)
	panel.client = stub
	level.call("_on_draw_button_pressed")
	_draw_two_lines(panel)
	await create_timer(1.0).timeout
	var guessing := stub.live > 0
	panel.call("_on_transform_pressed")
	await create_timer(0.2).timeout
	_check(not panel.is_refusing() and guessing and stub.sent == 1 and panel.status.text != "",
		"everywhere else the page guesses as she draws and sends what she paints",
		"refusing %s, guesses asked %d, sent %d, status '%s'" % [panel.is_refusing(), stub.live,
			stub.sent, panel.status.text])
	panel.close_panel()
	level.queue_free()
	await _frames(3)


## Two short strokes across the middle of the page.
func _draw_two_lines(panel: DrawPanel) -> void:
	var canvas := panel.canvas
	var middle := canvas.size * 0.5
	for row in [-30.0, 30.0]:
		canvas.call("_start_stroke", middle + Vector2(-60.0, row))
		for step in range(1, 13):
			canvas.call("_append_point", middle + Vector2(-60.0 + step * 10.0, row), true)


func _open_level(script: GDScript) -> Node:
	var level := (load("res://game_level.tscn") as PackedScene).instantiate()
	if script != null:
		level.set_script(script)
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(40):
		await physics_frame
	call_group(DialogueBox.GROUP, &"hide_line")
	paused = false
	await _frames(4)
	return level


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
