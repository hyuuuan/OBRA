extends "res://tests/run_walk_level5.gd"
## Continuous movement from spawn to the frame return. Recognized normal drawings are fixtures;
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
	if not await _travel(5840):
		_fail("could not reach the first memory cluster")
		return
	await _clear_ui()
	await _save_memory("terraces","stairs")
	await _photo("02_memories")
	if not await _travel(7280):
		_fail("could not reach the second memory cluster")
		return
	await _clear_ui()
	await _save_memory("church","door")
	if not await _travel(8010):
		_fail("could not cross the second memory cluster")
		return
	await _clear_ui()
	await _save_memory("bangka","sailboat")
	if not await _travel(9440):
		_fail("could not reach the flower detour")
		return
	await _grounded()
	if not await _travel(10200):
		_fail("could not climb the flower detour")
		return
	await _grounded()
	await _clear_ui()
	await _photo("03_flower")
	await _save_memory("flower","sun")
	_check(is_zero_approx(level.get("ink_manager").remaining()),"two gate drawings and four memories use exactly six visible units",str(level.get("ink_manager").remaining()))
	if not await _travel(11550):
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
	if not await _travel(12710):
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
	var frame_seen := false
	var pickup_seen := false
	var bouquet_seen := false
	until = Time.get_ticks_msec()+90000
	while is_instance_valid(level) and Time.get_ticks_msec()<until:
		var lola = level.call("_lola")
		if is_instance_valid(lola) and lola.has_flowers() and not bouquet_seen:
			bouquet_seen = true
			await _photo("07_bouquet")
		var frame := level.get_node_or_null("FrameReturn") as FrameReturn
		if frame != null and not frame_seen:
			frame_seen = true
			await create_timer(1.1,true).timeout
			await _photo("08_room")
		if frame != null and frame.holds_ordinary_brush() and not pickup_seen:
			pickup_seen = true
			await _photo("09_brush")
		if bool(level.call("went_home")): break
		await create_timer(.05,true).timeout
	_check(bouquet_seen and frame_seen and pickup_seen,"bouquet, seated room and ordinary brush all appear on the continuous route",str([bouquet_seen,frame_seen,pickup_seen]))
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
	var until := Time.get_ticks_msec()+40000
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

func _save_memory(id: String, answer: String) -> void:
	var target = level.call("_fragment_here")
	if target == null or String(target.fragment_id)!=id:
		_check(false,"memory target is "+id,str(target.fragment_id if target!=null else "none"))
		return
	_key(KEY_R)
	await process_frame
	var panel: DrawPanel = level.get("draw_panel")
	if not panel.is_open():
		_check(false,"normal page opens for "+id,"closed")
		return
	await _stroke(panel)
	var strokes: Array = panel.canvas.get_strokes().duplicate(true)
	panel.close_panel()
	var drawing := Image.create(32,32,false,Image.FORMAT_RGBA8)
	level.call("_on_drawing_ready",answer,answer.capitalize(),drawing,{"confidence":.95},strokes,1.0)
	_check(String(target.state())=="saved","the continuous route saves "+id,str(player.global_position))
	await _clear_ui()

func _paint_page() -> bool:
	await _clear_ui()
	var panel: DrawPanel = level.get("draw_panel")
	if not panel.is_open(): _key(KEY_R)
	await process_frame
	if not panel.is_open() or not panel.is_refusing(): return false
	await _stroke(panel)
	var until := Time.get_ticks_msec()+6000
	while panel.is_open() and Time.get_ticks_msec()<until:
		await create_timer(.05,true).timeout
	quiet_attempts += 1
	return not panel.is_open()

func _stroke(panel: DrawPanel) -> void:
	var middle := panel.canvas_viewport_container.get_global_rect().get_center()
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
