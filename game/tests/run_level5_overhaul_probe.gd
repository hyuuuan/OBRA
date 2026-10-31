extends SceneTree
## Contracts that teleport-driven old probes could not establish: locked context, paused
## clocks, exact saved ink, real canvas input, no recognition for quiet/free drawing,
## a mid-line disappearance, and a visible ordinary brush.
const CHECKS := 14
var checked := 0
var failures := 0
var level: Node
var completed: Array = []

class CountingClient extends Node:
	var asked := 0
	func request_live_guess() -> bool:
		asked += 1
		return true
	func send_drawing() -> void:
		asked += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	level = load("res://level_5.tscn").instantiate()
	level.get_node("BackendSupervisor").auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, "set_auto_dismiss", true)
	for i in range(40):
		await physics_frame
	var ink: InkManager = level.get("ink_manager")
	var panel: DrawPanel = level.get("draw_panel")
	var kubo: MemoryFragment2D = level.call("_fragment", "kubo")
	var church: MemoryFragment2D = level.call("_fragment", "church")
	_put(kubo.global_position + Vector2(0, 60))
	await _wait(.15)
	var four := 0
	for id in ["kubo", "terraces", "bandaritas", "dancers"]:
		four += int((level.call("_fragment", id) as MemoryFragment2D).state() == "draining")
	_check(four == 4 and church.state() == "whole", "one cluster starts together; remote memories wait")
	level.call("_open_the_page", true)
	var before := kubo.drain()
	await _wait(.25)
	var ref := panel.panel_root.get_node_or_null("MemoryReference")
	_check(is_equal_approx(before, kubo.drain()) and ref != null and not panel.canvas_viewport.is_ancestor_of(ref),
		"drawing pauses whitening and its reference stays outside captured ink")
	_put((level.call("_fragment", "terraces") as Node2D).global_position + Vector2(0, 60))
	panel.close_panel()
	var strokes := [{"points": PackedVector2Array([Vector2(12, 19), Vector2(51, 89), Vector2(92, 21)]), "width": 6.0, "color": Color.BLACK}]
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	level.call("_on_drawing_ready", "door", "Door", image, {}, strokes, 1.0)
	_check(kubo.state() == "saved" and (level.call("_fragment", "terraces") as MemoryFragment2D).state() != "saved",
		"a prediction saves the memory selected when the page opened")
	var lolo: Lolo = level.get("lolo")
	lolo.set_thinness(.63)
	var snapshot: Dictionary = level.call("_level_run_state")
	level.set("_save_order", [] as Array[String])
	kubo.restore_to("whole")
	lolo.set_thinness(0.0)
	level.call("_restore_level_run_state", snapshot)
	_check(kubo.strokes() == [[12.0, 19.0, 51.0, 89.0, 92.0, 21.0]] and level.get("_save_order") == ["kubo"]
		and is_equal_approx(lolo.thinness(), .63),
		"checkpoint restores exact ink, its outcome, and save order")
	level.call("_tend_clusters", 7000.0)
	await _wait(4.2)
	var lost: MemoryFragment2D = level.call("_fragment", "dancers")
	var left: Dictionary = level.call("_level_run_state")
	level.call("_restore_level_run_state", left)
	_check(lost.state() == "lost" and "memory_1" in level.get("_clusters_left"), "departed choices stay lost on reload")
	level.call("_tend_clusters", 7200.0)
	level.call("_tend_clusters", 7000.0)
	_check(church.state() == "passing" and "memory_2" in level.get("_clusters_left"),
		"leaving a cluster downhill also begins permanent loss")
	var profile := root.get_node("PlayerProfile")
	var routes_before: int = profile.call("route_count", "artist")
	level.call("_on_fragment_saved", "flower")
	level.set("_flower_credited", false)
	level.call("_on_fragment_saved", "flower")
	_check(int(profile.call("route_count", "artist")) == routes_before + 1, "flower route credit is durable and idempotent")
	var director: LevelDirector = level.get("director")
	director.enter_obstacle("L5_SPAN")
	_check(bool(level.call("_may_use_hidden_ink", "bridge")) and not bool(level.call("_may_use_hidden_ink", "sword"))
		and not bool(level.call("_may_use_hidden_ink", "bat")), "an unrelated drawing cannot spend a gate's reserve")
	director.exit_obstacle("L5_SPAN")
	ink.committed = ink.capacity
	_check(not bool(level.call("_spawn_or_replace", "monkey", "Monkey", image, strokes)) and is_equal_approx(ink.hidden_reserve, 2),
		"an empty brush cannot borrow reserve for a creature")
	# Quiet modes have a counted substitute client, and are exercised through canvas mouse events.
	var counter := CountingClient.new()
	panel.add_child(counter)
	panel.client = counter
	var optional_ui := Control.new()
	optional_ui.visible = false
	panel.panel_root.add_child(optional_ui)
	panel.free_paint_completed.connect(func(value: Array) -> void: completed.append(value))
	panel.set_drawing_mode(DrawPanel.DrawingMode.QUIET_REFUSAL)
	panel.open_panel()
	panel.call("_on_transform_pressed")
	var empty_stayed := panel.is_open()
	panel.handle_cancel()
	_check(empty_stayed and not panel.is_open() and String(level.get("_lolo_moment")) == "",
		"empty submit and cancel do not advance a quiet beat")
	panel.open_panel()
	_canvas_stroke(panel)
	await _wait(3.0)
	_check(not panel.is_open() and counter.asked == 0 and is_zero_approx(ink.remaining())
		and not panel.canvas_frame.visible and not panel.transform_button.visible, "a real quiet stroke fades without UI, recognition, or ink")
	panel.set_drawing_mode(DrawPanel.DrawingMode.FREE_PAINT)
	panel.open_panel()
	_canvas_stroke(panel)
	var drawn: Array = panel.canvas.get_strokes().duplicate(true)
	await _wait(2.0)
	_check(completed.size() == 1 and completed[0] == drawn and counter.asked == 0,
		"free paint returns the actual vectors without a recognizer request")
	panel.set_drawing_mode(DrawPanel.DrawingMode.NORMAL)
	panel.open_panel()
	_check(panel.canvas_frame.visible and not optional_ui.visible,
		"returning to normal restores the caller's original UI visibility")
	panel.close_panel()
	# Real dialogue typing: he must be gone while the interrupted line is still on screen.
	var box: DialogueBox = level.get("dialogue_box")
	box.set_auto_dismiss(false)
	level.set("_lolo_moment", "going")
	level.call("_let_him_go")
	await _wait(.15)
	box.complete()
	box.call("_advance")
	var gone := await _until(func() -> bool: return (level.get("lolo") as Lolo).is_gone(), 7.0)
	_check(gone and box.is_visible_in_tree() and box.current_line().ends_with("kept m"), "Lolo goes during his unfinished line, before dismissal")
	box.skip_all()
	box.set_auto_dismiss(true)
	# The frame performance is checked in its existing probe; keep this runner's expected count exact.
	level.queue_free()
	for i in range(8):
		await process_frame
	if checked != CHECKS:
		failures += 1
	print("OBRA_LEVEL5_OVERHAUL_%s (%d/%d)" % ["OK" if failures == 0 else "FAILED", checked, CHECKS])
	quit(0 if failures == 0 else 1)


func _put(at: Vector2) -> void:
	level.get("player").call("apply_morph_state", {"position": at, "linear_velocity": Vector2.ZERO})


func _canvas_stroke(panel: DrawPanel) -> void:
	var centre := panel.canvas.size * .5
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT; down.pressed = true; down.position = centre - Vector2(50, 0)
	panel.canvas.call("_gui_input", down)
	var motion := InputEventMouseMotion.new()
	motion.position = centre + Vector2(50, 30)
	panel.canvas.call("_gui_input", motion)
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false; up.position = motion.position
	panel.canvas.call("_gui_input", up)


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _until(done: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while not done.call() and Time.get_ticks_msec() < end:
		await _wait(.05)
	return bool(done.call())


func _check(ok: bool, what: String) -> void:
	checked += 1
	failures += int(not ok)
	print("  %s\t%s" % ["OK" if ok else "FAIL", what])
