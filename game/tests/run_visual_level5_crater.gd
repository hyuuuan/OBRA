extends SceneTree
## Actual scenery passes, character and foreground mask. Run with a real viewport.
var level: Node
var journey: Node
var output := "/tmp/obra_level5_crater"
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This visual tour needs a real viewport")
		quit(1)
		return
	root.size = Vector2i(1600,900)
	root.content_scale_size = Vector2i(1600,900)
	DirAccess.make_dir_recursive_absolute(output)
	level = load("res://level_5.tscn").instantiate()
	level.get_node("BackendSupervisor").auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, "set_auto_dismiss", true)
	await create_timer(.4).timeout
	journey = level.get("_journey")
	level.call("_on_backend_ready")
	await _put(Vector2(4910,98))
	await _shot("00_crater")
	await _check_lava()
	level.set("_phase", "memories")
	level.set("_lolo_moment", "gone")
	level.get("lolo").vanish()
	level.call("_set_journey_visible",true)
	for index in range(12):
		var place: Dictionary = journey.places[index]
		await _put(Vector2(float(place.start)+float(place.length)*.5,98))
		await _shot("%02d_%s" % [index+1,place.id])
		if index in [0,7,10]: await _check_life(String(place.id))
		if index < 11:
			for progress in [.25,.5,.75]:
				var boundary := float(journey.places[index+1].start)
				var x: float = boundary + (progress-.5)*1600.0/2.2
				await _put(Vector2(x,98))
				await _shot("wipe_%02d_%02d" % [index,int(progress*100)])
				if index == 2 and is_equal_approx(float(progress),.5): await _check_composite()
	root.size = Vector2i(1600,1000)
	root.content_scale_size = Vector2i(1600,1000)
	await _put(Vector2(11120,98))
	await _shot("tall_church")
	await _put(Vector2(10480,98))
	await _shot("tall_wipe")
	for index in [0,7,10]:
		var place: Dictionary = journey.places[index]
		# This is a second composition preview, rather than a replay of lost choices.
		for fragment: MemoryFragment2D in journey.fragments:
			if fragment.vignette_id == String(place.id): fragment.restore_to("whole")
		await _put(Vector2(float(place.start)+float(place.length)*.5,98))
		await _shot("tall_%s"%place.id)
	print("OBRA_VISUAL_LEVEL5_CRATER_%s " % ("OK" if failures==0 else "FAILED"),output)
	level.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)

func _put(point: Vector2) -> void:
	level.get("player").call("apply_morph_state", {"position":point,"linear_velocity":Vector2.ZERO})
	var camera: Camera2D = level.call("_world_camera")
	for i in range(18): await physics_frame
	camera.call("snap_to_target")
	camera.force_update_scroll()
	journey.sync()
	for i in range(4): await process_frame

func _shot(label: String) -> void:
	await create_timer(.35).timeout
	# This fixture deliberately starts no backend. Its reconnect status is not scenery.
	level.get("status_label").text=""
	level.get("status_label").hide()
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output+"/"+label+".png")
	if result != OK: push_error("Could not save "+label)

func _check_composite() -> void:
	await RenderingServer.frame_post_draw
	var rendered := root.get_texture().get_image()
	var outgoing: Image = journey.get_node("SceneryPass0").get_texture().get_image()
	var incoming: Image = journey.get_node("SceneryPass1").get_texture().get_image()
	var edge := int(journey.divider*rendered.get_width())
	var clear_offset := int(journey.column_pixels*.5+journey.column_softness_pixels+20)
	var left := Vector2i(edge-clear_offset,450)
	var right := Vector2i(edge+clear_offset,450)
	var old_matches := _distance(rendered.get_pixelv(left),outgoing.get_pixelv(left)) < .04
	var new_matches := _distance(rendered.get_pixelv(right),incoming.get_pixelv(right)) < .04
	var distinct := _distance(outgoing.get_pixelv(left),incoming.get_pixelv(left)) > .08
	var covers := rendered.get_pixel(edge,450).get_luminance()<.04 \
		and rendered.get_pixel(edge,650).get_luminance()<.04
	var soft_x := edge+int(journey.column_pixels*.5+journey.column_softness_pixels*.5)
	var soft := rendered.get_pixel(soft_x,450).get_luminance()
	var clear := incoming.get_pixel(soft_x,450).get_luminance()
	var feathered := soft>.01 and soft<clear*.85
	var ok := old_matches and new_matches and distinct and covers and feathered
	failures += int(not ok)
	print("  %s actual rendered mask: old left, new right, distinct places, foreground occlusion, soft edge %s" %
		["OK" if ok else "FAIL",[old_matches,new_matches,distinct,covers,feathered]])

func _distance(a: Color,b: Color) -> float:
	return Vector3(a.r,a.g,a.b).distance_to(Vector3(b.r,b.g,b.b))

func _check_life(id: String) -> void:
	var camera: Camera2D = level.call("_world_camera")
	var rendered_follow := camera.is_processing()
	var physics_follow := camera.is_physics_processing()
	camera.set_process(false)
	camera.set_physics_process(false)
	journey.sync()
	await process_frame
	await RenderingServer.frame_post_draw
	var before: Image = journey.get_node("SceneryPass0").get_texture().get_image()
	await create_timer(.65).timeout
	await RenderingServer.frame_post_draw
	var after: Image = journey.get_node("SceneryPass0").get_texture().get_image()
	var changed := 0
	for y in range(140,780,3):
		for x in range(300,1350,3):
			changed += int(_distance(before.get_pixel(x,y),after.get_pixel(x,y))>.06)
	var ok := changed>12
	failures+=int(not ok)
	camera.set_process(rendered_follow)
	camera.set_physics_process(physics_follow)
	print("  %s visible memory life in %s: %d changed samples"%["OK" if ok else "FAIL",id,changed])

func _check_lava() -> void:
	await RenderingServer.frame_post_draw
	var first := root.get_texture().get_image()
	await create_timer(.7).timeout
	await RenderingServer.frame_post_draw
	var second := root.get_texture().get_image()
	var colours: Dictionary = {}
	var changed := 0
	for x in range(1010,1210,4):
		for y in range(830,890,4):
			var colour := first.get_pixel(x,y)
			colours[colour.to_html(false)]=true
			changed+=int(_distance(colour,second.get_pixel(x,y))>.03)
	var ok := colours.size()>12 and changed>60
	failures+=int(not ok)
	print("  %s rendered lava has moving molten cells: %d colours, %d changed samples" %
		["OK" if ok else "FAIL",colours.size(),changed])
