extends SceneTree
## The places, headless: each level's props heard where the screen already shows them.
##
##   godot --headless --path game --script res://tests/run_sfx_places_probe.gd
##
## Headless hears nothing, so what is checked is the ASKING (AudioDirector.sfx_requested) and,
## at that moment, the visual the sound plays beside (Dilim's rule). AUDIO_PLAN.md's table E: a
## door seen to open (and not one a restore opens), a lock giving, a kandila on its rack, the
## dancers running, a cue danced (as loud as it was good), the line cast and reeled home, the
## bakunawa's gift, and a painting or the brush lifting. Dilim's four were already asked for
## (run_level4_sound_probe checks it, with their ripples); here they are checked to have files.
##
## `-- <words>` runs only the scenarios whose name holds them (for a mutant); the every-check-ran
## guard stands down for such a run.

const PLACES := [&"tiktik_call", &"tiyanak_cry", &"lantern_hit", &"dawn", &"door", &"candle",
	&"scatter", &"dance_cue", &"cast", &"reel", &"gift", &"painting"]
## ⚠ BY PATH: the fishing line has no class_name (see fishing_line_2d.gd).
const FishingLine = preload("res://scripts/fishing_line_2d.gd")
## And the next painting (next_painting_2d.gd has none either).
const NextPainting = preload("res://scripts/next_painting_2d.gd")

var failures := 0
var checked := 0
const CHECKS := 11
var level: Node
## Every sound asked for in the current scenario: [id, snapshot, loudness]. ⚠ A member, not a
## local: a lambda captures locals by value.
var heard: Array = []
## What a scenario wants recorded beside each sound, read the moment it is asked for.
var snapshot: Callable = func() -> Dictionary: return {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(300.0).timeout.connect(func() -> void:
		print("OBRA_SFX_PLACES_FAILED=watchdog")
		quit(2))
	root.get_node(^"AudioDirector").connect(&"sfx_requested", _on_sfx_requested)
	var only := " ".join(OS.get_cmdline_user_args())
	for scenario: Callable in [_every_place_sound_has_a_file, _a_door_is_heard_when_seen_to_open,
			_a_lock_is_heard_giving, _a_kandila_is_heard_on_its_rack, _the_dancers_are_heard_running,
			_a_cue_is_heard_as_good_as_it_was, _the_line_is_heard_in_and_home,
			_the_gift_is_heard_uncovered, _a_painting_is_heard_lifting]:
		if not only.is_empty() and not String(scenario.get_method()).contains(only):
			continue
		heard.clear()
		snapshot = func() -> Dictionary: return {}
		await scenario.call()
		if level != null and is_instance_valid(level):
			level.queue_free()
			level = null
			await _frames(4)
	if only.is_empty() and checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_SFX_PLACES_OK")
		quit(0)
	else:
		print("OBRA_SFX_PLACES_FAILED=%d" % failures)
		quit(1)


func _on_sfx_requested(id: StringName, loudness: float) -> void:
	heard.append([String(id), snapshot.call(), loudness])


# --- The scenarios -------------------------------------------------------------------------

func _every_place_sound_has_a_file() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/audio.json"))
	var sfx: Dictionary = catalog.get("sfx", {})
	var silent: Array[String] = []
	for id: StringName in PLACES:
		var path := String(sfx.get(String(id), ""))
		if path.is_empty() or not (load(path) is AudioStreamWAV):
			silent.append(String(id))
	_check(silent.is_empty(), "every place sound has a file", "%d of %d" % [PLACES.size() - silent.size(),
		PLACES.size()] if silent.is_empty() else "silent: " + ", ".join(silent))


## Piyesta's church door opens as she takes the kandila. A checkpoint restore opens doors too, on
## doors that were open all along, and that is not heard.
func _a_door_is_heard_when_seen_to_open() -> void:
	await _open("res://level_2.tscn", "level_2")
	var doors: Dictionary = level.get("_doors")
	var church := doors.get(level.get("DOOR_CHURCH")) as PiyestaDoor2D
	snapshot = func() -> Dictionary: return {"open": church.open}
	level.call("_hold_the_kandila")
	var church_heard := _count("door") == 1 and bool(_first("door").get("open", false))
	# The lit house's, as the Pragmatist route takes the kandila from its sill.
	var lit := doors.get(level.get("DOOR_LIT_HOUSE")) as PiyestaDoor2D
	heard.clear()
	snapshot = func() -> Dictionary: return {"open": lit.open}
	level.call("_on_route_solved", "L2_N1", "pragmatist")
	_check(church_heard and _count("door") == 1 and bool(_first("door").get("open", false)),
		"a door is heard as it is seen to open: the church's and the lit house's", "%s" % [heard])
	heard.clear()
	lit.set_open(false)
	lit.set_open(true)
	_check(lit.open and not _ids().has("door"), "and a door a restore opens is not heard", "%s" % [heard])


func _a_lock_is_heard_giving() -> void:
	var lock := Lockable2D.new()
	root.add_child(lock)
	await _frames(1)
	snapshot = func() -> Dictionary: return {"locked": lock.is_locked}
	lock.try_unlock("not_the_key", DrawnItemData.new())
	var wrong := _ids().duplicate()
	lock.try_unlock(lock.accepted_key_tag, DrawnItemData.new())
	_check(wrong.is_empty() and _count("unlock") == 1 and not bool(_first("unlock").get("locked", true)),
		"a lock is heard as it gives, and not to the wrong key", "wrong key %s, %s" % [wrong, heard])
	lock.queue_free()


func _a_kandila_is_heard_on_its_rack() -> void:
	var church := ChurchInterior2D.new()
	root.add_child(church)
	await _frames(1)
	snapshot = func() -> Dictionary: return {"on_rack": church.kandila_on_rack}
	church.place_the_kandila()
	church.place_the_kandila()
	_check(_count("candle") == 1 and bool(_first("candle").get("on_rack", false)),
		"a kandila is heard as it goes on the rack, once", "%s" % [heard])
	church.queue_free()


func _the_dancers_are_heard_running() -> void:
	var dancers := DancerGroup2D.new()
	root.add_child(dancers)
	await _frames(1)
	snapshot = func() -> Dictionary: return {"fleeing": int(dancers.get(&"_state")) == DancerGroup2D.State.FLEEING}
	dancers.scatter()
	dancers.scatter()
	_check(_count("scatter") == 1 and bool(_first("scatter").get("fleeing", false)),
		"the dancers are heard as they start to run, once", "%s" % [heard])
	dancers.queue_free()


## A perfect cue at full and a late one softer, each with its verdict's flash. (A stroke is only judged
## against a cue within the hit window, so a stroke is never a miss.)
func _a_cue_is_heard_as_good_as_it_was() -> void:
	var dance := DanceMinigame.new()
	dance.set_track(PackedFloat32Array([1.0, 3.0, 5.0]))
	var screen := DanceOverlay.new()
	root.add_child(screen)
	screen.bind(dance)
	await _frames(1)
	screen.present()
	await _frames(1)
	heard.clear()
	snapshot = func() -> Dictionary: return {"flash": String(screen.get(&"_flash"))}
	for at: float in [1.0, 3.0 + DanceMinigame.PERFECT_WINDOW + 0.05]:
		screen.set(&"_clock", at)
		screen.perform_stroke()
	var cues: Array = heard.filter(func(entry: Array) -> bool: return entry[0] == "dance_cue") \
		.map(func(entry: Array) -> String: return "%s %.1f" % [(entry[1] as Dictionary).get("flash", ""), entry[2]])
	_check(cues == ["PERFECT 1.0", "LATE 0.6"], "a cue is heard as good as it was",
		"%s" % [cues])
	# ⚠ CLOSED, NOT JUST FREED: it is modal, and UIRouter keeps the tree paused while it is open.
	screen.close()
	screen.queue_free()
	await _frames(2)
	paused = false


func _the_line_is_heard_in_and_home() -> void:
	var line: Node2D = FishingLine.new()
	line.set(&"waterline", 420.0)
	root.add_child(line)
	await _frames(1)
	snapshot = func() -> Dictionary: return {"in_water": bool(line.get(&"_in_water")),
		"winding": bool(line.get(&"_winding_home"))}
	line.call(&"cast", Vector2(100.0, 300.0), Vector2(400.0, 300.0), 0.6)
	for _frame in range(60 * 4):
		if _ids().has("cast"):
			break
		await _frames(1)
	_check(_count("cast") == 1 and bool(_first("cast").get("in_water", false)),
		"the line is heard as it goes in the water", "%s" % [heard])
	line.call(&"reel_in")
	for _frame in range(60 * 6):
		if _ids().has("reel"):
			break
		await _frames(1)
	_check(_count("reel") == 1 and not bool(_first("reel").get("winding", true)),
		"and heard again as it comes home", "%s" % [heard])
	line.queue_free()


func _the_gift_is_heard_uncovered() -> void:
	await _open("res://level_3.tscn", "level_3")
	level.call("_on_gift_offered")
	_check(_count("gift") == 1, "the bakunawa's gift is heard as it is uncovered", "%s" % [_ids()])


## The next painting, and Lola's brush on its stand.
func _a_painting_is_heard_lifting() -> void:
	var painting: Node2D = NextPainting.new()
	var stand := BrushStand2D.new()
	root.add_child(painting)
	root.add_child(stand)
	await _frames(1)
	snapshot = func() -> Dictionary: return {"painting": bool(painting.get(&"_taken")),
		"brush": not bool(stand.get(&"_holds_brush"))}
	painting.call(&"take")
	var first := _first("painting")
	heard.clear()
	stand.take()
	var second := _first("painting")
	_check(bool(first.get("painting", false)) and bool(second.get("brush", false)) and _count("painting") == 1,
		"a painting is heard as it lifts, and so is the brush", "%s / %s" % [first, second])
	painting.queue_free()
	stand.queue_free()


# --- Helpers -------------------------------------------------------------------------------

func _open(scene: String, level_id: String) -> void:
	root.get_node(^"LevelManager").set("current_level_id", level_id)
	level = (load(scene) as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(40)
	for _attempt in range(10):
		for node in get_nodes_in_group(ModalOverlay.GROUP):
			if node is InventoryScreen:
				continue
			if bool(node.call(&"is_open")):
				node.call(&"close")
		call_group(DialogueBox.GROUP, &"hide_line")
		paused = false
		await physics_frame
	heard.clear()


func _ids() -> Array:
	return heard.map(func(entry: Array) -> String: return entry[0])


func _count(id: String) -> int:
	return _ids().count(id)


func _first(id: String) -> Dictionary:
	for entry: Array in heard:
		if entry[0] == id:
			return entry[1]
	return {}


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
