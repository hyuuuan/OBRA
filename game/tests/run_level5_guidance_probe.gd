extends SceneTree
## Player-facing Mayon guidance, including actual Draw/Paint hit testing. Add -- --visual
## with a window to save the instruction states in /tmp/obra_level5_guidance.
const OUTPUT := "/tmp/obra_level5_guidance"
var level: Node
var failures := 0
var checked := 0
var visual := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	visual = "--visual" in OS.get_cmdline_user_args()
	root.size = Vector2i(1600, 900)
	root.content_scale_size = Vector2i(1600, 900)
	var profile := root.get_node("PlayerProfile")
	profile.call("reset_progress")
	profile.call("record_brush_acquired")
	profile.call("record_new_brush")
	root.get_node("LevelManager").set("current_level_id", "level_5")
	level = load("res://level_5.tscn").instantiate()
	level.get_node("BackendSupervisor").auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await create_timer(0.5).timeout
	var panel: DrawPanel = level.get("draw_panel")
	var sketch: Node = level.get("memory_sketch")
	var ink: InkManager = level.get("ink_manager")
	var fragment: MemoryFragment2D = level.call("_fragment", "terraces")
	preload("res://tests/level5_journey_fixture.gd").prepare(level, fragment.global_position + Vector2(0, 60))
	await create_timer(0.3).timeout
	var lines: DialogueScript = level.get("script_lines")
	_check(lines.has_heard("L5_CORRIDOR.enter") and lines.lines_spoken() >= 3,
		"Lolo explains preservation as part of entering the memories")
	level.call("refresh_objective")
	_check(_objective().contains("sketch and preserve"), "a reachable landmark explains how to preserve it")
	await _photo("01_memory_target")
	# Remapping changes the task's key and the real input that opens the page.
	var bindings := InputMap.action_get_events("redraw")
	InputMap.action_erase_events("redraw")
	var remapped := InputEventKey.new()
	remapped.physical_keycode = KEY_T
	InputMap.action_add_event("redraw", remapped)
	level.call("refresh_objective")
	_check(_objective().begins_with("T to sketch"), "the instruction uses the rebound drawing key")
	await _key(KEY_T)
	_check(sketch.is_open() and not panel.is_open() and sketch.find_children("*", "SubViewport", true, false).is_empty(),
		"real drawing input opens a separate sketchbook with no recognition capture")
	await _photo("02_memory_page")
	await create_timer(0.55).timeout
	var paper: Control = sketch.canvas
	var reference := sketch.find_child("LandmarkReference", true, false) as Control
	_check(root.get_visible_rect().encloses(paper.get_global_rect())
		and reference.is_visible_in_tree() and not paper.get_global_rect().intersects(reference.get_global_rect()),
		"the drawing area and landmark reference fit side by side")
	# Kent, 2026-11-05: "how are they supposed to know what to draw in that moment". The memory is
	# on the paper, faint, under her strokes; the page says to trace it, that a few lines do, what
	# it costs, where it goes, and how much ink is left.
	var trace := sketch.find_child("TraceGuide", true, false) as TextureRect
	var words: String = sketch.call("instructions")
	var guided := trace != null and trace.is_visible_in_tree() and trace.texture != null \
		and trace.texture == (reference as TextureRect).texture and trace.modulate.a < 0.4 \
		and trace.get_index() < paper.get_index() and paper.get_parent() == trace.get_parent()
	_check(guided and words.contains("Trace") and words.contains("1 ink") and words.contains("summit")
			and words.contains("Ink left: %d" % int(ink.remaining())),
		"the sketch page shows the memory faintly to trace and says what to do, its cost and the ink left")
	var before := ink.remaining()
	await _stroke(paper, [Vector2(-90, 20), Vector2(0, -90), Vector2(90, 20)])
	await _key(KEY_ESCAPE)
	_check(not sketch.is_open() and fragment.is_open() and is_equal_approx(ink.remaining(), before),
		"Escape closes the sketchbook without spending ink")
	await _key(KEY_T)
	await create_timer(0.55).timeout
	await _stroke(paper, [Vector2(-100, 40), Vector2(-100, -30), Vector2(0, -130),
		Vector2(100, -30), Vector2(100, 40), Vector2(-100, 40)])
	await _stroke(paper, [Vector2(-100, -30), Vector2(100, -30)])
	await _stroke(paper, [Vector2(-20, 40), Vector2(-20, 0), Vector2(20, 0), Vector2(20, 40)])
	await create_timer(1.5).timeout
	var strokes: Array = sketch.canvas.get_strokes()
	_check(sketch.is_open() and strokes.size() == 3 and is_equal_approx(ink.remaining(), before),
		"the house sketch can take several strokes without submitting or spending ink")
	await _photo("02_house_sketch")
	var expected: Array = []
	for stroke: Dictionary in strokes:
		var flat: Array = []
		for point: Vector2 in stroke.points:
			flat.append_array([point.x, point.y])
		expected.append(flat)
	var classes_before: int = profile.call("class_diversity")
	await _click(sketch.preserve_button)
	_check(not sketch.is_open() and fragment.state() == "saved" and fragment.strokes() == expected
		and is_equal_approx(ink.remaining(), before - 1.0)
		and int(profile.call("class_diversity")) == classes_before
		and String(level.get("status_label").text).contains("preserved"),
		"Preserve saves the original freehand strokes for one ink and confirms success")
	InputMap.action_erase_events("redraw")
	for binding in bindings: InputMap.action_add_event("redraw", binding)
	await create_timer(0.4).timeout
	await _photo("03_memory_saved")
	ink.committed = ink.capacity
	level.call("refresh_objective")
	_check(_objective().contains("still walk right"), "empty ink explains that the ending remains reachable")
	var other: MemoryFragment2D = level.call("_fragment", "kubo")
	preload("res://tests/level5_journey_fixture.gd").prepare(level, other.global_position + Vector2(0, 60))
	await create_timer(0.2).timeout
	await _key(KEY_R)
	_check(not sketch.is_open() and not panel.is_open() and other.is_open(),
		"empty ink leaves the landmark available without opening the wrong canvas")
	other.leave_behind()
	await create_timer(4.2).timeout
	_check(String(level.get("status_label").text).contains("left behind"), "a lost memory confirms the outcome without implying game over")
	level.get("lolo").vanish()
	level.set("_lolo_moment", "gone")
	preload("res://tests/level5_journey_fixture.gd").summit(level)
	await create_timer(0.3).timeout
	level.call("refresh_objective")
	_check(_objective().contains("Walk right toward Lola") and level.get("objective_banner").is_visible_in_tree(),
		"the white summit keeps the next action visible")
	await _photo("04_summit_approach")
	preload("res://tests/level5_journey_fixture.gd").prepare(level, level.call("_anchor", "summit_speak") + Vector2(10, 0))
	await create_timer(0.3).timeout
	call_group(DialogueBox.GROUP, &"hide_line")
	await create_timer(0.3).timeout
	level.call("refresh_objective")
	_check(level.get("draw_button").is_visible_in_tree() and _objective().contains("draw Lola"),
		"Lola's first drawing has a visible objective and Draw button")
	await _photo("05_summit_draw")
	# Click the real Draw button, draw through the viewport, then click the real Paint button.
	await _click(level.get("draw_button"))
	_check(panel.is_open() and panel.get("_context_title") == "Draw Lola"
		and panel.canvas_frame.is_visible_in_tree() and panel.transform_button.is_visible_in_tree(),
		"the ending page shows its drawing surface, instructions and submit button")
	await _photo("06_lola_page")
	await _stroke(panel.canvas_viewport_container, [Vector2(-60, 0), Vector2(60, 0)])
	await create_timer(1.6).timeout
	_check(panel.is_open() and panel.canvas.has_ink(), "pausing between strokes does not silently submit the ending drawing")
	await _click(panel.transform_button)
	await create_timer(1.5).timeout
	_check(not panel.is_open() and int(level.get("_attempts")) == 1 and is_zero_approx(ink.remaining()),
		"clicking Paint advances the quiet attempt without ink or recognition")
	await _key(KEY_R)
	await _stroke(panel.canvas_viewport_container, [Vector2(-60, 0), Vector2(60, 0)])
	await _click(panel.transform_button)
	await create_timer(1.5).timeout
	_check(level.call("summit_state") == "lowering", "the second instructed attempt advances the story")
	await create_timer(3.2).timeout
	await create_timer(0.2).timeout
	_check(panel.is_open() and panel.drawing_mode == DrawPanel.DrawingMode.FREE_PAINT
		and panel.get("_context_title") == "Draw the places you remember", "the final page explains its free, unrestricted drawing task")
	root.size = Vector2i(1600, 1000)
	root.content_scale_size = Vector2i(1600, 1000)
	await create_timer(0.2).timeout
	await _photo("07_free_paint_tall")
	panel.handle_cancel()
	level.set("_summit", "done")
	level.call("refresh_objective")
	_check(_objective().contains("Mayon complete") and _objective().contains("Progress saved"), "completion has an explicit acknowledgement")
	profile.call("mark_level_completed", "level_5")
	profile.call("note_dialogue_heard", "house_epilogue")
	level.queue_free()
	await process_frame
	var hub: Node = load("res://levels/hub/hub.tscn").instantiate()
	root.add_child(hub)
	await create_timer(0.4).timeout
	_check(String(hub.get("_status").text).contains("Journey complete. Progress saved."), "the house confirms completion after the ending and on later visits")
	await _photo("08_home_complete")
	hub.queue_free()
	await process_frame
	print("OBRA_LEVEL5_GUIDANCE_%s (%d checks)" % ["OK" if failures == 0 and checked == 21 else "FAILED", checked])
	quit(0 if failures == 0 and checked == 21 else 1)


func _objective() -> String:
	return String(level.get("objective_banner").get("_text"))


func _key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	_mouse(motion)
	await create_timer(0.1).timeout
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		_mouse(event)
		await process_frame


func _stroke(surface: Control, offsets: Array[Vector2]) -> void:
	var centre := surface.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.position = centre + offsets[0]
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	_mouse(down)
	await process_frame
	for offset in offsets.slice(1):
		var motion := InputEventMouseMotion.new()
		motion.position = centre + offset
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		_mouse(motion)
		await process_frame
	var up := down.duplicate() as InputEventMouseButton
	up.position = centre + offsets[-1]
	up.pressed = false
	_mouse(up)
	await process_frame


func _mouse(event: InputEventMouse) -> void:
	Input.warp_mouse(event.position * (Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size))
	event.global_position = event.position
	root.push_input(event, true)


func _photo(label: String) -> void:
	if not visual or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "/" + label + ".png")


func _check(ok: bool, what: String) -> void:
	checked += 1
	failures += int(not ok)
	print("  %s\t%s" % ["OK" if ok else "FAIL", what])
