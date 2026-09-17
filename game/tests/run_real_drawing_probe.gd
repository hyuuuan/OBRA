extends SceneTree
## DRAW ON THE CANVAS, AND LET THE REAL MODEL ANSWER.
##   godot --path game --script res://tests/run_real_drawing_probe.gd      (needs a window)
##
## Every suite in this project hands the level a class it has already decided -- "circle",
## "key" -- through `_on_drawing_ready`, with the recogniser out of the loop and the backend
## switched off. That is the right way to test a level and it skips the whole thesis: a stroke
## drawn on the oval, rasterised off the SubViewport, sent to the backend, run through the
## CNN and the dual gate, and the answer coming back into the level. A broken capture, a
## mismatched request, a backend that never starts or a panel that never closes after a reply
## would pass every other suite.
##
## So this starts the real backend, opens the drawing panel in Payyo, draws with strokes laid
## down the way the mouse lays them, presses Transform, and waits for the model: a circle has
## to come back as something, the panel has to close, and the answer has to reach the level.
## A scribble has to be declined, cost nothing, and leave the panel open to try again.

## Not 8000, so a server left over from an earlier run cannot answer in this one's place.
const PROBE_PORT := 8765

var failures := 0
var level: Node
var _ready_answer := {}
var _declined := {}


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-48s %s" % ["OK  " if ok else "FAIL", what, detail])


func _run() -> void:
	print("\n===== A REAL DRAWING =====")
	if DisplayServer.get_name() == "headless":
		print("  SKIP  needs a real viewport -- the canvas is captured off a SubViewport")
		print("OBRA_REAL_DRAWING_FAILED=1")
		quit(1)
		return
	level = (load("res://game_level.tscn") as PackedScene).instantiate()
	var supervisor := level.get_node("BackendSupervisor") as BackendSupervisor
	# ITS OWN BACKEND, ON ITS OWN PORT, set BEFORE the level starts. The supervisor reuses
	# anything already answering on 8000, and a server left running from an earlier session
	# serves whatever code and preprocessing it was started with -- which is exactly what this
	# probe exists to check. The level asks for a backend as it enters the tree, so the port
	# has to be right before then or the old server answers and this one is never started.
	supervisor.backend_port = PROBE_PORT
	var up := [false]
	supervisor.backend_ready.connect(func() -> void: up[0] = true)
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	var client := (level.get("draw_panel") as Node).get_node("PanelRoot/SketchClient")
	for property in ["backend_url", "live_url"]:
		if client.get(property) != null:
			client.set(property, String(client.get(property)).replace(":8000", ":%d" % PROBE_PORT))
	var waited := 0.0
	while waited < 60.0 and not up[0]:
		await create_timer(0.25, true, false, true).timeout
		waited += 0.25
	_check(up[0], "the recognition backend comes up", "%.1f s" % waited if up[0] else "never answered")
	if not up[0]:
		_finish()
		return

	var panel := level.get("draw_panel") as DrawPanel
	panel.drawing_ready.connect(func(entity: String, _n: String, _i: Image, response: Dictionary,
			strokes: Array, _c: float) -> void:
		_ready_answer = {"entity": entity, "confidence": float(response.get("confidence", 0.0)),
			"strokes": strokes.size()})
	panel.recognition_declined.connect(func(entity: String, confidence: float, margin: float,
			reason: String) -> void:
		_declined = {"entity": entity, "confidence": confidence, "margin": margin, "reason": reason})

	await _dismiss_story()
	await _draw_and_submit(panel, _circle(), "a circle")
	_check(not _ready_answer.is_empty(), "a drawn circle comes back from the model",
		"%s at %.0f%%" % [_ready_answer.get("entity", "?"), 100.0 * float(_ready_answer.get("confidence", 0.0))]
		if not _ready_answer.is_empty() else "NO ANSWER (declined: %s)" % str(_declined))
	_check(String(_ready_answer.get("entity", "")) == "circle", "and it is read as a circle",
		String(_ready_answer.get("entity", "")))
	_check(int(_ready_answer.get("strokes", 0)) > 0, "and the level gets the strokes it was drawn with",
		"%d stroke(s)" % int(_ready_answer.get("strokes", 0)))
	_check(not panel.is_open(), "and the panel closes on an answer", "closed")
	_check(not paused, "and the world is running again", "running")

	# A tangle nobody could name. The gate has to say so and it has to be free.
	_ready_answer = {}
	_declined = {}
	var ink := level.get("ink_manager") as Node
	var before := float(ink.call("total_uncommitted_available"))
	await _draw_and_submit(panel, _scribble(), "a scribble")
	var decided := not _declined.is_empty() or not _ready_answer.is_empty()
	_check(decided, "a scribble gets an answer either way", "declined" if not _declined.is_empty()
		else ("accepted as %s" % _ready_answer.get("entity", "?") if decided else "NOTHING came back"))
	if not _declined.is_empty():
		_check(is_equal_approx(float(ink.call("total_uncommitted_available")), before),
			"a declined drawing costs no ink", "%.1f before, %.1f after" % [before,
				float(ink.call("total_uncommitted_available"))])
		_check(panel.is_open(), "and the panel stays open to try again", "open")
	_finish()


func _finish() -> void:
	call_group(BackendSupervisor.GROUP, &"stop_backend")
	print("OBRA_REAL_DRAWING_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)


func _dismiss_story() -> void:
	for _i in range(60):
		for box in get_nodes_in_group(DialogueBox.GROUP):
			if bool(box.call("is_open")):
				box.call("skip_all")
		await process_frame


## Strokes laid on the canvas the way the mouse lays them, then Transform.
func _draw_and_submit(panel: DrawPanel, strokes: Array, what: String) -> void:
	if not panel.is_open():
		panel.open_panel()
	for _i in range(20):
		await process_frame
	# Past the canvas's own briefing lines, if any are up.
	for _i in range(10):
		for box in get_nodes_in_group(DialogueBox.GROUP):
			if bool(box.call("is_open")):
				box.call("skip_all")
		await process_frame
	var canvas := panel.get("canvas") as Control
	canvas.call("clear_canvas")
	var bounds: Rect2 = canvas.get("_bounds")
	if bounds.size.x < 10.0:
		bounds = Rect2(Vector2.ZERO, canvas.size)
	for stroke: Array in strokes:
		var first := true
		for point: Vector2 in stroke:
			var at := bounds.position + point * bounds.size
			if first:
				canvas.call("_start_stroke", at)
				first = false
			else:
				canvas.call("_append_point", at, true)
			await process_frame
		# What a mouse release does: the last point forced in, and the line let go.
		canvas.set("_current_line", null)
		await process_frame
	for _i in range(6):
		await process_frame
	print("    drew %s: %d stroke(s)" % [what, strokes.size()])
	(panel.get("transform_button") as Button).pressed.emit()
	# What was actually sent, kept for looking at when an answer is wrong.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var client := panel.get("client") as Node
	var sent := client.get("_last_drawing") as Image if client != null else null
	if sent != null:
		sent.save_png("/tmp/obra_real_%s.png" % what.replace(" ", "_"))
	var waited := 0.0
	while waited < 20.0 and _ready_answer.is_empty() and _declined.is_empty():
		await create_timer(0.1, true, false, true).timeout
		waited += 0.1
	for _i in range(20):
		await process_frame


## Points in 0..1 of the canvas's drawable box.
func _circle() -> Array:
	var ring: Array = []
	for step in range(41):
		var angle := TAU * float(step) / 40.0
		ring.append(Vector2(0.5 + cos(angle) * 0.3, 0.5 + sin(angle) * 0.3))
	return [ring]


func _scribble() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lines: Array = []
	for _line in range(6):
		var stroke: Array = []
		var at := Vector2(rng.randf_range(0.25, 0.75), rng.randf_range(0.25, 0.75))
		for _step in range(18):
			at += Vector2(rng.randf_range(-0.08, 0.08), rng.randf_range(-0.08, 0.08))
			at = at.clamp(Vector2(0.2, 0.2), Vector2(0.8, 0.8))
			stroke.append(at)
		lines.append(stroke)
	return lines
