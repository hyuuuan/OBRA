extends SceneTree
## PIYESTA, PLAYED BY FOLLOWING THE OBJECTIVE AND NOTHING ELSE.
##   godot --headless --path game --script res://tests/run_play_level2.gd
##
## Every other Level 2 probe teleports to the thing it is testing and calls the handler that
## thing would call. That is how a key drawn at the lit house went into the bag and opened
## nothing, while every suite in the project reported the route solved: the probes took the
## step the game did not. This one takes no such step. It walks with the movement keys, reads
## the objective line and walks to wherever the marker points, presses E where a player would
## press E, picks a route on the choice screen, hands the level a recognised drawing through
## the drawing panel's own door, sets placeables down through the placement controller,
## plays the dance on the beat and drags the painting together -- and fails the moment the
## objective stops changing for longer than a player would stand still.
##
## Three runs, so every route at every beat is walked by one of them.

const PLANS := [
	{"name": "house, bread, ladder",
		"L2_N1": "pragmatist", "L2_N2": "bread", "L2_N3": "ladder"},
	{"name": "scare, boomerang, axe",
		"L2_N1": "protector", "L2_N2": "boomerang", "L2_N3": "axe"},
	{"name": "dance, snake, ladder",
		"L2_N1": "artist", "L2_N2": "snake", "L2_N3": "ladder"},
]
## How long one objective may stand unchanged before the run counts as stuck, in physics
## frames. Twenty-five seconds: the priest's walk and the dance are the longest waits.
const STUCK_FRAMES := 1500
const RUN_FRAMES := 12000

const HudOverlap = preload("res://tests/hud_overlap.gd")

var failures := 0
var _asked: Dictionary = {}
## Every HUD overlap seen while playing, first sighting only, with the beat it happened in.
var _overlaps: Dictionary = {}
var level: Node
var player: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-44s %s" % ["OK  " if ok else "FAIL", what, detail])


func _run() -> void:
	print("\n===== PIYESTA, PLAYED =====")
	for plan: Dictionary in PLANS:
		await _play(plan)
	print("OBRA_PLAY_LEVEL2_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)


func _play(plan: Dictionary) -> void:
	print("  -- %s" % plan["name"])
	level = (load("res://level_2.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(40):
		await physics_frame
	var done: Dictionary = {}
	var last_key := ""
	var since := 0
	var trail: Array[String] = []
	var finished := false
	for frame in range(RUN_FRAMES):
		if bool(level.get("_level_completed")):
			finished = true
			break
		player = level.get("player") as Node2D
		if player == null or not is_instance_valid(player):
			await physics_frame
			continue
		if await _handle_screens(plan):
			since = 0
			continue
		var goal: Dictionary = level.call("_current_objective")
		var key := String(goal.get("key", ""))
		# THE HUD, WHILE IT IS BEING PLAYED. A still frame with everything raised found three
		# overlaps; the ones a player actually sees happen mid-beat, when a hint, a lesson and
		# an objective change arrive within a second of each other.
		if frame % 12 == 0:
			for clash in HudOverlap.clashes(HudOverlap.painted(level)):
				if not _overlaps.has(clash):
					_overlaps[clash] = "%s, during '%s'" % [plan["name"], key]
		if key != last_key:
			trail.append(key)
			last_key = key
			since = 0
		since += 1
		if since > STUCK_FRAMES:
			_release()
			_check(false, "%s: the objective moves on" % plan["name"],
				"STUCK on '%s' (\"%s\") in %s at %s, target %s" % [key,
					level.call("objective_text", goal), _room_name(),
					player.global_position.round(), goal.get("target", "none")])
			break
		await _act(plan, goal, key, done)
	_release()
	var seen: Array[String] = []
	for clash: String in _overlaps.keys():
		if String(_overlaps[clash]).begins_with(String(plan["name"])):
			seen.append("%s (%s)" % [clash, _overlaps[clash]])
	_check(seen.is_empty(), "%s: nothing on the HUD overlapped in play" % plan["name"],
		"clear the whole way" if seen.is_empty() else "; ".join(seen))
	_check(finished, "%s: the level is finished" % plan["name"],
		" > ".join(trail) if finished else "ended on '%s' after %s" % [last_key, " > ".join(trail)])
	if finished:
		var ledger = level.get("ledger")
		_check(int(ledger.call("held")) == 7, "%s: with all seven scraps" % plan["name"],
			"%d of 7" % int(ledger.call("held")))
	level.queue_free()
	for _frame in range(4):
		await process_frame


## The screens that stop the world, answered the way a player answers them. True when one was
## up this frame.
func _handle_screens(plan: Dictionary) -> bool:
	var choice := level.get_node_or_null(^"DialogueChoiceOverlay")
	if choice != null and bool(choice.call("is_open")):
		_release()
		# ⚠ ASKED BY WALKING, and nothing else here can open it. The DialogueNode was left at
		# y 440 when the plaza's walk line moved to 560, so its box ended over the apo's head
		# and Problem 1 -- the first beat, which opens only on this choice -- never began.
		if not _asked.has(plan["name"]):
			_asked[plan["name"]] = true
			_check(true, "%s: walking to the dancers opens the choice" % plan["name"],
				"asked at x %d" % int(player.global_position.x))
		await _frames(20)
		choice.call("_on_route_pressed", String(plan["L2_N1"]))
		await _frames(10)
		return true
	var dance := level.get("dance_screen") as DanceOverlay
	if dance != null and dance.is_open():
		_release()
		var track: PackedFloat32Array = (level.get("dance") as DanceMinigame).track()
		for beat in track:
			while dance.is_open() and dance.clock() < beat:
				await physics_frame
			if dance.is_open():
				dance.perform_stroke()
		await _frames(120)
		return true
	var table := level.get("assembly_screen") as AssemblyOverlay
	if table != null and table.is_open():
		_release()
		for scrap_id in table.piece_ids():
			table.drag_to(scrap_id, table.slot_of(scrap_id))
			await _frames(2)
		await _frames(20)
		table.call("_on_continue")
		await _frames(20)
		return true
	return false


## One step toward the objective.
func _act(plan: Dictionary, goal: Dictionary, key: String, done: Dictionary) -> void:
	var target: Variant = goal.get("target", null)
	match key:
		"light", "dance":
			await _walk_toward(target)
		"unlock":
			if await _walk_toward(target) and not done.has("key"):
				done["key"] = true
				await _draw("key")
		"startle":
			if await _walk_toward(target) and not done.has("scare"):
				done["scare"] = true
				await _draw("snake")
		"fetch_light", "to_church", "back_to_church", "rack":
			if await _walk_toward(target):
				level.call("press_interact")
				await _frames(20)
		"flock_strike":
			# The route the bot is proving is that nothing is lost by walking on, so it walks on.
			await _walk_toward(_onward_of("alley_1"), 4.0)
		"take_light", "to_alleys", "alley_on", "alley_end":
			await _walk_toward(target, 4.0)
		"priest":
			_release()
			await physics_frame
		"flock":
			if await _walk_toward(target) and not done.has("flock"):
				done["flock"] = true
				await _draw(String(plan["L2_N2"]))
		"bunting":
			if await _walk_toward(target) and not done.has("bunting"):
				done["bunting"] = true
				await _draw(String(plan["L2_N3"]))
		_:
			await physics_frame


## Walk toward a target with the movement keys, jumping when a step does not move the body.
## True once the player is standing under it.
func _walk_toward(target: Variant, close_enough: float = 22.0) -> bool:
	if not (target is Vector2):
		await physics_frame
		return true
	var dx: float = (target as Vector2).x - player.global_position.x
	if absf(dx) <= close_enough:
		_release()
		await physics_frame
		return true
	Input.action_release(&"move_left" if dx > 0.0 else &"move_right")
	Input.action_press(&"move_right" if dx > 0.0 else &"move_left")
	var before := player.global_position.x
	await _frames(6)
	# RE-READ: a morph running out mid-step swaps the body, and the old one is freed.
	player = level.get("player") as Node2D
	if player == null or not is_instance_valid(player):
		return false
	if absf(player.global_position.x - before) < 1.0:
		Input.action_press(&"jump")
		await _frames(8)
		Input.action_release(&"jump")
	return false


## A drawing, recognised: handed to the level through the panel's own signal handler, then set
## down through the placement controller if it is a thing that is set down.
func _draw(entity_id: String) -> void:
	_release()
	level.call("_on_drawing_ready", entity_id, entity_id.capitalize(),
		Image.create(28, 28, false, Image.FORMAT_RGBA8), {"confidence": 0.9}, [], 1.0)
	await _frames(12)
	var entry: Dictionary = (level.get("registry") as Node).call("get_entity", entity_id)
	var role := String(entry.get("runtime_role", ""))
	if role == "active_ragdoll_morph":
		await _frames(30)
		return
	# A TOOL IS ANSWERED BY USING IT: drawn where it answers it is put in hand, and F is the
	# answer. Pressed a few times, because a lock that measures the key can turn partway first.
	if String(entry.get("ink_role", "")) == "tool":
		await _frames(10)
		var director: Object = level.get("director")
		var beat := String(director.call("current_obstacle"))
		for _press in range(4):
			if beat.is_empty() or bool(director.call("is_solved", beat)):
				break
			level.call("_use_equipped_utility")
			await _frames(20)
		await _frames(20)
		return
	var items: Array = level.get("inventory_manager").call("items")
	for index in range(items.size()):
		var item := items[index] as DrawnItemData
		if item == null or item.entity_id != entity_id:
			continue
		level.call("_on_inventory_slot_pressed", index)
		await _frames(2)
		var placement := level.get("placement_controller") as Node2D
		if bool(placement.call("is_placing")):
			placement.set_process(false)
			# BEHIND, the way a player sets something down that is not a step: every target in
			# this level is further on, and a ladder stood in the way is a wall until it is
			# climbed or taken back.
			placement.call("update_target", player.global_position + Vector2(-110.0, -30.0))
			await _frames(4)
			if not bool(placement.call("confirm_placement")):
				placement.call("update_target", player.global_position + Vector2(110.0, -30.0))
				await _frames(4)
				placement.call("confirm_placement")
			placement.set_process(true)
		break
	await _frames(30)


func _onward_of(room_name: String) -> Vector2:
	var room := level.get(room_name) as PiyestaRoom2D
	return room.global_position + room.onward_rect().get_center()


func _room_name() -> String:
	var room := level.call("_room_holding_player") as Node2D
	return room.name if room != null else "plaza"


func _release() -> void:
	for action: StringName in [&"move_left", &"move_right", &"jump"]:
		Input.action_release(action)


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
