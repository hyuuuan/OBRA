extends SceneTree
## THE OBJECTIVE LINE, walked through both levels.
##   godot --headless --path game --script res://tests/run_objective_probe.gd
##
## Two playtests ended with "I am still confused on what to do", in both levels, from somebody
## who had read every line of dialogue. The banner answers that only if it is RIGHT at every
## step -- a line that still says "find a light" while the candle is in hand is worse than no
## line, because the player trusts it. So this drives each level through its real state
## changes, the way play does, and asks at every step:
##
##   the banner says something, and it is the line for THIS step
##   the marker has somewhere to point, in the room the player is in
##   a tag is named once the beat has taught it
##   and no objective in either config names a class the player has not earned

var failures := 0
var level: Node


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-52s %s" % ["OK  " if ok else "FAIL", what, detail])


func _run() -> void:
	print("\n===== OBJECTIVES =====")
	_audit_no_objective_names_a_class("res://config/level_01.json")
	_audit_no_objective_names_a_class("res://config/level_02.json")
	await _walk_piyesta()
	await _walk_payyo()
	print("OBRA_OBJECTIVE_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)


func _open(path: String) -> Node:
	var fresh := (load(path) as PackedScene).instantiate()
	(fresh.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(fresh)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(30):
		await physics_frame
	return fresh


func _frames(count: int = 8) -> void:
	for _frame in range(count):
		await physics_frame


## What the banner says and which line it came from, asked now rather than on the clock.
func _state() -> Dictionary:
	level.call("refresh_objective")
	var goal: Dictionary = level.call("_current_objective")
	var banner := level.get("objective_banner") as ObjectiveBanner
	var marker := level.get("objective_marker") as ObjectiveMarker
	return {
		"key": String(goal.get("key", "")),
		"text": banner.text() if banner != null else "",
		"marker": marker != null and marker.has_target(),
	}


func _expect(step: String, key: String, needs_marker: bool = true,
		must_say: String = "") -> void:
	var now := _state()
	_check(now["key"] == key, "%s: the line is '%s'" % [step, key],
		"'%s' -> \"%s\"" % [now["key"], now["text"]])
	_check(not String(now["text"]).is_empty(), "%s: and it says something" % step,
		"\"%s\"" % now["text"])
	if needs_marker:
		_check(bool(now["marker"]), "%s: and the marker has somewhere to point" % step,
			"pointing" if now["marker"] else "NOTHING to point at")
	if not must_say.is_empty():
		_check(String(now["text"]).contains(must_say), "%s: naming %s" % [step, must_say],
			"\"%s\"" % now["text"])


# --- Piyesta ---------------------------------------------------------------------------

func _walk_piyesta() -> void:
	level = await _open("res://level_2.tscn")
	var director = level.get("director")
	var player := level.get("player") as Node2D
	print("  -- Piyesta")
	_expect("arrival", "light")

	# Problem 1 by the house with the light on.
	director.enter_obstacle("L2_N1")
	await _frames()
	director.commit_route("L2_N1", "pragmatist")
	await _frames()
	_expect("chose the lit house", "unlock", true, "UNLOCK")
	# AND IT STANDS DOWN AT THE DOOR. The target is over the hood, two hundred units above the
	# apo's feet; a marker still bobbing over their head at the right door is the game failing
	# to notice they got there.
	var pointer := level.get("objective_marker") as ObjectiveMarker
	var start := player.global_position
	player.global_position = Vector2(pointer.target().x, 500.0)
	await _frames(4)
	_check(not pointer.showing(), "at the lit house the marker stands down", "hidden")
	player.global_position = start
	await _frames(4)
	_check(pointer.showing(), "and comes back when the player walks off", "showing")
	var accepted: PackedStringArray = director.accept_set("L2_N1")
	level.call("_judge_submission", accepted[0])
	await _frames(20)
	_expect("the house is open", "fetch_light")

	var house := level.get("house") as PiyestaRoom2D
	level.call("_enter_room", house, player.global_position)
	await _frames(12)
	_expect("inside the house", "take_light")
	var candle := level.get("_kandila_prop") as Kandila2D
	candle.call("_take")
	await _frames(12)
	_expect("candle in hand, still inside", "to_church")
	var marker := level.get("objective_marker") as ObjectiveMarker
	_check(Rect2(house.bounds()).grow(90.0).has_point(marker.target()),
		"and it points at the way out of the house, not at the plaza",
		"target %s" % marker.target())

	level.call("_leave_room", house)
	await _frames(12)
	_expect("candle in hand, on the plaza", "to_church")
	var church := level.get("church") as PiyestaRoom2D
	level.call("_enter_room", church, player.global_position)
	await _frames(12)
	_expect("in the church", "rack")
	# AT THE RACK, the way a player is when E puts it there -- the priest walks over to
	# whoever lit it, so where they are standing is part of the scene.
	var chancel := level.get("chancel") as ChurchInterior2D
	(level.get("player") as Node2D).global_position = chancel.rack_point() + Vector2(0.0, -8.0)
	await _frames(6)
	chancel.place_the_kandila()
	await _frames(6)
	_expect("candle on the rack", "priest", false)
	for _second in range(80):
		if church.onward_open:
			break
		await physics_frame
		await create_timer(0.1, true).timeout
	_check(church.onward_open, "the priest opens the way to the alleys", "open")
	_expect("the far end is open", "to_alleys")

	level.call("_go_onward", church)
	await _frames(12)
	# The alley asks how at the way in. Until it is answered, the line is the flock.
	_expect("in the first alley", "flock")
	director.enter_obstacle("L2_N2")
	await _frames()
	_expect("at the flock", "flock", true, "FEED")
	await _choose("artist")
	_expect("chose to feed them", "flock_feed", true, "FEED")
	_draw("bread")
	await _frames(4)
	await _place("bread", player.global_position + Vector2(280.0, -30.0))
	var alley_1 := level.get("alley_1") as PiyestaRoom2D
	var first = (level.get("_alleys") as Dictionary)["L2_N2"]
	await _until_pieces_are_down(first)
	_expect("the flock is down, the pieces are not in hand", "flock_collect", true)
	await _walk_over_the_pieces(first)
	_expect("every piece picked up", "alley_on")

	level.call("_go_onward", alley_1)
	await _frames(12)
	_expect("in the second alley", "flock")
	await _choose("protector")
	_expect("chose to throw", "flock_stone", true, "STRIKE")
	_draw("circle")
	await _frames(4)
	_expect("a stone in hand", "flock_aim", false)
	var second = (level.get("_alleys") as Dictionary)["L2_N3"]
	var thrower := second.get("thrower") as StoneThrow2D
	thrower.follow_mouse = false
	thrower.aim_at(level.call("_throwing_hand") + Vector2(140.0, -40.0))
	level.call("_use_equipped_utility")
	for _frame in range(240):
		if not thrower.in_flight():
			break
		await physics_frame
	await _frames(2)
	_expect("the stone missed and is lying there", "flock_fetch", true)
	player.global_position = Vector2(thrower.resting_stone().x, player.global_position.y)
	await _frames(6)
	_expect("picked back up", "flock_aim", false)
	for bird: ScrapBird2D in second.get("birds"):
		bird.strike_down()
	await _until_pieces_are_down(second)
	_expect("both knocked down", "flock_collect", true)
	await _walk_over_the_pieces(second)
	_expect("the last pieces picked up", "alley_end")
	level.call("_open_scene_3")
	await _frames(6)
	_expect("at the table", "table", false)
	level.queue_free()
	await process_frame
	await _walk_the_cut_route()


## The route with two drawings in it, on its own: a climb first, then an edge, and the line says
## which is next and points at the strings for the second.
func _walk_the_cut_route() -> void:
	level = await _open("res://level_2.tscn")
	var director = level.get("director")
	print("  -- Piyesta, the cut route")
	level.set("_has_kandila", true)
	(level.get("chancel") as ChurchInterior2D).kandila_on_rack = true
	(level.get("church") as PiyestaRoom2D).open_onward()
	level.call("_go_onward", level.get("church"))
	await _frames(12)
	await _choose("pragmatist")
	_expect("chose to cut them down", "flock_climb", true, "CLIMB")
	var alley = (level.get("_alleys") as Dictionary)["L2_N2"]
	var line := alley.get("line") as BandaritaLine2D
	var player := level.get("player") as Node2D
	_draw("ladder")
	await _frames(4)
	await _place("ladder", Vector2(line.middle().x, player.global_position.y - 60.0))
	_expect("something to climb set down", "flock_cut", true, "CUT")
	var marker := level.get("objective_marker") as ObjectiveMarker
	_check(marker.target().distance_to(line.middle()) < 2.0,
		"and the marker is on the strings", "target %s" % marker.target())
	_check(director.stage("L2_N2") == 1, "the cut route is on its second half", "stage 1")
	level.queue_free()
	await process_frame


func _choose(route: String) -> void:
	var choice := level.get_node_or_null(^"DialogueChoiceOverlay")
	for _frame in range(600):
		if choice != null and bool(choice.call("is_open")):
			break
		await physics_frame
	_check(choice != null and bool(choice.call("is_open")), "the alley asks how", route)
	if choice != null and bool(choice.call("is_open")):
		choice.call("_on_route_pressed", route)
	await _frames(10)


func _draw(entity_id: String) -> void:
	level.call("_on_drawing_ready", entity_id, entity_id.capitalize(),
		Image.create(28, 28, false, Image.FORMAT_RGBA8), {"confidence": 0.9}, [], 1.0)


func _place(entity_id: String, at: Vector2) -> void:
	var slot := int(level.call("_slot_holding", entity_id))
	if slot < 0:
		return
	level.call("_on_inventory_slot_pressed", slot)
	await _frames(2)
	var placement := level.get("placement_controller") as Node2D
	placement.set_process(false)
	placement.call("update_target", at)
	await _frames(4)
	placement.call("confirm_placement")
	placement.set_process(true)
	await _frames(10)


func _until_pieces_are_down(alley) -> void:
	var count: int = (alley.get("birds") as Array).size()
	for _frame in range(900):
		if (alley.get("dropped") as Dictionary).size() >= count:
			break
		await physics_frame
	await _frames(2)


func _walk_over_the_pieces(alley) -> void:
	var player := level.get("player") as Node2D
	for _i in range(20):
		var pieces: Dictionary = alley.get("pieces")
		if pieces.is_empty():
			break
		var piece: Node2D = pieces.values()[0]
		player.global_position = Vector2(piece.global_position.x, player.global_position.y)
		await _frames(6)


# --- Payyo -----------------------------------------------------------------------------

func _walk_payyo() -> void:
	level = await _open("res://game_level.tscn")
	var director = level.get("director")
	var player := level.get("player") as Node2D
	print("  -- Payyo")
	_expect("arrival", "b0_sub1")

	director.enter_obstacle("B0_HAGDAN")
	await _frames()
	_expect("at the paddy", "b0_sub1", true, "ROLL")
	level.call("_judge_submission", (director.accept_set("B0_HAGDAN") as PackedStringArray)[0])
	await _frames(12)
	_expect("the step floats", "b0_sub2", true, "SPAN")
	level.call("_judge_submission", (director.accept_set("B0_HAGDAN") as PackedStringArray)[0])
	await _frames(12)
	director.exit_obstacle("B0_HAGDAN")
	_expect("up Ang Hagdan", "gorge")
	var marker := level.get("objective_marker") as ObjectiveMarker
	_check(not marker.on_screen(), "and the gorge is off screen, so it is an edge arrow",
		"screen point %s" % marker.screen_point())

	director.enter_obstacle("L1_N1")
	director.commit_route("L1_N1", "protector")
	await _frames()
	_expect("chose to cut a way", "gorge", true, "CUT")
	level.call("_judge_submission", (director.accept_set("L1_N1") as PackedStringArray)[0])
	await _frames(20)
	director.exit_obstacle("L1_N1")
	player.global_position = Vector2(3500.0, 100.0)
	await _frames(12)
	_expect("across the gorge", "straw")

	# Straight to the house with the key off the nail, which never solves the heap.
	level.call("_take_the_bale_key", "off_the_nail")
	await _frames(6)
	_expect("carrying what was on the nail", "bale")
	director.solve_with_item("L1_N3", "L1_bale_key")
	level.call("_on_route_solved", "L1_N3", "pragmatist")
	await _frames(30)
	_expect("inside Ang Bale", "painting")
	var bale := get_first_node_in_group(&"bale_interiors")
	bale.call("_on_painting_body", player)
	await _frames(12)
	_expect("painting in hand", "onward")
	level.queue_free()
	await process_frame


# --- The words -------------------------------------------------------------------------

## THE RULE EVERY LINE OF DIALOGUE IS HELD TO, held here too: nothing on screen names a
## drawable class the player has not earned. The banner is the most-read line in the game, so
## it is the worst place to leak one. Whole words, and their plurals -- "birds" is "bird".
func _audit_no_objective_names_a_class(path: String) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var objectives: Dictionary = data.get("objectives", {})
	_check(not objectives.is_empty(), "%s has objectives" % path.get_file(),
		"%d lines" % objectives.size())
	var labels: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../model/labels.json")) \
		if FileAccess.file_exists("res://../model/labels.json") else []
	if labels.is_empty():
		for entry: Variant in (JSON.parse_string(FileAccess.get_file_as_string(
				"res://config/entities.json")) as Dictionary).get("entities", []):
			labels.append(String((entry as Dictionary).get("id", "")).replace("_", " "))
	var named: Array[String] = []
	# ⚠ READ AS SHOWN, the way run_level3_audit reads Dagat's. A `{key:use_utility}` is written
	# out as "F" before anybody sees it -- and `key` is one of the fifty, so read raw, every line
	# that names a key would name a class. Loaded here rather than preloaded: the base names the
	# autoloads, which a `--script` run has not registered when it compiles its own constants.
	var base = load("res://scripts/level_base.gd")
	for key: Variant in objectives.keys():
		if String(key).begins_with("$"):
			continue
		var shown := String(base.with_keys(String(objectives[key])))
		var words := _words_in(shown.to_lower())
		for label: Variant in labels:
			var word := String(label).to_lower()
			if word.contains(" "):
				if shown.to_lower().contains(word):
					named.append("%s: %s" % [key, word])
				continue
			if words.has(word) or words.has(word + "s") or words.has(word + "es"):
				named.append("%s: %s" % [key, word])
	_check(named.is_empty(), "and none of them names a class",
		"clean" if named.is_empty() else "; ".join(named))


func _words_in(text: String) -> PackedStringArray:
	var cleaned := ""
	for index in text.length():
		var glyph := text[index]
		cleaned += glyph if glyph >= "a" and glyph <= "z" else " "
	return cleaned.split(" ", false)
