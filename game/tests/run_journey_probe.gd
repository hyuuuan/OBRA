extends SceneTree
## THE WHOLE RUN, THROUGH THE REAL DOORS.
##   godot --headless --path game --script res://tests/run_journey_probe.gd
##
## Every other suite opens one scene and stays in it. Nothing followed a player from the title
## screen through the scene changes that make up a run -- PLAY into the house, the brush off its
## stand, a painting into Payyo, the gap in Ang Bale's wall into Piyesta, and the painting's
## last piece into the ending -- and those changes are where a paused tree, a stale level id or
## a HUD left over from the last scene would show up: every scene works, and the run between
## them does not.
##
## The levels are not replayed here; the play bots do that. This takes each level's exit the way
## the player does and checks what arrives on the other side.
##
## The profile it writes is the test run's own (user_data.gd), so it starts from nothing and
## leaves nobody's save behind.

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-50s %s" % ["OK  " if ok else "FAIL", what, detail])


func _run() -> void:
	print("\n===== THE WHOLE RUN =====")
	var profile := root.get_node("PlayerProfile")
	profile.set("_data", profile.call("_default_profile"))
	var manager := root.get_node("LevelManager")
	manager.set("transition_step_seconds", 0.0)

	await _title_to_house(manager)
	await _brush_and_payyo(manager)
	await _restart_payyo_from_pause(manager)
	await _payyo_to_piyesta(manager, profile)
	await _piyesta_to_ending(manager)
	await _ending_to_house(manager)

	print("OBRA_JOURNEY_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)


func _settle(manager: Node, frames: int = 30) -> void:
	for _i in range(600):
		if not bool(manager.call("is_transitioning")):
			break
		await process_frame
	for _i in range(frames):
		await process_frame


## Until a DIFFERENT instance of `expected` is current -- a restart reloads the same file, so the
## file name alone says nothing about whether it happened.
func _wait_for_fresh_scene(manager: Node, old: Node, expected: String, seconds: float = 8.0) -> void:
	var waited := 0.0
	while waited < seconds and (current_scene == old or _scene_name() != expected
			or bool(manager.call("is_transitioning"))):
		await create_timer(0.1, true, false, true).timeout
		waited += 0.1
	for _i in range(20):
		await process_frame


## Until the scene is `expected`, in REAL seconds. A level's exit holds a letterbox on a real
## timer before it asks for the next scene, and headless frames run far faster than that -- so
## a frame count "arrives" before the door has even started to open.
func _wait_for_scene(manager: Node, expected: String, seconds: float = 8.0) -> void:
	var waited := 0.0
	while waited < seconds and (_scene_name() != expected or bool(manager.call("is_transitioning"))):
		await create_timer(0.1, true, false, true).timeout
		waited += 0.1
	for _i in range(20):
		await process_frame


func _scene_name() -> String:
	return current_scene.scene_file_path.get_file() if current_scene != null else "(none)"


## A scene has just been walked into: is the world running, and is the scene the one expected?
func _arrived(manager: Node, expected: String, what: String) -> void:
	_check(_scene_name() == expected, "%s -- the scene is %s" % [what, expected], _scene_name())
	_check(not paused, "%s -- and nothing is left paused" % what,
		"running" if not paused else "THE TREE IS PAUSED -- the player arrives frozen")
	_check(not bool(manager.call("is_transitioning")), "%s -- and the wipe has finished" % what,
		"clear")


func _title_to_house(manager: Node) -> void:
	change_scene_to_file("res://ui/main_menu.tscn")
	await _settle(manager)
	var menu := current_scene
	_check(menu != null and menu.get("play_button") != null, "the title screen comes up", _scene_name())
	(menu.get("play_button") as Button).pressed.emit()
	await _wait_for_scene(manager, "hub.tscn")
	await _arrived(manager, "hub.tscn", "PLAY")


func _brush_and_payyo(manager: Node) -> void:
	var hub := current_scene
	var stand := hub.get("_stand") as Node2D
	var apo := hub.get("_player") as Node2D
	_check(stand != null and apo != null, "the house has a stand and an apo", "-")
	if stand == null or apo == null:
		return
	# A painting refuses without the brush, and says so.
	var paintings := get_nodes_in_group(&"paintings")
	var payyo: Node2D = null
	for node in paintings:
		if String(node.get("level_id")) == "level_1":
			payyo = node as Node2D
	hub.call("_on_painting_chosen", "level_1")
	await _settle(manager, 5)
	_check(_scene_name() == "hub.tscn", "Payyo will not open without the brush", _scene_name())

	apo.global_position = Vector2(stand.global_position.x, apo.global_position.y)
	for _i in range(20):
		await process_frame
	_press(&"interact")
	for _i in range(40):
		await process_frame
	_check(bool(root.get_node("PlayerProfile").call("has_brush")), "E at the stand takes the brush",
		"carried")
	# The card that says so takes the next key, whatever it is -- including an E pressed at a
	# painting -- so the walk waits for it the way the player's does: the stand is at the far end
	# of the hall and the card has gone by the time anyone reaches a picture.
	var card := hub.get_node_or_null(^"AcquiredOverlay")
	for _i in range(600):
		if card == null or not bool(card.call("is_busy")):
			break
		await process_frame
	_check(card == null or not bool(card.call("is_busy")), "and the card for it goes by itself",
		"gone")

	if payyo != null:
		apo.global_position = Vector2(payyo.global_position.x, apo.global_position.y)
	for _i in range(20):
		await process_frame
	_press(&"interact")
	await _wait_for_scene(manager, "game_level.tscn")
	await _arrived(manager, "game_level.tscn", "E at Payyo's painting")
	_check(String(manager.get("current_level_id")) == "level_1", "and the run knows it is in Payyo",
		String(manager.get("current_level_id")))
	var level := current_scene
	var badge := level.get("level_badge") as Label
	_check(badge != null and badge.text.contains("PAYYO"), "and the badge says so",
		badge.text if badge != null else "-")


## RESTART LEVEL, from the pause menu, after spending ink. The tree is paused while the menu is
## up, and a restart that forgot to let go of it -- or that kept the ink it had spent -- is the
## player arriving back at the start frozen, or poorer.
func _restart_payyo_from_pause(manager: Node) -> void:
	var level := current_scene
	var ink := level.get("ink_manager") as Node
	ink.call("spend_unit")
	ink.call("spend_unit")
	var menu := level.get_node_or_null(^"PauseMenu")
	menu.call("open_pause")
	for _i in range(10):
		await process_frame
	_check(paused, "Escape pauses Payyo", "paused")
	(menu.get("restart_button") as Button).pressed.emit()
	await _wait_for_fresh_scene(manager, level, "game_level.tscn")
	await _read_the_opening()
	_check(current_scene != level, "RESTART LEVEL loads Payyo again", _scene_name())
	await _arrived(manager, "game_level.tscn", "RESTART LEVEL")
	var fresh_ink := current_scene.get("ink_manager") as Node
	_check(is_equal_approx(float(fresh_ink.call("total_uncommitted_available")), 6.0),
		"and the ink spent before it is back", "%.1f of 6"
			% float(fresh_ink.call("total_uncommitted_available")))
	_check(String(manager.get("current_level_id")) == "level_1", "and it is still Payyo",
		String(manager.get("current_level_id")))


func _payyo_to_piyesta(manager: Node, profile: Node) -> void:
	var level := current_scene
	if level == null or not level.has_method("_on_onward_reached"):
		_check(false, "Payyo has a way through to Piyesta", _scene_name())
		return
	# Ang Bale's gap in the wall is the door. It is reached after the painting is taken, and the
	# painting is what unlocks the next level -- so the painting goes first, as it does in play.
	level.call("_grant_the_canvas")
	for _i in range(10):
		await process_frame
	_check(bool(profile.call("is_level_unlocked", "level_2")), "taking her painting unlocks Piyesta",
		"unlocked")
	level.call("_on_onward_reached")
	await _wait_for_scene(manager, "level_2.tscn")
	# Piyesta opens on Lolo speaking, and a story line stops the world by design. Read through it
	# the way a player does -- a key per line -- and THEN the world has to be running.
	await _read_the_opening()
	await _arrived(manager, "level_2.tscn", "through the gap in Ang Bale's wall")
	_check(String(manager.get("current_level_id")) == "level_2", "and the run knows it is in Piyesta",
		String(manager.get("current_level_id")))
	var piyesta := current_scene
	var banner := piyesta.get("objective_banner") as Control
	_check(banner != null and not String(banner.call("text")).is_empty(),
		"and Piyesta says what to do on arrival",
		String(banner.call("text")) if banner != null else "-")
	var bag := piyesta.get("inventory_manager") as Node
	var carried := 0
	for item: Variant in bag.call("items"):
		if item != null:
			carried += 1
	_check(carried == 0, "and nothing from Payyo's bag is carried in", "%d in the bag" % carried)
	var ink := piyesta.get("ink_manager") as Node
	_check(is_equal_approx(float(ink.call("total_uncommitted_available")), 6.0),
		"and the ink is full again", "%.1f of 6" % float(ink.call("total_uncommitted_available")))


func _piyesta_to_ending(manager: Node) -> void:
	var level := current_scene
	if level == null or level.get("assembly_screen") == null:
		_check(false, "Piyesta has its table", _scene_name())
		return
	level.call("_open_scene_3")
	for _i in range(30):
		await process_frame
	var table := level.get("assembly_screen") as AssemblyOverlay
	for scrap_id in table.piece_ids():
		table.drag_to(scrap_id, table.slot_of(scrap_id))
	for _i in range(30):
		await process_frame
	table.call("_on_continue")
	# Past the closing lines and the letterbox, to the completion card.
	var overlay := level.get("complete_overlay") as ModalOverlay
	var waited := 0.0
	while waited < 10.0 and not overlay.is_open():
		for box in get_nodes_in_group(DialogueBox.GROUP):
			if bool(box.call("is_open")):
				box.call("skip_all")
		await create_timer(0.1, true, false, true).timeout
		waited += 0.1
	_check(overlay.is_open(), "the last piece brings up the completion card", "open")
	overlay.call("_on_continue")
	await _wait_for_scene(manager, "ending_screen.tscn")
	await _arrived(manager, "ending_screen.tscn", "CONTINUE after Piyesta")


## The ending's one button goes back to the house.
func _ending_to_house(manager: Node) -> void:
	var ending := current_scene
	var button := ending.get("_continue_button") as Button if ending != null else null
	_check(button != null, "the ending has a way out", _scene_name())
	if button == null:
		return
	button.pressed.emit()
	await _wait_for_scene(manager, "hub.tscn")
	await _arrived(manager, "hub.tscn", "CONTINUE from the ending")
	_check(String(manager.get("current_level_id")).is_empty(), "and the run is back in no level",
		"'%s'" % String(manager.get("current_level_id")))


## Any story line up, advanced with a real key until none is.
func _read_the_opening() -> void:
	var waited := 0.0
	while waited < 20.0:
		var talking := false
		for box in get_nodes_in_group(DialogueBox.GROUP):
			if bool(box.call("is_open")):
				talking = true
				box.call("complete")
		if not talking:
			break
		# The box advances on ui_accept, which is Space and Enter by KEYCODE -- a key built
		# from the jump action carries only a physical code, and matched nothing.
		_press(&"ui_accept")
		await create_timer(0.15, true, false, true).timeout
		waited += 0.15
	for _i in range(30):
		await process_frame


## A real key press, through the input system, so whatever consumes it first gets it first.
func _press(action: StringName) -> void:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		var down := key.duplicate() as InputEventKey
		down.pressed = true
		Input.parse_input_event(down)
		var up := key.duplicate() as InputEventKey
		up.pressed = false
		Input.parse_input_event(up)
		return
