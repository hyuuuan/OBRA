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
		if String(place.id) == "payyo_crossing": await _check_painted("the gorge wall beside the river", Rect2(.385,.87,.06,.09))
		if String(place.id) == "piyesta_church": await _check_painted("the church floor down to the frame", Rect2(.25,.9,.4,.08))
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
	# ⚠ IN THE VIEW'S OWN UNITS. On a Retina display the window's texture is ~2.1x the 1600x900 view
	# while the scenery passes are not, so a pixel index taken off one read a different place in
	# the other, and this check failed on a correct mask.
	var view := root.get_visible_rect().size
	var on_screen := float(rendered.get_width())/view.x
	var on_pass := float(outgoing.get_width())/view.x
	var edge: float = journey.divider*view.x
	var clear_offset: float = journey.column_pixels*.5+journey.column_softness_pixels+20
	var left := Vector2(edge-clear_offset,450)
	var right := Vector2(edge+clear_offset,450)
	# A patch's mean, not one pixel: in detailed art a single pixel one step off reads as a mismatch.
	var old_matches := _distance(_patch(rendered,left,on_screen),_patch(outgoing,left,on_pass)) < .04
	var new_matches := _distance(_patch(rendered,right,on_screen),_patch(incoming,right,on_pass)) < .04
	var distinct := _distance(_patch(outgoing,left,on_pass),_patch(incoming,left,on_pass)) > .08
	var covers := rendered.get_pixelv(Vector2i(Vector2(edge,450)*on_screen)).get_luminance()<.04 \
		and rendered.get_pixelv(Vector2i(Vector2(edge,650)*on_screen)).get_luminance()<.04
	var soft_x: float = edge+journey.column_pixels*.5+journey.column_softness_pixels*.5
	var soft := rendered.get_pixelv(Vector2i(Vector2(soft_x,450)*on_screen)).get_luminance()
	var clear := incoming.get_pixelv(Vector2i(Vector2(soft_x,450)*on_pass)).get_luminance()
	var feathered := soft>.01 and soft<clear*.85
	var ok := old_matches and new_matches and distinct and covers and feathered
	failures += int(not ok)
	print("  %s actual rendered mask: old left, new right, distinct places, foreground occlusion, soft edge %s" %
		["OK" if ok else "FAIL",[old_matches,new_matches,distinct,covers,feathered]])

## Kent, 2026-11-05: parts of the runway "not rendering properly". Under the bridge was one flat dark
## box, and under the church floor one flat brown band. In a painted surface no one colour covers
## much of it; in a fill, one colour is nearly all of it. `area` is a fraction of the frame.
func _check_painted(what: String, area: Rect2) -> void:
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	var size := Vector2(frame.get_size())
	var counts := {}
	var samples := 0
	for y in range(int(area.position.y*size.y), int(area.end.y*size.y), 3):
		for x in range(int(area.position.x*size.x), int(area.end.x*size.x), 3):
			var c := frame.get_pixel(x, y)
			var key := Vector3i(int(c.r*31), int(c.g*31), int(c.b*31))
			counts[key] = int(counts.get(key, 0))+1
			samples += 1
	var commonest := 0
	for key: Vector3i in counts:
		commonest = maxi(commonest, int(counts[key]))
	var share := float(commonest)/maxf(1.0, float(samples))
	var ok := share < 0.35
	failures += int(not ok)
	print("  %s %s is painted, not a flat fill: its commonest colour covers %d%%" % [
		"OK" if ok else "FAIL", what, int(share*100.0)])

## The mean colour of a 13x13 view-unit patch centred on `at`, read off an image `scale` times the view.
func _patch(image: Image, at: Vector2, scale: float) -> Color:
	var sum := Color(0,0,0,0)
	var n := 0
	for dy in range(-6,7,2):
		for dx in range(-6,7,2):
			var p := Vector2i((at+Vector2(dx,dy))*scale)
			if p.x < 0 or p.y < 0 or p.x >= image.get_width() or p.y >= image.get_height(): continue
			sum += image.get_pixelv(p)
			n += 1
	return sum/maxf(1.0,float(n))

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
	# ⚠ WHERE THE LAVA IS, NOT A FIXED PIXEL BOX. The box was 1010..1210 x 830..890 in window pixels,
	# which is the lava only on a 1600x900 window at scale 1: on a Retina display the window texture
	# is ~2.1x the view, and a taller window fits the camera closer, so it sampled crater rock.
	var lava := level.find_child("MoltenSurface", true, false) as Polygon2D
	var molten := Rect2()
	for point in lava.polygon:
		var on_view: Vector2 = level.get_viewport().get_canvas_transform() * (lava.global_transform * point)
		molten = Rect2(on_view, Vector2.ZERO) if molten.size == Vector2.ZERO and molten.position == Vector2.ZERO \
			else molten.expand(on_view)
	# Inside its rim, away from the rock that overlaps its edges.
	molten = molten.grow_individual(-molten.size.x * .2, -2.0, -molten.size.x * .2, -molten.size.y * .35)
	# Only what is on screen: the pool runs on below the frame's bottom edge.
	molten = molten.intersection(Rect2(Vector2.ZERO, root.get_visible_rect().size - Vector2.ONE))
	await RenderingServer.frame_post_draw
	var first := root.get_texture().get_image()
	await create_timer(.7).timeout
	await RenderingServer.frame_post_draw
	var second := root.get_texture().get_image()
	var k := float(first.get_width()) / root.get_visible_rect().size.x
	var colours: Dictionary = {}
	var changed := 0
	var samples := 0
	for x in range(int(molten.position.x*k), int(molten.end.x*k), maxi(1, int(4*k))):
		for y in range(int(molten.position.y*k), int(molten.end.y*k), maxi(1, int(2*k))):
			var colour := first.get_pixel(x,y)
			colours[colour.to_html(false)]=true
			changed+=int(_distance(colour,second.get_pixel(x,y))>.03)
			samples+=1
	var ok := colours.size()>12 and changed>samples*.15
	failures+=int(not ok)
	print("  %s rendered lava has moving molten cells: %d colours, %d of %d samples changed" %
		["OK" if ok else "FAIL",colours.size(),changed,samples])
