extends SceneTree
## EVERY ROUTE A TOOL ANSWERS, answered the way a player answers it.
##   godot --headless --path game --script res://tests/run_tool_routes_probe.gd
##
## ⚠ A TOOL IS NEVER PLACED, AND THAT IS WHERE EVERY OTHER DRAWING IS JUDGED. A placeable is
## judged when it is set down and a creature when the player becomes it; a key, an axe, a
## boomerang went straight into the belt and nothing asked the obstacle whether they were
## the answer. Piyesta's lit house, its knocked-down birds, its cut bunting, Payyo's cut
## route and its drawn key were all unfinishable in play -- and every probe that "proved"
## them called `_judge_submission` directly, the one step the game did not take.
##
## So this never calls it. It hands the level a recognised drawing through the same door the
## drawing panel uses, and for the belt it presses the slot and uses the tool.

const LEVELS := ["res://game_level.tscn", "res://level_2.tscn"]

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-58s %s" % ["OK  " if ok else "FAIL", what, detail])


func _run() -> void:
	print("\n===== TOOL ROUTES =====")
	var entities: Dictionary = {}
	for entry: Variant in (JSON.parse_string(FileAccess.get_file_as_string(
			"res://config/entities.json")) as Dictionary).get("entities", []):
		entities[String((entry as Dictionary)["id"])] = entry
	var answered := 0
	for path in LEVELS:
		var plan := await _tool_routes(path, entities)
		for entry: Dictionary in plan:
			answered += 1
			await _answer_by_drawing(path, entry)
			await _answer_from_the_belt(path, entry)
	_check(answered >= 6, "the routes a tool answers were all found",
		"%d routes across both levels" % answered)
	print("OBRA_TOOL_ROUTES_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)


func _open(path: String) -> Node:
	var fresh := (load(path) as PackedScene).instantiate()
	(fresh.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(fresh)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(30):
		await physics_frame
	return fresh


func _close(level: Node) -> void:
	level.queue_free()
	await process_frame
	await process_frame


## Every (obstacle, route) whose answers include a tool, read off a live level so the accept
## set is the one the game uses -- exclusions and the level's own refusals included.
func _tool_routes(path: String, entities: Dictionary) -> Array[Dictionary]:
	var level := await _open(path)
	var director = level.get("director")
	var out: Array[Dictionary] = []
	for obstacle_id: String in director.obstacle_ids():
		var routes: Dictionary = director.obstacle(obstacle_id).get("routes", {})
		for route: String in routes.keys():
			if (routes[route] as Dictionary).get("required_tags", []).is_empty():
				continue
			# Committed on a throwaway level: committing is one-way, and the plan must not
			# spend the route it is about to test.
			var scratch := await _open(path)
			var sd = scratch.get("director")
			sd.enter_obstacle(obstacle_id)
			sd.commit_route(obstacle_id, route)
			var accepted: PackedStringArray = sd.accept_set(obstacle_id)
			await _close(scratch)
			for class_id in accepted:
				var entry: Dictionary = entities.get(class_id, {})
				if String(entry.get("ink_role", "")) == "tool":
					out.append({"obstacle": obstacle_id, "route": route, "tool": class_id})
					break
	await _close(level)
	return out


func _enter(level: Node, obstacle_id: String, route: String) -> void:
	var director = level.get("director")
	director.enter_obstacle(obstacle_id)
	await physics_frame
	director.commit_route(obstacle_id, route)
	for _frame in range(10):
		await physics_frame


## Drawn AT the obstacle: the recogniser's answer handed to the level, nothing else.
func _answer_by_drawing(path: String, entry: Dictionary) -> void:
	var level := await _open(path)
	await _enter(level, entry["obstacle"], entry["route"])
	var director = level.get("director")
	level.call("_on_drawing_ready", entry["tool"], String(entry["tool"]).capitalize(),
		Image.create(28, 28, false, Image.FORMAT_RGBA8), {"confidence": 0.9}, [], 1.0)
	for _frame in range(30):
		await physics_frame
	# A lock that measures the key may turn partway and ask again; using the key is how a
	# player tries again, and the lock opens on its last turn whatever was drawn.
	for _turn in range(4):
		if director.is_solved(entry["obstacle"]):
			break
		_use_from_belt(level, entry["tool"])
		for _frame in range(20):
			await physics_frame
	_check(director.is_solved(entry["obstacle"]),
		"%s: drawing a %s answers %s/%s" % [path.get_file(), entry["tool"],
			entry["obstacle"], entry["route"]],
		"solved" if director.is_solved(entry["obstacle"])
		else "STILL OPEN -- the %s went into the bag and nothing asked" % entry["tool"])
	await _close(level)


## Drawn EARLIER, somewhere else, and taken out of the belt at the obstacle -- FR-7's "reusable
## at no ink cost and with no redraw".
func _answer_from_the_belt(path: String, entry: Dictionary) -> void:
	var level := await _open(path)
	var director = level.get("director")
	# Standing at no obstacle. Piyesta's spawn is at the edge of Problem 1, so "somewhere else"
	# has to be made true rather than assumed.
	if not String(director.current_obstacle()).is_empty():
		director.exit_obstacle(director.current_obstacle())
	level.call("_on_drawing_ready", entry["tool"], String(entry["tool"]).capitalize(),
		Image.create(28, 28, false, Image.FORMAT_RGBA8), {"confidence": 0.9}, [], 1.0)
	for _frame in range(20):
		await physics_frame
	_check(not director.is_solved(entry["obstacle"]),
		"%s: a %s drawn away from %s answers nothing there" % [path.get_file(), entry["tool"],
			entry["obstacle"]], "still open, as it should be")
	await _enter(level, entry["obstacle"], entry["route"])
	for _turn in range(4):
		if director.is_solved(entry["obstacle"]):
			break
		_use_from_belt(level, entry["tool"])
		for _frame in range(20):
			await physics_frame
	_check(director.is_solved(entry["obstacle"]),
		"%s: and using it from the belt at %s answers it" % [path.get_file(), entry["obstacle"]],
		"solved" if director.is_solved(entry["obstacle"]) else "STILL OPEN")
	await _close(level)


## Press the slot the tool is in if it is not already in hand, then use it.
func _use_from_belt(level: Node, tool_id: String) -> void:
	var held := level.get("_equipped_utility") as UtilityObject
	if held == null or not is_instance_valid(held) or held.item_data == null \
			or held.item_data.entity_id != tool_id:
		var items: Array = level.get("inventory_manager").call("items")
		for index in range(items.size()):
			var item := items[index] as DrawnItemData
			if item != null and item.entity_id == tool_id:
				level.call("_on_inventory_slot_pressed", index)
				break
	level.call("_use_equipped_utility")
