extends SceneTree
## The actual summit state machine for both endings and all three voices, including no memories.
const CHECKS := 10
var checked := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for perfect in [false, true]:
		for route in ["artist", "pragmatist", "protector"]:
			await _ending(perfect, route)
	print("OBRA_LEVEL5_ENDINGS_%s (%d/%d)" % ["OK" if failures == 0 and checked == CHECKS else "FAILED", checked, CHECKS])
	quit(0 if failures == 0 and checked == CHECKS else 1)


func _ending(perfect: bool, route: String) -> void:
	var profile := root.get_node("PlayerProfile")
	profile.call("reset_progress")
	profile.call("record_route", "level_1", route)
	if perfect:
		for flower in ["flower_1", "L2_HF", "L3_HF", "L4_HF", "L5_HF"]:
			profile.call("record_collectible", flower)
	# Keep the frame transition out of this test, and record what real summit logic says.
	var script := GDScript.new()
	script.source_code = 'extends "res://scripts/level_5.gd"\nvar said: Array = []\n' \
		+ 'func _speak_and_wait(lines: Array) -> void:\n\tfor line in lines:\n\t\tsaid.append(line.get("id", ""))\n\tawait get_tree().process_frame\n' \
		+ 'func _play_own_ending() -> void:\n\tpass\n'
	if script.reload() != OK:
		_check(false, "ending harness compiles")
		return
	var level: Node = (load("res://level_5.tscn") as PackedScene).instantiate()
	level.set_script(script)
	level.get_node("BackendSupervisor").auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, "set_auto_dismiss", true)
	await create_timer(.3).timeout
	(level.get("lolo") as Lolo).vanish()
	level.set("_lolo_moment", "gone")
	if perfect:
		for id in ["church", "kubo"]:
			(level.call("_fragment", id) as MemoryFragment2D).restore_to("saved", [[2.0, 3.0, 11.0, 17.0]])
			(level.get("_save_order") as Array).append(id)
	level.get("player").call("apply_morph_state", {"position": Vector2(12750, -420), "linear_velocity": Vector2.ZERO})
	level.set("_summit", "places")
	if not perfect:
		level.get("ink_manager").committed = level.get("ink_manager").capacity
	var before_ink: float = level.get("ink_manager").remaining()
	var before_classes: int = profile.call("class_diversity")
	level.call("_free_paint_completed", [{"points": PackedVector2Array([Vector2(3, 8), Vector2(19, 51)]), "width": 8.0, "color": Color.BLACK}])
	level.call("_focus_camera_for", "lola")
	var wide: bool = not level.call("_world_camera").is_focused()
	var redraw := InputEventAction.new()
	redraw.action = &"redraw"
	redraw.pressed = true
	var sealed_input: bool = level.call("_handle_level_input", redraw)
	var offered_right := not perfect
	var end := Time.get_ticks_msec() + 9000
	while String(level.call("summit_state")) != "done" and Time.get_ticks_msec() < end:
		var pose = level.get("_performance")
		if is_instance_valid(pose) and pose.visible and pose.flip_h:
			offered_right = offered_right or level.get("player").global_position.distance_to(level.call("_lola").global_position) < 100.0
		await create_timer(.05).timeout
	var said: Array = level.get("said")
	var expected_voice := "L5_voice_" + route
	var end_id := "L5_end_perfect_2" if perfect else "L5_end_standard_1"
	var lola: Lola2D = level.call("_lola")
	var handed_nearby: bool = not perfect or (offered_right and level.get("player").global_position.distance_to(lola.global_position) < 100.0)
	_check(wide and sealed_input and String(level.call("summit_state")) == "done" and expected_voice in said and end_id in said
		and not lola.is_turned() and lola.has_flowers() == perfect
		and is_equal_approx(before_ink, level.get("ink_manager").remaining())
		and int(profile.call("class_diversity")) == before_classes
		and int(level.call("bloomed")) == (2 if perfect else 0) and handed_nearby,
		"%s voice, %s ending: places, temporary recognition, and no model/ink cost" % [route, "perfect" if perfect else "standard"])
	if perfect and route == "protector":
		var widths_hold := true
		var targets: Array = level.call("bloom_targets")
		var scenery: Array = level.get("_bloomed")
		for i in range(scenery.size()):
			widths_hold = widths_hold and is_equal_approx(scenery[i].texture.get_width()*scenery[i].scale.x,
				targets[i].bloom_width)
		_check(widths_hold and scenery.size() == 2, "restored scenery keeps its authored width through the fade")
		# Her saved lines sign each place at a signature's size; they do not span the landscape.
		var signed := scenery.size() == 2
		var sizes: Array[float] = []
		var deepest_place := -INF
		for picture: Sprite2D in scenery:
			deepest_place = maxf(deepest_place, picture.z_index)
		for picture: Sprite2D in scenery:
			var mark: Rect2 = picture.call("signature_rect")
			var on_screen := maxf(mark.size.x, mark.size.y) * picture.scale.x
			sizes.append(snappedf(on_screen, 0.1))
			# Drawn above every place, which overlap, and below the pair standing in front of them.
			var layer := picture.get_node_or_null(^"Signature") as Node2D
			signed = signed and absf(on_screen - 140.0) < 1.0 \
				and Rect2(-picture.texture.get_size() * 0.5, picture.texture.get_size()).encloses(mark) \
				and layer != null and not layer.z_as_relative and layer.z_index > deepest_place \
				and layer.z_index < (level.get("player") as Node2D).z_index
		_check(signed, "saved lines sign each restored place at 140px, inside it, above the places: %s" % [sizes])
		var state: Dictionary = level.call("_level_run_state")
		state.erase("layout_version")
		level.get("checkpoints").call("write", "CP2", {"position": Vector2(15000, -100), "level": state})
		var landing: Vector2 = level.call("_checkpoint_landing", {"position": Vector2(15000, -100), "level": state})
		_check(landing == Vector2(11900, -500) and String(level.get("_lolo_moment")) == "gone",
			"a legacy summit save lands safely and keeps Lolo gone")
		var ink: InkManager = level.get("ink_manager")
		ink.committed = 6.0
		ink.hidden_reserve = 0.0
		level.call("_give_back_what_cannot_come_back", {"bag_paid": 1.0, "placed": [{"paid": 1.0}]})
		_check(is_zero_approx(ink.remaining()) and is_zero_approx(ink.hidden_reserve),
			"resuming cannot convert spent gate reserve into memory ink")
	level.queue_free()
	for i in range(5):
		await process_frame


func _check(ok: bool, what: String) -> void:
	checked += 1
	failures += int(not ok)
	print("  %s\t%s" % ["OK" if ok else "FAIL", what])
