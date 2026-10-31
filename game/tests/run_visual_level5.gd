extends SceneTree
## Actual Mayon scene, photographed at 1600x900. Fails if a requested state is unreachable.
var level: Node
var out := "/tmp/obra_level5_"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	level = load("res://level_5.tscn").instantiate()
	# Hold the final scene for photographs instead of changing to the home screen.
	var tour := GDScript.new()
	tour.source_code = 'extends "res://scripts/level_5.gd"\nfunc _complete_level() -> void:\n\tpass\n'
	if tour.reload() != OK:
		quit(1)
		return
	level.set_script(tour)
	level.get_node("BackendSupervisor").auto_start_backend = false
	level.set("intro_enabled", false)
	root.add_child(level)
	level.call("_on_backend_ready")
	level.set("_forgot", 3)
	level.set("_corridor_seen", true)
	call_group(DialogueBox.GROUP, "set_auto_dismiss", true)
	await create_timer(.8).timeout
	await _put(Vector2(800, 500))
	await _shot("01_foot")
	await _put(Vector2(2000, 350))
	await _shot("02_ascent")
	for i in range(3):
		var at := Vector2([5800, 7600, 9400][i], [0, -160, -320][i])
		await _put(at)
		await _shot("0%d_cluster" % (3+i))
	# The actual quiet canvas, no controls; its strokes are drawn through the input handler.
	await _put(Vector2(11100, -420))
	level.set("_lolo_moment", "waiting")
	level.call("_open_the_page", true)
	var panel: DrawPanel = level.get("draw_panel")
	await _ink_stroke(panel)
	if not panel.canvas.has_ink():
		push_error("visual harness: real mouse input did not reach the quiet canvas")
		quit(1)
		return
	await _shot("06_refusal")
	panel.handle_cancel()
	call_group(DialogueBox.GROUP, "set_auto_dismiss", false)
	level.set("_lolo_moment", "going")
	level.call("_let_him_go")
	var dialogue: DialogueBox = level.get("dialogue_box")
	# Read the first line normally, then leave the unfinished second sentence onscreen.
	while dialogue.is_typing():
		await process_frame
	await _shot("06a_lolo")
	var feet: Vector2 = level.get("player").get_global_transform_with_canvas().origin
	if feet.y >= dialogue.frame_rect().position.y - 16.0:
		push_error("Lolo's scene must keep the world figures above the dialogue box")
		quit(1)
		return
	var advance := InputEventAction.new()
	advance.action = &"ui_accept"
	advance.pressed = true
	root.push_input(advance, true)
	var gone_by := Time.get_ticks_msec() + 12000
	while not level.get("lolo").is_gone() and Time.get_ticks_msec() < gone_by:
		await create_timer(.02, true).timeout
	await _shot("06b_disappearance")
	if not level.get("lolo").is_gone() or dialogue.get_node("Portrait").visible \
			or not dialogue.is_open() or not dialogue.current_line().ends_with("kept m"):
		push_error("Lolo's figure and portrait must vanish while his unfinished sentence stays")
		quit(1)
		return
	call_group(DialogueBox.GROUP, "hide_line")
	call_group(DialogueBox.GROUP, "set_auto_dismiss", true)
	await _put(Vector2(12300, -420))
	await create_timer(4.2).timeout
	await _shot("07_summit")
	for id in ["terraces", "church", "bangka", "forest"]:
		var fragment: MemoryFragment2D = level.call("_fragment", id)
		fragment.restore_to("saved", [[0.0, 30.0, 30.0, 0.0, 60.0, 30.0]])
		(level.get("_save_order") as Array).append(id)
	await _put(Vector2(12750, -420))
	call_group(DialogueBox.GROUP, "set_auto_dismiss", false)
	level.set("_summit", "blooming")
	level.call("_bloom_the_places")
	await create_timer(3.35, true).timeout
	if int(level.call("bloomed")) != 4:
		push_error("visual harness: all four saved memories must bloom before capture")
		quit(1)
		return
	await _shot("08_restored")
	(level.get("dialogue_box") as DialogueBox).visible = false
	root.get_node("PlayerProfile").call("set_setting", "reduce_motion", true)
	var lola: Lola2D = level.call("_lola")
	await lola.turn_around()
	level.get("player").call("apply_morph_state", {"position": lola.global_position + Vector2(-82,0), "linear_velocity":Vector2.ZERO})
	level.call("_world_camera").snap_to_target()
	lola.receive_flowers()
	level.call("_set_performance", "lower")
	await _shot("09_flowers")
	var frame := FrameReturn.new()
	frame.has_flowers = true
	level.add_child(frame)
	await create_timer(1.1, true).timeout
	(level.get("dialogue_box") as DialogueBox).visible = false
	await _shot("10_room")
	frame.pick_up_brush()
	await create_timer(.45, true).timeout
	await _shot("11_pickup")
	var until := Time.get_ticks_msec() + 3000
	while not frame.holds_ordinary_brush() and Time.get_ticks_msec() < until:
		await create_timer(.05, true).timeout
	if not frame.holds_ordinary_brush():
		push_error("visual harness: the ordinary brush was never picked up")
		quit(1)
		return
	await _shot("12_brush")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600,1000)
	await process_frame
	await _shot("13_room_tall", true)
	print("OBRA_VISUAL_LEVEL5_OK: /tmp/obra_level5_*.png")
	if OS.get_cmdline_user_args().has("--hold-at-end"):
		await create_timer(45.0, true).timeout
	# Finish the staged narration before freeing the scene; no suspended story coroutine.
	call_group(DialogueBox.GROUP, "set_auto_dismiss", true)
	var finished_by := Time.get_ticks_msec() + 6000
	while String(level.call("summit_state")) != "done" and Time.get_ticks_msec() < finished_by:
		await create_timer(.05, true).timeout
	if String(level.call("summit_state")) != "done":
		push_error("visual harness: staged summit did not finish before cleanup")
		quit(1)
		return
	level.queue_free()
	level = null
	tour = null
	for cleanup_tick in range(5): await process_frame
	quit(0)


func _put(at: Vector2) -> void:
	level.get("player").call("apply_morph_state", {"position": at, "linear_velocity": Vector2.ZERO})
	await create_timer(.4).timeout
	level.call("_world_camera").snap_to_target()
	await create_timer(.2).timeout


func _shot(name: String, native_size: bool = false) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if not native_size:
		image.resize(1600, 900, Image.INTERPOLATE_NEAREST)
	image.save_png(out + name + ".png")


func _ink_stroke(panel: DrawPanel) -> void:
	var middle := panel.canvas_viewport_container.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.position = middle - Vector2(70, 0)
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	_inject(down)
	await process_frame
	for point in [middle + Vector2(0, -80), middle + Vector2(70, 0)]:
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		_inject(motion)
		await process_frame
	var up := InputEventMouseButton.new()
	up.position = middle + Vector2(70, 0)
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	_inject(up)
	await process_frame


func _inject(event: InputEventMouse) -> void:
	# Same viewport/physical-pointer registration as run_click_ui's proven mouse harness.
	var window := Vector2(DisplayServer.window_get_size())
	var content := root.get_visible_rect().size
	Input.warp_mouse(event.position * (window / content))
	event.global_position = event.position
	root.push_input(event, true)
