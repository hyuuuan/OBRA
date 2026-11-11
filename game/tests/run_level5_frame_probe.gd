extends SceneTree
## Mayon's last shot is the house (DIARY.md; Kent, 2026-11-01): "Lolo. Let's go home." -- and she
## is home, where Lolo is in every painting and Lola is waiting. The first time, Lola takes the apo
## for him, asks where he is, and walks the length of the house to her easel at the far end;
## after that she is at her easel, and the paintings keep him. (It was the frame's return, a
## separate painted room; the name of this probe is the beat's, not the room's.)
##
##   godot --headless --path game --script res://tests/run_level5_frame_probe.gd

## Every check this probe makes. A script error that skips them must not pass as quiet.
const CHECKS := 18
const HUB := "res://levels/hub/hub.tscn"
const MAYON := "res://level_5.tscn"
## What is said in the house, and by whom, in order -- Kent's own words, near enough.
const LINES := [
	["lola", "Mahal! You look so young!"],
	["apo", "Lola, I'm your apo. I'm not Lolo."],
	["lola", "Where is he, then?"],
	["apo", "He's right here. In all your works."],
	["lola", "Oh."],
	["lola", "Who are you? Will you watch me paint?"],
]

var failures := 0
var checked := 0
var _played := false


func _initialize() -> void:
	node_added.connect(func(node: Node) -> void:
		if node is BackendSupervisor:
			node.auto_start_backend = false)
	call_deferred("_run")


func _run() -> void:
	var profile := root.get_node("PlayerProfile")
	profile.call("reset_progress")
	await _mayon_says_lets_go_home_and_goes()
	profile.call("reset_progress")
	await _before_mayon_the_house_is_as_it_was()
	profile.call("mark_level_completed", "level_5")
	await _the_first_time_lola_mistakes_her_for_him(profile)
	await _after_that_she_is_at_her_easel(profile)
	profile.call("reset_progress")
	await _lola_waits_for_the_way_home(profile)
	profile.call("reset_progress")
	profile.call("mark_level_completed", "level_5")
	await _while_she_talks_both_stand_above_the_box()
	profile.call("reset_progress")
	await _home_and_replay_with_no_memories(profile)
	profile.call("reset_progress")
	if failures == 0 and checked == CHECKS:
		print("OBRA_LEVEL5_FRAME_OK")
		quit(0)
	else:
		if checked != CHECKS:
			print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
		print("OBRA_LEVEL5_FRAME_FAILED=%d" % maxi(1, failures))
		quit(1)


func _mayon_says_lets_go_home_and_goes() -> void:
	var level := await _open_level()
	level.call("_play_own_ending")
	var home := await _until(func() -> bool: return not is_instance_valid(level) or bool(level.call("went_home")), 10.0)
	var said := is_instance_valid(level) and bool((level.get("script_lines") as Object).call("has_heard", "APO.home"))
	_check(home and said, "Mayon ends on \"Lolo. Let's go home.\" and goes home",
		"said %s, home %s" % [said, home])
	# The house it asked for is the current scene now; the checks below open their own.
	await _frames(30)
	if is_instance_valid(level):
		level.queue_free()
	if current_scene != null:
		current_scene.queue_free()
	await _frames(4)


func _before_mayon_the_house_is_as_it_was() -> void:
	var hub := await _open_hub()
	var plain := true
	for painting in _paintings(hub):
		plain = plain and not String((painting.get("art") as Texture2D).resource_path).ends_with("_lolo.png")
	_check(hub.call("epilogue") == null and plain and hub.find_child("Lola", true, false) == null,
		"before Mayon is finished the house is as it was: no Lola, no Lolo in the paintings",
		"epilogue %s, paintings plain %s" % [hub.call("epilogue") != null, plain])
	hub.queue_free()
	await _frames(4)


func _the_first_time_lola_mistakes_her_for_him(profile: Node) -> void:
	var old_page := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	old_page.fill(Color.WHITE)
	old_page.fill_rect(Rect2i(9, 9, 14, 14), Color.BLACK)
	profile.call("record_class_drawn", "square")
	profile.call("record_class_drawing", "square", old_page)
	var old_paths: PackedStringArray = profile.call("gallery_drawing_paths")
	var stroke := {"points": PackedVector2Array([Vector2(9, 11), Vector2(81, 24)]),
		"width": 7.0, "color": Color(0.12, 0.25, 0.55)}
	for _page in range(13):
		profile.call("record_gallery_drawing", [stroke])
	profile.call("load_profile")
	var paths: PackedStringArray = profile.call("gallery_drawing_paths")
	_check(old_paths.size() == 1 and paths.size() == 14 and paths[0].ends_with(".png"),
		"the gallery keeps an old class picture and every later submission after reload",
		"%d pages" % paths.size())
	var hub := await _open_hub(false)
	var epilogue := hub.call("epilogue") as HouseEpilogue
	var lolo := 0
	for painting in _paintings(hub):
		if String((painting.get("art") as Texture2D).resource_path).ends_with("_lolo.png"):
			lolo += 1
	var apo := hub.get_node("Apo") as Node2D
	var lola := epilogue.lola if epilogue != null else null
	var initial_paint := lola.painted()
	var held := bool(hub.call("is_revealing"))
	epilogue.finished.connect(_on_played)
	var done := await _until(func() -> bool: return _played, 40.0)
	# Waiting beside her and facing her as she speaks -- read off the first line as it was said: an
	# unattended run drops the lines at once, and by the next frame she is walking.
	var waiting := done and not epilogue.said.is_empty() and bool(epilogue.said[0]["facing"]) \
		and float(epilogue.said[0]["x"]) > apo.global_position.x
	_check(epilogue != null and lolo == 5 and waiting and held,
		"after Mayon Lolo is in all five paintings, and Lola is waiting beside her, facing her",
		"%d of 5 paintings, lola waiting %s, apo held %s" % [lolo, waiting, held])
	var lines: Array = []
	for entry: Dictionary in epilogue.said:
		lines.append([String(entry["speaker"]), String(entry["text"])])
	_check(done and lines == LINES, "she takes her for him, asks where he is, and is told: in all her works",
		"said %s" % [lines])
	var easel := epilogue.easel.global_position.x
	var at_easel := absf(lola.global_position.x - (easel - HouseEpilogue.AT_EASEL)) < 1.0
	var far := easel < float((_paintings(hub)[0] as Node2D).global_position.x)
	var last_there := epilogue.said.size() == LINES.size() \
		and absf(float(epilogue.said[-1]["x"]) - lola.global_position.x) < 1.0 \
		and float(epilogue.said[0]["x"]) > apo.global_position.x
	_check(done and at_easel and far and last_there,
		"then she walks the length of the house to her easel and asks who she is",
		"at the easel %s, at the far end %s, last line said there %s" % [at_easel, far, last_there])
	var painting := epilogue.easel.get_node_or_null(^"Canvas") as Sprite2D
	_check(painting != null and lola.painted() > initial_paint + 0.15,
		"Lola adds paint before the camera leaves the house easel",
		"canvas progress %.2f to %.2f" % [initial_paint, lola.painted()])
	var gallery := hub.get_node_or_null(^"DrawingGallery") as ModalOverlay
	var grid := gallery.get("_grid") as GridContainer if gallery != null else null
	_check(gallery != null and gallery.is_open() and grid != null and grid.get_child_count() == 12,
		"the gallery opens after the house scene", "first page of drawings")
	if gallery != null and gallery.is_open():
		(gallery.get("_next") as Button).pressed.emit()
		var line: Line2D
		if grid != null and grid.get_child_count() == 2:
			var ink := grid.get_child(0).get("_art") as Node2D
			line = ink.get_child(0) as Line2D if ink.get_child_count() > 0 else null
		_check(line != null and line.points == stroke["points"] \
				and line.width == stroke["width"] and line.default_color == stroke["color"],
			"Next shows the remaining drawings with their original ink", "last page")
		(gallery.get("_continue") as Button).pressed.emit()
	else:
		_check(false, "Next shows the remaining drawings", "no gallery")
	_check(done and not bool(hub.call("is_revealing")) and int(profile.call("dialogue_heard_count", "house_epilogue")) == 1,
		"and the house is hers again, and it is remembered",
		"held %s, heard %d" % [hub.call("is_revealing"), int(profile.call("dialogue_heard_count", "house_epilogue"))])
	hub.queue_free()
	await _frames(4)


func _after_that_she_is_at_her_easel(_profile: Node) -> void:
	var hub := await _open_hub(false)
	var epilogue := hub.call("epilogue") as HouseEpilogue
	await create_timer(2.0).timeout
	var lola := epilogue.lola
	var at_easel := absf(lola.global_position.x - (epilogue.easel.global_position.x - HouseEpilogue.AT_EASEL)) < 1.0
	var lolo := 0
	for painting in _paintings(hub):
		if String((painting.get("art") as Texture2D).resource_path).ends_with("_lolo.png"):
			lolo += 1
	_check(epilogue.said.is_empty() and at_easel and not lola.is_turned() and lolo == 5
			and not bool(hub.call("is_revealing")),
		"after that she is at her easel, painting, and the paintings keep him",
		"said %d, at the easel %s, turned %s, %d paintings" % [epilogue.said.size(), at_easel,
			lola.is_turned(), lolo])
	var button := hub.get_node_or_null(^"HubHud/DrawingsButton") as Button
	if button != null:
		button.pressed.emit()
	var gallery := hub.get_node_or_null(^"DrawingGallery") as ModalOverlay
	_check(gallery != null and gallery.is_open(), "Your Drawings reopens the gallery", "return visit")
	if gallery != null:
		gallery.close()
	hub.queue_free()
	await _frames(4)


## THE WAY HOME, AS A PLAYER TAKES IT. Mayon shrinks back into its frame (LevelManager
## _return_to_painting) while the house is built under it, with the interface held invisible until
## that has played. Every check above opens the house directly, with no transition at all; this
## one goes home the real way and asks whether Lola's first line waited for the house to be seen.
func _lola_waits_for_the_way_home(profile: Node) -> void:
	var manager := root.get_node("LevelManager")
	var level := await _open_level()
	current_scene = level
	manager.set("current_level_id", "level_5")
	profile.call("mark_level_completed", "level_5")
	var went := bool(manager.call("return_to_house"))
	var spoke_unseen := false
	var spoke_after := false
	var until := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < until and not spoke_after:
		await process_frame
		var hub := current_scene
		var epilogue: HouseEpilogue = hub.call("epilogue") \
			if hub != null and hub != level and hub.has_method("epilogue") else null
		if epilogue == null or epilogue.said.is_empty():
			continue
		if bool(manager.call("is_transitioning")):
			spoke_unseen = true
		else:
			spoke_after = true
	_check(went and spoke_after and not spoke_unseen,
		"going home the real way, Lola's first line waits until the house can be seen",
		"went %s, spoke during the way home %s, spoke after it %s" % [went, spoke_unseen, spoke_after])
	call_group(DialogueBox.GROUP, &"hide_line")
	await _frames(4)
	if current_scene != null:
		current_scene.queue_free()
	await _frames(4)


## Kent, 2026-11-05: "do something about it so that it wont hide both figures". The house talks
## over the bottom of the frame, where the floor was: only their heads showed above the box for the
## whole scene. While she talks, the eye drops so both stand above its top edge -- and the room is
## still drawn to the bottom of that lower view, not open onto nothing under the floor.
func _while_she_talks_both_stand_above_the_box() -> void:
	var hub := await _open_hub(false)
	var epilogue := hub.call("epilogue") as HouseEpilogue
	var until := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < until and (epilogue == null or epilogue.said.is_empty()):
		await process_frame
	# The eye takes a moment to drop; she is still talking, or walking under the same view.
	await create_timer(HouseEpilogue.EYE_SECONDS + 0.3).timeout
	var camera := hub.get_node("Camera") as Camera2D
	var room := hub.get_node("Room")
	var size := camera.get_viewport_rect().size
	var centre := camera.get_screen_center_position()
	var floor_y := float(room.call("ground_y"))
	var feet := (floor_y - centre.y) * camera.zoom.y + size.y * 0.5
	var box_top := (epilogue.get("_box") as DialogueBox).frame_rect().position.y
	var drawn_to := floor_y + float(room.get("floor_depth")) + float(room.get("floor_run_on"))
	var view_bottom := centre.y + size.y * 0.5 / camera.zoom.y
	_check(not epilogue.said.is_empty() and feet < box_top and drawn_to >= view_bottom,
		"while Lola talks in the house both of them stand above the dialogue box, on a floor drawn to the frame",
		"their feet at %.0f px, the box's top edge at %.0f; floor drawn to %.0f, the view reaches %.0f" % [
			feet, box_top, drawn_to, view_bottom])
	var portrait := DialoguePortrait.new()
	hub.add_child(portrait)
	var busts := PackedFloat32Array()
	for speaker in ["Lola", "Lolo", "Apo"]:
		portrait.show_for(speaker)
		busts.append(portrait.bust_rect().size.y)
	_check(busts[0] >= 400.0 and busts[0] == busts[1] and busts[0] == busts[2],
		"Lola, Lolo and the apo share a dialogue portrait scale", str(busts))
	hub.queue_free()
	await _frames(4)


func _on_played() -> void:
	_played = true


func _paintings(hub: Node) -> Array:
	return hub.get("_paintings")


func _open_hub(settle: bool = true) -> Node:
	var hub := (load(HUB) as PackedScene).instantiate()
	root.add_child(hub)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(10 if settle else 3)
	return hub


func _home_and_replay_with_no_memories(profile: Node) -> void:
	var manager := root.get_node("LevelManager")
	profile.call("record_brush_acquired")
	profile.call("record_new_brush")
	for id: String in ["level_1", "level_2", "level_3", "level_4"]:
		profile.call("mark_level_completed", id)
	manager.set("current_level_id", "level_5")
	var level := await _open_level()
	current_scene = level
	preload("res://tests/level5_journey_fixture.gd").summit(level)
	(level.get("lolo") as Lolo).vanish()
	level.set("_lolo_moment", "gone")
	level.set("_summit", "places")
	var player := level.get("player") as Node2D
	player.global_position = Vector2(level.call("_anchor", "lola")) + Vector2(-250, 0)
	player.set_physics_process(false)
	var ink := level.get("ink_manager") as InkManager
	ink.committed = ink.capacity
	var empty: bool = (level.call("bloom_targets") as Array).is_empty()
	level.call("_free_paint_completed", [{"points": PackedVector2Array([Vector2.ZERO, Vector2(90, 25)]),
		"width": 6.0, "color": Color.BLACK}])
	var home := await _until(func() -> bool:
		for overlay in get_nodes_in_group(ModalOverlay.GROUP):
			if overlay is DiaryOverlay and overlay.is_open():
				overlay.close()
		return current_scene != null and current_scene.scene_file_path == HUB \
			and not bool(manager.call("is_transitioning")) and not bool(current_scene.call("is_revealing")), 30.0)
	_check(empty and home and bool(profile.call("is_level_completed", "level_5")),
		"Mayon finishes and returns to the house with no preserved memories", "home %s" % home)
	if not home:
		return
	var hub := current_scene
	var ready_to_replay := 0
	for node in _paintings(hub):
		var painting := node as Painting2D
		if painting.art != null and painting.art.resource_path.ends_with("_lolo.png") \
				and painting.is_playable() and not painting.is_locked():
			ready_to_replay += 1
	_check(ready_to_replay == 5, "every painting has art and remains available after the empty run",
		"%d paintings" % ready_to_replay)
	var mayon := hub.call("painting_for_level", "level_5") as Painting2D
	(hub.get_node(^"Apo") as Node2D).global_position.x = mayon.global_position.x
	await _frames(4)
	var prompt := hub.get("_prompt") as Label
	var offered := prompt.visible and prompt.text.ends_with("REPLAY")
	# Simulate a completed preload without a usable PackedScene to exercise the fallback.
	var prefetched := await _until(func() -> bool: return manager.get("_preparing_path") == "", 8.0)
	manager.set("_prepared_path", MAYON)
	manager.set("_prepared_scene", null)
	var press := InputEventKey.new()
	press.physical_keycode = KEY_E
	press.pressed = true
	root.push_input(press, true)
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	root.push_input(release, true)
	var replayed := await _until(func() -> bool:
		return current_scene != null and current_scene.scene_file_path == MAYON \
			and not bool(manager.call("is_transitioning")), 12.0)
	_check(prefetched and offered and replayed and current_scene.call("journey_phase") == "ascent",
		"the Replay prompt reopens Mayon from the start even if the preload is unavailable",
		"offered %s, re-entered %s" % [offered, replayed])
	if is_instance_valid(current_scene):
		current_scene.queue_free()
	await _frames(4)


func _until(done: Callable, seconds: float) -> bool:
	var left := seconds
	while left > 0.0:
		if done.call():
			return true
		call_group(DialogueBox.GROUP, &"hide_line")
		await create_timer(0.1).timeout
		left -= 0.1
	return bool(done.call())


func _open_level() -> Node:
	var scene := (load("res://level_5.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(40):
		await physics_frame
	call_group(DialogueBox.GROUP, &"hide_line")
	paused = false
	await _frames(4)
	return scene


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
