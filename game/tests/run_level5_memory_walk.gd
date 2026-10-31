extends SceneTree
## Only the repaired memory terrain: real movement, target reach, framing and old landings.
var level: Node
var player: Node2D
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for i in range(3):
		await _open()
		if i == 0:
			await create_timer(.8).timeout
			await _photo("opening")
			if OS.get_cmdline_user_args().has("--opening-only"):
				await _close()
				quit(0)
				return
			player.call("apply_morph_state", {"position":Vector2(4800,50),"linear_velocity":Vector2.ZERO})
			for frame in range(30): await physics_frame
			level.call("_write_checkpoint","CP1")
		var entry: Dictionary = level.get("_cluster_data")[i]
		var start := Vector2(float(entry.entry) + 140.0, 10.0 - 160.0*i)
		player.call("apply_morph_state", {"position":start,"linear_velocity":Vector2.ZERO})
		for frame in range(20): await physics_frame
		level.call("_world_camera").snap_to_target()
		# Camera2D commits its canvas transform during the frame, after snap_to_target.
		await process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
		var visible_all := true
		var view := root.get_visible_rect()
		for id in entry.members:
			var fragment: Node2D = level.call("_fragment",id)
			var picture: Sprite2D = fragment.get_node("Picture")
			var bounds := picture.get_global_transform_with_canvas() * Rect2(-picture.texture.get_size()*.5, picture.texture.get_size())
			visible_all = visible_all and view.encloses(bounds)
		_check(visible_all,"cluster %d frames all four memories" % (i+1))
		await create_timer(.3).timeout
		await _photo("cluster%d" % (i+1))
		if i == 0:
			level.call("_restore_checkpoint")
			for frame in range(8): await physics_frame
			var camera = level.call("_world_camera")
			camera.snap_to_target()
			_check(player.global_position.x < float(entry.entry) and camera.room_bounds == Rect2()
				and absf(camera.global_position.x-player.global_position.x) < 400.0,
				"a checkpoint outside the memories clears the old camera room")
			player.call("apply_morph_state", {"position":start,"linear_velocity":Vector2.ZERO})
			for frame in range(20): await physics_frame
		var seen: Array[String] = []
		Input.action_press("move_right")
		for frame in range(600):
			if frame % 48 == 0: Input.action_press("jump")
			if frame % 48 == 26: Input.action_release("jump")
			await physics_frame
			var target = level.call("_fragment_here")
			if target != null and target.fragment_id not in seen:
				seen.append(target.fragment_id)
			if player.global_position.x >= float(entry.exit)-50.0: break
		Input.action_release("move_right")
		Input.action_release("jump")
		var expected: Array = entry.members.duplicate()
		expected.erase("flower")
		var reached := true
		for id in expected: reached = reached and id in seen
		_check(reached and is_equal_approx(level.get("ink_manager").remaining(),6.0),
			"cluster %d memories can be selected along a normal climb: %s" % [i+1,seen])
		if i == 2:
			player.call("apply_morph_state",{"position":Vector2(10190,-430),"linear_velocity":Vector2.ZERO})
			for frame in range(24): await physics_frame
			_check(level.call("_fragment_here") != level.call("_fragment","flower"),"the flower cannot be taken from the main path")
			# Nor from the top of a jump off that path, which comes within its raw reach.
			var flower: MemoryFragment2D = level.call("_fragment","flower")
			player.call("apply_morph_state",{"position":Vector2(10230,-422),"linear_velocity":Vector2.ZERO})
			for frame in range(12): await physics_frame
			Input.action_press("jump")
			var nearest_air := INF
			var taken_air := false
			for frame in range(40):
				await physics_frame
				nearest_air = minf(nearest_air, flower.global_position.distance_to(player.global_position))
				taken_air = taken_air or level.call("_fragment_here") == flower
			Input.action_release("jump")
			_check(flower.is_open() and nearest_air < flower.reach and not taken_air,
				"a jump from the path comes within the flower's reach but cannot take it: %.0f px" % nearest_air)
		await _close()
	# The optional rocks use one-way collision so the main path stays open underneath.
	await _open()
	player.call("apply_morph_state",{"position":Vector2(9440,-270),"linear_velocity":Vector2.ZERO})
	for frame in range(20): await physics_frame
	Input.action_press("move_right")
	var flower_reached := false
	for frame in range(600):
		if frame % 48 == 0: Input.action_press("jump")
		if frame % 48 == 26: Input.action_release("jump")
		await physics_frame
		if player.is_on_floor() and level.call("_fragment_here") == level.call("_fragment","flower"):
			flower_reached = true
			break
	Input.action_release("move_right")
	Input.action_release("jump")
	_check(flower_reached and is_equal_approx(level.get("ink_manager").remaining(),6.0),"flower detour is reachable by jumping without drawing: %s" % player.global_position)
	await _photo("flower")
	level.get("checkpoints").call("write","CP1",{})
	var old := {"level":{"layout_version":2,"clusters_left":["memory_2"]},"position":Vector2(8650,-180)}
	_check(level.call("_checkpoint_landing",old) == Vector2(8700,-350),"old shelf saves land above the rebuilt path")
	await _close()
	print("OBRA_LEVEL5_MEMORY_WALK_%s" % ("OK" if failures == 0 else "FAILED"))
	quit(0 if failures == 0 else 1)

func _open() -> void:
	level = load("res://level_5.tscn").instantiate()
	level.get_node("BackendSupervisor").auto_start_backend = false
	level.set("intro_enabled",false)
	root.add_child(level)
	level.call("_on_backend_ready")
	level.set("_forgot",3)
	level.set("_corridor_seen",true)
	level.set("_lolo_moment","probe")
	call_group(DialogueBox.GROUP,"set_auto_dismiss",true)
	for frame in range(25): await physics_frame
	player = level.get("player")

func _close() -> void:
	level.queue_free()
	for frame in range(5): await process_frame

func _photo(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	frame.resize(1600,900,Image.INTERPOLATE_NEAREST)
	frame.save_png("/tmp/obra_mayon_repaired_"+label+".png")

func _check(ok: bool, message: String) -> void:
	print("  %s\t%s" % ["OK" if ok else "FAIL",message])
	failures += int(not ok)
