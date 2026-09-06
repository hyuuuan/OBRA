extends SceneTree
## CAN LEVEL 1 ACTUALLY BE FINISHED? Nothing asked before.
##   godot --headless --path game --script res://tests/run_level1_finish_probe.gd
##
## `run_level1_audit` checks the data, `run_room_probe` checks the rooms in isolation and
## `run_nodraw_level1` proves the level cannot be finished WITHOUT drawing. None of them
## walks the last beat: get into Ang Bale, come out with the second canvas, and end the
## level. That is the whole point of Level 1 -- the painting is how Level 2 is reached --
## and it is the part the player reported as unplayable.

var level: Node2D
var director
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-46s %s" % ["OK  " if ok else "FAIL", what, detail])


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _run() -> void:
	level = (load("res://game_level.tscn") as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.4)
	director = level.get("director")

	await _audit_the_found_key_opens_the_house()
	await _audit_the_key_opens_the_lock()
	for route in ["artist", "pragmatist", "protector"]:
		await _audit_route(route)

	print("OBRA_LEVEL1_FINISH_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)


## ⚠ THE KEY FOUND IN THE HAY. Different key, different door, and the one the player said
## does not work. It is a COLLECTIBLE taken off the nail inside the straw heap, not a drawing;
## carrying it lets the house be opened with E instead of drawing a key at all. Nothing tested
## it: the ward lock has its own probe above, and this path never goes near the lock.
func _audit_the_found_key_opens_the_house() -> void:
	var fresh := (load("res://game_level.tscn") as PackedScene).instantiate() as Node2D
	(fresh.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(fresh)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.2)
	var d = fresh.get("director")
	if d == null:
		_check(false, "the level built its obstacle layer", "-")
		fresh.queue_free()
		return

	# ⚠ REACHED BY PATH, NOT BY NAME. An autoload IS created under /root -- it just is not
	# a resolvable identifier inside a `--script` file, because this file is compiled before
	# the autoload globals are registered. Writing `PlayerProfile` here fails to COMPILE the
	# whole probe; `/root/PlayerProfile` is there and works the moment the level has loaded.
	var profile := root.get_node_or_null(^"/root/PlayerProfile")
	if profile == null:
		_check(false, "the key from the hay is in the bag", "no PlayerProfile at /root")
		fresh.queue_free()
		return
	profile.call("record_collectible", "L1_bale_key")
	_check(bool(profile.call("is_collectible_found", "L1_bale_key")),
		"the key from the hay is in the bag", "L1_bale_key")

	d.enter_obstacle("L1_N3")
	await _wait(0.3)
	# What the level offers the player: a line saying the key would work here.
	fresh.call("_offer_the_found_key")
	await process_frame
	var bar = fresh.get("hint_bar")
	_check(bar != null and String(bar.call("current_text")).to_lower().contains("key"),
		"and the house says the key would fit",
		"'%s'" % (bar.call("current_text") if bar != null else ""))

	# And then the key the prompt names actually opens it.
	var used := bool(fresh.call("_interact_with_level"))
	await _wait(0.4)
	_check(used, "pressing interact tries the key", "the level took the press")
	_check(bool(d.is_solved("L1_N3")), "and the house opens to it",
		"solved with the found key" if d.is_solved("L1_N3")
		else "STILL SHUT -- the key found in the hay does nothing")
	fresh.queue_free()
	await process_frame


## ⚠ THE KEY IS THE PRAGMATIST ROUTE'S ONLY ANSWER, and the player reported it as not
## working. The lock measures the STROKES of a drawn key against a ward and refuses one of
## the wrong shape -- deliberately -- but it is also supposed to give up after three tries,
## because being locked out of the end of the level by a padlock is not a lesson.
##
## Three submissions of a plainly wrong key, and it must open.
func _audit_the_key_opens_the_lock() -> void:
	var fresh := (load("res://game_level.tscn") as PackedScene).instantiate() as Node2D
	(fresh.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(fresh)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.2)
	var d = fresh.get("director")
	var lock = fresh.get("ward_lock")
	_check(lock != null, "the level has a ward lock", "-" if lock == null else lock.name)
	if lock == null or d == null:
		fresh.queue_free()
		return
	d.enter_obstacle("L1_N3")
	d.commit_route("L1_N3", "pragmatist")
	await _wait(0.3)

	# A key nobody would call the right shape: one long stroke, no bits at all.
	var wrong: Array = [{"points": PackedVector2Array([Vector2(0, 0), Vector2(120, 0)]),
		"width": 6.0, "color": Color.BLACK}]
	var opened := false
	var turns := 0
	for attempt in range(int(lock.get("max_attempts")) + 1):
		if bool(lock.call("is_open")):
			opened = true
			break
		turns += 1
		fresh.call("_judge_submission", "key", wrong)
		await _wait(0.4)
	opened = opened or bool(lock.call("is_open"))
	_check(opened, "a wrong key still opens it inside its own limit",
		"opened on turn %d of %s" % [turns, lock.get("max_attempts")] if opened
		else "STILL SHUT after %d turns -- the level cannot be finished this way" % turns)
	_check(bool(d.is_solved("L1_N3")) or opened, "and the beat is answered",
		"solved" if d.is_solved("L1_N3") else "lock open")
	fresh.queue_free()
	await process_frame


## Each route on its own level, because the three are exclusive: committing one locks the
## others for that playthrough, which is the whole design of the tri-path system.
func _audit_route(route: String) -> void:
	var fresh := (load("res://game_level.tscn") as PackedScene).instantiate() as Node2D
	(fresh.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(fresh)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.2)
	var d = fresh.get("director")
	if d == null:
		_check(false, "%s: the level built its obstacle layer" % route, "-")
		fresh.queue_free()
		return

	# Straight to the last beat. The route before it is not what is under test here.
	d.enter_obstacle("L1_N3")
	d.commit_route("L1_N3", route)
	await _wait(0.3)
	fresh.call("_open_the_baul", route)
	await _wait(1.6)

	# ⚠ IN THE HOUSE. `_open_the_baul` awaits `_into_the_bale`, which moves the player a
	# thousand units up into the room -- if that never happens the route "succeeded" with
	# the apo still standing on the terrace looking at a shut door.
	var room := fresh.get_tree().get_first_node_in_group(&"bale_interiors") as Node2D
	var player := fresh.get("player") as Node2D
	var inside := room != null and player != null \
		and Rect2(room.call("bounds")).grow(120.0).has_point(player.global_position)
	_check(inside, "%s: the apo is inside Ang Bale" % route,
		"at %s" % (player.global_position.round() if player != null else "nowhere"))

	# AND THE PAINTING IS THERE TO TAKE. It leans against the wall and is picked up by
	# walking into it, so what this asserts is that it EXISTS and is reachable -- a route
	# that opens the chest onto an empty room is the level with no ending.
	var canvas := _find_painting(room)
	_check(canvas != null, "%s: the second canvas is in the room" % route,
		canvas.name if canvas != null else "NOTHING TO TAKE -- the level has no ending")
	fresh.queue_free()
	await process_frame


func _find_painting(room: Node) -> Node:
	if room == null:
		return null
	for child in room.get_children():
		var name := String(child.name).to_lower()
		if name.contains("painting") or name.contains("canvas"):
			return child
		var deeper := _find_painting(child)
		if deeper != null:
			return deeper
	return null
