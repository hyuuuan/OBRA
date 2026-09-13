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
	(level.get("chancel") as ChurchInterior2D).place_the_kandila()
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
	_expect("in the first alley", "flock")
	director.enter_obstacle("L2_N2")
	await _frames()
	_expect("at the flock", "flock", true, "FEED")
	director.commit_route("L2_N2", "artist")
	level.call("_judge_submission", (director.accept_set("L2_N2") as PackedStringArray)[0])
	await _frames(20)
	_expect("the flock is answered", "alley_on")

	var alley_1 := level.get("alley_1") as PiyestaRoom2D
	level.call("_go_onward", alley_1)
	await _frames(12)
	_expect("in the second alley", "bunting")
	director.enter_obstacle("L2_N3")
	await _frames()
	director.commit_route("L2_N3", "artist")
	level.call("_judge_submission", (director.accept_set("L2_N3") as PackedStringArray)[0])
	await _frames(20)
	_expect("the bunting is answered", "alley_end")
	level.call("_open_scene_3")
	await _frames(6)
	_expect("at the table", "table", false)
	level.queue_free()
	await process_frame


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
	for key: Variant in objectives.keys():
		if String(key).begins_with("$"):
			continue
		var words := _words_in(String(objectives[key]).to_lower())
		for label: Variant in labels:
			var word := String(label).to_lower()
			if word.contains(" "):
				if String(objectives[key]).to_lower().contains(word):
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
