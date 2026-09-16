extends SceneTree
## PAYYO'S HUD, WATCHED WHILE IT IS PLAYED.
##   godot --headless --path game --script res://tests/run_hud_watch_level1.gd
##
## Kent, twice: the text "at the top of the game" overlaps. A still frame with everything raised
## at once came up clear, and so did three whole plays of Piyesta -- but Payyo is the level
## that talks the most. It is the tutorial: the opening lines, a lesson on every first action,
## an objective that changes at every sub-beat, a card for every first drawing, and Lolo's
## hints over all of it. Those arrive within a second of each other, which is exactly when two
## of them land in the same place.
##
## So this does what a first-time player does in the first minutes -- stands at the spawn while
## Lolo talks, walks to the paddy, draws a circle and sets it on the plank, draws a square,
## walks the terraces, takes Lolo's choice at the gorge, draws the tool the route needs and uses
## it, and does the same at the straw and at the house -- and every few frames asks what the
## HUD is painting and whether any of it is standing on anything else.
##
## Run WITHOUT --headless and it also photographs each moment to /tmp/obra_watch_*.png, because
## "nothing overlaps" and "it looks neat" are two different claims and only one is a number.

const HudOverlap = preload("res://tests/hud_overlap.gd")

var failures := 0
var level: Node
var _frame := 0
var _seen: Dictionary = {}
var _moment := "spawn"


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-44s %s" % ["OK  " if ok else "FAIL", what, detail])


func _run() -> void:
	print("\n===== PAYYO, HUD WATCHED =====")
	level = (load("res://game_level.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	physics_frame.connect(_watch)

	await _moment_of("the opening, standing still", 480)
	await _walk("walking to the paddy", &"move_right", 150)
	await _draw_and_place("circle", Vector2(750.0, 520.0), "a circle for the plank")
	await _moment_of("the plank settling", 120)
	await _draw_and_place("square", Vector2(1120.0, 470.0), "a square at the stair")
	await _moment_of("after the stair", 180)

	for beat in [
		{"at": Vector2(2900.0, 180.0), "route": "protector", "tool": "axe", "name": "the gorge"},
		{"at": Vector2(3700.0, 180.0), "route": "", "tool": "rake", "name": "the straw"},
		{"at": Vector2(4450.0, 40.0), "route": "pragmatist", "tool": "key", "name": "the house"},
	]:
		await _at_a_beat(beat)

	physics_frame.disconnect(_watch)
	var lines: Array[String] = []
	for clash: String in _seen.keys():
		lines.append("%s (during %s)" % [clash, _seen[clash]])
	_check(lines.is_empty(), "nothing on Payyo's HUD overlapped in play",
		"clear the whole way" if lines.is_empty() else "; ".join(lines))
	print("OBRA_HUD_WATCH_L1_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)


var _shots := 0


func _photograph() -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_shots += 1
	root.get_texture().get_image().save_png("/tmp/obra_watch_%02d_%s.png" % [
		_shots, _moment.replace(" ", "_").replace(",", "")])


func _watch() -> void:
	_frame += 1
	if _frame % 6 != 0 or level == null or not is_instance_valid(level):
		return
	for clash in HudOverlap.clashes(HudOverlap.painted(level)):
		if not _seen.has(clash):
			_seen[clash] = _moment


func _moment_of(what: String, frames: int) -> void:
	_moment = what
	for _i in range(frames):
		await physics_frame
		_close_screens()
		if _i == 60:
			await _photograph()


## Any choice screen answers with the route asked for; any card or memory is dismissed the way
## a key press would.
func _close_screens(route: String = "artist") -> void:
	var choice := level.get_node_or_null(^"DialogueChoiceOverlay")
	if choice != null and bool(choice.call("is_open")):
		choice.call("_on_route_pressed", route)
	var memory := level.get_node_or_null(^"MemoryOverlay")
	if memory != null and bool(memory.call("is_open")):
		memory.call("close")


func _walk(what: String, action: StringName, frames: int) -> void:
	_moment = what
	Input.action_press(action)
	for _i in range(frames):
		await physics_frame
		_close_screens()
		if _i == frames - 10:
			await _photograph()
	Input.action_release(action)


func _player() -> Node2D:
	return level.get("player") as Node2D


func _draw_and_place(entity_id: String, at: Vector2, what: String) -> void:
	_moment = what
	level.call("_on_drawing_ready", entity_id, entity_id.capitalize(),
		Image.create(28, 28, false, Image.FORMAT_RGBA8), {"confidence": 0.9}, [], 1.0)
	for _i in range(40):
		await physics_frame
	var items: Array = level.get("inventory_manager").call("items")
	for index in range(items.size()):
		var item := items[index] as DrawnItemData
		if item == null or item.entity_id != entity_id:
			continue
		level.call("_on_inventory_slot_pressed", index)
		await physics_frame
		var placement := level.get("placement_controller") as Node2D
		if bool(placement.call("is_placing")):
			placement.set_process(false)
			placement.call("update_target", at)
			for _i in range(4):
				await physics_frame
			if not bool(placement.call("confirm_placement")):
				placement.call("cancel_placement")
			placement.set_process(true)
		break
	for _i in range(60):
		await physics_frame


func _at_a_beat(beat: Dictionary) -> void:
	_moment = "arriving at %s" % beat["name"]
	var apo := _player()
	if apo != null and apo.has_method("apply_morph_state"):
		apo.call("apply_morph_state", {"position": beat["at"], "linear_velocity": Vector2.ZERO})
	for _i in range(20):
		await physics_frame
	await _walk("walking into %s" % beat["name"], &"move_right", 90)
	var route := String(beat["route"])
	for _i in range(90):
		await physics_frame
		_close_screens(route if not route.is_empty() else "artist")
	var director = level.get("director")
	var here := String(director.current_obstacle())
	if not route.is_empty() and not here.is_empty():
		director.commit_route(here, route)
	_moment = "drawing the %s at %s" % [beat["tool"], beat["name"]]
	level.call("_on_drawing_ready", beat["tool"], String(beat["tool"]).capitalize(),
		Image.create(28, 28, false, Image.FORMAT_RGBA8), {"confidence": 0.9}, [], 1.0)
	for _i in range(90):
		await physics_frame
		_close_screens()
		if _i == 50:
			await _photograph()
	_moment = "using the %s at %s" % [beat["tool"], beat["name"]]
	for _press in range(3):
		level.call("_use_equipped_utility")
		for _i in range(60):
			await physics_frame
			_close_screens()
