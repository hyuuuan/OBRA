extends SceneTree
## NEW GAME STARTS IN PAYYO, AND THE HOUSE COMES AFTER IT.
##   godot --headless --path game --script res://tests/run_new_game_probe.gd
##
## Kent: "when the game is played new game it should automatically start to the tutorial level
## rather than the lobby like Start>Level 1>lobby>Get paint>go to level 2". So from the title
## screen, on a fresh save:
##
##   NEW GAME -> Payyo, carrying Lola's brush (the door refuses without it) -> her canvas home
##   to the house, where Piyesta's frame opens in front of her and the stand is already empty
##   -> Piyesta's painting -> Piyesta.
##
## And the other two doors on the title screen still go where they did: CONTINUE on a save
## opens the house rather than replaying Payyo, and NEW GAME on a save throws it away and
## starts in Payyo again. Pressed through the menu's own buttons, so a probe that called
## LevelManager directly cannot pass while the button still opens the house.

## Every check this probe makes. A crash part-way through cannot print OK.
const CHECKS := 19
const TutorialDoor = preload("res://tests/tutorial_door.gd")

var failures := 0
var checked := 0


func _initialize() -> void:
	# A level reached through LevelManager builds its own supervisor; catch it before its
	# _ready, so no recogniser is launched for a probe that never draws.
	node_added.connect(_quiet_the_backend)
	call_deferred("_run")


func _quiet_the_backend(node: Node) -> void:
	if node is BackendSupervisor:
		(node as BackendSupervisor).auto_start_backend = false


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if not ok:
		failures += 1
	print("  %s  %-58s %s" % ["OK  " if ok else "FAIL", what, detail])


func _run() -> void:
	print("\n===== NEW GAME -> PAYYO -> THE HOUSE -> PIYESTA =====")
	var profile := root.get_node("PlayerProfile")
	var manager := root.get_node("LevelManager")
	manager.set("transition_step_seconds", 0.0)
	profile.call("reset_progress")

	await _new_game_lands_in_payyo(manager, profile)
	await _payyo_comes_home(manager, profile)
	await _continue_opens_the_house(manager)
	await _new_game_over_a_save(manager, profile)

	var complete := checked == CHECKS
	if not complete:
		print("  FAIL  ran %d of %d checks -- something stopped the probe part-way" % [checked, CHECKS])
	print("OBRA_NEW_GAME_%s" % ("OK" if failures == 0 and complete else "FAILED=%d" % maxi(failures, 1)))
	quit(1 if failures > 0 or not complete else 0)


func _new_game_lands_in_payyo(manager: Node, profile: Node) -> void:
	var menu := await _title(manager)
	var play := menu.get("play_button") as Button
	_check(play != null and play.text == "NEW GAME", "a fresh save offers NEW GAME",
		play.text if play != null else "-")
	_check(not bool(profile.call("has_brush")), "and has not taken the brush yet", "no brush")
	play.pressed.emit()
	await _wait_for_scene(manager, "game_level.tscn")
	_check(_scene_name() == "game_level.tscn", "NEW GAME opens Payyo, not the house", _scene_name())
	_check(String(manager.get("current_level_id")) == "level_1", "and the run knows it is in Payyo",
		String(manager.get("current_level_id")))
	_check(bool(profile.call("has_brush")), "carrying Lola's brush, which the door asks for",
		"has_brush")
	await _read_the_cards()
	_check(not paused, "and once its cards are read, nothing is left paused", "running" if not paused else "PAUSED")
	var tutorial := current_scene.get("tutorial") as Node
	_check(tutorial != null and bool(tutorial.get("_enabled")),
		"with the tutorial teaching, on a first visit",
		"enabled" if tutorial != null and bool(tutorial.get("_enabled")) else "OFF")


func _payyo_comes_home(manager: Node, profile: Node) -> void:
	var level := current_scene
	if level == null or not level.has_method("_on_painting_taken"):
		_check(false, "Payyo has her canvas to take", _scene_name())
		return
	level.call("_on_painting_taken")
	await _read_the_lines()
	await _wait_for_scene(manager, "hub.tscn", 30.0)
	_check(_scene_name() == "hub.tscn", "her canvas takes her home to the house", _scene_name())
	var hub := current_scene
	var piyesta: Node = null
	for node in get_nodes_in_group(&"paintings"):
		if String(node.get("level_id")) == "level_2":
			piyesta = node
	var waited := 0.0
	while waited < 10.0 and (piyesta == null or bool(piyesta.call("is_locked"))
			or bool(hub.call("is_revealing"))):
		await create_timer(0.1).timeout
		waited += 0.1
	_check(piyesta != null and not bool(piyesta.call("is_locked")),
		"where Piyesta's frame opens in front of her", "in %.1f s" % waited)
	var stand := hub.get("_stand") as Node
	_check(stand != null and not bool(stand.call("holds_brush")),
		"and the stand is empty -- she took the brush already", "empty" if stand != null
			and not bool(stand.call("holds_brush")) else "STILL HOLDS IT")
	var status := hub.get("_status") as Label
	_check(status != null and not status.text.contains("Take it first"),
		"and the house does not send her for it", status.text if status != null else "-")
	piyesta.call("choose")
	await _wait_for_scene(manager, "level_2.tscn")
	await _read_the_lines()
	_check(_scene_name() == "level_2.tscn", "Piyesta's painting opens Piyesta", _scene_name())
	_check(bool(profile.call("is_level_completed", "level_1")), "with Payyo marked finished",
		"completed")


func _continue_opens_the_house(manager: Node) -> void:
	var menu := await _title(manager)
	var play := menu.get("play_button") as Button
	_check(play != null and play.text == "CONTINUE", "with a save, the title offers CONTINUE",
		play.text if play != null else "-")
	play.pressed.emit()
	await _wait_for_scene(manager, "hub.tscn")
	_check(_scene_name() == "hub.tscn", "and CONTINUE opens the house, not Payyo again",
		_scene_name())


func _new_game_over_a_save(manager: Node, profile: Node) -> void:
	var menu := await _title(manager)
	var new_game := menu.get("new_game_button") as Button
	_check(new_game != null and new_game.visible, "NEW GAME is offered beside CONTINUE",
		"shown" if new_game != null and new_game.visible else "hidden")
	new_game.pressed.emit()
	await process_frame
	var confirm := menu.get_node_or_null(^"ConfirmOverlay")
	(confirm.get_node("Root/Center/Panel/VBox/Buttons/ConfirmButton") as Button).pressed.emit()
	await _wait_for_scene(manager, "game_level.tscn")
	_check(_scene_name() == "game_level.tscn", "and, confirmed, starts in Payyo again", _scene_name())
	_check(not bool(profile.call("is_level_completed", "level_1"))
		and not bool(profile.call("is_level_unlocked", "level_2")),
		"with the old save forgotten", "Payyo unfinished, Piyesta locked")
	_check(bool(profile.call("has_brush")), "and the brush in her hand again", "has_brush")


## The title screen, fresh.
func _title(manager: Node) -> Node:
	if bool(manager.call("is_transitioning")):
		await manager.transition_finished
	manager.call("open_main_menu")
	await _wait_for_scene(manager, "main_menu.tscn")
	return current_scene


## Until the scene is `expected`, in real seconds: a level's exit holds a letterbox on a real
## timer before it asks for the next scene, and headless frames outrun it.
func _wait_for_scene(manager: Node, expected: String, seconds: float = 8.0) -> void:
	var waited := 0.0
	while waited < seconds and (_scene_name() != expected or bool(manager.call("is_transitioning"))):
		await create_timer(0.1, true, false, true).timeout
		waited += 0.1
	for _i in range(20):
		await process_frame


func _scene_name() -> String:
	return current_scene.scene_file_path.get_file() if current_scene != null else "(none)"


## Story lines stop the world until read; read them the way a player does.
func _read_the_lines() -> void:
	var waited := 0.0
	while waited < 20.0:
		var talking := false
		for box in get_nodes_in_group(DialogueBox.GROUP):
			if bool(box.call("is_open")):
				talking = true
				box.call("skip_all")
		for card in get_nodes_in_group(&"modal_overlays"):
			if card is AcquiredOverlay and bool(card.call("is_busy")):
				talking = true
		if not talking:
			break
		await create_timer(0.15, true, false, true).timeout
		waited += 0.15
	for _i in range(30):
		await process_frame


## PAYYO OPENS ON ITS CARDS, holding the world until each is done -- on purpose. Do them as a
## player does, so "nothing is left paused" asks about what is left after them.
func _read_the_cards() -> void:
	var tutorial = current_scene.get("tutorial") if current_scene != null else null
	var spot = current_scene.get("tutorial_spotlight") if current_scene != null else null
	if tutorial == null or spot == null:
		return
	var since := Time.get_ticks_msec()
	while bool(tutorial.call("is_teaching_the_door")) and Time.get_ticks_msec() - since < 60000:
		await process_frame
		# Each with what it shows -- a card at the door goes on nothing else -- and the bag Tab
		# opened put away once its card is done.
		TutorialDoor.close_the_bag(current_scene, spot as TutorialSpotlight)
		var up := TutorialDoor.do_the_card(spot as TutorialSpotlight, root)
		while not up.is_empty() and bool(spot.call("is_showing")) and String(spot.call("lesson_id")) == up \
				and Time.get_ticks_msec() - since < 60000:
			await process_frame
	for _i in range(5):
		await process_frame
