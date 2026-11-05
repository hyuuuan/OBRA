extends "res://tests/run_walk_level5.gd"
## Continuous movement from spawn to the house it ends in. Recognized normal drawings are fixtures;
## movement, dialogue, quiet/free strokes and the ending use the real input/state paths.
var read_left := 1.0
var quiet_attempts := 0
var shots := "/tmp/obra_mayon_finish_"

class Reader extends Node:
	var host: SceneTree
	func _process(delta: float) -> void:
		host.call("_read_ui", delta)

func _run() -> void:
	root.get_node("LevelManager").set("current_level_id","level_5")
	var profile := root.get_node("PlayerProfile")
	profile.call("record_brush_acquired")
	profile.call("record_new_brush")
	for flower in ["flower_1","L2_HF","L3_HF","L4_HF"]:
		profile.call("record_collectible",flower)
	level = load("res://level_5.tscn").instantiate()
	level.get_node("BackendSupervisor").auto_start_backend = false
	level.set("intro_enabled",true)
	root.add_child(level)
	current_scene = level
	player = level.get("player")
	var reader := Reader.new()
	reader.host = self
	reader.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(reader)
	call_group(DialogueBox.GROUP,"set_auto_dismiss",false)
	await create_timer(.5,true).timeout
	await _clear_ui()
	await _photo("01_opening")
	if not await _travel(2190):
		_fail("could not reach the span from spawn")
		return
	await _clear_ui()
	_check(await _place("bridge","span"),"bridge is placed through the normal ink path",str(player.global_position))
	if not await _travel(3980):
		_fail("could not walk from span to climb")
		return
	await _clear_ui()
	_check(await _place("stairs","climb"),"stairs are placed through the normal ink path",str(player.global_position))
	if not await _travel(6640):
		_fail("could not reach the first remembered place")
		return
	await _clear_ui()
	await _save_memory("terraces")
	await _photo("02_memories")
	if not await _travel(11820):
		_fail("could not reach the church")
		return
	await _clear_ui()
	await _save_memory("church")
	if not await _travel(14410):
		_fail("could not cross the church")
		return
	await _clear_ui()
	await _save_memory("bangka")
	if not await _travel(20180):
		_fail("could not reach the flower detour")
		return
	await _grounded()
	if not await _travel(20990):
		_fail("could not climb the flower detour")
		return
	await _grounded()
	await _clear_ui()
	await _photo("03_flower")
	await _save_memory("flower")
	_check(is_zero_approx(level.get("ink_manager").remaining()),"two gate drawings and four memories use exactly six visible units",str(level.get("ink_manager").remaining()))
	if not await _travel(21290):
		_fail("could not leave the memories for Lolo's moment")
		return
	await _clear_ui()
	if not await _paint_page():
		_fail("Lolo's quiet page did not finish")
		return
	var until := Time.get_ticks_msec()+16000
	while not level.get("lolo").is_gone() and Time.get_ticks_msec()<until:
		await create_timer(.05,true).timeout
	_check(level.get("lolo").is_gone(),"Lolo disappears in the actual dialogue sequence",str(level.get("_lolo_moment")))
	await _photo("04_lolo_gone")
	await _clear_ui()
	if not await _travel(22060):
		_fail("could not approach Lola")
		return
	await _clear_ui()
	await _photo("05_summit")
	var statistics: int = profile.call("class_diversity")
	for attempt in range(2):
		if not await _paint_page():
			_fail("Lola's quiet page did not finish")
			return
		await _clear_ui()
	_check(String(level.call("summit_state")) == "lowering","Lola's two refusals lead to lowering the brush",str(level.call("summit_state")))
	until = Time.get_ticks_msec()+7000
	while String(level.call("summit_state")) != "places" and Time.get_ticks_msec()<until:
		await create_timer(.05,true).timeout
	if not await _paint_page():
		_fail("the final free painting did not finish")
		return
	await create_timer(1.8,true).timeout
	await _photo("06_restoration")
	# The house is the ending now (DIARY.md): the bouquet, her last page, "Lolo. Let's go home.",
	# and home -- no seated room and no ordinary brush between.
	var bouquet_seen := false
	var home_said := false
	var went := false
	until = Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<until:
		# ⚠ GONE IS HOME. The way home is quick now -- no room between -- and the scene change frees
		# the level, so a level no longer there, with the house up, is the apo home.
		if not is_instance_valid(level):
			went = went or (current_scene != null and current_scene.scene_file_path.contains("hub"))
			break
		var lola = level.call("_lola")
		if is_instance_valid(lola) and lola.has_flowers() and not bouquet_seen:
			bouquet_seen = true
			await _photo("07_bouquet")
			continue
		home_said = home_said or bool((level.get("script_lines") as Object).call("has_heard", "APO.home"))
		if bool(level.call("went_home")):
			went = true
			break
		await create_timer(.05,true).timeout
	_check(bouquet_seen and home_said and went,"the bouquet, then \"Lolo. Let's go home.\", then home, on the continuous route",str([bouquet_seen,home_said,went]))
	_check(int(profile.call("class_diversity")) == statistics,"quiet attempts and free painting do not add recognition statistics",str(quiet_attempts))
	reader.queue_free()
	for action in ["move_right","move_up","jump"]: Input.action_release(action)
	if is_instance_valid(level): level.queue_free()
	for frame in range(5): await process_frame
	print("OBRA_LEVEL5_FINISH_WALK_%s (%d checks)" % ["OK" if failures==0 else "FAILED",checked])
	quit(0 if failures==0 else 1)

func _read_ui(delta: float) -> void:
	read_left -= delta
	if read_left > 0: return
	var needs_key := false
	for box in get_nodes_in_group(DialogueBox.GROUP):
		needs_key = needs_key or bool(box.get("_blocking"))
	for spot in get_nodes_in_group(TutorialSpotlight.GROUP):
		needs_key = needs_key or (bool(spot.get("_open")) and float(spot.get("_age"))>2.0)
	# A page of her diary, open over the game -- her last, at the easel: read, then CONTINUE, which
	# has the focus, so Enter is the key a player presses.
	for overlay in get_nodes_in_group(ModalOverlay.GROUP):
		needs_key = needs_key or (overlay is DiaryOverlay and (overlay as DiaryOverlay).is_open())
	if needs_key:
		_key(KEY_ENTER)
		read_left = 1.0

func _key(code: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = true
	root.push_input(key,true)
	key = key.duplicate()
	key.pressed = false
	root.push_input(key,true)

func _clear_ui() -> void:
	var until := Time.get_ticks_msec()+16000
	while paused and Time.get_ticks_msec()<until:
		await create_timer(.05,true).timeout

func _travel(to_x: float) -> bool:
	print("WALK ",to_x," from ",player.global_position)
	var until := Time.get_ticks_msec()+90000
	var tick := 0
	Input.action_press("move_right")
	Input.action_press("move_up")
	while player.global_position.x<to_x and Time.get_ticks_msec()<until:
		if tick%48==0: Input.action_press("jump")
		if tick%48==26: Input.action_release("jump")
		await physics_frame
		tick += 1
	for action in ["move_right","move_up","jump"]: Input.action_release(action)
	return player.global_position.x>=to_x

func _grounded() -> void:
	for frame in range(90):
		if player.is_on_floor(): return
		await physics_frame

func _save_memory(id: String) -> void:
	var target = level.call("_fragment_here")
	if target == null or String(target.fragment_id)!=id:
		_check(false,"memory target is "+id,str(target.fragment_id if target!=null else "none"))
		return
	_key(KEY_R)
	await process_frame
	var sketch: Node = level.get("memory_sketch")
	if not sketch.is_open():
		_check(false,"the memory sketchbook opens for "+id,"closed")
		return
	await create_timer(.6,true).timeout
	await _stroke(sketch.canvas)
	await _click(sketch.preserve_button)
	_check(String(target.state())=="saved","the continuous route saves "+id,str(player.global_position))
	await _clear_ui()

func _paint_page() -> bool:
	var panel: DrawPanel = level.get("draw_panel")
	# A line still up is read first; a page already open is drawn on at once. Waiting that pause
	# out as well left the page untouched, and an untouched page plays on without her lines.
	if not panel.is_open():
		await _clear_ui()
	if not panel.is_open(): _key(KEY_R)
	await process_frame
	if not panel.is_open() or not panel.is_refusing(): return false
	await _stroke(panel.canvas_viewport_container)
	await _click(panel.transform_button)
	var until := Time.get_ticks_msec()+6000
	while panel.is_open() and Time.get_ticks_msec()<until:
		await create_timer(.05,true).timeout
	quiet_attempts += 1
	return not panel.is_open()

func _click(control: Control) -> void:
	# Guided ending pages now wait for the player's explicit Paint action.
	var at := control.get_global_rect().get_center()
	var hover := InputEventMouseMotion.new()
	hover.position = at
	_mouse(hover)
	await create_timer(.1,true).timeout
	for pressed in [true,false]:
		var click := InputEventMouseButton.new()
		click.position = at
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		_mouse(click)
		await process_frame

func _stroke(surface: Control) -> void:
	var middle := surface.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.position = middle-Vector2(65,0)
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	_mouse(down)
	await process_frame
	for at in [middle+Vector2(0,-85),middle+Vector2(65,0)]:
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		_mouse(motion)
		await process_frame
	var up := down.duplicate() as InputEventMouseButton
	up.position = middle+Vector2(65,0)
	up.pressed = false
	_mouse(up)

func _mouse(event: InputEventMouse) -> void:
	Input.warp_mouse(event.position*(Vector2(DisplayServer.window_get_size())/root.get_visible_rect().size))
	event.global_position = event.position
	root.push_input(event,true)

func _photo(label: String) -> void:
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.resize(1600,900,Image.INTERPOLATE_NEAREST)
	picture.save_png(shots+label+".png")

func _fail(reason: String) -> void:
	print("OBRA_LEVEL5_FINISH_WALK_FAILED ",reason," at ",player.global_position)
	quit(1)
