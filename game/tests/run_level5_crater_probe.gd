extends SceneTree
## The new journey's contracts: actual entry input, complementary mask geometry, preservation,
## zero-ink traversal, reversible scenery, irreversible choices and legacy checkpoint landings.
var level: Node
var journey: Node
var failures := 0
var checked := 0
var player: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	level = load("res://level_5.tscn").instantiate()
	level.get_node("BackendSupervisor").auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, "set_auto_dismiss",true)
	await create_timer(.3).timeout
	journey = level.get("_journey")
	player = level.get("player")
	if OS.get_cmdline_user_args().has("--flower-only"):
		level.set("_phase","memories")
		level.call("_set_journey_visible",true)
		await _flower_walk()
		quit(failures)
		return
	_check(journey.places.size() == 13 and journey.fragments.size() == 12,
		"twelve playable places and a final summit, with the twelve original preservation IDs")
	var cone: Array = level.get_node("EnvironmentBaseplate/GameplayPlane/Terrain/Cone").get("platforms")
	_check(cone.size()==2 and is_equal_approx(cone[1].position.x-cone[0].end.x,500.0)
		and is_equal_approx((cone[1].position.x+cone[0].end.x)*.5,journey.anchor("crater").x),
		"the visible crater and its entry anchor agree with the actual opening in collision")
	var bodies := 0
	for scene in journey.scenes:
		bodies += scene.find_children("*","CollisionObject2D",true,false).size()
	_check(bodies == 0 and journey.get_node("SceneryPass0").find_world_2d() != root.find_world_2d(),
		"scenery passes own no physics, player, companion or duplicate gameplay")
	await _put(Vector2(4880,98))
	Input.action_press("move_right")
	Input.action_press("jump")
	var end := Time.get_ticks_msec()+6000
	while level.call("journey_phase") != "memories" and Time.get_ticks_msec()<end:
		await physics_frame
	Input.action_release("move_right")
	Input.action_release("jump")
	_check(level.call("journey_phase") == "memories" and player.global_position.x >= 6000,
		"running and jumping into the open crater enters the memories without E or a death")
	_check(is_equal_approx(level.get("ink_manager").remaining(),6.0),"the crater charges no ink")
	level.get("status_label").text = ""
	await _mask_contracts()
	await _preservation_contracts()
	await _morph_contract()
	if not OS.get_cmdline_user_args().has("--quick"): await _walking_contracts()
	_legacy_contracts()
	await _farewell_contract()
	for action in ["move_right","move_left","move_up","jump"]: Input.action_release(action)
	level.queue_free()
	for i in range(5): await process_frame
	print("OBRA_LEVEL5_CRATER_%s (%d checks)" % ["OK" if failures==0 else "FAILED",checked])
	quit(0 if failures==0 else 1)

func _mask_contracts() -> void:
	var camera: Camera2D = level.call("_world_camera")
	camera.set_process(false)
	level.set_physics_process(false)
	player.set_physics_process(false)
	var boundary := float(journey.places[1].start)
	camera.global_position = Vector2(boundary,-162)
	camera.force_update_scroll()
	journey.sync()
	var initial: float = journey.divider
	camera.position.x += 40
	camera.force_update_scroll()
	journey.sync()
	var moved: float = journey.divider
	var width := root.get_visible_rect().size.x
	_check(journey.pair == Vector2i(0,1) and absf((initial-moved)*width - 40*camera.zoom.x*2.2)<.1,
		"the foreground divider advances at 2.2 times camera travel between adjacent places")
	camera.position.x -= 40
	camera.force_update_scroll()
	journey.sync()
	_check(is_equal_approx(journey.divider,initial),"backtracking reverses the exact same mask")
	journey.sync()
	_check(is_equal_approx(journey.divider,initial),"an idle camera does not advance the transition")
	var left := camera.global_position+Vector2(-160,0)
	var right := camera.global_position+Vector2(160,0)
	_check(journey.active_index(left)==0 and journey.active_index(right)==1,
		"interaction ownership uses the same left/right divider as the renderer")
	var a: SubViewport = journey.get_node("SceneryPass0")
	var b: SubViewport = journey.get_node("SceneryPass1")
	_check(a.canvas_transform==root.canvas_transform and b.canvas_transform==root.canvas_transform,
		"both scenery passes use the gameplay canvas transform without a second camera")
	var visible := 0
	for scene in journey.scenes: visible += int(scene.visible)
	_check(visible==2,"only the adjacent scenery pair is visible during a crossing")
	root.size = Vector2i(1600,1000)
	camera.force_update_scroll()
	journey.sync()
	_check(a.size==root.size and b.size==root.size,"both render targets follow viewport resizing")
	root.size = Vector2i(1600,900)
	var original_zoom := camera.zoom
	camera.zoom = Vector2.ONE * .8
	camera.force_update_scroll()
	journey.sync()
	_check(a.canvas_transform==root.canvas_transform and b.canvas_transform==root.canvas_transform,
		"zoom keeps both scenery passes registered with the actual gameplay camera")
	camera.zoom = original_zoom
	camera.force_update_scroll()
	journey.sync()
	level.call("_open_the_page",true)
	var paused_seam: float = journey.divider
	camera.position.x += 50
	camera.force_update_scroll()
	journey.sync()
	_check(is_equal_approx(journey.divider,paused_seam),"a moving dialogue camera cannot advance a paused crossing")
	level.get("draw_panel").close_panel()
	level.get("memory_sketch").close()
	camera.position.x -= 50
	camera.force_update_scroll()
	journey.sync()
	var profile := root.get_node("PlayerProfile")
	profile.call("set_setting","reduce_motion",true)
	var crater: Node = level.get_node("EnvironmentBaseplate/GameplayPlane/Crater")
	var clock: float = crater.get("_clock")
	crater.call("_process",.2)
	camera.position.x += 20
	camera.force_update_scroll()
	var old_seam: float = journey.divider
	journey.sync()
	_check(is_equal_approx(crater.get("_clock"),clock) and journey.divider<old_seam,
		"Reduce Motion holds eruption animation while the functional mask still responds to travel")
	profile.call("set_setting","reduce_motion",false)
	player.set_physics_process(true)
	level.set_physics_process(true)
	camera.set_process(true)

func _preservation_contracts() -> void:
	var terraces: MemoryFragment2D = level.call("_fragment","terraces")
	await _put(terraces.global_position+Vector2(0,-42))
	await create_timer(.15).timeout
	_check(terraces.is_targeted() and terraces.landmark_mode,"a reachable live landmark is the drawing target")
	level.call("_open_the_page",true)
	var before := terraces.drain()
	var seam: float = journey.divider
	await create_timer(.2).timeout
	_check(is_equal_approx(terraces.drain(),before) and is_equal_approx(journey.divider,seam),
		"drawing pauses preservation and shadow travel")
	var sketch: Node = level.get("memory_sketch")
	_check(sketch.is_open() and not level.get("draw_panel").is_open(),
		"preservation opens a separate page from recognition")
	# Move while the page is paused. The drawing must still use its locked landmark.
	player.call("apply_morph_state",{"position":Vector2(6250,98),"linear_velocity":Vector2.ZERO})
	var strokes := [{"points":PackedVector2Array([Vector2(12,19),Vector2(51,89),Vector2(92,21)]),"width":6.0,"color":Color.BLACK}]
	var ink: InkManager = level.get("ink_manager")
	var reserve := ink.hidden_reserve
	level.call("_preserve_memory", strokes)
	_check(terraces.state()=="saved" and terraces.strokes()==[[12.0,19.0,51.0,89.0,92.0,21.0]]
		and is_equal_approx(ink.remaining(),5) and is_equal_approx(ink.hidden_reserve,reserve),
		"the locked landmark saves exact strokes for one visible ink and cannot spend reserve")
	var snapshot: Dictionary = level.call("_level_run_state")
	terraces.restore_to("whole")
	level.call("_restore_level_run_state",snapshot)
	_check(terraces.state()=="saved" and level.get("_save_order")==["terraces"] and snapshot.layout_version==5,
		"the compact layout restores preserved outcomes, original strokes and save order")
	var profile := root.get_node("PlayerProfile")
	var count: int = profile.call("route_count","artist")
	level.call("_on_fragment_saved","flower")
	level.set("_flower_credited",false)
	level.call("_on_fragment_saved","flower")
	_check(int(profile.call("route_count","artist"))==count+1,"flower credit remains durable and idempotent")
	# A later crossing closes an unsaved choice. Walking back changes scenery, not its outcome.
	await _put(Vector2(9940,98))
	await create_timer(4.2).timeout
	var kubo: MemoryFragment2D = level.call("_fragment","kubo")
	await _put(kubo.global_position+Vector2(0,-42))
	_check(kubo.state()=="lost" and not kubo.is_open(),"backtracking cannot reopen a departed preservation choice")
	await _put(Vector2(11090,140))
	var camera: Camera2D = level.call("_world_camera")
	camera.global_position.x = 11120.0
	camera.force_update_scroll()
	journey.sync()
	level.call("_write_checkpoint","CP1")
	var saved_camera := camera.global_position
	var saved_divider: float = journey.divider
	await _put(Vector2(10600,140))
	level.call("_restore_checkpoint")
	_check(camera.global_position==saved_camera and is_equal_approx(journey.divider,saved_divider),
		"a checkpoint restores its in-progress crossing and exact camera position")

func _morph_contract() -> void:
	await _put(Vector2(7180,140))
	var ink: InkManager = level.get("ink_manager")
	var committed := ink.committed
	var image := Image.create(32,32,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var strokes := [{"points":PackedVector2Array([Vector2(0,60),Vector2(35,0),Vector2(70,60)]),"width":6.0,"color":Color.BLACK}]
	var became: bool = level.call("_spawn_or_replace","monkey","Monkey",image,strokes)
	player=level.get("player")
	Input.action_press("move_right")
	for frame in range(180): await physics_frame
	Input.action_release("move_right")
	_check(became and player.get_viewport()==root and player.global_position.x>7280,
		"a drawn creature crosses the shadow in the sole gameplay world")
	level.call("_revert_to_base_form")
	player=level.get("player")
	ink.committed=committed

func _walking_contracts() -> void:
	level.set("_lolo_moment","gone")
	level.get("lolo").vanish()
	var ink: InkManager = level.get("ink_manager")
	ink.committed = ink.capacity
	await _put(journey.anchor("entry"))
	Input.action_press("move_right")
	var arrived := false
	var lowest := -INF
	for frame in range(7200):
		if frame%48==20: Input.action_press("jump")
		elif frame%48==46: Input.action_release("jump")
		await physics_frame
		lowest = maxf(lowest,player.global_position.y)
		if player.global_position.x > 21300:
			arrived = true
			break
	Input.action_release("move_right")
	Input.action_release("jump")
	_check(arrived and lowest<400 and is_zero_approx(ink.remaining()),
		"real movement traverses every memory with zero ink and no required transformation")
	await _flower_walk()

func _flower_walk() -> void:
	await _put(Vector2(20180,98))
	Input.action_press("move_right")
	Input.action_press("move_up")
	var flower_reached := false
	for frame in range(450):
		if frame%48==20: Input.action_press("jump")
		elif frame%48==46: Input.action_release("jump")
		await physics_frame
		if level.call("_fragment_here")==level.call("_fragment","flower"):
			flower_reached=true
			break
	for action in ["move_right","move_up","jump"]: Input.action_release(action)
	print("FLOWER TRACE ",player.global_position," floor ",player.is_on_floor()," target state ",level.call("_fragment","flower").state()," place ",journey.current_id(player.global_position))
	_check(flower_reached,"the optional flower is reached through its actual three footholds")

func _legacy_contracts() -> void:
	var state: Dictionary = level.call("_level_run_state")
	state.layout_version=3
	var snapshots: Dictionary = state.fragments
	level.get("checkpoints").call("write","CP1",{"level":state,"position":Vector2(8700,-350)})
	level.call("_restore_level_run_state",state)
	var landing: Vector2 = level.call("_checkpoint_landing",{"level":state,"position":Vector2(8700,-350)})
	_check(landing==journey.anchor("entry") and level.call("journey_phase")=="memories"
		and snapshots==level.call("_level_run_state").fragments,"legacy CP1 maps to safe entry without losing preservation data")
	level.get("checkpoints").call("write","CP2",{"level":state,"position":Vector2(11900,-500)})
	level.call("_restore_level_run_state",state)
	landing=level.call("_checkpoint_landing",{"level":state,"position":Vector2(11900,-500)})
	_check(landing==journey.anchor("summit")+Vector2(-100,0) and level.get("_lolo_moment")=="gone",
		"legacy CP2 maps below the new summit and keeps Lolo gone")
	state.layout_version=4
	state.phase="memories"
	state.active_vignette="dagat_shore"
	var ink_before: float = level.get("ink_manager").remaining()
	level.get("checkpoints").call("write","CP1",{"level":state,"position":Vector2(17900,98)})
	level.call("_restore_level_run_state",state)
	landing=level.call("_checkpoint_landing",{"level":state,"position":Vector2(17900,98)})
	_check(landing==Vector2(float(journey.places[6].start)+170,98)
		and snapshots==level.call("_level_run_state").fragments
		and level.get("_restored_camera").is_empty()
		and is_equal_approx(ink_before,level.get("ink_manager").remaining()),
		"the longer layout resumes at its matching compact place with outcomes and ink intact")

func _put(point: Vector2) -> void:
	player.call("apply_morph_state",{"position":point,"linear_velocity":Vector2.ZERO})
	level.call("_world_camera").snap_to_target()
	level.call("_world_camera").force_update_scroll()
	journey.sync()
	for i in range(8): await physics_frame

func _check(ok: bool, description: String) -> void:
	checked+=1
	failures+=int(not ok)
	print("  %s\t%s" % ["OK" if ok else "FAIL",description])


func _farewell_contract() -> void:
	var flower: MemoryFragment2D = level.call("_fragment","flower")
	flower.restore_to("whole")
	level.set("_phase","memories")
	level.set("_lolo_moment","")
	var lolo: Lolo = level.get("lolo")
	lolo.set("_vanished",false)
	lolo.show()
	await _put(Vector2(float(level.call("lolo_goes_at"))+20,140))
	_check(level.call("journey_phase")=="farewell" and not flower.is_open(),
		"Lolo's farewell closes the final preservation choices before backtracking can reopen them")
	call_group(DialogueBox.GROUP,"hide_line")
	lolo.vanish()
	level.set("_lolo_moment","gone")
	level.set("_flower_credited",false)
	level.call("_on_fragment_saved","flower")
	await process_frame
	_check(not level.get("dialogue_box").is_open(),"a late or migrated flower reward cannot bring Lolo's voice back")
