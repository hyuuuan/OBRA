extends SceneTree
## A key that has been used is gone from what the player carries.
##
##   godot --headless --path game --script res://tests/run_key_probe.gd
##
## Kent: "in cases like a key is used, it should be gone in the inventory". Three keys open
## doors in this game: the brass key found on the nail in Level 1, and a drawn key at Ang Bale
## (Level 1) or Ang Kandila (Level 2). Each is used the way a player uses it, and then the bag
## and the inventory screen are read.

var level: Node
var results: Array[String] = []
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	results.append("  %s  %-52s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	print("\n===== USED KEYS =====")
	await _the_found_key()
	await _a_drawn_key("res://game_level.tscn", "L1_N3")
	await _a_drawn_key("res://level_2.tscn", "L2_N1")
	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_KEYS_OK")
		quit(0)
	else:
		print("OBRA_KEYS_FAILED=%d" % failures)
		quit(1)


## The brass key off the nail opens Ang Bale, and stays in the lock.
func _the_found_key() -> void:
	await _open("res://game_level.tscn")
	var profile := root.get_node("PlayerProfile")
	profile.call("record_collectible", "L1_bale_key")
	var director = level.get("director")
	director.call("enter_obstacle", "L1_N3")
	var opened: bool = level.call("_use_the_found_key")
	_check(opened and bool(director.call("is_solved", "L1_N3")), "the brass key opens Ang Bale",
		"solved" if opened else "refused")
	var shown := await _found_on_the_screen("L1_bale_key")
	_check(not shown, "and the inventory no longer shows it", "hidden" if not shown else "still shown")
	_check(bool(profile.call("is_collectible_found", "L1_bale_key")),
		"but it still counts as found", "the run found it")
	await _close()


## A drawn key, in hand as soon as it is drawn, used on the door with F.
func _a_drawn_key(scene: String, beat: String) -> void:
	await _open(scene)
	var director = level.get("director")
	director.call("enter_obstacle", beat)
	director.call("commit_route", beat, "pragmatist")
	await _unpause()
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	# No strokes: the ward lock stands aside for a key with nothing to measure, and the
	# ordinary Unlock answer applies -- this is about where the key goes, not its teeth.
	level.call("_on_drawing_ready", "key", "Key", sheet, {"confidence": 0.9}, [], 1.0)
	await _unpause()
	var slot := int(level.call("_slot_holding", "key"))
	_check(slot >= 0, "%s: the drawn key is in the bag" % beat, "slot %d" % slot)
	# A drawn tool goes straight into the hand; F uses it.
	level.call("_use_equipped_utility")
	await _unpause()
	_check(bool(director.call("is_solved", beat)), "%s: the key opens the door" % beat, "solved")
	_check(int(level.call("_slot_holding", "key")) < 0, "%s: and it is gone from the bag" % beat,
		"slot %d" % int(level.call("_slot_holding", "key")))
	var held = level.get("_equipped_utility")
	_check(held == null or not is_instance_valid(held), "%s: and from the hand" % beat,
		"empty-handed" if held == null or not is_instance_valid(held) else "still holding it")
	await _close()


func _found_on_the_screen(id: String) -> bool:
	var screen: InventoryScreen = null
	for node in get_nodes_in_group(&"modal_overlays"):
		if node is InventoryScreen:
			screen = node
	if screen == null:
		return true
	screen.call("open")
	await process_frame
	var buttons: Array = screen.get("_found_buttons")
	var shown := false
	for index in range(buttons.size()):
		if String(InventoryScreen.FOUND[index]["id"]) == id:
			shown = (buttons[index] as Button).visible
	screen.call("close")
	await process_frame
	return shown


func _open(scene: String) -> void:
	var profile := root.get_node("PlayerProfile")
	profile.call("reset_profile") if profile.has_method("reset_profile") else null
	level = (load(scene) as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _f in range(40):
		await physics_frame
	await _unpause()


func _close() -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
	for _f in range(4):
		await physics_frame


func _unpause() -> void:
	for _attempt in range(20):
		for node in get_nodes_in_group(&"modal_overlays"):
			if node is InventoryScreen:
				continue
			if node.has_method("is_open") and node.has_method("close") and bool(node.call("is_open")):
				node.call("close")
		call_group(DialogueBox.GROUP, &"hide_line")
		paused = false
		await physics_frame
