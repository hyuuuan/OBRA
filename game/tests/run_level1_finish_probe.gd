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
## ⚠ A MEMBER, NOT A LOCAL. GDScript lambdas capture locals BY VALUE, so `var stepped := false`
## with a `func(): stepped = true` connected to the signal writes to the lambda's own copy and
## the outer one stays false forever. The door was firing and all three assertions below read
## a variable nothing could ever change -- which would have passed the "it does not fire under
## them" check with no door in the game at all.
var stepped_through := false


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
	await _audit_a_drawn_ladder_does_not_eat_the_key()
	await _audit_the_key_opens_the_lock()
	for route in ["artist", "pragmatist", "protector"]:
		await _audit_route(route)
	# ⚠ LAST, AND IT REALLY TRANSITIONS. The door's whole claim is that it opens Piyesta,
	# and the only honest way to check that is to let it -- which changes the scene out from
	# under everything above. Nothing may follow it.
	await _audit_the_wall_opens()

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


## ⚠ THE ONE ABOVE PASSED WHILE THE GAME WAS BROKEN, and this is why.
##
## It calls `_interact_with_level` directly, so it proves the key WOULD work if the press
## reached it. In play the press did not: `_unhandled_input` tries a drawing within arm's
## reach first, and the drawing within arm's reach at Ang Bale is the ladder the player just
## drew to get up to the door. E pocketed the ladder, in silence, while the bar went on
## saying "press E to try it". "The key is not working ... when I make a ladder it
## complicates everything" is that, exactly.
##
## So this one goes through the real door: a placed ladder at the player's feet, and a
## synthesised press of the actual action.
func _audit_a_drawn_ladder_does_not_eat_the_key() -> void:
	var fresh := (load("res://game_level.tscn") as PackedScene).instantiate() as Node2D
	(fresh.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(fresh)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.2)
	var d = fresh.get("director")
	var profile := root.get_node_or_null(^"/root/PlayerProfile")
	var apo := fresh.get("player") as Node2D
	if d == null or profile == null or apo == null:
		_check(false, "a drawn ladder does not eat the key", "the level did not come up")
		fresh.queue_free()
		return
	profile.call("record_collectible", "L1_bale_key")
	d.enter_obstacle("L1_N3")
	await _wait(0.3)

	# The ladder, lying exactly where the player would have left it: within reach.
	var registry := fresh.get_node("EntityRegistry") as EntityRegistry
	var ladder := registry.instantiate_entity("ladder") as UtilityObject
	fresh.get_node("EnvironmentBaseplate/GameplayPlane/WorldItemRoot").add_child(ladder)
	ladder.apply_item_data(DrawnItemData.from_prediction(
		"ladder", "Ladder", Image.create(512, 512, false, Image.FORMAT_RGBA8), [],
		0.4, registry.get_entity("ladder")))
	ladder.confirm_placement()
	await _wait(0.3)
	# Stood where a settled ladder stands: beside the player, frozen, which is what a placed
	# one does once it has stopped moving. Set AFTER the settle, or it falls out of reach
	# while the level is still coming up.
	ladder.global_position = apo.global_position + Vector2(30.0, 0.0)
	ladder.freeze = true
	await _wait(0.2)

	fresh.call("_offer_the_found_key")
	await process_frame
	# ⚠ THIS LEVEL'S E, NOT THE TREE'S. A synthesised `InputEventAction` reaches every level
	# alive in the tree; the first one to handle it calls `set_input_as_handled` and the one
	# under test never sees the press. The first version of this test did exactly that and
	# passed with the fix reverted.
	_check(bool(fresh.call("_nearest_interactable_utility") != null),
		"the drawn ladder is within arm's reach", "E has something to pick up")
	fresh.call("press_interact")
	await _wait(0.4)

	_check(bool(d.is_solved("L1_N3")),
		"E at the house opens it with the key, not the ladder",
		"the house opened" if d.is_solved("L1_N3")
		else "STILL SHUT -- the press went to the ladder")
	if is_instance_valid(ladder):
		ladder.queue_free()
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


## THE WAY ON, AND THE THREE THINGS THAT MAKE IT A DOOR RATHER THAN A TRAPDOOR.
##
## Lifting Lola's canvas off the boards opens the wall behind it, and walking into the gap
## ends Payyo and starts Piyesta. The player is standing ON that spot at the moment it
## opens -- the painting is taken by walking into it -- so an unguarded door would take them
## to the next level on the frame they picked the canvas up, before they had seen the room
## the whole level is for. Held here:
##
##   shut until the painting is taken
##   does not fire on the step that opened it
##   fires once they have been clear of it and come back, and lands in Piyesta
func _audit_the_wall_opens() -> void:
	# ⚠ EVERY OTHER PAYYO OUT OF THE TREE FIRST. This audit lets the transition happen for
	# real, and a level built by _build_obstacle_layer finds its volumes through a GROUP --
	# so Piyesta loading beside three leftover Payyos reads Payyo's obstacle volumes and
	# pushes an error for every one of them. Only ever true in a probe; only ever noise.
	if level != null and is_instance_valid(level):
		level.queue_free()
		level = null
		await process_frame
	var fresh := (load("res://game_level.tscn") as PackedScene).instantiate() as Node2D
	(fresh.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(fresh)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.2)
	var room := fresh.get_tree().get_first_node_in_group(&"bale_interiors") as Node2D
	var apo := fresh.get("player") as Node2D
	if room == null or apo == null:
		_check(false, "the way on: the room and the apo exist", "-")
		fresh.queue_free()
		return
	var script := room.get_script() as Script
	var constants: Dictionary = script.get_script_constant_map()
	var door: Vector2 = room.global_position + Vector2(constants["ONWARD_AT"])

	stepped_through = false
	room.connect(&"onward_reached", _on_stepped_through)
	# ⚠ ARRIVE THE WAY A PLAYER DOES. open_level asks three questions -- is it building, is
	# it unlocked, is she carrying Lola's brush -- and a probe that instantiates the scene
	# directly has answered none of them. Without the brush the door refuses for a reason
	# that has nothing to do with the door.
	var profile := root.get_node_or_null("PlayerProfile")
	if profile != null:
		profile.call("record_brush_acquired")

	# --- shut, while the painting is still on the boards ----------------------
	fresh.call("_into_the_bale")
	await _wait(0.6)
	# Beside the opening but NOT on the canvas, which would take it and open the wall --
	# the trigger reaches down to the walk line and is 74 wide.
	_place(apo, door + Vector2(0.0, 130.0))
	await _wait(0.8)
	_check(not stepped_through, "the wall is shut while the painting hangs on it",
		"nothing fired" if not stepped_through else "it opened with the canvas still there")

	# --- taken, and it does not fire on that step -----------------------------
	_place(apo, door)
	await _wait(1.0)
	_check(bool(room.call("painting_is_taken")), "walking into the canvas takes it",
		"taken" if bool(room.call("painting_is_taken")) else "the canvas was not picked up")
	_check(not stepped_through, "and the wall it uncovers does not fire under them",
		"still standing in the opening, and Payyo has not ended")

	# --- clear of it, and back --------------------------------------------------
	_place(apo, room.global_position + Vector2(constants["DOOR_AT"]) + Vector2(54.0, 0.0))
	await _wait(0.6)
	_place(apo, door)
	await _wait(0.8)
	_check(stepped_through, "stepping away and back walks through it",
		"onward_reached fired" if stepped_through else "the door never fired -- Payyo cannot be left")

	# --- and it lands in Piyesta -------------------------------------------------
	var manager := root.get_node_or_null("LevelManager")
	_check(manager != null and String(manager.call("next_level_id", "level_1")) == "level_2",
		"and the level after Payyo is Piyesta",
		String(manager.call("next_level_id", "level_1")) if manager != null else "no manager")
	# The handler stages the cinematic bars before it opens anything, so this has to wait
	# them out -- and then stop the moment the manager has been told.
	#
	# ⚠ POLLED, AND RETURNED FROM THE INSTANT IT FLIPS. `open_level` writes current_level_id
	# and DEFERS the scene change, which then spends about a third of a second closing the
	# pixel transition before it swaps anything. Catching the write inside that window is
	# what proves the door opened Piyesta without loading Piyesta on top of a tree that
	# still has this probe's Payyo in it -- which reads Payyo's obstacle volumes out of the
	# group and pushes an error for every one of them.
	var landed := false
	for step in range(60):
		await _wait(0.05)
		if manager != null and String(manager.get("current_level_id")) == "level_2":
			landed = true
			break
	_check(landed, "and the door opens it",
		"LevelManager is on '%s'" % (String(manager.get("current_level_id"))
			if manager != null else "?"))


## Put the apo somewhere, whatever body they are currently in.
##
## ⚠ AND CLEAR THE SCREEN FIRST. Taking the canvas speaks a beat AND throws an acquisition
## card, and both stop the tree -- so the room's own `_process`, which is what watches both
## doorways, does not run while either is up. In play that is exactly right: the player reads
## the line, presses on, and then walks. In a probe the timers keep running and the room does
## not, so every step after the pickup measured a room that had not had a frame since.
##
## ⚠ AND WRITING `paused` IS NOT ENOUGH. UIRouter DERIVES the pause from whichever modals are
## open and re-asserts it, so a probe that unpauses by hand is overruled on the next refresh.
## The overlays have to be closed, which is what a player pressing on does.
func _place(apo: Node2D, at: Vector2) -> void:
	var tree := apo.get_tree()
	for node in tree.get_nodes_in_group(ModalOverlay.GROUP):
		if node.has_method(&"is_open") and bool(node.call(&"is_open")) \
				and node.has_method(&"close"):
			node.call("close")
	UIRouter.refresh_pause(tree)
	tree.paused = false
	if apo.has_method("apply_morph_state"):
		apo.call("apply_morph_state", {"position": at, "linear_velocity": Vector2.ZERO})
	else:
		apo.global_position = at


func _on_stepped_through() -> void:
	stepped_through = true
